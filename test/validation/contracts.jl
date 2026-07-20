using CSV
using CairoMakie
using DataFrames
using Dates
using Epsilon
using JSON3
using Random
using Statistics
using Test
using YAML

const _VALIDATION_FIXTURE_ROOT = joinpath(@__DIR__, "..", "fixtures", "golden", "validation")
const _RESPONSE_GRID_FACTORS = [0.25, 0.5, 1.0]
const _OPTIMIZATION_GRID_POINTS = 51

const _PREDICTIVE_SUMMARY_TOLERANCES = Dict(
    "mean" => (atol = 8.0e-2, rtol = 2.0e-1),
    "sd" => (atol = 1.5e-1, rtol = 1.0),
    "q05" => (atol = 3.7e-1, rtol = 3.5e-1),
    "q50" => (atol = 1.2e-1, rtol = 2.5e-1),
    "q95" => (atol = 3.7e-1, rtol = 3.5e-1),
)
const _OPTIMIZATION_SPEND_TOLERANCE = (atol = 1.0e-6, rtol = 1.0e-6)

_validation_case_dir(slug::AbstractString) = joinpath(_VALIDATION_FIXTURE_ROOT, slug)

function _plain_json(value)
    if value isa JSON3.Object
        return Dict(String(key) => _plain_json(item) for (key, item) in pairs(value))
    elseif value isa JSON3.Array
        return [_plain_json(item) for item in value]
    end
    return value
end

function _read_fixture_json(path::AbstractString)
    return _plain_json(JSON3.read(read(path, String)))
end

function _parse_validation_dates(values)
    parsed = DateTime[]
    for value in values
        if value isa Date
            push!(parsed, DateTime(value))
            continue
        elseif value isa DateTime
            push!(parsed, value)
            continue
        end

        string_value = String(value)
        parsed_value = tryparse(Date, string_value)
        if !isnothing(parsed_value)
            push!(parsed, DateTime(parsed_value))
            continue
        end

        parsed_datetime = tryparse(DateTime, string_value)
        isnothing(parsed_datetime) &&
            throw(ArgumentError("could not parse validation date value `$string_value`"))
        push!(parsed, parsed_datetime)
    end

    has_time = any(date -> Time(date) != Time(0), parsed)
    if has_time
        return parsed
    end
    return Date.(parsed)
end

function _panel_key_product(panel_coordinates::Dict{String, Vector{String}}, panel_columns)
    keys = [()]
    for column in panel_columns
        keys = [(key..., value) for key in keys for value in panel_coordinates[column]]
    end
    return keys
end

function _load_validation_time_series_dataset(
        dataset_path::AbstractString,
        config::ModelConfig,
    )
    frame = CSV.read(dataset_path, DataFrame; normalizenames = false)
    parsed_dates = _parse_validation_dates(frame[!, config.date_column])
    order = sortperm(parsed_dates)

    controls = isempty(config.control_columns) ? nothing :
        Matrix{Float64}(frame[order, config.control_columns])

    event_columns = get(config.events, "columns", String[])
    events = isempty(event_columns) ? nothing : Matrix{Float64}(frame[order, event_columns])

    return MMMData(
        dates = parsed_dates[order],
        target = Float64.(frame[order, config.target_column]),
        channels = Matrix{Float64}(frame[order, config.channel_columns]),
        channel_names = copy(config.channel_columns),
        controls = controls,
        control_names = copy(config.control_columns),
        events = events,
        event_names = String.(event_columns),
    )
end

function _load_validation_panel_dataset(
        dataset_path::AbstractString,
        config::ModelConfig,
    )
    frame = CSV.read(dataset_path, DataFrame; normalizenames = false)
    isempty(config.dims) &&
        throw(ArgumentError("panel validation dataset requires a panel dimension"))
    panel_columns = collect(config.dims)
    parsed_dates = _parse_validation_dates(frame[!, config.date_column])
    panel_coordinates = Dict{String, Vector{String}}(
        column => unique(String.(frame[!, column])) for column in panel_columns
    )
    panel_keys = _panel_key_product(panel_coordinates, panel_columns)
    panel_names = [join(Tuple(key), "|") for key in panel_keys]
    date_values = sort(unique(parsed_dates))
    ntime = length(date_values)
    npanels = length(panel_names)
    nchannels = length(config.channel_columns)

    target = Matrix{Float64}(undef, ntime, npanels)
    channels = Array{Float64}(undef, ntime, nchannels, npanels)
    panel_coordinate_columns = Dict{String, Vector{String}}(
        column => String[] for column in panel_columns
    )

    for (panel_index, panel_key) in enumerate(panel_keys)
        panel_mask = trues(nrow(frame))
        for (column, value) in zip(panel_columns, Tuple(panel_key))
            panel_mask .&= String.(frame[!, column]) .== String(value)
            push!(panel_coordinate_columns[column], String(value))
        end
        panel_frame = frame[panel_mask, :]
        panel_dates = _parse_validation_dates(panel_frame[!, config.date_column])
        order = sortperm(panel_dates)
        sorted_dates = panel_dates[order]
        sorted_dates == date_values ||
            throw(
            ArgumentError(
                "panel validation dataset must contain identical sorted dates for each panel",
            ),
        )

        target[:, panel_index] = Float64.(panel_frame[order, config.target_column])
        channels[:, :, panel_index] = Matrix{Float64}(panel_frame[order, config.channel_columns])
    end

    return PanelMMMData(
        dates = date_values,
        target = target,
        channels = channels,
        panel_names = panel_names,
        channel_names = copy(config.channel_columns),
        panel_coordinates = panel_coordinate_columns,
    )
end

function _load_validation_case(case_dir::AbstractString)
    loaded = load_public_config(joinpath(case_dir, "config.yml"))
    dataset_path = joinpath(case_dir, "dataset.csv")
    data = if isempty(loaded.model_config.dims)
        _load_validation_time_series_dataset(dataset_path, loaded.model_config)
    else
        _load_validation_panel_dataset(dataset_path, loaded.model_config)
    end
    return loaded, data
end

function _time_series_validation_model(case_dir::AbstractString)
    loaded, data = _load_validation_case(case_dir)
    data isa MMMData ||
        throw(ArgumentError("time-series validation case requires MMMData"))
    return TimeSeriesMMM(loaded.model_config, loaded.sampler_config, data), loaded
end

function _panel_validation_model(case_dir::AbstractString)
    loaded, data = _load_validation_case(case_dir)
    data isa PanelMMMData ||
        throw(ArgumentError("panel validation case requires PanelMMMData"))
    return PanelMMM(loaded.model_config, loaded.sampler_config, data), loaded
end

function _case_config_metadata(case_id::AbstractString, loaded)
    return Dict(
        "case_id" => String(case_id),
        "model_type" => isempty(loaded.model_config.dims) ? "TimeSeriesMMM" : "PanelMMM",
        "support_row" => case_id == "VAL-TS-04-MCMC" ? "TS-04" :
            case_id == "VAL-P-00-MCMC" ? "P-00" : "TS-00",
        "backend" => "mcmc",
        "random_seed" => something(loaded.sampler_config.random_seed, 0),
        "draws" => loaded.sampler_config.draws,
        "tune" => loaded.sampler_config.tune,
        "chains" => loaded.sampler_config.chains,
    )
end

function _date_type(values)
    isempty(values) && return "Date"
    return first(values) isa DateTime ? "DateTime" : "Date"
end

function _case_dataset_metadata(case_id::AbstractString, data::MMMData, config::ModelConfig)
    return Dict(
        "case_id" => String(case_id),
        "nobs" => length(data.target),
        "nchannels" => length(data.channel_names),
        "has_controls" => !isempty(config.control_columns),
        "has_events" => !isempty(data.event_names) || haskey(config.events, "windows"),
        "has_panel" => false,
        "date_type" => _date_type(data.dates),
    )
end

function _chain_values_by_parameter(chain)
    return Set(String.(names(chain, :parameters)))
end

function _flatten_symbol_values(chain, symbol::Symbol)
    return Epsilon._flatten_chain_values(chain[symbol])
end

function _summary_namedtuple(name::AbstractString, values)
    draws = Float64.(collect(values))
    return (
        parameter = String(name),
        mean = mean(draws),
        sd = std(draws),
        q05 = quantile(draws, 0.05),
        q50 = quantile(draws, 0.5),
        q95 = quantile(draws, 0.95),
    )
end

function _normalized_epsilon_posterior_summary(model::TimeSeriesMMM)
    chain = model.fit_state.artifact.chain
    present = _chain_values_by_parameter(chain)
    rows = NamedTuple[]

    "intercept" in present &&
        push!(rows, _summary_namedtuple("intercept", _flatten_symbol_values(chain, :intercept)))
    "sigma" in present &&
        push!(rows, _summary_namedtuple("sigma", _flatten_symbol_values(chain, :sigma)))

    for (index, channel) in enumerate(model.fit_state.artifact.spec.channel_columns)
        alpha_name = "alpha[$index]"
        alpha_name in present && push!(
            rows,
            _summary_namedtuple(
                "adstock_alpha:$channel",
                _flatten_symbol_values(chain, Symbol(alpha_name)),
            ),
        )

        lam_name = "lam[$index]"
        lam_name in present && push!(
            rows,
            _summary_namedtuple(
                "saturation_lam:$channel",
                _flatten_symbol_values(chain, Symbol(lam_name)),
            ),
        )
    end

    if "beta_seasonality[1]" in present
        fourier_modes = model.fit_state.artifact.spec.coordinate_metadata.coordinates["fourier_mode"]
        for (index, mode) in enumerate(fourier_modes)
            push!(
                rows,
                _summary_namedtuple(
                    "fourier_beta:$mode",
                    _flatten_symbol_values(chain, Symbol("beta_seasonality[$index]")),
                ),
            )
        end
    end

    if "delta_trend[1]" in present
        ntrend = model.fit_state.artifact.runtime.ntrend_terms
        for index in 1:ntrend
            push!(
                rows,
                _summary_namedtuple(
                    "trend_delta:$index",
                    _flatten_symbol_values(chain, Symbol("delta_trend[$index]")),
                ),
            )
        end
    end

    return sort!(DataFrame(rows), :parameter)
end

function _normalized_predictive_summary(chain, nobs_value::Integer)
    matrix = Epsilon._target_draw_matrix(chain, nobs_value)
    rows = NamedTuple[]
    for observation in 1:nobs_value
        draws = Float64.(matrix[:, observation])
        push!(
            rows,
            (
                observation = observation,
                mean = mean(draws),
                sd = std(draws),
                q05 = quantile(draws, 0.05),
                q50 = quantile(draws, 0.5),
                q95 = quantile(draws, 0.95),
            ),
        )
    end
    return DataFrame(rows)
end

function _aggregated_component_samples(results::ContributionResults)
    component_lookup = Dict(
        name => results.values[:, :, index] for
            (index, name) in enumerate(results.component_names)
    )
    aggregated = Dict{String, Matrix{Float64}}()

    haskey(component_lookup, "intercept") &&
        (aggregated["intercept"] = Float64.(component_lookup["intercept"]))

    for name in sort(filter(name -> startswith(name, "media:"), results.component_names))
        aggregated[name] = Float64.(component_lookup[name])
    end

    if any(startswith(name, "event:") for name in results.component_names)
        event_indices = findall(name -> startswith(name, "event:"), results.component_names)
        aggregated["events"] = Float64.(dropdims(sum(results.values[:, :, event_indices]; dims = 3); dims = 3))
    end

    "seasonality" in results.component_names &&
        (aggregated["seasonality"] = Float64.(component_lookup["seasonality"]))
    "trend" in results.component_names &&
        (aggregated["trend"] = Float64.(component_lookup["trend"]))

    return aggregated
end

_mean_vector(values) = collect(Float64.(vec(mean(values; dims = 1))))

function _normalized_postmodel_summary(grouped::InferenceResults)
    contributions = contribution_results(grouped)
    aggregated = _aggregated_component_samples(contributions)
    contribution_means = Dict(
        name => _mean_vector(values) for
            (name, values) in aggregated
    )
    decomposition_totals = Dict(
        name => Float64(mean(sum(values; dims = 2))) for
            (name, values) in aggregated
    )

    channel = sort(copy(grouped.spec.channel_columns))[1]
    observed_total = sum(Float64.(grouped.observed_data.channels[:, grouped.spec.channel_indices[channel]]))
    spend_grid = observed_total .* _RESPONSE_GRID_FACTORS
    curves = response_curve_results(grouped; channel, grid = spend_grid)
    metrics = metric_results(curves)

    metric_lookup = Dict(
        name => _mean_vector(metrics.values[:, :, index]) for
            (index, name) in enumerate(metrics.metric_names)
    )

    return Dict(
        "contribution_component_means" => contribution_means,
        "decomposition_component_totals" => decomposition_totals,
        "response_curve_mean" => Dict(
            "channel" => channel,
            "spend_grid" => Float64.(collect(curves.spend_grid)),
            "mean" => _mean_vector(curves.values),
        ),
        "metric_mean" => Dict(
            "channel" => channel,
            "spend_grid" => Float64.(collect(metrics.spend_grid)),
            "metrics" => metric_lookup,
        ),
    )
end

function _normalized_optimization_summary(grouped::InferenceResults)
    total_budget = sum(Float64.(grouped.observed_data.channels))
    optimization_grid = Dict(
        channel => collect(range(0.0, stop = total_budget, length = _OPTIMIZATION_GRID_POINTS)) for
            channel in grouped.spec.channel_columns
    )
    result = optimize_budget(grouped; total_budget, grid = optimization_grid)
    return Dict(
        "objective_value" => Float64(result.optimized_response),
        "current_total_response" => Float64(result.current_response),
        "optimized_total_response" => Float64(result.optimized_response),
        "channel_current_spend" => Dict(
            channel => Float64(result.current_spend[channel]) for channel in grouped.spec.channel_columns
        ),
        "channel_optimized_spend" => Dict(
            channel => Float64(result.optimized_spend[channel]) for channel in grouped.spec.channel_columns
        ),
        "channel_spend_delta" => Dict(
            channel => Float64(result.optimized_spend[channel] - result.current_spend[channel]) for
                channel in grouped.spec.channel_columns
        ),
    )
end

_nan_aware_isapprox(lhs::Real, rhs::Real; atol::Real, rtol::Real) =
    (isnan(lhs) && isnan(rhs)) || isapprox(lhs, rhs; atol, rtol)

function _compare_summary_table(
        observed::DataFrame,
        expected::DataFrame,
        key::Symbol,
        tolerances::Dict{String, <:NamedTuple},
    )
    sort!(observed, key)
    sort!(expected, key)
    @test observed[!, key] == expected[!, key]

    for (column, tolerance) in tolerances
        for row in 1:nrow(expected)
            @test _nan_aware_isapprox(
                observed[row, Symbol(column)],
                expected[row, Symbol(column)];
                atol = tolerance.atol,
                rtol = tolerance.rtol,
            )
        end
    end
    return
end

function _assert_nested_numeric_values_finite(payload::AbstractDict)
    for value in values(payload)
        if value isa AbstractDict
            _assert_nested_numeric_values_finite(value)
        elseif value isa AbstractVector
            for item in value
                item isa Real && @test isfinite(Float64(item))
            end
        elseif value isa Real
            @test isfinite(Float64(value))
        end
    end
    return
end

function _compare_posterior_parameter_identity(
        observed::DataFrame,
        expected::DataFrame,
    )
    sort!(observed, :parameter)
    sort!(expected, :parameter)
    return @test observed.parameter == expected.parameter
end

function _compare_postmodel_summary(
        observed::AbstractDict{String},
        expected::AbstractDict{String},
    )
    @test sort(collect(keys(observed["contribution_component_means"]))) ==
        sort(collect(keys(expected["contribution_component_means"])))
    @test sort(collect(keys(observed["decomposition_component_totals"]))) ==
        sort(collect(keys(expected["decomposition_component_totals"])))
    _assert_nested_numeric_values_finite(observed["contribution_component_means"])
    _assert_nested_numeric_values_finite(observed["decomposition_component_totals"])

    @test observed["response_curve_mean"]["channel"] == expected["response_curve_mean"]["channel"]
    @test observed["response_curve_mean"]["spend_grid"] == expected["response_curve_mean"]["spend_grid"]
    @test length(observed["response_curve_mean"]["mean"]) ==
        length(expected["response_curve_mean"]["mean"])
    _assert_nested_numeric_values_finite(observed["response_curve_mean"])

    @test observed["metric_mean"]["channel"] == expected["metric_mean"]["channel"]
    @test observed["metric_mean"]["spend_grid"] == expected["metric_mean"]["spend_grid"]
    @test sort(collect(keys(observed["metric_mean"]["metrics"]))) ==
        sort(collect(keys(expected["metric_mean"]["metrics"])))
    return _assert_nested_numeric_values_finite(observed["metric_mean"])
end

function _compare_optimization_summary(
        observed::AbstractDict{String},
        expected::AbstractDict{String},
    )
    for key in ("channel_current_spend", "channel_optimized_spend", "channel_spend_delta")
        @test sort(collect(keys(observed[key]))) == sort(collect(keys(expected[key])))
    end
    for key in ("objective_value", "current_total_response", "optimized_total_response")
        @test observed[key] isa Real
        @test isfinite(Float64(observed[key]))
    end
    current_total_budget = 0.0
    optimized_total_budget = 0.0
    for channel in keys(expected["channel_current_spend"])
        @test _nan_aware_isapprox(
            Float64(observed["channel_current_spend"][channel]),
            Float64(expected["channel_current_spend"][channel]);
            atol = _OPTIMIZATION_SPEND_TOLERANCE.atol,
            rtol = _OPTIMIZATION_SPEND_TOLERANCE.rtol,
        )
        current_total_budget += Float64(observed["channel_current_spend"][channel])
        optimized_total_budget += Float64(observed["channel_optimized_spend"][channel])
        @test isfinite(Float64(observed["channel_optimized_spend"][channel]))
        @test isfinite(Float64(observed["channel_spend_delta"][channel]))
    end
    @test _nan_aware_isapprox(
        current_total_budget,
        optimized_total_budget;
        atol = _OPTIMIZATION_SPEND_TOLERANCE.atol,
        rtol = _OPTIMIZATION_SPEND_TOLERANCE.rtol,
    )
    return @test Float64(observed["optimized_total_response"]) >= Float64(observed["current_total_response"])
end

function _assert_posterior_fixture_schema(expected::DataFrame)
    @test names(expected) == ["parameter", "mean", "sd", "q05", "q50", "q95"]
    @test !isempty(expected)
    for column in ("mean", "sd", "q05", "q50", "q95")
        for value in expected[!, Symbol(column)]
            @test _nan_aware_isapprox(
                Float64(value),
                Float64(value);
                atol = 0.0,
                rtol = 0.0,
            )
        end
    end
    return
end

function _assert_matrix_all_finite(values::AbstractMatrix)
    for value in values
        @test isfinite(Float64(value))
    end
    return
end

@testset "golden fixture rows match compact validation fixtures" begin
    cases = [
        ("VAL-TS-00-MCMC", "ts00_mcmc"),
    ]

    for (case_id, slug) in cases
        @testset "$case_id" begin
            case_dir = _validation_case_dir(slug)
            model, loaded = _time_series_validation_model(case_dir)
            fit!(model)
            Random.seed!(something(loaded.sampler_config.random_seed, 0))
            grouped = inference_results(
                model;
                include_prior = false,
                include_posterior_predictive = true,
                include_prior_predictive = false,
            )

            expected_config_metadata = _read_fixture_json(joinpath(case_dir, "config_metadata.json"))
            expected_dataset_metadata = _read_fixture_json(joinpath(case_dir, "dataset_metadata.json"))
            @test _case_config_metadata(case_id, loaded) == expected_config_metadata
            @test _case_dataset_metadata(case_id, model.data, loaded.model_config) == expected_dataset_metadata

            expected_posterior = CSV.read(joinpath(case_dir, "posterior_summary.csv"), DataFrame)
            _assert_posterior_fixture_schema(expected_posterior)
            observed_posterior = _normalized_epsilon_posterior_summary(model)
            _compare_posterior_parameter_identity(observed_posterior, expected_posterior)

            expected_predictive = CSV.read(joinpath(case_dir, "predictive_summary.csv"), DataFrame)
            @test !isnothing(grouped.posterior_predictive)
            observed_predictive = _normalized_predictive_summary(
                grouped.posterior_predictive,
                grouped.spec.nobs,
            )
            _compare_summary_table(
                observed_predictive,
                expected_predictive,
                :observation,
                _PREDICTIVE_SUMMARY_TOLERANCES,
            )

            expected_postmodel = _read_fixture_json(joinpath(case_dir, "postmodel_summary.json"))
            observed_postmodel = _normalized_postmodel_summary(grouped)
            _compare_postmodel_summary(observed_postmodel, expected_postmodel)

            expected_optimization = _read_fixture_json(joinpath(case_dir, "optimization_summary.json"))
            observed_optimization = _normalized_optimization_summary(grouped)
            _compare_optimization_summary(observed_optimization, expected_optimization)
        end
    end
end

@testset "holiday-bearing native fixture row remains truthful" begin
    case_id = "VAL-TS-04-MCMC"
    case_dir = _validation_case_dir("ts04_mcmc")
    model, loaded = _time_series_validation_model(case_dir)
    fit!(model)
    Random.seed!(something(loaded.sampler_config.random_seed, 0))
    grouped = inference_results(
        model;
        include_prior = false,
        include_posterior_predictive = true,
        include_prior_predictive = false,
    )

    expected_config_metadata = _read_fixture_json(joinpath(case_dir, "config_metadata.json"))
    expected_dataset_metadata = _read_fixture_json(joinpath(case_dir, "dataset_metadata.json"))
    @test _case_config_metadata(case_id, loaded) == expected_config_metadata
    @test _case_dataset_metadata(case_id, model.data, loaded.model_config) == expected_dataset_metadata

    observed_posterior = _normalized_epsilon_posterior_summary(model)
    _assert_posterior_fixture_schema(observed_posterior)

    @test !isnothing(grouped.posterior_predictive)
    observed_predictive = _normalized_predictive_summary(
        grouped.posterior_predictive,
        grouped.spec.nobs,
    )
    @test nrow(observed_predictive) == grouped.spec.nobs
    for column in (:mean, :sd, :q05, :q50, :q95)
        @test all(value -> isfinite(Float64(value)), observed_predictive[!, column])
    end

    contributions = contribution_results(grouped)
    decomposition = decomposition_results(grouped)
    @test "holiday" in contributions.component_names
    @test !any(startswith(name, "holiday:") for name in contributions.component_names)
    @test "holiday" in decomposition.component_names

    channel = sort(copy(grouped.spec.channel_columns))[1]
    observed_total = sum(Float64.(grouped.observed_data.channels[:, grouped.spec.channel_indices[channel]]))
    spend_grid = observed_total .* _RESPONSE_GRID_FACTORS
    response = response_curve_results(grouped; channel, grid = spend_grid)
    saturation = saturation_curve_results(grouped; channel, grid = spend_grid)
    adstock = adstock_curve_results(grouped; channel, grid = spend_grid)
    metrics = metric_results(response)
    optimisation_grid = Dict(
        channel_name =>
            collect(range(0.0, stop = sum(Float64.(grouped.observed_data.channels)), length = _OPTIMIZATION_GRID_POINTS)) for
            channel_name in grouped.spec.channel_columns
    )
    optimisation = optimize_budget(
        grouped;
        total_budget = sum(Float64.(grouped.observed_data.channels)),
        grid = optimisation_grid,
    )

    @test response.channel == channel
    @test saturation.channel == channel
    @test adstock.channel == channel
    @test metrics.channel == channel
    @test response.spend_grid == spend_grid
    @test saturation.spend_grid == spend_grid
    @test adstock.spend_grid == spend_grid
    _assert_matrix_all_finite(response.values)
    _assert_matrix_all_finite(saturation.values)
    _assert_matrix_all_finite(adstock.values)
    _assert_matrix_all_finite(dropdims(sum(metrics.values; dims = 3); dims = 3))
    @test optimisation.optimized_response >= optimisation.current_response
end

@testset "bounded panel contract row remains truthful" begin
    case_dir = _validation_case_dir("p00_mcmc")
    model, loaded = _panel_validation_model(case_dir)
    fit!(model)
    grouped = inference_results(model; include_prior = false, include_prior_predictive = false)

    @test _case_config_metadata("VAL-P-00-MCMC", loaded)["model_type"] == "PanelMMM"
    @test grouped.spec.model_kind == :panel_mmm
    @test !isnothing(grouped.posterior)
    @test size(predict(model), 1) == model.sampler_config.draws
    contributions = contribution_results(grouped)
    @test size(contributions.values) == (
        model.sampler_config.draws,
        length(model.data.dates),
        length(model.data.panel_names),
        length(contributions.component_names),
    )
    @test all(isfinite, contributions.values)
    @test_throws ArgumentError response_curve_results(grouped; channel = "tv", grid = [1.0, 2.0])
    total_budget = sum(Float64.(model.data.channels))
    optimisation = optimize_budget(grouped; total_budget)
    @test optimisation isa PanelBudgetOptimizationResult
    @test optimisation.panel_allocation_mode == :historical_shares
    @test optimisation.optimized_response + 1.0e-6 >= optimisation.current_response
    @test sum(values(optimisation.optimized_spend)) ≈ total_budget
    @test sum(optimisation.optimized_channel_panel_spend; dims = 2)[:] ≈ [
        optimisation.optimized_spend[channel] for channel in optimisation.spec.channel_columns
    ]
end


@testset "bounded pipeline fixture row remains truthful" begin
    case_dir = _validation_case_dir("pipeline_ts00_mcmc")
    config_path = joinpath(case_dir, "config.yml")

    mktempdir() do tmpdir
        result = run_pipeline(
            PipelineRunConfig(
                config_path = config_path,
                output_dir = joinpath(tmpdir, "validation-results"),
                run_name = "contract-validation",
                prior_samples = 12,
                curve_points = 15,
            ),
        )

        @test result.status == :completed
        metadata_record = only(filter(record -> record.key == "metadata", result.stage_records))
        validation_record = only(filter(record -> record.key == "validation", result.stage_records))
        optimisation_record = only(filter(record -> record.key == "optimisation", result.stage_records))
        @test metadata_record.status == :completed
        @test validation_record.status == :completed
        @test optimisation_record.status == :completed

        manifest = _plain_json(JSON3.read(read(result.manifest_path, String)))
        @test manifest["status"] == "completed"
        @test manifest["model_type"] == "TimeSeriesMMM"
        @test manifest["data"]["n_rows"] == 6
        @test manifest["stages"]["validation"]["status"] == "completed"
        @test manifest["stages"]["optimisation"]["status"] == "completed"

        optimisation_stage_dir = joinpath(result.run_dir, "70_optimisation")
        fit_stage_dir = joinpath(result.run_dir, "20_model_fit")
        assessment_stage_dir = joinpath(result.run_dir, "30_model_assessment")
        decomposition_stage_dir = joinpath(result.run_dir, "40_decomposition")
        curves_stage_dir = joinpath(result.run_dir, "60_response_curves")
        @test isfile(joinpath(optimisation_stage_dir, "budget_optimization_result.jls"))
        @test isfile(joinpath(optimisation_stage_dir, "budget_impact.csv"))
        @test isfile(joinpath(optimisation_stage_dir, "budget_bounds_audit.csv"))
        @test isfile(joinpath(optimisation_stage_dir, "budget_optimization.png"))
        @test isfile(joinpath(fit_stage_dir, "trace.png"))
        @test isfile(joinpath(assessment_stage_dir, "observed_fitted.png"))
        @test isfile(joinpath(decomposition_stage_dir, "contributions.png"))
        @test isfile(joinpath(curves_stage_dir, "response_curve_tv.png"))

        bundle_dir = write_plot_bundle(result; output_dir = joinpath(tmpdir, "validation-plots"))
        @test isfile(joinpath(bundle_dir, "diagnostics", "trace.png"))
        @test isfile(joinpath(bundle_dir, "postmodel", "contributions.png"))
        @test isfile(joinpath(bundle_dir, "optimization", "budget_optimization.png"))
    end
end
