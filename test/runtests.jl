using Aqua
using Documenter
using Epsilon
using Test

const _TEST_LAYERS = Set(
    (
        :api_exports,
        :basic,
        :distributions,
        :inference,
        :model,
        :optimization,
        :pipeline,
        :plotting,
        :postmodel,
        :scenario_planner,
        :transforms,
        :validation,
    )
)
const _TEST_ROOT = @__DIR__
const _TEST_REAL_ROOT = realpath(_TEST_ROOT)
const _RUNTESTS_PATH = normpath(abspath(@__FILE__))
const _RUNTESTS_REAL_PATH = realpath(@__FILE__)

function _path_is_under(path::AbstractString, root::AbstractString)
    relative = relpath(path, root)
    return relative != ".." && !startswith(relative, string("..", Base.Filesystem.path_separator))
end

function _selector_components(selector::AbstractString)
    normalised = replace(String(selector), '\\' => '/')
    parts = filter(!isempty, split(normalised, '/'))
    if !isempty(parts) && first(parts) == "test"
        popfirst!(parts)
    end
    return parts
end

function _normalise_test_file_selector(selector::AbstractString)
    raw = String(selector)
    !isempty(raw) || throw(ArgumentError("test file selector must not be empty"))

    candidate = if isabspath(raw)
        normpath(abspath(raw))
    else
        parts = _selector_components(raw)
        !isempty(parts) || throw(ArgumentError("test file selector must name a file under test/"))
        !any(==(".."), parts) ||
            throw(ArgumentError("test file selector must not use parent traversal: $(raw)"))
        unresolved = normpath(joinpath(_TEST_ROOT, parts...))
        isdir(unresolved) && throw(ArgumentError("test file selector must name a file, got directory: $(raw)"))
        if !endswith(last(parts), ".jl")
            parts[end] = string(parts[end], ".jl")
        end
        normpath(joinpath(_TEST_ROOT, parts...))
    end

    _path_is_under(candidate, _TEST_ROOT) ||
        throw(ArgumentError("test file selector must resolve under test/: $(raw)"))
    candidate != _RUNTESTS_PATH ||
        throw(ArgumentError("test/runtests.jl cannot be selected recursively"))
    isfile(candidate) ||
        throw(ArgumentError("test file selector does not resolve to an existing file: $(raw)"))
    real_candidate = realpath(candidate)
    real_candidate != _RUNTESTS_REAL_PATH ||
        throw(ArgumentError("test/runtests.jl cannot be selected recursively"))
    _path_is_under(real_candidate, _TEST_REAL_ROOT) ||
        throw(ArgumentError("test file selector must resolve under test/: $(raw)"))
    return candidate
end

function _looks_like_file_selector(selector::AbstractString)
    return occursin("/", selector) ||
        occursin("\\", selector) ||
        endswith(selector, ".jl") ||
        startswith(selector, ".")
end

function _resolve_test_selection(args::Vector{String})
    isempty(args) && return (mode = :all, layers = Set{Symbol}(), files = String[])

    layer_args = String[]
    file_args = String[]
    unknown_args = String[]
    for arg in args
        symbol = Symbol(arg)
        if symbol in _TEST_LAYERS
            push!(layer_args, arg)
        elseif _looks_like_file_selector(arg)
            push!(file_args, arg)
        else
            push!(unknown_args, arg)
        end
    end

    isempty(unknown_args) ||
        throw(ArgumentError("unknown test selector(s): $(join(unknown_args, ", "))"))
    if !isempty(layer_args) && !isempty(file_args)
        throw(ArgumentError("cannot mix test layer selectors and test file selectors"))
    end
    if !isempty(file_args)
        files = unique(_normalise_test_file_selector.(file_args))
        return (mode = :files, layers = Set{Symbol}(), files = files)
    end
    return (mode = :layers, layers = Set(Symbol.(layer_args)), files = String[])
end

const _REQUESTED_TEST_SELECTION = _resolve_test_selection(String.(ARGS))

_run_test_layer(name::Symbol) =
    _REQUESTED_TEST_SELECTION.mode === :all ||
    (_REQUESTED_TEST_SELECTION.mode === :layers && name in _REQUESTED_TEST_SELECTION.layers)

@testset "Epsilon.jl" begin
    if _REQUESTED_TEST_SELECTION.mode === :files
        for file in _REQUESTED_TEST_SELECTION.files
            include(file)
        end
    else
        _run_test_layer(:basic) && include("basic.jl")
        _run_test_layer(:api_exports) && include("api_exports.jl")
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
    end

    if _REQUESTED_TEST_SELECTION.mode === :all
        Aqua.test_all(Epsilon; ambiguities = false)
        doctest(Epsilon; manual = false)
    end
end
