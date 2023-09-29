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
    brange = 1:size(breakfast, 1)
    lrange = 1:size(lunch, 1)

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    @variable(model, x[brange], Bin)
    @variable(model, y[lrange], Bin)

    bcalories = sum(breakfast[i, :calories] * x[i] for i in brange)
    lcalories = sum(lunch[i, :calories] * y[i] for i in lrange)
    @constraint(model, bcalories >= mincalories)
    @constraint(model, lcalories >= mincalories)
    @constraint(model, bcalories + lcalories <= maxcalories * 2)

    bprotein = sum(breakfast[i, :protein] * x[i] for i in brange)
    lprotein = sum(lunch[i, :protein] * y[i] for i in lrange)
    @constraint(model, bprotein + lprotein >= 100)

    @objective(model, Min, sum(x[i] for i in brange) + sum(y[i] for i in lrange))

    optimize!(model)

    breakfast[!, "eat"] = [value(x[i]) > 0.5 for i in brange]
    lunch[!, "eat"] = [value(y[i]) > 0.5 for i in lrange]

    return nothing
end

function calculateplan!(lunch)
    range = 1:size(lunch, 1)

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    @variable(model, x[range], Bin)
    @constraint(model, mincalories <= sum(lunch[i, :calories] * x[i] for i in range) <= maxcalories)
    @constraint(model, sum(lunch[i, :protein] * x[i] for i in range) >= 50)
    @objective(model, Min, sum(x[i] for i in range))

    optimize!(model)

    lunch[!, "eat"] = [value(x[i]) > 0.5 for i in range]

    return nothing
end

end