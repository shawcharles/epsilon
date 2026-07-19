"""
Calibration and lift-test schema, alignment, scaling, and likelihood-term
helpers.

This module defines Epsilon's bounded calibration surface: row-to-coordinate
alignment, lift-test monotonicity validation, channel and target rescaling for
lift-test data, mean/standard-deviation to `Distributions.Gamma` `shape`/`scale`
reparameterization, lift-test likelihood helpers, and cost-per-target
soft-penalty calculations.
"""

using Distributions

const _SUPPORTED_CALIBRATION_METHODS = Set(
    (
        "add_cost_per_target_calibration",
        "add_lift_test_measurements",
    )
)

const _REQUIRED_LIFT_TEST_COLUMNS = Set(("x", "delta_x", "delta_y", "sigma"))

function _finite_float_vector(values::AbstractVector{<:Real}, name::AbstractString)
    vector = Float64.(collect(values))
    all(isfinite, vector) || throw(ArgumentError("$(name) must contain only finite values"))
    return vector
end

function _positive_float_vector(values::AbstractVector{<:Real}, name::AbstractString)
    vector = _finite_float_vector(values, name)
    all(>(0.0), vector) || throw(ArgumentError("$(name) must contain only positive values"))
    return vector
end

function _matching_lengths(names_and_values::Pair{<:AbstractString, <:AbstractVector}...)
    lengths = Dict(String(name) => length(values) for (name, values) in names_and_values)
    length(unique(values(lengths))) == 1 ||
        throw(ArgumentError("vectors must have matching lengths: $(sort!(collect(lengths)))"))
    return first(values(lengths))
end

function _finite_transform_result(result, expected_size::Tuple{Int, Int}, name::AbstractString)
    result isa AbstractMatrix ||
        throw(ArgumentError("$(name) transform must return a matrix"))
    size(result) == expected_size ||
        throw(ArgumentError("$(name) transform result must have size $(expected_size); got $(size(result))"))
    matrix = Float64.(result)
    all(isfinite, matrix) ||
        throw(ArgumentError("$(name) transform result must contain only finite values"))
    return matrix
end

function _finite_transform_result(result, expected_length::Integer, name::AbstractString)
    result isa AbstractArray ||
        throw(ArgumentError("$(name) transform must return an array"))
    vector = vec(Float64.(result))
    length(vector) == expected_length ||
        throw(ArgumentError("$(name) transform result must have length $(expected_length); got $(length(vector))"))
    all(isfinite, vector) ||
        throw(ArgumentError("$(name) transform result must contain only finite values"))
    return vector
end

function _finite_saturation_result(result, expected_length::Integer, name::AbstractString)
    result isa AbstractVector ||
        throw(ArgumentError("$(name) must return a vector"))
    vector = Float64.(collect(result))
    length(vector) == expected_length ||
        throw(ArgumentError("$(name) must return length $(expected_length); got $(length(vector))"))
    all(isfinite, vector) ||
        throw(ArgumentError("$(name) must contain only finite values"))
    return vector
end

"""
    CalibrationStepConfig(; method, params=Dict())

Typed representation of one public YAML `calibration` step: a `method` name
drawn from the supported calibration methods plus a free-form `params` mapping.
`params.dist` is rejected because custom likelihood distributions are not
currently configurable through YAML.

Applying a configured step to a model is a separate, not-yet-implemented
model-integration concern.
"""
struct CalibrationStepConfig
    method::String
    params::Dict{String, Any}
end

function Base.:(==)(lhs::CalibrationStepConfig, rhs::CalibrationStepConfig)
    return lhs.method == rhs.method && lhs.params == rhs.params
end

function CalibrationStepConfig(; method, params = Dict{String, Any}())
    config = CalibrationStepConfig(String(method), _string_key_dict(params))
    _validate_calibration_step_config(config)
    return config
end

"""
    validate_calibration_step_config(config)

Deprecated public validation wrapper for one `CalibrationStepConfig`.

Use `CalibrationStepConfig` construction or `load_public_config` calibration
parsing instead. Direct calls emit a deprecation warning, then validate that
`method` is non-empty and one of the currently supported calibration methods,
and that `params` does not configure a custom `dist`.
"""
function validate_calibration_step_config(config::CalibrationStepConfig)
    Base.depwarn(
        "Epsilon.validate_calibration_step_config is deprecated as a public API; use CalibrationStepConfig construction or load_public_config calibration parsing instead. The function remains exported for this release and may be unexported before v1.",
        :validate_calibration_step_config,
    )
    return _validate_calibration_step_config(config)
end

function _validate_calibration_step_config(config::CalibrationStepConfig)
    !isempty(config.method) || throw(ArgumentError("calibration step method must not be empty"))
    config.method in _SUPPORTED_CALIBRATION_METHODS ||
        throw(
        ArgumentError(
            "calibration step method must be one of $(join(sort!(collect(_SUPPORTED_CALIBRATION_METHODS)), ", ")); got $(config.method)",
        ),
    )
    !haskey(config.params, "dist") ||
        throw(ArgumentError("calibration step `params.dist` is not currently supported"))
    return nothing
end

"""
    UnalignedValuesError(unaligned_values)

Raised by [`exact_row_indices`](@ref) when one or more rows of calibration data
cannot be exactly matched to a single coordinate value. `unaligned_values` maps
each affected column name to the 1-based row indices that failed to align.
"""
struct UnalignedValuesError <: Exception
    unaligned_values::Dict{String, Vector{Int}}
end

function Base.showerror(io::IO, err::UnalignedValuesError)
    rows = sort!(collect(reduce(union, values(err.unaligned_values); init = Set{Int}())))
    return print(io, "the following rows are not aligned: $(rows)")
end

"""
    NonMonotonicError(message)

Raised by [`assert_monotonic_lift`](@ref) when lift-test `delta_x`/`delta_y`
pairs disagree in sign.
"""
struct NonMonotonicError <: Exception
    message::String
end

Base.showerror(io::IO, err::NonMonotonicError) = print(io, err.message)

"""
    exact_row_indices(coords, df) -> Dict{String, Vector{Int}}

Return, for each column shared between `df` and `coords`, the 1-based index
into the corresponding coordinate vector for every row of `df`.

`coords` and `df` are both column-name-to-vector mappings. Every value in a
shared column must match exactly one coordinate value; throws
[`UnalignedValuesError`](@ref) listing the offending rows otherwise, and
throws `ArgumentError` when a `df` column has no matching `coords` entry.
Returned indices use Julia's native 1-based indexing.
"""
function exact_row_indices(
        coords::AbstractDict{<:AbstractString, <:AbstractVector},
        df::AbstractDict{<:AbstractString, <:AbstractVector},
    )
    indices = Dict{String, Vector{Int}}()
    unaligned = Dict{String, Vector{Int}}()
    missing_coords = String[]
    if !isempty(df)
        lengths = Dict(String(column) => length(values) for (column, values) in df)
        length(unique(values(lengths))) == 1 ||
            throw(ArgumentError("df columns must have matching lengths: $(sort!(collect(lengths)))"))
    end

    for (column, column_values) in df
        column_name = String(column)
        if !haskey(coords, column_name)
            push!(missing_coords, column_name)
            continue
        end

        coord_values = coords[column_name]
        row_indices = Vector{Int}(undef, length(column_values))
        bad_rows = Int[]
        for (row, value) in enumerate(column_values)
            matches = findall(==(value), coord_values)
            if length(matches) != 1
                push!(bad_rows, row)
                row_indices[row] = 0
            else
                row_indices[row] = matches[1]
            end
        end
        isempty(bad_rows) || (unaligned[column_name] = bad_rows)
        indices[column_name] = row_indices
    end

    isempty(unaligned) || throw(UnalignedValuesError(unaligned))
    isempty(missing_coords) ||
        throw(ArgumentError("the following columns are not present in coords: $(sort!(missing_coords))"))

    return indices
end

"""
    validate_lift_test_columns(columns)

Require that `columns` contains the lift-test data columns needed to register a
calibration likelihood term: `x`, `delta_x`, `delta_y`, and `sigma`.
"""
function validate_lift_test_columns(columns)
    available = Set(String(column) for column in columns)
    missing_columns = setdiff(_REQUIRED_LIFT_TEST_COLUMNS, available)
    isempty(missing_columns) ||
        throw(
        ArgumentError(
            "lift-test data is missing required columns: $(join(sort!(collect(missing_columns)), ", "))",
        ),
    )
    return nothing
end

"""
    assert_monotonic_lift(delta_x, delta_y)

Require that `delta_x` and `delta_y` agree in sign (or are zero) elementwise.
Throws [`NonMonotonicError`](@ref) otherwise.
"""
function assert_monotonic_lift(delta_x::AbstractVector{<:Real}, delta_y::AbstractVector{<:Real})
    _matching_lengths("delta_x" => delta_x, "delta_y" => delta_y)
    delta_x_values = _finite_float_vector(delta_x, "delta_x")
    delta_y_values = _finite_float_vector(delta_y, "delta_y")
    all(delta_x_values .* delta_y_values .>= 0) ||
        throw(NonMonotonicError("lift-test delta_x and delta_y must be monotonic (matching sign or zero)"))
    return nothing
end

"""
    scale_channel_lift_measurements(channel, x, delta_x, channel_columns, transform)

Rescale lift-test `x`/`delta_x` values through a fitted channel `transform`
(for example a fitted `MaxAbsScaler`'s `transform` applied to its underlying
matrix).

Each row's value is embedded into a zero-filled `(nrows, nchannels)` matrix at
its own channel's column, `transform` is applied to that full matrix, and each
row's own scaled value is read back out. This preserves
pivot/transform/unpivot behaviour for any matrix-valued `transform`. Returns a
named tuple `(; channel, x, delta_x)`.
"""
function scale_channel_lift_measurements(
        channel::AbstractVector,
        x::AbstractVector{<:Real},
        delta_x::AbstractVector{<:Real},
        channel_columns::AbstractVector,
        transform::Function,
    )
    n = _matching_lengths("channel" => channel, "x" => x, "delta_x" => delta_x)
    x_values = _finite_float_vector(x, "x")
    delta_x_values = _finite_float_vector(delta_x, "delta_x")
    isempty(channel_columns) && throw(ArgumentError("channel_columns must not be empty"))
    length(unique(channel_columns)) == length(channel_columns) ||
        throw(ArgumentError("channel_columns must not contain duplicates"))

    column_index = Dict(value => index for (index, value) in enumerate(channel_columns))
    ncols = length(channel_columns)
    wide_x = zeros(Float64, n, ncols)
    wide_delta_x = zeros(Float64, n, ncols)
    row_columns = Vector{Int}(undef, n)
    for (row, value) in enumerate(channel)
        haskey(column_index, value) ||
            throw(ArgumentError("channel value $(value) is not present in channel_columns"))
        column = column_index[value]
        row_columns[row] = column
        wide_x[row, column] = x_values[row]
        wide_delta_x[row, column] = delta_x_values[row]
    end

    scaled_x_wide = _finite_transform_result(transform(wide_x), size(wide_x), "channel")
    scaled_delta_x_wide = _finite_transform_result(transform(wide_delta_x), size(wide_delta_x), "channel")
    scaled_x = [scaled_x_wide[row, row_columns[row]] for row in 1:n]
    scaled_delta_x = [scaled_delta_x_wide[row, row_columns[row]] for row in 1:n]

    return (; channel = collect(channel), x = scaled_x, delta_x = scaled_delta_x)
end

"""
    scale_target_for_lift_measurements(target, transform)

Rescale a lift-test target-like vector (`delta_y` or `sigma`) through a fitted
target `transform`.
"""
function scale_target_for_lift_measurements(target::AbstractVector{<:Real}, transform::Function)
    target_values = _finite_float_vector(target, "target")
    reshaped = reshape(target_values, :, 1)
    return _finite_transform_result(transform(reshaped), length(target_values), "target")
end

"""
    scale_lift_measurements(channel, x, delta_x, delta_y, sigma, channel_columns, channel_transform, target_transform)

Rescale a full lift-test dataset (channel-indexed `x`/`delta_x` plus target-like
`delta_y`/`sigma`) for use against a scaled model. Returns a named tuple
`(; channel, x, delta_x, delta_y, sigma)`.
"""
function scale_lift_measurements(
        channel::AbstractVector,
        x::AbstractVector{<:Real},
        delta_x::AbstractVector{<:Real},
        delta_y::AbstractVector{<:Real},
        sigma::AbstractVector{<:Real},
        channel_columns::AbstractVector,
        channel_transform::Function,
        target_transform::Function,
    )
    _matching_lengths(
        "channel" => channel,
        "x" => x,
        "delta_x" => delta_x,
        "delta_y" => delta_y,
        "sigma" => sigma,
    )
    channel_scaled = scale_channel_lift_measurements(channel, x, delta_x, channel_columns, channel_transform)
    delta_y_scaled = scale_target_for_lift_measurements(delta_y, target_transform)
    sigma_scaled = scale_target_for_lift_measurements(sigma, target_transform)
    all(>(0.0), sigma_scaled) ||
        throw(ArgumentError("scaled sigma must contain only positive values"))

    return (;
        channel = channel_scaled.channel,
        x = channel_scaled.x,
        delta_x = channel_scaled.delta_x,
        delta_y = delta_y_scaled,
        sigma = sigma_scaled,
    )
end

"""
    gamma_shape_scale(mu, sigma)

Convert a `Gamma(mu, sigma)` mean/standard-deviation parameterization into the
`(shape, scale)` parameterization used by `Distributions.Gamma`. `mu` and
`sigma` must both be strictly positive.
"""
function gamma_shape_scale(mu::Real, sigma::Real)
    isfinite(sigma) && sigma > 0 || throw(ArgumentError("sigma must be positive and finite"))
    isfinite(mu) && mu > 0 || throw(ArgumentError("mu must be positive and finite"))
    shape = mu^2 / sigma^2
    scale = sigma^2 / mu
    return (; shape, scale)
end

"""
    lift_test_gamma_distribution(mu, sigma)

Build the `Distributions.Gamma` lift-test observation distribution from a
positive observation mean and standard deviation.
"""
function lift_test_gamma_distribution(mu::Real, sigma::Real)
    params = gamma_shape_scale(mu, sigma)
    return Distributions.Gamma(params.shape, params.scale)
end

"""
    lift_test_estimated_lift(saturation_fn, x, delta_x)

Compute the model-estimated lift `saturation_fn(x + delta_x) - saturation_fn(x)`
for a lift-test row. `saturation_fn` must accept and return a vector (for
example
`x -> centered_logistic_saturation(x, lam)`).
"""
function lift_test_estimated_lift(
        saturation_fn::Function,
        x::AbstractVector{<:Real},
        delta_x::AbstractVector{<:Real},
    )
    n = _matching_lengths("x" => x, "delta_x" => delta_x)
    x_values = _finite_float_vector(x, "x")
    delta_x_values = _finite_float_vector(delta_x, "delta_x")
    x_after = x_values .+ delta_x_values
    all(isfinite, x_after) || throw(ArgumentError("x + delta_x must contain only finite values"))
    before = _finite_saturation_result(saturation_fn(x_values), n, "saturation_fn(x)")
    after = _finite_saturation_result(saturation_fn(x_after), n, "saturation_fn(x + delta_x)")
    return after .- before
end

"""
    lift_test_likelihood_terms(saturation_fn, x, delta_x, delta_y, sigma)

Compute lift-test likelihood-term ingredients for one batch of lift-test rows:
the Gamma observation mean `mu = |estimated_lift|`, the observed value
`|delta_y|`, and the elementwise Gamma log-density
`logp = logpdf(Gamma(mu, sigma), |delta_y|)`. Returns a named tuple `(; mu,
observed, logp)`.
"""
function lift_test_likelihood_terms(
        saturation_fn::Function,
        x::AbstractVector{<:Real},
        delta_x::AbstractVector{<:Real},
        delta_y::AbstractVector{<:Real},
        sigma::AbstractVector{<:Real},
    )
    _matching_lengths("x" => x, "delta_x" => delta_x, "delta_y" => delta_y, "sigma" => sigma)
    lift = lift_test_estimated_lift(saturation_fn, x, delta_x)
    mu = abs.(lift)
    all(>(0.0), mu) ||
        throw(ArgumentError("estimated lift magnitude must contain only positive values"))
    observed = abs.(_finite_float_vector(delta_y, "delta_y"))
    sigma_values = _positive_float_vector(sigma, "sigma")
    logp = [
        Distributions.logpdf(lift_test_gamma_distribution(mu[index], sigma_values[index]), observed[index])
            for index in eachindex(mu)
    ]
    return (; mu, observed, logp)
end

"""
    lift_test_estimated_lift_ad(saturation_fn, x, delta_x)

AD-compatible variant of [`lift_test_estimated_lift`](@ref) for use on the
Turing sampling path, where `saturation_fn` may close over sampled saturation
parameters and therefore return AD numeric types (for example
`ForwardDiff.Dual` or `ReverseDiff.TrackedReal`) rather than plain `Float64`.
Computes `saturation_fn(x + delta_x) .- saturation_fn(x)` without forcing
`Float64` conversion of `saturation_fn`'s output, unlike
[`lift_test_estimated_lift`](@ref) (whose `Float64.(collect(...))`-based
result validation would otherwise truncate AD dual/tracked numbers and break
gradients).

`x` and `delta_x` are the fixed (non-parameter), already-scaled calibration
data and are still eagerly validated as finite `Float64` vectors; only
`saturation_fn`'s *output* is left untouched so that AD types survive.
"""
function lift_test_estimated_lift_ad(
        saturation_fn::Function,
        x::AbstractVector{<:Real},
        delta_x::AbstractVector{<:Real},
    )
    n = _matching_lengths("x" => x, "delta_x" => delta_x)
    x_values = _finite_float_vector(x, "x")
    delta_x_values = _finite_float_vector(delta_x, "delta_x")
    x_after = x_values .+ delta_x_values

    before = saturation_fn(x_values)
    after = saturation_fn(x_after)
    before isa AbstractVector && length(before) == n ||
        throw(ArgumentError("saturation_fn(x) must return a vector of length $(n)"))
    after isa AbstractVector && length(after) == n ||
        throw(ArgumentError("saturation_fn(x + delta_x) must return a vector of length $(n)"))
    all(isfinite, before) ||
        throw(ArgumentError("saturation_fn(x) must return only finite values"))
    all(isfinite, after) ||
        throw(ArgumentError("saturation_fn(x + delta_x) must return only finite values"))

    return after .- before
end

"""
    lift_test_log_density(saturation_fn, x, delta_x, delta_y, sigma)

AD-compatible lift-test log-density contribution for one batch of lift-test
rows, computed entirely from already-scaled model-space values: the total
Gamma log-density `sum(logpdf(Gamma(mu, sigma), |delta_y|))`, where
`mu = |saturation_fn(x + delta_x) - saturation_fn(x)|`.

This mirrors the (summed) `logp` produced by
[`lift_test_likelihood_terms`](@ref), but unlike that function it does not
force `saturation_fn`'s output to `Float64`, so it is safe to call with a
`saturation_fn` that closes over sampled Turing parameters. That makes it
suitable for `Turing.@addlogprob!` integration on the model's saturation
parameter sampling path (Task 15-05). This function itself has no dependency
on Turing. `saturation_fn` must be a pure saturation closure with no adstock
applied, preserving the calibration contract that adstock is never inserted
into lift-test calibration.

Throws `ArgumentError` for mismatched lengths, non-finite `x`/`delta_x`/
`delta_y`, non-positive `sigma`, or a non-positive/non-finite estimated lift
magnitude (which would make the observation's Gamma mean degenerate, for
example when the estimated lift is exactly zero).
"""
function lift_test_log_density(
        saturation_fn::Function,
        x::AbstractVector{<:Real},
        delta_x::AbstractVector{<:Real},
        delta_y::AbstractVector{<:Real},
        sigma::AbstractVector{<:Real},
    )
    _matching_lengths("x" => x, "delta_x" => delta_x, "delta_y" => delta_y, "sigma" => sigma)
    observed = abs.(_finite_float_vector(delta_y, "delta_y"))
    sigma_values = _positive_float_vector(sigma, "sigma")

    lift = lift_test_estimated_lift_ad(saturation_fn, x, delta_x)
    mu = abs.(lift)
    all(value -> isfinite(value) && value > 0, mu) ||
        throw(ArgumentError("estimated lift magnitude must contain only positive finite values"))

    return sum(
        Distributions.logpdf(lift_test_gamma_distribution(mu[index], sigma_values[index]), observed[index])
            for index in eachindex(mu)
    )
end

"""
    cost_per_target_penalties(gathered_cpt, targets, sigma)

Compute the cost-per-target Gaussian soft-penalty term elementwise:
`-(|gathered_cpt - targets|)^2 / (2 * sigma^2)`.
"""
function cost_per_target_penalties(
        gathered_cpt::AbstractVector{<:Real},
        targets::AbstractVector{<:Real},
        sigma::AbstractVector{<:Real},
    )
    _matching_lengths("gathered_cpt" => gathered_cpt, "targets" => targets, "sigma" => sigma)
    gathered_values = _finite_float_vector(gathered_cpt, "gathered_cpt")
    target_values = _finite_float_vector(targets, "targets")
    sigma_values = _positive_float_vector(sigma, "sigma")
    deviation = abs.(gathered_values .- target_values)
    return -(deviation .^ 2) ./ (2.0 .* sigma_values .^ 2)
end

"""
    cost_per_target_total_penalty(gathered_cpt, targets, sigma)

Sum [`cost_per_target_penalties`](@ref) into a scalar model log-density
contribution.
"""
function cost_per_target_total_penalty(
        gathered_cpt::AbstractVector{<:Real},
        targets::AbstractVector{<:Real},
        sigma::AbstractVector{<:Real},
    )
    return sum(cost_per_target_penalties(gathered_cpt, targets, sigma))
end

"""
    LiftTestCalibrationPayload(channel_index, x, delta_x, delta_y, sigma)

Typed, row-aligned, already-scaled lift-test calibration observations ready
for the model runtime. `channel_index` is the 1-based index into the model's
channel axis for each row; `x`, `delta_x`, `delta_y`, and `sigma` are all in
scaled model space (the same space as the fitted media and target
likelihood). `sigma` must be strictly positive.

Use [`build_lift_test_calibration_payload`](@ref) to construct one of these
from plain columnar lift-test input plus fitted channel/target scalers; this
struct's own positional constructor performs no scaling or alignment and
should generally not be called directly outside tests.
"""
struct LiftTestCalibrationPayload
    channel_index::Vector{Int}
    x::Vector{Float64}
    delta_x::Vector{Float64}
    delta_y::Vector{Float64}
    sigma::Vector{Float64}
end

function Base.:(==)(lhs::LiftTestCalibrationPayload, rhs::LiftTestCalibrationPayload)
    return lhs.channel_index == rhs.channel_index &&
        lhs.x == rhs.x &&
        lhs.delta_x == rhs.delta_x &&
        lhs.delta_y == rhs.delta_y &&
        lhs.sigma == rhs.sigma
end

"""
    validate_lift_test_calibration_payload(payload)

Deprecated public validation wrapper for one
[`LiftTestCalibrationPayload`](@ref).

Use [`build_lift_test_calibration_payload`](@ref) instead. Direct calls emit a
deprecation warning, then validate that all fields have matching, nonzero
length; `channel_index` is strictly positive (1-based); `x`, `delta_x`, and
`delta_y` are finite; and `sigma` is strictly positive and finite.
"""
function validate_lift_test_calibration_payload(payload::LiftTestCalibrationPayload)
    Base.depwarn(
        "Epsilon.validate_lift_test_calibration_payload is deprecated as a public API; use build_lift_test_calibration_payload instead. The function remains exported for this release and may be unexported before v1.",
        :validate_lift_test_calibration_payload,
    )
    return _validate_lift_test_calibration_payload(payload)
end

function _validate_lift_test_calibration_payload(payload::LiftTestCalibrationPayload)
    n = length(payload.channel_index)
    n > 0 || throw(ArgumentError("lift-test calibration payload must contain at least one row"))
    length(payload.x) == n ||
        throw(ArgumentError("lift-test calibration payload x length must match channel_index length"))
    length(payload.delta_x) == n ||
        throw(ArgumentError("lift-test calibration payload delta_x length must match channel_index length"))
    length(payload.delta_y) == n ||
        throw(ArgumentError("lift-test calibration payload delta_y length must match channel_index length"))
    length(payload.sigma) == n ||
        throw(ArgumentError("lift-test calibration payload sigma length must match channel_index length"))
    all(>(0), payload.channel_index) ||
        throw(ArgumentError("lift-test calibration payload channel_index must contain only positive (1-based) indices"))
    all(isfinite, payload.x) ||
        throw(ArgumentError("lift-test calibration payload x must contain only finite values"))
    all(isfinite, payload.delta_x) ||
        throw(ArgumentError("lift-test calibration payload delta_x must contain only finite values"))
    all(isfinite, payload.delta_y) ||
        throw(ArgumentError("lift-test calibration payload delta_y must contain only finite values"))
    all(value -> isfinite(value) && value > 0.0, payload.sigma) ||
        throw(ArgumentError("lift-test calibration payload sigma must contain only positive finite values"))
    return nothing
end

"""
    build_lift_test_calibration_payload(; channel, x, delta_x, delta_y, sigma, channel_columns, channel_transform, target_transform)

Build a validated [`LiftTestCalibrationPayload`](@ref) from plain columnar
lift-test input. Reuses [`assert_monotonic_lift`](@ref) and
[`scale_lift_measurements`](@ref) for monotonicity checking and scaling, then
resolves each row's channel label into a 1-based index into `channel_columns`.
"""
function build_lift_test_calibration_payload(;
        channel::AbstractVector,
        x::AbstractVector{<:Real},
        delta_x::AbstractVector{<:Real},
        delta_y::AbstractVector{<:Real},
        sigma::AbstractVector{<:Real},
        channel_columns::AbstractVector,
        channel_transform::Function,
        target_transform::Function,
    )
    assert_monotonic_lift(delta_x, delta_y)
    scaled = scale_lift_measurements(
        channel,
        x,
        delta_x,
        delta_y,
        sigma,
        channel_columns,
        channel_transform,
        target_transform,
    )
    column_index = Dict(value => index for (index, value) in enumerate(channel_columns))
    channel_index = Int[column_index[value] for value in scaled.channel]

    payload = LiftTestCalibrationPayload(
        channel_index,
        scaled.x,
        scaled.delta_x,
        scaled.delta_y,
        scaled.sigma,
    )
    _validate_lift_test_calibration_payload(payload)
    return payload
end

"""
    lift_test_payload_log_density(saturation_fn, payload, channel_param)

Multi-channel, [`LiftTestCalibrationPayload`](@ref)-aware entry point for
[`lift_test_log_density`](@ref): selects each row's saturation parameter from
a full per-channel sampled parameter vector `channel_param` (indexed the same
way as the model's channel axis, so that
`channel_param[payload.channel_index[i]]` is the parameter for row `i`), then
delegates to `lift_test_log_density`.

`saturation_fn` must accept `(x_row, param_row)` — both row-aligned vectors —
and return a row-aligned vector, for example
`(x_row, lam_row) -> centered_logistic_saturation.(x_row, lam_row)`.

This is the intended calibration entry point for Task 15-05's
`Turing.@addlogprob!` wiring, where `channel_param` is a sampled Turing
parameter vector (for example the model's `lam`) and may carry AD dual/tracked
numeric types; this function itself has no dependency on Turing.

Throws `ArgumentError` if any `payload.channel_index` value is out of bounds
for `channel_param`, so a channel-index/parameter-vector length mismatch fails
closed rather than throwing an opaque `BoundsError` deep inside AD.
"""
function lift_test_payload_log_density(
        saturation_fn::Function,
        payload::LiftTestCalibrationPayload,
        channel_param::AbstractVector,
    )
    nparams = length(channel_param)
    all(index -> 1 <= index <= nparams, payload.channel_index) ||
        throw(
        ArgumentError(
            "lift-test calibration payload channel_index is out of bounds for a channel parameter vector of length $(nparams)",
        ),
    )

    param_rows = channel_param[payload.channel_index]
    saturation_fn_of_x = x_row -> saturation_fn(x_row, param_rows)
    return lift_test_log_density(saturation_fn_of_x, payload.x, payload.delta_x, payload.delta_y, payload.sigma)
end

"""
    CostPerTargetCalibrationPayload(gathered_cpt, targets, sigma)

Typed, already-scaled cost-per-target calibration observations ready for the
model runtime: `gathered_cpt` is the observed cost-per-target value,
`targets` is the target cost-per-target value, and `sigma` is the strictly
positive soft-penalty scale, all in scaled model space.

Use [`build_cost_per_target_calibration_payload`](@ref) to construct one of
these from plain columnar input plus a fitted target scaler; this struct's own
positional constructor performs no scaling and should generally not be called
directly outside tests.
"""
struct CostPerTargetCalibrationPayload
    gathered_cpt::Vector{Float64}
    targets::Vector{Float64}
    sigma::Vector{Float64}
end

function Base.:(==)(lhs::CostPerTargetCalibrationPayload, rhs::CostPerTargetCalibrationPayload)
    return lhs.gathered_cpt == rhs.gathered_cpt &&
        lhs.targets == rhs.targets &&
        lhs.sigma == rhs.sigma
end

"""
    validate_cost_per_target_calibration_payload(payload)

Deprecated public validation wrapper for one
[`CostPerTargetCalibrationPayload`](@ref).

Use [`build_cost_per_target_calibration_payload`](@ref) instead. Direct calls
emit a deprecation warning, then validate that all fields have matching,
nonzero length; `gathered_cpt` and `targets` are finite; and `sigma` is
strictly positive and finite.
"""
function validate_cost_per_target_calibration_payload(payload::CostPerTargetCalibrationPayload)
    Base.depwarn(
        "Epsilon.validate_cost_per_target_calibration_payload is deprecated as a public API; use build_cost_per_target_calibration_payload instead. The function remains exported for this release and may be unexported before v1.",
        :validate_cost_per_target_calibration_payload,
    )
    return _validate_cost_per_target_calibration_payload(payload)
end

function _validate_cost_per_target_calibration_payload(payload::CostPerTargetCalibrationPayload)
    n = length(payload.gathered_cpt)
    n > 0 || throw(ArgumentError("cost-per-target calibration payload must contain at least one row"))
    length(payload.targets) == n ||
        throw(ArgumentError("cost-per-target calibration payload targets length must match gathered_cpt length"))
    length(payload.sigma) == n ||
        throw(ArgumentError("cost-per-target calibration payload sigma length must match gathered_cpt length"))
    all(isfinite, payload.gathered_cpt) ||
        throw(ArgumentError("cost-per-target calibration payload gathered_cpt must contain only finite values"))
    all(isfinite, payload.targets) ||
        throw(ArgumentError("cost-per-target calibration payload targets must contain only finite values"))
    all(value -> isfinite(value) && value > 0.0, payload.sigma) ||
        throw(ArgumentError("cost-per-target calibration payload sigma must contain only positive finite values"))
    return nothing
end

"""
    build_cost_per_target_calibration_payload(; gathered_cpt, targets, sigma, transform)

Build a validated [`CostPerTargetCalibrationPayload`](@ref) from plain
columnar cost-per-target input, rescaling each of `gathered_cpt`, `targets`,
and `sigma` through `transform` via
[`scale_target_for_lift_measurements`](@ref).
"""
function build_cost_per_target_calibration_payload(;
        gathered_cpt::AbstractVector{<:Real},
        targets::AbstractVector{<:Real},
        sigma::AbstractVector{<:Real},
        transform::Function,
    )
    _matching_lengths("gathered_cpt" => gathered_cpt, "targets" => targets, "sigma" => sigma)
    gathered_scaled = scale_target_for_lift_measurements(gathered_cpt, transform)
    targets_scaled = scale_target_for_lift_measurements(targets, transform)
    sigma_scaled = scale_target_for_lift_measurements(sigma, transform)

    payload = CostPerTargetCalibrationPayload(gathered_scaled, targets_scaled, sigma_scaled)
    _validate_cost_per_target_calibration_payload(payload)
    return payload
end

"""
    LiftTestCalibrationRows(channel, x, delta_x, delta_y, sigma)

Plain, unscaled columnar lift-test row data supplied by a caller, in the
model's original (unscaled) units. This is the raw companion input accepted by
`TimeSeriesMMM`'s calibration constructor arguments; it is resolved into a
scaled [`LiftTestCalibrationPayload`](@ref) internally once the fitted
channel/target scales are known.

Use the keyword constructor to build one of these from plain vectors; it
validates matching lengths, finite `x`/`delta_x`/`delta_y`, positive `sigma`,
and lift-test monotonicity via [`assert_monotonic_lift`](@ref) eagerly, so
malformed calibration data fails at `TimeSeriesMMM` construction time rather
than at fit time.
"""
struct LiftTestCalibrationRows
    channel::Vector{String}
    x::Vector{Float64}
    delta_x::Vector{Float64}
    delta_y::Vector{Float64}
    sigma::Vector{Float64}
end

function Base.:(==)(lhs::LiftTestCalibrationRows, rhs::LiftTestCalibrationRows)
    return lhs.channel == rhs.channel &&
        lhs.x == rhs.x &&
        lhs.delta_x == rhs.delta_x &&
        lhs.delta_y == rhs.delta_y &&
        lhs.sigma == rhs.sigma
end

function LiftTestCalibrationRows(;
        channel::AbstractVector,
        x::AbstractVector{<:Real},
        delta_x::AbstractVector{<:Real},
        delta_y::AbstractVector{<:Real},
        sigma::AbstractVector{<:Real},
    )
    channel_values = String[String(value) for value in channel]
    x_values = _finite_float_vector(x, "x")
    delta_x_values = _finite_float_vector(delta_x, "delta_x")
    delta_y_values = _finite_float_vector(delta_y, "delta_y")
    sigma_values = _positive_float_vector(sigma, "sigma")
    rows = LiftTestCalibrationRows(channel_values, x_values, delta_x_values, delta_y_values, sigma_values)
    _validate_lift_test_calibration_rows(rows)
    return rows
end

"""
    CostPerTargetCalibrationRows(gathered_cpt, targets, sigma)

Plain, unscaled columnar cost-per-target row data supplied by a caller, in the
model's original (unscaled) units. This is the raw companion input accepted by
`TimeSeriesMMM`'s calibration constructor arguments; it is resolved into a
scaled [`CostPerTargetCalibrationPayload`](@ref) internally once the fitted
target scale is known.

Use the keyword constructor to build one of these from plain vectors; it
validates matching lengths, finite `gathered_cpt`/`targets`, and positive
`sigma` eagerly.
"""
struct CostPerTargetCalibrationRows
    gathered_cpt::Vector{Float64}
    targets::Vector{Float64}
    sigma::Vector{Float64}
end

function Base.:(==)(lhs::CostPerTargetCalibrationRows, rhs::CostPerTargetCalibrationRows)
    return lhs.gathered_cpt == rhs.gathered_cpt &&
        lhs.targets == rhs.targets &&
        lhs.sigma == rhs.sigma
end

function CostPerTargetCalibrationRows(;
        gathered_cpt::AbstractVector{<:Real},
        targets::AbstractVector{<:Real},
        sigma::AbstractVector{<:Real},
    )
    gathered_values = _finite_float_vector(gathered_cpt, "gathered_cpt")
    target_values = _finite_float_vector(targets, "targets")
    sigma_values = _positive_float_vector(sigma, "sigma")
    rows = CostPerTargetCalibrationRows(gathered_values, target_values, sigma_values)
    _validate_cost_per_target_calibration_rows(rows)
    return rows
end

function _validate_lift_test_calibration_rows(rows::LiftTestCalibrationRows)
    n = length(rows.channel)
    n > 0 || throw(ArgumentError("lift-test calibration rows must contain at least one row"))
    _matching_lengths(
        "channel" => rows.channel,
        "x" => rows.x,
        "delta_x" => rows.delta_x,
        "delta_y" => rows.delta_y,
        "sigma" => rows.sigma,
    )
    assert_monotonic_lift(rows.delta_x, rows.delta_y)
    all(isfinite, rows.x) ||
        throw(ArgumentError("lift-test calibration rows x must contain only finite values"))
    all(isfinite, rows.delta_x) ||
        throw(ArgumentError("lift-test calibration rows delta_x must contain only finite values"))
    all(isfinite, rows.delta_y) ||
        throw(ArgumentError("lift-test calibration rows delta_y must contain only finite values"))
    all(value -> isfinite(value) && value > 0.0, rows.sigma) ||
        throw(ArgumentError("lift-test calibration rows sigma must contain only positive finite values"))
    return nothing
end

function _validate_cost_per_target_calibration_rows(rows::CostPerTargetCalibrationRows)
    n = length(rows.gathered_cpt)
    n > 0 || throw(ArgumentError("cost-per-target calibration rows must contain at least one row"))
    _matching_lengths("gathered_cpt" => rows.gathered_cpt, "targets" => rows.targets, "sigma" => rows.sigma)
    all(isfinite, rows.gathered_cpt) ||
        throw(ArgumentError("cost-per-target calibration rows gathered_cpt must contain only finite values"))
    all(isfinite, rows.targets) ||
        throw(ArgumentError("cost-per-target calibration rows targets must contain only finite values"))
    all(value -> isfinite(value) && value > 0.0, rows.sigma) ||
        throw(ArgumentError("cost-per-target calibration rows sigma must contain only positive finite values"))
    return nothing
end

"""
    TimeSeriesCalibrationInput(steps, lift_test, cost_per_target)

Companion internal payload attached to a `TimeSeriesMMM`, bundling the raw
(unscaled) calibration steps and row data supplied at construction time. Build
one of these indirectly through `TimeSeriesMMM`'s `calibration_steps`,
`lift_test_data`, and `cost_per_target_data` constructor arguments rather than
calling this constructor directly.
"""
struct TimeSeriesCalibrationInput
    steps::Vector{CalibrationStepConfig}
    lift_test::Union{Nothing, LiftTestCalibrationRows}
    cost_per_target::Union{Nothing, CostPerTargetCalibrationRows}
end

function Base.:(==)(lhs::TimeSeriesCalibrationInput, rhs::TimeSeriesCalibrationInput)
    return lhs.steps == rhs.steps &&
        lhs.lift_test == rhs.lift_test &&
        lhs.cost_per_target == rhs.cost_per_target
end

"""
    MMMCalibrationSpec(steps, lift_test, cost_per_target)

Resolved calibration metadata attached to a time-series `MMMModelSpec`:
the configured calibration steps plus already-scaled
[`LiftTestCalibrationPayload`](@ref) and/or
[`CostPerTargetCalibrationPayload`](@ref) observations, ready for the model
runtime. `PanelMMM` specs must never carry a non-`nothing` value here.
"""
struct MMMCalibrationSpec
    steps::Vector{CalibrationStepConfig}
    lift_test::Union{Nothing, LiftTestCalibrationPayload}
    cost_per_target::Union{Nothing, CostPerTargetCalibrationPayload}
end

function Base.:(==)(lhs::MMMCalibrationSpec, rhs::MMMCalibrationSpec)
    return lhs.steps == rhs.steps &&
        lhs.lift_test == rhs.lift_test &&
        lhs.cost_per_target == rhs.cost_per_target
end

"""
    _validate_calibration_steps_and_rows(steps, lift_test, cost_per_target)

Require that configured calibration `steps` and supplied row data agree:
`add_lift_test_measurements` requires `lift_test` row data and vice versa;
`add_cost_per_target_calibration` requires `cost_per_target` row data and vice
versa. Also rejects repeated steps for the same method.
"""
function _validate_calibration_steps_and_rows(
        steps::Vector{CalibrationStepConfig},
        lift_test::Union{Nothing, LiftTestCalibrationRows},
        cost_per_target::Union{Nothing, CostPerTargetCalibrationRows},
    )
    methods = _validate_calibration_step_configs(steps)
    !isnothing(lift_test) && _validate_lift_test_calibration_rows(lift_test)
    !isnothing(cost_per_target) && _validate_cost_per_target_calibration_rows(cost_per_target)
    _validate_calibration_step_presence(methods, !isnothing(lift_test), !isnothing(cost_per_target))
    return nothing
end

function _validate_calibration_step_configs(steps::Vector{CalibrationStepConfig})
    foreach(_validate_calibration_step_config, steps)
    methods = [step.method for step in steps]
    length(unique(methods)) == length(methods) ||
        throw(ArgumentError("calibration steps must not repeat the same method"))
    return methods
end

function _validate_calibration_step_presence(
        methods::AbstractVector{<:AbstractString},
        has_lift_test::Bool,
        has_cost_per_target::Bool,
    )
    isempty(methods) && !has_lift_test && !has_cost_per_target &&
        throw(ArgumentError("calibration must include at least one configured step"))

    has_lift_step = "add_lift_test_measurements" in methods
    has_cpt_step = "add_cost_per_target_calibration" in methods

    has_lift_step == has_lift_test ||
        throw(
        ArgumentError(
            "an `add_lift_test_measurements` calibration step requires `lift_test_data`, and `lift_test_data` requires an `add_lift_test_measurements` step",
        ),
    )
    has_cpt_step == has_cost_per_target ||
        throw(
        ArgumentError(
            "an `add_cost_per_target_calibration` calibration step requires `cost_per_target_data`, and `cost_per_target_data` requires an `add_cost_per_target_calibration` step",
        ),
    )
    return nothing
end

function _validate_time_series_calibration_input(input::TimeSeriesCalibrationInput)
    _validate_calibration_steps_and_rows(input.steps, input.lift_test, input.cost_per_target)
    return nothing
end

function _validate_mmm_calibration_spec(
        spec::MMMCalibrationSpec;
        nchannels::Union{Nothing, Integer} = nothing,
        saturation_type::Union{Nothing, Symbol} = nothing,
    )
    methods = _validate_calibration_step_configs(spec.steps)
    !isnothing(spec.lift_test) && _validate_lift_test_calibration_payload(spec.lift_test)
    !isnothing(spec.cost_per_target) && _validate_cost_per_target_calibration_payload(spec.cost_per_target)
    _validate_calibration_step_presence(methods, !isnothing(spec.lift_test), !isnothing(spec.cost_per_target))

    if !isnothing(spec.lift_test)
        if !isnothing(nchannels)
            nchannels > 0 || throw(ArgumentError("calibration model channel count must be positive"))
            all(index -> index <= nchannels, spec.lift_test.channel_index) ||
                throw(
                ArgumentError(
                    "lift-test calibration payload channel_index is out of bounds for a model with $(nchannels) channels",
                ),
            )
        end
        if !isnothing(saturation_type)
            saturation_type === :logistic ||
                throw(
                ArgumentError(
                    "lift-test calibration is only supported for `logistic` saturation in the current model path",
                ),
            )
        end
    end
    return nothing
end

"""
    _build_calibration_input(steps, lift_test, cost_per_target)

Build a validated [`TimeSeriesCalibrationInput`](@ref) from raw constructor
arguments, or return `nothing` when no calibration is configured.
"""
function _build_calibration_input(
        steps::Vector{CalibrationStepConfig},
        lift_test::Union{Nothing, LiftTestCalibrationRows},
        cost_per_target::Union{Nothing, CostPerTargetCalibrationRows},
    )
    isempty(steps) && isnothing(lift_test) && isnothing(cost_per_target) && return nothing
    _validate_calibration_steps_and_rows(steps, lift_test, cost_per_target)
    input = TimeSeriesCalibrationInput(steps, lift_test, cost_per_target)
    _validate_time_series_calibration_input(input)
    return input
end

"""
    _resolve_calibration_spec(config, calibration_input, channel_scale, target_scale)

Resolve a [`TimeSeriesCalibrationInput`](@ref) (or `nothing`) into a
[`MMMCalibrationSpec`](@ref) (or `nothing`) by scaling its row data through
the model's fitted `channel_scale`/`target_scale`, mirroring the scaling
applied to media channels and the target in the time-series Turing model.
"""
_resolve_calibration_spec(::ModelConfig, ::Nothing, ::AbstractVector{<:Real}, ::Real) = nothing

function _resolve_calibration_spec(
        config::ModelConfig,
        calibration_input::TimeSeriesCalibrationInput,
        channel_scale::AbstractVector{<:Real},
        target_scale::Real,
    )
    _validate_time_series_calibration_input(calibration_input)
    channel_scale_values = Float64.(collect(channel_scale))
    target_scale_value = Float64(target_scale)
    channel_transform = matrix -> matrix ./ reshape(channel_scale_values, 1, :)
    target_transform = matrix -> matrix ./ target_scale_value

    lift_test_payload = if isnothing(calibration_input.lift_test)
        nothing
    else
        build_lift_test_calibration_payload(
            channel = calibration_input.lift_test.channel,
            x = calibration_input.lift_test.x,
            delta_x = calibration_input.lift_test.delta_x,
            delta_y = calibration_input.lift_test.delta_y,
            sigma = calibration_input.lift_test.sigma,
            channel_columns = config.channel_columns,
            channel_transform = channel_transform,
            target_transform = target_transform,
        )
    end

    cost_per_target_payload = if isnothing(calibration_input.cost_per_target)
        nothing
    else
        build_cost_per_target_calibration_payload(
            gathered_cpt = calibration_input.cost_per_target.gathered_cpt,
            targets = calibration_input.cost_per_target.targets,
            sigma = calibration_input.cost_per_target.sigma,
            transform = target_transform,
        )
    end

    spec = MMMCalibrationSpec(calibration_input.steps, lift_test_payload, cost_per_target_payload)
    _validate_mmm_calibration_spec(spec; nchannels = length(config.channel_columns))
    return spec
end
