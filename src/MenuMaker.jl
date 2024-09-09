module MenuMaker

using PDFIO
using JuMP
using HiGHS
using ..Config

export makemenu

function makemenu(filename::AbstractString, config::Config.AutoMenu)
    file = pdDocOpen(filename)

    pagecount = pdDocGetPageCount(file)

    menu = []
    for i in 1:pagecount
        if i ∉ config.schedule.breakfast_days && i ∉ config.schedule.lunch_days
            continue
        end

        page = pdDocGetPage(file, i)

        breakfast, lunch = parsepage(page, config.nutrition)

        if i ∉ config.schedule.breakfast_days
            breakfast = []
        end
        if i ∉ config.schedule.lunch_days
            lunch = []
        end

        breakfast, lunch = calculateplan(breakfast, lunch, config.nutrition)

        push!(menu, (breakfast=breakfast, lunch=lunch))
    end

    return menu
end

function parsepage(page::PDPage, config::Config.Nutrition)
    text = sprint(pdPageExtractText, page)

    text = replace(text, r"[\n ]{2,}" => ";", "," => ".")

    breakfast = match(r"ЗАВТРАК;(.*);ОБЕД", text)[1]
    breakfast = parsefoods(breakfast, config)

    lunch = match(r"ОБЕД;(.*);ПОЛДНИК", text)[1]
    lunch = parsefoods(lunch, config)

    return breakfast, lunch
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
    model = Model(HiGHS.Optimizer)
    set_silent(model)

    include_breakfast = !isempty(breakfast)
    include_lunch = !isempty(lunch)

    meal_count = include_breakfast + include_lunch

    breakfast_dishes, breakfast_calories, breakfast_protein = add_meal_constraints(model, breakfast, config)
    lunch_dishes, lunch_calories, lunch_protein = add_meal_constraints(model, lunch, config)

    @constraint(model, breakfast_calories + lunch_calories <= config.calories_range[2] * meal_count)
    @constraint(model, breakfast_protein + lunch_protein >= config.min_protein * meal_count)

    @objective(model, Min, sum(breakfast_dishes) + sum(lunch_dishes))

    optimize!(model)

    breakfast = breakfast[filter(i -> value(breakfast_dishes[i]) > 0.5, 1:end)]
    lunch = lunch[filter(i -> value(lunch_dishes[i]) > 0.5, 1:end)]
    return breakfast, lunch
end

function add_meal_constraints(model, meal, config)
    if isempty(meal)
        return [0], 0, 0
    end

    meal_range = 1:size(meal, 1)

    dishes = @variable(model, [meal_range], Bin)

    meal_calories = sum(meal[i].calories * dishes[i] for i in meal_range)
    meal_protein = sum(meal[i].protein * dishes[i] for i in meal_range)

    @constraint(model, meal_calories >= config.calories_range[1])
    @constraint(model, sum(meal[i].meat * dishes[i] for i in meal_range) <= 2)

    return dishes, meal_calories, meal_protein
end

end
