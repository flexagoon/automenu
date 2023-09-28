using PDFIO
using DataFrames
using JuMP
using HiGHS

const foodpattern = r"([^\d;]+);([\d.]+);([\d.]+);([\d.]+);([\d.]+);\d+ руб.;(\d+) гр\.;|([\d.]+);([\d.]+);([\d.]+);([\d.]+);([^\d;]+);\d+ руб.;(\d+) гр\.;"
const blacklist = ["Сарделька из мяса птицы", "Сыр", "Запечённая индейка"]
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

function calculateamounts!(breakfast, lunch)
    brange = 1:size(breakfast, 1)
    lrange = 1:size(lunch, 1)

    model = Model(HiGHS.Optimizer)
    set_silent(model)

    @variable(model, x[brange], Bin)
    @variable(model, y[lrange], Bin)

    bcalories = sum(breakfast[i, :calories] * x[i] for i in brange)
    lcalories = sum(lunch[i, :calories] * y[i] for i in lrange)
    @constraint(model, bcalories >= 700)
    @constraint(model, lcalories >= 700)
    @constraint(model, bcalories + lcalories <= 1800)

    bprotein = sum(breakfast[i, :protein] * x[i] for i in brange)
    lprotein = sum(lunch[i, :protein] * y[i] for i in lrange)
    @objective(model, Max, bprotein + lprotein)

    optimize!(model)

    breakfast[!, "amount"] = [value(x[i]) for i in brange]
    lunch[!, "amount"] = [value(y[i]) for i in lrange]
end

file = pdDocOpen("menu.pdf")

pages = pdDocGetPageCount(file)

page = pdDocGetPage(file, 1)
text = sprint(pdPageExtractText, page)

text = replace(text, r"[\n ]{2,}" => ";", "," => ".")

breakfast = match(r"ЗАВТРАК;(.*);ОБЕД", text)[1]
lunch = match(r"ОБЕД;(.*);ПОЛДНИК", text)[1]

breakfast = parsefoods(breakfast)
lunch = parsefoods(lunch)

calculateamounts!(breakfast, lunch)