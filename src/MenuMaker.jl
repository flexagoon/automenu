module MenuMaker

using PDFIO
using DataFrames
using JuMP
using HiGHS

export makemenu

const blacklist = ["Сарделька из мяса птицы", "Сыр", "Запечённая индейка", "Сосиска из мяса птицы"]
const mincalories = 600
const maxcalories = 700
const minprotein = 50

function makemenu(filename::AbstractString)
    file = pdDocOpen(filename)

    pagecount = pdDocGetPageCount(file)

    menu = []
    for i in 1:pagecount
        page = pdDocGetPage(file, i)

        if i != 5
            breakfast, lunch = parsepage(page)
            push!(menu, (breakfast=breakfast, lunch=lunch))
        else
            lunch = parsepage(page, false)
            push!(menu, (breakfast=nothing, lunch=lunch))
        end
    end

    return menu
end

function parsepage(page::PDPage, includebreakfast=true)
    text = sprint(pdPageExtractText, page)

    text = replace(text, r"[\n ]{2,}" => ";", "," => ".")

    lunch = match(r"ОБЕД;(.*);ПОЛДНИК", text)[1]
    lunch = parsefoods(lunch)

    if includebreakfast
        breakfast = match(r"ЗАВТРАК;(.*);ОБЕД", text)[1]
        breakfast = parsefoods(breakfast)

        calculateplan!(breakfast, lunch)

        filter!(row -> row.eat, breakfast)
        filter!(row -> row.eat, lunch)

        return breakfast, lunch
    else
        calculateplan!(lunch)

        filter!(row -> row.eat, lunch)

        return lunch
    end
end

const foodpattern = r"([^\d;]+);([\d.]+);([\d.]+);([\d.]+);([\d.]+);\d+ руб.;(\d+) гр\.;|([\d.]+);([\d.]+);([\d.]+);([\d.]+);([^\d;]+);\d+ руб.;(\d+) гр\.;"
function parsefoods(menu)
    matches = eachmatch(foodpattern, menu)

    foods = DataFrame()
    for match in matches
        match = match.captures
        if isnothing(match[7])
            match = map(x -> something(tryparse(Float64, x), x), match[1:6])

            size = match[6] / 100
            if !(match[1] in blacklist)
                push!(foods, (
                    name=match[1],
                    calories=match[2] * size,
                    protein=match[3] * size,
                    fat=match[4] * size,
                    carbs=match[5] * size
                ))
            end
        else
            match = map(x -> something(tryparse(Float64, x), x), match[7:12])

            size = match[6] / 100
            if !(match[5] in blacklist)
                push!(foods, (
                    name=match[5],
                    calories=match[1] * size,
                    protein=match[2] * size,
                    fat=match[3] * size,
                    carbs=match[4] * size
                ))
            end
        end
    end

    return foods
end

function calculateplan!(breakfast, lunch)
    breakfast_range = 1:size(breakfast, 1)
    lunch_range = 1:size(lunch, 1)

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    @variable(model, x[breakfast_range], Bin)
    @variable(model, y[lunch_range], Bin)

    breakfast_calories = sum(breakfast.calories[i] * x[i] for i in breakfast_range)
    lunch_calories = sum(lunch.calories[i] * y[i] for i in lunch_range)
    @constraint(model, breakfast_calories >= mincalories)
    @constraint(model, lunch_calories >= mincalories)
    @constraint(model, breakfast_calories + lunch_calories <= maxcalories * 2)

    bprotein = sum(breakfast.protein[i] * x[i] for i in breakfast_range)
    lprotein = sum(lunch.protein[i] * y[i] for i in lunch_range)
    @constraint(model, bprotein + lprotein >= minprotein * 2)

    @objective(model, Min, sum(x) + sum(y))

    optimize!(model)

    breakfast[!, "eat"] = [value(x[i]) > 0.5 for i in breakfast_range]
    lunch[!, "eat"] = [value(y[i]) > 0.5 for i in lunch_range]

    return nothing
end

function calculateplan!(lunch)
    range = 1:size(lunch, 1)

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    @variable(model, x[range], Bin)
    @constraint(model, mincalories <= sum(lunch.calories[i] * x[i] for i in range) <= maxcalories)
    @constraint(model, sum(lunch.protein[i] * x[i] for i in range) >= minprotein)
    @objective(model, Min, sum(x))

    optimize!(model)

    lunch[!, "eat"] = [value(x[i]) > 0.5 for i in range]

    return nothing
end

end
