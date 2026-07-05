using Test
using Epsilon

const API_EXPORTS_DOC_PATH = joinpath(@__DIR__, "..", "docs", "src", "api.md")
const API_EXPORTS_DOCS_SRC_PATH = joinpath(@__DIR__, "..", "docs", "src")
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

function _api_exports_inventory_symbols()
    table_text = _api_exports_marked_inventory_table(read(API_EXPORTS_DOC_PATH, String))
    inventory_rows = _api_exports_parse_inventory_rows(table_text)
    return [row.symbol for row in inventory_rows]
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
