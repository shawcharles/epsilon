# Phase 38: Permanent VI Surface Retirement

## Status

Landed. The detailed implementation plan was approved on 2026-07-12 after an
independent architectural review resolved config-bypass, deserialisation,
backend-allowlist, and plotting-coverage risks. Builder implementation removed
the public/runtime VI surface, hardened MCMC-only config and artifact backend
contracts, and retained MCMC coverage at former VI consumer boundaries.
Independent implementation review approved the landed contract. The
phase-closing gate passed with `9925 / 9925` tests in `23m33.1s` plus a
successful docs build.

## Objective

Retire Epsilon's existing variational-inference implementation and public API
permanently. Epsilon is a pre-release Julia MMM library whose sole supported
inference method is MCMC/Turing. This phase removes a real implementation
surface rather than carrying a second approximate-inference contract that the
maintainer has decided Epsilon will never own.

## Decision And Compatibility Contract

- Remove public `VariationalConfig` and `approximate_fit!` without a
  deprecation wrapper or replacement API. The package remains pre-release
  (`0.1.0-dev`), so a clean breaking removal is more honest than a compatibility
  bridge for a permanently unsupported feature.
- `fit!` with `SamplerConfig` and Turing/MCMC is Epsilon's only fitting path.
  No alternate inference backend is supported, planned, or retained as a
  scaffold.
- Public dict/YAML and pipeline configuration must reject `vi`, `variational`,
  and `approximate_fit` input keys, and reject non-MCMC `fit.backend` values
  through a clear MCMC-only validation error. Those names are reserved rejected
  inputs, not a viable compatibility configuration. Apply the same validation
  after merged defaults/overrides in both `model_config_from_dict` and the
  independently callable `sampler_config_from_dict`; an uncalibrated or
  standalone sampler map must not bypass it.
- Grouped or model artefacts marked `backend = :variational` are unsupported.
  Reject them at supported grouped-artifact entry/loading boundaries with a
  clear `ArgumentError`; do not let old VI draws feed post-model, optimisation,
  or reporting APIs through backend-agnostic validation.
- Runtime fit-state backends are allowlisted as `nothing` before fitting and
  `:turing` after an attempted or successful fit. Public result constructors
  and result loaders accept only `:turing`, existing deterministic `:fixture`
  test artefacts, or `nothing` for an unfitted/no-chain container; reject
  `:variational` and every other backend symbol. Model envelope metadata and a
  restored inner fit state must be coherent before a model is returned.
- Previously serialised model payloads containing the removed Julia
  `VariationalConfig` type are intentionally incompatible. Do not preserve a
  private legacy type or serialisation shim solely to read them. Metadata-only
  legacy payloads that deserialize can receive a controlled `ArgumentError`;
  payloads embedding the removed Julia type can fail during `deserialize`
  before Epsilon receives control. Record both pre-release outcomes in the
  changelog.
- Do not remove `AdvancedVI` from `Manifest.toml` or attempt to remove it by
  changing Turing. It is a transitive dependency of the pinned Turing release,
  not an Epsilon direct dependency.

## In Scope

- Remove the VI config type, constructor, equality method, validation helper,
  exported names, entry-point docstring, include, and implementation file.
- Collapse shared inference helpers to MCMC/Turing-only behavior and remove
  VI-specific grouped-prior sizing branches and diagnostic wording.
- Add fail-closed rejection for grouped `:variational` artefacts and retained
  VI-shaped public config input.
- Remove tests that execute VI and retain or strengthen MCMC-only coverage at
  the same consumer boundaries.
- Make README, docs, changelog, API inventory, planning state, and ledger state
  that VI is permanently retired rather than deferred or scaffolded.

## Explicit Exclusions

- No new inference method, approximation family, deprecation wrapper, or
  migration utility.
- No change to MCMC likelihood, priors, HSGP, calibration mathematics, panels,
  pipeline stages, optimisation semantics, dashboards, or AI advisor scope.
- No upgrade, downgrade, or removal of Turing or transitive dependencies.
- No backwards compatibility promise for existing VI model payloads.
- No rewrite of closed historical phase records; historical mentions remain
  factual and are marked superseded only where current-facing planning needs
  clarification.

## Architecture

1. **Remove the production VI leaf.** Delete `src/inference/vi.jl`; remove its
   inclusion, exported symbols, and public API docstring from `src/Epsilon.jl`.
   Delete `VariationalConfig` and `_validate_variational_config` from
   `src/model/types.jl`. No symbol with either public name remains defined.
2. **Tighten shared inference contracts.** Replace the `(:turing,
   :variational)` posterior-fit allowance with a Turing-only requirement.
   Simplify grouped prior draw/chain/core selection so it no longer probes a
   `variational_config` field. Update user-facing generic wording to describe
   MCMC/Turing artefacts only.
3. **Fail closed on residual artefacts and configuration.** Introduce one
   private backend-policy helper with context-specific allowlists: fit states
   admit only `nothing` or `:turing`; result constructors/loaders admit
   `nothing` only for an unfitted/no-chain container, plus `:turing` and the
   existing deterministic `:fixture` test artefacts. Use it in both public
   result constructors, `_validate_artifact_metadata`, and `_restore_fit_state`.
   Verify outer model-envelope metadata and inner fit-state backend coherence
   before returning a loaded model. This rejects `:variational` and arbitrary
   future symbols without breaking established fixture tests. At model-config
   and pipeline boundaries, retain the three reserved VI-shaped keys as
   explicitly rejected input, including after merged defaults/overrides, in
   uncalibrated configs, and through standalone `sampler_config_from_dict`.
   Preserve generic MCMC-only backend rejection; no parser should silently
   retain a VI-shaped input in `extras`.
4. **Remove VI consumer evidence, not MCMC coverage.** Delete the dedicated VI
   suite and remove VI-specific blocks from inference, post-model,
   optimisation, plotting, validation, and HSGP rejection tests. Keep the
   corresponding MCMC tests. Specifically replace the sole direct
   `posterior_density_plot` VI test with an MCMC grouped-results test. Replace
   old API-guard expectations about scaffolded exports with assertions that
   neither public symbol exists and current-facing documentation describes
   permanent retirement.
5. **Update support truth.** Replace current-facing language such as
   "out-of-scope for v1" and "scaffolded pre-v1 review export" with permanent
   non-support wording. Preserve changelog/history facts that VI once existed,
   then add the Phase 38 breaking-removal entry. Mark the VI ledger row
   `deferred`, not `missing` or `scaffolded`.

## Expected Files

### Runtime

- `src/Epsilon.jl`
- `src/inference/vi.jl` (delete)
- `src/inference/mcmc.jl`
- `src/inference/results.jl`
- `src/model/io.jl`
- `src/model/types.jl`
- `src/model/config.jl`
- `src/model/results.jl`
- `src/pipeline/config.jl`
- `src/plotting/diagnostics.jl` where wording/refusal logic refers to VI

### Tests

- `test/inference/vi.jl` (delete), `test/inference/runtests.jl`, and
  `test/inference/matrix.jl`
- `test/api_exports.jl`
- `test/model/config.jl`, `test/model/io.jl`, `test/model/results.jl`, and
  `test/model/time_varying_media.jl`, including crafted mismatched envelope/
  fit-state backend payload coverage
- affected VI-only blocks in `test/postmodel/`, `test/optimization/`,
  `test/plotting/`, `test/validation/`, and pipeline config/CLI tests; retain
  an MCMC `posterior_density_plot` test in `test/plotting/diagnostics.jl`

### Documentation And Planning

- `README.md`, `CHANGELOG.md`, `docs/src/index.md`, `docs/src/api.md`,
  `docs/src/release.md`, and `docs/src/calibration.md`
- `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`,
  `.planning/ABACUS-PARITY-LEDGER.md`, and `.planning/API-EXPORT-TRIAGE.md`

## Acceptance Criteria

1. `Epsilon.VariationalConfig` and `Epsilon.approximate_fit!` are undefined,
   unexported, undocumented, and unused in current runtime/test code.
2. The package no longer includes an executable VI source file or emits a
   `:variational` fit state.
3. Fit-state restore permits only `nothing` or `:turing`; model-envelope and
   inner fit-state backends are coherent. Result constructors/loaders allow
   only `:turing`, deterministic `:fixture`, or an unfitted/no-chain `nothing`
   container. `:variational` and arbitrary backend symbols are rejected before
   reporting, post-model, optimisation, or loaded-model use.
4. Model config and pipeline config fail closed for all three VI-shaped input
   keys and non-MCMC backend values, including configurations without
   calibration.
5. MCMC regression coverage remains at every consumer boundary from which a
   VI-only test was removed.
6. Current-facing documentation says VI will not be implemented, while
   historical records remain historically accurate. The ledger’s VI row is
   `deferred`.
7. `Project.toml`, `Manifest.toml`, and docs manifest do not change.

## Verification

During implementation, run only focused lanes:

```bash
make test-file FILE=test/inference/mcmc.jl
make test-file FILE=test/inference/results.jl
make test-file FILE=test/api_exports.jl
make test-file FILE=test/model/config.jl
make test-file FILE=test/model/io.jl
make test-file FILE=test/model/results.jl
make test-file FILE=test/pipeline/config.jl
make test-file FILE=test/plotting/diagnostics.jl
make test-model
make format-check-touched
git diff --check
test -z "$(git diff --name-only -- Project.toml Manifest.toml docs/Manifest.toml)"
rg -n "VariationalConfig|approximate_fit!|Turing\\.Variational|:variational" src test README.md docs/src
```

The final `rg` must return only intentionally retained historical text or
explicit rejected-input names, documented in the review request.

After independent implementation review, run exactly one `make check-full` at
Phase 38 closure. Do not run the full suite during ordinary iteration.

Closure verification completed:

- Focused regression after the closure-gate finding:
  `make test-file FILE=test/postmodel/hsgp_guard.jl` passed `11 / 11`.
- The reviewed fix marks the synthetic HSGP guard posterior as a deterministic
  fitted `:fixture` artifact, matching the Phase 38 backend policy without
  weakening fit-state rejection for retired or unknown backends.
- Phase-closing `make check-full` passed `9925 / 9925` tests in `23m33.1s` and
  completed the docs build successfully.

## Risks And Review Questions

1. Does a generic grouped artefact with `backend = :variational` still reach a
   post-model or optimisation consumer?
2. Can a top-level VI-shaped model-config key bypass calibration validation and
   remain silently stored as `extras`?
3. Do any removed VI tests provide unique MCMC behavior coverage rather than
   merely exercising the retired backend?
4. Does any current-facing doc still imply future VI implementation, or does
   historical documentation get incorrectly rewritten as if it never existed?
5. Did dependency metadata stay untouched despite Turing retaining AdvancedVI
   transitively?
