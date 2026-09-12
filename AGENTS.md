# AGENTS.md

## Project

This repository implements a grid-based turn-based tactical game in Godot.

Do not reinterpret the project as a generic RTS, card game, or Go clone.

Use project terminology consistently. Prefer the canonical names already used by the codebase and design documents.

## Source of Truth

Gameplay rules and design intent are defined by:

1. `docs/anchor_core_rules_en.md` — authoritative core rules.
2. `docs/anchor_expansion_design_en.md` — expansion concepts, prototypes, and implementation direction.

Core rules take precedence over expansion ideas.

Do not duplicate gameplay rules in this file.

When a task depends on gameplay behavior, read only the relevant sections of the design documents.

If repository paths differ, use the corresponding current core-rules and expansion-design documents.

## Scope Discipline

Prefer the smallest change that fully satisfies the task.

Do not:

- redesign unrelated mechanics;
- resolve unrelated open questions;
- implement nearby ideas opportunistically;
- refactor unrelated systems without a concrete need;
- change established gameplay behavior unless the task requires it;
- hide gameplay decisions inside implementation details.

Preserve existing working behavior unless the task intentionally changes it.

## Architecture

Follow the architecture already established in the repository.

Prefer:

- deterministic, testable gameplay simulation;
- gameplay logic separated from UI and rendering;
- centralized legality and state resolution;
- data-driven gameplay content and balance values;
- explicit stable IDs for persistent game entities;
- deterministic RNG seeds where randomness affects gameplay;
- replayable action/state logs when practical;
- existing Godot conventions.

Avoid:

- UI code deciding gameplay legality;
- card or content scripts duplicating core rule logic;
- unnecessary scene-tree coupling;
- one monolithic simulation script;
- speculative abstractions for systems that do not yet exist;
- switching language or architecture without a concrete reason.

Favor a clear playable implementation over framework-building.

## Coding Style

- Add a concise file-level summary comment where appropriate.
- Add concise comments for non-obvious gameplay functions.
- Keep functions focused and preferably under ~100 lines.
- Prefer readable names over abbreviations.
- Keep state transitions explicit.
- Prefer reusable helpers for shared simulation logic.
- Centralize configuration and balance constants.
- Design for known future extension points, but do not over-engineer.

## Task Workflow

For implementation and bug-fix tasks:

1. Identify the directly affected system and files.
2. Inspect the current implementation and focused tests.
3. Inspect relevant `git diff` when uncommitted or recent changes may affect the task.
4. Read design/specification documents only when the task depends on gameplay rules, changes them, or may conflict with them.
5. Trace only the call/state flow necessary to understand the requested behavior.
6. If genuinely blocked by an unresolved design decision, stop and ask rather than inventing a permanent rule.
7. Expand repository search only when a concrete dependency, ambiguity, or regression risk requires it.
8. Implement the requested behavior rather than stopping at analysis unless genuinely blocked.
9. Add or update focused tests when practical.
10. Run the narrowest relevant validation first; run broader tests only when justified.
11. Inspect the final diff for unintended changes.
12. For bug fixes, verify the reported bug is fixed and check likely regressions.
13. Commit completed changes with a concise descriptive message prefixed with `[codex]`.

Do not perform a full repository review for ordinary incremental tasks.

Reuse valid context from the current session unless repository state contradicts it.

## Design Changes

When explicitly asked to implement changed design documents:

1. inspect the relevant design-document diff;
2. identify the changed requirements;
3. inspect only the affected implementation and tests;
4. update the affected systems;
5. remove behavior that directly conflicts with the new specification;
6. preserve unrelated behavior;
7. update focused tests as needed.


When a task establishes or changes a permanent gameplay rule, update the appropriate design document with the smallest necessary edit.

Do not modify design documents merely to accommodate an implementation bug when the intended rule is already specified.

## Testing

Add automated tests for gameplay formulas, state transitions, topology, and regressions when practical.

Prefer:

- small deterministic fixtures;
- reproducible RNG seeds;
- focused regression tests;
- direct simulation tests over UI-driven tests when possible.

Do not run unrelated expensive validation as routine ceremony.

For bug fixes:

- reproduce the bug when practical;
- add a regression test when the behavior is testable;
- verify the fix against nearby edge cases.

## Markdown / Specification Editing

For Markdown and design files:

- make minimal targeted edits;
- preserve surrounding structure and formatting where practical;
- do not globally reformat unrelated content;
- keep diffs focused on semantic changes;
- do not duplicate rules across documents unnecessarily.

## Git / Commit Discipline

Before committing:

- inspect the final diff;
- remove accidental or unrelated changes;
- ensure generated/debug artifacts are not committed unless intended;
- verify relevant tests pass.

Commit completed changes with:

```text
[codex] concise descriptive message
```

If the task is incomplete or blocked, do not create a misleading completion commit.

## Final Report

After implementation, briefly report:

- what changed;
- root cause for bug fixes;
- files changed;
- tests/validation performed and results;
- remaining limitations or ambiguities;
- manual verification steps when relevant.
