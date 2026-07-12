using Dates
using Epsilon
import MCMCChains
using Test
import Turing

function _hsgp_contribution_replay_results(; data_override = nothing, parameter_names = nothing)
    config = ModelConfig(
        date_column = "date",
        target_column = "revenue",
        channel_columns = ["tv", "search"],
        control_columns = ["price"],
        time_varying_media = TimeVaryingMediaConfig(
            m = 2,
            L = 6.0,
            time_resolution = 7,
            eta_prior = EpsilonPrior("Exponential"; lam = 1.5),
            lengthscale_prior = EpsilonPrior("LogNormal"; mu = 0.0, sigma = 0.4),
        ),
    )
    training_data = MMMData(
        dates = Date[Date(2024, 1, 1), Date(2024, 1, 8), Date(2024, 1, 15)],
        target = [10.0, 12.0, 14.0],
        channels = [1.0 2.0; 2.0 3.0; 4.0 1.0],
        channel_names = ["tv", "search"],
        controls = reshape([0.5, 1.0, 1.5], :, 1),
        control_names = ["price"],
    )
    spec = build_model(
        TimeSeriesMMM(
            config,
            SamplerConfig(draws = 2, tune = 0, chains = 1, cores = 1),
            training_data,
        ),
    )
    names = isnothing(parameter_names) ? Symbol[
            :intercept,
            :sigma,
            Symbol("beta_media[1]"),
            Symbol("beta_media[2]"),
            Symbol("beta_controls[1]"),
            :hsgp_media_eta,
            :hsgp_media_lengthscale,
            Symbol("hsgp_media_z[1]"),
            Symbol("hsgp_media_z[2]"),
        ] : parameter_names
    draw_values = [
        0.4 0.7 0.3 0.8 -0.2 1.1 2.0 -0.4 0.2
        0.6 0.9 0.5 0.4 0.1 0.7 1.3 0.3 -0.5
    ]
    selected_indices = [
        findfirst(
                ==(name), Symbol[
                    :intercept,
                    :sigma,
                    Symbol("beta_media[1]"),
                    Symbol("beta_media[2]"),
                    Symbol("beta_controls[1]"),
                    :hsgp_media_eta,
                    :hsgp_media_lengthscale,
                    Symbol("hsgp_media_z[1]"),
                    Symbol("hsgp_media_z[2]"),
                ]
            ) for name in names
    ]
    chain = MCMCChains.Chains(reshape(draw_values[:, selected_indices], 2, length(names), 1), names)
    data = isnothing(data_override) ? training_data : data_override
    results = InferenceResults(
        Epsilon._artifact_metadata("TimeSeriesMMM"; backend = :fixture, fit_status = :fit),
        spec;
        posterior = chain,
        observed_data = data,
    )
    return (; results, spec, data, draw_values)
end

function _hsgp_contribution_component_index(results, name)
    index = findfirst(==(name), results.component_names)
    isnothing(index) && error("missing HSGP contribution component $name")
    return index
end

@testset "HSGP time-series contribution replay" begin
    fixture = _hsgp_contribution_replay_results()
    contributions = contribution_results(fixture.results)
    decomposition = decomposition_results(fixture.results)
    state = fixture.spec.priors["_hsgp_media_spec_state"]
    scaled_channels = Epsilon._scale_channels(fixture.data.channels, fixture.spec.channel_scale)
    scaled_target = fixture.data.target ./ fixture.spec.target_scale
    runtime, controls = Epsilon._turing_runtime(fixture.spec, fixture.data)
    turing_model = Epsilon._time_series_mmm_model(
        scaled_target,
        scaled_channels,
        controls,
        nothing,
        nothing,
        runtime,
    )
    target_scale = fixture.spec.target_scale
    tv_index = _hsgp_contribution_component_index(contributions, "media:tv")
    search_index = _hsgp_contribution_component_index(contributions, "media:search")
    control_index = _hsgp_contribution_component_index(contributions, "control:price")

    @test contributions.component_kinds == [:intercept, :media, :media, :control]
    @test size(contributions.values) == (2, 3, 4)

    for draw in 1:2
        parameters = fixture.draw_values[draw, :]
        multiplier = Epsilon._hsgp_media_multiplier(
            state,
            collect(state.training.training_indices),
            parameters[6],
            parameters[7],
            parameters[8:9],
        )
        expected_tv = scaled_channels[:, 1] .* parameters[3] .* multiplier .* target_scale
        expected_search = scaled_channels[:, 2] .* parameters[4] .* multiplier .* target_scale
        expected_control = fixture.data.controls[:, 1] .* parameters[5] .* target_scale
        conditioned = Turing.DynamicPPL.condition(
            turing_model,
            (
                intercept = parameters[1],
                sigma = parameters[2],
                beta_media = parameters[3:4],
                beta_controls = [parameters[5]],
                hsgp_media_eta = parameters[6],
                hsgp_media_lengthscale = parameters[7],
                hsgp_media_z = parameters[8:9],
            ),
        )
        returned, _ = Turing.DynamicPPL.evaluate!!(
            conditioned,
            Turing.DynamicPPL.VarInfo(conditioned),
        )

        @test contributions.values[draw, :, tv_index] ≈ expected_tv atol = 1.0e-12 rtol = 1.0e-12
        @test contributions.values[draw, :, search_index] ≈ expected_search atol = 1.0e-12 rtol = 1.0e-12
        @test contributions.values[draw, :, control_index] ≈ expected_control atol = 1.0e-12 rtol = 1.0e-12
        @test vec(sum(contributions.values[draw, :, :]; dims = 2)) ≈
            returned.mu .* target_scale atol = 1.0e-12 rtol = 1.0e-12
    end

    @test decomposition.totals ≈ dropdims(sum(contributions.values; dims = 2); dims = 2)
end

@testset "HSGP contribution replay rejects unsupported posterior and date state" begin
    fixture = _hsgp_contribution_replay_results()
    required_names = Symbol.(MCMCChains.names(fixture.results.posterior, :parameters))
    for missing_name in (
            :hsgp_media_eta,
            :hsgp_media_lengthscale,
            Symbol("hsgp_media_z[1]"),
            Symbol("hsgp_media_z[2]"),
        )
        missing_fixture = _hsgp_contribution_replay_results(
            parameter_names = filter(!=(missing_name), required_names),
        )
        @test_throws ArgumentError contribution_results(missing_fixture.results)
    end

    malformed = _hsgp_contribution_replay_results()
    malformed.spec.priors["_hsgp_media_spec_state"] = :corrupt
    @test_throws ArgumentError contribution_results(malformed.results)

    for dates in (
            [1, 2, 3],
            Date[Date(2024, 1, 1), Date(2024, 1, 9), Date(2024, 1, 15)],
            Date[Date(2024, 1, 1), Date(2024, 1, 8), Date(2024, 1, 15), Date(2024, 1, 22)],
            Date[Date(2024, 1, 8), Date(2024, 1, 1), Date(2024, 1, 15)],
            Date[Date(2024, 1, 1), Date(2024, 1, 8), Date(2024, 1, 8)],
            Date[Date(2024, 1, 1), Date(2024, 1, 15), Date(2024, 1, 29)],
        )
        data = MMMData(
            dates = dates,
            target = fill(10.0, length(dates)),
            channels = ones(length(dates), 2),
            channel_names = ["tv", "search"],
            controls = ones(length(dates), 1),
            control_names = ["price"],
        )
        mismatched = _hsgp_contribution_replay_results(; data_override = data)
        @test_throws ArgumentError contribution_results(mismatched.results)
    end
end
