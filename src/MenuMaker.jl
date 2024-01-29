module MenuMaker

using PDFIO
using JuMP
using HiGHS

export makemenu

const blacklist = ["Сарделька из мяса птицы", "Сыр", "Запечённая индейка", "Сосиска из мяса птицы"]
const mincalories = 600
const maxcalories = 700
const minprotein = 35

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

    lunch = match(r"ОБЕД;(.*);ПОЛДНИК", text)[1] |> parsefoods

    if includebreakfast
        breakfast = match(r"ЗАВТРАК;(.*);ОБЕД", text)[1] |> parsefoods

        return calculateplan(breakfast, lunch)
    else
        return calculateplan(lunch)
    end
end

const foodpattern = r"([^\d;]+)[; ]?([\d.]+);([\d.]+);([\d.]+);([\d.]+);\d+ руб\.;?(\d+) гр\.;|([\d.]+);([\d.]+);([\d.]+);([\d.]+)[; ]?([^\d;]+);\d+ руб\.[; ]?(\d+) гр\.;"
function parsefoods(menu)
    foods = NamedTuple[]
    for match in eachmatch(foodpattern, menu)
        food = makefood(match.captures)
        if !(food.name in blacklist)
            push!(foods, food)
        end
    end
    return foods
end

function makefood(captures::Vector)
    if isnothing(captures[7])
        values = map(x -> something(tryparse(Float64, x), x), captures[1:6])

        size = values[6] / 100
        return (
            name=values[1],
            calories=values[2] * size,
            protein=values[3] * size,
            fat=values[4] * size,
            carbs=values[5] * size,
            meat=ismeat(values[1])
        )
    else
        values = map(x -> something(tryparse(Float64, x), x), captures[7:12])

        size = values[6] / 100
        return (
            name=values[5],
            calories=values[1] * size,
            protein=values[2] * size,
            fat=values[3] * size,
            carbs=values[4] * size,
            meat=ismeat(values[5])
        )
    end
end

const meat_words = [
    "котлета",
    "филе",
    "стейк",
    "терияки",
    "печень",
    "печёночные",
    "треска",
    "бифштекс",
    "рыбные палочки",
    "котлет",
    "сайда",
    "чахохбили",
    "бефстроганов",
    "наггетсы",
    "гуляш",
    "тефтели",
    "форель",
    "куриц",
    "судак",
    "грудка",
    "индейки",
    "говядин",
]
function ismeat(name)
    lname = lowercase(name)
    for word in meat_words
        if occursin(word, lname)
            return true
        end
    end
    return false
end

function calculateplan(breakfast, lunch)
    breakfast_range = 1:size(breakfast, 1)
    lunch_range = 1:size(lunch, 1)

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    @variable(model, x[breakfast_range], Bin)
    @variable(model, y[lunch_range], Bin)

    breakfast_calories = sum(breakfast[i].calories * x[i] for i in breakfast_range)
    lunch_calories = sum(lunch[i].calories * y[i] for i in lunch_range)
    @constraint(model, breakfast_calories >= mincalories)
    @constraint(model, lunch_calories >= mincalories)
    @constraint(model, breakfast_calories + lunch_calories <= maxcalories * 2)

    @constraint(model, sum(breakfast[i].meat * x[i] for i in breakfast_range) <= 2)
    @constraint(model, sum(lunch[i].meat * y[i] for i in lunch_range) <= 2)

    bprotein = sum(breakfast[i].protein * x[i] for i in breakfast_range)
    lprotein = sum(lunch[i].protein * y[i] for i in lunch_range)
    @constraint(model, bprotein + lprotein >= minprotein * 2)

    @objective(model, Min, sum(x) + sum(y))

    optimize!(model)

    return breakfast[filter(i -> value(x[i]) > 0.5, 1:end)], lunch[filter(i -> value(y[i]) > 0.5, 1:end)]
end

function calculateplan(lunch)
    range = 1:size(lunch, 1)

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    @variable(model, x[range], Bin)
    @constraint(model, mincalories <= sum(lunch[i].calories * x[i] for i in range) <= maxcalories)
    @constraint(model, sum(lunch[i].meat * x[i] for i in range) <= 2)
    @constraint(model, sum(lunch[i].protein * x[i] for i in range) >= minprotein)
    @objective(model, Min, sum(x))

    optimize!(model)

    return lunch[filter(i -> value(x[i]) > 0.5, 1:end)]
end

end
