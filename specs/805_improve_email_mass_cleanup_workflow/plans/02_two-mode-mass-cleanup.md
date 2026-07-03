# Implementation Plan: Task #805 — Two-Mode Mass-Cleanup Workflow

- **Task**: 805 - Improve the email/ extension's mass-cleanup workflow (default 50-step, `--all`, `--archive`)
- **Status**: [IMPLEMENTING]
- **Effort**: 14 hours
- **Dependencies**: None (task 803 email extension already authored; frozen `.dotfiles` wrapper contract, task 72)
- **Research Inputs**:
  - reports/02_two-mode-batching-design.md (PRIMARY/AUTHORITATIVE for batching UX)
  - reports/01_team-research.md (broader design decisions)
  - reports/01_teammate-c-findings.md (verified wrapper constraints)
- **Artifacts**: plans/02_two-mode-mass-cleanup.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Extend the existing `/email` command and `skill-email-cleanup` **in place** to add two decision-granularity
modes plus an orthogonal folder-scope flag, without touching the frozen `.dotfiles` wrapper (task 72) and
without introducing any non-wrapper binary. **Default `/email` (no flag)** becomes a bounded, safer
50-at-a-time stepping pass that uses the wrapper's durable `+proposed-*` notmuch tags as a cross-invocation
cursor. **`--all`** performs a whole-mailbox operation: an unconditionally-chunked, backgrounded (read/tag-only)
classify sweep paginated by a captured message-ID-list slice, one consolidated sender/domain bucket
bulk-approval via `AskUserQuestion`, then a transparent sub-50 execute drain over sha256-confirmed split
sub-manifests with progress-only reporting and no per-batch re-prompt. **`--archive`** composes with either
mode by scoping the classify QUERY to `folder:Gmail/.All_Mail`, adding extra-caution gates (second
blast-radius-naming confirmation, `--expunge-trash` opt-in only, asymmetric/corroborated confidence bar,
reversible-then-hard two-phase, never auto-chain `--sync`). Definition of done: all mode branches authored,
the stale in-repo `wrapper-contracts.md` refreshed against ground truth, three new context docs authored and
indexed, README/EXTENSION updated, and a bounded pilot gate installed before `--archive` runs at full scale.
Because the extension has never been loaded into a consuming repo, "testing" is doc-lint plus dry-run
reasoning walkthroughs — never live mailbox mutation.

### Research Integration

- **Report 02 (authoritative)** supersedes report 01 on the default-vs-`--all` split: default = 50-step
  stepping (safer default), `--all` = whole-mailbox bulk decision. It resolves the mtime policy (`touch -r`
  preserve + explicit expiry stop-and-report), the classify-sweep pagination mechanism (captured ID-list
  slice, NOT `+proposed-*` tags, because classify has `--limit` but no offset flag and overwrites its
  candidate manifest per call), the chunk sizing (~1,000 IDs/chunk), the backgrounding boundary (only the
  non-gated read/tag-only sweep may be backgrounded), and the exact All Mail scope token
  (`folder:Gmail/.All_Mail`, confirmed verbatim in `email-census`).
- **Report 01** contributes the manifest-splitting requirement (`enforce_batch_size()` hard-refuses over 50,
  never auto-chunks), the `min()` confidence rollup with 0.90 option-availability gating, the fix-it
  multiSelect/"Select all" idiom, the `--archive` extra gates, the verification-first + doc-refresh mandate,
  the new-context-docs list, and the pilot-before-64k recommendation (F9).
- **Teammate C** provides the verified `agent-tools.nix` line references this plan's Phase 1 must re-confirm.

### Prior Plan Reference

No prior plan (this is round-2 planning off round-2 research; `next_artifact_number` is 3, and the first plan
slot for this task is 02). Round-1 research findings are carried as reference, not templated.

### Roadmap Alignment

No `roadmap_flag` was set for this dispatch and no ROADMAP.md consultation was requested. This task advances
the email extension's trajectory from ad-hoc single-pass triage toward full-mailbox lifecycle management
(the on-trajectory framing from report 01, Teammate D), but no ROADMAP.md items are annotated here.

## Goals & Non-Goals

**Goals**:
- Add a safer default 50-step stepping mode that makes real forward progress across separate `/email`
  invocations via the durable `+proposed-*` tag cursor.
- Add `--all` whole-mailbox mode: chunked backgrounded classify sweep, one consolidated bucket bulk-approval,
  and a transparent sub-50 execute drain — the 50-cap disappears from the user's experience everywhere except
  where the wrapper hard-enforces it (execute), and even there it is a mechanical, progress-only drain.
- Add `--archive` as an orthogonal `folder:Gmail/.All_Mail` scope flag with proportionate extra-caution gates.
- Preserve the original approval mtime on split sub-manifests (`touch -r`) with an explicit expiry
  stop-and-report path (no silent clock reset).
- Refresh the stale in-repo `wrapper-contracts.md`; author `patterns/bulk-bucket-review.md`,
  `patterns/batch-drain-loop.md` (agent-system layer), and `domain/archive-mode-risk.md`; update
  README.md/EXTENSION.md; register new context entries.
- Install a bounded pilot gate before `--archive` runs at full (~64k) scale.

**Non-Goals**:
- No change to the frozen `.dotfiles` wrapper: MAX_BATCH_SIZE stays 50 (split/loop, never raise it), no new
  wrapper flag, no `manifest.json`/`mail-guard.sh`/`settings-fragment.json` change.
- No fork of a new skill — `skill-email-cleanup`/`email.md` are extended in place (no non-wrapper binary is
  introduced, unlike `--sync`).
- No raw `himalaya`/`notmuch`/`msmtp`/`secret-tool` calls anywhere in the design (the captured-ID-list sweep
  is expressed as a design requirement for the wrapper-side classify pagination, not as an agent-issued raw
  notmuch command — see Phase 1 verification and the Risks section on how this is reconciled).
- No live mailbox validation (extension has never been loaded); validation is doc-lint + dry-run reasoning.
- No classifier generalization, durable-rule-writeback feedback loop, or maintenance-mode scheduling — these
  are flagged follow-ons, out of scope.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A Phase-1 assumption is falsified (line ranges/behavior drifted in `agent-tools.nix`) | H | M | Phase 1 is a hard gate: if any of the five behaviors differs, STOP and adapt later phases before authoring them; record the corrected facts in `wrapper-contracts.md` |
| Wrapper-only invariant violated by the ID-list-slice sweep needing raw `notmuch search` | H | M | The captured-ID-list slice is a **classify-side pagination requirement**, satisfied by passing an `id:a or id:b ...` QUERY positional to `email-classify` (a wrapper binary); the skill must NOT itself run raw `notmuch`. Phase 1 verifies whether the wrapper exposes an ID-capture path; if it does not, Phase 4 falls back to `--limit`-based chunking with a documented completeness caveat rather than introducing a raw binary |
| Interactive review gate accidentally placed in a background subagent | H | L | Only the read/tag-only classify sweep may be backgrounded (Phase 4). The bucket-approval `AskUserQuestion` and the whole execute drain run in the root session, direct-execution. Each phase restates this invariant in its verification |
| `enforce_batch_size()` hard-refuses a >50 sub-manifest during the drain | H | L | Phase 5 splits the approved set into ≤50-lines-per-action sub-manifests before any execute call; each split independently passes the per-action cap |
| Interrupted `--all` drain leaves splits that all expire at PLAN_EXPIRY_DAYS=7 simultaneously | M | M | `touch -r` preserves original mtime; on an expired split the drain STOPS and reports the residual, instructing a fresh `--all` re-sweep. No silent re-timestamping |
| Background classify sweep crashes mid-run with a partial accumulator | M | M | Sweep writes a per-chunk progress-log line (chunk index, count, running total); the skill inspects it on resume to know how far it got |
| `--archive` full-scale drain run before any empirical validation | H | M | Phase 9 installs a pilot gate: `--archive` at full scale is refused until a bounded pilot pass has been run and acknowledged |
| Fresh `--all` sweep re-surfaces previously-declined messages | L | M | Deliberate trade-off (favor completeness for "look at everything"); Stage 2.5 labels previously-seen-and-declined buckets (detectable via `+proposed-*`) so the user can distinguish new from residual |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6, 7 | 5 |
| 7 | 8 | 6, 7 |
| 8 | 9 | 8 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Verification-First Ground Truth + wrapper-contracts.md Refresh [COMPLETED]

- **Goal:** Re-confirm the five load-bearing wrapper behaviors against the live `.dotfiles` source before
  any design is committed, then update the stale in-repo contract doc to document them. This phase GATES all
  subsequent phases — if any assumption is falsified, later phases must be adapted before authoring.
- **Tasks:**
  - [x] Re-read `~/.dotfiles/modules/home/email/agent-tools.nix` and confirm each of: *(completed: all five behaviors confirmed)*
    - [x] `enforce_batch_size()` hard-refuses (`exit 1`, "split required") over `MAX_BATCH_SIZE=50` per action, counting all lines for that action in the pointed-at `--manifest` file (~lines 235-243). *(confirmed: lines 236-243; per-action per-file)*
    - [x] `email-classify` uses `--limit` (a cap, `head -n`) with no offset/`--skip`/`--after` flag, and its default QUERY is `folder:Gmail` (~lines 334-344, 428-439). *(confirmed: lines 333-359, 434-439)*
    - [x] `classify_one()` confidence constants (0.98 custom-keep, 0.98/≥0.90 for the ~13-domain `CUSTOM_DELETE_DOMAINS`, 0.60 newsletter, 0.55 notification, 0.50 default-unsure) and the sub-0.90 delete→unsure downgrade (~lines 403-430, 460-466). *(confirmed: lines 396-432, 459-466; CUSTOM_DELETE_DOMAINS has 14 domains, not 13)*
    - [x] The All Mail scope token is the notmuch query `folder:Gmail/.All_Mail`, confirmed verbatim in `email-census`'s hardcoded report (~lines 492-501, cross-check ~299). *(confirmed verbatim at line 299)*
    - [x] `PLAN_EXPIRY_DAYS=7` is enforced against raw file mtime `stat -c %Y` on whatever `--manifest` points at, and `<manifest>.state.jsonl` is derived per-path (~lines 108-146). *(confirmed: lines 34-35, 108-111, 135-142; expunge hop uses separate .expunge-state.jsonl, lines 630-637)*
    - [x] Whether any wrapper path emits/accepts a captured message-ID list (informs the Phase 4 sweep pagination mechanism and the wrapper-only reconciliation in Risks). *(resolved: QUERY positional ACCEPTS id:/date:/tag: queries; NO wrapper EMITS a complete ID list — Phase 4 pre-authorized fallback engaged. Bonus finding: `--limit 0` is a wrapper-only count oracle via the NOTE line)*
  - [x] If any behavior differs from the reports, record the discrepancy and flag the affected downstream phase(s) for adaptation before proceeding. *(completed: no load-bearing falsification; Phase 4 flagged for the plan's own no-ID-capture fallback — QUERY-window + --limit chunking)*
  - [x] Update `context/project/email/domain/wrapper-contracts.md` to document: the hard-refuse-over-cap behavior (§5), mtime-based expiry semantics (§4/§5), classify's own `--limit`/no-offset pagination and candidate-manifest overwrite-per-call, the `QUERY` folder-scope parameter and the `folder:Gmail/.All_Mail` token, and the deterministic-constant nature of the confidence values. *(completed: §5a-c, §7a, §10 pagination contract, §11 folder tokens added; doc-lint email PASS)*
- **Timing:** ~1.5 hours
- **Depends on:** none
- **Files to modify:**
  - `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` — add verified sections closing F13a-e
- **Files to read (ground truth):**
  - `~/.dotfiles/modules/home/email/agent-tools.nix`
- **Verification:**
  - Each of the five behaviors has a confirmed line reference recorded in `wrapper-contracts.md`.
  - Doc-lint (`.claude/scripts/check-extension-docs.sh`) passes for the email extension after the edit.
  - Hard invariants preserved: no wrapper change proposed; the doc explicitly records MAX_BATCH_SIZE=50 as frozen.

---

### Phase 2: Mode Dispatch in email.md (`--all`, `--archive`, composable) [COMPLETED]

- **Goal:** Extend `/email`'s argument parsing to recognize `--all` and `--archive` as composable flags
  producing `mode=default|all` and `scope=inbox|archive`, while preserving the existing `--sync` route and
  free-text focus hint. Argument parsing only — no behavioral logic yet.
- **Tasks:**
  - [x] Add parsing steps: `--all` sets whole-mailbox mode; `--archive` sets `folder:Gmail/.All_Mail` scope; both composable (`/email --all --archive`); `--sync` remains a distinct, earlier-matched route. *(completed: steps 1-3 in argument_parsing; --sync wins on conflict)*
  - [x] Thread `mode` and `scope` into the `skill-email-cleanup` delegation args alongside the existing `focus_hint`. *(completed: args now "mode=..., scope=..., focus_hint=...")*
  - [x] Document the new invocation forms and their safety posture in the command's Input and Safety Notes sections (default = safer 50-step; `--all` = whole-mailbox; `--archive` = extra-caution All Mail scope; never auto-chain `--sync`). *(completed: Input bullets + "Safety posture by invocation form" block)*
  - [x] Follow the `--sync` mode-flag precedent (`skill-email-sync` routing) for flag-matching structure, but route `--all`/`--archive` to the SAME `skill-email-cleanup` (no fork). *(completed)*
- **Timing:** ~1 hour
- **Depends on:** 1
- **Files to modify:**
  - `.claude/extensions/email/commands/email.md` — argument_parsing + workflow_execution + Safety Notes
- **Files to reference:**
  - `.claude/extensions/email/skills/skill-email-sync/SKILL.md` (mode-flag precedent)
- **Verification:**
  - Dry-run reasoning: enumerate `/email`, `/email --all`, `/email --archive`, `/email --all --archive`,
    `/email --sync` and confirm each resolves to the intended (mode, scope, route) without ambiguity.
  - Hard invariants preserved: still routes to `skill-email-cleanup` (no new skill); no wrapper/manifest change.

---

### Phase 3: Default 50-Step Mode in skill-email-cleanup [COMPLETED]

- **Goal:** Refine the existing census→classify→review→execute flow into the explicit `mode=default` branch:
  a bounded ≤50-candidate pass that never needs splitting, and that uses the durable `+proposed-*` tags as the
  cross-invocation forward-progress cursor so repeated `/email` runs step through the mailbox instead of
  re-showing the same newest 50.
- **Tasks:**
  - [x] Introduce an explicit `mode` branch at the top of the skill's Execution Flow; `mode=default` preserves the current 6-stage shape with `--limit 50`. *(completed: Stage 0 Mode and Scope Dispatch)*
  - [x] Specify the cursor rule: once a mailbox has had ≥1 default pass, the classify QUERY excludes already-tagged messages (`<QUERY> and not tag:proposed-delete and not tag:proposed-archive and not tag:proposed-unsure and not tag:proposed-keep`) so each re-run advances by construction (executed messages leave the folder; declined-but-seen messages carry a durable tag). *(completed: Stage 2 cursor rule)*
  - [x] State that default mode never needs classify chunking (input bounded to 50) nor manifest splitting (approved set ≤50 per action by construction, so it can never trip `enforce_batch_size`). *(completed: Default Mode intro)*
  - [x] Keep the mandatory Stage 3 review stop and Stage 6 execution-state diff unchanged. *(completed: unchanged)*
- **Timing:** ~1.5 hours
- **Depends on:** 2
- **Files to modify:**
  - `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` — mode branch + default-mode cursor
- **Verification:**
  - Dry-run reasoning: a second bare `/email` run demonstrably classifies a different 50 than the first
    (cursor advances); no path constructs `--execute` before the AskUserQuestion approval.
  - Hard invariants preserved: wrapper-only; mandatory human review gate intact; root-session direct execution;
    MAX_BATCH_SIZE unchanged; the cursor is expressed as a `email-classify` QUERY argument (wrapper binary),
    not a raw `notmuch tag` query issued by the skill.

---

### Phase 4: `--all` Classify Sweep + Bucket Bulk-Approval Stage [COMPLETED]

- **Goal:** Author the `mode=all` Stage 2 (sweep) and Stage 2.5 (bucket review): an unconditionally-chunked,
  backgrounded read/tag-only classify sweep paginated by a captured message-ID-list slice, accumulating a
  single candidate set, followed by ONE consolidated sender/domain bucket bulk-approval via `AskUserQuestion`.
- **Tasks:**
  - [x] Specify Stage 2 (sweep): capture the in-scope message-ID list ONCE at sweep start; slice into fixed-size chunks (~1,000 IDs/chunk, tunable per Phase 9 pilot); for each chunk build an `id:a or id:b or …` QUERY and invoke `email-classify --limit <chunk-size> "<id-query>"`; immediately copy/append each chunk's candidate manifest into a persistent accumulator BEFORE the next chunk overwrites it. *(deviation: altered — Phase 1 found NO wrapper emits a complete ID list, so per this plan's pre-authorized fallback (Risks row 2, Rollback bullet 3) the sweep paginates by `--limit` + tag-exclusion QUERY for new mail (complete) plus one bounded re-classify pass per prior tag for residual mail (documented completeness caveat, CHUNK_SIZE per tag bucket per run). Accumulate-before-next-chunk requirement kept)*
  - [x] Specify that the sweep runs as a SINGLE backgrounded Bash job (`run_in_background`) that internally loops over all chunks and writes a per-chunk progress-log line (chunk index, message count, running total); the skill starts it once and monitors it. Surface a one-time pre-sweep estimate ("~N messages, ~M chunks, est. Xh — proceeding in background"). *(completed: Stage 2 job spec + Stage 1 estimate via the `--limit 0` count oracle)*
  - [x] State the pagination decision explicitly: pagination is by captured-ID-list slice, NOT by `+proposed-*` tags (classify has no offset flag and its candidate manifest is overwritten per call; reusing tags would silently exclude previously-declined messages from a later `--all` sweep). *(deviation: altered — inverted by ground truth: ID-list capture is not implementable wrapper-only, so tag-based pagination IS the mechanism; the previously-declined exclusion is made non-silent via pre-sweep residual counts, bounded residual re-classify passes, and `[residual]` bucket labeling)*
  - [x] Specify Stage 2.5 (bucket review): group candidates by sender/domain; roll confidence up per bucket with `min()` (one weak match must not license bulk-approving strong ones); the 0.90 delete gate is enforced by WHICH options exist (a sub-0.90 bucket never gets an "approve all as delete" option), not post-hoc filtering; reuse the fix-it multiSelect/"Select all (N items)" idiom for >20 buckets; label buckets previously seen-and-declined (detectable via `+proposed-*`) as residual vs. new. *(completed: Stage 2.5 items 1-6)*
- **Timing:** ~2 hours
- **Depends on:** 3
- **Files to modify:**
  - `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` — `mode=all` Stage 2 + Stage 2.5
- **Files to reference:**
  - `.claude/skills/skill-fix-it/SKILL.md:121-243` (AskUserQuestion bulk-approval / "Select all" idiom)
- **Verification:**
  - Dry-run reasoning: trace a ~64k scope through capture→slice→chunked-classify→accumulate→bucket-review and
    confirm no chunk-to-chunk progress relies on tags, and the accumulator survives per-call overwrites.
  - Hard invariants preserved: ONLY the read/tag-only sweep is backgrounded; the bucket-approval AskUserQuestion
    runs in the root session (direct execution); wrapper-only (classify is invoked by name with a QUERY
    positional; no raw notmuch mutation); mandatory human review gate is this bucket-approval stage.

---

### Phase 5: `--all` Transparent Execute Drain (split + mtime + progress) [COMPLETED]

- **Goal:** Author `mode=all` Stage 4 (split) and Stage 3.5 (transparent drain): partition the approved set
  into ≤50-lines-per-action sha256-confirmed sub-manifests with the original approval mtime preserved, then
  drain them mechanically with progress-only reporting and NO per-batch re-prompt after the single Stage 2.5
  approval.
- **Tasks:**
  - [x] Specify Stage 4 (split): partition the logically-approved set by action, then by ≤50 lines per action, into N physical sub-manifest files; where both actions fall in the same index range, pack ≤50 archive AND ≤50 delete lines into ONE file (each action independently passes its own `enforce_batch_size`), halving file count. Preserve the original approved manifest's mtime on every split via `touch -r <original-approved-file> <split-file>`. *(completed: Stage 4 items 1-5, incl. the 137a+60d worked example)*
  - [x] Specify Stage 3.5 (drain): for each split in order, compute its sha256 and invoke `email-archive-confirmed`/`email-delete-confirmed --execute --confirm-manifest <sha256> --manifest <split-path>` for whichever action(s) it contains; log executed/failed/remaining per split; rely on the wrapper's per-split `<manifest>.state.jsonl` for idempotency (no second ledger). This stage is mechanical and progress-only — the human already decided at Stage 2.5. *(deviation: altered — authored as "Stage 5 (`--all`): Transparent Execute Drain (plan name: Stage 3.5)" for sequential stage numbering; content identical. Added Stage 3 materialize step so the approval mtime has a concrete origin file)*
  - [x] Specify the PLAN_EXPIRY_DAYS=7 stop-and-report: on an expired split (original approval >7 days old), STOP the drain and report "N remaining approved actions across M un-executed splits have expired (approved {age} days ago); re-run `/email --all` to re-sweep and re-review the residual." Never silently re-timestamp. *(completed: expiry pre-check + stop-and-report block)*
  - [x] Add an aggregate audit/progress surface across splits ("X of Y processed, Z failed, resuming at split #k"). *(completed: aggregate progress surface + Stage 6 all-splits verify)*
- **Timing:** ~2 hours
- **Depends on:** 4
- **Files to modify:**
  - `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` — `mode=all` Stage 4 + Stage 3.5 + expiry handling
- **Verification:**
  - Dry-run reasoning: trace an approved set of, e.g., 137 archive + 60 delete lines into split files and confirm
    every split passes both per-action caps; confirm `touch -r` preserves mtime; confirm an expired-split trace
    stops and reports rather than mutating.
  - Hard invariants preserved: MAX_BATCH_SIZE not raised (split/loop instead); wrapper-only; no per-batch
    re-prompt (single approval upstream); drain runs in root session; idempotency via wrapper state file only.

---

### Phase 6: `--archive` Folder Scope + Extra-Caution Gates + archive-mode-risk.md [COMPLETED]

- **Goal:** Compose `scope=archive` with either mode by scoping the classify QUERY to `folder:Gmail/.All_Mail`,
  and add the proportionate extra-caution gates the ~64k blast radius warrants; author the risk doc.
- **Tasks:**
  - [x] Specify that `--archive` sets the classify QUERY positional to `folder:Gmail/.All_Mail` (no new wrapper flag), composable with default (50-step through All Mail) and `--all` (full All Mail sweep/drain). *(completed: Archive Scope section, composition bullets; email.md Safety Notes already cover --archive posture from Phase 2)*
  - [x] Add extra gates for archive scope: a second, distinctly-worded blast-radius-naming confirmation ("yes, operate on N archived messages in All Mail"); `--expunge-trash` opt-in ONLY (default recoverable Trash, never expunge by default); asymmetric/corroborated confidence bar (stricter than inbox) for archive-scope deletes; reversible-then-hard two-phase (move to Trash first, expunge only behind the separate opt-in); per-chunk classify (inherited from Phase 4); never auto-chain `/email --sync` after an archive drain. *(completed: gates 1-6; Pilot Gate section also authored here — front-loads Phase 9 task 1 since it is Stage-0-coupled)*
  - [x] Author `context/project/email/domain/archive-mode-risk.md` documenting the All Mail blast radius, the reversible-vs-hard boundary, the asymmetric confidence policy, and the never-auto-sync rule. *(completed: new doc with blast-radius table, hop boundary, asymmetric policy, gates, invariants)*
- **Timing:** ~2 hours
- **Depends on:** 5
- **Files to modify:**
  - `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` — `scope=archive` branch + gates
  - `.claude/extensions/email/commands/email.md` — Safety Notes for `--archive`
- **Files to create:**
  - `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md`
- **Verification:**
  - Dry-run reasoning: trace `/email --archive` and `/email --all --archive`; confirm the QUERY token, the second
    confirmation, the expunge opt-in default-off, and the no-auto-sync rule all fire.
  - Hard invariants preserved: wrapper-only (scope is a QUERY arg to a wrapper binary); human review gate plus a
    stronger archive-specific gate; no wrapper contract change.

---

### Phase 7: New Pattern Docs (bulk-bucket-review, batch-drain-loop) + Index Registration [COMPLETED]

- **Goal:** Author the two reusable pattern docs and register the new context entries. Placement decision
  (justified below) is part of this phase.
- **Tasks:**
  - [x] Author `.claude/extensions/email/context/project/email/patterns/bulk-bucket-review.md` (EMAIL-LAYER: tied to email's sender/domain taxonomy, the `min()` rollup, 0.90 option-availability gating, and the fix-it AskUserQuestion idiom). *(completed: 81 lines incl. invariants section)*
  - [x] Author `.claude/context/patterns/batch-drain-loop.md` at the AGENT-SYSTEM LAYER. **Justification:** "many approved mutations gated by ONE human decision, safely resumable" is a domain-agnostic primitive (report 01 Teammate D finding 3; report 02 Context Extension Recommendations), and its natural sibling half — chunked-sweep pagination for a read-only/tag-only tool that exposes `--limit` but no offset — is also general. It does not belong to the email domain, so it lives in the core `.claude/context/patterns/` layer. *(completed: 84 lines, domain-agnostic wording, sibling chunked-sweep section)*
  - [x] Register the email-layer doc in `.claude/extensions/email/index-entries.json`; register the agent-system-layer doc in `.claude/context/index.json` with appropriate `load_when` scoping. (No `manifest.json` change.) *(completed: also registered archive-mode-risk.md and refreshed wrapper-contracts.md line_count/description in index-entries.json; both indexes jq-valid; entry discoverable via agent query; doc-lint email PASS)*
- **Timing:** ~1.5 hours
- **Depends on:** 5
- **Files to create:**
  - `.claude/extensions/email/context/project/email/patterns/bulk-bucket-review.md`
  - `.claude/context/patterns/batch-drain-loop.md`
- **Files to modify:**
  - `.claude/extensions/email/index-entries.json` (register bulk-bucket-review)
  - `.claude/context/index.json` (register batch-drain-loop)
- **Verification:**
  - Both docs are discoverable via their respective index queries; `check-extension-docs.sh` passes.
  - Hard invariants preserved: docs restate wrapper-only, human-gate, root-session, and no-raise-MAX_BATCH_SIZE
    constraints so the patterns cannot be misapplied to bypass them.

---

### Phase 8: README.md + EXTENSION.md Updates [COMPLETED]

- **Goal:** Document the two modes, the `--archive` scope, and the new context docs in the extension's
  user-facing and CLAUDE.md-fragment docs.
- **Tasks:**
  - [x] Update `README.md`: add `--all`/`--archive` to the command description and file inventory; reference the three new context docs; note the pilot gate for `--archive`. *(completed: "Two modes and a scope flag" section + inventory rows + batch-drain-loop pointer)*
  - [x] Update `EXTENSION.md`: add `/email --all` and `/email --archive` to the Commands table; extend the Safety Invariants section with the default-mode cursor, the sub-50 transparent drain, the mtime-preserve/expiry-stop policy, and the archive extra gates. *(completed: also added missing `/email --sync` command row and skill-email-sync mapping row for consistency)*
- **Timing:** ~1 hour
- **Depends on:** 6, 7
- **Files to modify:**
  - `.claude/extensions/email/README.md`
  - `.claude/extensions/email/EXTENSION.md`
- **Verification:**
  - `check-extension-docs.sh` passes (READMEs, manifest, cross-references consistent).
  - Every new flag/mode/doc referenced in code is described in at least one of README/EXTENSION.

---

### Phase 9: `--archive` Pilot Gate + Final Validation [COMPLETED]

- **Goal:** Install a bounded pilot gate so `--archive` cannot run at full (~64k) scale until a bounded pilot
  pass has been run and acknowledged, and perform the final doc-lint + dry-run validation of the whole design.
  Reflects that the extension has never been loaded, so validation is reasoning + lint, not live mutation.
- **Tasks:**
  - [x] Specify the pilot gate in `skill-email-cleanup`: the first `--archive` operation is bounded (e.g. a small capped scope / low-thousands ID slice) and requires an explicit acknowledgement before full-scale `--archive` is permitted; document how the acknowledgement is recorded and surfaced. Tie the chunk-size default (~1,000) to a "confirm/adjust after pilot" note. *(completed in Phase 6 — "Pilot Gate for --archive" section: pilot bound, archive-pilot-ack.json acknowledgement record, Stage-0 gate check, chunk_size_verdict)*
  - [x] Run `.claude/scripts/check-extension-docs.sh` and resolve any failures across all touched docs. *(completed: email extension PASS after every doc-touching phase; the only FAIL is the pre-existing, unrelated lean extension routing_hard issue, confirmed present before this task's changes via git stash)*
  - [x] Perform an end-to-end dry-run reasoning walkthrough of all five invocation forms, confirming each hard invariant holds at every stage; record the walkthrough outcome in the eventual implementation summary (not a separate report file). *(completed: walkthrough recorded in summaries/02_two-mode-mass-cleanup-summary.md)*
- **Timing:** ~1.5 hours
- **Depends on:** 8
- **Files to modify:**
  - `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` — pilot gate for `--archive`
  - `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md` — pilot prerequisite note
- **Verification:**
  - `check-extension-docs.sh` exits 0.
  - Dry-run walkthrough confirms: wrapper-only throughout; human gate present in every mutating path; only the
    classify sweep backgrounded; MAX_BATCH_SIZE never raised; `--archive` full scale blocked pre-pilot.

---

## Testing & Validation

Because the email extension has never been loaded into a consuming repo, there is NO live mailbox mutation in
this task. Validation is limited to:

- [x] `.claude/scripts/check-extension-docs.sh` exits 0 after each doc-touching phase and at the end. *(email extension PASS throughout; script-level exit reflects a pre-existing unrelated lean-extension failure confirmed via git stash)*
- [x] Dry-run reasoning walkthrough of all five invocation forms (`/email`, `--all`, `--archive`,
      `--all --archive`, `--sync`) confirming (mode, scope, route) resolution and gate placement. *(recorded in summary)*
- [x] Manual trace that every mutating path constructs `--execute --confirm-manifest <sha256>` ONLY after an
      explicit in-conversation approval. *(default: Stage 5 after Stage 3; --all: Stage 5 drain after Stage 2.5 (+ archive second confirmation); expunge hop behind its own opt-in gate)*
- [x] Manual trace that every `--all` split passes both per-action `enforce_batch_size` caps and preserves the
      original approval mtime. *(137a+60d worked example -> (50a+50d),(50a+10d),(37a); touch -r on every split)*
- [x] Manual trace of the expiry stop-and-report path and the `--archive` pilot gate. *(drain Stage 5 step 1 pre-check + stop-and-report block; Stage 0 pilot gate refusal absent archive-pilot-ack.json)*
- [x] Confirm no phase introduces a raw `himalaya`/`notmuch`/`msmtp`/`secret-tool` call or a wrapper-contract
      change. *(grep scan: only descriptive/prohibitive mentions; zero .dotfiles edits; MAX_BATCH_SIZE untouched)*

## Artifacts & Outputs

- `.claude/extensions/email/commands/email.md` (mode dispatch)
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` (default 50-step, `--all` sweep/bucket/drain, `--archive` gates, pilot gate)
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` (refreshed)
- `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md` (new)
- `.claude/extensions/email/context/project/email/patterns/bulk-bucket-review.md` (new)
- `.claude/context/patterns/batch-drain-loop.md` (new, agent-system layer)
- `.claude/extensions/email/index-entries.json` (register bulk-bucket-review)
- `.claude/context/index.json` (register batch-drain-loop)
- `.claude/extensions/email/README.md`, `.claude/extensions/email/EXTENSION.md` (updated)
- `specs/805_improve_email_mass_cleanup_workflow/summaries/02_two-mode-mass-cleanup-summary.md` (at implementation)

## Rollback/Contingency

- All changes are additive doc/skill/command edits within `.claude/` — revert with `git checkout` of the touched
  files; no wrapper, manifest, hook, or settings-fragment change to unwind.
- If Phase 1 falsifies a load-bearing assumption, halt before Phase 2 and revise this plan (via `/revise 805`)
  rather than authoring against a wrong model.
- If the captured-ID-list sweep cannot be expressed wrapper-only (Phase 1 finds no ID-capture path), fall back
  in Phase 4 to `--limit`-based chunking with a documented completeness caveat, rather than introducing a raw
  binary — and re-scope `--all` accordingly.
- The `--archive` pilot gate (Phase 9) is itself the contingency for the never-loaded/never-validated risk:
  full-scale archive cleanup stays blocked until a bounded pilot succeeds.
