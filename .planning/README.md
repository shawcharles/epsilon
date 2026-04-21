# Epsilon MMM — Project Planning

## GSD Workflow

This project follows a **GSD (Getting Stuff Done)** workflow — structured, milestone-driven, with clear deliverables at each phase.

### Primary Control Docs

These files now act as the authoritative planning backbone:

| Document | Purpose |
|----------|---------|
| [PROJECT.md](PROJECT.md) | Product definition, active requirements, constraints, and key decisions |
| [REQUIREMENTS.md](REQUIREMENTS.md) | Checkable v1 requirements and phase traceability |
| [ROADMAP.md](ROADMAP.md) | Execution-ordered development phases and seeded plan breakdown |
| [STATE.md](STATE.md) | Current phase, blockers, and session continuity |
| [config.json](config.json) | GSD workflow configuration |

### Planning Documents

| Document | Purpose |
|----------|---------|
| [GSD Board](GSD-BOARD.md) | Master task board — epics, milestones, and task status |
| [Architecture](ARCHITECTURE.md) | System architecture and design decisions |
| [Component Mapping](COMPONENT-MAPPING.md) | PyMC/PyTensor → Turing.jl equivalents (the Rosetta Stone) |
| [Dependencies](DEPENDENCIES.md) | Julia package dependencies and version strategy |
| [Milestones](MILESTONES.md) | Phase definitions and acceptance criteria |
| [Risks & Decisions](RISKS-AND-DECISIONS.md) | Technical risks, open questions, and ADRs |
| [Technical Standards](../TECHNICAL-STANDARDS.md) | Repository engineering standards and quality baseline |

These reference documents inform the roadmap and should stay aligned with it,
but `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, and `STATE.md` are the files
that drive day-to-day execution.

### How We Work

1. **Plan** → Define the epic, break into tasks, estimate effort
2. **Build** → Implement in focused sprints, one module at a time
3. **Verify** → Test against Abacus outputs (numerical parity checks)
4. **Ship** → Tag a milestone release, document what changed

### Porting Strategy

We port **bottom-up** — starting with the mathematical primitives (transforms, distributions) and building up to the model specification layer, then the pipeline. Each layer is independently testable against Abacus reference outputs.

```
Phase 1: Foundation    → Project scaffold, CI, dependencies
Phase 2: Primitives    → Adstock, saturation, convolution, scaling
Phase 3: Priors        → Distribution system, prior specification
Phase 4: Model Core    → Model builder, Turing @model, config system
Phase 5: Features      → Seasonality, trend, events, HSGP, TVP, panels
Phase 6: Inference     → MCMC, VI, predictive sampling, diagnostics
Phase 7: Post-Model    → Contributions, decomposition, response curves
Phase 8: Optimization  → Budget optimizer, constraints
Phase 9: Pipeline      → YAML-driven end-to-end pipeline
Phase 10: Plotting     → Visualization layer
Phase 11: Validation   → Numerical parity with Abacus, benchmarks
```
