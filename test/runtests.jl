using Aqua
using Documenter
using Epsilon
using Test

@testset "Epsilon.jl" begin
    include("basic.jl")
    Aqua.test_all(Epsilon; ambiguities = false)
    doctest(Epsilon; manual = false)
end
