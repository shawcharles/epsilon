# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-21)

**Core value:** Deliver Abacus-grade Bayesian MMM capability in Julia without
numerical or package-quality regressions.
**Current focus:** Phase 4 - Model Core

## Current Position

**Current Phase:** 4
**Current Phase Name:** Model Core
**Total Phases:** 11
**Current Plan:** 1
**Total Plans in Phase:** 4
**Status:** Phase 3 completed; Phase 4 model/core work is in progress with config scaffolding and builder interfaces landed
**Last Activity:** 2026-04-21
**Last Activity Description:** Added the first builder/orchestration layer with `TimeSeriesMMM`, `build_model`, and deferred fit-state handling on top of the typed config/data surface
**Progress:** 89%
**Paused At:** None

## Performance Metrics

**Velocity:**
- Total plans completed: 4
- Average duration: 0 min
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: none
- Trend: Stable

## Decisions Made

| Phase | Summary | Rationale |
|-------|---------|-----------|
| Bootstrap | Convert existing milestone and architecture docs into a real GSD roadmap | The repo had planning content but no executable planning backbone |
| 1 | Do foundation work before numerical porting | Docs, tests, and package structure should stabilize before deeper model work |
| Bootstrap | Keep the port strategy bottom-up | Lower layers enable parity tests and reduce ambiguity for higher layers |
| 1 | Treat passing local quality gates as the real Phase 1 exit criterion | The repo already had scaffold files, but `make test` and `make docs` had to become true before Phase 2 work |
| 2 | Use generated Julia fixtures from local Abacus runs instead of Python during Julia tests | Keeps parity tests deterministic and keeps Python out of the Julia test runtime |
| 3 | Represent prior config as Julia-native `EpsilonPrior` objects before wiring Turing-specific model code | Keeps Phase 3 testable without coupling config parsing to the eventual model builder |
| 3 | Treat current Abacus special priors as config/runtime compatibility objects first and defer Turing-specific plate behavior to Phase 4 | Preserves momentum while avoiding premature coupling to the unfinished model layer |
| 3 | Do not invent unsupported Abacus custom distributions when the upstream code only exposes a transform or helper concept | Keeps the port anchored to real behavior instead of stale milestone wording |
| 3 | Represent shrinkage priors as recipe objects plus deterministic helper math before the Turing model layer exists | Lets Phase 3 validate serialization and core formulas without faking full probabilistic-program integration |
| 3 | Close Michaelis scope at the saturation layer rather than inventing a separate prior/distribution type | The upstream port target exposes Michaelis-Menten as a transform, so a standalone distribution would add unsupported surface area |
| 4 | Introduce typed config and data containers before building Turing model orchestration | Keeps Phase 4 testable in slices and reduces ambiguity before sampler/builder code lands |

## Pending Todos

- Implement config merging (defaults plus user overrides) on top of the typed loaders.
- Replace the deferred builder/orchestration stubs with the first real Turing-backed `fit!` and `predict` path.
- Decide how model-level dims/plates should map from typed config into the eventual Turing model builder.

## Blockers

- The final HSGP implementation strategy is still unresolved and should be forced early in Phase 5, not discovered late.
- PyMC-to-Turing parameterization differences need focused parity coverage in Phase 3 and Phase 4.

## Session

**Last Date:** 2026-04-21 00:00
**Stopped At:** Builder/orchestration interfaces landed; next step is wiring the first Turing-backed MMM model through them
**Resume File:** None
