#!/usr/bin/env -S julia --project=.

include("MenuMaker.jl")
include("GoogleDrive.jl")
include("Notifier.jl")

using .MenuMaker
using .GoogleDrive
using .Notifier

total_nutrition(::Nothing, lunch) = sum(lunch -> lunch.calories, lunch), sum(lunch -> lunch.protein, lunch)
total_nutrition(breakfast, lunch) = sum(b -> b.calories, breakfast) + sum(lunch -> lunch.calories, lunch), sum(b -> b.protein, breakfast) + sum(lunch -> lunch.protein, lunch)

println("Downloading menu...")

GoogleDrive.download("1d9p3y0gJz6YDLn2kjkzjFIGvx2NX8JNX", "menu.pdf")

println("Generating meal plan...")
menu = makemenu("menu.pdf")

plan = IOBuffer()
for day in menu
    println(plan, "=================================")

    calories, protein = total_nutrition(day.breakfast, day.lunch)
    println(plan, "$calories ккал")
    println(plan, "$protein г. Б")

    if !isnothing(day.breakfast)
        println(plan)
        println(plan, "ЗАВТРАК")
        for food in day.breakfast
            println(plan, food.name)
        end
    end

    println(plan)
    println(plan, "ОБЕД")
    for food in day.lunch
        println(plan, food.name)
    end
end

plan = String(take!(plan))
print(plan)

println("Sending to Telegram...")
Notifier.notify(plan)
