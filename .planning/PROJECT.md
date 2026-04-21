# Epsilon MMM

## What This Is

Epsilon.jl is a Julia-native framework for Bayesian Marketing Mix Modeling.
It is being built as a serious port of Abacus: same statistical intent and
parity targets, but expressed with Julia idioms, the Turing ecosystem, and a
package structure that supports long-term maintainability.

## Core Value

Deliver Abacus-grade Bayesian MMM capability in Julia without sacrificing
numerical rigor, reproducibility, or package quality.

## Requirements

### Validated

- [x] Foundation quality gate passes locally (`make test`, `make docs`)
- [x] `batched_convolution` is implemented and parity-tested against Abacus
- [x] `geometric_adstock` is implemented and parity-tested against Abacus

### Active

- [ ] Contributors can develop Epsilon as a normal Julia package with reliable
      tests, docs, formatting, and CI.
- [ ] Users can run the same core MMM transforms and priors as Abacus and get
      parity-tested outputs.
- [ ] Users can define, fit, and inspect MMMs through a Julia-first API and a
      YAML-driven configuration path.
- [ ] Analysts can generate decomposition, response, and optimization outputs
      that are comparable to Abacus.
- [ ] Maintainers can prove parity and benchmark performance before a v1.0
      release.

### Out of Scope

- Web dashboards or a hosted product surface - the initial release is a Julia
  package and CLI, not a SaaS application.
- Plotly Dash feature parity with Abacus - the Abacus statistical core is the
  parity target, while its Dash layer is beta and can be omitted or reduced to
  simpler plots and report artifacts in Epsilon v1.
- Feature expansion beyond Abacus parity - v1.0 should finish the port before
  inventing new MMM methodology.
- Non-Bayesian MMM variants - they dilute the core parity target and testing
  effort.
- GPU/distributed infrastructure work beyond what the chosen Julia inference
  stack already supports - premature until the core model path is stable.

## Context

The repository has the package skeleton, docs scaffold, technical standards,
and planning documents in place, and now has the first transform primitives
landed with parity fixtures. The near-term challenge is to continue building
the mathematical layer methodically rather than broadening scope too early.

The port strategy is bottom-up: first the mathematical primitives, then the
prior system, then the model core, then higher-level features and the pipeline.
This reflects the dependency structure of an MMM stack and makes parity testing
possible at each layer before more complex abstractions are introduced.

## Constraints

- **Tech stack**: Julia 1.10+ with Turing.jl and the Julia scientific stack -
  the package needs to feel native in the Julia ecosystem.
- **Compatibility**: YAML remains a first-class config surface - migration from
  Abacus should not require inventing a new external configuration model.
- **Numerical correctness**: Abacus parity is a release gate - testability beats
  elegance when they conflict.
- **Parity scope**: Abacus parity means validated statistical methodology,
  transforms, priors, models, inference, and downstream analyst outputs; it
  does not require reproducing the beta Dash UI.
- **Engineering quality**: Docs, tests, compat bounds, and CI must evolve with
  code - the package cannot grow as an unverified research prototype.
- **Architecture**: Autodiff-safe, composable building blocks are required -
  inference and transform code must work with Julia AD backends.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Prefer Julia-native design over Python transliteration | Multiple dispatch and composition are a better long-term fit than copying Abacus class hierarchies | Good |
| Build bottom-up from transforms to pipeline | Lower layers unblock parity testing and reduce downstream ambiguity | Good |
| Keep YAML as the external configuration format | It preserves migration ergonomics and maps to the current planning docs | Good |
| Exclude Plotly Dash parity from v1 | Abacus's validated value is in the MMM/statistical core; the Dash layer is beta and not a release gate for Epsilon | Good |
| Start with a simple MMM `@model`, then refactor toward composable components | It reduces early implementation risk while preserving the desired architecture direction | Pending |
| Treat parity, docs, and tests as first-class deliverables in each phase | The project is scientific software, so correctness and reproducibility are product features | Good |

---
*Last updated: 2026-04-21 after GSD planning bootstrap*
