# Implementation Plan: Task #827

- **Task**: 827 - Redesign the /email staleness detector — stop equating maildir files with deduped messages
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: 826 (completed — Logos maildir reclone + full sync)
- **Research Inputs**: reports/01_staleness-detector-redesign.md
- **Artifacts**: plans/01_staleness-detector-redesign.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `email-census` freshness gate compares himalaya's on-disk maildir FILE count against
`notmuch count folder:X` (a deduped-MESSAGE count) with strict equality. This is an
apples-to-oranges test that is structurally unreachable for the Logos account (on-disk=341 vs
notmuch-messages=318, permanently `[STALE]` even after a clean reclone + fresh reindex) and only
passes for Gmail by coincidence (128==128, zero Message-ID duplicates today). Per the research
report the fix is the combination (a)+(b)+(c): (a) compare file-vs-file using a **path-prefix
post-filtered** `notmuch --output=files` count for the exact maildir path; (b) replace strict
equality with a bounded tolerance so a small irreducible residual does not perpetually block
`--all`; (c) add a `email-reindex`-ran marker as a robust secondary signal (critical for
autonomous mode). The new semantics are defined once in the authoritative design doc
(Phase 1) and then propagated to code (census.nix / mbsync.nix), the frozen-fact restatement
(wrapper-contracts.md §13), the gate logic (skill-email-cleanup SKILL.md), and lower-stakes
docs. Definition of done: both Gmail and Logos reach `[ok]` on the current mailbox under the new
gate, every enumerated doc/code site is consistent, and the two independent anomalies (the 22
unindexed Logos files, the `--account` positional-arg bug) are handed off as separate follow-up
tasks rather than solved here.

### Research Integration

Key findings integrated from `reports/01_staleness-detector-redesign.md`:
- **Finding 1** — Both accounts' INBOX is the maildir root (`{cur,new}` directly under `Gmail/` /
  `Logos/`); `folder:$ACCOUNT_FOLDER` (bare) is already the correct folder query. The defect is the
  *kind of count* on the notmuch side, not which folder is queried.
- **Finding 2** — A naive option (a) using `notmuch count --output=files folder:X` is *actively
  wrong*: `--output=files` returns every known file for each matching message, including duplicate
  copies in other folders and even other accounts (verified: `folder:Gmail --output=files`=238 vs
  128 real files; `folder:Logos --output=files`=403, 84 of them outside `Logos/{cur,new}`). Option
  (a) MUST post-filter the file list by literal path prefix.
- **Finding 3** — After correct file-vs-file counting, Logos still shows a 22-file residual gap:
  22 files notmuch has NEVER indexed (id: lookup returns zero; two sanctioned `email-reindex` runs,
  including one after forcing the directory mtime forward, did not index them). This is an
  independent bug, NOT staleness — it makes tolerance (b) load-bearing and is handed off as a
  separate follow-up task.
- **Finding 4** — Ten doc/code sites encode the current semantics; each is assigned to a phase
  below.
- **Finding 5** — `email-census` (and all five wrappers) silently discard a positional account arg;
  only `--account <val>` works. Deferred to a separate task (see Phase 7) to preserve scope
  discipline around the frozen `lib.nix` preamble.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (meta task; roadmap flag not set).

## Goals & Non-Goals

**Goals**:
- Replace the unreachable strict-equality freshness gate with a reachable, internally-consistent
  file-vs-file comparison plus a bounded tolerance and a reindex-ran marker.
- Define the new freshness-line semantics exactly once (authoritative doc), then propagate them
  consistently to all ten enumerated doc/code sites.
- Make `[ok]` reachable for BOTH Gmail and Logos on the current mailbox, verified live.
- Specify the exact `census.nix` (and `mbsync.nix` marker) edits concretely, flagged as cross-repo
  edits the user applies and rebuilds.

**Non-Goals**:
- Root-causing the 22 unindexed Logos files (handed off as a separate follow-up task).
- Fixing the `--account` positional-argument bug in the shared frozen `lib.nix` preamble (handed
  off as a separate follow-up task).
- Running `nixos-rebuild` / `home-manager switch`, or committing/pushing in `~/.dotfiles`.
- Changing which notmuch folder is queried (Finding 1 confirmed `folder:$ACCOUNT_FOLDER` is
  correct).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Tolerance chosen too generously masks genuine future staleness | M | M | Use a modest ratio (10% of on-disk) with a small absolute floor, and pair with the (c) reindex marker so "reindex never run" stays distinct from "reindex ran, residual within tolerance". Document the exact threshold and its rationale in Phase 1. |
| Line-format drift between census.nix and the docs re-breaks the gate parser | H | M | Phase 1 fixes the canonical line format string once; Phases 2-4 quote it verbatim. Phase 6 verifies the SKILL.md parser matches the emitted line. |
| `notmuch search --output=files \| grep -c` is heavier than `notmuch count` | L | L | Read-only, once-per-`email-census` cost on a path already doing several notmuch calls; acceptable per report Risk section. |
| Cross-repo census.nix edit is written but not rebuilt, so live behavior lags the docs | M | H | Phase 2 writes the file content only and explicitly stops; Phase 6 verifies the *logic* live via a standalone snippet (no rebuild needed) and flags the post-`home-manager switch` re-verification as a user step. |
| Logos residual grows past tolerance later, re-blocking `--all` | M | L | (c) marker + the spawned follow-up task (Phase 7) to reduce the residual at the source; threshold can be tightened once the anomaly is fixed. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6 | 2, 3, 4, 5 |
| 4 | 7 | 6 |

Phases within the same wave can execute in parallel (territory-disjoint: Phase 2 touches
`~/.dotfiles`, Phase 3 touches wrapper-contracts.md, Phase 4 touches SKILL.md, Phase 5 touches the
lower-stakes docs).

---

### Phase 1: Define the new freshness-line semantics (authoritative doc) [COMPLETED]

**Goal**: Fix the new gate's semantics — the exact comparison, the tolerance rule, the reindex
marker, and the canonical freshness-line format — once, in the authoritative design doc, so every
downstream site propagates from a single source of truth.

**Tasks**:
- [x] Rewrite the "Ground truth vs. index" section of
      `.claude/extensions/email/context/project/email/domain/staleness-detection.md` to state the
      file-vs-file model: on-disk file count (himalaya) vs a **path-prefix post-filtered**
      `notmuch --output=files` count for the exact maildir path — replacing the deduped
      `notmuch count folder:X` message count. *(completed)*
- [x] Add a subsection documenting the `notmuch(1)` `--output=files` cross-folder/cross-account
      duplicate-inclusion quirk (Finding 2), with the man-page quote and the verified numbers
      (`folder:Gmail --output=files`=238 vs 128; `folder:Logos`=403 with 84 outside
      `Logos/{cur,new}`), so future maintainers do not reintroduce a naive query. *(completed)*
- [x] Define the **tolerance rule (b)** precisely: divergence `Δ = |on-disk − indexed-files|`;
      tolerance `T = max(5, ceil(0.10 × on-disk))`; `[ok]` when `Δ ≤ T`, else `[STALE]`. Document
      that 10% is chosen deliberately to make Logos (residual 22/341 ≈ 6.5%) reachable today while
      staying modest, and that the threshold should be tightened once the Phase-7 follow-up reduces
      the residual. *(completed)*
- [x] Define the **reindex marker (c)**: `email-reindex` writes an ISO-8601 timestamp to
      `${XDG_STATE_HOME:-$HOME/.local/state}/email-agent/last-reindex`; `email-census` reads it and
      surfaces `reindex=<ISO|never>` on the freshness line. State that the marker is a complementary
      *informational* signal (it does not itself flip `[ok]`/`[STALE]`) that the Stage 1 gate uses
      to distinguish "reindex never attempted" from "reindex ran, residual within tolerance",
      especially in autonomous mode. *(completed)*
- [x] Fix the **canonical freshness-line format string** (quoted verbatim by all downstream sites):
      `INBOX freshness  on-disk=<D>  indexed-files=<F>  divergence=<Δ>  tol=<T>  reindex=<ISO|never>  [ok|STALE]`.
      *(completed)*
- [x] Update the end-to-end flow diagram and the live-example numbers in the doc to reflect the new
      gate (both accounts reaching `[ok]` under tolerance). *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/email/context/project/email/domain/staleness-detection.md` — ground-truth
  table, new comparison + tolerance + marker semantics, canonical line format, flow diagram.

**Verification**:
- The doc contains the exact tolerance formula and the exact canonical line-format string.
- The `--output=files` quirk is documented with the man-page quote and verified numbers.
- No remaining claim that `[ok]` requires `on-disk == notmuch-indexed`.

---

### Phase 2: Implement the freshness line in census.nix + reindex marker in mbsync.nix (cross-repo) [COMPLETED]

**Goal**: Implement the Phase-1 semantics in the authoritative code in `~/.dotfiles`.

**CROSS-REPO NOTICE**: These files live in `~/.dotfiles` (a SEPARATE repository). The
implementation agent MAY write the edited file content into the `.dotfiles` paths if safe, but MUST
NOT run `nixos-rebuild` / `home-manager switch`, and MUST NOT commit or push in `~/.dotfiles`. The
user applies and rebuilds. If writing into `~/.dotfiles` is not safe/desired, the agent instead
records the exact edited content in the implementation summary for the user to apply.

**Tasks**:
- [x] Replace the freshness block in
      `~/.dotfiles/modules/home/email/agent-tools/census.nix` (lines ~40-49) with the new logic
      below. Preserve Nix string-interpolation escaping (`''${...}`). *(completed)*
- [x] Add the reindex-marker write to the `email-reindex` definition in
      `~/.dotfiles/modules/home/email/mbsync.nix` (Finding 4 site #2): after the `notmuch new
      --no-hooks` call, write the timestamp marker. *(completed)*
- [x] Cross-check `email-freeze`/`email-thaw` operator-facing messages in `mbsync.nix` for any
      wording that references the old freshness semantics; update for consistency if present.
      *(completed: no freeze/thaw wording referenced the old on-disk==notmuch-indexed semantics;
      verified via grep, no changes needed there)*

Concrete census.nix freshness block (implements (a) post-filter, (b) tolerance, (c) marker read):

```sh
echo "--- Index freshness: INBOX on-disk (himalaya) vs notmuch-indexed FILES (task 827) ---"
echo "(divergence beyond tolerance => notmuch index is stale for INBOX; reconcile with"
echo " 'email-reindex' before a coverage-promising --all sweep.)"
# (a) file-vs-file. notmuch(1): --output=files returns EVERY known file for a matching message,
# incl. duplicates in other folders/accounts, so post-filter to the exact maildir path prefix.
INBOX_ONDISK=$(himalaya envelope list "''${HIMALAYA_ACCT[@]}" -f INBOX -o json -s 100000 2>/dev/null \
  | jq 'length' 2>/dev/null)
INBOX_ONDISK="''${INBOX_ONDISK:-?}"
INBOX_INDEXED=$(notmuch search --output=files \
    "path:$ACCOUNT_FOLDER/cur or path:$ACCOUNT_FOLDER/new" 2>/dev/null \
  | grep -cE "/$ACCOUNT_FOLDER/(cur|new)/" || echo 0)
# (b) bounded tolerance instead of strict equality (see staleness-detection.md rationale).
if printf '%s' "$INBOX_ONDISK" | grep -qE '^[0-9]+$'; then
  DIVERGENCE=$(( INBOX_ONDISK - INBOX_INDEXED ))
  AD=''${DIVERGENCE#-}                              # absolute value
  PCT_TOL=$(( (INBOX_ONDISK * 10 + 99) / 100 ))     # ceil(10% * on-disk)
  TOL=$(( PCT_TOL > 5 ? PCT_TOL : 5 ))              # floor of 5
  if [ "$AD" -le "$TOL" ]; then FRESH="ok"; else FRESH="STALE"; fi
else
  DIVERGENCE="?"; TOL="?"; FRESH="STALE"
fi
# (c) reindex-run marker (informational secondary signal).
REINDEX_MARKER="''${XDG_STATE_HOME:-$HOME/.local/state}/email-agent/last-reindex"
if [ -r "$REINDEX_MARKER" ]; then REINDEX_AT=$(cat "$REINDEX_MARKER" 2>/dev/null); else REINDEX_AT="never"; fi
printf "%-16s on-disk=%s  indexed-files=%s  divergence=%s  tol=%s  reindex=%s  [%s]\n" \
  "INBOX freshness" "$INBOX_ONDISK" "$INBOX_INDEXED" "$DIVERGENCE" "$TOL" "$REINDEX_AT" "$FRESH"
```

Concrete mbsync.nix marker write (append to the `email-reindex` body, after `notmuch new --no-hooks`):

```sh
mkdir -p "''${XDG_STATE_HOME:-$HOME/.local/state}/email-agent"
date -Iseconds > "''${XDG_STATE_HOME:-$HOME/.local/state}/email-agent/last-reindex"
```

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `~/.dotfiles/modules/home/email/agent-tools/census.nix` — freshness block (cross-repo).
- `~/.dotfiles/modules/home/email/mbsync.nix` — `email-reindex` marker write (cross-repo).

**Verification**:
- The emitted `printf` format string matches the Phase-1 canonical line format verbatim.
- Nix interpolation escaping (`''${...}`) is preserved; no unescaped `${...}` that Nix would try to
  interpolate.
- `nix flake check` / build is NOT run by the agent (user responsibility); the agent notes this in
  the summary.

---

### Phase 3: Propagate to wrapper-contracts.md §13 (frozen-fact restatement) [NOT STARTED]

**Goal**: Update the terse frozen-fact restatement of the gate so it does not drift from
staleness-detection.md.

**Tasks**:
- [ ] Update §13 "Freshness disclosure" in
      `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` to state the
      new file-vs-file comparison, the tolerance rule, the reindex marker, and the new canonical
      line format.
- [ ] Replace the stale "`on-disk == notmuch-indexed`" pass condition with the `Δ ≤ T` tolerance
      condition.
- [ ] Keep the `email-reindex` sanctioned-non-wrapper description intact; add the one-line note
      that `email-reindex` now also writes the reindex marker read by `email-census`.

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` (§13).

**Verification**:
- §13 quotes the same canonical line format as Phase 1.
- No remaining `on-disk == notmuch-indexed` equality claim in §13.

---

### Phase 4: Update the Stage 1 gate + Staleness Remediation in SKILL.md [NOT STARTED]

**Goal**: Update the `--all` mandatory gate logic and remediation flow to parse the new line and
apply the new pass/fail condition, including reindex-marker handling and autonomous-mode behavior.

**Tasks**:
- [ ] Update the Stage 1 "Census + Staleness Gate" section (~lines 304-323) of
      `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md`: parse the new
      `INBOX freshness … on-disk=<D> indexed-files=<F> divergence=<Δ> tol=<T> reindex=<…> [ok|STALE]`
      line; define `[ok]` as `Δ ≤ T` (file-vs-file within tolerance), not exact equality.
- [ ] Describe how the `reindex=<ISO|never>` marker is surfaced and used: it is informational and
      does not flip the gate, but in autonomous/orchestrator mode "reindex=never AND `[STALE]`"
      routes to STOP-with-`email-reindex`-command, whereas "reindex ran recently AND `[STALE]`"
      is reported as a persistent residual (candidate follow-up), distinguishing "never attempted"
      from "attempted, gap persists".
- [ ] Update the "Staleness Remediation" section (~lines 608-640) to match: the reindex still runs
      via `email-reindex`, but the re-check now uses the tolerance condition, and the marker makes
      "reindex ran, residual within tolerance" a first-class `[ok]` outcome.
- [ ] Keep the "line absent (older email-census)" unverified-coverage fallback wording.

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` (Stage 1 gate + Staleness
  Remediation).

**Verification**:
- The parsed field names in SKILL.md exactly match the fields emitted by the Phase-2 `printf`.
- The gate's `[ok]` condition is the tolerance rule, not equality.
- Autonomous-mode behavior for the reindex marker is described.

---

### Phase 5: Propagate to lower-stakes doc sites [NOT STARTED]

**Goal**: Keep the remaining enumerated sites (Finding 4 sites #5, #7, #8, #9, #10) accurate for
context-discovery relevance and user-facing description, and re-verify #5.

**Tasks**:
- [ ] `.claude/extensions/email/EXTENSION.md` — update the "on-disk vs notmuch-indexed" summary
      blurb to the file-vs-file + tolerance wording.
- [ ] `.claude/extensions/email/README.md` — update the `[ok|STALE]` line-format description and
      reconciliation flow.
- [ ] `.claude/extensions/email/commands/email.md` — update the Stage 1 gate behavior description
      (interactive + autonomous).
- [ ] `.claude/extensions/email/index-entries.json` — update any "on-disk vs indexed"
      descriptions/summaries so context-discovery matching stays accurate.
- [ ] `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md` — re-verify the
      Stage 1 gate reference; update wording only if it asserts the old equality semantics.

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/email/EXTENSION.md`
- `.claude/extensions/email/README.md`
- `.claude/extensions/email/commands/email.md`
- `.claude/extensions/email/index-entries.json`
- `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md` (verify; edit only
  if needed)

**Verification**:
- `grep -rn "on-disk\|notmuch-indexed\|\[STALE\]" .claude/extensions/email/` shows no site still
  asserting strict `on-disk == notmuch-indexed` equality as the pass condition.

---

### Phase 6: Verify the new gate reaches [ok] for both accounts (live) [NOT STARTED]

**Goal**: Prove the redesigned gate is reachable for BOTH Gmail and Logos on the current mailbox,
without requiring a `home-manager` rebuild.

**Tasks**:
- [ ] Run the standalone verification snippet below (read-only; replicates the Phase-2 census.nix
      logic) against the live mailbox for both accounts and capture the output.
- [ ] Confirm Gmail lands `[ok]` (expected `on-disk=128 indexed-files=128 divergence=0`) and Logos
      lands `[ok]` (expected `on-disk=341 indexed-files≈319 divergence≈22 tol≈35`).
- [ ] Confirm the SKILL.md gate parser (Phase 4) reads the exact field names the snippet emits.
- [ ] Record in the summary that the DEPLOYED census.nix result must be re-verified by the user
      after `home-manager switch`, and that the reindex marker path is created on the next
      `email-reindex` run.

Standalone verification snippet (read-only, no rebuild needed):

```sh
for acct in Gmail Logos; do
  a=$(printf '%s' "$acct" | tr '[:upper:]' '[:lower:]')
  OND=$(himalaya envelope list -a "$a" -f INBOX -o json -s 100000 2>/dev/null | jq length)
  IDX=$(notmuch search --output=files "path:$acct/cur or path:$acct/new" 2>/dev/null \
    | grep -cE "/$acct/(cur|new)/")
  D=$(( OND - IDX )); AD=${D#-}
  P=$(( (OND*10+99)/100 )); TOL=$(( P > 5 ? P : 5 ))
  [ "$AD" -le "$TOL" ] && S=ok || S=STALE
  printf '%-6s on-disk=%s indexed-files=%s divergence=%s tol=%s [%s]\n' "$acct" "$OND" "$IDX" "$D" "$TOL" "$S"
done
```

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4, 5

**Files to modify**: none (verification only).

**Verification**:
- Snippet output shows `[ok]` for both `Gmail` and `Logos`.
- Logos divergence is within tolerance (`Δ ≈ 22 ≤ T ≈ 35`).

---

### Phase 7: Hand off the two independent anomalies as follow-up tasks [NOT STARTED]

**Goal**: Record and recommend the two out-of-scope items as separate tasks, preserving this
task's scope discipline.

**Tasks**:
- [ ] Recommend spawning a follow-up task for the **22 unindexed Logos files** anomaly
      (Finding 3), including the diagnostic dead-ends already ruled out (id: lookup returns zero;
      two `email-reindex` runs including one after forcing `Logos/cur` mtime forward, both no-op;
      `new.ignore` patterns and hardlink/inode dedup ruled out; files mtime 2026-07-06 coincide
      with the task-826/828 reclone + UID-collision repair) so a future investigator does not
      repeat them. Suggested via `/spawn 827` or `/task`.
- [ ] Recommend spawning a follow-up task for the **`--account` positional-argument bug**
      (Finding 5) in the shared `~/.dotfiles/.../lib.nix` `mkPreamble` arg-parsing loop, noting it
      affects all five wrapper binaries plus `email-census` and touches the frozen preamble — hence
      deliberately deferred from this task.
- [ ] State the deferral decisions explicitly in the implementation summary.

**Timing**: 0.25 hours

**Depends on**: 6

**Files to modify**: none (recommendations recorded in the summary; task creation is a follow-up
action).

**Verification**:
- The summary lists both follow-up recommendations with enough diagnostic context to act on them.

## Testing & Validation

- [ ] Phase 6 snippet shows `[ok]` for BOTH Gmail and Logos on the current mailbox.
- [ ] The canonical freshness-line format string is identical across staleness-detection.md,
      census.nix (`printf`), wrapper-contracts.md §13, and the SKILL.md parser.
- [ ] `grep -rn "on-disk == notmuch-indexed\|D == I\|on-disk=%s  notmuch-indexed" .claude/extensions/email/`
      returns no residual strict-equality gate assertion.
- [ ] The `--output=files` post-filter (path-prefix grep) is present in the census.nix logic, not a
      raw `notmuch count --output=files folder:X`.
- [ ] SKILL.md Stage 1 parses the emitted field names verbatim; `[ok]` is the tolerance condition.
- [ ] Cross-repo guardrail respected: no `home-manager switch` / `nixos-rebuild` run, no commit or
      push in `~/.dotfiles`.

## Artifacts & Outputs

- `specs/827_email_staleness_detector_redesign/plans/01_staleness-detector-redesign.md` (this file)
- `specs/827_email_staleness_detector_redesign/summaries/01_staleness-detector-redesign-summary.md`
  (on completion)
- Edited in-repo docs: staleness-detection.md, wrapper-contracts.md, skill-email-cleanup/SKILL.md,
  EXTENSION.md, README.md, commands/email.md, index-entries.json, archive-mode-risk.md (if needed)
- Edited cross-repo (written, not built): `~/.dotfiles/.../census.nix`, `~/.dotfiles/.../mbsync.nix`
- Two follow-up task recommendations (22-unindexed-files anomaly; `--account` positional-arg bug)

## Rollback/Contingency

- In-repo doc/skill edits are plain Markdown/JSON; revert via `git checkout -- <path>` (or `git
  revert` of the task commit). No runtime state is mutated by the doc changes.
- The cross-repo census.nix / mbsync.nix edits take effect only after the user runs `home-manager
  switch`; until then the live gate is unchanged, so there is nothing to roll back on the running
  system if the plan is abandoned mid-flight. If the deployed gate misbehaves, the user reverts the
  `~/.dotfiles` edit and re-runs `home-manager switch`.
- The reindex marker file is additive and disposable; deleting it simply reverts `reindex=` to
  `never`.
