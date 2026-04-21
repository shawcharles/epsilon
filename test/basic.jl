using Test
using Epsilon

@testset "version" begin
    @test Epsilon.epsilon_version() isa VersionNumber
end
