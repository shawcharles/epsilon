# Comparison With Other Open-Source MMM Tools

This page compares Epsilon.jl with several widely visible open-source
marketing mix modelling tools. It is intended to help analysts choose an
evaluation path, not to rank packages.

The comparison is based on public repositories and official documentation
accessed on **22 July 2026**. Open-source projects move quickly, so verify
current release notes before making production or procurement decisions.

Tools compared:

- [Epsilon.jl](https://github.com/shawcharles/epsilon)
- [PyMC-Marketing](https://github.com/pymc-labs/pymc-marketing)
- [Google Meridian](https://github.com/google/meridian)
- [Meta Robyn](https://github.com/facebookexperimental/Robyn)
- [Mamimo](https://github.com/RobKuebler/mamimo)
- [Paramark MMM](https://github.com/paramark-inc/mmm)

## Summary

The current open-source MMM landscape can be read as four broad families.

**Full Bayesian Python frameworks.** PyMC-Marketing and Meridian are the most
substantial Bayesian options in this group. PyMC-Marketing emphasises
modelling flexibility in the PyMC ecosystem. Meridian emphasises geo-level,
hierarchical MMM with Google-maintained documentation and GPU-oriented
runtime guidance.

**Automated frequentist or machine-learning workflows.** Robyn is a mature,
widely used R package built around ridge regression and multi-objective
hyperparameter optimisation. It is not a Bayesian posterior-inference tool,
but it gives marketing teams a fast and heavily automated MMM workflow.

**Lightweight composable libraries.** Mamimo offers scikit-learn-compatible
carryover and saturation components. Paramark MMM wraps a LightweightMMM-style
Bayesian workflow behind CSV/YAML inputs and timestamped output folders.
These are smaller projects with narrower public surfaces.

**Julia-native MMM.** Epsilon.jl is the Julia entrant in this comparison. Its
main distinction is a single-language Julia workflow: YAML configuration,
Turing/NUTS MCMC, typed post-model result surfaces, structured local output
folders, and explicit support boundaries.

Epsilon's strongest fit is a technical user who wants an inspectable,
config-driven Bayesian MMM library in Julia. Its main caveat is maturity:
Epsilon is pre-stable software, not yet registered in Julia's General registry,
and currently suited to bounded local and demo-scale workflows rather than
large institutional deployment.

## High-Level Comparison

| Tool | Language | Modelling engine | Workflow | Bayesian? | Geo/panel support | Calibration/lift tests | Optimisation | Best fit |
|---|---|---|---|---|---|---|---|---|
| Epsilon.jl | Julia | Turing/NUTS | YAML runner and Julia API | Yes | Bounded panel support | Time-series calibration path | Historical-share optimisation | Julia users wanting a transparent local MMM library |
| PyMC-Marketing | Python | PyMC | Code-first Python API and notebooks | Yes | Documented multidimensional/hierarchical MMM | Documented lift-test calibration | Documented budget optimisation | Python users wanting flexible Bayesian model construction |
| Meridian | Python | TensorFlow Probability NUTS | Code-first API and Colab guides | Yes | First-class geo-level hierarchical MMM | Experiment calibration | Budget allocation and scenario planning | Teams with geo data and GPU-capable infrastructure |
| Robyn | R, with Python beta | Ridge regression plus Nevergrad search | Semi-automated scripts and reports | No | Mainly time-series-oriented in public docs | Documented calibration support | Budget allocation | R teams wanting fast automated MMM without MCMC |
| Mamimo | Python | scikit-learn pipelines | Code-first transformers | No | Not evident from public docs | Not evident from public docs | Not evident from public docs | Simple sklearn-native MMM baselines |
| Paramark MMM | Python | LightweightMMM-style Bayesian engine | CSV/YAML runner | Yes | Unclear from public docs | Unclear from public docs | Unclear from public docs | Users wanting a small config-file wrapper around LightweightMMM-style modelling |

## Tool Notes

### Epsilon.jl

Epsilon.jl is a Julia-native Bayesian MMM library. The maintained workflow is
config driven: users provide a `config.yml`, `dataset.csv`, and `holidays.csv`,
then run the local pipeline through `runme.jl` or call `run_pipeline` from
Julia. Results are written to structured stage directories with a manifest,
diagnostics, decomposition, response curves, plots where available, validation
where supported, and optional optimisation artifacts.

The modelling path uses Turing/NUTS. Epsilon documents media adstock and
saturation functions, scaling and prior interpretation, contribution and
response-curve calculations, and the maintained time-series regression form.
The current public surface includes time-series MMM, bounded panel MMM,
time-series blocked holdout validation, time-series calibration terms, and
historical-share budget optimisation.

The trade-off is maturity. Epsilon is pre-release software. It is not yet
registered in Julia's General registry, and several surfaces are explicitly out
of scope, including variational inference, dashboard workflows, panel
calibration, panel holdout validation, and free channel-by-panel optimisation.
That explicit boundedness is useful: it makes the library easier to evaluate
honestly, but it also means Epsilon should not be treated as a mature platform
replacement.

### PyMC-Marketing

PyMC-Marketing is a Python Bayesian marketing package from PyMC Labs. Its MMM
surface is code-first and highly extensible: users can work with custom priors,
custom transformations, alternative NUTS backends, lift-test calibration,
time-varying components, and budget optimisation through the PyMC ecosystem.

Its strength is flexibility. A team already comfortable with Python and PyMC
gets a broad modelling toolbox with active maintenance and extensive notebook
documentation. The corresponding cost is dependency weight and API movement:
it remains a 0.x package, and a serious run still requires Bayesian workflow
discipline rather than blind execution.

### Google Meridian

Meridian is Google's open-source Bayesian MMM framework and the successor path
for users of LightweightMMM. It is designed for geo-level hierarchical MMM, with
documented support for experiment calibration, reach and frequency, budget
allocation, scenario planning, and structured pre-model/post-model workflows.

Meridian is the most institutionally backed tool in this comparison. It is a
strong candidate when the data are geo-level, the model needs to scale, and the
team can work comfortably in Python with TensorFlow Probability. The main
trade-off is runtime and infrastructure. Its documentation is explicit that
NUTS is compute intensive, and GPU-capable execution is part of the normal
usage story.

### Robyn

Robyn is Meta's R-based MMM package. It is not Bayesian. The core approach is
ridge regression with Nevergrad-driven multi-objective hyperparameter search,
time-series decomposition, and automated model selection/reporting. This makes
Robyn attractive for marketing teams that want quick iteration and a highly
automated workflow.

The limitation is inferential. Robyn produces point-estimate models selected by
optimisation; it does not give posterior uncertainty over model parameters,
contributions, or ROI. That is not a flaw if the team wants a fast predictive
MMM workflow, but it is a different statistical object from a Bayesian MMM.
The Python implementation is described publicly as a beta, so R remains the
more established path.

### Mamimo

Mamimo is a small Python library built around scikit-learn-compatible
transformers for media carryover, saturation, and time features. Its design is
simple and useful for teaching, experimentation, or baseline modelling inside
existing sklearn pipelines.

Its public scope is narrow. Public documentation does not establish support for
Bayesian inference, calibration, budget optimisation, or panel MMM. It is best
read as a lightweight composable modelling library rather than a full MMM
workflow system.

### Paramark MMM

Paramark MMM provides a config-driven CSV/YAML workflow around a
LightweightMMM-style Bayesian engine. It writes timestamped results folders and
offers a small, approachable workflow for users who want to run MMM from files
rather than notebooks.

The uncertainty is scope and maintenance. Public documentation does not clearly
establish panel support, calibration, or optimisation surfaces. Because the
underlying modelling lineage is LightweightMMM-style, users should also account
for the broader ecosystem shift towards Meridian.

## How Epsilon Fits

Epsilon is not trying to be a dashboard product, a hosted MMM platform, or a
general Python/R ecosystem competitor. Its niche is narrower:

- Julia-native statistical modelling with Turing/NUTS.
- A reproducible local config-to-results workflow.
- Typed Julia APIs for users who want to inspect or extend the modelling
  surface.
- Explicit support boundaries rather than implied broad coverage.

This makes Epsilon most appealing when the user values transparent local
statistical software and is comfortable with Julia. It is less appealing when
the deciding factor is community size, package-registry maturity, GPU-scale geo
modelling, or ready-made organisational support.

## Recommendation Guide

Use **Epsilon.jl** if you want an inspectable Julia-native Bayesian MMM library
with a local YAML runner and structured result artifacts, and you accept
pre-stable software.

Use **PyMC-Marketing** if you are Python-native and want the broadest flexible
Bayesian MMM modelling surface.

Use **Meridian** if you have geo-level data, GPU-capable infrastructure, and
want a heavily documented hierarchical Bayesian MMM framework.

Use **Robyn** if you want fast R-based MMM automation and do not require
posterior inference.

Use **Mamimo** if you need a small sklearn-compatible baseline or teaching
tool.

Use **Paramark MMM** if you specifically want a CSV/YAML wrapper around a
LightweightMMM-style Bayesian workflow and can accept a smaller public surface.

## Sources

All external sources were accessed on **22 July 2026**.

- Epsilon.jl repository and documentation:
  <https://github.com/shawcharles/epsilon>,
  <https://epsilon.charlesshaw.net>
- PyMC-Marketing repository and documentation:
  <https://github.com/pymc-labs/pymc-marketing>,
  <https://www.pymc-marketing.io/>
- Google Meridian repository and documentation:
  <https://github.com/google/meridian>,
  <https://developers.google.com/meridian>
- Meta Robyn repository and documentation:
  <https://github.com/facebookexperimental/Robyn>,
  <https://facebookexperimental.github.io/Robyn/>
- Mamimo repository:
  <https://github.com/RobKuebler/mamimo>
- Paramark MMM repository:
  <https://github.com/paramark-inc/mmm>
