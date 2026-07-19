using Documenter
using Epsilon

makedocs(
    modules = [Epsilon],
    sitename = "Epsilon.jl",
    checkdocs = :exports,
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        size_threshold = 300 * 1024,
    ),
    pages = [
        "Home" => "index.md",
        "Supported Local Workflows" => "supported_paths.md",
        "Public API" => "api.md",
        "Calibration" => "calibration.md",
        "Support Boundaries" => "release.md",
    ],
)

deploydocs(
    repo = "github.com/shawcharles/epsilon.git",
    devbranch = "main",
)
