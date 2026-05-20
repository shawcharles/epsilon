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
- [ ] Abacus demo-style `timeseries`, `geo_panel`, and `geo_brand_panel`
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
- [x] Maintainers can prove the bounded v1 methodology and benchmark behavior
      honestly before a v1.0 release.
- [ ] Maintainers can close the external code-review findings around fitted
      prediction state, media-domain validation, and pipeline config parsing
      before release preparation resumes.
- [ ] Maintainers can distinguish `ported`, `native`, `scaffolded`, `missing`,
      and `deferred` surfaces in the Abacus parity ledger before making release
      claims.

### Deferred

- AI advisor functionality - useful product assistance, but not central to the
  statistical or methodological port.
- Plotly Dash / hosted dashboard parity - Epsilon is a Julia package and CLI
  with Julia-native plots and artifacts, not a clone of the Abacus product UI.

### Out of Scope

- Feature work that widens the bounded v1 statistical surface without a clear
  methodological case and test strategy.
- Non-Bayesian MMM variants - they dilute the core bounded methodology and
  testing effort.
- GPU/distributed infrastructure work beyond what the chosen Julia inference
  stack already supports - premature until the core model path is stable.

## Context

The repository has a broad Julia package scaffold and many implemented modules,
but functional parity with Abacus is not yet established at the product level.
Transforms and some primitive behavior have fixture-backed parity. Higher
surfaces - config compilation, panel model semantics, prediction replay,
post-model artifacts, optimization, and pipeline outputs - must now be
revalidated against concrete Abacus demo-style runs instead of treated as
complete because matching modules exist. The active planning document for that
reset is `.planning/ABACUS-PARITY-LEDGER.md`.

The port strategy remains bottom-up, but the acceptance criterion is now
vertical: the `timeseries`, `geo_panel`, and `geo_brand_panel` Abacus
demo-style paths must compile, fit, replay, summarize, optimize, and emit
stable artifacts before Epsilon makes broad release claims.

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
  advisor and Dash/dashboard parity, Abacus statistical and methodological
  functionality should be treated as in scope unless a ledger row explicitly
  says otherwise.
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
| Add Phase 13 before release prep to close external code-review findings | Prediction/replay state and config-validation bugs can invalidate release behavior even after methodology claims are reconciled | Pending |
| Use the Abacus parity ledger as the release roadmap | Module presence is not enough; release claims need fixture-backed or demo-backed evidence | Pending |

---
*Last updated: 2026-05-19 after centered-logistic API cleanup*
