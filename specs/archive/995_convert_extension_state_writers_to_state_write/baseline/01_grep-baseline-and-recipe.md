# Phase 1: Baseline Inventory and Conversion Recipe

Grep command used (matches the task's VERIFICATION BAR pattern):

```bash
grep -rn 'mv .*state\.json\|state\.json > \|> .*state\.tmp\|> .*state\.json\.tmp' \
  agent-system/extensions/ --include="*.md" --include="*.sh"
```

Total matching lines at baseline: **109**.

## Per-file matching-line counts and CONVERT/EXCLUDE verdicts

### CONVERT — founder/skills (Phase 2): 15 files / 37 lines

| File | Lines |
|---|---|
| skill-market/SKILL.md | 219, 237, 244 (3) |
| skill-founder-plan/SKILL.md | 166, 178 (2) |
| skill-founder-spreadsheet/SKILL.md | 213, 236, 243 (3) |
| skill-deck-plan/SKILL.md | 428, 440 (2) |
| skill-meeting/SKILL.md | 208, 226, 233 (3) |
| skill-strategy/SKILL.md | 222, 240, 247 (3) |
| skill-consult/SKILL.md | 185 (1) |
| skill-finance/SKILL.md | 222, 240, 247 (3) |
| skill-deck-research/SKILL.md | 213, 231, 238 (3) |
| skill-financial-analysis/SKILL.md | 178 (1) |
| skill-project/SKILL.md | 201, 219, 226 (3) |
| skill-deck-implement/SKILL.md | 192, 208 (2) |
| skill-analyze/SKILL.md | 220, 238, 245 (3) |
| skill-legal/SKILL.md | 219, 237, 244 (3) |
| skill-founder-implement/SKILL.md | 180, 210 (2) |

Total = 37. Matches the plan's Scope Hypothesis exactly.

### CONVERT — present/skills (Phase 3): 5 files / 17 lines

| File | Lines |
|---|---|
| skill-slides/SKILL.md | 140 (1) |
| skill-budget/SKILL.md | 219, 242, 249 (3) |
| skill-grant/SKILL.md | 167, 402, 458, 465, 843 (5) |
| skill-funds/SKILL.md | 144, 320, 341, 348 (4) |
| skill-timeline/SKILL.md | 146, 263, 278, 285 (4) |

Total = 17. Matches the plan's Scope Hypothesis exactly.

### CONVERT — lean/skills (Phase 4): 4 files / 10 lines

| File | Lines |
|---|---|
| skill-lean-research-hard/SKILL.md | 187 (1) |
| skill-lean-research/SKILL.md | 64, 167, 186 (3) |
| skill-lean-implementation-hard/SKILL.md | 328, 335, 362 (3) |
| skill-lean-implementation/SKILL.md | 205, 212, 232 (3) |

Total = 10. Matches the plan's Scope Hypothesis exactly.

### CONVERT — cslib/skills, individually reviewed (Phase 5): 5 files / 5 lines

| File | Line | Variant |
|---|---|---|
| skill-pr-review-implementation/SKILL.md | 271 | `/tmp/state.tmp` |
| skill-pr-review-research/SKILL.md | 232 | `/tmp/state.tmp` |
| skill-cslib-research-hard/SKILL.md | 232 | `specs/tmp/state.json` |
| skill-cslib-vet/SKILL.md | 346 | `specs/state.json.tmp` (task-creation site) |
| skill-pr-implementation/SKILL.md | 124 | `$CSLIB_STATE` variable-indirected (hardcoded-absolute-path bug) |

Total = 5. Matches the plan's Scope Hypothesis exactly.

### CONVERT — commands/*.md task-creation sites (Phase 6): 16 files / 23 lines

Founder (10 files / 11 lines):

| File | Lines |
|---|---|
| market.md | 228 (1) |
| finance.md | 246 (1) |
| analyze.md | 212 (1) |
| meeting.md | 165 (1) |
| sheet.md | 219 (1) |
| deck.md | 228 (1) |
| consult.md | 175, 176 (2) — one site spanning two grep lines |
| project.md | 413 (1) |
| strategy.md | 220 (1) |
| legal.md | 237 (1) |

Present (5 files / 10 lines):

| File | Lines |
|---|---|
| timeline.md | 193, 194 (2) |
| slides.md | 281, 282 (2) |
| grant.md | 189, 190, 443, 444 (4) |
| budget.md | 217 (1) |
| funds.md | 227 (1) |

Epidemiology (1 file / 2 lines):

| File | Lines |
|---|---|
| epi.md | 295, 296 (2) |

Total = 11 + 10 + 2 = 23. Matches the plan's Scope Hypothesis exactly.

### CONVERT — core residual (Phase 7): 2 files / 6 lines

| File | Lines | Note |
|---|---|---|
| core/commands/review.md | 670, 671, 676, 677 | two `specs/reviews/state.json` sites, each a 2-line `jq > tmp && mv` pair |
| core/context/formats/command-structure.md | 828, 829 | illustrative doc example teaching the anti-pattern |

Note: the plan's Scope Hypothesis text ("2 convertible sites... 2 matching lines") undercounted
review.md's grep-line total (each of the 2 sites is itself a 2-line `jq ... > tmp` / `mv tmp ...`
pair, i.e. 4 grep lines for 2 sites) — re-measurement per Phase 1's mandate corrects this to 4
lines / 2 sites for review.md. Site count (2) matches the plan; line count is corrected here.

### EXCLUDE — core (evidenced per this plan's Scope Boundary Resolution table)

| File:Line | Reason | Evidence |
|---|---|---|
| core/scripts/state-write.sh:6 | It IS the sanctioned writer; line 6 is header-comment prose describing the anti-pattern it replaces | Header comment, not a live write |
| core/commands/todo.md:871 | `mv "${vault_path}/archive/state.json" "${vault_path}/state.json"` is a file relocation (vault restore), not a jq-staged read-modify-write; no temp path, no transform | Grep line is a bare `mv` of one state file onto another with no producing `jq` |
| core/scripts/deprecated/vault-operation.sh:129 | Same vault-rename shape as todo.md:871 | Bare `mv`, no `jq` |
| core/skills/skill-todo/SKILL.md:680 | Same vault-rename shape | Bare `mv`, no `jq` |
| core/commands/task.md:442 | `jq -e ... specs/state.json > /dev/null` is a read-only existence check | Redirect target is `/dev/null` |
| core/context/orchestration/validation.md:281, 286, 339 | `jq -e ... > /dev/null` read-only existence checks (archive and live state) | Redirect target is `/dev/null` in all three |
| core/scripts/tests/test-update-task-status.sh:329, 330 | Test fixture deliberately constructing a corrupt-state fixture; converting it would defeat the test | Lives under `scripts/tests/`, write is fixture setup |
| core/context/patterns/jq-escaping-workarounds.md:255 | Illustrative prose about the anti-pattern, writing `specs/tmp/test-state.json` as a worked example — not a live writer | File is a documentation/pattern reference, not a skill/command |
| core/context/patterns/task-lock.md | Prose describing the anti-pattern (`jq ... > tmp && mv` mentioned in running text); no literal instance matches the grep pattern | Confirmed no grep hit in this file at all — listed here only because the plan names it as an excluded prose reference |
| `base_branch` / `forcing_data` schema non-conformance | Changing *what* is written is out of scope (WORK item 2: preserve semantics) | Deferred to a follow-up per the plan's Non-Goals |

No unclassified remainder: 37 + 17 + 10 + 5 + 23 + 6 (convert) + 12 (exclude: state-write.sh 1,
todo.md 1, vault-operation.sh 1, skill-todo 1, task.md 1, validation.md 3, test file 2,
jq-escaping-workarounds.md 1, task-lock.md 0 non-matching) = 98 + ... reconciliation: the raw
grep total was 109 lines; 37+17+10+5+23+6 = 98 CONVERT lines; the remaining 11 EXCLUDE lines
(state-write.sh 1, todo.md 1, vault-operation.sh 1, skill-todo 1, task.md 1, validation.md 3,
test-update-task-status.sh 2, jq-escaping-workarounds.md 1) sum to 11. 98 + 11 = 109. Fully
reconciled, no unclassified remainder.

## Canonical conversion recipe

Copied from the two landed precedents (`skill-status-sync`, `skill-researcher`) and the
already-converted `skill-web-*` skills:

1. **One existing site becomes exactly one `state-write.sh` call.** Never merge adjacent sites
   into one call, never split one site across two calls (except where the site already used the
   two-step timestamp+artifact pattern documented in `jq-escaping-workarounds.md`, which stays
   two `state-write.sh` calls, matching `skill-status-sync`).
2. **Bind the task number with `--argjson`, never string-interpolate it.**
   `--argjson num "$task_number"` (see `skill-researcher/SKILL.md:113-116`), not
   `'$task_number'` embedded in the filter string as a bare literal via shell interpolation.
3. **Every call carries `--session-id "$session_id"` (or `"{session_id}"` in prose templates).**
4. **`--regen-todo` is added ONLY where the site already regenerated TODO.md** immediately after
   the write (matches `core/commands/task.md:216-232`'s Create Task pattern). A site that
   hand-Edits TODO.md afterward keeps doing so unchanged.
5. **Task-creation sites** (`next_project_number` bump + `.active_projects` prepend/append) stay
   inside ONE `state-write.sh` call, per `core/commands/task.md:216-232`'s worked example — this
   is the canonical shape for Phase 6.
6. **`--state-file`** is used only for non-default targets (`specs/reviews/state.json` in
   Phase 7); `--regen-todo` is never combined with a non-default `--state-file` (refused by
   `state-write.sh` itself).
7. Replace the generic `mv tmp.json specs/state.json` illustrative example in
   `command-structure.md` with the `state-write.sh` shape, so the doc stops teaching the
   anti-pattern (Phase 7).

## Bash-fence extraction and `bash -n` command

Each conversion phase runs this over every edited file to catch a malformed heredoc/quote:

```bash
awk '/^```bash/{flag=1; next} /^```$/{flag=0} flag' "$file" > /tmp/fence-check.sh
bash -n /tmp/fence-check.sh
```

Applied per-file, once per phase, over every file the phase touched.
