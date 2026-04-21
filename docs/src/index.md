# Epsilon.jl

`Epsilon.jl` is a Julia-native framework for Bayesian marketing mix modeling.
The initial package scaffold follows standard Julia package conventions so the
port from Abacus can grow in layers without fighting the toolchain.

## Current Status

Epsilon is in Phase 0:

- package entry point
- test harness
- docs scaffold
- CI workflow skeleton
- repository standards

## Working Principles

- Preserve statistical parity with Abacus, not Python implementation details.
- Prefer Julia-native APIs, multiple dispatch, and explicit types.
- Keep the public API small until each layer is stable.
- Treat autodiff compatibility and numerical tests as first-class constraints.

## Planning

Project planning documents live under `.planning/` in the repository root.

## Standards

Repository standards are defined in `TECHNICAL-STANDARDS.md` at the repository
root.
