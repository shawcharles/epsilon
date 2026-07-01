"""
Calibration and lift-test schema, alignment, scaling, and likelihood-term
helpers.

This module ports the bounded, fixture-backed first slice of Abacus
`abacus/mmm/calibration/*.py` and `abacus/mmm/lift_test.py` semantics:
row-to-coordinate alignment, lift-test monotonicity validation, channel and
target rescaling for lift-test data, the PyMC `mu`/`sigma` -> Julia
`shape`/`scale` `Gamma` reparameterization used by the Abacus lift-test
likelihood term, and the cost-per-target soft-penalty calculation. Wiring a
calibration likelihood term into `TimeSeriesMMM`/`PanelMMM` sampling is an
explicit follow-on slice and is out of scope here.
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

Typed mirror of the Abacus public YAML `calibration` step schema
(`abacus/mmm/builders/schema.py::CalibrationStepConfig`): one step is a
`method` name drawn from the supported calibration methods plus a free-form
`params` mapping. `params.dist` is rejected, matching Abacus's current YAML
restriction that custom likelihood distributions cannot be configured through
YAML.

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
    validate_calibration_step_config(config)
    return config
end

"""
    validate_calibration_step_config(config)

Validate one `CalibrationStepConfig`: `method` must be non-empty and one of
the currently supported calibration methods, and `params` must not configure
a custom `dist`.
"""
function validate_calibration_step_config(config::CalibrationStepConfig)
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

Raised by [`exact_row_indices`](@ref) when one or more rows of calibration
data cannot be exactly matched to a single coordinate value, mirroring Abacus
`abacus.mmm.calibration.alignment.UnalignedValuesError`. `unaligned_values`
maps each affected column name to the 1-based row indices that failed to
align.
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
pairs disagree in sign, mirroring Abacus
`abacus.mmm.calibration.alignment.NonMonotonicError`.
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
This mirrors Abacus `abacus.mmm.calibration.alignment.exact_row_indices`,
adapted to Julia's native 1-based indexing.
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

Require that `columns` contains the lift-test data columns Abacus needs to
register a calibration likelihood term: `x`, `delta_x`, `delta_y`, and
`sigma`.
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

Require that `delta_x` and `delta_y` agree in sign (or are zero) elementwise,
mirroring Abacus `abacus.mmm.calibration.alignment.assert_monotonic`. Throws
[`NonMonotonicError`](@ref) otherwise.
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
matrix), mirroring Abacus
`abacus.mmm.calibration.scaling.scale_channel_lift_measurements`.

Each row's value is embedded into a zero-filled `(nrows, nchannels)` matrix at
its own channel's column, `transform` is applied to that full matrix, and each
row's own scaled value is read back out. This reproduces Abacus's
pivot/transform/unpivot behavior for any matrix-valued `transform`. Returns a
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
target `transform`, mirroring Abacus
`abacus.mmm.calibration.scaling.scale_target_for_lift_measurements`.
"""
function scale_target_for_lift_measurements(target::AbstractVector{<:Real}, transform::Function)
    target_values = _finite_float_vector(target, "target")
    reshaped = reshape(target_values, :, 1)
    return _finite_transform_result(transform(reshaped), length(target_values), "target")
end

"""
    scale_lift_measurements(channel, x, delta_x, delta_y, sigma, channel_columns, channel_transform, target_transform)

Rescale a full lift-test dataset (channel-indexed `x`/`delta_x` plus target-like
`delta_y`/`sigma`) for use against a scaled model, mirroring Abacus
`abacus.mmm.calibration.scaling.scale_lift_measurements`. Returns a named
tuple `(; channel, x, delta_x, delta_y, sigma)`.
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

Convert a PyMC-style `Gamma(mu, sigma)` mean/standard-deviation
parameterization into the `(shape, scale)` parameterization used by
`Distributions.Gamma`. `mu` and `sigma` must both be strictly positive.
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

Build the `Distributions.Gamma` lift-test observation distribution Abacus
registers via `pm.Gamma(mu=mu, sigma=sigma, observed=...)` in
`abacus.mmm.calibration.graph.add_saturation_observations`.
"""
function lift_test_gamma_distribution(mu::Real, sigma::Real)
    params = gamma_shape_scale(mu, sigma)
    return Distributions.Gamma(params.shape, params.scale)
end

"""
    lift_test_estimated_lift(saturation_fn, x, delta_x)

Compute the model-estimated lift `saturation_fn(x + delta_x) - saturation_fn(x)`
for a lift-test row, mirroring the core computation in Abacus
`abacus.mmm.calibration.graph.add_saturation_observations`. `saturation_fn`
must accept and return a vector (for example
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

Compute the Abacus lift-test likelihood-term ingredients for one batch of
lift-test rows: the Gamma observation mean `mu = |estimated_lift|`, the
observed value `|delta_y|`, and the elementwise Gamma log-density
`logp = logpdf(Gamma(mu, sigma), |delta_y|)`. Returns a named tuple
`(; mu, observed, logp)`.
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
    cost_per_target_penalties(gathered_cpt, targets, sigma)

Compute the Abacus cost-per-target Gaussian soft-penalty term elementwise,
`-(|gathered_cpt - targets|)^2 / (2 * sigma^2)`, mirroring
`abacus.mmm.calibration.graph.add_cost_per_target_potentials`.
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

Sum [`cost_per_target_penalties`](@ref) into the scalar value Abacus passes
to `pm.Potential`.
"""
function cost_per_target_total_penalty(
        gathered_cpt::AbstractVector{<:Real},
        targets::AbstractVector{<:Real},
        sigma::AbstractVector{<:Real},
    )
    return sum(cost_per_target_penalties(gathered_cpt, targets, sigma))
end
