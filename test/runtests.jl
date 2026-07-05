using Aqua
using Documenter
using Epsilon
using Test

const _REQUESTED_TEST_LAYERS = Set(Symbol.(ARGS))
_run_test_layer(name::Symbol) = isempty(_REQUESTED_TEST_LAYERS) || name in _REQUESTED_TEST_LAYERS

@testset "Epsilon.jl" begin
    _run_test_layer(:basic) && include("basic.jl")
    _run_test_layer(:distributions) && include("distributions/runtests.jl")
    _run_test_layer(:model) && include("model/runtests.jl")
    _run_test_layer(:inference) && include("inference/runtests.jl")
    _run_test_layer(:postmodel) && include("postmodel/runtests.jl")
    if _run_test_layer(:optimization)
        include("model/sample_models.jl")
        include("optimization/runtests.jl")
    end
    _run_test_layer(:scenario_planner) && include("scenario_planner.jl")
    _run_test_layer(:pipeline) && include("pipeline/runtests.jl")
    _run_test_layer(:plotting) && include("plotting/runtests.jl")
    if _run_test_layer(:validation)
        include("model/sample_models.jl")
        include("validation/runtests.jl")
    end
    _run_test_layer(:transforms) && include("transforms/runtests.jl")
    if isempty(_REQUESTED_TEST_LAYERS)
        Aqua.test_all(Epsilon; ambiguities = false)
        doctest(Epsilon; manual = false)
    end
end
