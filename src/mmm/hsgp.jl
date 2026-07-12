using Dates
using Statistics

function _infer_hsgp_time_index(
        new_dates::AbstractVector{<:Date},
        training_dates::AbstractVector{<:Date};
        time_resolution::Integer,
    )::Vector{Int}
    isempty(training_dates) && throw(ArgumentError("training_dates must not be empty"))
    time_resolution > 0 || throw(ArgumentError("time_resolution must be a positive integer"))
    isempty(new_dates) && return Int[]

    origin = first(training_dates)
    time_index = Vector{Int}(undef, length(new_dates))
    for (index, new_date) in pairs(new_dates)
        day_offset = Dates.value(new_date - origin)
        rem(day_offset, time_resolution) == 0 || throw(
            ArgumentError("new_dates must align to the fitted cadence"),
        )
        time_index[index] = div(day_offset, time_resolution)
    end

    return time_index
end

function _hsgp_mode_count(m)
    m isa Integer || throw(ArgumentError("m must be a positive integer"))
    m >= 1 || throw(ArgumentError("m must be a positive integer"))

    try
        return Int(m)
    catch err
        err isa InexactError || rethrow()
        throw(ArgumentError("m must fit in Int"))
    end
end

function _hsgp_positive_finite(value, name::AbstractString)
    _hsgp_finite_scalar(value, name)
    isfinite(value) && value > zero(value) || throw(
        ArgumentError("$name must be a finite positive real number"),
    )
    return value
end

function _hsgp_finite_scalar(value, name::AbstractString)
    value isa Real && !(value isa Bool) || throw(
        ArgumentError("$name must be a finite real number"),
    )
    isfinite(value) || throw(ArgumentError("$name must be a finite real number"))
    return value
end

function _hsgp_finite_vector(x, name::AbstractString)
    x isa AbstractVector || throw(ArgumentError("$name must be a one-dimensional numeric vector"))
    isempty(x) && throw(ArgumentError("$name must not be empty"))
    all(value -> value isa Real && !(value isa Bool) && isfinite(value), x) || throw(
        ArgumentError("$name must contain only finite real values"),
    )
    return x
end

function _hsgp_finite_matrix(x, name::AbstractString)
    x isa AbstractMatrix || throw(ArgumentError("$name must be a two-dimensional numeric matrix"))
    size(x, 1) >= 1 || throw(ArgumentError("$name must have at least one row"))
    all(value -> value isa Real && !(value isa Bool) && isfinite(value), x) || throw(
        ArgumentError("$name must contain only finite real values"),
    )
    return x
end

function _hsgp_nonnegative_weights(sqrt_psd)
    sqrt_psd isa AbstractVector || throw(ArgumentError("sqrt_psd must be a numeric vector"))
    all(value -> value isa Real && !(value isa Bool) && isfinite(value), sqrt_psd) || throw(
        ArgumentError("sqrt_psd must contain only finite real values"),
    )
    all(value -> value >= zero(value), sqrt_psd) || throw(
        ArgumentError("sqrt_psd must contain only non-negative values"),
    )
    return sqrt_psd
end

function _hsgp_covariance_constants(covariance)
    covariance === :expquad && return (3.2, 1.75)
    covariance === :matern52 && return (4.1, 2.65)
    covariance === :matern32 && return (4.5, 3.42)
    throw(ArgumentError("covariance must be :expquad, :matern32, or :matern52"))
end

function _hsgp_logaddexp(left, right)
    maximum_value = max(left, right)
    return maximum_value + log(exp(left - maximum_value) + exp(right - maximum_value))
end

function _hsgp_frequencies(m, L; drop_first::Bool = false)::Vector{Float64}
    mode_count = _hsgp_mode_count(m)
    boundary = try
        Float64(_hsgp_positive_finite(L, "L"))
    catch err
        err isa InexactError || rethrow()
        throw(ArgumentError("L must be representable as a finite Float64"))
    end
    isfinite(boundary) && boundary > 0 || throw(
        ArgumentError("L must be representable as a finite Float64"),
    )
    frequencies = (π / boundary) .* (Float64.(1:mode_count) ./ 2)
    all(isfinite, frequencies) || throw(
        ArgumentError("L produces non-finite HSGP frequencies"),
    )
    return drop_first ? frequencies[2:end] : frequencies
end

function _hsgp_basis_matrix(
        x;
        m,
        L,
        drop_first::Bool = false,
        demeaned_basis::Bool = false,
    )::Matrix{Float64}
    values = _hsgp_finite_vector(x, "x")
    boundary = Float64(_hsgp_positive_finite(L, "L"))
    frequencies = _hsgp_frequencies(m, boundary; drop_first = drop_first)
    numeric_values = Float64.(values)
    all(isfinite, numeric_values) || throw(
        ArgumentError("x must be representable as finite Float64 values"),
    )
    centre = minimum(numeric_values) / 2 + maximum(numeric_values) / 2
    scaled_inputs = numeric_values ./ boundary .- centre / boundary .+ 1
    all(isfinite, scaled_inputs) || throw(
        ArgumentError("x and L produce non-finite scaled HSGP coordinates"),
    )
    phi = inv(sqrt(boundary)) .* sin.(
        scaled_inputs .* permutedims(frequencies .* boundary),
    )

    demeaned_basis && (phi .-= mean(phi; dims = 1))
    all(isfinite, phi) || throw(ArgumentError("x and L produce a non-finite HSGP basis"))
    return phi
end

function _hsgp_sqrt_psd(
        m,
        L;
        covariance,
        eta,
        lengthscale,
        drop_first::Bool = false,
    )
    frequencies = _hsgp_frequencies(m, L; drop_first = drop_first)
    _hsgp_covariance_constants(covariance)
    _hsgp_positive_finite(eta, "eta")
    _hsgp_positive_finite(lengthscale, "lengthscale")

    weights = map(frequencies) do omega
        scaled_frequency = lengthscale * omega
        log_amplitude = log(eta) + log(lengthscale) / 2
        if covariance === :expquad
            exp(log_amplitude + log(sqrt(sqrt(2 * π))) - 0.25 * scaled_frequency^2)
        elseif covariance === :matern32
            log_denominator = _hsgp_logaddexp(log(3), 2 * (log(lengthscale) + log(omega)))
            exp(log_amplitude + log(sqrt(12 * sqrt(3))) - log_denominator)
        else
            log_denominator = _hsgp_logaddexp(log(5), 2 * (log(lengthscale) + log(omega)))
            exp(log_amplitude + log(sqrt(400 * sqrt(5) / 3)) - 3 * log_denominator / 2)
        end
    end
    all(isfinite, weights) || throw(ArgumentError("HSGP PSD weights must be finite"))
    return weights
end

function _hsgp_latent(phi, sqrt_psd, z)
    basis = _hsgp_finite_matrix(phi, "phi")
    weights = _hsgp_nonnegative_weights(sqrt_psd)
    retained_modes = size(basis, 2)
    length(weights) == retained_modes || throw(
        ArgumentError("phi and sqrt_psd must have matching retained-mode counts"),
    )

    if z isa AbstractVector
        all(value -> value isa Real && !(value isa Bool) && isfinite(value), z) || throw(
            ArgumentError("z must contain only finite real values"),
        )
        length(z) == retained_modes || throw(
            ArgumentError("sqrt_psd and z must have matching retained-mode counts"),
        )
        latent = basis * (weights .* z)
    elseif z isa AbstractMatrix
        size(z, 2) >= 1 || throw(ArgumentError("matrix z must have at least one series column"))
        all(value -> value isa Real && !(value isa Bool) && isfinite(value), z) || throw(
            ArgumentError("z must contain only finite real values"),
        )
        size(z, 1) == retained_modes || throw(
            ArgumentError("sqrt_psd and z must have matching retained-mode counts"),
        )
        latent = basis * (weights .* z)
    else
        throw(ArgumentError("z must be a numeric vector or matrix"))
    end

    all(isfinite, latent) || throw(ArgumentError("HSGP latent values must be finite"))
    return latent
end

function _hsgp_stable_softplus(value)
    _hsgp_finite_scalar(value, "latent value")
    value < -37 && return exp(value)
    value < 18 && return log1p(exp(value))
    value < 33.3 && return value + exp(-value)
    return value
end

function _hsgp_positive_multiplier(phi, sqrt_psd, z)
    latent = _hsgp_latent(phi, sqrt_psd, z)
    raw = _hsgp_stable_softplus.(latent)
    all(value -> isfinite(value) && value > zero(value), raw) || throw(
        ArgumentError("HSGP softplus values must be finite and strictly positive"),
    )
    raw_mean = mean(raw; dims = 1)
    all(value -> isfinite(value) && value > zero(value), raw_mean) || throw(
        ArgumentError("HSGP softplus means must be finite and strictly positive"),
    )
    multiplier = raw ./ raw_mean
    all(value -> isfinite(value) && value > zero(value), multiplier) || throw(
        ArgumentError("HSGP multipliers must be finite and strictly positive"),
    )
    return multiplier
end

function _approx_hsgp_hyperparams(
        x,
        x_center;
        lengthscale_range,
        covariance,
    )
    values = _hsgp_finite_vector(x, "x")
    _hsgp_finite_scalar(x_center, "x_center")
    lengthscale_range isa Tuple && length(lengthscale_range) == 2 || throw(
        ArgumentError("lengthscale_range must contain lower and upper bounds"),
    )
    lengthscale_lower, lengthscale_upper = lengthscale_range
    _hsgp_positive_finite(lengthscale_lower, "lengthscale_lower")
    _hsgp_positive_finite(lengthscale_upper, "lengthscale_upper")
    lengthscale_lower < lengthscale_upper || throw(
        ArgumentError("lengthscale_lower must be less than lengthscale_upper"),
    )
    minimum(values) < maximum(values) || throw(ArgumentError("x must have non-zero span"))

    a1, a2 = _hsgp_covariance_constants(covariance)
    span = maximum(abs.(values .- x_center))
    span > zero(span) || throw(ArgumentError("x must have non-zero centred span"))
    c = max(a1 * lengthscale_upper / span, 1.2)
    isfinite(c) || throw(ArgumentError("recommended c must be finite"))
    mode_proposal = a2 * c * span / lengthscale_lower
    isfinite(mode_proposal) && mode_proposal <= typemax(Int) || throw(
        ArgumentError("recommended m must fit in Int"),
    )
    m = floor(Int, mode_proposal)
    m >= 1 || throw(ArgumentError("recommended m must be positive"))
    return m, c
end

function _recommend_hsgp_basis(
        x,
        x_mid;
        lengthscale_lower,
        lengthscale_upper = nothing,
        covariance,
    )
    _hsgp_positive_finite(x_mid, "x_mid")
    resolved_upper = isnothing(lengthscale_upper) ? 2 * x_mid : lengthscale_upper
    m, c = _approx_hsgp_hyperparams(
        x,
        x_mid;
        lengthscale_range = (lengthscale_lower, resolved_upper),
        covariance = covariance,
    )
    boundary = c * x_mid
    isfinite(boundary) && boundary > zero(boundary) || throw(
        ArgumentError("recommended L must be finite and positive"),
    )
    return m, boundary
end
