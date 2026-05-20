# External Methodology Advice

This review prioritizes methodological coherence, identifiability, and analyst-facing decomposition over product/UI parity. The central repo-level finding is that the holiday semantics are currently not aligned across the two codebases:

- local **Abacus** `holidays.mode = "prophet_component"` is a **single Prophet-derived holiday component** that is fit in a separate Prophet step and then enters the MMM as one pooled regressor with one MMM coefficient;
- current **Epsilon** holiday code under the same label is materially different in spirit: it constructs **multiple holiday indicator columns** and estimates a `beta_holidays` vector inside the MMM.

That matters because holiday design is not just an implementation detail. It determines where variation is allowed to live, how priors must be calibrated, and what decomposition claims are honest.

## Recommended Design

### Trend

Trend should own **low-frequency, non-periodic baseline movement** in the target.

- Today: linear or changepoint trend is acceptable as a bounded approximation.
- Future: HSGP belongs here, as the smooth non-periodic baseline component.
- The trend block should be **mean-zero/centered around the model intercept** so the intercept owns average level and the trend owns deviations through time.

Trend should **not** own:

- repeating within-year structure;
- holiday pulses;
- analyst-declared one-off shocks;
- anything that is better described as a sparse calendar effect.

### Seasonality

Seasonality should own **smooth, repeating within-year structure**.

- Keep this as a **yearly Fourier basis** with a small order.
- This remains valuable even after HSGP is introduced.
- Its defining property should be **periodicity**, not generic smoothness.

Seasonality should **not** own:

- secular drift;
- structural breaks;
- holiday spikes;
- manual campaign/event windows.

### Holidays

Automatic holidays should own **sparse, calendar-driven, known-in-advance pulses**.

My recommended automatic holiday design for a coherent Julia-native MMM is:

- one **pooled holiday regressor** built from the holiday calendar;
- daily data: pooled binary pulse;
- weekly/aggregated data: **holiday-day share in the modeled period**;
- one MMM coefficient;
- one analyst-facing holiday component in decomposition.

This is much cleaner than Fourier-smoothing the holiday calendar, and much more stable than estimating one coefficient per holiday automatically.

If the project also wants an **Abacus compatibility mode**, keep that as a second, explicitly separate path using actual Prophet-component semantics. Do **not** treat that as the same methodology as the native pooled holiday regressor.

### Events

Events should own **manual, analyst-specified, named windows or dummies**:

- promotions;
- launches;
- outages;
- one-off shocks;
- manually specified holiday windows/dummies when the analyst wants named treatment.

Events should be allowed to coexist with automatic holidays. They should only be blocked when they duplicate the same underlying feature definition.

Events should **not** own:

- generic yearly seasonality;
- smooth trend;
- the entire automatic holiday system.

## Answers To The Key Questions

### 1. Structural Ownership

#### Trend

Trend should own:

- long-run baseline drift;
- secular growth/decline;
- smooth regime movement not pinned to known calendar dates.

Trend should **not** own:

- yearly repeating pattern;
- sparse holiday pulses;
- manually declared event windows;
- short-run spikes that are really event or holiday structure.

#### Seasonality

Seasonality should own:

- repeating annual pattern that recurs each year in roughly the same calendar position;
- smooth within-year cyclic structure.

Seasonality should **not** own:

- holiday spikes;
- structural breaks;
- one-off shocks;
- low-frequency baseline drift.

#### Holiday effects

Holiday effects should own:

- known calendar dates from a holiday catalog;
- sparse, non-media, calendar-driven deviations;
- one automatic pooled holiday component by default.

Holiday effects should **not** own:

- generic year-end seasonality;
- non-holiday promotions;
- analyst-specific event windows;
- smooth baseline trend.

#### Manual events

Manual events should own:

- analyst-declared dummies/windows;
- named shocks the analyst wants to inspect separately;
- manual holiday dummies if the analyst wants holiday-level treatment instead of pooled automatic treatment.

Manual events should **not** own:

- the automatic holiday calendar;
- generic seasonality;
- smooth trend.

### 2. HSGP Interaction

Once HSGP is introduced for trend, it should own **smooth, non-periodic residual baseline variation through time**.

Concretely:

- **HSGP trend owns**: multi-week/multi-month drift, soft structural movement, slow baseline curvature.
- **Yearly Fourier owns**: repeating within-year pattern.
- **Holiday effects own**: sparse calendar pulses or pooled holiday exposure.

Those boundaries are coherent only if the model design enforces them. The practical rules should be:

1. **Keep yearly Fourier even after HSGP exists.** HSGP is not a good replacement for periodic annual structure if you want stable decomposition and extrapolation.
2. **Use HSGP as a trend mode, not as a second seasonality block.** If a periodic GP is ever wanted, that is a seasonality mode, not trend.
3. **Center the HSGP block** so the intercept owns the average level.
4. **Use a smoothness prior that disallows holiday/event-scale wiggles.** HSGP should be too smooth to explain sparse spikes.
5. **Do not let HSGP replace the holiday block.** Holidays remain deterministic calendar structure, not latent smooth drift.
6. **Treat `linear`, `changepoint`, and future `hsgp` as alternative trend modes**, not stacked trend blocks in the same v1 path.

If those guardrails are not imposed, HSGP will compete with Fourier and holidays, especially on short samples.

### 3. Holiday Effect Design

#### Evaluation of `holidays.mode = "auto_fourier"`

Proposed idea:

1. pool holidays into one binary pulse series;
2. Fourier-transform that pooled pulse into a smooth holiday index;
3. feed that index into the MMM as one regressor.

#### Verdict

I do **not** recommend this as the default automatic holiday design.

#### Statistical coherence

It is only weakly coherent. The core problem is that it turns a **sparse pulse process** into a **smooth recurring calendar signal**.

That creates overlap with:

- yearly Fourier seasonality, because both now encode smooth calendar-position structure;
- future HSGP trend, because the smoothed index leaks away from the actual holiday dates;
- manual events, because specific holiday windows become harder to separate from the smoothed automatic block.

The automatic holiday block should stay sparse and calendar-specific. `auto_fourier` makes it behave like pseudo-seasonality.

#### Degrees of freedom

It does **not meaningfully save degrees of freedom** relative to a single pooled holiday regressor if the final MMM sees only one index and one coefficient.

In that setup, both approaches give the MMM:

- one regressor;
- one beta.

So the real difference is not Bayesian df saving. The difference is that `auto_fourier` pre-smooths the feature before the model ever sees it.

If instead the Fourier coefficients are learned inside the MMM, then it is no longer low-df and the overlap problem gets worse.

#### Underfit / over-smoothing risk

`auto_fourier` is likely to **underfit sharp holiday structure** and **over-smooth true pulses**.

Typical failure modes:

- the peak effect gets smeared into nearby non-holiday periods;
- different holidays with very different magnitudes are compressed into one smooth seasonal-looking curve;
- the model attributes some of that smooth curve to seasonality or trend anyway.

#### Comparison with alternatives

| Design | Assessment |
|---|---|
| **One dummy per holiday** | Too high-variance as an automatic default on weekly MMM; acceptable only as manual event treatment when the analyst explicitly wants it. |
| **One pooled binary holiday indicator** | Coherent and parsimonious, but for weekly/aggregated data I prefer period-level holiday-day share rather than a raw binary. |
| **Abacus Prophet-derived component** | Much closer to Abacus semantics, but it is a separate two-stage learned component, not a Julia-native exogenous calendar regressor. Good for compatibility, not my preferred long-term native design. |
| **`auto_fourier`** | Worse than pooled pulse/share for coherence; not parity with Abacus; likely to blur into seasonality. |

#### Bottom line

The best automatic native design is **not** `auto_fourier`. It is a **pooled holiday pulse/share regressor**.

### 4. Weekly Aggregation

For weekly MMM, the most defensible bounded default is:

**holiday-day share in the modeled period**

That is:

- count the number of **unique holiday days** that fall in the modeled week;
- divide by the number of days in that modeled period.

For a standard week this is usually:

`holiday_day_share = holiday_days_in_week / 7`

#### Why this is the best default

- It is **bounded** in `[0, 1]`.
- It preserves more information than `any_holiday_in_week`.
- It is more comparable across frequencies than raw holiday counts.
- It stays sparse and interpretable.
- It does not introduce smoothing overlap with Fourier or HSGP.

#### Why not the other options?

- **Binary any-holiday-in-week** throws away intensity.
- **Holiday-count-in-week** is less stable across different aggregation widths and can double-count overlapping labels.
- **Smoothed holiday index** reintroduces the identifiability problem.

If the analyst wants a wider holiday window than the literal holiday-day share captures, that should be modeled as a **manual event window**, not forced into the automatic holiday default.

### 5. Controls vs Separate Additive Block

The automatic holiday effect should be a **separate semantic model block**.

Internally, it is fine to reuse controls-style matrix plumbing. Publicly and conceptually, it should remain distinct.

#### Tradeoffs

| Aspect | Separate holiday block | Route through generic controls |
|---|---|---|
| **Priors** | Cleaner: holiday priors can be tuned as sparse calendar effects | Mixed with unrelated control priors |
| **Decomposition clarity** | Clear single `holiday` component | Holidays disappear into generic controls |
| **Implementation simplicity** | Slightly more surface area, but manageable | Slightly simpler internals |
| **Future HSGP interaction** | Clearer ownership boundaries vs trend/seasonality | More semantic ambiguity |

My recommendation is therefore:

- **public API:** dedicated `holidays` block;
- **implementation detail:** allowed to reuse controls matrix code.

### 6. Manual Holidays

It is **not** ideal to tell users to add individual holiday dummies as ordinary controls.

The better alternative is:

- tell users to add them as **manual events** via named dummies or windows.

Why events are better than controls:

- they are sparse shocks, not generic exogenous covariates;
- they deserve separate decomposition treatment;
- they may need different prior expectations;
- they fit naturally with analyst language.

So I would **not** add `holidays.mode = "manual"` if an `events` path already exists and can carry named dummies/windows. Instead:

- keep `holidays` for **automatic calendar-derived effects**;
- use `events` for **manual named holiday/event treatment**.

### 7. Analyst-Facing Decomposition

For a small and honest v1 API, the most defensible surface is:

- **one single pooled holiday component** for the automatic holiday block;
- **separate named components** for manual events.

I do **not** recommend showing both pooled and multiple named holiday components for the same automatic holiday block.

Why:

- if the model estimated one holiday coefficient, there is only one holiday contribution that is honestly identified at the MMM level;
- splitting that into multiple named holiday contributions would be pseudo-decomposition, not model decomposition.

The compromise I do recommend is:

- decomposition output: one `holiday` component;
- metadata output: a **holiday feature manifest** listing which source holidays fed that pooled component.

### 8. Parity vs Product Decision

If Epsilon adopts `auto_fourier`, it is **not honest** to call that “Abacus-comparable.”

It must be documented as an **Epsilon-native alternative**.

More strongly: the current Epsilon holiday implementation under `prophet_component` also should **not** be described as Abacus parity, because it is not using Prophet-derived component semantics.

To call the holiday path genuinely Abacus-comparable, Epsilon would need to copy the following semantics closely enough to be substantively the same:

1. filter the holiday catalog by country;
2. collapse the training target to the modeled date series in scaled space;
3. fit Prophet on that collapsed series with the holiday calendar;
4. extract the Prophet `holidays` component;
5. feed that single component into the MMM as one holiday regressor with one MMM coefficient;
6. decompose it as one pooled holiday component.

Without that, parity language should be narrowed.

## Recommended Bounded v1 Contract

My preferred bounded v1 contract is a **coherent Epsilon-native automatic holiday block**, not `auto_fourier`.

### Preferred native v1 contract

```yaml
seasonality:
  type: fourier
  n_order: 2

trend:
  type: changepoint   # or linear; future hsgp should be an alternative trend mode
  n_changepoints: 8

holidays:
  mode: pooled_pulse
  path: ../../reference/abacus/holidays.csv
  countries: ["UK"]
  priors:
    beta:
      distribution: Normal
      mu: 0
      sigma: 1

events:
  windows: []
```

### Data flow

1. Load the holiday CSV.
2. Filter to the requested countries.
3. Project holiday dates onto modeled periods.
4. Build **one period-level holiday regressor**:
   - daily: `0/1` pooled holiday pulse;
   - weekly/aggregated: `holiday_day_share`.
5. Feed that regressor into a **dedicated holiday block** with one coefficient.
6. Replay and decomposition expose **one `holiday` component**.

### Controls vs separate block

- **Publicly:** separate `holidays` block.
- **Internally:** allowed to reuse controls-style feature-matrix code.

### What appears in decomposition

- `holiday` for the automatic block;
- `event:<name>` for manual events;
- no fake holiday-by-holiday automatic decomposition.

### If the repo must also keep an Abacus compatibility mode

The smallest honest split is:

- `holidays.mode = "pooled_pulse"` — recommended Epsilon-native automatic holiday mode;
- `holidays.mode = "prophet_component"` — compatibility mode only, explicitly documented as an Abacus-style holiday path.

If that split is adopted, **do not add `auto_fourier`**. It is not the right native mode.

### Future HSGP support

When HSGP is added, it should enter as:

```yaml
trend:
  type: hsgp
```

with the understanding that:

- it replaces `linear`/`changepoint` as the trend mode for that row;
- it does not replace yearly Fourier;
- it does not replace holidays;
- it remains centered/smooth enough not to absorb event-scale variation.

## Parity Judgment

My recommendation is:

**an Epsilon-native alternative that must not be described as parity**

Specifically:

- the coherent automatic holiday design I recommend is **pooled pulse/share**, not Prophet and not `auto_fourier`;
- therefore it is not true Abacus parity;
- if the project still wants parity claims on a bounded holiday row, it must keep a separate compatibility mode that actually matches Prophet-component semantics.

## Risks

If the project chooses the wrong design, the main risks are:

1. **HSGP / Fourier / holiday overlap**
   - components compete for the same variation;
   - priors become hard to interpret;
   - decomposition becomes unstable.

2. **Holiday smoothing masquerades as seasonality**
   - `auto_fourier` makes sparse holiday structure look like smooth calendar seasonality;
   - the resulting holiday line is no longer clearly a holiday line.

3. **Automatic per-holiday dummies become weakly identified**
   - especially on weekly data with only a few years of history.

4. **Manual holiday dummies routed through controls muddy interpretation**
   - controls stop meaning controls;
   - holiday/event decomposition is lost.

5. **Blocking holidays and events from coexisting forces bad analyst behavior**
   - users must choose the wrong block for some effects;
   - the model surface becomes less coherent than necessary.

6. **Parity claims become misleading**
   - especially if non-Prophet holiday handling is still labeled `prophet_component` or described as Abacus-comparable.

## Concrete Next Steps

1. **Correct the holiday terminology immediately.**
   - Current Epsilon `prophet_component` naming is not semantically honest relative to Abacus.
   - Either implement actual Prophet-component semantics or rename/narrow the claim.

2. **Do not proceed with `auto_fourier`.**
   - Reject it as the planned native automatic holiday mode.

3. **Choose the public holiday contract explicitly.**
   - If coherence is the priority: ship `pooled_pulse` (or equivalent naming) as the native mode.
   - If parity must be retained: keep a separate `prophet_component` compatibility mode.

4. **Stop treating `holidays` and `events` as methodologically mutually exclusive.**
   - Allow coexistence.
   - Validate duplicate features rather than forbidding the entire combination.

5. **Document manual holiday dummies under `events`, not `controls`.**
   - This is the right semantic home for named holiday windows/dummies.

6. **Reserve future HSGP as a trend mode with guardrails.**
   - centered;
   - smooth enough not to absorb holiday/event pulses;
   - not a replacement for yearly Fourier.

7. **Freeze the decomposition contract now.**
   - automatic holidays: one pooled `holiday` component;
   - manual events: named `event:<name>` components;
   - optional holiday manifest metadata, not pseudo-decomposition.

8. **Add validation/planning language that separates parity from native design.**
   - “Abacus-comparable” should mean actual Prophet-component semantics.
   - The pooled native holiday block should be documented as Epsilon-native.