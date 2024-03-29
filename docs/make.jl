cd(@__DIR__)

using ProcessBasedModelling

import Downloads
Downloads.download(
    "https://raw.githubusercontent.com/JuliaDynamics/doctheme/master/build_docs_with_style.jl",
    joinpath(@__DIR__, "build_docs_with_style.jl")
)
include("build_docs_with_style.jl")

pages =  [
    "Documentation" => "index.md",
]

build_docs_with_style(pages, ProcessBasedModelling;
    authors = "George Datseris <datseris.george@gmail.com>",
)
