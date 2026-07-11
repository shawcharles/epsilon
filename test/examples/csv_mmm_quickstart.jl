using Dates
using Test

include(joinpath(@__DIR__, "..", "..", "examples", "csv_mmm", "run_csv_mmm.jl"))

function _csv_quickstart_argument_error_message(f)
    try
        f()
    catch err
        @test err isa ArgumentError
        return sprint(showerror, err)
    end
    error("expected ArgumentError")
end

function _write_csv_quickstart_fixture(path::AbstractString, body::AbstractString)
    write(path, "date,sales,tv,search\n" * body)
    return path
end

@testset "CSV MMM quickstart loader" begin
    repo_root = normpath(joinpath(@__DIR__, "..", ".."))
    bundled_path = joinpath(repo_root, "examples", "csv_mmm", "toy_timeseries.csv")
    data = load_csv_mmm_data(bundled_path)

    @test data.dates == [Date(2026, 1, 5), Date(2026, 1, 12), Date(2026, 1, 19), Date(2026, 1, 26)]
    @test data.target == [82.0, 86.0, 91.0, 95.0]
    @test data.channel_names == ["tv", "search"]
    @test data.channels == [12.0 4.0; 14.0 5.0; 16.0 6.0; 18.0 6.5]

    mktempdir() do directory
        sorted_path = _write_csv_quickstart_fixture(
            joinpath(directory, "unsorted.csv"),
            "2026-01-19,91,16,6\n2026-01-05,82,12,4\n2026-01-12,86,14,5\n",
        )
        sorted = load_csv_mmm_data(sorted_path)
        @test sorted.dates == [Date(2026, 1, 5), Date(2026, 1, 12), Date(2026, 1, 19)]
        @test sorted.target == [82.0, 86.0, 91.0]
        @test sorted.channels == [12.0 4.0; 14.0 5.0; 16.0 6.0]

        duplicate_path = _write_csv_quickstart_fixture(
            joinpath(directory, "duplicate.csv"),
            "2026-01-05,82,12,4\n2026-01-05,86,14,5\n",
        )
        duplicate_message = _csv_quickstart_argument_error_message(
            () -> load_csv_mmm_data(duplicate_path),
        )
        @test occursin("date", duplicate_message)
        @test occursin("duplicate", duplicate_message)

        malformed_date_path = _write_csv_quickstart_fixture(
            joinpath(directory, "malformed-date.csv"),
            "2026/01/05,82,12,4\n",
        )
        malformed_date_message = _csv_quickstart_argument_error_message(
            () -> load_csv_mmm_data(malformed_date_path),
        )
        @test occursin("date", malformed_date_message)

        missing_date_path = _write_csv_quickstart_fixture(
            joinpath(directory, "missing-date.csv"),
            ",82,12,4\n",
        )
        missing_date_message = _csv_quickstart_argument_error_message(
            () -> load_csv_mmm_data(missing_date_path),
        )
        @test occursin("date", missing_date_message)

        for (column, value) in (
                ("sales", ""),
                ("tv", "NaN"),
                ("search", "Inf"),
                ("tv", "-1"),
                ("tv", "true"),
                ("sales", "not-a-number"),
            )
            path = _write_csv_quickstart_fixture(
                joinpath(directory, "$(column)-value.csv"),
                "2026-01-05,$(column == "sales" ? value : "82"),$(column == "tv" ? value : "12"),$(column == "search" ? value : "4")\n",
            )
            message = _csv_quickstart_argument_error_message(() -> load_csv_mmm_data(path))
            @test occursin(column, message)
        end

        unexpected_column_path = joinpath(directory, "unexpected-column.csv")
        write(
            unexpected_column_path,
            "date,sales,tv,search,control\n2026-01-05,82,12,4,1\n",
        )
        unexpected_column_message = _csv_quickstart_argument_error_message(
            () -> load_csv_mmm_data(unexpected_column_path),
        )
        @test occursin("unexpected", unexpected_column_message)
        @test occursin("control", unexpected_column_message)
    end

    missing_path_message = _csv_quickstart_argument_error_message(
        () -> load_csv_mmm_data(joinpath(repo_root, "does-not-exist.csv")),
    )
    @test occursin("does-not-exist.csv", missing_path_message)

    mktempdir() do directory
        for missing_column in ("date", "sales", "tv", "search")
            path = joinpath(directory, "missing-$(missing_column).csv")
            headers = filter(!=(missing_column), ["date", "sales", "tv", "search"])
            values = Dict("date" => "2026-01-05", "sales" => "82", "tv" => "12", "search" => "4")
            write(path, join(headers, ",") * "\n" * join((values[header] for header in headers), ",") * "\n")
            message = _csv_quickstart_argument_error_message(() -> load_csv_mmm_data(path))
            @test occursin(missing_column, message)
        end
    end
end

@testset "CSV MMM quickstart CLI and include safety" begin
    repo_root = normpath(joinpath(@__DIR__, "..", ".."))
    script_path = joinpath(repo_root, "examples", "csv_mmm", "run_csv_mmm.jl")

    default_options = _parse_csv_mmm_cli(String[])
    @test default_options["data"] == _CSV_MMM_DEFAULT_DATA_PATH
    @test default_options["draws"] == _CSV_MMM_DEFAULT_DRAWS
    @test default_options["tune"] == _CSV_MMM_DEFAULT_TUNE
    @test default_options["seed"] == _CSV_MMM_DEFAULT_SEED
    @test isnothing(default_options["output_dir"])

    for option in ("--draws", "--tune")
        for value in ("0", "-1")
            message = _csv_quickstart_argument_error_message(
                () -> _parse_csv_mmm_cli([option, value]),
            )
            @test occursin(option, message)
            @test occursin("positive integer", message)
        end
    end

    parsed_options = _parse_csv_mmm_cli(
        [
            "--data",
            "custom.csv",
            "--draws",
            "11",
            "--tune",
            "12",
            "--seed",
            "13",
            "--output-dir",
            "csv-output",
        ],
    )
    @test parsed_options["data"] == "custom.csv"
    @test parsed_options["draws"] == 11
    @test parsed_options["tune"] == 12
    @test parsed_options["seed"] == 13
    @test parsed_options["output_dir"] == "csv-output"

    for option in ("--data", "--draws", "--tune", "--seed", "--output-dir")
        message = _csv_quickstart_argument_error_message(() -> _parse_csv_mmm_cli([option]))
        @test occursin(option, message)
        @test occursin("requires a value", message)
    end

    for option in ("--draws", "--tune", "--seed")
        message = _csv_quickstart_argument_error_message(
            () -> _parse_csv_mmm_cli([option, "not-an-int"]),
        )
        @test occursin(option, message)
        @test occursin("not-an-int", message)
    end

    unknown_message = _csv_quickstart_argument_error_message(
        () -> _parse_csv_mmm_cli(["--bad-option"]),
    )
    @test occursin("unknown argument", unknown_message)
    @test occursin("--bad-option", unknown_message)

    help_output = read(`$(Base.julia_cmd()) --project=$(repo_root) $(script_path) --help`, String)
    @test occursin("Usage:", help_output)
    @test occursin("--data", help_output)
    @test !occursin("status=", help_output)
    @test !occursin("backend=", help_output)

    short_help_options = _parse_csv_mmm_cli(["-h"])
    @test short_help_options["help"] == true

    mktempdir() do workdir
        include_check = """
        cd($(repr(workdir)))
        include($(repr(script_path)))
        @assert isdefined(Main, :run_csv_mmm)
        @assert !isfile("contribution_summary.csv")
        @assert !isfile("metric_summary.csv")
        @assert !isfile("run_summary.txt")
        print("include-safe")
        """
        output = read(`$(Base.julia_cmd()) --project=$(repo_root) -e $(include_check)`, String)
        @test output == "include-safe"
    end
end

@testset "CSV MMM quickstart MCMC smoke demo" begin
    mktempdir() do output_dir
        result = run_csv_mmm(; draws = 8, tune = 8, seed = 20260711, output_dir, verbose = false)

        @test result.state.status == :fit
        @test result.state.backend == :turing
        @test result.model.data === result.data
        @test result.data.channel_names == ["tv", "search"]
        @test result.model.sampler_config.chains == 1
        @test result.model.sampler_config.cores == 1
        @test result.model.sampler_config.progressbar == false
        @test result.model.sampler_config.compute_convergence_checks == false
        @test !isnothing(result.grouped.posterior)
        @test size(result.contribution_table, 1) > 0
        @test size(result.metric_table, 1) > 0
        @test haskey(result.written_paths, :contribution_summary)
        @test haskey(result.written_paths, :metric_summary)
        @test haskey(result.written_paths, :run_summary)

        for path in values(result.written_paths)
            @test isfile(path)
            @test filesize(path) > 0
        end
    end

end
