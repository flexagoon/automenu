using PDFIO

file = pdDocOpen("menu.pdf")

pages = pdDocGetPageCount(file)

page = pdDocGetPage(file, 1)
text = sprint(pdPageExtractText, page)

text = replace(text, r"[\n ]{2,}" => ";")

breakfast = match(r"ЗАВТРАК;(.*);ОБЕД", text)[1]
lunch = match(r"ОБЕД;(.*);ПОЛДНИК", text)[1]

const meals = r"([^\d;]+);([\d,]+);([\d,]+);([\d,]+);([\d,]+);\d+ руб.;(\d+) гр\.;|([\d,]+);([\d,]+);([\d,]+);([\d,]+);([^\d;]+);\d+ руб.;(\d+) гр\.;"

breakfastmeals = eachmatch(meals, breakfast)
for meal in breakfastmeals
    if isnothing(meal[7])
        println("$(meal[1]): $(meal[2]) ккал, $(meal[3]) Б, $(meal[4]) Ж, $(meal[5]) У, $(meal[6]) гр.")
    else
        println("$(meal[11]): $(meal[7]) ккал, $(meal[8]) Б, $(meal[9]) Ж, $(meal[10]) У, $(meal[12]) гр.")
    end
end
