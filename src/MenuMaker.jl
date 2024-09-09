module MenuMaker

using PDFIO
using JuMP
using HiGHS
using ..Config

export makemenu

function makemenu(filename::AbstractString, config::Config.Nutrition)
    file = pdDocOpen(filename)

    pagecount = pdDocGetPageCount(file)

    menu = []
    for i in 1:pagecount
        page = pdDocGetPage(file, i)

        if i != 5
            breakfast, lunch = parsepage(page, config; includebreakfast=true)
            push!(menu, (breakfast=breakfast, lunch=lunch))
        else
            lunch = parsepage(page, config; includebreakfast=false)
            push!(menu, (breakfast=nothing, lunch=lunch))
        end
    end

    return menu
end

function parsepage(page::PDPage, config::Config.Nutrition; includebreakfast=true)
    text = sprint(pdPageExtractText, page)

    text = replace(text, r"[\n ]{2,}" => ";", "," => ".")

    lunch = match(r"ОБЕД;(.*);ПОЛДНИК", text)[1]
    lunch = parsefoods(lunch, config)

    if includebreakfast
        breakfast = match(r"ЗАВТРАК;(.*);ОБЕД", text)[1]
        breakfast = parsefoods(breakfast, config)

        return calculateplan(breakfast, lunch, config)
    else
        return calculateplan(lunch, config)
    end
end

const foodpattern = r"([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+);?([^\d;]+);\d+ руб\.[; ]?(\d+) (?>гр|мл)\."
function parsefoods(menu, config::Config.Nutrition)
    foods = NamedTuple[]
    for match in eachmatch(foodpattern, menu)
        food = makefood(match.captures)
        if !(food.name in config.blacklist)
            push!(foods, food)
        end
    end
    return foods
end

function makefood(captures::Vector)
    values = map(x -> something(tryparse(Float64, x), x), captures)

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

function calculateplan(breakfast, lunch, config::Config.Nutrition)
    breakfast_range = 1:size(breakfast, 1)
    lunch_range = 1:size(lunch, 1)

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    @variable(model, x[breakfast_range], Bin)
    @variable(model, y[lunch_range], Bin)

    breakfast_calories = sum(breakfast[i].calories * x[i] for i in breakfast_range)
    lunch_calories = sum(lunch[i].calories * y[i] for i in lunch_range)
    @constraint(model, breakfast_calories >= config.calories_range[1])
    @constraint(model, lunch_calories >= config.calories_range[1])
    @constraint(model, breakfast_calories + lunch_calories <= config.calories_range[2] * 2)

    @constraint(model, sum(breakfast[i].meat * x[i] for i in breakfast_range) <= 2)
    @constraint(model, sum(lunch[i].meat * y[i] for i in lunch_range) <= 2)

    bprotein = sum(breakfast[i].protein * x[i] for i in breakfast_range)
    lprotein = sum(lunch[i].protein * y[i] for i in lunch_range)
    @constraint(model, bprotein + lprotein >= config.min_protein * 2)

    @objective(model, Min, sum(x) + sum(y))

    optimize!(model)

    return breakfast[filter(i -> value(x[i]) > 0.5, 1:end)], lunch[filter(i -> value(y[i]) > 0.5, 1:end)]
end

function calculateplan(lunch, config::Config.Nutrition)
    range = 1:size(lunch, 1)

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    @variable(model, x[range], Bin)
    @constraint(model, config.calories_range[1] <= sum(lunch[i].calories * x[i] for i in range) <= config.calories_range[2])
    @constraint(model, sum(lunch[i].meat * x[i] for i in range) <= 2)
    @constraint(model, sum(lunch[i].protein * x[i] for i in range) >= config.min_protein)
    @objective(model, Min, sum(x))

    optimize!(model)

    return lunch[filter(i -> value(x[i]) > 0.5, 1:end)]
end

end
