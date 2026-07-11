# Phase 31: HSGP Time-Index Foundation

## Status

Closed. Implementation and final shared-namespace checkpoint passed.

## Objective

Port the deterministic cadence-aware time-index primitive used by Abacus before
it constructs an HSGP time-varying multiplier. This is a narrow foundation for
future HSGP/TVP work, not an HSGP basis, prior, Turing model term, config type,
or user-facing seasonality feature.

## Reference Contract

Abacus `infer_time_index(date_series_new, date_series, time_resolution)`:

- measures each new date's day offset from the first training date;
- divides an on-cadence offset by a positive whole-day cadence;
- supports in-sample, forward, and backward indices;
- rejects non-positive cadence and dates that are not aligned to the fitted
  cadence.

Epsilon will accept `AbstractVector{<:Date}` inputs only. It will preserve the
first supplied training date as the fitted origin, return `Vector{Int}`, and
raise explicit `ArgumentError`s for an empty training vector, non-positive
cadence, and off-cadence new dates. It will not sort or deduplicate input dates:
that belongs to data ingestion, and silently changing the fitted origin would
break reference semantics.

The helper computes signed whole-day offsets using Julia `Date` subtraction,
checks exact divisibility by `time_resolution` before integer division, and
permits an empty `new_dates` vector as `Int[]`. Only `new_dates` are cadence
validated: Abacus uses the first training date as origin and does not validate
the remaining training date vector. Empty training input is an intentional
Epsilon hardening with a clear error rather than Abacus's incidental indexing
failure.

## In Scope

- An internal, pure date-index helper under `src/mmm/`.
- Inclusion in the package module without adding a public export.
- Deterministic Abacus-generated fixture cases for daily, weekly, in-sample,
  forward, backward, leap/calendar-boundary, and off-cadence rows.
- Focused Julia tests and exporter coverage.
- Conservative planning/ledger/changelog state documenting this only as a
  foundation; the HSGP/TVP ledger row remains `missing`.
- Ignored Three Man Team handoff records.

## Out Of Scope

- `seasonality.type = "hsgp"` acceptance, any HSGP basis/spectral-density
  implementation, GP hyperpriors, `Turing.@model` changes, time-varying media
  coefficients, `SoftPlusHSGP` multiplier semantics, prediction/replay state,
  panel HSGP, or calibration changes.
- Public exports or documentation that presents HSGP/TVP as supported.
- New dependencies, Python runtime coupling, dashboard/UI, VI, benchmarks, or
  release evidence. The one full-suite run listed below is a final include-graph
  checkpoint, not an expansion of this phase's product scope.

## Tasks

### Task 31-01: Plan And Review

- [x] Write the architect brief and this plan.
- [x] Review the exact Abacus source/test contract in fresh context.
- [x] Resolve all Must Fix findings before implementation.

### Task 31-02: Fixture-Backed Pure Primitive

- [x] Extend `scripts/export_abacus_fixtures.py` to call Abacus's real
      `infer_time_index` on a small fixed case matrix, catching only expected
      off-cadence `ValueError`s and writing Julia-safe `Date`/`Int` literals.
- [x] Add a deterministic Julia fixture file under `test/fixtures/abacus/`.
- [x] Add `_infer_hsgp_time_index(new_dates, training_dates; time_resolution)`.
- [x] Return integer indices based on day offsets from `first(training_dates)`.
- [x] Reject empty training dates, non-positive cadence, and off-cadence dates
      with clear `ArgumentError`s.
- [x] Test empty `new_dates`, unsorted/duplicate training-date preservation,
      backward off-cadence rejection, and an across-month/leap-date case.

### Task 31-03: Focused Evidence And Closure

- [x] Add `test/model/hsgp_time_index.jl`, registered in model runtests.
- [x] Verify fixture parity for all accepted daily/weekly cases and explicit
      Epsilon error contracts for invalid input.
- [x] Assert the helper is not exported and `seasonality.type = "hsgp"` remains
      rejected by existing configuration/model paths.
- [x] Update ledger evidence without moving the HSGP/TVP core row from
      `missing`.
- [x] Update changelog, roadmap, state, phase plan, and local handoff logs.
- [x] Run the one final full-suite shared-namespace checkpoint, then mark the
      phase closed.

## Acceptance Criteria

- Epsilon returns Abacus-matching integer indices for the fixed in-sample,
  forward, backward, and weekly cadence cases.
- Off-cadence dates and non-positive cadence are rejected before any model
  construction.
- Empty new dates return `Int[]`; empty training dates have a deliberate clear
  Epsilon error; unsorted/duplicate training dates preserve their first-date
  origin rather than being silently normalised.
- The helper is pure, allocation-bounded by input length, and never invokes
  Turing/Python at Julia test runtime.
- No supported model/config surface or public export changes.
- The focused test file, fixture exporter, Runic check, `git diff --check`, and
  source/dependency scope checks pass. Because this phase changes the package
  include graph and a shared model test runner, run the full suite once at the
  final checkpoint only; do not rerun it during ordinary iteration.

## Verification

```bash
PYTHONNOUSERSITE=1 python scripts/export_abacus_fixtures.py
make test-file FILE=test/model/hsgp_time_index.jl
julia --project=@runic -m Runic --check --diff src/mmm/hsgp.jl test/model/hsgp_time_index.jl
git diff --check
test -z "$(git diff --name-only -- Project.toml Manifest.toml)"
# Final checkpoint only, after review:
make test
```

## Risks

| Risk | Mitigation |
|---|---|
| Foundation code is misrepresented as HSGP support | Keep config/model paths rejecting HSGP and ledger status `missing`. |
| Divergence from Abacus's first-date origin | Generate fixtures by calling the real Abacus helper and test backward/forward offsets. |
| Date sorting changes fitted origin silently | Preserve caller order and document that responsibility remains with ingestion. |
| Scope expands into GP modelling | Explicitly prohibit basis, priors, Turing, config, and replay work in this phase. |

## Review Notes

- Fresh-context review required explicit empty, unsorted/duplicate, backward,
  and calendar-boundary cases; signed day arithmetic/divisibility semantics;
  safe expected-error fixture export; and an unexported-helper assertion. All
  are incorporated above.
- The reviewer also required one final full-suite run because the phase changes
  `src/Epsilon.jl` and `test/model/runtests.jl`. This is a one-time closing
  checkpoint under the local verification policy, not an iterative test rule.
- Final verification passed with `make test`: `8,488 / 8,488` tests in
  `20m44.6s` (exit status `0`).
