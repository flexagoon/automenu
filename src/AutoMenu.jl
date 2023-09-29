include("MenuMaker.jl")
include("GoogleDrive.jl")

using .MenuMaker
using .GoogleDrive

total_nutrition(::Nothing, lunch) = sum(lunch.calories), sum(lunch.protein)
total_nutrition(breakfast, lunch) = sum(breakfast.calories) + sum(lunch.calories), sum(breakfast.protein) + sum(lunch.protein)

GoogleDrive.download("1d9p3y0gJz6YDLn2kjkzjFIGvx2NX8JNX", "menu.pdf")
menu = makemenu("menu.pdf")

for day in menu
    println("=================================")

    calories, protein = total_nutrition(day.breakfast, day.lunch)
    println("$calories ккал")
    println("$protein г. Б")

    if !isnothing(day.breakfast)
        println()
        println("ЗАВТРАК")
        for food in eachrow(day.breakfast)
            println(food.name)
        end
    end

    println()
    println("ОБЕД")
    for food in eachrow(day.lunch)
        println(food.name)
    end
end