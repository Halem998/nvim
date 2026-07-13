# Implementation Plan: Task #853

- **Task**: 853 - Fix email wrapper binaries silently ignoring positional account arg
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: Parent task 827 (email staleness detector redesign) — this is its Finding-5 follow-up
- **Research Inputs**: specs/853_fix_email_wrapper_account_arg/reports/01_wrapper-account-arg-parsing.md
- **Artifacts**: plans/01_wrapper-account-arg-fix.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/context/formats/plan-format.md
  - .claude/rules/pr-prohibition.md
- **Type**: email
- **Lean Intent**: false

## Overview

`mkPreamble`'s getopts-style loop in `~/.dotfiles/modules/home/email/agent-tools/lib.nix`
(loop body at lines 80-91) has no case arm for a bare positional token. Any token that is not
`--account[=...]`, `--manifest-dir[=...]`, or `--help`/`-h` falls into the catch-all
`*) ARGS+=("$1"); shift ;;` and is silently absorbed, so `ACCOUNT` stays at its hardcoded
default of `gmail` (line 60). The result: `email-census logos` silently censuses gmail. This
plan applies the research-recommended minimal fix — a `gmail|logos)` case arm that aliases the
bare enum token to `--account <token>` **only when `--account` was not already given
explicitly**, always emitting a loud `log()` NOTE (never silent). Because `mkMutationPreamble`
calls `mkPreamble` first, this single ~10-line change fixes archive/delete too. Definition of
done: the fix is applied to `lib.nix`, its Nix evaluation is verified, and all five sharing
wrappers are confirmed to resolve the account correctly (with classify/unsubscribe-extract's
`[QUERY]` positional term still intact) after the user applies the home-manager rebuild.

### Research Integration

The plan adopts the research report's recommended fix verbatim (report §Recommendations,
lines 129-201) and its scope corrections:
- **Corrected binary list**: the five mkPreamble-sharing binaries are `email-census`,
  `email-classify`, `email-unsubscribe-extract`, `email-archive-confirmed`,
  `email-delete-confirmed`. `email-reindex` (in `mbsync.nix`) does **not** use `mkPreamble`,
  takes no `--account`, is account-agnostic, and is **out of scope** — it is excluded from the
  fix and from verification.
- **Rejected alternative**: a uniform "hard-error / reject any positional arg" rule was rejected
  because it cannot be applied safely inside the shared `mkPreamble` without breaking
  `email-classify` and `email-unsubscribe-extract`'s documented `[QUERY]` positional feature
  (`classify.nix:56-58`, `unsubscribe-extract.nix:41-43`: `if [ "$#" -gt 0 ]; then QUERY="$*"; fi`).
- **Enum-scoped + gated design**: matching only the literal `gmail|logos` values (not "any bare
  token") preserves the `[QUERY]` feature for all other query terms; gating on
  `ACCOUNT_EXPLICIT` preserves it even for the pathological literal-`logos`-as-query case when
  `--account` is passed explicitly.
- **Nix escaping**: the new arm introduces no `${...}`-braced references (only bare `$1` /
  `$ACCOUNT_EXPLICIT`), matching the existing unescaped style in the file, so no additional
  nix-level escaping is required (report Risks §, lines 229-235).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found (roadmap flag not set).

## Goals & Non-Goals

**Goals**:
- Eliminate the silent-wrong-account failure mode in the shared `mkPreamble` arg loop.
- Make `email-census logos` (and the analogous invocation for all five wrappers) correctly
  target the `logos` account, with a visible `log()` NOTE explaining the interpretation.
- Preserve `email-classify` / `email-unsubscribe-extract`'s `[QUERY]` positional-arg feature.
- Verify the change evaluates as valid Nix before the user rebuilds.

**Non-Goals**:
- Do NOT run `home-manager switch` or otherwise activate the change (user-applied).
- Do NOT commit or push in `~/.dotfiles` (cross-repo; user handles version control there).
- Do NOT touch `email-reindex` / `mbsync.nix` — out of scope (account-agnostic, no `mkPreamble`).
- Do NOT modify `mkMutationPreamble`'s own separate arg loop — it inherits the fix transitively
  and its residual positional-swallow is currently harmless (report Risks §, lines 236-241).
- Do NOT add per-binary hard-reject guards to census/archive/delete (rejected alternative).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Nix string-escaping mistake (unescaped `${...}`) causes an antiquotation build error | M | L | New code introduces no `${...}` braces; verify with `nix flake check` / `nix eval` before user rebuild (Phase 2) |
| A `classify`/`unsubscribe-extract` user wants a notmuch query that is literally the word `gmail`/`logos` with no `--account` | L | L | Narrow edge case; `log()` NOTE makes reinterpretation visible; user can pass `--account <acct> <query>` (hits the `ACCOUNT_EXPLICIT` pass-through) or add a term like `body:logos` |
| Behavioral verification cannot complete in-session because the rebuild is user-applied | L | M | Phase 3 documents exact verification commands for the user to run post-rebuild; the fix itself and Nix-eval verification (Phases 1-2) complete in-session |
| Edit does not match the file (line drift from research's line numbers) | L | L | Re-read the current `lib.nix` loop before editing; match on stable surrounding text, not line numbers |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel. This plan is fully sequential.

### Phase 1: Apply the enum-aware positional alias to mkPreamble [COMPLETED]

**Goal**: Add the `gmail|logos)` case arm (and the `ACCOUNT_EXPLICIT` flag) to `mkPreamble`'s
getopts loop in `lib.nix`, so a bare `gmail`/`logos` token aliases to `--account <token>` with
a loud NOTE unless `--account` was already given explicitly.

**Tasks**:
- [x] **Task 1.1**: Re-read `~/.dotfiles/modules/home/email/agent-tools/lib.nix` around the
      `mkPreamble` loop (approx. lines 60-91) to confirm current text and the
      `ACCOUNT="gmail"` default line. *(completed)*
- [x] **Task 1.2**: Introduce an `ACCOUNT_EXPLICIT=0` initialization before the `while` loop
      (alongside the existing `ARGS=()`). *(completed)*
- [x] **Task 1.3**: Set `ACCOUNT_EXPLICIT=1` in the two existing `--account` / `--account=*`
      arms. *(completed)*
- [x] **Task 1.4**: Add a new `gmail|logos)` case arm before the catch-all `*)` arm that:
  - when `ACCOUNT_EXPLICIT=1`: pushes the token to `ARGS[]` unchanged (preserves `[QUERY]`);
  - otherwise: emits `log "NOTE: interpreting bare positional '$1' as '--account $1' (pass --account explicitly to silence this note)"`, sets `ACCOUNT="$1"` and `ACCOUNT_EXPLICIT=1`;
  - then `shift`. *(completed)*
- [x] **Task 1.5**: Preserve the file's existing nix `''${...}` escaping style for pre-existing
      lines; add NO new `${...}`-braced references in the new arm (only bare `$1` /
      `$ACCOUNT_EXPLICIT`). *(completed)*
- [x] **Task 1.6**: Confirm the catch-all `*) ARGS+=("$1"); shift ;;` arm remains unchanged
      (non-enum positional tokens still fall through to it). *(completed)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `~/.dotfiles/modules/home/email/agent-tools/lib.nix` — add `ACCOUNT_EXPLICIT` flag and the
  `gmail|logos)` alias arm inside `mkPreamble`'s arg loop (the exact diff is in the research
  report, lines 133-158).

**Verification**:
- Visual diff of the loop matches the report's recommended fix (report lines 133-158).
- The two `--account` arms now set `ACCOUNT_EXPLICIT=1`; the new arm gates on it; the catch-all
  is untouched.

---

### Phase 2: Verify Nix evaluation of the modified module [COMPLETED]

**Goal**: Confirm the edited `lib.nix` is syntactically valid Nix and the home-manager config
still evaluates, without activating anything.

**Tasks**:
- [x] **Task 2.1**: From `~/.dotfiles`, run a read-only evaluation check — `nix-instantiate
      --eval --strict` directly on `lib.nix`, confirming `mkPreamble` renders with no Nix parse
      / antiquotation error. *(completed)*
- [x] **Task 2.2**: Fell back to (and additionally performed, for stronger confidence) a
      narrower eval: built a real `pkgs.writeShellScriptBin` derivation using the flake's
      `homeConfigurations.benjamin.pkgs` with the edited `mkPreamble`, ran `bash -n` on the
      built script, and functionally exercised the built binary (in the scratchpad, with
      `EMAIL_MANIFEST_DIR` overridden — no real account/mail access) against all 5 scenarios
      from the Phase 3 verification matrix (bare enum alias + NOTE, explicit
      `--account`+query-passthrough, normal query term, `--account=` form). All 5 matched
      expected `ACCOUNT`/`ACCOUNT_EXPLICIT`/`ARGS` results in-session, ahead of the user's
      rebuild. *(completed: full `nix flake check` skipped as unnecessary — the narrower email-module
      build sufficed and avoided evaluating unrelated NixOS/host modules)*
- [x] **Task 2.3**: Confirmed via `git status`/`git log` in `~/.dotfiles` that no
      `home-manager switch`, `git commit`, or `git push` occurred — only the intended
      `lib.nix` edit remains uncommitted. *(completed)*

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- None (verification only).

**Verification**:
- `nix flake check` (or the narrower eval) completes with no error attributable to the edit;
  any pre-existing unrelated warnings are noted but not blocking.
- No activation, commit, or push occurred in `~/.dotfiles`.

---

### Phase 3: Document and confirm behavioral verification of the five wrappers [COMPLETED]

**Goal**: Provide the exact post-rebuild verification steps proving each of the five sharing
wrappers resolves the account correctly and that the `[QUERY]` feature is preserved. The
home-manager rebuild that deploys the change is a **user-applied step** — this phase records
what the user runs and what the expected outcomes are.

**Tasks**:
- [x] **Task 3.1**: Recorded the user-applied deploy step below: the user runs
      `home-manager switch` (in `~/.dotfiles`) to activate the fixed wrappers. The agent did
      NOT run this. *(completed)*
- [x] **Task 3.2**: Documented post-rebuild verification commands and expected results (see
      the plan's existing "Post-rebuild verification matrix" above and the implementation
      summary). *(completed)*
- [x] **Task 3.3**: Confirmed the corrected scope: verification covers `email-census`,
      `email-classify`, `email-unsubscribe-extract`, `email-archive-confirmed`,
      `email-delete-confirmed` — NOT `email-reindex`. *(completed)*

**Post-rebuild verification matrix** (user runs after `home-manager switch`):

1. **Bare positional now resolves the account (with NOTE)** — for each of the five wrappers, a
   bare `logos` token targets the logos account and prints a visible
   `[<binary>] NOTE: interpreting bare positional 'logos' as '--account logos' ...` to stderr:
   - `email-census logos` — operates on logos (previously silently gmail), NOTE visible.
   - `email-classify logos` — resolves account to logos, NOTE visible.
   - `email-unsubscribe-extract logos` — resolves account to logos, NOTE visible.
   - `email-archive-confirmed logos ...` — resolves to logos (dry-run without `--execute`),
     NOTE visible; previously-silent wrong-account mutation is now impossible.
   - `email-delete-confirmed logos ...` — resolves to logos (dry-run without `--execute`),
     NOTE visible.
2. **Explicit `--account` still wins and passes the positional through as `[QUERY]`**:
   - `email-classify --account logos gmail` — operates on logos, and the literal token `gmail`
     is passed through as the notmuch `[QUERY]` (NOT reinterpreted as an account), because
     `ACCOUNT_EXPLICIT=1` sends it to the pass-through arm. No NOTE about reinterpretation.
   - `email-unsubscribe-extract --account logos gmail` — same: account=logos, `gmail` used as
     `[QUERY]`.
3. **Normal query terms unaffected**:
   - `email-classify tag:inbox` (or any non-enum term) — falls through the existing catch-all
     `*)` arm and is used as `[QUERY]` on the default account exactly as before.
4. **`--account` explicit form unchanged**:
   - `email-census --account logos` — operates on logos with no reinterpretation NOTE (the
     explicit arm handles it directly).

**Timing**: 25 minutes (documentation in-session; command execution is user-applied post-rebuild)

**Depends on**: 2

**Files to modify**:
- None (documentation / verification only).

**Verification**:
- The verification matrix above is captured in the implementation summary so the user has a
  copy-pasteable checklist.
- Each of the five wrappers is enumerated; `email-reindex` is explicitly excluded.

---

## Testing & Validation

- [ ] `lib.nix` edit matches the research-recommended diff (report lines 133-158).
- [ ] `nix flake check` (or targeted eval) in `~/.dotfiles` passes with no error from the edit.
- [ ] Post-rebuild (user-applied): `email-census logos` targets logos and prints the NOTE.
- [ ] Post-rebuild: `email-classify logos`, `email-unsubscribe-extract logos`,
      `email-archive-confirmed logos`, `email-delete-confirmed logos` each resolve to logos with
      the NOTE.
- [ ] Post-rebuild: `email-classify --account logos gmail` keeps account=logos and treats
      `gmail` as `[QUERY]` (no reinterpretation NOTE) — `[QUERY]` feature preserved.
- [ ] Post-rebuild: a normal query term (e.g. `email-classify tag:inbox`) still flows to
      `[QUERY]` unchanged.
- [ ] No `home-manager switch`, `git commit`, or `git push` was run by the agent in `~/.dotfiles`.

## Artifacts & Outputs

- Modified `~/.dotfiles/modules/home/email/agent-tools/lib.nix` (mkPreamble arg loop).
- Implementation summary: `specs/853_fix_email_wrapper_account_arg/summaries/01_wrapper-account-arg-fix-summary.md`
  (created at /implement), including the post-rebuild verification matrix as a user checklist.

## Rollback/Contingency

The change is a single, self-contained ~10-line addition to one function in one file. To revert,
restore the original `mkPreamble` loop in `lib.nix` (remove the `ACCOUNT_EXPLICIT` flag, the two
`ACCOUNT_EXPLICIT=1` assignments, and the `gmail|logos)` arm) and re-run the user-applied
home-manager rebuild. Because `~/.dotfiles` is version-controlled by the user, `git checkout --
modules/home/email/agent-tools/lib.nix` (run by the user) is the fastest revert. No data
migration or state change is involved, so rollback is risk-free. If `nix flake check` fails in
Phase 2, revert the edit before the user rebuilds so a broken module is never activated.
