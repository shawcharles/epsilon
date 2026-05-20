using Epsilon
using Test

@testset "control design matrix helpers" begin
    config = Dict{String, Any}("transform" => "standardize")
    controls = [1.0 3.0; 2.0 5.0; 3.0 7.0]

    transformed, state = Epsilon._control_design_matrix(config, controls)
    @test size(transformed) == size(controls)
    @test vec(sum(transformed; dims = 1)) ≈ zeros(2)
    @test state.mean == [2.0, 5.0]
    @test state.scale ≈ [sqrt(2 / 3), sqrt(8 / 3)]

    new_controls = [2.0 4.0; 4.0 8.0]
    applied, reused = Epsilon._control_design_matrix(
        config,
        new_controls;
        control_transform_state = state,
    )
    @test reused == state
    @test applied ≈ (new_controls .- reshape(state.mean, 1, :)) ./ reshape(state.scale, 1, :)

    passthrough, passthrough_state = Epsilon._control_design_matrix(Dict{String, Any}(), controls)
    @test passthrough == controls
    @test isnothing(passthrough_state)
end

@testset "controls config validation" begin
    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        controls = Dict("transform" => "robust"),
    )

    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        controls = Dict("transform" => "standardize"),
    )

    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        control_columns = ["price_index"],
        controls = Dict("transform" => "standardize", "priors" => Any[]),
    )

    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        control_columns = ["price_index"],
        priors = Dict("beta_controls" => EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0)),
    )

    @test_throws ArgumentError ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv"],
        control_columns = ["price_index"],
        priors = Dict("beta_control" => EpsilonPrior("Normal"; mu = 0.0, sigma = 1.0)),
    )
end
