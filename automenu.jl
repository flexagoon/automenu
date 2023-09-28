using PDFIO
using DataFrames

const foodpattern = r"([^\d;]+);([\d.]+);([\d.]+);([\d.]+);([\d.]+);\d+ руб.;(\d+) гр\.;|([\d.]+);([\d.]+);([\d.]+);([\d.]+);([^\d;]+);\d+ руб.;(\d+) гр\.;"
function parsefoods(menu)
    matches = eachmatch(foodpattern, menu)

    foods = DataFrame()
    for match in matches
        match = match.captures
        if isnothing(match[7])
            @show match = map(x -> something(tryparse(Float64, x), x), match[1:6])

            size = match[6] / 100
            push!(foods, (
                name=match[1],
                calories=match[2] * size,
                protein=match[3] * size,
                fat=match[4] * size,
                carbs=match[5] * size
            ))
        else
            match = map(x -> something(tryparse(Float64, x), x), match[7:12])

            size = match[6] / 100
            push!(foods, (
                name=match[5],
                calories=match[1] * size,
                protein=match[2] * size,
                fat=match[3] * size,
                carbs=match[4] * size
            ))
        end
    end

    return foods
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
