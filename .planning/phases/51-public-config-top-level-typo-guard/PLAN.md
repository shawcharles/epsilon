# Phase 51: Public Config Top-Level Typo Guard

Status: Landed

## Objective

Harden `model_config_from_dict` / `load_public_config` against typo-prone
unsupported top-level keys while preserving the small set of intentional
model-level extras.

Phase 13 already made `run_pipeline` fail closed on unsupported top-level YAML
keys, but the lower-level public model-config parser still stores arbitrary
unknown top-level keys in `ModelConfig.extras`. That means direct users can
still silently pass likely mistakes such as `validaton`, `optimisation`, or
runner-only blocks such as `prior_sensitivity` and receive a typed model config
whose intended option was ignored.

This phase closes that direct-parser gap without removing the `extras` field,
without renaming fixtures or reference provenance, and without widening any
pipeline, release, benchmark, or parity surface.

## Contract Boundary

Preserve:

- recognised model config keys: `data`, `target`, `media`, `dimensions`,
  `seasonality`, `trend`, `events`, `holidays`, `controls`, `priors`, `fit`,
  and `calibration`;
- legacy comparison/migration shim key `effects`, which is normalised to
  `seasonality` when it carries `yearly_fourier`;
- intentional current model-level extra `validation`, because existing tests
  and `ModelConfig.extras` usage preserve it;
- programmatic-only `ModelConfig(extras = ...)` behaviour for typed extras such
  as `time_varying_media`.

Reject in `model_config_from_dict` and `load_public_config`:

- misspelled stage/config keys that look intentional but are unsupported:
  `validaton` and `optimisation`;
- pipeline-runner-only top-level blocks that should not be silently stored in a
  direct `ModelConfig`: `optimization`, `prior_sensitivity`, `ai_advisor`, and
  `original_scale_vars`;
- any other unknown top-level key not in the recognised key set or explicit
  public extra allowlist.

Error messages must name every unsupported key deterministically in sorted
order and should point users at either the supported key or the programmatic
`ModelConfig(extras = ...)` path when they really need opaque local state.

## File Allowlist

Implementation may touch only:

- `src/model/config.jl`
- `src/pipeline/config.jl`
- `test/model/config.jl`
- `test/pipeline/config.jl`
- `docs/src/index.md`
- `CHANGELOG.md`
- `.planning/phases/51-public-config-top-level-typo-guard/PLAN.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`

The pre-existing untracked `.planning/CRITICAL-REVIEW-2026-07-19.md` remains
outside this phase and must not be staged.

## Tasks

### Task 51-01: Add Public Config Top-Level Guard

Implement a small source-level guard in `src/model/config.jl` before
`ModelConfig` construction.

Acceptance criteria:

- [x] `model_config_from_dict` rejects unsupported unknown top-level keys before
      constructing `ModelConfig`.
- [x] `load_public_config` rejects the same unsupported keys after YAML loading
      and path/default/override merging.
- [x] `run_pipeline` keeps accepting pipeline-runner-only top-level blocks by
      stripping them before the direct model parser is called.
- [x] The error includes the sorted unsupported key names.
- [x] Existing accepted top-level keys, `effects`, and `validation` still work.
- [x] Programmatic `ModelConfig(extras = ...)` remains unchanged.

Verification:

- [x] `make test-file FILE=test/model/config.jl` (`143 / 143`, `19.4s`)
- [x] `make test-file FILE=test/pipeline/config.jl` (`66 / 66`, `12.8s`)

### Task 51-02: Focused Tests And Documentation

Add focused config tests and update current-facing docs/changelog for the
public behaviour change.

Acceptance criteria:

- [x] Tests reject `validaton`, `optimisation`, `optimization`,
      `prior_sensitivity`, and an arbitrary unknown key through
      `model_config_from_dict`.
- [x] Tests reject unsupported keys through `load_public_config`.
- [x] Pipeline config tests prove `optimization`, `prior_sensitivity`,
      `ai_advisor`, and `original_scale_vars` remain accepted by `run_pipeline`
      where those keys are part of the pipeline-level contract.
- [x] Tests preserve `validation` as an intentional model-level extra.
- [x] Tests preserve the `effects` yearly Fourier shim.
- [x] `docs/src/index.md` records that public model config parsing now rejects
      unsupported top-level keys as well as pipeline YAML, and that preserved
      extras such as `validation` are narrow compatibility allowances rather
      than a generic YAML escape hatch.
- [x] `CHANGELOG.md` records the stricter public config contract.

Verification:

- [x] `make test-file FILE=test/model/config.jl` (`143 / 143`, `19.4s`)

### Task 51-03: Planning Closure

Update roadmap and state after focused verification passes.

Acceptance criteria:

- [x] `.planning/ROADMAP.md` records Phase 51.
- [x] `.planning/STATE.md` records the landed scope and exact scoped
      verification.
- [x] This plan is marked landed.
- [x] The parity ledger is not changed; this is public config hygiene, not a
      new reference-parity claim.

Verification:

- [x] `make format-check-touched`
- [x] `git diff --check`
- [x] `git diff --cached --check`
- [x] exact changed-file allowlist check

## Out Of Scope

- Changing pipeline top-level allowlist semantics except stripping already
  allowed runner-only keys before model-config parsing.
- Adding a general public `extras:` YAML block.
- Removing or renaming `ModelConfig.extras`.
- Changing typed `ModelConfig(extras = ...)` programmatic behaviour.
- Renaming fixture directories, generated constants, exporter scripts, or
  planning ledgers.
- Benchmarks, release-prep, smoke harness changes, docs build, or full-suite
  checks.
- Any new reference-parity or release-readiness claim.

## Verification Plan

Use scoped checks only:

```bash
make test-file FILE=test/model/config.jl
make test-file FILE=test/pipeline/config.jl
make format-check-touched
git diff --check
git diff --cached --check
```

No full suite is required. This slice changes the public model-config top-level
guard, strips already allowed runner-only keys before pipeline model parsing,
updates focused config tests, and adds small docs/planning/changelog text. It
does not touch exports, shared test namespace imports, dependencies, manifests,
model runtime, MCMC, pipeline stage execution, generated fixtures, or
parity-ledger status.

## Independent Review Questions

Before implementation, an independent review must check:

- whether the proposed allowlist preserves currently intentional extras;
- whether rejecting arbitrary unknown top-level keys in `model_config_from_dict`
  is too strict for existing public usage;
- whether `effects` and `validation` are the right preserved non-model keys;
- whether `optimization` should be rejected in the direct model parser while
  remaining accepted by `run_pipeline`;
- whether docs/changelog should be included because this is a public behaviour
  change;
- whether the file allowlist is tight enough; and
- whether scoped verification is sufficient.

Review result before implementation:

- The reviewer agreed that rejecting arbitrary unknown top-level keys in
  `model_config_from_dict` is the right direction.
- The reviewer confirmed `effects` should be preserved as a migration shim and
  `validation` may remain a narrow compatibility extra.
- The reviewer required plan revision before implementation because
  `ai_advisor` and `original_scale_vars` are currently allowed by `run_pipeline`
  but not stripped before model parsing. The implementation must either strip
  them in the pipeline path or narrow the direct-parser rejection list. This
  plan chooses to strip already allowed runner-only keys in
  `src/pipeline/config.jl` and verify `test/pipeline/config.jl`.
- The reviewer required docs to clarify that preserved extras are narrow
  compatibility allowances, not a general YAML escape hatch.

## Landing Notes

Implemented as a bounded public config contract hardening slice:

- `model_config_from_dict` now rejects unsupported top-level keys after
  compatibility normalisation and before typed `ModelConfig` construction;
- error messages list unsupported keys in deterministic sorted order and direct
  opaque state users to programmatic `ModelConfig(extras = ...)`;
- the existing `effects` migration shim and `validation` compatibility extra
  remain accepted;
- `ModelConfig(extras = ...)` programmatic construction remains unchanged; and
- `run_pipeline` strips already allowed runner-only `ai_advisor` and
  `original_scale_vars` blocks before calling the direct model parser, matching
  the existing stripping policy for `validation`, `prior_sensitivity`, and
  `optimization`.
