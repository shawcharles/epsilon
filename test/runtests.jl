using Aqua
using Documenter
using Epsilon
using Test

@testset "Epsilon.jl" begin
    include("basic.jl")
    include("distributions/runtests.jl")
    include("model/runtests.jl")
    include("transforms/runtests.jl")
    Aqua.test_all(Epsilon; ambiguities = false)
    doctest(Epsilon; manual = false)
end
