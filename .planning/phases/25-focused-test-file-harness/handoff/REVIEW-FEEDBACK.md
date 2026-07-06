# Review Feedback: Phase 25 Plan

## Reviewer

Leibniz subagent, plan review before implementation.

## Result

Approved after Must Fix clarification.

## Must Fix

1. Add explicit negative verification for selector safety: missing file,
   directory selector, `test/runtests.jl`, parent traversal, absolute outside
   path, and mixed layer/file arguments.
2. Define mixed selector behaviour before implementation.

## Should Fix

1. Specify selector normalisation: optional leading `test/`, optional `.jl`,
   canonicalise under `test/`, require `isfile`, reject `test/runtests.jl`.
2. Add Runic verification for both edited files, `test/runtests.jl` and
   `Makefile`.
3. Sanity-check `Pkg.test(...; julia_args=["--depwarn=yes"])` on the available
   Julia version.

## Resolution

- The plan and architect brief now define selector grammar and reject mixed
  layer/file mode.
- Negative verification commands are now part of the planned acceptance checks.
- Formatter verification is split by file type: Runic covers
  `test/runtests.jl`, and `git diff --check` covers both the Julia harness and
  `Makefile` whitespace.
- `Pkg.test(; test_args=["basic"], julia_args=["--depwarn=yes"])` was
  smoke-tested successfully on the local Julia version before implementation.

## Verification Position

The full suite is not required unless the harness work expands into shared
imports/export behaviour. Focused verification should prove file selectors run
inside `Pkg.test`, existing layer selectors still work, and invalid selectors
fail loudly before unrelated tests run.

---

# Review Feedback: Phase 25 Implementation

## Reviewer

Leibniz subagent, implementation review before commit.

## Result

Request changes, then cleared after local resolution.

## Must Fix

1. `.planning/STATE.md` claimed implementation review was complete before this
   implementation review was recorded, while `PLAN.md` still had the
   implementation-review acceptance items unchecked.

## Should Fix

1. Harden selector canonicalisation against symlinks under `test/` that point
   outside the test tree.

## Resolution

- This implementation-review section records the review result and resolves
  the state contradiction.
- `test/runtests.jl` now compares `realpath(candidate)` against
  `realpath(test/)` after `isfile(candidate)`, rejecting symlink escapes.
- `test/runtests.jl` also rejects a symlink that resolves to
  `test/runtests.jl`, preserving the recursive-selection guard for real paths
  as well as lexical paths.

## Final Position

No remaining Must Fix items. The implementation is bounded to Phase 25 files,
preserves existing layer and full-suite semantics, and does not change runtime
model behaviour or Abacus parity claims.
