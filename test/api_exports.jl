using Test
using Epsilon

const API_EXPORTS_DOC_PATH = joinpath(@__DIR__, "..", "docs", "src", "api.md")
const API_EXPORTS_DOCS_SRC_PATH = joinpath(@__DIR__, "..", "docs", "src")
const API_EXPORTS_TRIAGE_PATH = joinpath(@__DIR__, "..", ".planning", "API-EXPORT-TRIAGE.md")
const API_EXPORTS_CLEANUP_RFC_PATH = joinpath(@__DIR__, "..", ".planning", "API-EXPORT-CLEANUP-RFC.md")
const API_EXPORTS_RUNTIME_DEPRECATION_DESIGN_PATH = joinpath(
    @__DIR__,
    "..",
    ".planning",
    "API-RUNTIME-DEPRECATION-DESIGN.md",
)
const API_EXPORTS_INVENTORY_BEGIN = "<!-- BEGIN PUBLIC API INVENTORY -->"
const API_EXPORTS_INVENTORY_END = "<!-- END PUBLIC API INVENTORY -->"
const API_EXPORTS_TRIAGE_BEGIN = "<!-- BEGIN PUBLIC API TRIAGE -->"
const API_EXPORTS_TRIAGE_END = "<!-- END PUBLIC API TRIAGE -->"
const API_EXPORTS_CLEANUP_RFC_BEGIN = "<!-- BEGIN PUBLIC API CLEANUP CANDIDATES -->"
const API_EXPORTS_CLEANUP_RFC_END = "<!-- END PUBLIC API CLEANUP CANDIDATES -->"
const API_EXPORTS_DEPRECATION_AUDIT_BEGIN = "<!-- BEGIN PUBLIC API DEPRECATION MIGRATION AUDIT -->"
const API_EXPORTS_DEPRECATION_AUDIT_END = "<!-- END PUBLIC API DEPRECATION MIGRATION AUDIT -->"
const API_EXPORTS_CLEANUP_RFC_DECISION = "Candidate only; no runtime or export change in Phase 22."
const API_EXPORTS_DEPRECATION_AUDIT_RUNTIME_WARNING = "landed"
const API_EXPORTS_DEPRECATION_AUDIT_REPLACEMENT_STATUS = "guarded"
const API_EXPORTS_DEPRECATION_AUDIT_READY_TO_UNEXPORT = "no"
const API_EXPORTS_DEPRECATED_VALIDATION_HELPERS = Set(
    [
        :validate_calibration_step_config,
        :validate_cost_per_target_calibration_payload,
        :validate_lift_test_calibration_payload,
        :validate_mmm_data,
        :validate_model_config,
        :validate_sampler_config,
    ]
)
const API_EXPORTS_TRIAGE_LIFECYCLES = Set(
    [
        "keep-public",
        "keep-bounded",
        "compatibility",
        "review-before-v1",
        "deprecation-candidate",
    ]
)

function _api_exports_current_symbols()
    exports = Set(Symbol.(names(Epsilon; all = false, imported = false)))
    delete!(exports, :Epsilon)
    return exports
end

function _api_exports_marked_table(text::AbstractString, begin_marker::AbstractString, end_marker::AbstractString)
    begin_matches = collect(eachmatch(Regex(escape_string(begin_marker)), text))
    end_matches = collect(eachmatch(Regex(escape_string(end_marker)), text))

    @test length(begin_matches) == 1
    @test length(end_matches) == 1
    @test begin_matches[1].offset < end_matches[1].offset

    start_index = begin_matches[1].offset + ncodeunits(begin_marker)
    stop_index = prevind(text, end_matches[1].offset)
    return text[start_index:stop_index]
end

function _api_exports_marked_inventory_table(text::AbstractString)
    return _api_exports_marked_table(text, API_EXPORTS_INVENTORY_BEGIN, API_EXPORTS_INVENTORY_END)
end

function _api_exports_marked_triage_table(text::AbstractString)
    return _api_exports_marked_table(text, API_EXPORTS_TRIAGE_BEGIN, API_EXPORTS_TRIAGE_END)
end

function _api_exports_marked_cleanup_rfc_table(text::AbstractString)
    return _api_exports_marked_table(text, API_EXPORTS_CLEANUP_RFC_BEGIN, API_EXPORTS_CLEANUP_RFC_END)
end

function _api_exports_marked_deprecation_audit_table(text::AbstractString)
    return _api_exports_marked_table(text, API_EXPORTS_DEPRECATION_AUDIT_BEGIN, API_EXPORTS_DEPRECATION_AUDIT_END)
end

function _api_exports_section_table(text::AbstractString, heading::AbstractString)
    lines = split(text, '\n')
    heading_indices = findall(line -> strip(line) == heading, lines)

    @test length(heading_indices) == 1
    isempty(heading_indices) && return ""

    table_lines = String[]
    for line in lines[(only(heading_indices) + 1):end]
        stripped = strip(line)
        startswith(stripped, "## ") && break
        isempty(stripped) && isempty(table_lines) && continue
        isempty(stripped) && !isempty(table_lines) && break
        startswith(stripped, "|") || continue
        push!(table_lines, line)
    end

    return join(table_lines, "\n")
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

function _api_exports_parse_triage_rows(table_text::AbstractString)
    rows = split(table_text, '\n')
    nonempty_rows = filter(row -> !isempty(strip(row)), rows)

    @test length(nonempty_rows) >= 2
    @test strip(nonempty_rows[1]) == "| Symbol | Domain | Support | Lifecycle | Replacement / Migration | Rationale |"
    @test strip(nonempty_rows[2]) == "|---|---|---|---|---|---|"

    parsed = NamedTuple{
        (:symbol, :domain, :support, :lifecycle, :migration, :rationale),
        Tuple{Symbol, String, String, String, String, String},
    }[]
    for row in nonempty_rows[3:end]
        match_result = match(
            r"^\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|$",
            row,
        )
        @test !isnothing(match_result)
        isnothing(match_result) && continue

        domain = strip(match_result.captures[2])
        support = strip(match_result.captures[3])
        lifecycle = strip(match_result.captures[4])
        migration = strip(match_result.captures[5])
        rationale = strip(match_result.captures[6])
        @test !isempty(domain)
        @test !isempty(support)

        push!(
            parsed,
            (
                symbol = Symbol(match_result.captures[1]),
                domain = domain,
                support = support,
                lifecycle = lifecycle,
                migration = migration,
                rationale = rationale,
            ),
        )
    end

    return parsed
end

function _api_exports_parse_cleanup_rfc_candidate_rows(table_text::AbstractString)
    rows = split(table_text, '\n')
    nonempty_rows = filter(row -> !isempty(strip(row)), rows)

    @test length(nonempty_rows) >= 2
    @test strip(nonempty_rows[1]) == "| Symbol | Current Lifecycle | Proposed Lifecycle | Migration | Rationale | Risk | Decision |"
    @test strip(nonempty_rows[2]) == "|---|---|---|---|---|---|---|"

    parsed = NamedTuple{
        (:symbol, :current_lifecycle, :proposed_lifecycle, :migration, :rationale, :risk, :decision),
        Tuple{Symbol, String, String, String, String, String, String},
    }[]
    for row in nonempty_rows[3:end]
        match_result = match(
            r"^\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|$",
            row,
        )
        @test !isnothing(match_result)
        isnothing(match_result) && continue

        current_lifecycle = strip(match_result.captures[2])
        proposed_lifecycle = strip(match_result.captures[3])
        migration = strip(match_result.captures[4])
        rationale = strip(match_result.captures[5])
        risk = strip(match_result.captures[6])
        decision = strip(match_result.captures[7])
        @test !isempty(rationale)
        @test !isempty(risk)

        push!(
            parsed,
            (
                symbol = Symbol(match_result.captures[1]),
                current_lifecycle = current_lifecycle,
                proposed_lifecycle = proposed_lifecycle,
                migration = migration,
                rationale = rationale,
                risk = risk,
                decision = decision,
            ),
        )
    end

    return parsed
end

function _api_exports_parse_deprecation_audit_rows(table_text::AbstractString)
    rows = split(table_text, '\n')
    nonempty_rows = filter(row -> !isempty(strip(row)), rows)

    @test length(nonempty_rows) >= 2
    @test strip(nonempty_rows[1]) ==
        "| Symbol | Runtime Warning | Migration Path | Replacement Warning-Free | Ready To Unexport | Evidence |"
    @test strip(nonempty_rows[2]) == "|---|---|---|---|---|---|"

    parsed = NamedTuple{
        (:symbol, :runtime_warning, :migration, :replacement_warning_free, :ready_to_unexport, :evidence),
        Tuple{Symbol, String, String, String, String, String},
    }[]
    for row in nonempty_rows[3:end]
        match_result = match(
            r"^\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|$",
            row,
        )
        @test !isnothing(match_result)
        isnothing(match_result) && continue

        runtime_warning = strip(match_result.captures[2])
        migration = strip(match_result.captures[3])
        replacement_warning_free = strip(match_result.captures[4])
        ready_to_unexport = strip(match_result.captures[5])
        evidence = strip(match_result.captures[6])

        push!(
            parsed,
            (
                symbol = Symbol(match_result.captures[1]),
                runtime_warning = runtime_warning,
                migration = migration,
                replacement_warning_free = replacement_warning_free,
                ready_to_unexport = ready_to_unexport,
                evidence = evidence,
            ),
        )
    end

    return parsed
end

function _api_exports_parse_runtime_deprecation_source_rows(table_text::AbstractString)
    rows = split(table_text, '\n')
    nonempty_rows = filter(row -> !isempty(strip(row)), rows)

    @test length(nonempty_rows) >= 2
    @test strip(nonempty_rows[1]) == "| Symbol | Future Migration Target |"
    @test strip(nonempty_rows[2]) == "|---|---|"

    parsed = NamedTuple{(:symbol, :migration), Tuple{Symbol, String}}[]
    for row in nonempty_rows[3:end]
        match_result = match(r"^\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|$", row)
        @test !isnothing(match_result)
        isnothing(match_result) && continue

        push!(
            parsed,
            (
                symbol = Symbol(match_result.captures[1]),
                migration = strip(match_result.captures[2]),
            ),
        )
    end

    return parsed
end

function _api_exports_countmap(values)
    counts = Dict{Symbol, Int}()
    for value in values
        counts[value] = get(counts, value, 0) + 1
    end
    return counts
end

function _api_exports_inventory_symbols()
    table_text = _api_exports_marked_inventory_table(read(API_EXPORTS_DOC_PATH, String))
    inventory_rows = _api_exports_parse_inventory_rows(table_text)
    return [row.symbol for row in inventory_rows]
end

function _api_exports_inventory_rows()
    table_text = _api_exports_marked_inventory_table(read(API_EXPORTS_DOC_PATH, String))
    return _api_exports_parse_inventory_rows(table_text)
end

function _api_exports_triage_rows()
    table_text = _api_exports_marked_triage_table(read(API_EXPORTS_TRIAGE_PATH, String))
    return _api_exports_parse_triage_rows(table_text)
end

function _api_exports_cleanup_rfc_candidate_rows()
    table_text = _api_exports_marked_cleanup_rfc_table(read(API_EXPORTS_CLEANUP_RFC_PATH, String))
    return _api_exports_parse_cleanup_rfc_candidate_rows(table_text)
end

function _api_exports_deprecation_audit_rows()
    table_text = _api_exports_marked_deprecation_audit_table(read(API_EXPORTS_CLEANUP_RFC_PATH, String))
    return _api_exports_parse_deprecation_audit_rows(table_text)
end

function _api_exports_runtime_deprecation_source_rows()
    table_text = _api_exports_section_table(
        read(API_EXPORTS_RUNTIME_DEPRECATION_DESIGN_PATH, String),
        "## Source Candidate Set",
    )
    return _api_exports_parse_runtime_deprecation_source_rows(table_text)
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

@testset "public API exports appear in Documenter docs blocks" begin
    public_symbols = _api_exports_public_symbols()
    docs_entries = _api_exports_documenter_docs_entries()
    missing_docs_entries = sort(
        [
            symbol for symbol in public_symbols if !("Epsilon.$(String(symbol))" in docs_entries)
        ]
    )

    @test missing_docs_entries == Symbol[]
end

@testset "public API lifecycle triage matches inventory" begin
    exported_symbols = _api_exports_current_symbols()
    inventory_rows = _api_exports_inventory_rows()
    triage_rows = _api_exports_triage_rows()

    inventory_by_symbol = Dict(row.symbol => row for row in inventory_rows)
    triage_symbols = [row.symbol for row in triage_rows]
    triage_symbol_set = Set(triage_symbols)
    inventory_symbol_set = Set(row.symbol for row in inventory_rows)

    duplicate_symbols = sort([symbol for (symbol, count) in pairs(_api_exports_countmap(triage_symbols)) if count > 1])
    missing_symbols = sort(collect(setdiff(exported_symbols, triage_symbol_set)))
    stale_symbols = sort(collect(union(setdiff(triage_symbol_set, inventory_symbol_set), setdiff(triage_symbol_set, exported_symbols))))
    domain_mismatched_symbols = sort(
        unique(
            [
                row.symbol for row in triage_rows if haskey(inventory_by_symbol, row.symbol) &&
                    row.domain != inventory_by_symbol[row.symbol].domain
            ]
        ),
    )
    support_mismatched_symbols = sort(
        unique(
            [
                row.symbol for row in triage_rows if haskey(inventory_by_symbol, row.symbol) &&
                    row.support != inventory_by_symbol[row.symbol].support
            ]
        ),
    )
    invalid_lifecycle_symbols = sort(
        unique([row.symbol for row in triage_rows if !(row.lifecycle in API_EXPORTS_TRIAGE_LIFECYCLES)]),
    )
    empty_rationale_symbols = sort(unique([row.symbol for row in triage_rows if isempty(strip(row.rationale))]))
    weak_deprecation_migration_symbols = sort(
        unique(
            [
                row.symbol for row in triage_rows if row.lifecycle == "deprecation-candidate" &&
                    (isempty(strip(row.migration)) || lowercase(strip(row.migration)) == "n/a")
            ]
        ),
    )

    @test duplicate_symbols == Symbol[]
    @test missing_symbols == Symbol[]
    @test stale_symbols == Symbol[]
    @test domain_mismatched_symbols == Symbol[]
    @test support_mismatched_symbols == Symbol[]
    @test invalid_lifecycle_symbols == Symbol[]
    @test empty_rationale_symbols == Symbol[]
    @test weak_deprecation_migration_symbols == Symbol[]
    @test length(triage_rows) == length(exported_symbols)
end

@testset "public API cleanup RFC candidates match triage" begin
    exported_symbols = _api_exports_current_symbols()
    triage_rows = _api_exports_triage_rows()
    rfc_rows = _api_exports_cleanup_rfc_candidate_rows()

    triage_by_symbol = Dict(row.symbol => row for row in triage_rows)
    triage_deprecation_symbols = sort(
        unique([row.symbol for row in triage_rows if row.lifecycle == "deprecation-candidate"]),
    )
    rfc_symbols = [row.symbol for row in rfc_rows]
    rfc_symbol_set = Set(rfc_symbols)

    duplicate_rfc_symbols = sort([symbol for (symbol, count) in pairs(_api_exports_countmap(rfc_symbols)) if count > 1])
    missing_export_symbols = sort(collect(setdiff(rfc_symbol_set, exported_symbols)))
    missing_triage_symbols = sort(
        unique([row.symbol for row in rfc_rows if !haskey(triage_by_symbol, row.symbol)]),
    )
    current_lifecycle_mismatched_symbols = sort(
        unique([row.symbol for row in rfc_rows if row.current_lifecycle != "review-before-v1"]),
    )
    proposed_lifecycle_mismatched_symbols = sort(
        unique([row.symbol for row in rfc_rows if row.proposed_lifecycle != "deprecation-candidate"]),
    )
    weak_migration_symbols = sort(
        unique(
            [
                row.symbol for row in rfc_rows if isempty(strip(row.migration)) ||
                    lowercase(strip(row.migration)) == "n/a"
            ],
        ),
    )
    invalid_decision_symbols = sort(
        unique([row.symbol for row in rfc_rows if row.decision != API_EXPORTS_CLEANUP_RFC_DECISION]),
    )
    triage_lifecycle_mismatched_symbols = sort(
        unique(
            [
                row.symbol for row in rfc_rows if haskey(triage_by_symbol, row.symbol) &&
                    triage_by_symbol[row.symbol].lifecycle != "deprecation-candidate"
            ],
        ),
    )
    missing_rfc_for_triage_symbols = sort(collect(setdiff(Set(triage_deprecation_symbols), rfc_symbol_set)))
    stale_rfc_deprecation_symbols = sort(collect(setdiff(rfc_symbol_set, Set(triage_deprecation_symbols))))
    migration_mismatched_symbols = sort(
        unique(
            [
                row.symbol for row in rfc_rows if haskey(triage_by_symbol, row.symbol) &&
                    triage_by_symbol[row.symbol].migration != row.migration
            ],
        ),
    )

    @test duplicate_rfc_symbols == Symbol[]
    @test missing_export_symbols == Symbol[]
    @test missing_triage_symbols == Symbol[]
    @test current_lifecycle_mismatched_symbols == Symbol[]
    @test proposed_lifecycle_mismatched_symbols == Symbol[]
    @test weak_migration_symbols == Symbol[]
    @test invalid_decision_symbols == Symbol[]
    @test triage_lifecycle_mismatched_symbols == Symbol[]
    @test missing_rfc_for_triage_symbols == Symbol[]
    @test stale_rfc_deprecation_symbols == Symbol[]
    @test migration_mismatched_symbols == Symbol[]
end

@testset "deprecated validation helper migration audit is coherent" begin
    exported_symbols = _api_exports_current_symbols()
    triage_rows = _api_exports_triage_rows()
    rfc_rows = _api_exports_cleanup_rfc_candidate_rows()
    audit_rows = _api_exports_deprecation_audit_rows()
    runtime_design_rows = _api_exports_runtime_deprecation_source_rows()

    triage_by_symbol = Dict(row.symbol => row for row in triage_rows)
    rfc_by_symbol = Dict(row.symbol => row for row in rfc_rows)
    audit_by_symbol = Dict(row.symbol => row for row in audit_rows)
    runtime_design_by_symbol = Dict(row.symbol => row for row in runtime_design_rows)

    filtered_export_symbols = Set(intersect(exported_symbols, API_EXPORTS_DEPRECATED_VALIDATION_HELPERS))
    triage_deprecation_symbols = Set(row.symbol for row in triage_rows if row.lifecycle == "deprecation-candidate")
    rfc_candidate_symbols = Set(row.symbol for row in rfc_rows)
    audit_symbols = [row.symbol for row in audit_rows]
    runtime_design_symbols = [row.symbol for row in runtime_design_rows]
    expected_symbols = API_EXPORTS_DEPRECATED_VALIDATION_HELPERS

    duplicate_audit_symbols = sort([symbol for (symbol, count) in pairs(_api_exports_countmap(audit_symbols)) if count > 1])
    duplicate_runtime_design_symbols = sort(
        [symbol for (symbol, count) in pairs(_api_exports_countmap(runtime_design_symbols)) if count > 1],
    )
    missing_helper_exports = sort(collect(setdiff(expected_symbols, filtered_export_symbols)))
    stale_filtered_helper_exports = sort(collect(setdiff(filtered_export_symbols, expected_symbols)))
    audit_mismatched_symbols = sort(collect(setdiff(union(Set(audit_symbols), expected_symbols), intersect(Set(audit_symbols), expected_symbols))))
    runtime_design_mismatched_symbols = sort(
        collect(
            setdiff(
                union(Set(runtime_design_symbols), expected_symbols),
                intersect(Set(runtime_design_symbols), expected_symbols),
            ),
        ),
    )
    triage_set_mismatch = sort(
        collect(setdiff(union(triage_deprecation_symbols, expected_symbols), intersect(triage_deprecation_symbols, expected_symbols))),
    )
    rfc_set_mismatch = sort(
        collect(setdiff(union(rfc_candidate_symbols, expected_symbols), intersect(rfc_candidate_symbols, expected_symbols))),
    )
    export_set_mismatch = sort(
        collect(setdiff(union(filtered_export_symbols, expected_symbols), intersect(filtered_export_symbols, expected_symbols))),
    )

    migration_mismatched_symbols = sort(
        [
            symbol for symbol in expected_symbols if haskey(triage_by_symbol, symbol) &&
                haskey(rfc_by_symbol, symbol) &&
                haskey(audit_by_symbol, symbol) &&
                haskey(runtime_design_by_symbol, symbol) &&
                length(
                    Set(
                        [
                            triage_by_symbol[symbol].migration,
                            rfc_by_symbol[symbol].migration,
                            audit_by_symbol[symbol].migration,
                            runtime_design_by_symbol[symbol].migration,
                        ],
                    ),
                ) != 1
        ],
    )
    runtime_warning_mismatched_symbols = sort(
        unique(
            [
                row.symbol for row in audit_rows if row.runtime_warning != API_EXPORTS_DEPRECATION_AUDIT_RUNTIME_WARNING
            ],
        ),
    )
    replacement_status_mismatched_symbols = sort(
        unique(
            [
                row.symbol for row in audit_rows if row.replacement_warning_free !=
                    API_EXPORTS_DEPRECATION_AUDIT_REPLACEMENT_STATUS
            ],
        ),
    )
    unexport_readiness_mismatched_symbols = sort(
        unique(
            [
                row.symbol for row in audit_rows if row.ready_to_unexport !=
                    API_EXPORTS_DEPRECATION_AUDIT_READY_TO_UNEXPORT
            ],
        ),
    )
    empty_evidence_symbols = sort(unique([row.symbol for row in audit_rows if isempty(strip(row.evidence))]))

    @test length(audit_rows) == 6
    @test duplicate_audit_symbols == Symbol[]
    @test duplicate_runtime_design_symbols == Symbol[]
    @test missing_helper_exports == Symbol[]
    @test stale_filtered_helper_exports == Symbol[]
    @test audit_mismatched_symbols == Symbol[]
    @test runtime_design_mismatched_symbols == Symbol[]
    @test triage_set_mismatch == Symbol[]
    @test rfc_set_mismatch == Symbol[]
    @test export_set_mismatch == Symbol[]
    @test migration_mismatched_symbols == Symbol[]
    @test runtime_warning_mismatched_symbols == Symbol[]
    @test replacement_status_mismatched_symbols == Symbol[]
    @test unexport_readiness_mismatched_symbols == Symbol[]
    @test empty_evidence_symbols == Symbol[]
end
