include("MenuMaker.jl")
include("GoogleDrive.jl")

using .MenuMaker
using .GoogleDrive

GoogleDrive.download("1d9p3y0gJz6YDLn2kjkzjFIGvx2NX8JNX", "menu.pdf")
menu = makemenu("menu.pdf")