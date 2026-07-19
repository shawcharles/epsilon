# Phase 48: Internal Provenance Rename Assessment

Status: Landed

## Objective

Assess whether and how remaining internal Abacus-named provenance surfaces
should migrate to neutral reference naming after Phase 47 made the public
identity Epsilon-first.

This is a planning-only phase. It does not rename fixture directories,
generated constants, exporter scripts, ledger files, demo paths, source
functions, or tests.

## File Allowlist

Closure may touch only:

- `.planning/phases/48-internal-provenance-rename-assessment/PLAN.md`
- `.planning/ROADMAP.md`
- `.planning/STATE.md`

The pre-existing untracked `.planning/CRITICAL-REVIEW-2026-07-19.md` remains
outside this phase and must not be staged.

## Background

Phase 46 classified Abacus references by audience and purpose. Phase 47 rewrote
current public-facing identity language while preserving validation provenance.
The remaining work is harder: many names are not prose. They are fixture paths,
generated constants, test includes, exporter CLI defaults, demo data paths, and
planning links.

Renaming them without a compatibility contract would create churn and could
damage the audit trail that currently makes numerical claims reproducible.

## Current Inventory

Fresh post-Phase-47 scan, excluding `Manifest.toml`, binary/local `.jls`
artifacts, and the Phase 46/47 plan directories:

```bash
git ls-files \
  | grep -Ev '(^Manifest\.toml$|\.jls$|^\.planning/phases/46-abacus-reference-decoupling/|^\.planning/phases/47-public-identity-rewrite/)' \
  | xargs rg -i --count-matches "abacus"
```

Result: **164 tracked files** with **1,734 matches**.

Additional filesystem counts:

- `test/fixtures/abacus/`: 59 tracked fixture/data files; 29 contain Abacus
  provenance text or generated `ABACUS_*` constants.
- `examples/demo/reference/abacus/`: 7 tracked reference input files.
- `examples/demo/results/`: 90 tracked result-sidecar files, some preserving
  historical `reference/abacus/...` paths.

## Dependency Clusters

### 1. Fixture Directory And Generated Constants

Examples:

- `test/fixtures/abacus/*.jl`
- generated constants such as `ABACUS_BATCHED_CONVOLUTION_CASES`,
  `ABACUS_TIMESERIES_CONFIG_DATA`, and `ABACUS_CALIBRATION_INTEGRATION_CASES`
- test files under `test/transforms/`, `test/model/`, `test/pipeline/`,
  `test/postmodel/`, `test/optimization/`, and `test/validation/`

Assessment: high-value provenance, high rename blast radius. The current names
tell reviewers exactly which implementation generated the comparison facts.
Neutral names would improve Epsilon identity but weaken traceability unless the
source provenance remains explicit inside each fixture header.

Recommendation: do not path-rename this cluster directly. First add a neutral
fixture alias layer or regenerate fixtures with both neutral public constants
and explicit source-provenance metadata, then migrate tests in focused layers.

### 2. Exporter Scripts

Examples:

- `scripts/export_abacus_fixtures.py`
- `scripts/export_abacus_postmodel_fixtures.py`
- `scripts/export_abacus_optimization_fixtures.py`
- `scripts/export_abacus_validation_fixtures.py`

Assessment: these are internal acquisition tools whose current names are
accurate because they import the local Abacus checkout. Renaming them to
generic `export_reference_*` names would be misleading unless the CLI contract
also supports more than one reference implementation.

Recommendation: keep script filenames until a wrapper exists. A future phase
can add neutral wrapper commands while retaining the Abacus-specific scripts as
implementation backends.

### 3. Demo Reference Paths

Examples:

- `examples/demo/reference/abacus/`
- `examples/demo/epsilon/timeseries/config.yml`
- `examples/demo/run_demo.jl` fields such as `abacus_config`
- historical files under `examples/demo/results/`

Assessment: medium user-facing visibility, medium-high compatibility risk.
The paths are embedded in runnable configs and committed result metadata.
Renaming the directory would require result policy decisions: regenerate,
delete, or preserve historical output paths.

Recommendation: defer a path rename until there is a separate demo-artifact
policy. If renamed, provide one deliberate migration in the runner/configs and
either regenerate or explicitly archive old result directories.

### 4. Source And Docstring Implementation Names

Examples:

- private `_normalize_abacus_config_surface` in `src/model/config.jl`
- source docstrings citing mirrored Abacus calibration/HSGP semantics
- field names such as `abacus_config` in example-only demo metadata

Assessment: low public API risk where private, but docstrings often preserve
methodological traceability. Renaming private helpers is feasible after fixture
and exporter policy is settled.

Recommendation: allow narrow private source renames later, but do not remove
source citations that explain exact mirrored semantics.

### 5. Planning Ledger And Historical Records

Examples:

- `.planning/ABACUS-PARITY-LEDGER.md`
- historical phase plans and reviews
- `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`

Assessment: high churn, low immediate user value. The ledger filename is
historical but still the controlling evidence record. A rename would require a
compatibility stub or broad link update, and historical phase records should
not be scrubbed.

Recommendation: do not rename the ledger before v1. Before v1, at most add an
Epsilon-first preamble in a separate reviewed slice. Any filename rename is
post-v1 work and must include a compatibility stub at the old path plus a link
audit.

## Decision Matrix

| Surface | Rename Now? | Later Strategy | Primary Risk |
|---|---:|---|---|
| `test/fixtures/abacus/` | No | Neutral alias layer first, then layer-by-layer test migration | Broken includes and weaker provenance |
| Generated `ABACUS_*` constants | No | Emit or define `REFERENCE_*` aliases before migrating consumers | Large test churn |
| Exporter script filenames | No | Add neutral wrapper commands while preserving backend-specific scripts | Misleading generic names |
| Demo `reference/abacus/` paths | No | Separate demo-result policy, then one migration | Stale committed result metadata |
| Private source helper names | Not alone | Rename after fixture/exporter policy | Low value if done in isolation |
| `.planning/ABACUS-PARITY-LEDGER.md` | No | Post-v1 rename only, with compatibility stub and link audit | Broken planning links and audit trail |
| Historical phase/review docs | No | Add forward pointers only where needed | History laundering |

## Recommended Future Sequence

### Phase 49: Neutral Fixture Alias Contract

Goal: introduce a neutral fixture-consumption layer without moving fixture
files or deleting `ABACUS_*` constants.

Likely work:

- add a small `test/fixtures/reference_aliases.jl` or exporter-generated alias
  block that maps selected `REFERENCE_*` names to existing `ABACUS_*` fixtures;
- make the alias boundary explicitly state that the current source backend is
  Abacus and preserve source checkout/revision metadata;
- migrate one low-risk layer, probably transform tests, from direct
  `ABACUS_*` consumption to neutral aliases;
- verify with the targeted transform test lane and `test/api_exports.jl` only
  if docs guard wording changes.

### Phase 50: Exporter Wrapper And Provenance Metadata

Goal: separate neutral fixture workflow naming from Abacus-specific acquisition.

Likely work:

- add neutral wrapper script or documented command that calls the existing
  Abacus-specific exporters;
- make the wrapper declare the sole current backend explicitly; it must not
  imply multi-reference support unless another backend is implemented;
- keep explicit source metadata in generated fixture headers:
  source implementation, source checkout path, source revision, export command;
- avoid claiming support for non-Abacus reference backends unless implemented.

### Phase 51: Demo Reference Path Policy

Goal: decide whether demo inputs should remain under `reference/abacus/` or
move to a neutral path.

Likely work:

- classify committed demo result directories as historical artifacts,
  regenerated artifacts, or removable artifacts;
- choose one explicit result-sidecar policy before any path move: preserve
  historical sidecars unchanged, regenerate them all, or delete/archive them;
- if path migration is accepted, update configs and runner fields in one slice;
- add a focused demo path/list test rather than running demo MCMC.

### Phase 52: Ledger Rename Or Compatibility Stub

Goal: decide whether `.planning/ABACUS-PARITY-LEDGER.md` should become a
neutral validation ledger.

Likely work:

- before v1, keep the current filename and consider only an Epsilon-first
  preamble in a separate reviewed slice;
- after v1, either keep the current filename or rename/copy to
  `.planning/REFERENCE-VALIDATION-LEDGER.md`;
- if renamed post-v1, leave a compatibility stub at the old path because many
  historical docs and tests reference it;
- update only current-facing docs and state links, not historical phase plans.

## Out Of Scope

- Any actual rename of fixture directories, constants, scripts, source helpers,
  demo data paths, or ledger files.
- Regenerating fixtures or demo results.
- Editing `.planning/ABACUS-PARITY-LEDGER.md`.
- Running benchmark, smoke, release, or full test gates.
- Scrubbing historical phase plans or reviews.

## Verification

Planning-only verification:

```bash
git diff --check
git diff --cached --check
```

Closure status check:

```bash
git status --short
```

The status output must show only the intended Phase 48 tracked files plus the
pre-existing untracked `.planning/CRITICAL-REVIEW-2026-07-19.md`.

Optional, if touched-file formatting includes Markdown:

```bash
make format-check-touched
```

No Julia tests are required because this phase changes only planning/state
documents and does not change runtime, tests, docs build inputs, fixtures, or
exporter behavior.

## Review Questions

An independent review must check:

- whether any recommended future phase accidentally starts a rename now;
- whether the alias-first fixture strategy preserves provenance;
- whether the exporter wrapper recommendation avoids pretending Epsilon has
  multiple reference backends;
- whether demo result metadata needs a separate policy before path renames;
- whether the ledger rename should be deferred until after v1; and
- whether the verification plan is proportionate for a planning-only slice.

Review completed before closure. Required edits were accepted: explicit file
allowlist, no ledger rename before v1, explicit source provenance at any future
alias boundary, honest single-backend wording for any neutral exporter wrapper,
demo result-sidecar policy before path migration, and status verification that
excludes the pre-existing untracked critical review file.
