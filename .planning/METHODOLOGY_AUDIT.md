# Targeted Methodology Audit: Epsilon vs Abacus

**Date**: 2026-04-23  
**Scope**: Bounded v1 time-series path  
**Epsilon commit**: `44e6c47`  
**Abacus commit**: `b81f732`

---

## Findings

### **HIGH** — `epsilon/src/mmm/model.jl:130-131`, `abacus/abacus/mmm/models/panel_build.py:206-221` — Epsilon fits on raw unscaled data; Abacus scales channels and target before fitting

**What Abacus does**:  
Abacus divides channel data by `channel_scale` and target data by `target_scale` before the model ever sees them (`panel_build.py:206-221`). The scaling factors are computed by `compute_scales()` (`panel_data.py:582-594`) which defaults to `method="max"` over the date dimension for both channels and target (`panel_config.py:111-113`). The model observes `channel_data_scaled` and `target_data_scaled`, so all posterior parameters (`intercept`, `sigma`, `saturation_lam`, `beta`, etc.) are estimated in scaled space. Original-scale outputs require explicit reconstruction: `channel_contribution * target_scale` (`mmm_wrapper.py:479`) or `_original_scale` deterministic variables (`panel_build.py:135-170`).

**What Epsilon does**:  
Epsilon passes `model.data.target` and `model.data.channels` directly to the Turing model with no scaling (`model.jl:130-131`). The `_turing_runtime` function never invokes `MaxAbsScaleChannels` or `MaxAbsScaleTarget` (`model.jl:251-334`). These scalers exist in `transforms/scaling.jl` as exported public utilities but are never called by the pipeline or model-fitting path. All posterior parameters and contribution outputs are on the original data scale.

**Why this matters**:
1. **Saturation semantics change**: The logistic saturation function `1 / (1 + exp(-lam * x))` behaves fundamentally differently when `x` is max-scaled to ~[0, 1] vs. when `x` is in raw currency units (potentially thousands or millions). In Abacus, `lam` controls saturation in a normalized space where spend magnitudes are comparable across channels. In Epsilon, `lam` must absorb the raw magnitude of each channel, making priors less portable and cross-channel `lam` comparisons meaningless.
2. **Prior compatibility breaks**: The Abacus demo config's `Gamma(3, 1)` prior for `lam` is calibrated for scaled-channel inputs. The same prior on raw-channel inputs produces a dramatically different prior predictive distribution, altering the effective regularization.
3. **`sigma` interpretability**: In Abacus, `sigma` is residual noise on the scaled target (~0 to 1). In Epsilon, `sigma` is on the raw target scale. The same prior `HalfNormal(1)` is weakly informative in Abacus but informatively tight or loose in Epsilon depending on target magnitude.
4. **Cross-channel parameter comparability**: Abacus's scaling makes `beta_media` values comparable across channels because they all operate on similarly scaled inputs. Epsilon's `beta_media` values reflect both the channel's natural coefficient and the channel's spend magnitude, making them non-comparable without manual normalization.
5. **Fitted behavior differs**: Because the model operates in a different space, the posterior distribution over parameters will differ. Even with identical data and priors, the same MCMC sampler will converge to different parameter regions because the likelihood surface has a different geometry. This is not just a reporting difference—it changes what the model learns.

---

### **HIGH** — `epsilon/src/postmodel/contributions.jl`, `abacus/abacus/data/idata/mmm_wrapper.py:469-479` — Epsilon contributions are on original scale natively; Abacus requires explicit target_scale reconstruction

**What Abacus does**:  
Posterior `channel_contribution` is stored in scaled space. Original-scale contributions are obtained by multiplying by `target_scale` (`mmm_wrapper.py:476-479`):

```python
contributions["channels"] = channel_contrib * target_scale
```

Alternatively, pre-computed `_original_scale` deterministic variables are used when available (`panel_build.py:135-170`). The `constant_data` group is required to contain both `channel_scale` and `target_scale` (`schema.py:270-283`).

**What Epsilon does**:  
`_replayed_contribution_values` (`replay.jl:344-432`) replays the forward pass on the raw channel data and multiplies by `beta_media`, producing contributions already in original scale. No `channel_scale` or `target_scale` fields exist or are needed in Epsilon's output.

**Why this matters**:  
This is a direct consequence of Finding 1. The contributions may appear superficially similar (both claim "original scale"), but they arise from models fitted in different spaces. Epsilon's "original scale" is the native scale of the model; Abacus's "original scale" is a post-hoc reconstruction from a scaled model. If the models were truly equivalent (same fitted parameters on the same effective data), the outputs would match—but they are not equivalent because the data entering the model differs. This is not a reporting bug in either system; it is a structural difference in model semantics.

---

### **MEDIUM** — `epsilon/src/postmodel/response_curves.jl`, `abacus/abacus/pipeline/stages/curves.py:563-623` — Epsilon produces only forward-pass contribution curves; Abacus produces three distinct curve types

**What Abacus does**:  
Stage 60 generates three distinct curve artifacts (`curves.py:563-623`):
1. **Saturation-only curve**: Pure saturation transform applied to a grid of `x` values from 0 to `max_value` in scaled space, with `original_scale=True` multiplying y by `target_scale`. No adstock. Exposes the shape of the saturation function alone.
2. **Forward-pass contribution curve**: Full `channel_contribution_forward_pass` applied to the observed historical spend path scaled from 0% to 200% of observed, including adstock carryover. Reports total contribution across the horizon in original scale.
3. **Adstock curve**: Pure adstock carryover profile over time, showing the decay pattern.

**What Epsilon does**:  
`response_curve_results` (`response_curves.jl:12-63`) computes a single curve type: the full forward-pass contribution (adstock → saturation → beta) for the observed spend path scaled proportionally from the grid points, summed across the horizon. This is methodologically closest to Abacus's forward-pass contribution curve.

**Why this matters**:  
The saturation-only curve is a distinct analytical artifact that isolates the saturation shape from adstock dynamics. Analysts use it to understand diminishing returns independently of carryover. The adstock curve shows the decay profile. Epsilon's lack of these curve types means analysts cannot decompose the response into saturation-vs-adstock components. This is a real analytical gap, not just a missing plot. The optimization stage also depends on curve semantics (see next finding).

---

### **MEDIUM** — `epsilon/src/optimization/objective.jl:275-382`, `abacus/abacus/mmm/optimization/graph.py:89-103` — Epsilon optimization uses interpolated response-curve surfaces; Abacus replays the full model graph per allocation

**What Abacus does**:  
The `BudgetOptimizer` operates on the live PyMC model graph. `replace_channel_data_by_optimization_variable` (`graph.py:89-103`) replaces `channel_data` with an optimization variable, divides budgets by `channel_scales` to convert from original to scaled space, and evaluates the full forward pass (adstock + saturation + coefficients + all other components) for each candidate allocation. This means adstock carryover from the optimization horizon is properly computed within the graph.

**What Epsilon does**:  
`_build_budget_optimization_problem` (`objective.jl:275-382`) builds monotone cubic interpolation surfaces from `response_curve_results`, which replay the *historical* spend path at each spend level. The optimization then evaluates these interpolated surfaces (`_evaluate_channel_surface`) rather than replaying the model. The baseline and fixed-channel response come from `contribution_results` of the fitted model (`objective.jl:127-153`).

**Why this matters**:  
1. **Adstock carryover semantics**: Abacus's graph-based optimization propagates adstock carryover within the optimization horizon itself. Epsilon's surface-based approach carries over adstock from the *historical* spend path shape, which may not match the constant-spend allocation implied by the optimization budget distribution. This is a methodological approximation, not just an implementation shortcut.
2. **Scale conventions**: Abacus divides budgets by `channel_scales` before injecting them into the model graph (`graph.py:103`). Epsilon's surfaces are in original-scale spend and contribution, so no channel_scale conversion is needed—but this is because the underlying model is already in original scale (Finding 1).
3. **Optimization surface fidelity**: The monotone cubic interpolation adds an approximation layer. While this is reasonable for smooth response curves, it cannot capture non-monotonic or irregular response behavior that the full model graph would produce (e.g., from adstock interaction effects under changed allocation patterns).

---

### **MEDIUM** — `epsilon/examples/demo/epsilon/timeseries/config.yml`, `abacus/data/demo/timeseries/config.yml:76-81` — Epsilon demo omits holiday component; Abacus demo includes Prophet-style holiday smoothing

**What Abacus does**:  
The Abacus demo config includes a `holidays` section (`config.yml:76-81`):

```yaml
holidays:
  mode: prophet_component
  path: ../../holidays.csv
  countries: UK
```

This activates `EventAdditiveEffect` (`additive_effect.py:584-778`), which builds a Prophet-style smoothed holiday component with a windowed Gaussian basis, integrated as an additive effect in the model graph. The holiday contribution is estimated as a separate latent parameter, not just binary indicators.

**What Epsilon does**:  
The Epsilon demo config has no `holidays` key at all. Epsilon's event system (`events.jl:94-106`) supports only binary window indicators: a 1/0 column for each event window matching dates in `[start_date, end_date]`. There is no `prophet_component` mode or smoothed holiday basis.

**Why this matters**:  
1. **Statistical methodology**: Prophet-style holiday smoothing is a fundamentally different approach than binary event indicators. Smoothed components share information across nearby dates and produce more stable estimates. Binary indicators estimate independent coefficients for each window, which can be noisy and overfit with sparse events.
2. **Demo comparability**: The Abacus demo models holiday effects; the Epsilon demo does not. This means the intercept and other components absorb the holiday variance differently, making the two demos non-comparable in their fitted decomposition even if the data is identical.
3. **Not just a UX difference**: This is a genuine statistical-methodology gap. The Abacus `prophet_component` holiday mode is a model-fitting choice that affects the posterior, not a display-layer option.

---

### **MEDIUM** — `epsilon/examples/demo/epsilon/timeseries/config.yml:27-48`, `abacus/data/demo/timeseries/config.yml:29-43` — Epsilon hoists `beta_media` out of saturation; Abacus nests `saturation_beta` inside the saturation transform

**What Abacus does**:  
The Abacus logistic saturation priors include both `lam` and `beta` inside `saturation.priors` (`config.yml:29-43`):

```yaml
saturation:
  type: logistic
  priors:
    lam:
      distribution: Gamma
      alpha: 3
      beta: 1
    beta:
      distribution: HalfNormal
      sigma: 1
```

In Abacus, `saturation_beta` is applied within the saturation transform itself, on scaled channel data. The `channel_contribution` Deterministic is the output of the full forward pass (adstock → saturation with internal beta) on scaled data.

**What Epsilon does**:  
Epsilon logistic saturation priors include only `lam` in `saturation.priors` (`config.yml:27-33`). The `beta_media` is hoisted to top-level `priors` (`config.yml:44-47`):

```yaml
saturation:
  type: logistic
  priors:
    lam: ...
priors:
  beta_media:
    distribution: HalfNormal
    sigma: 1
```

In Epsilon, the model applies adstock → saturation (without internal beta) → multiply by `beta_media` (`model.jl:33-68`).

**Why this matters**:  
This is a direct consequence of the scaling difference. In Abacus's scaled space, the saturation function `1 / (1 + exp(-lam * x))` outputs values in ~[0, 1], so an internal `saturation_beta` scales the output. In Epsilon's raw space, the external `beta_media` coefficient is necessary because the saturation output is not naturally scaled. The mathematical identity `saturation(x) * beta = (saturation(x) * beta)` holds, so the parameterization is equivalent in principle—but the prior semantics differ because Abacus's `saturation_beta` is calibrated for ~[0,1] saturation output while Epsilon's `beta_media` must absorb the raw scale of the target. This means the same `HalfNormal(1)` prior has dramatically different effective regularization in the two systems.

---

### **LOW** — `epsilon/docs/src/release.md:37-44` — Release docs claim "Abacus-Comparable Rows" validation but do not disclose the scaling methodological gap

**What the docs say**:  
The release doc (`release.md:66-84`) states that `VAL-TS-00-MCMC` and `VAL-TS-04-MCMC` are "validated against compact committed Abacus-derived fixtures" and that "posterior parameter identity" and "posterior-predictive summary parity" are checked.

**What the code shows**:  
The fundamental scaling difference (Finding 1) means that Epsilon and Abacus cannot have "posterior parameter identity" for parameters like `intercept`, `sigma`, `lam`, and `beta_media` because these parameters exist in different spaces. If the validation fixtures are testing transform-layer parity on isolated functions (e.g., geometric adstock, logistic saturation with identical inputs), that is valid. But the release docs' language of "posterior parameter identity" and "posterior-predictive summary parity" could be read as implying end-to-end model parity, which does not hold.

**Why this matters**:  
The release docs should clarify that the Abacus-comparable validation rows test transform-layer and isolated-component parity, not end-to-end model-fitting parity on the same data. The current wording could lead analysts to believe that Epsilon reproduces Abacus results on the same dataset, which is not the case due to the scaling difference.

---

## Non-Issues

1. **Makie vs Dash**: Epsilon uses CairoMakie for static plots; Abacus uses Dash/Plotly for interactive dashboards. This is explicitly documented as out of scope in `release.md:61` ("Dash parity or interactive dashboard/reporting surfaces") and is an acceptable product-layer difference.

2. **Pipeline stage numbering**: Epsilon uses descriptive stage names ("metadata", "fit", "assessment", "decomposition", "curves", "optimisation"); Abacus uses numeric prefixes. This is a pipeline UX convention, not a methodology difference.

3. **Config schema structure**: Epsilon uses a top-level `seasonality` key with `type` and `n_order`; Abacus uses an `effects` list with `type: yearly_fourier`. Both produce the same Fourier feature matrix for order 2. This is a YAML schema difference, not a statistical difference.

4. **VI support**: Epsilon supports variational inference (`approximate_fit!`); Abacus does not expose VI in the pipeline. This is additive Epsilon scope, not a parity gap.

5. **Control standardization**: Both systems support optional control standardization. Epsilon applies it via `_control_design_matrix` (`model.jl:281-285`); Abacus does not standardize controls by default. The difference is minor because controls are not the primary focus of this audit and the behavior is configurable.

6. **Plot artifact formats**: Epsilon serializes plot artifacts as `.png` files via Makie; Abacus uses matplotlib `.png` files. Visual parity is not a methodology requirement.

---

## Residual Risks

1. **Adstock normalization flag**: Epsilon supports `adstock.normalize = false` (default) and `true` in the config (`model.jl:304`). Abacus's adstock normalization behavior should be verified—if Abacus normalizes adstock weights by default and Epsilon does not, this would compound the scaling difference for channels with different spend levels.

2. **Michaelis-Menten parameterization**: In Epsilon, `michaelis_menten` saturation does NOT use an external `beta_media` (`model.jl:296`: `uses_external_media_beta = saturation_type != :michaelis_menten`). In Abacus, the Michaelis-Menten path may handle the coefficient differently inside the saturation transform. This warrants a targeted code comparison if Michaelis-Menten is used in production.

3. **Control contribution scale**: Abacus controls are NOT scaled (`panel_build.py:519-529`: raw `control_data * gamma_control`). Epsilon's controls may be standardized. If a user switches between systems, control contribution magnitudes may differ even if the control coefficients are similar.

4. **Posterior predictive scale**: Abacus stores `y` in `posterior_predictive` in scaled space and provides `y_original_scale` or `to_original_scale()` conversion. Epsilon's posterior predictive is already in original scale. If any downstream tool assumes Abacus's convention (scaled y), it will misinterpret Epsilon output.

---

## Bottom Line

**Is Epsilon currently at approximate Abacus parity on the bounded time-series path?**

No. Epsilon is not at approximate Abacus parity on the bounded time-series path for a specific, structural reason:

**The scaling gap blocks the parity claim.** Abacus's entire modeling pipeline operates in a scaled latent space (channels divided by max-channel, target divided by max-target), with original-scale outputs reconstructed post-hoc. Epsilon operates directly on raw data in original units. This is not a surface-level difference—it changes the model's effective likelihood, the meaning of every posterior parameter, the calibration of every prior, the behavior of the saturation function, and the comparability of cross-channel coefficients.

**Specific methodological gaps that block the parity claim:**

1. **Channel and target scaling** (HIGH): The most fundamental gap. Without matching Abacus's scaling convention, no other parity claim holds for fitted behavior.
2. **Holiday/event methodology** (MEDIUM): The Abacus demo uses Prophet-style holiday smoothing; Epsilon uses binary indicators. This changes the model decomposition.
3. **Response curve coverage** (MEDIUM): Epsilon lacks saturation-only and adstock-only curve types, limiting analytical comparability.
4. **Optimization surface** (MEDIUM): Epsilon's interpolated-surface approach approximates what Abacus computes via full model-graph replay, with different adstock carryover semantics.

**What would be required for parity**: Epsilon would need to either (a) implement automatic channel/target scaling matching Abacus's default `method="max"` convention, with corresponding unscaling for all outputs, or (b) explicitly document that it operates on a different scale convention and provide guidance on how to achieve comparable results by manual preprocessing. Option (a) is the cleaner path to genuine parity.