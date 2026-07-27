# Research Report: Task #907

**Task**: 907 - orchestrator_runtime_file_tracking_policy
**Started**: 2026-07-27T00:00:00Z
**Completed**: 2026-07-27T00:00:00Z
**Effort**: research
**Dependencies**: 885, 902, 906 (serialization-for-file-overlap only, not logical prerequisites)
**Sources/Inputs**: agent-system/extensions/core/ (source store), this repo's root `.gitignore`, `/home/benjamin/.dotfiles` (live consumer repo, git history and working tree)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The user-chosen policy (keep `.orchestrator-handoff.json` and `.return-meta.json` tracked) directly contradicts the source store's own current documentation**, which states in `docs/architecture/handoff-schema.md` line 5 that the handoff file is "runtime; not checked in." This is a real conflict, not a misreading — see Finding 1. It needs an explicit decision, not a silent skip.
- **The "swept into a commit mid-lifecycle" hazard is real, confirmed by live evidence in both repos**, not merely theoretical: `orchestrator-postflight.sh` Stage 9 runs a whole-task-dir `git add` on *every* research/plan/implement dispatch cycle, while `skill-orchestrate/SKILL.md`'s loop-guard cleanup (`rm -f "$loop_guard_file"`) only fires when the *entire* `/orchestrate` loop terminates — never per-cycle. A currently-live example sits in `/home/benjamin/.dotfiles`: task 124's committed `.orchestrator-loop-guard` shows `cycle_count: 3, current_state: "implementing"`, genuinely mid-run, sitting in git history right now. See Finding 2.
- **The loop-guard has no freshness/staleness gate at all** (no session_id check, no mtime check) — it unconditionally resumes `cycle_count` from whatever is on disk. This is the structural reason the loop-guard specifically is dangerous when git-restorable, in contrast to the handoff file, which *does* have a documented mtime-vs-`dispatch_start_ts` freshness gate. This asymmetry is the strongest argument for treating the two file classes differently, and it independently supports the user's policy of gitignoring only the loop-guard/lock/churn-state class. See Finding 3.
- **The two consumer repos are NOT in the asymmetric state the task description implies.** Both `/home/benjamin/.config/nvim` (this repo) and `/home/benjamin/.dotfiles` gitignore `.claude/` identically (`/.claude/` in both). The real asymmetry is narrower than described: only this repo's root `.gitignore` additionally covers the `specs/*/` runtime-file block (lines 25-40); `.dotfiles`' `.gitignore` has no such block at all, and confirms non-trivial committed counts (47 return-meta, 29 handoff, 4 loop-guard, 2 `.lock`, 0 churn-state — churn-state's absence is explained by it being a newer file class than most of `.dotfiles`' history). See Finding 4.
- **`root-files/.gitignore` cannot deliver a `specs/*/` pattern**: it is deployed relative to the target `.claude/` directory (confirmed contents: `hooks/*.log`, `logs/`, `output/`, `*.tmp`, none of which reference `specs/`), and the loader's `copy_root_files()` mechanism (`context/guides/loader-reference.md` line 29) copies it to `{target_dir}/` root — i.e., into `.claude/`, not the consumer repo's root. A `specs/*/...` pattern placed there would resolve to `.claude/specs/*/...` and match nothing, exactly as the task's material constraint warns. See Finding 5 for the only mechanisms the source store can actually use.
- Implementing the user's policy in a repo whose root `.gitignore` already has `**/.orchestrator-handoff.json` / `**/.return-meta.json` (this repo, and presumably others) is a **reversal, not an addition** — it requires deleting existing ignore lines, which will cause `git status` to newly show every one of these files as untracked across every `specs/*/` task directory the moment the lines are removed, and each must then be explicitly `git add`ed (or left untracked, defeating the "durable provenance" intent). This is a materially disruptive one-time migration and must be surfaced to the user for confirmation, not silently absorbed into the implementation. See Finding 6.

## Context & Scope

Task 907 asks for a source-store-authored git-tracking policy covering the ephemeral runtime
files `/orchestrate` writes under `specs/{NNN}_{SLUG}/`: `.orchestrator-handoff.json`,
`.return-meta.json`, `.orchestrator-loop-guard`, `.orchestrator-churn-state.json`, and `.lock/`.
The task supplies a decided policy (gitignore the loop-guard/lock/churn-state class; keep
handoff/return-meta tracked) and asks this research pass to resolve a contradiction the dispatcher
found between that policy and this repo's current `.gitignore`, verify the mid-lifecycle-sweep
hazard is real, characterize the asymmetry between this repo and the `.dotfiles` consumer repo,
and determine what deploy mechanism (if any) can actually deliver a root-level gitignore
contribution from the source store.

## Findings

### Finding 1 — `handoff-schema.md` explicitly says the handoff is not checked in; this contradicts the user-chosen policy today

`agent-system/extensions/core/docs/architecture/handoff-schema.md` line 5 reads, verbatim:

> **File location**: `specs/{NNN}_{SLUG}/.orchestrator-handoff.json` (runtime; not checked in)

This is not an offhand remark — it is the file-location line of the doc's own header, immediately
followed by "Written by ... Read by ...". It is the doc's canonical characterization of the file
as of today. There is no other passage in the file contradicting this; every later section (the
freshness-check contract, the token-budget section, the "Outcome Channels" section describing
`.return-meta.json` as a distinct *fallback* channel) is consistent with treating the handoff as
transient, per-cycle, overwrite-in-place state ("The filename is static (not timestamped). Each
dispatch cycle overwrites the previous handoff," lines 351-352).

**The root `.gitignore`'s comment block (lines 25-31 of this repo's `.gitignore`) accurately
quotes and reflects this doc.** It is not a stale or incorrect characterization — it is current
and correct as of this research pass. This means the user-chosen policy is not just in tension
with one repo's incidental gitignore choice; it is in tension with the source store's own current
architecture documentation for that exact file. Implementing the policy as stated requires
*also* changing `handoff-schema.md`'s file-location line and its "not checked in" framing (and
checking the rest of the doc for consistency, e.g. whether "overwrites the previous handoff"
still holds once the file is tracked — it does; overwriting a tracked file in the working tree is
no different, it is simply what gets committed each cycle that changes).

This is surfaced, not silently resolved: the report does not choose to keep the user's policy or
defer to the doc. Both must be reconciled in the same change, and the plan phase should treat
"update `handoff-schema.md`'s file-location line and its framing" as an explicit, in-scope edit
alongside the gitignore change — not an afterthought.

### Finding 2 — the mid-lifecycle-sweep hazard is real and reproducible, confirmed by live evidence in both repos

The mechanism: `agent-system/extensions/core/scripts/orchestrator-postflight.sh` Stage 9 (git
commit) runs after **every single** research/plan/implement dispatch, not just at the end of an
`/orchestrate` run. Its staging is:

```bash
stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")   # orchestrator-postflight.sh line 458
```

This is a whole-task-directory `git add`, executed once per cycle. Meanwhile, the loop-guard file
that `skill-orchestrate/SKILL.md` Stage 2 creates (line 122: `loop_guard_file="${TASK_DIR}/.orchestrator-loop-guard"`)
is only removed via `rm -f "$loop_guard_file"` at loop-*termination* points (lines 444 and 912 in
the base skill, 569/648/660/1119 in the hard variant) — never in between cycles while the loop is
still running. So for every cycle of a multi-cycle `/orchestrate` run, Stage 9's whole-directory
add captures whatever the loop-guard (and, if the file existed, the churn-state / `.lock/`
entries) looked like at that instant — mid-lifecycle, exactly as the `.gitignore` comment states.

This is directly confirmed as a **currently live** condition in `/home/benjamin/.dotfiles`:

```
specs/124_fix_wake_mark_resume_hook_wiring/.orchestrator-loop-guard  (git-tracked)
{
  "session_id": "sess_1785113814_55d32b",
  "cycle_count": 3,
  "max_cycles": 5,
  "infra_failures": 0,
  "current_state": "implementing",
  "started": "2026-07-27T00:57:12Z",
  "last_updated": "2026-07-27T01:14:04Z"
}
```

and a second, older example from task 117 (`current_state: "partial", cycle_count: 1`, task's
own `state.json` status is `"partial"` — i.e., the task genuinely stalled mid-loop and its
loop-guard was committed in that stalled state). Both are real, present-day artifacts of the
mechanism described above, not archaeology — task 124's `last_updated` is from earlier the same
day as this research pass.

**Would the hazard recur if handoff/return-meta were un-ignored per the user's policy?** No — see
Finding 3. The hazard is specific to the loop-guard (and by the same reasoning, the churn-state
and `.lock/` classes), not to handoff/return-meta. Un-ignoring handoff/return-meta does not
reintroduce this specific correctness hazard; it only makes those two files' per-cycle contents
part of the durable commit history, which is exactly the "provenance" outcome the user's policy
intends and accepts.

### Finding 3 — the loop-guard has no freshness gate; the handoff does. This asymmetry justifies treating the two classes differently

`skill-orchestrate/SKILL.md` Stage 2 (lines 128-133) reads the loop guard unconditionally:

```bash
if [ -f "$loop_guard_file" ] && jq empty "$loop_guard_file" 2>/dev/null; then
  # Resume: read existing guard
  cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
  ...
```

There is no session_id comparison and no mtime/staleness check anywhere in this branch — any
syntactically valid guard file at the expected path is trusted and resumed from, regardless of
its age or which session wrote it. Contrast this with `handoff-schema.md`'s explicit contract:
"**Readers MUST check freshness.** ... Both orchestrators compare the file's mtime against
`dispatch_start_ts` ... and treat an out-of-window handoff exactly as they treat a missing one"
(lines 35-38). The handoff is *designed* to be read-and-discarded if stale; the loop guard is not.

This means a committed-then-git-restored loop guard is a genuine correctness hazard in a way a
committed-then-restored handoff is not — the reader-side freshness gate the handoff already has
neutralizes the "restored from an old commit" scenario for that file, but no equivalent gate
exists for the loop guard. This is independent, mechanism-level support for the user's chosen
split (guard/lock/churn-state ignored, handoff/return-meta kept), beyond just "the guard causes
budget hazards and the others don't" — it explains *why* structurally.

One caveat for the plan phase: `.return-meta.json`'s own freshness handling is weaker than the
handoff's. `handoff-schema.md`'s "Outcome Channels" section states the recovery fallback treats a
`.return-meta.json` as valid only if fresh "within the current dispatch window" — so `.return-meta.json` *does* have an equivalent mtime gate at its one documented read site
(`orchestrate-recover-outcome.sh`). Good — this closes what would otherwise be a gap in the
justification for keeping it tracked.

### Finding 4 — the two-repo asymmetry is real but narrower than the task description states

Both repos gitignore `.claude/` as a disposable deploy artifact:

| | this repo (`/home/benjamin/.config/nvim`) | `/home/benjamin/.dotfiles` |
|---|---|---|
| `.claude/` tracked? | No (`/.claude/`, `.gitignore` line 7) | No (`/.claude/`, `.gitignore` line 36) |
| `specs/` tracked? | Yes | Yes (581 files) |
| `**/.return-meta.json` ignored? | Yes (line 1) | No — 47 committed |
| `**/.orchestrator-handoff.json` ignored? | Yes (line 33) | No — 29 committed |
| `**/.orchestrator-loop-guard` ignored? | Yes (line 34) | No — 4 committed (2 of them under `specs/archive/`, i.e. even archived/completed tasks carry stale committed guards) |
| `**/.lock/` ignored? | Yes (line 32) | No — 2 committed `.lock/holder.json` entries |
| `.orchestrator-churn-state.json` ignored? | Yes (line 36) | No matches found (this file class postdates most of this repo's history; its absence in `.dotfiles` is not evidence it would be safe there — the same commit mechanism (Finding 2) applies to it identically) |

So the task's framing ("`.claude/` and `specs/` ARE tracked" in `.dotfiles`, "unlike this repo") is
only half accurate: `.claude/` tracking is identical (untracked) in both repos. The real, confirmed
asymmetry is narrower and specific to `specs/*/` runtime-file gitignore coverage: this repo's root
`.gitignore` has an explicit block for it (lines 25-40); `.dotfiles`' does not, at all. This
narrower framing should replace the broader claim when this task's findings feed the plan phase,
so the fix is correctly scoped as "ship a `specs/*/` runtime-file ignore contribution usable by
any consumer repo that tracks `specs/`" rather than being conflated with `.claude/`-tracking
differences that do not actually exist.

### Finding 5 — `root-files/.gitignore` cannot deliver this; no other automatic root-`.gitignore` deploy path exists in the source store today

Confirmed contents of `agent-system/extensions/core/root-files/.gitignore`:

```
# Personal settings (not shared)
# settings.local.json

# Hook logs
hooks/*.log
logs/
output/

# Temporary files
*.tmp
```

`context/guides/loader-reference.md` line 29 documents the deploy mechanism: `copy_root_files()`
copies `root_files` from an extension's `root-files/` subdirectory to `"{target_dir}/" root` — and
`{target_dir}` for the core extension is the consumer's `.claude/` directory (confirmed: the
existing entries — `hooks/*.log`, `logs/`, `output/` — are all paths that exist *under* `.claude/`
in this repo, e.g. `.claude/hooks/`, not repo-root `logs/`). A `specs/*/...` pattern placed in this
file would deploy to `.claude/.gitignore` and be interpreted relative to `.claude/`, resolving to
`.claude/specs/*/...` — which does not exist in any consumer repo — and would silently match
nothing. This is exactly the failure mode the task's material constraint warns against, confirmed
directly from the deploy mechanism rather than assumed.

I found no other automatic mechanism in `agent-system/extensions/core/` (checked `scripts/`,
`templates/`, `merge-sources/`, and all `context/guides/*` deploy-related docs) that writes to or
merges into a consumer repo's **root** `.gitignore`. The `templates/` directory here contains only
`extension-readme-template.md`, `settings.json`, and `claudemd-header.md` — no gitignore template
and no deploy path targeting the repo root at all.

**Conclusion for the plan phase**: there is currently no automatic way for the source store to
ship a root-level `.gitignore` contribution to a consumer repo. The only two honest options are:
(a) documented, one-time, human-applied setup guidance (e.g., a "Consumer Repo Setup" doc section
listing the exact lines to add to the repo's root `.gitignore`, plus a verification check script
the user or an agent can run to confirm coverage), or (b) building a new deploy path (e.g. an
`append_root_gitignore()` loader primitive distinct from `copy_root_files()`) — a larger, separate
change this task should flag as a candidate follow-up rather than attempt inline. Given task 907's
own framing prioritizes not shipping a silently-broken pattern file, and given the loader
primitive is a nontrivial addition with its own idempotency/merge-conflict questions (what happens
on re-sync if the user already customized their root `.gitignore`?), documented guidance (option
a) is the safer near-term deliverable; option b is a reasonable task to spawn separately if the
plan phase wants a fully automatic contribution.

### Finding 6 — implementing the policy in a repo whose root `.gitignore` already ignores handoff/return-meta is a reversal, with real migration cost

This repo is a live example of exactly this situation. If the user's policy (keep handoff and
return-meta tracked) is applied here, `.gitignore` lines 1 and 33 must be *removed* (not added
to) — un-ignoring is inherently a subtractive edit to an existing ignore file. The moment those
lines are removed:

- Every existing `specs/*/.return-meta.json` and `specs/*/.orchestrator-handoff.json` file already
  on disk across every task directory (active and archived) becomes untracked-and-visible in
  `git status`, in one shot, repo-wide.
- None of that history is retroactively recoverable as "durable provenance" — files that already
  existed before this policy change were never committed, so removing the ignore line only starts
  tracking *future* writes to those paths (existing on-disk content is caught by whatever the next
  natural commit for that task directory happens to be, if one occurs; abandoned/archived task
  directories may never get one, leaving those particular handoff/return-meta files permanently
  untracked despite the new policy).
- Any automated `git add specs/{task}/` (already the standard whole-task-dir staging pattern
  documented in `git-staging-scope.md`'s "plan"/"implement" sections and used verbatim by
  `commands/orchestrate.md` and `orchestrator-postflight.sh`) will, from that point on, begin
  silently absorbing every handoff/return-meta file it touches — which is the *intended* new
  behavior, but is a behavior change to every existing automated commit path in this repo,
  worth calling out explicitly rather than treating as a drive-by side effect of a gitignore edit.

This is a plain reversal-with-migration, not a straightforward additive gitignore change, and it
should be presented to the user as such before the plan phase proceeds — e.g., "removing lines 1
and 33 from `.gitignore` will make N existing untracked handoff/return-meta files across specs/
become stageable; do you want them backfilled into history in one migration commit, or left to
accrue naturally as tasks get future commits?" The research pass surfaces this rather than
resolving it, per the task's own instruction not to silently narrow or re-decide the policy.

## Decisions

- Confirmed as fact (not re-litigated): the user's split (ignore loop-guard/`.lock/`/churn-state;
  keep handoff/return-meta tracked) is mechanistically well-justified by the freshness-gate
  asymmetry in Finding 3, independent of the "durable provenance" framing already given in the
  task description.
- Confirmed as fact: `root-files/.gitignore` cannot deliver `specs/*/` patterns; the plan phase
  must choose documented setup guidance or a new loader primitive, not a silently-broken pattern
  file (Finding 5).
- Surfaced, not decided here: `handoff-schema.md`'s "not checked in" framing and file-location
  line must be updated in the same change as the gitignore policy, or the two will keep
  contradicting each other (Finding 1).
- Surfaced, not decided here: applying the policy to a repo (like this one) whose root
  `.gitignore` already ignores these files is a reversal with a real, repo-specific migration
  question that needs explicit user sign-off, not silent absorption (Finding 6).

## Risks & Mitigations

- **Risk**: A plan that only narrows `git-staging-scope.md`'s staging pattern (per the "generalize
  the narrow form" instruction) without also fixing `.gitignore` coverage would still leave
  consumer repos lacking any root-`.gitignore` contribution (like `.dotfiles` today) exposed to
  the loop-guard hazard, since whole-task-dir staging is documented as the *intended* contract for
  `plan`/`implement` operations (`git-staging-scope.md`'s "Per-Operation Scope" section), not a
  bug to be removed outright. **Mitigation**: treat gitignore coverage as the primary, necessary
  fix (it is sufficient on its own — this repo's three completed `/orchestrate` runs today swept
  nothing in, purely because of gitignore coverage, not staging narrowness) and staging-pattern
  changes as defense-in-depth, not a substitute.
- **Risk**: Silently deciding Finding 1 or Finding 6 one way or the other during planning would
  violate the task's explicit "do not quietly narrow... do not silently re-decide" instruction.
  **Mitigation**: the plan phase should present both as an explicit checkpoint/question in its
  own artifact, and the eventual implementation should update `handoff-schema.md`'s framing in
  the same change that updates the gitignore guidance.
- **Risk**: `.orchestrator-churn-state.json` has no live examples to confirm the hazard model
  against (absent from `.dotfiles`' history). **Mitigation**: Finding 2's mechanism (whole-dir
  Stage 9 add running before loop-termination cleanup) applies identically regardless of file
  name — `context/patterns/task-lock.md` groups churn-state with the loop-guard under the same
  atomic-creation pattern (per the task description), so no separate verification is needed
  before including it in the same ignore class.

## Context Extension Recommendations

- **Topic**: Consumer-repo root-`.gitignore` contribution mechanism.
- **Gap**: `context/guides/loader-reference.md` documents `copy_root_files()` for `.claude/`-root
  files but has no equivalent guidance for repo-root files a consumer must apply once by hand.
- **Recommendation**: once the plan phase picks an approach (documented guidance vs. new loader
  primitive), add a section to `loader-reference.md` (or a new
  `context/guides/consumer-repo-setup.md`) describing how repo-root contributions (like a
  `specs/*/` gitignore block) are delivered, since this is likely to recur for future
  source-store-authored, root-level guidance.

## Appendix

### Verification commands run

```bash
jq -r '.active_projects[]|select(.project_number==907)|.description' specs/state.json
cat -n .gitignore
cat -n agent-system/extensions/core/root-files/.gitignore
cat agent-system/extensions/core/docs/architecture/handoff-schema.md
grep -n "stage_paths\|git add" agent-system/extensions/core/commands/orchestrate.md
grep -n "loop_guard_file\|loop-guard\|churn-state" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md
grep -n "loop_guard_file\|loop-guard\|churn-state" agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md
cd /home/benjamin/.dotfiles && git ls-files | grep -c '\.return-meta\.json$'   # 47
cd /home/benjamin/.dotfiles && git ls-files | grep -c '\.orchestrator-handoff\.json$'  # 29
cd /home/benjamin/.dotfiles && git ls-files | grep -c '\.orchestrator-loop-guard$'  # 4
cd /home/benjamin/.dotfiles && git ls-files | grep -c '/\.lock/'  # 2
cd /home/benjamin/.dotfiles && cat specs/124_fix_wake_mark_resume_hook_wiring/.orchestrator-loop-guard
cd /home/benjamin/.dotfiles && git log --oneline -- specs/117_laptop_lid_close_no_sleep_headless/.orchestrator-loop-guard
```

### References

- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (lines 5, 35-38, 251-277, 349-360)
- `agent-system/extensions/core/context/standards/git-staging-scope.md` (full)
- `agent-system/extensions/core/commands/orchestrate.md` (lines 350-373, 480-501)
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` (lines 440-490)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (lines 110-170, 444, 912)
- `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` (lines 234-277, 569, 648, 660, 1119)
- `agent-system/extensions/core/root-files/.gitignore`
- `agent-system/extensions/core/context/guides/loader-reference.md` (line 29, 102)
- `.gitignore` (this repo, root)
- `/home/benjamin/.dotfiles/.gitignore`, `/home/benjamin/.dotfiles` git history and working tree (live evidence)
