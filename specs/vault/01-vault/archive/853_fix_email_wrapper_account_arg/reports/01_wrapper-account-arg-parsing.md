# Research Report: Task #853

**Task**: 853 - Fix email wrapper binaries silently ignoring positional account arg
**Started**: 2026-07-13T00:00:00Z
**Completed**: 2026-07-13T00:00:00Z
**Effort**: 1 hour (matches task estimate; this is a single-file, ~10-line diff)
**Dependencies**: Parent task 827 (email staleness detector redesign) — this task is its
  Finding-5 follow-up
**Sources/Inputs**:
- Codebase: `~/.dotfiles/modules/home/email/agent-tools/{lib.nix,census.nix,classify.nix,
  unsubscribe-extract.nix,archive-confirmed.nix,delete-confirmed.nix,default.nix}`,
  `~/.dotfiles/modules/home/email/mbsync.nix`
- Task 827 artifacts: `specs/827_email_staleness_detector_redesign/reports/01_staleness-detector-redesign.md`
  (Finding 5), `.orchestrator-handoff.json`, `summaries/01_staleness-detector-redesign-summary.md`
**Artifacts**:
- This report: `specs/853_fix_email_wrapper_account_arg/reports/01_wrapper-account-arg-parsing.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Root cause confirmed exactly as task 827 described**: `mkPreamble`'s getopts-style loop in
  `~/.dotfiles/modules/home/email/agent-tools/lib.nix` (loop body at lines 80-91, full preamble
  at lines 41-115) has no case arm for a bare positional token. `ACCOUNT="gmail"` is the hardcoded
  default (line 60); any token that isn't `--account[=...]`, `--manifest-dir[=...]`, or
  `--help`/`-h` falls into the catch-all `*) ARGS+=("$1"); shift ;;` and is silently absorbed —
  `ACCOUNT` is never touched.
- **Scope correction**: the task description names the affected five as email-census,
  email-classify, **email-reindex**, email-archive-confirmed, email-delete-confirmed. This is
  imprecise. `email-reindex` is defined in a *different* file (`mbsync.nix`, lines 343-377), does
  **not** call `mkPreamble`/`mkMutationPreamble` at all, takes no `--account` flag, and is
  explicitly commented `"NOT part of the 5-binary agent contract"` (mbsync.nix:347). It is
  account-agnostic (`notmuch new --no-hooks` reindexes the whole database) and is **unaffected**
  by this bug. The fifth binary that actually shares `mkPreamble` is **email-unsubscribe-extract**
  (`unsubscribe-extract.nix`). The fix should target `email-census`, `email-classify`,
  `email-unsubscribe-extract`, `email-archive-confirmed`, `email-delete-confirmed` — not
  `email-reindex`.
- **Downstream positional-arg usage differs per binary**, which constrains the fix: `census.nix`,
  `archive-confirmed.nix`, and `delete-confirmed.nix` never consume `"$@"` after the preamble (any
  leftover positional arg is dead weight today), but `classify.nix` and `unsubscribe-extract.nix`
  *do* — leftover positional args become the notmuch `QUERY` (`if [ "$#" -gt 0 ]; then QUERY="$*";
  fi`). A blanket "reject any positional arg" rule (option b, applied uniformly) would break the
  documented `[QUERY]` feature of those two binaries.
- **Recommended minimal fix** (below): in `mkPreamble`'s loop, add a case arm that matches the
  literal enum tokens `gmail`/`logos` specifically. If `--account` was not already given
  explicitly, treat the bare token as `--account <token>` **and log a visible NOTE** (never
  silent); if `--account` was already given explicitly, push the token through to `ARGS[]`
  unchanged (preserves `classify`/`unsubscribe-extract`'s query-term use case). This is a ~10-line
  change to the single shared `mkPreamble` function; both mutation binaries inherit it via
  `mkMutationPreamble` (which calls `mkPreamble` first), and its own separate arg loop is
  unaffected since `mkPreamble`'s loop runs first and fully resolves `ACCOUNT` before
  `mkMutationPreamble`'s loop ever sees `"$@"`.

## Context & Scope

Task 827 diagnosed the account-selection bug live: running `email-census logos` actually
censused the `gmail` account because the positional `logos` token was discarded and `ACCOUNT`
stayed at its hardcoded default. This task is the scoped follow-up to fix that in `lib.nix`
without reopening 827's own frozen-preamble concerns (827 explicitly deferred touching the
argument parser to preserve scope discipline).

Constraints from the task description:
- Change is scoped to the shared `mkPreamble` getopts loop in `lib.nix` (all five wrapper
  binaries inherit it).
- Prefer failing loudly over silently defaulting, "especially for the mutating wrappers
  (archive/delete)".
- Cross-repo: the fix lands in `~/.dotfiles`; a `home-manager switch` (user-run) is required to
  deploy it. This session must not run `home-manager switch` or commit/push in `~/.dotfiles`.

## Findings

### Codebase Patterns

**`mkPreamble`'s current arg-parsing loop** (`~/.dotfiles/modules/home/email/agent-tools/lib.nix`,
lines 80-91, reproduced with the `''` nix-escaping stripped for readability):

```sh
ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --account) ACCOUNT="${2:-}"; shift 2 ;;
    --account=*) ACCOUNT="${1#--account=}"; shift ;;
    --manifest-dir) MANIFEST_DIR="${2:-}"; shift 2 ;;
    --manifest-dir=*) MANIFEST_DIR="${1#--manifest-dir=}"; shift ;;
    --help|-h) print_help; exit 0 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]}"
```

`ACCOUNT="gmail"` is set unconditionally at line 60, before this loop runs, and nothing in the
loop's catch-all `*)` arm ever assigns to `ACCOUNT`. The `log()` helper (line 63, `echo
"[$BINARY_NAME] $*" >&2`) is defined and available for use inside this loop — it is used
extensively later in the preamble and in `mkMutationPreamble`.

**How `mkMutationPreamble` composes with this** (lines 123-133): `mkMutationPreamble` calls
`mkPreamble { ...; safetyClass = "mutation"; }` first, then appends its own arg loop (lines
139-150) that processes `--execute`/`--confirm-manifest`/`--manifest` from whatever `"$@"`
`mkPreamble`'s loop left behind. This means a fix inside `mkPreamble`'s loop resolves `ACCOUNT`
*before* `email-archive-confirmed`/`email-delete-confirmed`'s own mutation-flag loop ever runs —
no double-handling or ordering hazard.

**Which binaries actually consume leftover positional args downstream** (this is the key
constraint on the fix's shape):

| Binary | File | Uses `mkPreamble`/`mkMutationPreamble` | Consumes leftover positional args? |
|---|---|---|---|
| `email-census` | `census.nix` | `mkPreamble` | No — script body never references `"$@"` |
| `email-classify` | `classify.nix` | `mkPreamble` | **Yes** — `classify.nix:56-58`: `if [ "$#" -gt 0 ]; then QUERY="$*"; fi` (documented `[QUERY]` flag in its `extraHelp`) |
| `email-unsubscribe-extract` | `unsubscribe-extract.nix` | `mkPreamble` | **Yes** — same pattern, `unsubscribe-extract.nix:41-43` |
| `email-archive-confirmed` | `archive-confirmed.nix` | `mkMutationPreamble` | No — script body never references `"$@"` |
| `email-delete-confirmed` | `delete-confirmed.nix` | `mkMutationPreamble` | No — only strips `--expunge-trash` via its own `for a in "$@"` loop; no positional-arg use |
| `email-reindex` (NOT one of the five) | `mbsync.nix:343-377` | Neither — standalone script, no `mkPreamble` call at all | N/A — takes no `--account`, is account-agnostic |

This asymmetry is why a uniform "reject/error on any leftover positional arg" rule (task's option
b, applied blindly across all five) is unsafe: it would break `email-classify`'s and
`email-unsubscribe-extract`'s documented `[QUERY]` positional argument. Any fix must either be
scoped to the two enum values (`gmail`/`logos`) specifically, or be applied per-binary rather than
in the shared preamble.

### External Resources

No external research was needed — this is a self-contained shell-argument-parsing fix inside a
single already-read Nix file, and the fix pattern (getopts loop with an enum-aware positional
case arm) is standard POSIX-shell practice, not something requiring external documentation.

### Recommendations

**Recommended fix** — add a case arm to `mkPreamble`'s loop (lib.nix lines 80-91) that recognizes
the two literal account-enum tokens as a positional alias for `--account`, but only when
`--account` was not already given explicitly, and always logs the interpretation (never silent):

```sh
ACCOUNT_EXPLICIT=0
ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --account) ACCOUNT="${2:-}"; ACCOUNT_EXPLICIT=1; shift 2 ;;
    --account=*) ACCOUNT="${1#--account=}"; ACCOUNT_EXPLICIT=1; shift ;;
    --manifest-dir) MANIFEST_DIR="${2:-}"; shift 2 ;;
    --manifest-dir=*) MANIFEST_DIR="${1#--manifest-dir=}"; shift ;;
    --help|-h) print_help; exit 0 ;;
    gmail|logos)
      if [ "$ACCOUNT_EXPLICIT" -eq 1 ]; then
        # --account already given explicitly; treat this token as an ordinary
        # positional arg (e.g. email-classify/email-unsubscribe-extract's [QUERY]).
        ARGS+=("$1")
      else
        log "NOTE: interpreting bare positional '$1' as '--account $1' (pass --account explicitly to silence this note)"
        ACCOUNT="$1"
        ACCOUNT_EXPLICIT=1
      fi
      shift
      ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]}"
```

(In the actual `lib.nix` source, `${2:-}`/`${1#--account=}` etc. need the `''${...}` nix-escaping
already used throughout the file; the new `gmail|logos)` arm and the `log "NOTE: ..." '$1' ...`
line contain no `${...}` braces, so — consistent with how bare `$1`/`$ACCOUNT` are already
written unescaped elsewhere in this file (e.g. `case "$1" in` on the existing line 82) — they
need no additional nix-level escaping.)

**Why this shape, addressing the task's two options directly**:
- This is a hybrid of the task's option (a) and (b): it *aliases* the bare token (a), but does so
  **loudly** via `log()` to stderr — satisfying "prefer failing loudly over silent wrong-account
  operation" without actually failing (hard-erroring) on a case that is, in 3 of 5 binaries
  (census, archive-confirmed, delete-confirmed), unambiguously a fixed bug, and in the other 2
  (classify, unsubscribe-extract), an edge case so narrow — a bare notmuch query consisting only
  of the literal word "gmail" or "logos" — that resolving it in favor of the account switch is the
  right default for an agent-facing wrapper whose whole raison d'être (per task 827) is the account
  switch.
- Scoping the new case arm to the *literal enum values* (`gmail|logos`) rather than "any bare
  positional token" is what keeps `classify.nix`/`unsubscribe-extract.nix`'s `[QUERY]` feature
  intact: any other positional token (a real notmuch query term) still falls through to the
  existing catch-all `*)` arm unchanged.
- Gating the alias on `ACCOUNT_EXPLICIT` (only apply if `--account` wasn't already passed) means
  a user who explicitly writes `--account gmail logos` (i.e., really did mean to search/query for
  the literal word "logos" while operating on gmail) still gets `logos` passed through as a
  positional arg, not silently reinterpreted as an account override.
- For the two mutation binaries (archive/delete), this uniformly makes the previously-silent
  wrong-account failure mode impossible: since they never used leftover positional args for
  anything, the fix is strictly a safety improvement there with zero behavioral tradeoff — a call
  like `email-archive-confirmed logos --execute --confirm-manifest <sha>` now correctly resolves
  to the Logos account (and logs that it did so) instead of silently mutating gmail.

**Alternative considered and rejected**: A pure "hard error on any unrecognized positional arg"
approach (task's option b, taken literally and applied uniformly in `mkPreamble`) was rejected
because it cannot be applied safely inside the *shared* `mkPreamble` function without breaking
`classify`/`unsubscribe-extract`'s legitimate `[QUERY]` usage — `mkPreamble` has no way to know,
at the point its own loop runs, whether the binary being built will consume `"$@"` afterward.
Making it per-binary (adding a trailing `if [ "$#" -gt 0 ]; then log ERROR ...; exit 1; fi` guard
only to `census.nix`, `archive-confirmed.nix`, `delete-confirmed.nix`) is possible but is no
longer "a small change to the mkPreamble ... loop" as scoped by the task, touches four files
instead of one, and is redundant once the enum-aware alias above exists (since after the fix,
`gmail`/`logos` are never silently dropped in the first place — the only remaining leftover
positional args in census/archive/delete would be genuinely unrecognized junk, which was already
silently swallowed pre-fix and is out of this task's stated scope).

## Decisions

- Target the fix at `mkPreamble`'s getopts loop only (lib.nix lines 80-91), consistent with the
  task's framing of "a small change to the mkPreamble getopts loop ... all five binaries inherit
  it."
- Do NOT include `email-reindex` in the fix's testing/verification scope — it is a distinct
  script in `mbsync.nix` with no `mkPreamble` dependency and no `--account` flag at all. The
  planner should update the task's binary list to `email-census`, `email-classify`,
  `email-unsubscribe-extract`, `email-archive-confirmed`, `email-delete-confirmed` for
  verification purposes.
- Adopt the hybrid alias-with-log approach over a strict hard-reject, because a uniform hard
  reject is not safely expressible inside the shared preamble (see Recommendations above).
- Gate the alias on both (a) exact match against the enum (`gmail`/`logos` only) and (b)
  `--account` not already explicit, to avoid breaking `classify`/`unsubscribe-extract`'s
  documented `[QUERY]` behavior for the pathological literal-query-term case.

## Risks & Mitigations

- **Risk**: `classify`/`unsubscribe-extract` users who genuinely want a notmuch query consisting
  solely of the literal word "gmail" or "logos" (with no other query terms and no `--account`
  flag) will have that term silently reinterpreted as an account selector instead.
  **Mitigation**: this is an extremely narrow edge case for an agent-facing email-triage tool;
  the fix's `log()` NOTE makes the reinterpretation visible in output, and users who need the
  literal query can pass `--account <acct> <query>` explicitly (falls into the `ACCOUNT_EXPLICIT`
  branch, preserved as a positional pass-through) or phrase the query with an additional term
  (e.g. `body:logos`).
- **Risk**: Nix string-escaping mistakes in the diff (unescaped `${...}` would trigger a Nix
  antiquotation error at build time rather than a shell error). **Mitigation**: the new code
  introduces no `${...}`-braced references — only bare `$1`/`$ACCOUNT_EXPLICIT`, matching the
  existing unescaped style already used for `case "$1" in` and other brace-free variable
  references in this same file — so no new nix-escaping is required; `nix flake check` (or
  simply building/evaluating the home-manager config) should be used to verify syntax before
  the user runs `home-manager switch`.
- **Risk (out of scope but noted)**: `mkMutationPreamble`'s own separate arg loop (lib.nix lines
  139-150) has the identical "no positional-arg case arm" shape and silently swallows any
  positional junk into `MUT_ARGS[]` too — but since neither `archive-confirmed.nix` nor
  `delete-confirmed.nix` consumes leftover positional args after that loop either, this is
  currently harmless (dead weight, not a wrong-account risk) and is not part of this task's
  scoped fix. Flagging for awareness only.

## Context Extension Recommendations

None. This is a narrowly-scoped cross-repo bugfix in a personal dotfiles module; no
`.claude/context/` documentation gap was identified. (The email extension's
`wrapper-contracts.md` in this repo already documents the `--account` contract per task 827's
Finding 5 write-up; no update to that doc is required by this fix since the documented `--account
<gmail|logos>` interface itself is unchanged — only its accidental-positional-arg failure mode is
fixed.)

## Appendix

### Search queries / commands used

```bash
# Confirm the five wrapper-binary files under agent-tools/
ls ~/.dotfiles/modules/home/email/agent-tools/

# Read the shared preamble and each per-binary script in full
# (lib.nix, census.nix, classify.nix, archive-confirmed.nix, delete-confirmed.nix,
#  unsubscribe-extract.nix, default.nix)

# Locate email-reindex (not found among agent-tools/*.nix; found in a different file)
grep -rl "email-reindex" ~/.dotfiles/ --include="*.nix"
grep -n "email-reindex\|writeShellScriptBin\|mkPreamble" ~/.dotfiles/modules/home/email/mbsync.nix

# Cross-reference task 827's own diagnosis of this exact bug
grep -rn "email-census logos\|silently\|positional" specs/827_email_staleness_detector_redesign/
```

### Files read

- `~/.dotfiles/modules/home/email/agent-tools/lib.nix` (full file, 339 lines)
- `~/.dotfiles/modules/home/email/agent-tools/census.nix` (full file)
- `~/.dotfiles/modules/home/email/agent-tools/classify.nix` (full file)
- `~/.dotfiles/modules/home/email/agent-tools/archive-confirmed.nix` (full file)
- `~/.dotfiles/modules/home/email/agent-tools/delete-confirmed.nix` (full file)
- `~/.dotfiles/modules/home/email/agent-tools/unsubscribe-extract.nix` (full file)
- `~/.dotfiles/modules/home/email/agent-tools/default.nix` (full file)
- `~/.dotfiles/modules/home/email/mbsync.nix` (lines 340-379, the `email-reindex` definition)
- `specs/827_email_staleness_detector_redesign/reports/01_staleness-detector-redesign.md`
  (Finding 5, lines 179-210, 358-360)
- `specs/827_email_staleness_detector_redesign/.orchestrator-handoff.json` (follow-up item text)
- `specs/827_email_staleness_detector_redesign/summaries/01_staleness-detector-redesign-summary.md`
  (§2, lines 112-121)

### No cross-repo mutating actions taken

Per task instructions, no edits were made to any file in `~/.dotfiles`, and no `home-manager
switch`, `nix flake check`, `git commit`, or `git push` was run in `~/.dotfiles`. All reads above
were read-only. This report contains the recommended diff as text/inspection only; applying it is
the implementation phase's job.
