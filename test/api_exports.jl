using Test
using Epsilon
using TOML

const API_EXPORTS_DOC_PATH = joinpath(@__DIR__, "..", "docs", "src", "api.md")
const API_EXPORTS_DOCS_SRC_PATH = joinpath(@__DIR__, "..", "docs", "src")
const API_EXPORTS_CURRENT_DOCS_CLAIM_GUARD_PATHS = Dict(
    "docs index" => joinpath(@__DIR__, "..", "docs", "src", "index.md"),
    "release gate" => joinpath(@__DIR__, "..", "docs", "src", "release.md"),
    "supported paths" => joinpath(@__DIR__, "..", "docs", "src", "supported_paths.md"),
)
const API_EXPORTS_PUBLIC_IDENTITY_GUARD_PATHS = Dict(
    "readme" => joinpath(@__DIR__, "..", "README.md"),
    "changelog" => joinpath(@__DIR__, "..", "CHANGELOG.md"),
    "contributing" => joinpath(@__DIR__, "..", "CONTRIBUTING.md"),
    "technical standards" => joinpath(@__DIR__, "..", "TECHNICAL-STANDARDS.md"),
    "docs index" => joinpath(@__DIR__, "..", "docs", "src", "index.md"),
    "release gate" => joinpath(@__DIR__, "..", "docs", "src", "release.md"),
    "api docs" => joinpath(@__DIR__, "..", "docs", "src", "api.md"),
    "calibration docs" => joinpath(@__DIR__, "..", "docs", "src", "calibration.md"),
    "supported paths" => joinpath(@__DIR__, "..", "docs", "src", "supported_paths.md"),
    "demo index" => joinpath(@__DIR__, "..", "data", "demo", "README.md"),
    "timeseries demo" => joinpath(@__DIR__, "..", "data", "demo", "timeseries", "README.md"),
    "geo panel demo" => joinpath(@__DIR__, "..", "data", "demo", "geo_panel", "README.md"),
    "geo brand panel demo" => joinpath(@__DIR__, "..", "data", "demo", "geo_brand_panel", "README.md"),
)
const API_EXPORTS_INVENTORY_BEGIN = "<!-- BEGIN PUBLIC API INVENTORY -->"
const API_EXPORTS_INVENTORY_END = "<!-- END PUBLIC API INVENTORY -->"
const API_EXPORTS_ACTIVE_VI_SUPPORT_PATTERNS = Regex[
    r"\bsupported\s+vi\b"i,
    r"\bsupported\s+mcmc\s+and\s+vi\b"i,
    r"\bbounded\s+vi\s+support\b"i,
    r"\bvi\s+is\s+(?:a\s+)?(?:release-)?supported\b"i,
    r"\bvi\s+is\s+supported\s+for\s+v1\b"i,
    r"\badvi\s+is\s+(?:a\s+)?supported\b"i,
    r"\bvariational\s+inference\s+is\s+(?:a\s+)?(?:release-)?supported\b"i,
]
const API_EXPORTS_ALLOWED_VI_CONTEXT_PATTERNS = Regex[
    r"\bunsupported\b"i,
    r"\bout[- ]of[- ]scope\b"i,
    r"\bnot\s+(?:release-)?supported\b"i,
    r"\bnot\s+planned\b"i,
]
const API_EXPORTS_STALE_CURRENT_DOCS_PATTERNS = Regex[
    r"\bphases?\s+\d+\b"i,
    r"\binternal\s+milestone\b"i,
]
const API_EXPORTS_LOCAL_WORKFLOW_CLAIM_SUBJECT_PATTERNS = Regex[
    r"\bworkflow(?:s)?\b"i,
    r"\bsupported[- ]path\b"i,
    r"\blocal\s+workflow\b"i,
    r"\bmake\s+smoke\b"i,
    r"\bsmoke\s+command\b"i,
]
const API_EXPORTS_LOCAL_WORKFLOW_EVIDENCE_PATTERNS = Regex[
    r"\bbenchmark(?:s)?\b"i,
    r"\brelease\s+evidence\b"i,
    r"\brelease\s+gate(?:s)?\b"i,
    Regex("\\b" * "reference[- ]" * "par" * "ity\\b", "i"),
]
const API_EXPORTS_PUBLIC_DEPENDENT_PRODUCT_PATTERNS = Regex[
    r"\bjulia\s+(?:port|clone|wrapper)\b"i,
    r"\b(?:port|clone|wrapper)\s+of\s+\w+"i,
    r"\bbuilt\s+on\s+.+\b"i,
    r"\binformed\s+by\s+\[?\w+\]?\b"i,
    Regex("\\bproduct\\s+" * "par" * "ity\\b", "i"),
    Regex("\\bexternal\\s+" * "reference\\s+" * "implementation\\b", "i"),
    Regex("\\b" * "reference\\s+" * "implementation\\b", "i"),
    Regex("\\bcomparison" * "-backed\\b", "i"),
    Regex("\\b" * "reference" * "-backed\\b", "i"),
    Regex("\\b" * "reference[- ]" * "par" * "ity\\b", "i"),
    r"\bwhere\s+semantics\s+match\b"i,
]
const API_EXPORTS_TRUSTED_LOCAL_ARTIFACT_PATTERNS = Regex[
    r"\.jls\b"i,
    r"\bseriali[sz]ation\s+artifacts\b"i,
    r"\bscenario_store\.jls\b"i,
]
const API_EXPORTS_PORTABLE_OR_UNTRUSTED_ARTIFACT_PATTERNS = Regex[
    r"\bportable\b"i,
    r"\buntrusted\s+input\b"i,
    r"\buntrusted\s+interchange\b"i,
]
const API_EXPORTS_NEGATED_BOUNDARY_CONTEXT_PATTERNS = Regex[
    r"\bnot\b"i,
    r"\bwithout\b"i,
    r"\bno\b"i,
    r"\brather\s+than\b"i,
]

function _api_exports_current_symbols()
    exports = Set(Symbol.(names(Epsilon; all = false, imported = false)))
    delete!(exports, :Epsilon)
    return exports
end

function _api_exports_countmap(values)
    counts = Dict{Symbol, Int}()
    for value in values
        counts[value] = get(counts, value, 0) + 1
    end
    return counts
end

function _api_exports_marked_inventory_table(text::AbstractString)
    begin_offset = findfirst(API_EXPORTS_INVENTORY_BEGIN, text)
    end_offset = findfirst(API_EXPORTS_INVENTORY_END, text)

    @test !isnothing(begin_offset)
    @test !isnothing(end_offset)
    @test first(begin_offset) < first(end_offset)

    start_index = last(begin_offset) + 1
    stop_index = prevind(text, first(end_offset))
    return text[start_index:stop_index]
end

function _api_exports_parse_inventory_rows(table_text::AbstractString)
    rows = split(table_text, '\n')
    nonempty_rows = filter(row -> !isempty(strip(row)), rows)

    @test length(nonempty_rows) >= 2
    @test strip(nonempty_rows[1]) == "| Symbol | Domain | Support |"
    @test strip(nonempty_rows[2]) == "|---|---|---|"

    parsed = NamedTuple{(:symbol, :domain, :support), Tuple{Symbol, String, String}}[]
    for row in nonempty_rows[3:end]
        match_result = match(r"^\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|$", row)
        @test !isnothing(match_result)
        isnothing(match_result) && continue

        domain = strip(match_result.captures[2])
        support = strip(match_result.captures[3])
        @test !isempty(domain)
        @test !isempty(support)

        push!(parsed, (symbol = Symbol(match_result.captures[1]), domain = domain, support = support))
    end

    return parsed
end

function _api_exports_inventory_rows()
    table_text = _api_exports_marked_inventory_table(read(API_EXPORTS_DOC_PATH, String))
    return _api_exports_parse_inventory_rows(table_text)
end

function _api_exports_inventory_symbols()
    return [row.symbol for row in _api_exports_inventory_rows()]
end

function _api_exports_public_symbols()
    exported_symbols = _api_exports_current_symbols()
    inventory_symbols = _api_exports_inventory_symbols()

    @test sort(collect(exported_symbols)) == sort(inventory_symbols)
    return sort(inventory_symbols)
end

function _api_exports_doc_for(symbol::Symbol)
    object = try
        getfield(Epsilon, symbol)
    catch
        return nothing
    end

    doc = try
        Base.Docs.doc(object)
    catch
        return nothing
    end
    isnothing(doc) && return nothing

    rendered = try
        sprint(show, MIME("text/plain"), doc)
    catch
        return nothing
    end

    stripped = strip(rendered)
    isempty(stripped) && return nothing
    return stripped
end

function _api_exports_docs_src_files()
    markdown_paths = String[]
    for (root, _, files) in walkdir(API_EXPORTS_DOCS_SRC_PATH)
        for file in files
            endswith(file, ".md") || continue
            push!(markdown_paths, joinpath(root, file))
        end
    end
    return sort(markdown_paths)
end

function _api_exports_documenter_docs_entries()
    entries = Set{String}()
    for path in _api_exports_docs_src_files()
        in_docs_block = false
        for line in eachline(path)
            stripped = strip(line)
            if in_docs_block
                if startswith(stripped, "```")
                    in_docs_block = false
                else
                    push!(entries, stripped)
                end
            elseif stripped == "```@docs"
                in_docs_block = true
            end
        end
    end
    return entries
end

function _api_exports_normalized_text(path::AbstractString)
    return replace(read(path, String), r"\s+" => " ")
end

function _api_exports_current_docs_claims()
    return Dict(label => _api_exports_normalized_text(path) for (label, path) in API_EXPORTS_CURRENT_DOCS_CLAIM_GUARD_PATHS)
end

function _api_exports_matching_claim_lines(paths, predicate::Function)
    matches = String[]
    repo_root = normpath(joinpath(@__DIR__, ".."))

    for path in values(paths)
        for (line_number, line) in enumerate(eachline(path))
            predicate(line) || continue
            push!(matches, "$(relpath(path, repo_root)):$(line_number):$(strip(line))")
        end
    end

    return sort(matches)
end

function _api_exports_has_any_pattern(line::AbstractString, patterns)
    return any(pattern -> occursin(pattern, line), patterns)
end

function _api_exports_has_allowed_vi_context(line::AbstractString)
    return _api_exports_has_any_pattern(line, API_EXPORTS_ALLOWED_VI_CONTEXT_PATTERNS)
end

function _api_exports_has_active_vi_release_claim(line::AbstractString)
    _api_exports_has_allowed_vi_context(line) && return false
    return _api_exports_has_any_pattern(line, API_EXPORTS_ACTIVE_VI_SUPPORT_PATTERNS)
end

function _api_exports_has_negated_boundary_context(line::AbstractString)
    return _api_exports_has_any_pattern(line, API_EXPORTS_NEGATED_BOUNDARY_CONTEXT_PATTERNS)
end

function _api_exports_has_stale_current_docs_claim(line::AbstractString)
    return _api_exports_has_any_pattern(line, API_EXPORTS_STALE_CURRENT_DOCS_PATTERNS)
end

function _api_exports_has_active_local_workflow_evidence_claim(line::AbstractString)
    _api_exports_has_any_pattern(line, API_EXPORTS_LOCAL_WORKFLOW_CLAIM_SUBJECT_PATTERNS) || return false
    _api_exports_has_any_pattern(line, API_EXPORTS_LOCAL_WORKFLOW_EVIDENCE_PATTERNS) || return false
    return !_api_exports_has_negated_boundary_context(line)
end

function _api_exports_has_active_portable_or_untrusted_artifact_claim(line::AbstractString)
    _api_exports_has_any_pattern(line, API_EXPORTS_TRUSTED_LOCAL_ARTIFACT_PATTERNS) || return false
    _api_exports_has_any_pattern(line, API_EXPORTS_PORTABLE_OR_UNTRUSTED_ARTIFACT_PATTERNS) || return false
    return !_api_exports_has_negated_boundary_context(line)
end

function _api_exports_has_public_dependent_product_claim(line::AbstractString)
    return _api_exports_has_any_pattern(line, API_EXPORTS_PUBLIC_DEPENDENT_PRODUCT_PATTERNS)
end

@testset "public API inventory matches exports" begin
    exported_symbols = _api_exports_current_symbols()
    inventory_symbols = _api_exports_inventory_symbols()

    duplicate_symbols = sort([symbol for (symbol, count) in pairs(_api_exports_countmap(inventory_symbols)) if count > 1])
    missing_symbols = sort(collect(setdiff(exported_symbols, Set(inventory_symbols))))
    stale_symbols = sort(collect(setdiff(Set(inventory_symbols), exported_symbols)))

    @test isempty(duplicate_symbols)
    @test isempty(missing_symbols)
    @test isempty(stale_symbols)
    @test length(inventory_symbols) == length(exported_symbols)
end

@testset "public API exports have docstrings" begin
    public_symbols = _api_exports_public_symbols()
    missing_doc_symbols = sort([symbol for symbol in public_symbols if isnothing(_api_exports_doc_for(symbol))])

    @test missing_doc_symbols == Symbol[]
end

@testset "time-varying media configuration is intentionally public" begin
    inventory_rows = _api_exports_inventory_rows()

    @test :TimeVaryingMediaConfig in _api_exports_current_symbols()
    @test any(row -> row.symbol == :TimeVaryingMediaConfig, inventory_rows)
end

@testset "public API exports appear in Documenter docs blocks" begin
    public_symbols = _api_exports_public_symbols()
    docs_entries = _api_exports_documenter_docs_entries()
    missing_docs_entries = sort(
        [
            symbol for symbol in public_symbols if !("Epsilon.$(String(symbol))" in docs_entries)
        ],
    )

    @test missing_docs_entries == Symbol[]
end

@testset "plotting remains optional in the base package" begin
    @test Base.get_extension(Epsilon, :EpsilonCairoMakieExt) === nothing

    plotting_error = try
        trace_plot(nothing)
        nothing
    catch caught
        caught
    end
    @test plotting_error isa ArgumentError
    @test occursin("optional plotting support", sprint(showerror, plotting_error))

    artifact_paths = Dict{String, String}()
    warnings = String[]
    returned = Epsilon._save_pipeline_plot!(
        artifact_paths,
        warnings,
        "fit",
        "trace_plot",
        joinpath(tempdir(), "trace.png"),
        "20_model_fit/trace.png",
        :trace,
        nothing,
    )

    @test returned === artifact_paths
    @test isempty(artifact_paths)
    @test length(warnings) == 1
    @test occursin("optional plotting support is unavailable", only(warnings))
end

@testset "CairoMakie remains an optional package extension dependency" begin
    project = TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))
    cairomakie_uuid = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"

    @test !haskey(project["deps"], "CairoMakie")
    @test project["weakdeps"]["CairoMakie"] == cairomakie_uuid
    @test project["extensions"]["EpsilonCairoMakieExt"] == "CairoMakie"
    @test project["extras"]["CairoMakie"] == cairomakie_uuid
    @test "CairoMakie" in project["targets"]["test"]
end

@testset "current docs claim boundaries remain truthful" begin
    docs_claims = _api_exports_current_docs_claims()
    stale_current_claims = _api_exports_matching_claim_lines(
        API_EXPORTS_CURRENT_DOCS_CLAIM_GUARD_PATHS,
        _api_exports_has_stale_current_docs_claim,
    )
    active_vi_claims = _api_exports_matching_claim_lines(
        API_EXPORTS_CURRENT_DOCS_CLAIM_GUARD_PATHS,
        _api_exports_has_active_vi_release_claim,
    )
    active_local_workflow_evidence_claims = _api_exports_matching_claim_lines(
        API_EXPORTS_CURRENT_DOCS_CLAIM_GUARD_PATHS,
        _api_exports_has_active_local_workflow_evidence_claim,
    )
    active_portable_or_untrusted_artifact_claims = _api_exports_matching_claim_lines(
        API_EXPORTS_CURRENT_DOCS_CLAIM_GUARD_PATHS,
        _api_exports_has_active_portable_or_untrusted_artifact_claim,
    )

    @test occursin("Julia-native Bayesian marketing mix modelling library", docs_claims["docs index"])
    @test occursin("Runnable demo bundles are available under", docs_claims["docs index"])
    @test occursin("data/demo/geo_brand_panel/", docs_claims["docs index"])

    @test occursin("Support Boundaries", docs_claims["release gate"])
    @test occursin("Epsilon supports MCMC/Turing fitting only", docs_claims["release gate"])
    @test occursin("Unsupported paths should fail explicitly", docs_claims["release gate"])

    @test occursin("Trusted-Local Artifacts", docs_claims["supported paths"])
    @test occursin("They are not portable interchange files", docs_claims["supported paths"])
    @test occursin("trusted-local serialization artifacts", docs_claims["supported paths"])
    @test occursin(
        "not portable interchange files and must not be loaded from untrusted input",
        docs_claims["supported paths"],
    )

    @test stale_current_claims == String[]
    @test active_vi_claims == String[]
    @test active_local_workflow_evidence_claims == String[]
    @test active_portable_or_untrusted_artifact_claims == String[]
end

@testset "public docs avoid dependent-product identity claims" begin
    public_identity_claims = _api_exports_matching_claim_lines(
        API_EXPORTS_PUBLIC_IDENTITY_GUARD_PATHS,
        _api_exports_has_public_dependent_product_claim,
    )
    allowed_lines = [
        "Epsilon.jl is a Julia-native Bayesian marketing mix modelling library.",
        "Runnable demo bundles are available under data/demo/.",
        "These workflows are maintenance and teaching evidence for the supported Turing/NUTS MCMC path.",
    ]
    rejected_lines = [
        "Epsilon is a Julia port.",
        "Epsilon is a clone of another package.",
        "Epsilon is built on another modelling library.",
        "The first target is full product " * "par" * "ity.",
        "It is developed with comparison" * "-backed evidence where an external " *
            "reference " * "implementation has matching statistical semantics.",
        "Independent Julia MMM library, comparison" * "-backed where semantics match.",
        "The " * "reference" * "-backed row is retained for release evidence.",
    ]

    @test [_api_exports_has_public_dependent_product_claim(line) for line in allowed_lines] ==
        fill(false, length(allowed_lines))
    @test [_api_exports_has_public_dependent_product_claim(line) for line in rejected_lines] ==
        fill(true, length(rejected_lines))
    @test public_identity_claims == String[]
end
