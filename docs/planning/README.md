# Epsilon MMM — Project Planning

## GSD Workflow

This project follows a **GSD (Getting Stuff Done)** workflow — structured, milestone-driven, with clear deliverables at each phase.

### Planning Documents

| Document | Purpose |
|----------|---------|
| [GSD Board](GSD-BOARD.md) | Master task board — epics, milestones, and task status |
| [Architecture](ARCHITECTURE.md) | System architecture and design decisions |
| [Component Mapping](COMPONENT-MAPPING.md) | PyMC/PyTensor → Turing.jl equivalents (the Rosetta Stone) |
| [Dependencies](DEPENDENCIES.md) | Julia package dependencies and version strategy |
| [Milestones](MILESTONES.md) | Phase definitions and acceptance criteria |
| [Risks & Decisions](RISKS-AND-DECISIONS.md) | Technical risks, open questions, and ADRs |

### How We Work

1. **Plan** → Define the epic, break into tasks, estimate effort
2. **Build** → Implement in focused sprints, one module at a time
3. **Verify** → Test against Abacus outputs (numerical parity checks)
4. **Ship** → Tag a milestone release, document what changed

### Porting Strategy

We port **bottom-up** — starting with the mathematical primitives (transforms, distributions) and building up to the model specification layer, then the pipeline. Each layer is independently testable against Abacus reference outputs.

```
Phase 0: Foundation    → Project scaffold, CI, dependencies
Phase 1: Primitives    → Adstock, saturation, convolution, scaling
Phase 2: Priors        → Distribution system, prior specification
Phase 3: Model Core    → Model builder, Turing @model, config system
Phase 4: Features      → Seasonality, trend, events, HSGP, TVP, panels
Phase 5: Inference     → MCMC, VI, predictive sampling, diagnostics
Phase 6: Post-Model    → Contributions, decomposition, response curves
Phase 7: Optimization  → Budget optimizer, constraints
Phase 8: Pipeline      → YAML-driven end-to-end pipeline
Phase 9: Plotting      → Visualization layer
Phase 10: Validation   → Numerical parity with Abacus, benchmarks
```
