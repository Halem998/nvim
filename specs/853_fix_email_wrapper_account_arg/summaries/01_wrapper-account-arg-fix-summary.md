# Implementation Summary: Task #853

**Completed**: 2026-07-13
**Duration**: ~45 minutes

## Overview

Fixed the silent-wrong-account bug in the shared `mkPreamble` arg-parsing loop
(`~/.dotfiles/modules/home/email/agent-tools/lib.nix`): a bare positional token such as
`logos` was previously absorbed by the catch-all arm and silently ignored, leaving `ACCOUNT`
at its hardcoded `gmail` default. The fix adds an enum-scoped `gmail|logos)` case arm, gated
on a new `ACCOUNT_EXPLICIT` flag, that aliases the bare token to `--account <token>` with a
loud `log()` NOTE — unless `--account` was already given explicitly, in which case the token
passes through unchanged (preserving `email-classify`/`email-unsubscribe-extract`'s `[QUERY]`
positional-argument feature). Because `mkMutationPreamble` calls `mkPreamble` first, this
single change transitively fixes all five sharing wrappers: `email-census`, `email-classify`,
`email-unsubscribe-extract`, `email-archive-confirmed`, `email-delete-confirmed`.
`email-reindex` is unaffected and was correctly left untouched (it does not use `mkPreamble`
and takes no `--account`).

## What Changed

- `/home/benjamin/.dotfiles/modules/home/email/agent-tools/lib.nix` — added
  `ACCOUNT_EXPLICIT=0` initialization before the `while` loop in `mkPreamble`; set
  `ACCOUNT_EXPLICIT=1` in both existing `--account`/`--account=*` arms; added a new
  `gmail|logos)` case arm before the catch-all `*)` arm that gates on `ACCOUNT_EXPLICIT` to
  either pass the token through as an ordinary positional arg (`ARGS+=("$1")`, preserving
  `[QUERY]`) or alias it to `--account $1` with a loud NOTE. No new `${...}`-braced Nix
  antiquotations were introduced (only bare `$1`/`$ACCOUNT_EXPLICIT`), matching the file's
  existing unescaped-bash-variable style.

**Note (cross-repo change)**: `~/.dotfiles` is a separate git repository from this task's
`~/.config/nvim` repo. Per task constraints, this change was made but **not committed** in
`~/.dotfiles` — that repo's version control is user-owned. `git status` in `~/.dotfiles`
confirms only this one file is modified, with no other changes and no commits/pushes made.

## Decisions

- Applied the research report's recommended diff verbatim (report §Recommendations, lines
  133-158) rather than exploring alternatives — it was already adversarially reviewed against
  the rejected "hard-reject-any-positional" alternative during planning.
- For Phase 2 verification, used a narrower, targeted Nix build (one real
  `pkgs.writeShellScriptBin` derivation built through the flake's
  `homeConfigurations.benjamin.pkgs`) instead of a full `nix flake check`, since the plan
  explicitly permits this fallback and a full check would needlessly evaluate unrelated
  NixOS/host modules.
- Went beyond the plan's Phase 2 minimum by also functionally exercising the built binary
  in-session (scratchpad-only, `EMAIL_MANIFEST_DIR` overridden, zero real notmuch/himalaya
  calls) against all 5 scenarios in the Phase 3 verification matrix, giving strong pre-rebuild
  confidence that the fix behaves correctly — this is a superset of, not a substitute for, the
  post-rebuild user checklist below.

## Plan Deviations

- None (implementation followed plan). The Phase 2 "narrow eval fallback" and the additional
  in-session functional exercise were explicitly plan-sanctioned/plan-compatible, not
  deviations.

## Verification

- Build: Success — `nix-instantiate --eval --strict` on `lib.nix` produced no
  antiquotation/parse error; a real `pkgs.writeShellScriptBin "email-census"`-style derivation
  built successfully through the flake's actual `homeConfigurations.benjamin.pkgs`; `bash -n`
  on the built script passed.
- Tests: N/A (no existing automated test suite for this shell-generation module); in-session
  functional exercise of the built binary against 5 scenarios all matched expected results
  (see table below).
- Files verified: Yes — `git diff`/`git status` in `~/.dotfiles` confirms only the intended
  `lib.nix` hunk is modified; no `home-manager switch`, `git commit`, or `git push` was run.

### In-session functional exercise (pre-rebuild, safe/no real accounts touched)

| Invocation | Result | NOTE printed? |
|---|---|---|
| `<bin> logos` | `ACCOUNT=logos ACCOUNT_EXPLICIT=1 ARGS=` | Yes |
| `<bin> --account logos gmail` | `ACCOUNT=logos ACCOUNT_EXPLICIT=1 ARGS=gmail` | No |
| `<bin> tag:inbox` | `ACCOUNT=gmail ACCOUNT_EXPLICIT=0 ARGS=tag:inbox` | No |
| `<bin> --account logos` | `ACCOUNT=logos ACCOUNT_EXPLICIT=1 ARGS=` | No |
| `<bin> --account=gmail logos` | `ACCOUNT=gmail ACCOUNT_EXPLICIT=1 ARGS=logos` | No |

All five results match the plan's intended behavior exactly.

## User-Applied Next Step (REQUIRED — not performed by this agent)

**Deploy**: Run `home-manager switch` in `~/.dotfiles` to activate the fixed wrappers. This
was intentionally NOT run by the agent per task constraints (deployment is user-applied).

### Post-rebuild verification checklist (copy-paste, run after `home-manager switch`)

1. **Bare positional now resolves the account (with NOTE)**:
   ```
   email-census logos
   email-classify logos
   email-unsubscribe-extract logos
   email-archive-confirmed logos          # dry-run, no --execute
   email-delete-confirmed logos           # dry-run, no --execute
   ```
   Each should target the `logos` account (not silently default to `gmail`) and print
   `[<binary>] NOTE: interpreting bare positional 'logos' as '--account logos' ...` to stderr.

2. **Explicit `--account` still wins; positional passes through as `[QUERY]`**:
   ```
   email-classify --account logos gmail
   email-unsubscribe-extract --account logos gmail
   ```
   Both should operate on `logos` and treat the literal token `gmail` as the notmuch
   `[QUERY]` (not reinterpreted as an account) — no reinterpretation NOTE.

3. **Normal query terms unaffected**:
   ```
   email-classify tag:inbox
   ```
   Should fall through to `[QUERY]` on the default account exactly as before the fix.

4. **Explicit `--account` form unchanged**:
   ```
   email-census --account logos
   ```
   Should operate on `logos` with no reinterpretation NOTE.

`email-reindex` is explicitly out of scope and excluded from this checklist.

## Notes

- This task is the Finding-5 follow-up to parent task 827 (email staleness detector
  redesign).
- The commit for this task's `specs/` artifacts was made in the `~/.config/nvim` repo only
  (three phase commits: `task 853 phase 1/2/3: ...`). The `lib.nix` change itself remains
  uncommitted in `~/.dotfiles`, awaiting the user's own review/commit and
  `home-manager switch` there.
