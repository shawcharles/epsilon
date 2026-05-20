# External Methodology Review

You are an external expert reviewer advising on the statistical design of the
`Epsilon.jl` marketing mix model relative to the local `Abacus` codebase.

This is **not** a code-style review and **not** a generic planning review.
Your job is to recommend the most coherent additive-effect design for:

- trend
- seasonality
- holiday effects
- event effects
- future HSGP support

The main concern is methodological coherence and analyst-facing decomposition,
not UI or product parity.

## Repository Context

- Epsilon repo: `/home/user/Documents/GITHUB/shawcharles/epsilon`
- Abacus repo: `/home/user/Documents/GITHUB/tandpds/abacus`
- Project: Julia-native Bayesian MMM framework
- Original intent: approximate/parity port of the validated Abacus statistical
  core
- Explicitly out of scope: Plotly Dash parity

## Current Situation

Epsilon recently reopened its roadmap because a methodology audit found that
the bounded time-series path was not yet at honest Abacus parity.

The repo has already landed:

- explicit channel/target scaling on the bounded comparable row
- original-scale reconstruction for public outputs
- Stage 60 response/saturation/adstock curve families

However, the holiday-component design is unsettled.

### Important Current Decision Pressure

There is a product/model-design fork:

1. **Abacus-like path**
   - keep holiday handling close to Abacus semantics
   - Abacus currently has `holidays.mode = "prophet_component"`
   - that path uses Python Prophet, not just Fourier terms

2. **Epsilon-native path**
   - implement a Julia-native pooled holiday effect
   - proposed new mode:
     - `holidays.mode = "auto_fourier"`
   - idea:
     1. load holiday calendar CSV
     2. collapse holidays into one pooled binary pulse series over the modeled
        periods
     3. pass that pulse series through a bounded Fourier basis
     4. produce one continuous holiday index
     5. use that index as a low-degree-of-freedom exogenous regressor
   - manual individual holiday dummies would **not** be a holidays mode; users
     would declare those manually as ordinary controls

The team wants expert advice on whether this proposed split is statistically
coherent, especially once HSGP trend is introduced.

## Key Design Question

What is the best coherent additive decomposition for Abacus-style MMM work on
the bounded time-series path when the model may eventually include:

- smooth trend (today: linear/changepoint; later: HSGP)
- smooth repeating seasonality (Fourier)
- sparse calendar-driven holiday structure
- optional manual event windows / dummies

The risk is that an incoherent design creates overlap or competition between:

- HSGP trend
- Fourier seasonality
- holiday effects
- manual events

which would make priors harder to calibrate, decomposition less interpretable,
and parity claims less honest.

## Files To Read First

### Epsilon

1. `TECHNICAL-STANDARDS.md`
2. `AGENTS.md`
3. `.planning/PROJECT.md`
4. `.planning/ROADMAP.md`
5. `.planning/STATE.md`
6. `.planning/phases/12-parity-remediation/PLAN.md`
7. `README.md`
8. `docs/src/release.md`

Then inspect implementation context as needed, especially:

- `src/mmm/model.jl`
- `src/mmm/seasonality.jl`
- `src/mmm/trend.jl`
- `src/mmm/events.jl`
- `src/mmm/holidays.jl`
- `src/postmodel/replay.jl`
- `src/postmodel/contributions.jl`
- `src/postmodel/decomposition.jl`
- `src/postmodel/response_curves.jl`
- `examples/demo/epsilon/timeseries/config.yml`

### Abacus

Inspect these carefully:

- `abacus/mmm/additive_effect.py`
- `abacus/mmm/builders/holidays.py`
- `abacus/data/demo/timeseries/config.yml`
- any HSGP-related code you consider relevant

## What You Are Being Asked To Advise On

Please answer these questions directly and concretely.

### 1. Structural Ownership

For a coherent MMM design, what should each of these own?

- trend
- seasonality
- holiday effects
- manual events

Be explicit about what each component should **not** own.

### 2. HSGP Interaction

Once HSGP is introduced for trend:

- what part of variation should HSGP own?
- what part should remain with yearly Fourier seasonality?
- what part should remain with holiday effects?

We need clear boundaries so these components do not fight each other.

### 3. Holiday Effect Design

Evaluate the proposed `holidays.mode = "auto_fourier"` idea:

- pooled binary holiday pulse series over model periods
- low-order Fourier transform of that pooled holiday pulse
- one continuous holiday index fed as an exogenous regressor

Assess:

- whether this is statistically coherent
- whether it meaningfully saves degrees of freedom
- whether it is likely to underfit or over-smooth holiday structure
- whether it is preferable to:
  - one dummy per holiday
  - one pooled binary holiday indicator
  - Abacus’ current Prophet-derived component

### 4. Weekly Aggregation

The model is often run on weekly data.

For weekly MMM aggregation, what is the most defensible holiday handling?

Examples:

- binary any-holiday-in-week
- holiday-count-in-week
- weighted pulse by number of holiday days in the week
- smoothed holiday index

Please recommend one bounded default and explain why.

### 5. Controls vs Separate Additive Block

Should the automatic holiday effect be:

- a special dedicated model block
- or just a structured exogenous regressor routed through the controls path

Explain the tradeoffs for:

- priors
- decomposition clarity
- implementation simplicity
- future HSGP interaction

### 6. Manual Holidays

If users want individual holiday dummies, is it correct to tell them to add
those manually as ordinary controls instead of supporting a dedicated
`holidays.mode = "manual"`?

If not, explain the better alternative.

### 7. Analyst-Facing Decomposition

For analyst interpretation, what decomposition surface is most defensible?

Should outputs show:

- a single pooled holiday component
- multiple named holiday components
- both

Assume the goal is a small, honest, stable v1 API.

### 8. Parity vs Product Decision

Given that Abacus currently uses Prophet-derived holiday handling, answer this
explicitly:

- if Epsilon adopts `auto_fourier`, is that still honest to call
  “Abacus-comparable”?
- or must the docs/release language clearly treat it as an Epsilon-native
  alternative rather than parity?

## Review Priorities

Prioritize your advice in this order:

1. methodological coherence
2. identifiability / separation of effects
3. analyst interpretability
4. bounded implementation feasibility for Julia
5. parity honesty vs Abacus

## Output Requirements

Write your answer as Markdown.

Start with:

`# External Methodology Advice`

Then use these sections in order:

## Recommended Design

State the best design you recommend for:

- trend
- seasonality
- holidays
- events

## Answers To The Key Questions

Answer questions 1-8 directly.

## Recommended Bounded v1 Contract

Propose the smallest coherent public contract for Epsilon v1.
If you recommend `holidays.mode = "auto_fourier"`, specify:

- config shape
- data flow
- whether it goes through controls or a separate block
- what appears in decomposition

## Parity Judgment

State clearly whether your recommendation is:

- true Abacus parity
- approximate parity
- or an Epsilon-native alternative that must not be described as parity

## Risks

List the main modeling risks if the project chooses the wrong design.

## Concrete Next Steps

List the smallest concrete implementation/planning changes the repo should make
next.

## Review Discipline

- Do not give generic forecasting advice.
- Stay focused on MMM additive-effect design.
- Be explicit about tradeoffs.
- If you recommend abandoning Abacus parity for holidays, say so plainly.
- If you recommend keeping parity, explain what exact semantics must be copied.

## Suggested Output File

The result should be suitable to save under:

`/home/user/Documents/GITHUB/shawcharles/epsilon/.planning/reviews/`

Suggested filename:

`external-methodology-advice_trend-seasonality-holidays-hsgp.md`
