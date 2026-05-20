# Requirements: Epsilon MMM

**Defined:** 2026-04-21
**Core Value:** Deliver a methodologically coherent Bayesian MMM library in
Julia, informed by Abacus and validated against it where comparison is
meaningful, without sacrificing numerical rigor, reproducibility, or package
quality.

## v1 Requirements

### Foundation

- [x] **FOUND-01**: Contributor can instantiate the package, run tests, format
      code, and build docs on supported Julia versions.
- [x] **FOUND-02**: The default local quality gate covers tests, formatting,
      docs, and package health checks.

### Transforms

- [x] **TRANS-01**: User can apply convolution, adstock, saturation, and
      scaling transforms with parity-tested outputs against Abacus fixtures.

### Priors

- [x] **PRIOR-01**: User can declare standard and custom priors through config
      and obtain correct Julia-side prior recipes and distribution wrappers
      that are ready for later Turing integration.

### Modeling

- [x] **MODEL-01**: User can load MMM data and configuration into typed Julia
      model structures.
- [x] **MODEL-02**: User can build, fit, predict with, and serialize a basic
      time-series MMM.
- [x] **MODEL-03**: User can enable the supported Phase 5 MMM feature contract
      for seasonality, trend, events, richer controls, and a bounded
      panel/hierarchical path, with exact supported keys and combinations
      documented.

### Inference

- [x] **INFER-01**: User can run truthful MCMC via `fit!` and a bounded explicit
      VI path via `approximate_fit!`, with external config semantics that stay
      honest about which backend they control.
- [x] **INFER-02**: User can inspect convergence, sampler diagnostics, and
      explicit warning/failure surfaces that expose common fitting problems on
      the supported inference paths.
- [x] **INFER-03**: User can materialize and persist grouped inference artifacts
      through one canonical Julia-native `InferenceResults` surface with
      predictive groups, observed data, coordinates, and metadata preserved for
      later phases.

### Post-Modeling

- [x] **POST-01**: Analyst can compute channel contributions, decomposition,
      response curves, and business metrics from supported grouped
      `InferenceResults` on the frozen time-series surface.

### Optimization

- [x] **OPT-01**: Analyst can optimize channel budgets subject to practical
      business constraints.

### Pipeline

- [x] **PIPE-01**: User can execute an end-to-end YAML-driven MMM workflow from
      a CLI entry point and obtain a structured results directory.

### Visualization

- [x] **PLOT-01**: User can render or export practical non-Dash visual outputs
      for contributions, response curves, diagnostics, and optimization
      results.

### Validation

- [x] **VAL-01**: Maintainer can demonstrate honest Abacus-reference
      comparison for the supported rows whose semantics genuinely match, and
      explicit contract-validation for the bounded Epsilon-only supported rows
      in the final release gate.
- [x] **VAL-02**: Maintainer can publish performance benchmarks and final usage
      documentation for the v1.0 release candidate.

### Parity Remediation

- [x] **PAR-01**: Maintainer can reconcile the bounded time-series methodology
      and release claim honestly: shared channel/target scaling semantics,
      explicit original-scale reconstruction, truthful Stage 60 curve families,
      downstream optimization semantics built on that corrected contract, and a
      coherent holiday/trend/seasonality design in which automatic holidays are
      not misrepresented as Abacus parity unless a true compatibility mode
      exists.

### Prediction-State and Contract Remediation

- [ ] **PRED-01**: Maintainer can prove that trend-enabled and holiday-enabled
      prediction/replay paths use fitted feature state rather than state
      recomputed from arbitrary holdout slices, and that media input validation
      plus pipeline YAML parsing reject misleading invalid inputs before
      release preparation resumes.

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
| AutoML-style model search | Would dilute the bounded methodology-first roadmap |
| Non-Bayesian MMM workflows | Outside the core product definition |
| Novel modeling features without a clear methodological case | Defer until the bounded methodology is settled and benchmarked |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 | Phase 1 | Completed |
| FOUND-02 | Phase 1 | Completed |
| TRANS-01 | Phase 2 | Completed |
| PRIOR-01 | Phase 3 | Completed |
| MODEL-01 | Phase 4 | Completed |
| MODEL-02 | Phase 4 | Completed |
| MODEL-03 | Phase 5 | Completed |
| INFER-01 | Phase 6 | Completed |
| INFER-02 | Phase 6 | Completed |
| INFER-03 | Phase 6 | Completed |
| POST-01 | Phase 7 | Completed |
| OPT-01 | Phase 8 | Completed |
| PIPE-01 | Phase 9 | Completed |
| PLOT-01 | Phase 10 | Completed |
| VAL-01 | Phase 12 | Completed |
| VAL-02 | Phase 11 | Completed |
| PAR-01 | Phase 12 | Completed |
| PRED-01 | Phase 13 | Planned |

**Coverage:**
- v1 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0

---
*Requirements defined: 2026-04-21*
*Last updated: 2026-04-24 after Phase 13 planning*
