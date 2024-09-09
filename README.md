# AutoMenu

## About

This is a personal script I wrote to automatically generate daily meal plans for
myself. It fetches the data from my school cafeteria menu for the week and
generates a meal plan according to the following parameters:

1. 600-700 kcal per meal
2. At least 70 grams of protein per breakfast and lunch combined
3. No more than 2 meat dishes per meal
4. As little separate dishes as possible while fitting the above criteria

## Implementation

### Downloading the menu

My school provides the menu as a pdf on a Google Drive folder. The actual file
and its URL changes every week, however, the folder URL stays the same. Because
of this, I am able to get the HTML of the folder and extract the file id with a
simple regular expression. After that, I can just download the pdf file.
Apparently, Google Drive used to require some cookie manipulation to download
files through code, but now it no longer needs that, and it can be done through
a simple request.

The very short code that does this can be found in
[src/GoogleDrive.jl](src/GoogleDrive.jl).

### Parsing the PDF

Since the menu is only available as a PDF, the only data that can be extracted
from it is an extremely messy plaintext string with no clear delimeters between
different data fields. I rely on a [really hacky
regex](https://github.com/flexagoon/automenu/blob/c33924ea34e3e6e265c458b36e673a20a1a0811c/src/MenuMaker.jl#L54)
to parse the contents of a PDF into named tuples that I can use for further
processing.

### Generating the meal plan

To optimize a mathematical model according to given constraints, you need to use
a linear solver. I use [JuMP](https://jump.dev/) as an abstraction above the
[HiGHS solver](https://highs.dev/). JuMP is an extremely convenient library that
allows me to specify all of my requirements as a bunch of simple `@constraint`
and `@objective` macros instead of actually figuring out linear equations. See
[this
section](https://jump.dev/JuMP.jl/stable/background/algebraic_modeling_languages)
of JuMP docs for more information.

## Skills 

Here are the main skills I acquired while working on this:

1. Julia

    This was my first experience with the [Julia programming
    language](https://julialang.org/). I loved the language and will definitely use
    it for other projects in the future.

2. Linear programming

    While I didn't really learn the actual mathematical side of it due to using
    JuMP, making this made me understand how powerful of a tool it is. Perhaps I'll
    actually try to learn the maths behind it.
