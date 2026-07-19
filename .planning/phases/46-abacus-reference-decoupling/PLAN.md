# Phase 46: Abacus Reference Decoupling Plan

## Status

Landed. This planning and audit phase is complete.

## Objective

Design the path for Epsilon to stand publicly as an independent Julia MMM
library while preserving the internal validation provenance that currently
makes its numerical and methodological claims auditable.

The core rule is simple: public identity should become Epsilon-first, but
validation history must not be laundered. References to Abacus should be
removed, renamed, or reframed only after each occurrence is classified by
audience and purpose.

## Inventory Method

Authoritative tracked-file inventory was generated from the repository root
with:

```bash
git ls-files \
  | grep -Ev '(^Manifest\.toml$|\.jls$|^\.planning/phases/46-abacus-reference-decoupling/)' \
  | xargs rg -i --count-matches "abacus"
```

This keeps the audit durable against local ignored artifacts while still
including tracked files that happen to sit under ignored path patterns.

Current inventory, excluding `Manifest.toml`, binary/local `.jls` artifacts,
and this Phase 46 plan directory itself:

| Area | Files With References | Current Role |
|---|---:|---|
| Root docs (`README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `TECHNICAL-STANDARDS.md`) | 4 | Public identity, historical release notes, contributor guidance |
| Source docs (`docs/src/`) | 6 | Public user documentation, benchmark/release/support pages |
| Built docs (`docs/build/`) | 7 | Generated documentation output; rebuild, do not hand-edit |
| Planning docs (`.planning/`) | 90 | Historical plans, parity ledger, methodology reviews, state, roadmap |
| Source files (`src/`) | 6 | Public docstrings, compatibility comments, method naming rationale |
| Fixture exporter scripts (`scripts/`) | 1 | Internal fixture-generation machinery |
| Fixture files (`test/fixtures/abacus/`) | 29 | Generated validation fixtures and provenance headers |
| Non-fixture tests (`test/`) | 23 | Regression, parity, and validation checks |
| Examples (`examples/`) | 11 | Demo data, demo configs, user-facing example docs |
| Benchmarks (`benchmark/`) | 2 | Historical benchmark infrastructure and notes |
| **Total** | **172** | **1821 matches** |

Optional local scrub audits may additionally use `rg --hidden --no-ignore` to
inspect ignored generated docs, local guidance, handoff logs, and temporary
benchmark outputs. Those local artifacts are not authoritative inputs for a
committed rewrite plan.

## Classification Contract

Every future edit must classify each touched reference into one of these
classes before changing text or paths.

| Class | Meaning | Default Action | Examples |
|---|---|---|---|
| Public identity language | Makes Epsilon sound like a port, clone, or dependent product | Reframe first | README tagline, docs home intro, examples readmes |
| Public evidence boundary | Explains what is and is not validated against a reference | Reframe carefully, keep comparison honesty | release gate, benchmarks, supported workflow disclaimers |
| Internal validation provenance | Needed to reproduce fixture-backed checks or understand committed evidence | Keep until replacement validation artifact exists | `test/fixtures/abacus/`, exporter scripts, fixture headers |
| Historical planning record | Explains why earlier decisions were made | Usually keep; optionally add forward pointer | old phase plans, methodology reviews, changelog |
| API/test implementation detail | Names fixtures, constants, or tests around a comparison baseline | Rename only with migration plan and focused tests | `ABACUS_*` fixture constants, `test/validation/parity.jl` |
| Dead scaffolding | No longer used by code, docs, or validation | Candidate for deletion | stale handoffs, obsolete scripts after audit |

## Public Language Rules

Future public docs should prefer Epsilon-first wording:

- Use "Epsilon is a Julia-native Bayesian MMM library" as the lead identity.
- Use "validated against a production reference implementation where semantics
  match" only when the specific evidence remains relevant.
- Use "comparison-backed" or "fixture-backed" instead of broad "parity" unless
  the parity ledger explicitly supports the claim.
- Avoid "Abacus Julia port" and "full Abacus parity" in public-facing current
  status language.
- Keep explicit caveats that local smoke workflows, toy examples, and
  trusted-local `.jls` roundtrips are not benchmarks, release evidence, or
  reference-parity evidence.

## Future Implementation Sequence

### 46-01: Plan And Review

- [x] Record this inventory, classification contract, and rewrite boundary.
- [x] Run an independent review before any scrub implementation.
- [x] Resolve review findings before marking the plan complete.

### 46-02: Public Identity Rewrite Plan

This is the recommended next implementation phase after Phase 46, not part of
Phase 46 itself.

Candidate file allowlist:

- `README.md`
- `CONTRIBUTING.md`
- `TECHNICAL-STANDARDS.md`
- `docs/src/index.md`
- `docs/src/release.md`
- `docs/src/api.md`
- `docs/src/calibration.md`
- `docs/src/benchmarks.md`
- `docs/src/supported_paths.md`
- `examples/toy_mmm/README.md`
- `examples/csv_mmm/README.md`
- `examples/demo/README.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`
- `.planning/phases/47-public-identity-rewrite/PLAN.md`
- `test/api_exports.jl`

Expected work:

- Replace public "port" and direct-dependence language with Epsilon-first
  identity language.
- Audit contributor and standards docs separately: keep reference-validation
  rules where they are still needed, but remove language that makes Epsilon's
  public identity dependent on another project.
- Preserve concrete validation provenance where the user needs to understand
  what evidence exists.
- Add or update a docs-claim guard that prevents reintroducing public
  "Abacus port" identity claims.
- Do not rename fixture directories, generated constants, exporter scripts, or
  parity-ledger files in this phase.

### 46-03: Internal Provenance Rename Assessment

This should remain a later optional phase.

Candidate questions:

- Should `test/fixtures/abacus/` eventually become
  `test/fixtures/reference/`?
- Should `ABACUS_*` generated constants become `REFERENCE_*` constants?
- Should `.planning/ABACUS-PARITY-LEDGER.md` become a generic
  `REFERENCE-VALIDATION-LEDGER.md`?
- What migration compatibility is required for old reports, fixture exporters,
  and test names?

Do not start this until the public rewrite is complete and tests show the new
language contract is stable.

### 46-04: Historical Archive Policy

This should remain a later optional phase.

Candidate work:

- Add a short "Historical Reference Notes" preamble to old planning directories
  rather than editing dozens of historical records.
- Leave `CHANGELOG.md` factual: historical references should remain historical.
- Archive stale handoffs only if they are not used by current state docs.

## Out of Scope For Phase 46

- Editing runtime code, tests, examples, docs prose, fixture files, or exporter
  behavior beyond this plan and planning-state hooks.
- Renaming `test/fixtures/abacus/`.
- Renaming `.planning/ABACUS-PARITY-LEDGER.md`.
- Changing fixture constants or generated file headers.
- Changing release, benchmark, parity, or support claims.
- Running the full test suite, `make smoke`, benchmarks, or release gates.

## Acceptance Criteria

- The plan records the current file-level inventory and match-count summary.
- The plan separates public identity cleanup from internal validation
  provenance.
- The plan gives a bounded future public rewrite allowlist.
- The plan explicitly prevents premature fixture, exporter, test-constant, or
  parity-ledger renames.
- `.planning/ROADMAP.md` and `.planning/STATE.md` record Phase 46 as a
  planning-only phase.

## Verification

Use planning-only checks:

```bash
git ls-files \
  | grep -Ev '(^Manifest\.toml$|\.jls$|^\.planning/phases/46-abacus-reference-decoupling/)' \
  | xargs rg -i --count-matches "abacus"
make format-check-touched
git diff --check
git diff --cached --check
git status --short
```

No full suite, docs build, smoke run, benchmark, fixture regeneration, or
release gate is required.

Actual verification:

- [x] Tracked inventory command returned `172` files and `1821` matches.
- [x] `make format-check-touched`
- [x] `git diff --check`
- [x] `git diff --cached --check`
- [x] `git status --short`

## Risks

- **Premature provenance deletion:** deleting internal reference language before
  replacing the validation narrative would weaken trust. Mitigation: separate
  public identity cleanup from internal fixture/provenance work.
- **Over-broad public rewrite:** touching every historical planning file would
  create noise and make review harder. Mitigation: start with current public
  docs only, then decide whether old archives need a preamble.
- **Path rename churn:** renaming fixtures and constants would create a large
  mechanical diff with little user value. Mitigation: defer internal renames
  until after public-language cleanup proves stable.

## Inventory Appendix

File-level snapshot from the tracked-file inventory command above:

```text
.planning/ABACUS-PARITY-LEDGER.md:147
.planning/API-EXPORT-TRIAGE.md:1
.planning/API-RUNTIME-DEPRECATION-DESIGN.md:2
.planning/ARCHITECTURE.md:14
.planning/CODE-REVIEW-2026-07-05.md:23
.planning/COMPONENT-MAPPING.md:18
.planning/DEPENDENCIES.md:7
.planning/GSD-BOARD.md:17
.planning/METHODOLOGY_AUDIT.md:65
.planning/MILESTONES.md:19
.planning/PAUSE-HANDOFF-2026-07-06.md:1
.planning/PROJECT.md:22
.planning/README.md:2
.planning/REQUIREMENTS.md:7
.planning/RISKS-AND-DECISIONS.md:30
.planning/ROADMAP.md:63
.planning/STATE.md:51
.planning/phases/07-post-modeling/PLAN.md:5
.planning/phases/08-budget-optimization/PLAN.md:7
.planning/phases/10-plotting/PLAN.md:2
.planning/phases/11-validation-and-benchmarks/PLAN.md:45
.planning/phases/12-parity-remediation/.continue-here.md:8
.planning/phases/12-parity-remediation/PLAN.md:36
.planning/phases/13-prediction-state-and-contract-remediation/PLAN.md:2
.planning/phases/14-abacus-parity-recovery/.continue-here.md:31
.planning/phases/14-abacus-parity-recovery/PLAN.md:17
.planning/phases/15-calibration-likelihood-integration/.continue-here.md:5
.planning/phases/15-calibration-likelihood-integration/PLAN.md:36
.planning/phases/16-scenario-planner-manual-allocation/.continue-here.md:1
.planning/phases/16-scenario-planner-manual-allocation/PLAN.md:2
.planning/phases/17-calibration-yaml-pipeline/PLAN.md:1
.planning/phases/18-scenario-store-artifacts/PLAN.md:3
.planning/phases/19-public-api-export-hygiene/PLAN.md:10
.planning/phases/20-public-api-docstring-guard/PLAN.md:6
.planning/phases/21-public-api-export-triage/PLAN.md:5
.planning/phases/22-public-api-export-cleanup-rfc/PLAN.md:3
.planning/phases/23-runtime-deprecation-design/PLAN.md:3
.planning/phases/23-runtime-deprecation-design/handoff/ARCHITECT-BRIEF.md:1
.planning/phases/23-runtime-deprecation-design/handoff/REVIEW-REQUEST.md:1
.planning/phases/24-runtime-deprecation-wrappers/PLAN.md:5
.planning/phases/24-runtime-deprecation-wrappers/handoff/ARCHITECT-BRIEF.md:1
.planning/phases/24-runtime-deprecation-wrappers/handoff/BUILD-LOG.md:1
.planning/phases/24-runtime-deprecation-wrappers/handoff/REVIEW-REQUEST.md:1
.planning/phases/25-focused-test-file-harness/handoff/REVIEW-FEEDBACK.md:1
.planning/phases/25-focused-test-file-harness/handoff/REVIEW-REQUEST.md:1
.planning/phases/26-deprecated-validation-helper-migration-audit/PLAN.md:3
.planning/phases/26-deprecated-validation-helper-migration-audit/handoff/ARCHITECT-BRIEF.md:1
.planning/phases/26-deprecated-validation-helper-migration-audit/handoff/REVIEW-FEEDBACK.md:1
.planning/phases/26-deprecated-validation-helper-migration-audit/handoff/REVIEW-REQUEST.md:1
.planning/phases/27-scope-boundary-reconciliation/PLAN.md:2
.planning/phases/27-scope-boundary-reconciliation/handoff/ARCHITECT-BRIEF.md:3
.planning/phases/27-scope-boundary-reconciliation/handoff/BUILD-LOG.md:3
.planning/phases/27-scope-boundary-reconciliation/handoff/PLAN-REVIEW.md:2
.planning/phases/27-scope-boundary-reconciliation/handoff/REVIEW-REQUEST.md:1
.planning/phases/28-toy-mcmc-smoke-demo/PLAN.md:6
.planning/phases/28-toy-mcmc-smoke-demo/handoff/ARCHITECT-BRIEF.md:4
.planning/phases/28-toy-mcmc-smoke-demo/handoff/BUILD-LOG.md:3
.planning/phases/28-toy-mcmc-smoke-demo/handoff/PLAN-REVIEW.md:3
.planning/phases/28-toy-mcmc-smoke-demo/handoff/REVIEW-FEEDBACK.md:1
.planning/phases/28-toy-mcmc-smoke-demo/handoff/REVIEW-REQUEST.md:2
.planning/phases/29-toy-mcmc-path-hardening/PLAN.md:2
.planning/phases/30-csv-timeseries-quickstart/PLAN.md:3
.planning/phases/31-hsgp-time-index-foundation/PLAN.md:13
.planning/phases/32-hsgp-linearized-geometry-foundation/PLAN.md:21
.planning/phases/33-hsgp-softplus-positive-multiplier/PLAN.md:21
.planning/phases/34-hsgp-fitted-positive-multiplier-replay/PLAN.md:18
.planning/phases/35-timeseries-hsgp-media-methodology-contract/PLAN.md:16
.planning/phases/36-timeseries-hsgp-shared-media-multiplier/PLAN.md:14
.planning/phases/37-hsgp-timeseries-contribution-replay/PLAN.md:2
.planning/phases/38-permanent-vi-surface-retirement/PLAN.md:1
.planning/phases/39-supported-path-smoke-certification/PLAN.md:3
.planning/phases/40-planning-truth-reconciliation/PLAN.md:6
.planning/phases/41-supported-path-output-usability/PLAN.md:3
.planning/phases/42-supported-path-artifact-roundtrip/PLAN.md:5
.planning/phases/43-supported-path-user-workflow-runbook/PLAN.md:5
.planning/phases/44-current-docs-truth-reconciliation/PLAN.md:14
.planning/phases/45-current-docs-claim-guard/PLAN.md:11
.planning/prompts/code-review-prompt.md:1
.planning/prompts/external-methodology-review_trend-seasonality-holidays-hsgp.md:19
.planning/prompts/planning-review-prompt.md:1
.planning/reviews/2026-05-19-critical-review.md:6
.planning/reviews/2026-05-19-senior-engineer-recommendation.md:4
.planning/reviews/code-review-v0.md:6
.planning/reviews/code-review-v2.md:1
.planning/reviews/code-review-v4.md:3
.planning/reviews/external-methodology-advice_trend-seasonality-holidays-hsgp.md:15
.planning/reviews/planning-review_12-02.md:11
.planning/reviews/planning-review_12-03.md:16
.planning/reviews/planning-review_v0.md:1
.planning/reviews/planning-review_v1.md:2
CHANGELOG.md:18
CONTRIBUTING.md:1
README.md:35
TECHNICAL-STANDARDS.md:4
benchmark/README.md:2
benchmark/run_benchmarks.jl:3
docs/src/api.md:4
docs/src/benchmarks.md:2
docs/src/calibration.md:3
docs/src/index.md:21
docs/src/release.md:21
docs/src/supported_paths.md:2
examples/csv_mmm/README.md:1
examples/demo/README.md:11
examples/demo/epsilon/timeseries/config.yml:2
examples/demo/results/demo-timeseries_20260423_203231/00_run_metadata/config.original.yaml:1
examples/demo/results/demo-timeseries_20260423_203231/00_run_metadata/config.resolved.yaml:1
examples/demo/results/demo-timeseries_20260423_212314/00_run_metadata/config.original.yaml:1
examples/demo/results/demo-timeseries_20260423_212314/00_run_metadata/config.resolved.yaml:1
examples/demo/results/demo-timeseries_20260423_213308/00_run_metadata/config.original.yaml:1
examples/demo/results/demo-timeseries_20260423_213308/00_run_metadata/config.resolved.yaml:1
examples/demo/run_demo.jl:18
examples/toy_mmm/README.md:1
scripts/export_abacus_fixtures.py:237
src/mmm/calibration.jl:32
src/mmm/seasonality.jl:1
src/model/builder.jl:1
src/model/config.jl:8
src/scenario_planner.jl:3
src/transforms/adstock.jl:1
test/api_exports.jl:6
test/fixtures/abacus/README.md:32
test/fixtures/abacus/batched_convolution_cases.jl:5
test/fixtures/abacus/binomial_adstock_cases.jl:5
test/fixtures/abacus/calibration_alignment_cases.jl:5
test/fixtures/abacus/calibration_channel_scaling_cases.jl:5
test/fixtures/abacus/calibration_combined_scaling_cases.jl:5
test/fixtures/abacus/calibration_integration_cases.jl:5
test/fixtures/abacus/calibration_monotonic_cases.jl:5
test/fixtures/abacus/calibration_target_scaling_cases.jl:5
test/fixtures/abacus/calibration_unaligned_cases.jl:5
test/fixtures/abacus/cost_per_target_cases.jl:5
test/fixtures/abacus/delayed_adstock_cases.jl:5
test/fixtures/abacus/geo_brand_panel/config_data.jl:9
test/fixtures/abacus/geo_panel/config_data.jl:9
test/fixtures/abacus/geometric_adstock_cases.jl:5
test/fixtures/abacus/hill_function_cases.jl:5
test/fixtures/abacus/hsgp_fitted_replay_cases.jl:5
test/fixtures/abacus/hsgp_linearized_cases.jl:5
test/fixtures/abacus/hsgp_positive_multiplier_cases.jl:5
test/fixtures/abacus/hsgp_time_index_cases.jl:5
test/fixtures/abacus/hsgp_time_varying_media_cases.jl:5
test/fixtures/abacus/lift_test_likelihood_cases.jl:5
test/fixtures/abacus/logistic_saturation_cases.jl:5
test/fixtures/abacus/michaelis_menten_cases.jl:5
test/fixtures/abacus/optimization/cases.jl:5
test/fixtures/abacus/postmodel_summary_cases.jl:5
test/fixtures/abacus/tanh_saturation_cases.jl:5
test/fixtures/abacus/timeseries/config_data.jl:9
test/fixtures/abacus/weibull_adstock_cases.jl:5
test/model/builder.jl:6
test/model/calibration.jl:20
test/model/hsgp_fitted_replay.jl:4
test/model/hsgp_linearized.jl:3
test/model/hsgp_positive_multiplier.jl:3
test/model/hsgp_time_index.jl:2
test/model/time_varying_media.jl:3
test/optimization/summary.jl:3
test/pipeline/demo.jl:4
test/pipeline/run.jl:75
test/postmodel/summary.jl:4
test/scenario_planner.jl:1
test/transforms/adstock.jl:12
test/transforms/convolution.jl:3
test/transforms/saturation.jl:12
test/validation/geo_brand_panel_config_data.jl:4
test/validation/geo_brand_panel_model_replay.jl:5
test/validation/geo_panel_config_data.jl:4
test/validation/geo_panel_model_replay.jl:5
test/validation/parity.jl:2
test/validation/timeseries_config_data.jl:4
test/validation/timeseries_model_replay.jl:5
```

## Review Notes

Independent review completed before closure. Findings and resolution:

- Medium: the first inventory used `--no-ignore`, which made ignored generated
  docs and local artifacts look authoritative. Fixed by switching the
  authoritative command to tracked files from `git ls-files`, excluding this
  Phase 46 plan directory to avoid self-count drift.
- Low: the future public rewrite allowlist did not include root contributor and
  standards docs even though those files contain governance references. Fixed by
  adding `CONTRIBUTING.md` and `TECHNICAL-STANDARDS.md` to the candidate
  allowlist and requiring a separate audit of their validation-rule language.
- The reviewer confirmed that public identity cleanup is safely separated from
  fixture paths, exporter scripts, generated constants, and the parity ledger.
