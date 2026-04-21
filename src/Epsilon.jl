module Epsilon

export deserialize_model_config
export deserialize_prior
export EpsilonPrior
export expand_masked_values
export After
export Before
export AbstractMMMModel
export AbstractModel
export AbstractRegressionModel
export build_model
export fit!
export active_count
export binomial_adstock
export ConvMode
export Overlap
export FinnishHorseshoePrior
export finnish_horseshoe_coefficients
export LaplacePrior
export LogNormalPrior
export MaxAbsScaleChannels
export MaxAbsScaleTarget
export MaxAbsScaler
export MaskedPrior
export ModelConfigError
export HorseshoePrior
export horseshoe_coefficients
export Scaled
export SkewStudentT
export R2D2Prior
export r2d2_coefficients
export r2d2_variance_weights
export regularized_local_scales
export StandardizeControls
export StandardScaler
export WeibullType
export batched_convolution
export delayed_adstock
export epsilon_version
export geometric_adstock
export hill_function
export instantiate_distribution
export inverse_transform
export logistic_saturation
export max_abs_scale_channel_data
export max_abs_scale_target_data
export michaelis_menten
export MMMData
export MMMModelSpec
export ModelConfig
export model_config_from_dict
export ModelFitState
export normalize_channel_columns
export nobs
export load_model_config
export load_public_config
export load_sampler_config
export SamplerConfig
export sampler_config_from_dict
export standardize_control_data
export tanh_saturation
export TimeSeriesMMM
export transform
export fit_transform!
export predict
export validate_channel_values
export validate_column_indices
export validate_model_config
export validate_mmm_data
export validate_sampler_config
export validate_target_data
export weibull_adstock

include("distributions/priors.jl")
include("distributions/special.jl")
include("distributions/masked.jl")
include("distributions/shrinkage.jl")
include("model/types.jl")
include("model/config.jl")
include("model/builder.jl")
include("transforms/convolution.jl")
include("transforms/adstock.jl")
include("transforms/saturation.jl")
include("transforms/scaling.jl")

"""
    epsilon_version()

Return the installed Epsilon package version.
"""
epsilon_version() = pkgversion(@__MODULE__)

end
