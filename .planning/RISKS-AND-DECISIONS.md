# Risks & Decisions — Epsilon MMM

> Technical risks, open questions, and Architecture Decision Records (ADRs).

---

## Technical Risks

### 🔴 High Risk

#### R1: HSGP (Hilbert Space Gaussian Processes)

**Risk:** HSGP is a critical feature in Abacus (used for flexible seasonality). PyMC has a built-in `pm.gp.HSGP` implementation. The Julia GP ecosystem (`AbstractGPs.jl`) does not have a direct HSGP equivalent.

**Impact:** If we can't port HSGP, we lose a key differentiator of Abacus over simpler Fourier seasonality.

**Mitigation:**
1. **Spike early** (Phase 4, week 1): Investigate AbstractGPs.jl capabilities and Stheno.jl
2. **Fallback A:** Port the HSGP math manually from PyMC's source code (basis functions + spectral density → Turing @model). This is feasible since HSGP is ultimately a linear approximation.
3. **Fallback B:** Use Fourier seasonality as default; HSGP as optional advanced feature added later.
4. **Reference:** [Riutort-Mayol et al., 2023](https://arxiv.org/abs/2004.11408) — the original HSGP paper.

**Owner:** TBD  
**Status:** 🔴 Not started

---

#### R2: Deterministic Tracking in Turing.jl

**Risk:** Abacus uses `pm.Deterministic` extensively (~80 references) to track intermediate values during sampling (channel contributions, transformed media, response curves). Turing.jl doesn't have a direct equivalent — it requires `generated_quantities()` as a post-hoc step, which means deterministics are computed AFTER sampling, not during.

**Impact:** If `generated_quantities` is slow or doesn't support all needed intermediate values, post-modeling analysis (contributions, response curves) could be incomplete or slow.

**Mitigation:**
1. Test `generated_quantities` performance with 10+ return values on realistic model sizes.
2. If too slow, consider caching the `@model` return values during sampling (Turing supports this via `returned` argument in newer versions).
3. Alternative: Use `DynamicPPL.@submodel` for composable sub-models that expose tracked quantities.

**Owner:** TBD  
**Status:** 🔴 Not started

---

#### R3: Autodiff Compatibility

**Risk:** All transforms (adstock, saturation, convolution) must work with Turing's autodiff backends (ForwardDiff.jl, ReverseDiff.jl). Julia code with mutation (e.g., `x[i] = ...`) may break ReverseDiff. The batched convolution uses loops and indexing that may not differentiate cleanly.

**Impact:** If transforms aren't autodiff-compatible, NUTS sampling won't work → project-blocking.

**Mitigation:**
1. Test each transform with `ForwardDiff.gradient` and `ReverseDiff.gradient` immediately after implementation.
2. Avoid in-place mutation in transform hot paths. Use functional style: `map`, broadcasting, `reduce`.
3. If ReverseDiff fails, try `Zygote.jl` or `Enzyme.jl` as alternative backends.
4. Write custom `ChainRulesCore.rrule` if needed for specific transforms.

**Owner:** TBD  
**Status:** 🔴 Not started

---

### 🟡 Medium Risk

#### R4: Turing.jl Performance on Large Models

**Risk:** Abacus models can be large (100+ parameters for panel models with many geos/channels). Turing.jl's performance on high-dimensional models may degrade versus PyMC+nutpie.

**Impact:** If sampling is slower than Abacus for large models, the performance benefit of Julia is negated.

**Mitigation:**
1. Benchmark early (M3): sample a 100-parameter model in both Abacus and Epsilon, compare ESS/sec.
2. Use `Turing.setadbackend(:reversediff)` for high-dimensional models (reverse-mode is O(1) in parameter count).
3. Consider `DynamicHMC.jl` as alternative sampler if `AdvancedHMC` is slow.
4. Explore `Pathfinder.jl` for fast initialization.

**Owner:** TBD  
**Status:** 🔴 Not started

---

#### R5: Julia Ecosystem Stability

**Risk:** The Turing.jl ecosystem is actively evolving. Breaking changes between versions of Turing, DynamicPPL, AdvancedHMC, etc. could require maintenance.

**Impact:** Dependency updates could break Epsilon between releases.

**Mitigation:**
1. Pin compat bounds tightly in `Project.toml`.
2. Run CI against Turing `main` branch weekly to catch breaking changes early.
3. Stay engaged with Turing.jl community (Discourse, GitHub issues).

**Owner:** TBD  
**Status:** 🟡 Ongoing

---

#### R6: Panel Data Hierarchical Models

**Risk:** Abacus's `PanelMMM` uses complex hierarchical priors with geo-level and brand-level offsets. Mapping PyMC's `dims` system to Turing's `filldist` + manual indexing may produce subtle bugs or performance issues in multi-dimensional plate structures.

**Impact:** Panel models are the primary use case. Bugs here affect all production models.

**Mitigation:**
1. Start with a simple 2-geo, 2-channel test case. Validate posterior against Abacus.
2. Gradually scale to real-world panel sizes (20+ geos, 10+ channels).
3. Consider using `TuringGLM.jl` as reference for hierarchical model patterns.

**Owner:** TBD  
**Status:** 🔴 Not started

---

### 🟢 Low Risk

#### R7: Plotting Parity

**Risk:** Makie.jl and Matplotlib have different APIs and default aesthetics. Plots may not look identical.

**Impact:** Visual differences only — no statistical impact. Since Epsilon does
not target Plotly Dash parity for v1, the practical risk is limited to
producing clear static outputs rather than replicating the Abacus app surface.

**Mitigation:** Define Epsilon theme early. Prioritize information content over
visual parity, and treat simple static or file-based report outputs as
sufficient for v1.

---

#### R8: Julia Learning Curve

**Risk:** Team familiarity with Julia may be limited compared to Python.

**Impact:** Slower initial velocity; more bugs in idiomatic Julia patterns.

**Mitigation:** Julia's syntax is close to Python. Invest 1-2 days upfront in Julia training. Use Julia linting and formatting tools.

---

## Open Questions

| # | Question | Status | Decision |
|---|----------|--------|----------|
| Q1 | Should we use `Plots.jl` (simpler) or `Makie.jl` (more powerful) for non-Dash plotting? | 🟡 Open | Leaning Makie for long-term, Plots.jl for prototyping |
| Q2 | Should we support both `ForwardDiff` and `ReverseDiff` as autodiff backends? | 🟡 Open | Default to ReverseDiff (better for >20 params); ForwardDiff as fallback |
| Q3 | Should `generated_quantities` be called inside sampling or post-hoc? | 🟡 Open | Depends on R2 investigation |
| Q4 | Should we use `JuMP.jl` or `Optim.jl` for budget optimization? | 🟡 Open | JuMP for constrained; Optim for unconstrained. May need both. |
| Q5 | Should we keep Abacus YAML config format exactly or redesign for Julia? | 🟡 Open | Keep compatible where possible; extend for Julia-specific features |
| Q6 | Should we support `NetCDF` output for ArviZ interop? | 🟡 Open | Nice-to-have for users migrating from Abacus |
| Q7 | How do we handle Julia's time-to-first-plot latency for CLI usage? | 🟡 Open | PackageCompiler.jl for production; accept latency in dev |
| Q8 | Should the CLI be a Julia script or compiled binary? | 🟡 Open | Script initially; compiled via PackageCompiler.jl for production |

---

## Architecture Decision Records (ADRs)

### ADR-001: Julia as Target Language

**Status:** ✅ Accepted  
**Date:** 2026-04-21  
**Context:** Considered Go, Rust, C++, Julia for porting Abacus.  
**Decision:** Julia with Turing.jl — only ecosystem that matches PyMC feature-for-feature with native compiled performance.  
**Consequences:** Team needs Julia fluency. Ecosystem is younger than Python but mature enough.

---

### ADR-002: Turing.jl as Probabilistic Programming Framework

**Status:** ✅ Accepted  
**Date:** 2026-04-21  
**Context:** Considered Gen.jl as alternative.  
**Decision:** Turing.jl — larger community, better documentation, more active development, NUTS/HMC built-in.  
**Consequences:** Tied to Turing's `@model` macro pattern. Must handle deterministics via `generated_quantities`.

---

### ADR-003: Bottom-Up Porting Strategy

**Status:** ✅ Accepted  
**Date:** 2026-04-21  
**Context:** Could port top-down (pipeline first) or bottom-up (primitives first).  
**Decision:** Bottom-up — transforms first, then priors, then model core, then pipeline.  
**Consequences:** Each layer is independently testable. Slower to get end-to-end demo but more reliable.

---

### ADR-004: Composition over Inheritance

**Status:** ✅ Accepted  
**Date:** 2026-04-21  
**Context:** Abacus uses deep Python class hierarchies (5 levels). Julia doesn't support multiple inheritance.  
**Decision:** Use abstract types (shallow hierarchy) + multiple dispatch + composition via struct fields.  
**Consequences:** More idiomatic Julia. May require refactoring the mental model from Abacus's OOP design.

---

### ADR-005: Project Name — Epsilon

**Status:** ✅ Accepted  
**Date:** 2026-04-21  
**Context:** Needed a brand name for the Julia port.  
**Decision:** Epsilon (ε) — the statistical error term, representing precision and the irreducible uncertainty that Bayesian inference quantifies.  
**Consequences:** Clean namespace, strong technical identity, memorable.

---

### ADR-006: GSD Workflow

**Status:** ✅ Accepted  
**Date:** 2026-04-21  
**Context:** Needed a project management approach.  
**Decision:** GSD (Getting Stuff Done) — milestone-driven, clear acceptance criteria, documentation-first.  
**Consequences:** Higher upfront planning investment. Better long-term velocity and quality.

---

### ADR-007: Abacus Parity Scope Excludes Dash

**Status:** ✅ Accepted  
**Date:** 2026-04-21  
**Context:** Abacus's library and statistical methodology are production-grade,
but its Plotly Dash component is still beta.  
**Decision:** Epsilon v1 targets parity for the validated MMM/statistical core
and may omit or simplify the Dash/UI layer.  
**Consequences:** Plotting remains in scope, but only as practical Julia-native
diagnostic and analyst outputs rather than an interactive dashboard clone.
