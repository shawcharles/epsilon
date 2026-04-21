# Requirements: Epsilon MMM

**Defined:** 2026-04-21
**Core Value:** Deliver Abacus-grade Bayesian MMM capability in Julia without
sacrificing numerical rigor, reproducibility, or package quality.

## v1 Requirements

### Foundation

- [x] **FOUND-01**: Contributor can instantiate the package, run tests, format
      code, and build docs on supported Julia versions.
- [x] **FOUND-02**: CI enforces the default quality gate for tests,
      formatting, docs, and package health checks.

### Transforms

- [ ] **TRANS-01**: User can apply convolution, adstock, saturation, and
      scaling transforms with parity-tested outputs against Abacus fixtures.

### Priors

- [ ] **PRIOR-01**: User can declare standard and custom priors through config
      and obtain correct Julia/Turing-compatible prior objects.

### Modeling

- [ ] **MODEL-01**: User can load MMM data and configuration into typed Julia
      model structures.
- [ ] **MODEL-02**: User can build, fit, predict with, and serialize a basic
      time-series MMM.
- [ ] **MODEL-03**: User can enable major MMM features including seasonality,
      trend, events, controls, and panel structure.

### Inference

- [ ] **INFER-01**: User can run MCMC and variational inference with configurable
      settings and predictive sampling.
- [ ] **INFER-02**: User can inspect convergence and sampling diagnostics that
      surface common fitting problems.

### Post-Modeling

- [ ] **POST-01**: Analyst can compute channel contributions, decomposition,
      response curves, and business metrics from fitted models.

### Optimization

- [ ] **OPT-01**: Analyst can optimize channel budgets subject to practical
      business constraints.

### Pipeline

- [ ] **PIPE-01**: User can execute an end-to-end YAML-driven MMM workflow from
      a CLI entry point and obtain a structured results directory.

### Visualization

- [ ] **PLOT-01**: User can render or export practical non-Dash visual outputs
      for contributions, response curves, diagnostics, and optimization
      results.

### Validation

- [ ] **VAL-01**: Maintainer can demonstrate numerical parity with Abacus for
      the supported v1 feature set.
- [ ] **VAL-02**: Maintainer can publish performance benchmarks and final usage
      documentation for the v1.0 release candidate.

## v2 Requirements

### Expansion

- **EXP-01**: Support features that intentionally extend beyond Abacus parity.
- **EXP-02**: Add optional acceleration or scale-out strategies once the core
  modeling path is stable.
- **EXP-03**: Explore richer application surfaces such as notebooks, dashboards,
  or hosted workflows.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Hosted UI or reporting app | Not required to validate the Julia package itself |
| Plotly Dash parity with Abacus | The Abacus Dash surface is beta; Epsilon v1 only needs simple Julia-native visual/report outputs |
| AutoML-style model search | Would dilute the parity-first roadmap |
| Non-Bayesian MMM workflows | Outside the core product definition |
| Novel modeling features not present in Abacus | Defer until parity is complete and benchmarked |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 | Completed |
| FOUND-02 | Phase 1 | Completed |
| TRANS-01 | Phase 2 | Pending |
| PRIOR-01 | Phase 3 | Pending |
| MODEL-01 | Phase 4 | Pending |
| MODEL-02 | Phase 4 | Pending |
| MODEL-03 | Phase 5 | Pending |
| INFER-01 | Phase 6 | Pending |
| INFER-02 | Phase 6 | Pending |
| POST-01 | Phase 7 | Pending |
| OPT-01 | Phase 8 | Pending |
| PIPE-01 | Phase 9 | Pending |
| PLOT-01 | Phase 10 | Pending |
| VAL-01 | Phase 11 | Pending |
| VAL-02 | Phase 11 | Pending |

**Coverage:**
- v1 requirements: 15 total
- Mapped to phases: 15
- Unmapped: 0

---
*Requirements defined: 2026-04-21*
*Last updated: 2026-04-21 after initial planning bootstrap*
