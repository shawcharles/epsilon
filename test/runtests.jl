using Aqua
using Documenter
using Epsilon
using Test

@testset "Epsilon.jl" begin
    include("basic.jl")
    include("distributions/runtests.jl")
    include("model/runtests.jl")
    include("inference/runtests.jl")
    include("postmodel/runtests.jl")
    include("optimization/runtests.jl")
    include("scenario_planner.jl")
    include("pipeline/runtests.jl")
    include("plotting/runtests.jl")
    include("validation/runtests.jl")
    include("transforms/runtests.jl")
    Aqua.test_all(Epsilon; ambiguities = false)
    doctest(Epsilon; manual = false)
end
