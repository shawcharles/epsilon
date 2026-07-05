using Documenter
using Epsilon

makedocs(
    modules = [Epsilon],
    sitename = "Epsilon.jl",
    format = Documenter.HTML(; prettyurls = get(ENV, "CI", "false") == "true"),
    pages = [
        "Home" => "index.md",
        "Calibration" => "calibration.md",
        "Release Gate" => "release.md",
        "Benchmarks" => "benchmarks.md",
    ],
)

deploydocs(
    repo = "github.com/shawcharles/epsilon.git",
    devbranch = "main",
)
