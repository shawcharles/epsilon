# Epsilon MMM

## What This Is

Epsilon.jl is a Julia-native framework for Bayesian Marketing Mix Modeling.
Abacus is the main reference library and comparison baseline for the MMM
statistical and methodological core, but Epsilon is an independent Julia
product and should claim parity only for rows with fixtures, demo acceptance,
or explicit documentation showing that the semantics genuinely match.

## Core Value

Deliver a methodologically coherent Bayesian MMM library in Julia by porting
the validated Abacus statistical and methodological functionality bottom-up,
proving parity where semantics match, and documenting Julia-native divergence
where a direct copy would be less coherent.

## Requirements

### Validated

- [x] Foundation quality gate passes locally (`make test`, `make docs`)
- [x] `batched_convolution` is implemented and parity-tested against Abacus
- [x] The full transform layer is implemented and parity-tested against Abacus
- [x] The prior/distribution layer is implemented and validated as Julia-side compatibility objects
- [x] Abacus demo-style `timeseries`, `geo_panel`, and `geo_brand_panel`
      acceptance targets pass through config/data, model, post-model, and
      pipeline artifact gates.

### Active

- [x] Contributors can develop Epsilon as a normal Julia package with reliable
      tests, docs, and formatting.
- [x] Users can run the supported core MMM transforms and priors through
      documented Epsilon APIs, with Abacus fixture checks retained where the
      semantics genuinely match.
- [x] Users can define, fit, and inspect MMMs through a Julia-first API and a
      YAML-driven configuration path.
- [x] Analysts can generate decomposition, response, and optimization outputs
      that are methodologically coherent and truthfully cross-checkable against
      Abacus where comparison is meaningful on the bounded time-series row.
- [x] Maintainers can prove the bounded v1 methodology and existing benchmark
      methodology honestly before a v1.0 release; any refreshed benchmark
      snapshot remains a separate explicit decision.
- [x] Maintainers can close the external code-review findings around fitted
      prediction state, media-domain validation, and pipeline config parsing
      before release preparation resumes.
- [x] Maintainers can distinguish `ported`, `native`, `scaffolded`, `missing`,
      and `deferred` surfaces in the Abacus parity ledger before making release
      claims.

### Deferred

- Variational inference - permanently retired before release. Epsilon will not
  implement a variational backend; MCMC/Turing is the sole inference contract.
- AI advisor functionality - useful product assistance, but not central to the
  statistical or methodological port.
- Plotly Dash / hosted dashboard parity - Epsilon is a Julia package and CLI
  with Julia-native plots and artifacts, not a clone of the Abacus product UI.

<!-- BEGIN V1 OUT OF SCOPE -->
| Surface | Status | Rationale |
|---|---|---|
| variational_inference | permanently-retired | Epsilon will not implement variational inference; MCMC/Turing is the sole supported fitting path. |
| dashboard_ui | out-of-scope-v1 | Epsilon v1 is a Julia library and artifact-producing workflow, not a Plotly Dash or hosted dashboard clone. |
| ai_advisor | out-of-scope-v1 | Advisor behaviour is product assistance outside the statistical and methodological v1 evidence spine. |
<!-- END V1 OUT OF SCOPE -->

### Out of Scope

- Feature work that widens the bounded v1 statistical surface without a clear
  methodological case and test strategy.
- Non-Bayesian MMM variants - they dilute the core bounded methodology and
  testing effort.
- GPU/distributed infrastructure work beyond what the chosen Julia inference
  stack already supports - premature until the core model path is stable.

## Context

The repository now has a broad Julia package implementation with a
ledger-backed bounded evidence spine for the Abacus-referenced MMM core.
Transforms, primitive behavior, time-series model/replay paths, bounded
calibration, selected panel/brand-panel replay, and pipeline artifact-key
surfaces have fixture-backed or demo-backed evidence where the semantics
genuinely match. `.planning/ABACUS-PARITY-LEDGER.md` remains the source of truth
for which surfaces are `ported`, `native`, `scaffolded`, `missing`, or
`deferred`.

The supported local toy and fixed-schema CSV workflows now have a canonical
runbook at `docs/src/supported_paths.md`. Those workflows, their compact
sidecars, `make smoke`, and trusted-local `.jls` artifact roundtrips are local
confidence and teaching evidence only; they are not benchmarks, release
evidence, portable interchange formats, or Abacus parity evidence.

The port strategy remains bottom-up, but acceptance is vertical: broad release
claims must be backed by the ledger and by concrete `timeseries`, `geo_panel`,
and `geo_brand_panel` evidence rather than by the presence of matching module
names.

## Constraints

- **Tech stack**: Julia 1.10+ with Turing.jl and the Julia scientific stack -
  the package needs to feel native in the Julia ecosystem.
- **Compatibility**: YAML remains a first-class config surface - migration from
  Abacus should be straightforward, but config compatibility does not require
  copying every upstream implementation choice.
- **Numerical correctness**: comparison against Abacus is a major validation
  tool, but methodological coherence wins if literal fidelity would produce a
  weaker or less honest bounded Julia design.
- **Reference scope**: Abacus remains the main external reference for validated
  statistical ideas, methodological behavior, fixtures, and regression checks;
  Epsilon should only claim parity where semantics truly match. Apart from AI
  advisor, Dash/dashboard parity, and variational inference v1 support, Abacus
  statistical and methodological functionality should be treated as in scope
  unless a ledger row explicitly says otherwise.
- **Engineering quality**: Docs, tests, compat bounds, and local quality checks must evolve with
  code - the package cannot grow as an unverified research prototype.
- **Architecture**: Autodiff-safe, composable building blocks are required -
  inference and transform code must work with Julia AD backends.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Prefer Julia-native design over Python transliteration | Multiple dispatch and composition are a better long-term fit than copying Abacus class hierarchies | Good |
| Build bottom-up from transforms to pipeline | Lower layers unblock parity testing and reduce downstream ambiguity | Good |
| Keep YAML as the external configuration format | It preserves migration ergonomics and maps to the current planning docs | Good |
| Defer AI advisor and Plotly Dash/dashboard parity | Abacus's validated value for Epsilon is in the MMM statistical and methodological core; product-assistant and dashboard parity are not release gates | Good |
| Start with a simple MMM `@model`, then refactor toward composable components | It reduces early implementation risk while preserving the desired architecture direction | Pending |
| Treat docs, tests, and comparison evidence as first-class deliverables in each phase | The project is scientific software, so correctness and reproducibility are product features | Good |
| Let methodological coherence beat literal Abacus fidelity when the two conflict | Abacus is a reference library, not a hard requirement to reproduce every implementation detail | Good |
| Reopen the roadmap if the methodology audit invalidates a release claim | Release readiness is subordinate to truthful methodology and documentation | Good |
| Add Phase 13 before release prep to close external code-review findings | Prediction/replay state and config-validation bugs can invalidate release behavior even after methodology claims are reconciled | Closed |
| Use the Abacus parity ledger as the release roadmap | Module presence is not enough; release claims need fixture-backed or demo-backed evidence | Good |
| Permanently retire VI before release in Phase 38 | Epsilon will not own an approximate-inference contract; MCMC/Turing is the sole fitting path | Good |
| Keep local smoke certification separate from release evidence in Phase 39 | Toy and CSV supported-path smoke checks are useful maintenance commands, but they are not benchmarks, release gates, or Abacus parity claims | Good |
| Reconcile planning truth in Phase 40 before choosing more feature work | Stale control docs can misdirect future agents into reopened release-prep or benchmark work despite the current scoped-test and MCMC-only boundaries | Good |
| Document supported local workflows in one canonical runbook | The toy, CSV, compact-output, artifact-roundtrip, and smoke paths are mature enough to document together without recasting them as release, benchmark, or parity evidence | Good |
| Keep current-facing docs aligned with planning state | Stale phase-count or last-updated markers create false resume points and bad next-action recommendations | Good |

---
*Last updated: 2026-07-19 after Phase 44 current docs truth reconciliation*
