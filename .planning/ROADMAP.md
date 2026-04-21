# Roadmap: Epsilon MMM

## Overview

Epsilon moves from package scaffold to a validated Julia MMM stack in eleven
ordered phases. The sequence follows the real dependency graph of the system:
establish package quality first, then build mathematically testable primitives,
then the prior and modeling layers, then inference and post-model workflows,
and only then finish the pipeline, visualization, and release validation work.

## Repository Review Snapshot

Repository review on 2026-04-21 found that the project is partially through
Phase 1 already:

- package scaffold, Makefile, docs scaffold, `.gitignore`, and GitHub Actions
  workflows exist
- `make test` currently fails in `Aqua.jl` because the package has stale
  direct dependencies and no `[compat]` bounds for test extras
- `make docs` currently fails because the exported docstring is not included in
  a canonical `@docs` or `@autodocs` block
- source implementation is still stub-level, so the immediate priority is to
  make the foundation truthful and green before starting numerical port work
- Abacus parity should target the validated MMM/statistical core, not its beta
  Plotly Dash surface

Follow-up on 2026-04-21:

- `make test` now passes locally
- `make docs` now passes locally
- the canonical standards file is back at the repository root
- the fixture export/import path is established through
  `scripts/export_abacus_fixtures.py`
- the full transform layer is implemented and parity-tested
- the prior/distribution layer is implemented, including special and shrinkage
  prior recipes
- typed model/config/data structs plus YAML-backed config loading are now in
  place as the first slice of Phase 4
- the first builder/orchestration shell is now in place through `TimeSeriesMMM`
  and `build_model`, while `fit!`/`predict` still defer execution until the
  Turing model path lands

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions added later if needed

- [x] **Phase 1: Foundation** - Establish the package, tooling, quality gate,
      and repository conventions.
- [x] **Phase 2: Primitives** - Port the mathematical transform layer with
      parity fixtures.
- [x] **Phase 3: Priors and Distributions** - Build the prior specification and
      custom distribution system.
- [ ] **Phase 4: Model Core** - Implement typed config, model builders, and a
      basic runnable MMM.
- [ ] **Phase 5: MMM Features** - Add seasonality, trend, events, controls,
      panel structure, and other model features.
- [ ] **Phase 6: Inference** - Harden sampling, predictive workflows, and
      diagnostics.
- [ ] **Phase 7: Post-Modeling** - Produce contributions, decomposition,
      response curves, and business metrics.
- [ ] **Phase 8: Budget Optimization** - Implement constrained optimization on
      top of modeled response.
- [ ] **Phase 9: Pipeline** - Deliver the end-to-end YAML-driven CLI workflow.
- [ ] **Phase 10: Plotting** - Build the visualization layer for diagnostics and
      MMM outputs.
- [ ] **Phase 11: Validation and Benchmarks** - Prove parity, benchmark
      performance, and prepare v1.0 release artifacts.

## Phase Details

### Phase 1: Foundation
**Goal:** Create a reliable Julia package foundation that supports fast, reproducible iteration on the rest of the roadmap.
**Depends on:** Nothing (first phase)
**Requirements:** [FOUND-01, FOUND-02]
**Success Criteria** (what must be TRUE):
  1. Contributors can run tests, formatting, and docs locally with a standard
     project workflow.
  2. CI validates the package on supported Julia versions and enforces the
     baseline quality gate.
  3. The repository structure matches the agreed technical standards and is
     ready for layer-by-layer implementation.
**Plans:** 3 plans

Plans:
- [x] 01-01: Finalize the canonical contributor surface: standards path,
      contributor references, and repository-facing documentation.
- [x] 01-02: Make the default quality gate pass locally and in CI (`make test`,
      `make docs`, and Runic format checks).
- [x] 01-03: Establish the layer-oriented module/test skeleton and a concrete
      fixture acquisition path for Abacus parity work.

### Phase 2: Primitives
**Goal:** Port the mathematical transform layer and lock down parity at the lowest reusable layer.
**Depends on:** Phase 1
**Requirements:** [TRANS-01]
**Success Criteria** (what must be TRUE):
  1. Users can call convolution, adstock, saturation, and scaling utilities from
     Julia code.
  2. Transform outputs match Abacus fixtures within defined tolerances.
  3. The transform layer is documented and safe to use from higher model layers.
**Plans:** 4 plans

Plans:
- [x] 02-01: Implement convolution primitives and fixture-based tests.
- [x] 02-02: Implement adstock variants with normalization behavior and tests.
- [x] 02-03: Implement saturation variants and parity tests.
- [x] 02-04: Implement scaling, validation helpers, and transform integration
      coverage.

### Phase 3: Priors and Distributions
**Goal:** Create the config-driven prior system and the custom distributions required by the port.
**Depends on:** Phase 2
**Requirements:** [PRIOR-01]
**Success Criteria** (what must be TRUE):
  1. Users can describe priors in config and obtain consistent Julia objects.
  2. Custom and shrinkage priors behave correctly for sampling and log density
     evaluation.
  3. Distribution naming and parameterization differences from PyMC are handled
     in one well-tested layer.
**Plans:** 3 plans

Plans:
- [x] 03-01: Implement prior schema, registry, and config deserialization.
- [x] 03-02: Implement special distributions and their numerical tests.
- [x] 03-03: Implement shrinkage and masked priors with compatibility coverage.

### Phase 4: Model Core
**Goal:** Build the typed core abstractions and a basic runnable MMM path.
**Depends on:** Phase 3
**Requirements:** [MODEL-01, MODEL-02]
**Success Criteria** (what must be TRUE):
  1. Users can load config and data into typed model objects.
  2. Users can build, fit, predict with, and save a basic time-series MMM.
  3. The model core exposes a stable interface that higher MMM features can
     extend without major redesign.
**Plans:** 4 plans

Plans:
- [x] 04-01: Implement model types, config loading, and validation.
- [ ] 04-02: Implement builder interfaces and model orchestration entry points.
- [ ] 04-03: Implement the base MMM `@model` and media-channel path.
- [ ] 04-04: Implement serialization and integration tests for the basic model
      lifecycle.

### Phase 5: MMM Features
**Goal:** Extend the base MMM with the major features needed for practical marketing-mix work.
**Depends on:** Phase 4
**Requirements:** [MODEL-03]
**Success Criteria** (what must be TRUE):
  1. Users can configure seasonality, trend, events, controls, and panel
     structure in supported models.
  2. The feature layer composes with the Phase 4 model interfaces cleanly.
  3. High-risk features such as HSGP have a bounded implementation path and test
     coverage before downstream work depends on them.
**Plans:** 4 plans

Plans:
- [ ] 05-01: Implement seasonality and trend components.
- [ ] 05-02: Implement events and control-variable components.
- [ ] 05-03: Implement panel and hierarchical MMM support.
- [ ] 05-04: Spike and integrate HSGP or an accepted alternative path.

### Phase 6: Inference
**Goal:** Turn the model stack into a robust fitting workflow with diagnostics and predictive sampling.
**Depends on:** Phase 5
**Requirements:** [INFER-01, INFER-02]
**Success Criteria** (what must be TRUE):
  1. Users can run MCMC and VI from config with reproducible settings.
  2. Users can generate prior and posterior predictive outputs.
  3. Diagnostics clearly surface poor mixing, divergence, and convergence
     problems.
**Plans:** 3 plans

Plans:
- [ ] 06-01: Implement MCMC wrappers, multi-chain execution, and diagnostics.
- [ ] 06-02: Implement variational inference and predictive sampling.
- [ ] 06-03: Harden inference configuration, test coverage, and failure
      reporting.

### Phase 7: Post-Modeling
**Goal:** Produce the downstream business outputs analysts need after fitting a model.
**Depends on:** Phase 6
**Requirements:** [POST-01]
**Success Criteria** (what must be TRUE):
  1. Analysts can compute contributions and decomposition from fitted results.
  2. Analysts can generate response curves and marketing metrics such as ROAS.
  3. Post-model outputs remain traceable to modeled quantities and parity tests.
**Plans:** 3 plans

Plans:
- [ ] 07-01: Implement contributions and decomposition outputs.
- [ ] 07-02: Implement response-curve and metric calculations.
- [ ] 07-03: Add parity tests and summary-table generation for analyst outputs.

### Phase 8: Budget Optimization
**Goal:** Optimize media allocation using the modeled response functions and practical constraints.
**Depends on:** Phase 7
**Requirements:** [OPT-01]
**Success Criteria** (what must be TRUE):
  1. Analysts can optimize budget allocations under supported constraints.
  2. The optimizer can target response and efficiency objectives reproducibly.
  3. Optimization outputs are parity-tested against Abacus on agreed fixtures.
**Plans:** 3 plans

Plans:
- [ ] 08-01: Implement optimization objectives and constraint primitives.
- [ ] 08-02: Implement the optimizer orchestration layer and solver integration.
- [ ] 08-03: Add optimization parity tests and reporting outputs.

### Phase 9: Pipeline
**Goal:** Deliver the full YAML-driven workflow that orchestrates Epsilon from configuration to results.
**Depends on:** Phase 8
**Requirements:** [PIPE-01]
**Success Criteria** (what must be TRUE):
  1. Users can invoke an end-to-end pipeline from a CLI command.
  2. Pipeline stages execute in the intended order with clear artifacts and
     error reporting.
  3. The output directory structure is predictable and compatible with the
     project’s documentation and parity goals.
**Plans:** 4 plans

Plans:
- [ ] 09-01: Implement pipeline config, context, and orchestration skeleton.
- [ ] 09-02: Implement metadata, preflight, fit, and assessment stages.
- [ ] 09-03: Implement validation, decomposition, optimization, and reporting
      stages.
- [ ] 09-04: Implement the CLI entry point and end-to-end integration coverage.

### Phase 10: Plotting
**Goal:** Provide a pragmatic Julia-native visualization/reporting layer for model diagnostics and MMM outputs without targeting Dash parity.
**Depends on:** Phase 9
**Requirements:** [PLOT-01]
**Success Criteria** (what must be TRUE):
  1. Users can render the core MMM visual outputs from fitted results.
  2. Plots and exported report artifacts are consistent in theme, labeling, and
     output quality.
  3. Diagnostic visuals support debugging and interpretation of model behavior
     without requiring a replicated interactive dashboard surface.
**Plans:** 3 plans

Plans:
- [ ] 10-01: Implement plot theme and diagnostic plotting foundation.
- [ ] 10-02: Implement contribution, decomposition, and response-curve plots.
- [ ] 10-03: Implement optimization and report-ready visual outputs, keeping the
      UI surface intentionally simpler than Abacus Dash.

### Phase 11: Validation and Benchmarks
**Goal:** Prove that the port is correct, performant, and ready for release.
**Depends on:** Phase 10
**Requirements:** [VAL-01, VAL-02]
**Success Criteria** (what must be TRUE):
  1. Maintainers can run a parity suite that covers the supported v1 surface.
  2. Benchmark results quantify Epsilon performance and release readiness.
  3. Documentation and release notes support a v1.0 release candidate.
**Plans:** 3 plans

Plans:
- [ ] 11-01: Build the parity harness and reference datasets for final
      validation.
- [ ] 11-02: Build and document performance benchmarks.
- [ ] 11-03: Finalize release docs, examples, and v1.0 readiness criteria.

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> ... -> 11

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/3 | Completed | quality gate, standards path, fixture export path |
| 2. Primitives | 4/4 | Completed | convolution, adstock, saturation, scaling |
| 3. Priors and Distributions | 3/3 | Completed | prior schema, distribution mapping, config deserialization, special-prior compatibility, custom distributions, shrinkage recipes |
| 4. Model Core | 1/4 | In progress | typed model/config/data structs, YAML-backed config loading, validation, builder/orchestration shell |
| 5. MMM Features | 0/4 | Not started | - |
| 6. Inference | 0/3 | Not started | - |
| 7. Post-Modeling | 0/3 | Not started | - |
| 8. Budget Optimization | 0/3 | Not started | - |
| 9. Pipeline | 0/4 | Not started | - |
| 10. Plotting | 0/3 | Not started | - |
| 11. Validation and Benchmarks | 0/3 | Not started | - |
