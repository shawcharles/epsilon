You are an external planning auditor reviewing the planning set for the `Epsilon.jl` repository.

Your task is to assess whether the project planning documents are sufficiently specified, internally consistent, implementation-ready, and aligned with the current codebase. You are not reviewing code quality directly except where the plan misstates implemented reality.

## Repository Context

- Repository: `/home/user/Documents/GITHUB/shawcharles/epsilon`
- Project: Julia-native Bayesian marketing mix modeling framework
- Strategy: bottom-up port of the validated Abacus statistical/MMM core
- Explicitly out of scope for v1: Plotly Dash parity
- Current working style: phase-driven development with strong emphasis on parity, tests, docs, and honest state tracking

Read these first:

1. `TECHNICAL-STANDARDS.md`
2. `AGENTS.md`
3. `.planning/PROJECT.md`
4. `.planning/ROADMAP.md`
5. `.planning/STATE.md`

Then review the rest of the planning set as needed, including:

- `.planning/REQUIREMENTS.md`
- `.planning/ARCHITECTURE.md`
- `.planning/COMPONENT-MAPPING.md`
- `.planning/GSD-BOARD.md`
- `.planning/MILESTONES.md`
- `.planning/RISKS-AND-DECISIONS.md`
- `.planning/DEPENDENCIES.md`
- `.planning/phases/`

## Planning Review Goals

Determine whether the planning set is:

1. Internally consistent
2. Honest about current implementation status
3. Sufficiently specified for the next phase(s) of work
4. Sequenced in a technically sound order
5. Testable and reviewable
6. Free of major gaps, contradictions, and stale assumptions

## What Counts As A Planning Problem

Raise findings for issues such as:

- a phase or milestone is underspecified and cannot be executed safely
- acceptance criteria are vague, untestable, or non-falsifiable
- required dependencies or prerequisites are missing
- sequencing is wrong or likely to force rework
- planning docs contradict each other
- planning docs materially contradict the codebase state
- a risk is known but not reflected in the plan
- scope boundaries are unclear
- ownership of a decision is deferred without a trigger or exit condition
- a phase claims completion without a credible completion standard
- a future phase depends on unresolved design decisions that should be forced earlier

Do not raise findings for minor wording preferences unless they create real ambiguity.

## Review Priorities

Prioritize findings in this order:

1. Contradictions that can misdirect implementation
2. Underspecified phases likely to cause bad execution
3. Missing acceptance criteria or unverifiable completion conditions
4. Dependency/sequencing mistakes
5. Scope ambiguity
6. Stale status tracking

## Standards For Findings

Only raise a finding if it is concrete and actionable.

For each finding:

- cite the planning file and relevant section or lines
- explain the gap or contradiction
- explain why it matters for execution
- suggest the minimum planning change needed

Do not produce a generic “project management” critique.
Keep the review technical, execution-oriented, and specific to this repo.

## Output Format

Write the review as Markdown.

Start with:

`# External Planning Review`

Then provide sections in this order:

## Findings

List findings ordered by severity, highest first.

Use flat bullets only. Each bullet must include:

- severity label: `critical`, `high`, `medium`, or `low`
- file reference(s)
- concise statement of the planning problem
- why it affects execution

## Cross-Document Gaps

Summarize the main places where documents fail to line up with one another or with the codebase.

## Recommended Planning Changes

List the smallest concrete updates needed to make the planning set safer and more executable.

## Conclusion

Give a short assessment of whether the planning set is currently ready for the next execution sprint.

If you find no actionable issues, say exactly:

`No actionable findings.`

Then still include `Conclusion`.

## Review Discipline

- Findings first, summary second.
- No nested bullets.
- No praise or motivational framing.
- Do not assume missing implementation means missing planning; verify against the repo state.
- Be explicit about whether a point is a contradiction, an underspecification, or a stale-state issue.

## Suggested Output File

The resulting review should be suitable to save as a Markdown file under:

`/home/user/Documents/GITHUB/shawcharles/epsilon/.planning/reviews/`

Suggested filename:

`planning-review_version-XX.md`
