include("MenuMaker.jl")
include("GoogleDrive.jl")

using .MenuMaker
using .GoogleDrive

total_nutrition(::Nothing, lunch) = sum(lunch -> lunch.calories, lunch), sum(lunch -> lunch.protein, lunch)
total_nutrition(breakfast, lunch) = sum(b -> b.calories, breakfast) + sum(lunch -> lunch.calories, lunch), sum(b -> b.protein, breakfast) + sum(lunch -> lunch.protein, lunch)

println("Downloading menu...")

GoogleDrive.download("1d9p3y0gJz6YDLn2kjkzjFIGvx2NX8JNX", "menu.pdf")

println("Generating meal plan...")
menu = makemenu("menu.pdf")

for day in menu
    println("=================================")

    calories, protein = total_nutrition(day.breakfast, day.lunch)
    println("$calories ккал")
    println("$protein г. Б")

    if !isnothing(day.breakfast)
        println()
        println("ЗАВТРАК")
        for food in day.breakfast
            println(food.name)
        end
    end

    println()
    println("ОБЕД")
    for food in day.lunch
        println(food.name)
    end
end
