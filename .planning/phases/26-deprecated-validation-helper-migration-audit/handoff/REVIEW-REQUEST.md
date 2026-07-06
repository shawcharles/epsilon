# Review Request: Phase 26 Deprecated Validation Helper Migration Audit

## Review Focus

Please review the Phase 26 implementation from a senior Julia library/API
governance perspective.

## Intended Behaviour

- No exports are removed.
- No runtime warning text changes.
- No validation semantics or model behaviour changes.
- The six deprecated validation-helper exports remain exported and remain
  `deprecation-candidate`.
- The new migration audit records current state only: runtime warnings landed,
  replacements guarded, and not ready to unexport.
- The focused `api_exports` guard keeps the audit aligned with the filtered
  deprecated-helper export subset, triage register, cleanup RFC, and
  runtime-deprecation design.

## Must Check

- `.planning/API-EXPORT-CLEANUP-RFC.md` distinguishes historical Phase 22
  candidate status from current post-Phase-24 runtime-warning status without
  overclaiming readiness.
- `test/api_exports.jl` correctly parses the new table with exact structure.
- The guard validates only the six deprecated helpers, not all exports.
- Migration text must match across triage, RFC, audit, and runtime design.
- The implementation does not touch `src/`, `Project.toml`, exports, model
  source, or calibration source.
- `CHANGELOG.md`, `.planning/ROADMAP.md`, and `.planning/STATE.md` remain
  conservative and do not imply stable-v1 API readiness or Abacus parity.

## Verification Already Run

```bash
make test-file FILE=test/api_exports.jl
julia --project=@runic -m Runic --check --diff test/api_exports.jl
git diff --name-only -- src/
git diff --check
```

`make test-file FILE=test/api_exports.jl` passed after fixing the audit-table
separator parser bug found during the first Builder verification attempt.
