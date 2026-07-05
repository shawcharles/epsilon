using Test
using Epsilon

const API_EXPORTS_DOC_PATH = joinpath(@__DIR__, "..", "docs", "src", "api.md")
const API_EXPORTS_INVENTORY_BEGIN = "<!-- BEGIN PUBLIC API INVENTORY -->"
const API_EXPORTS_INVENTORY_END = "<!-- END PUBLIC API INVENTORY -->"

function _api_exports_current_symbols()
    exports = Set(Symbol.(names(Epsilon; all = false, imported = false)))
    delete!(exports, :Epsilon)
    return exports
end

function _api_exports_marked_inventory_table(text::AbstractString)
    begin_matches = collect(eachmatch(Regex(escape_string(API_EXPORTS_INVENTORY_BEGIN)), text))
    end_matches = collect(eachmatch(Regex(escape_string(API_EXPORTS_INVENTORY_END)), text))

    @test length(begin_matches) == 1
    @test length(end_matches) == 1
    @test begin_matches[1].offset < end_matches[1].offset

    start_index = begin_matches[1].offset + ncodeunits(API_EXPORTS_INVENTORY_BEGIN)
    stop_index = prevind(text, end_matches[1].offset)
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

function _api_exports_countmap(values)
    counts = Dict{Symbol, Int}()
    for value in values
        counts[value] = get(counts, value, 0) + 1
    end
    return counts
end

@testset "public API inventory matches exports" begin
    exported_symbols = _api_exports_current_symbols()
    table_text = _api_exports_marked_inventory_table(read(API_EXPORTS_DOC_PATH, String))
    inventory_rows = _api_exports_parse_inventory_rows(table_text)
    inventory_symbols = [row.symbol for row in inventory_rows]

    duplicate_symbols = sort([symbol for (symbol, count) in pairs(_api_exports_countmap(inventory_symbols)) if count > 1])
    missing_symbols = sort(collect(setdiff(exported_symbols, Set(inventory_symbols))))
    stale_symbols = sort(collect(setdiff(Set(inventory_symbols), exported_symbols)))

    @test isempty(duplicate_symbols)
    @test isempty(missing_symbols)
    @test isempty(stale_symbols)
    @test length(inventory_symbols) == length(exported_symbols)
end
