using Test

include(joinpath(@__DIR__, "..", "..", "examples", "toy_mmm", "run_toy_mmm.jl"))

@testset "toy MMM MCMC smoke demo" begin
    mktempdir() do output_dir
        result = run_toy_mmm(;
            draws = 8,
            tune = 8,
            seed = 20260706,
            output_dir = output_dir,
            verbose = false,
        )

        @test result.state.status == :fit
        @test result.state.backend == :turing
        @test result.model.sampler_config.draws == 8
        @test result.model.sampler_config.tune == 8
        @test result.model.sampler_config.chains == 1
        @test result.model.sampler_config.cores == 1
        @test result.model.sampler_config.progressbar == false
        @test result.model.sampler_config.compute_convergence_checks == false
        @test !isnothing(result.grouped.posterior)
        @test isnothing(result.grouped.prior)
        @test isnothing(result.grouped.posterior_predictive)
        @test isnothing(result.grouped.prior_predictive)
        @test result.grouped.observed_data === result.model.data
        @test size(result.grouped.posterior, 1) == 8
        @test :intercept in result.grouped.posterior.name_map.parameters
        @test Symbol("beta_media[1]") in result.grouped.posterior.name_map.parameters
        @test size(result.contribution_table, 1) > 0
        @test size(result.metric_table, 1) > 0
        @test haskey(result.written_paths, :contribution_summary)
        @test haskey(result.written_paths, :metric_summary)
        @test haskey(result.written_paths, :run_summary)

        for path in values(result.written_paths)
            @test isfile(path)
            @test filesize(path) > 0
        end
    end
end
