# Adoption-Lint Conventions

This repository has landed two different conventions for a lint that guards against a
hand-rolled pattern regrowing once a shared helper already exists to replace it. Both are
legitimate; the choice between them is a single decision rule, not a matter of taste. Read this
before building a third adoption lint from scratch.

## The Two Conventions

### Zero-tolerance (single-source assertion)

**Precedent**: `tests/test-common-lib.sh`'s `collect_session_id_offenders()`, which asserts that
`common_session_id()` in `lib/common.sh` is the *only* place a session ID is generated anywhere
in scope. Any hit outside `lib/common.sh` itself (and the assertion's own test file) is a
failure, unconditionally — there is no allowlist.

This convention works when the class being guarded has already been migrated to (or started at)
zero real duplicates. The assertion is simple, has no upkeep burden, and gives the strongest
possible guarantee: the shared helper is the single source of truth, full stop.

### Structural-plus-reasoned-allowlist

**Precedent**: `scripts/lint/lint-state-writer-boundary.sh` (state.json hand-rolled writes) and
`scripts/lint/lint-task-lookup-adoption.sh` (hand-rolled full-record task lookups). Both use two
layers: a structural classifier (Layer 1) that distinguishes the guarded anti-pattern shape from
adjacent-but-legitimate shapes, plus a file-level allowlist (Layer 2) whose every entry carries an
inline reason — no bare paths.

This convention works when the class being guarded has real, non-zero migration debt at landing
time. A zero-tolerance assertion would simply fail on day one and either block landing the lint
entirely or force a rushed, unreviewed mass-migration to make it pass. The allowlist instead lets
the lint land immediately and start preventing *new* occurrences, while existing debt is retired
incrementally and each retirement shrinks the allowlist by one reasoned entry.

## The Decision Rule

**Non-zero migration debt at landing time selects the allowlist convention. A class already
migrated to (or starting at) zero selects zero-tolerance.**

Check the live duplicate count before choosing, not the count from whatever report or dispatch
message motivated the task — it is common for that count to be stale or to conflate two distinct
helpers (see `lint-task-lookup-adoption.sh`'s own header for a worked example: a dispatch message
that misattributed one helper's adopter count to a different, unrelated helper). If the honest
live count is non-zero, use the allowlist convention. Retrofitting zero-tolerance onto a
non-empty class either blocks the lint from landing at all, or forces a rushed migration whose
correctness cannot be verified as carefully as an incremental one can.

## Two Structural Requirements Every Adoption Lint In This Repo Must Satisfy

1. **Deterministic dual-mode root resolution (source-store vs. deployed).** An adoption lint must
   resolve correctly whether it is invoked from the source store
   (`agent-system/extensions/<ext>/scripts/lint/`) or from a deployed checkout
   (`.claude/scripts/lint/`), and must not silently scan the wrong tree (or an empty one) in
   either case. This was the defect that made an earlier single-source gate worthless: an
   environment-dependent scan root that happened to resolve correctly in one invocation context
   and silently found nothing in another. Reuse the probe already established rather than
   re-deriving it: `tests/test-common-lib.sh`'s `collect_session_id_offenders()` probes for
   `core/manifest.json` one level under a candidate root to distinguish source-store (nested,
   per-extension `manifest.json` files) from deployed (flat, no per-extension nesting) layout.

2. **Executable-surface file scope by construction, not by exclusion list.** Scope is `*.sh`
   across the extension's `scripts/` tree, plus `*.md` scoped *only* to `commands/`, `skills/`,
   `agents/` subdirectories. `docs/`, `context/`, and `rules/` are out of scope because the scan
   never visits them — never because a growing per-file exclusion list happens to skip them. A
   lint that is `.sh`-only, blind to the `.md` executable surfaces where a skill or command's own
   inline bash blocks live, misses most of the real offenders in this codebase (lifecycle
   `SKILL.md` files in particular).

## Allowlist Hygiene Rule

Every Layer 2 allowlist entry carries an inline reason; there are no bare paths. A bare path list
rots into an unauditable suppression file with no record of *why* each entry is there or whether
it is still needed. The list is expected to **shrink** over time as sites migrate to the shared
helper — adding a new entry is a deliberate act with a stated reason, never the default response
to a failing run. When every entry is retired and the class reaches zero real duplicates, that is
the signal to reconsider migrating the lint itself to the zero-tolerance convention.

## See Also

- `scripts/lint/lint-state-writer-boundary.sh` — the state.json hand-rolled-write lint (allowlist
  convention).
- `scripts/lint/lint-task-lookup-adoption.sh` — the task-lookup lint (allowlist convention); its
  own header documents the detection model, known limitations, and the two canonical helpers
  (`skill_validate_input()` in `scripts/skill-base.sh`, `gate_in()` in
  `scripts/command-gate-in.sh`) it guards.
- `tests/test-common-lib.sh`'s `collect_session_id_offenders()` — the session-ID generator lint
  (zero-tolerance convention) and the dual-mode root-resolution probe both allowlist-convention
  lints above reuse.
