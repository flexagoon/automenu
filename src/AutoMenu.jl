#!/usr/bin/env -S julia --project=.

module AutoMenu

include("Config.jl")
include("MenuMaker.jl")
include("GoogleDrive.jl")
include("Notifier.jl")

using .Config
using .MenuMaker
using .GoogleDrive
using .Notifier

const config = Config.load("config.toml")

function total_nutrition(breakfast, lunch)
    dishes = vcat(breakfast, lunch)
    calories = sum(dish -> dish.calories, dishes; init=0)
    protein = sum(dish -> dish.protein, dishes; init=0)
    return round(calories; digits=2), round(protein; digits=2)
end

println("Downloading menu...")

GoogleDrive.download("1d9p3y0gJz6YDLn2kjkzjFIGvx2NX8JNX", "menu.pdf")

println("Generating meal plan...")
menu = makemenu("menu.pdf", config)

plan = IOBuffer()
for day in menu
    println(plan, "=================================")

    calories, protein = total_nutrition(day.breakfast, day.lunch)
    println(plan, "$calories ккал")
    println(plan, "$protein г. Б")

    if !isempty(day.breakfast)
        println(plan)
        println(plan, "ЗАВТРАК")
        for food in day.breakfast
            println(plan, food.name)
        end
    end

    if !isempty(day.lunch)
        println(plan)
        println(plan, "ОБЕД")
        for food in day.lunch
            println(plan, food.name)
        end
    end
end

plan = String(take!(plan))
print(plan)

println("Sending to Telegram...")
Notifier.notify(plan, config.notifier)

end
