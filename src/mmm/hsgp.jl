using Dates
using Statistics

struct _HSGPMediaPriorSnapshot
    distribution::Symbol
    parameters::Tuple{Vararg{Tuple{Symbol, Float64}}}
end

struct _HSGPMediaConfigSnapshot
    m::Int
    L::Float64
    time_resolution::Int
    covariance::Symbol
    eta_prior::_HSGPMediaPriorSnapshot
    lengthscale_prior::_HSGPMediaPriorSnapshot
end

struct _HSGPTimeSeriesTrainingState
    training_origin::Date
    time_resolution::Int
    training_indices::Tuple{Vararg{Int}}
    training_centre::Float64
    m::Int
    L::Float64
    covariance::Symbol
    drop_first::Bool
    demeaned_basis::Bool
end

struct _HSGPMediaSpecState
    config::_HSGPMediaConfigSnapshot
    training::_HSGPTimeSeriesTrainingState
end

function _hsgp_media_prior_snapshot(prior::EpsilonPrior, name::AbstractString)
    _validate_hsgp_media_prior(prior, name)
    parameters = if prior.distribution == "Exponential"
        value = only(prior.parameters[key] for key in (:lam, :lambda, :rate) if haskey(prior.parameters, key))
        ((:lam, Float64(value)),)
    elseif prior.distribution == "Gamma"
        beta_key = haskey(prior.parameters, :beta) ? :beta : :rate
        ((:alpha, Float64(prior.parameters[:alpha])), (:beta, Float64(prior.parameters[beta_key])))
    elseif prior.distribution == "HalfNormal"
        ((:sigma, Float64(prior.parameters[:sigma])),)
    else
        mu = get(prior.parameters, :mu, 0.0)
        ((:mu, Float64(mu)), (:sigma, Float64(prior.parameters[:sigma])))
    end
    return _HSGPMediaPriorSnapshot(Symbol(prior.distribution), parameters)
end

function _instantiate_hsgp_media_prior(snapshot::_HSGPMediaPriorSnapshot)
    parameters = Dict{Symbol, Any}(name => value for (name, value) in snapshot.parameters)
    return instantiate_distribution(EpsilonPrior(String(snapshot.distribution), parameters))
end

function _hsgp_media_config_snapshot(config::TimeVaryingMediaConfig)
    return _HSGPMediaConfigSnapshot(
        config.m,
        config.L,
        config.time_resolution,
        config.covariance,
        _hsgp_media_prior_snapshot(config.eta_prior, "eta_prior"),
        _hsgp_media_prior_snapshot(config.lengthscale_prior, "lengthscale_prior"),
    )
end

function _hsgp_time_series_training_state(config::TimeVaryingMediaConfig, dates)
    dates isa AbstractVector || throw(ArgumentError("time_varying_media requires MMMData.dates to be a Date vector"))
    all(date -> date isa Date, dates) ||
        throw(ArgumentError("time_varying_media requires MMMData.dates to contain only Date values"))
    training_dates = Date[date for date in dates]
    isempty(training_dates) && throw(ArgumentError("time_varying_media requires at least one training date"))
    training_indices = _infer_hsgp_time_index(
        training_dates,
        training_dates;
        time_resolution = config.time_resolution,
    )
    training_centre = minimum(training_indices) / 2 + maximum(training_indices) / 2
    return _HSGPTimeSeriesTrainingState(
        first(training_dates),
        config.time_resolution,
        Tuple(training_indices),
        Float64(training_centre),
        config.m,
        config.L,
        config.covariance,
        false,
        false,
    )
end

function _hsgp_media_spec_state(config::TimeVaryingMediaConfig, data::MMMData)
    return _HSGPMediaSpecState(
        _hsgp_media_config_snapshot(config),
        _hsgp_time_series_training_state(config, data.dates),
    )
end

function _validate_hsgp_media_training_data(config::ModelConfig, data::MMMData)
    time_varying_media = _time_varying_media_config(config)
    isnothing(time_varying_media) && return nothing
    _hsgp_time_series_training_state(time_varying_media, data.dates)
    return nothing
end

function _hsgp_media_current_indices(indices)
    indices isa AbstractVector || throw(
        ArgumentError("current HSGP indices must be a one-dimensional integer vector"),
    )
    isempty(indices) && throw(ArgumentError("current HSGP indices must not be empty"))
    all(index -> index isa Integer && !(index isa Bool), indices) || throw(
        ArgumentError("current HSGP indices must contain only integers"),
    )

    try
        return Int.(indices)
    catch err
        err isa InexactError || rethrow()
        throw(ArgumentError("current HSGP indices must fit in Int"))
    end
end

function _validate_hsgp_media_spec_state(state::_HSGPMediaSpecState)
    config = state.config
    training = state.training
    config.m == training.m || throw(ArgumentError("HSGP media state mode counts must match"))
    config.L == training.L || throw(ArgumentError("HSGP media state boundaries must match"))
    config.covariance == training.covariance || throw(
        ArgumentError("HSGP media state covariances must match"),
    )
    config.time_resolution == training.time_resolution || throw(
        ArgumentError("HSGP media state cadence resolutions must match"),
    )
    !training.drop_first || throw(ArgumentError("HSGP media state must retain the first mode"))
    !training.demeaned_basis || throw(ArgumentError("HSGP media state must use an undemeaned basis"))
    training.training_indices isa Tuple || throw(
        ArgumentError("HSGP training indices must be stored as an immutable tuple"),
    )
    isempty(training.training_indices) && throw(ArgumentError("HSGP training indices must not be empty"))
    all(index -> index isa Int, training.training_indices) || throw(
        ArgumentError("HSGP training indices must contain only Int values"),
    )
    _hsgp_finite_scalar(training.training_centre, "training_centre")
    _hsgp_mode_count(config.m)
    _hsgp_positive_finite(config.L, "L")
    _hsgp_covariance_constants(config.covariance)
    return state
end

function _hsgp_media_multiplier(
        state::_HSGPMediaSpecState,
        current_indices,
        eta,
        lengthscale,
        z,
    )
    _validate_hsgp_media_spec_state(state)
    indices = _hsgp_media_current_indices(current_indices)
    _hsgp_positive_finite(eta, "eta")
    _hsgp_positive_finite(lengthscale, "lengthscale")
    _hsgp_finite_vector(z, "z")
    length(z) == state.config.m || throw(
        ArgumentError("z must have one value for each configured HSGP mode"),
    )

    sqrt_psd = _hsgp_sqrt_psd(
        state.config.m,
        state.config.L;
        covariance = state.config.covariance,
        eta,
        lengthscale,
        drop_first = state.training.drop_first,
    )
    training_phi = _hsgp_basis_matrix_at_centre(
        collect(state.training.training_indices),
        state.training.training_centre;
        m = state.training.m,
        L = state.training.L,
        drop_first = state.training.drop_first,
    )
    current_phi = _hsgp_basis_matrix_at_centre(
        indices,
        state.training.training_centre;
        m = state.training.m,
        L = state.training.L,
        drop_first = state.training.drop_first,
    )
    training_raw = _hsgp_stable_softplus.(_hsgp_latent(training_phi, sqrt_psd, z))
    training_raw_mean = mean(training_raw)
    isfinite(training_raw_mean) && training_raw_mean > zero(training_raw_mean) || throw(
        ArgumentError("HSGP training softplus mean must be finite and strictly positive"),
    )
    multiplier = _hsgp_stable_softplus.(_hsgp_latent(current_phi, sqrt_psd, z)) ./
        training_raw_mean
    all(value -> isfinite(value) && value > zero(value), multiplier) || throw(
        ArgumentError("HSGP media multipliers must be finite and strictly positive"),
    )
    return multiplier
end

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

function _hsgp_basis_matrix_at_centre(
        x,
        centre;
        m,
        L,
        drop_first::Bool = false,
    )::Matrix{Float64}
    values = _hsgp_finite_vector(x, "x")
    _hsgp_finite_scalar(centre, "centre")
    boundary = Float64(_hsgp_positive_finite(L, "L"))
    frequencies = _hsgp_frequencies(m, boundary; drop_first = drop_first)
    numeric_values = Float64.(values)
    all(isfinite, numeric_values) || throw(
        ArgumentError("x must be representable as finite Float64 values"),
    )
    numeric_centre = Float64(centre)
    isfinite(numeric_centre) || throw(
        ArgumentError("centre must be representable as a finite Float64 value"),
    )
    scaled_inputs = numeric_values ./ boundary .- numeric_centre / boundary .+ 1
    all(isfinite, scaled_inputs) || throw(
        ArgumentError("x, centre, and L produce non-finite scaled HSGP coordinates"),
    )
    phi = inv(sqrt(boundary)) .* sin.(
        scaled_inputs .* permutedims(frequencies .* boundary),
    )
    all(isfinite, phi) || throw(
        ArgumentError("x, centre, and L produce a non-finite HSGP basis"),
    )
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

struct _HSGPPositiveMultiplierState{
        L,
        C,
        O,
        W,
        M,
    }
    m::Int
    L::L
    drop_first::Bool
    demeaned_basis::Bool
    training_centre::C
    basis_offset::O
    weighted_coefficients::W
    weighted_coefficient_type::Type
    weighted_coefficient_size::Tuple{Int, Int}
    weighted_coefficients_are_matrix::Bool
    training_raw_mean::M
end

function _hsgp_weighted_coefficients(sqrt_psd, z, retained_modes)
    weights = _hsgp_nonnegative_weights(sqrt_psd)
    length(weights) == retained_modes || throw(
        ArgumentError("sqrt_psd must have one value for each retained HSGP mode"),
    )

    if z isa AbstractVector
        all(value -> value isa Real && !(value isa Bool) && isfinite(value), z) || throw(
            ArgumentError("z must contain only finite real values"),
        )
        length(z) == retained_modes || throw(
            ArgumentError("sqrt_psd and z must have matching retained-mode counts"),
        )
        weighted_coefficients = copy(weights .* z)
        return (
            Tuple(weighted_coefficients),
            eltype(weighted_coefficients),
            (length(weighted_coefficients), 1),
            false,
        )
    elseif z isa AbstractMatrix
        size(z, 2) >= 1 || throw(ArgumentError("matrix z must have at least one series column"))
        all(value -> value isa Real && !(value isa Bool) && isfinite(value), z) || throw(
            ArgumentError("z must contain only finite real values"),
        )
        size(z, 1) == retained_modes || throw(
            ArgumentError("sqrt_psd and z must have matching retained-mode counts"),
        )
        weighted_coefficients = copy(weights .* z)
        return (
            Tuple(weighted_coefficients),
            eltype(weighted_coefficients),
            size(weighted_coefficients),
            true,
        )
    end

    throw(ArgumentError("z must be a numeric vector or matrix"))
end

function _hsgp_materialize_weighted_coefficients(state::_HSGPPositiveMultiplierState)
    weighted_coefficients = collect(
        state.weighted_coefficient_type,
        state.weighted_coefficients,
    )
    if state.weighted_coefficients_are_matrix
        return reshape(weighted_coefficients, state.weighted_coefficient_size)
    end
    return weighted_coefficients
end

function _hsgp_materialize_training_raw_mean(state::_HSGPPositiveMultiplierState)
    training_raw_mean = collect(state.training_raw_mean)
    if state.weighted_coefficients_are_matrix
        return reshape(training_raw_mean, 1, state.weighted_coefficient_size[2])
    end
    return training_raw_mean
end

function _hsgp_validate_positive_multiplier_state(state::_HSGPPositiveMultiplierState)
    retained_modes = length(
        _hsgp_frequencies(state.m, state.L; drop_first = state.drop_first),
    )
    _hsgp_finite_scalar(state.training_centre, "training_centre")

    if state.demeaned_basis
        state.basis_offset isa Tuple || throw(
            ArgumentError("demeaned HSGP state must store an immutable basis offset tuple"),
        )
        length(state.basis_offset) == retained_modes || throw(
            ArgumentError("HSGP basis offset must match retained-mode count"),
        )
        all(value -> value isa Real && !(value isa Bool) && isfinite(value), state.basis_offset) || throw(
            ArgumentError("HSGP basis offset must contain only finite real values"),
        )
    else
        isnothing(state.basis_offset) || throw(
            ArgumentError("non-demeaned HSGP state must not store a basis offset"),
        )
    end

    coefficients = state.weighted_coefficients
    coefficients isa Tuple || throw(
        ArgumentError("HSGP weighted coefficients must be stored as an immutable tuple"),
    )
    state.weighted_coefficient_type <: Real && state.weighted_coefficient_type !== Bool || throw(
        ArgumentError("HSGP weighted coefficient type must be a real numeric type"),
    )
    all(value -> value isa state.weighted_coefficient_type, coefficients) || throw(
        ArgumentError("HSGP weighted coefficient values must match their stored type"),
    )
    retained_size, series_count = state.weighted_coefficient_size
    retained_size == retained_modes || throw(
        ArgumentError("HSGP weighted coefficients must match retained-mode count"),
    )
    series_count >= 1 || throw(
        ArgumentError("HSGP weighted coefficients must have at least one series column"),
    )
    length(coefficients) == retained_size * series_count || throw(
        ArgumentError("HSGP weighted coefficient data must match its stored size"),
    )
    !state.weighted_coefficients_are_matrix && series_count != 1 && throw(
        ArgumentError("vector HSGP weighted coefficients must have one series column"),
    )
    all(value -> value isa Real && !(value isa Bool) && isfinite(value), coefficients) || throw(
        ArgumentError("HSGP weighted coefficients must contain only finite real values"),
    )

    denominator = state.training_raw_mean
    denominator isa Tuple || throw(
        ArgumentError("HSGP training raw-softplus means must be stored as an immutable tuple"),
    )
    expected_denominator_count = state.weighted_coefficients_are_matrix ? series_count : 1
    length(denominator) == expected_denominator_count || throw(
        ArgumentError("HSGP training raw-softplus means must match the coefficient series count"),
    )
    all(value -> value isa Real && !(value isa Bool) && isfinite(value) && value > zero(value), denominator) || throw(
        ArgumentError("HSGP training raw-softplus means must be finite and strictly positive"),
    )
    return state
end

function _fit_hsgp_positive_multiplier_state(
        x_training,
        sqrt_psd,
        z;
        m,
        L,
        drop_first::Bool = false,
        demeaned_basis::Bool = false,
    )
    values = _hsgp_finite_vector(x_training, "x_training")
    boundary = Float64(_hsgp_positive_finite(L, "L"))
    retained_modes = length(_hsgp_frequencies(m, boundary; drop_first = drop_first))
    numeric_values = Float64.(values)
    all(isfinite, numeric_values) || throw(
        ArgumentError("x_training must be representable as finite Float64 values"),
    )
    training_centre = minimum(numeric_values) / 2 + maximum(numeric_values) / 2
    phi_raw = _hsgp_basis_matrix_at_centre(
        values,
        training_centre;
        m = m,
        L = boundary,
        drop_first = drop_first,
    )
    basis_offset = demeaned_basis ? copy(vec(mean(phi_raw; dims = 1))) : nothing
    phi = isnothing(basis_offset) ? phi_raw : phi_raw .- permutedims(basis_offset)
    weighted_coefficients, weighted_coefficient_type, weighted_coefficient_size, weighted_coefficients_are_matrix =
        _hsgp_weighted_coefficients(sqrt_psd, z, retained_modes)
    weighted_coefficients_local = collect(weighted_coefficient_type, weighted_coefficients)
    if weighted_coefficients_are_matrix
        weighted_coefficients_local = reshape(
            weighted_coefficients_local,
            weighted_coefficient_size,
        )
    end
    latent = phi * weighted_coefficients_local
    all(isfinite, latent) || throw(ArgumentError("HSGP latent values must be finite"))
    raw = _hsgp_stable_softplus.(latent)
    all(value -> isfinite(value) && value > zero(value), raw) || throw(
        ArgumentError("HSGP softplus values must be finite and strictly positive"),
    )
    training_raw_mean = Tuple(copy(mean(raw; dims = 1)))
    all(value -> isfinite(value) && value > zero(value), training_raw_mean) || throw(
        ArgumentError("HSGP softplus means must be finite and strictly positive"),
    )

    state = _HSGPPositiveMultiplierState(
        _hsgp_mode_count(m),
        boundary,
        drop_first,
        demeaned_basis,
        training_centre,
        isnothing(basis_offset) ? nothing : Tuple(basis_offset),
        weighted_coefficients,
        weighted_coefficient_type,
        weighted_coefficient_size,
        weighted_coefficients_are_matrix,
        training_raw_mean,
    )
    return _hsgp_validate_positive_multiplier_state(state)
end

function _hsgp_replay_positive_multiplier(x, state::_HSGPPositiveMultiplierState)
    _hsgp_validate_positive_multiplier_state(state)
    phi = _hsgp_basis_matrix_at_centre(
        x,
        state.training_centre;
        m = state.m,
        L = state.L,
        drop_first = state.drop_first,
    )
    if !isnothing(state.basis_offset) && !isempty(state.basis_offset)
        phi .-= permutedims(collect(state.basis_offset))
    end
    weighted_coefficients = _hsgp_materialize_weighted_coefficients(state)
    training_raw_mean = _hsgp_materialize_training_raw_mean(state)
    latent = phi * weighted_coefficients
    all(isfinite, latent) || throw(ArgumentError("HSGP latent values must be finite"))
    raw = _hsgp_stable_softplus.(latent)
    all(value -> isfinite(value) && value > zero(value), raw) || throw(
        ArgumentError("HSGP softplus values must be finite and strictly positive"),
    )
    multiplier = raw ./ training_raw_mean
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
