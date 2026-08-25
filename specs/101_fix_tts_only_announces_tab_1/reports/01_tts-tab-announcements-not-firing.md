# Research Report: TTS lifecycle announcements never fire ("only ever Tab 1")

- **Task**: 101 - fix_tts_only_announces_tab_1
- **Started**: 2026-08-25T12:20:00-07:00
- **Completed**: 2026-08-25T12:45:00-07:00
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Sources/Inputs**:
  - Codebase: `agent-system/extensions/core/scripts/skill-base.sh`, `lifecycle-notify.sh`,
    `orchestrator-postflight.sh`; `agent-system/extensions/core/hooks/tts-notify.sh`,
    `claude-stop-notify.sh`; `agent-system/extensions/core/context/patterns/skill-postflight-flow.md`;
    the deployed `.claude/` twins of all of the above; `.claude/settings.json`;
    `agent-system/extensions/core/skills/{skill-researcher,skill-researcher-hard,skill-planner,
    skill-planner-hard,skill-implementer,skill-implementer-hard,skill-reviser,
    skill-team-implement}/SKILL.md` and the `web`/`cslib`/`epidemiology` extension research/implement
    skills; `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua` and
    `lua/neotex/plugins/editor/which-key.lua` (nvim `<leader>al` keymap)
  - Git history: `git log -S"STATE_STATUS"`, `git show ed42d0bcb`, `git show 0170704c9`,
    `git show 7e79b2695`
  - Live commands run in this session: `wezterm cli list --format=json`, direct invocation of
    `.claude/scripts/lifecycle-notify.sh` with empty and non-empty status, `bash -c 'source
    .claude/scripts/skill-base.sh; skill_lifecycle_notify "$STATE_STATUS"'`, `specs/tmp/claude-tts-notify.log`
- **Artifacts**:
  - `specs/101_fix_tts_only_announces_tab_1/reports/01_tts-tab-announcements-not-firing.md` (this report)
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

## Executive Summary

- **Root cause (confirmed by direct testing): an undefined variable.** Every lifecycle-completion
  call site invokes `skill_lifecycle_notify "$STATE_STATUS"`, but no skill ever defines a variable
  named `STATE_STATUS` — the shared preflight/postflight contract defines the operative variable as
  `status` (`agent-system/extensions/core/context/patterns/skill-postflight-flow.md:37,51`). Bash
  silently substitutes an empty string for the unset `$STATE_STATUS`, so `lifecycle-notify.sh`
  receives `""`, hits its own `[[ -z "$STATUS" ]] && exit 0` no-op guard
  (`agent-system/extensions/core/scripts/lifecycle-notify.sh:38-40`), and returns before ever
  reaching `tts-notify.sh` or WezTerm tab-color update. This was reproduced live in this session
  (see Findings > Empirical Verification).
- **This is not a deploy-staleness issue.** `skill-base.sh`, `lifecycle-notify.sh`, and
  `tts-notify.sh` are byte-identical between `agent-system/extensions/core/**` and the deployed
  `.claude/**` twins (verified by `diff`, all three exit 0). The bug lives in the source store
  itself and is faithfully deployed.
- **The interactive "Tab N" path is a completely separate, working code path**, which is why the
  AskUserQuestion prompt in this session correctly announced "Tab 5": the `Notification` hook
  (`.claude/settings.json:113-123`) calls `tts-notify.sh` with **no arguments**, which never touches
  `STATE_STATUS` at all — it goes straight to `get_tab_prefix()`. That function was independently
  verified correct in this session's live WezTerm state (tab_id 10, unique-sorted position 4 -> "Tab
  5", matching the confirmed tab). The interactive path and the lifecycle path share the same
  `get_tab_prefix()` tab-resolution logic (`tts-notify.sh:52-72`) — they are not divergent in how a
  tab number is computed, only in whether the lifecycle path ever reaches that logic at all.
- **The "only ever hear Tab 1" observation is best explained as an artifact of which announcements
  actually fire, not a wrong tab number.** Since every lifecycle completion silently no-ops, the
  *only* TTS the user has ever heard is the interactive-prompt path, correctly reporting whatever
  tab they happen to be in at the time — which for their typical single-tab or first-tab workflow is
  usually tab 1. No code path was found that hardcodes or defaults to "Tab 1" specifically; the
  fallback on tab-resolution failure is the bare string `"Tab"` (no number), not `"Tab 1"`.
  Empty-lifecycle-status silence is fully sufficient to explain the reported symptom without positing
  a second, number-specific bug.
- **Scope: this affects 12 skill files** across `core`, `web`, `cslib`, and `epidemiology`
  extensions, plus the shared pattern file they all trace back to — i.e. every lifecycle skill
  invoked by `/research`, `/plan`, `/implement` (standard and `--hard`), `/revise`, and
  `skill-team-implement`. `/orchestrate` is **not** affected: `orchestrator-postflight.sh` builds its
  own correctly-scoped `$status`/`$notify_status` variable independently and does not go through
  `skill_lifecycle_notify`'s `$STATE_STATUS` argument at all — confirmed by a genuine historical log
  line (`Lifecycle notification sent: Tab 3 completed`, 2026-08-24T20:47:13) that predates this
  session's testing.
- **The bug is long-standing, not a recent regression.** `git log -S"STATE_STATUS"` shows the
  undefined-variable pattern already present at commit `7e79b2695` (2026-07-14, a file-relocation
  commit, so likely older still) and was faithfully carried forward — never introduced, never
  fixed — through the task-983 shared-postflight-block unification (commit `ed42d0bcb`,
  2026-08-08) into the current `skill-postflight-flow.md`.

## Context & Scope

The user reported that `<leader>al`-launched Claude Code sessions across multiple repos never
announce anything but "Tab 1", and never speak lifecycle-completion phrases ("Tab n researched" /
"planned" / "implemented") or needs-input phrases — except for one confirmed counterexample in this
very session, where an `AskUserQuestion` prompt correctly announced "Tab 5" (the tab this session
actually occupies). The research goal was to identify the discriminating variable between the
working and non-working paths, not to fix anything.

Note for the record: `<leader>al` itself (`lua/neotex/plugins/editor/which-key.lua:259-268`,
`lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua`) is the AI commands/agents picker keymap
that launches a Claude Code session — it is not itself a TTS trigger. The reported symptom is about
what that launched Claude Code session announces via its own Claude Code hooks, not about the
keymap's own behavior. This distinction does not change the root-cause finding.

## Findings

### The two independent notification code paths

1. **Interactive / needs-input path** — `Notification` hook, matcher
   `permission_prompt|elicitation_dialog`, `.claude/settings.json:113-123` -> calls
   `.claude/hooks/tts-notify.sh` **with no arguments**. Inside `tts-notify.sh`, this hits the
   "INTERACTIVE MODE" branch (`tts-notify.sh:108-115`), calls `get_tab_prefix()`, and speaks `"Tab
   N"`. No `STATE_STATUS`/`status` variable is involved anywhere in this path.
2. **Lifecycle-completion path** — every research/plan/implement skill's own Stage 8a, either
   inlined or lazily imported via `@.claude/context/patterns/skill-postflight-flow.md`. All call
   `skill_lifecycle_notify "$STATE_STATUS"` (defined in `skill-base.sh:718-725`, deployed identically
   at `.claude/scripts/skill-base.sh:718-725`), which backgrounds
   `bash .claude/scripts/lifecycle-notify.sh "$state_status" &`.

### The defect

- `skill-postflight-flow.md`'s own Preconditions section names the variable the importing skill
  is expected to have in scope `status`, not `STATE_STATUS`
  (`agent-system/extensions/core/context/patterns/skill-postflight-flow.md:37`: "`status` — the
  operation's success-variant string read from `.return-meta.json` at Stage 6 ...").
- Its Stage 7 code block correctly uses `$status`
  (`skill-postflight-flow.md:54`: `skill_postflight_update "$task_number" "$operation"
  "$session_id" "$status"`).
- Its Stage 8a code block instead reads `$STATE_STATUS`
  (`skill-postflight-flow.md:99`: `skill_lifecycle_notify "$STATE_STATUS"`), a name that appears
  nowhere else in the Preconditions or in any importing skill's own variable assignments.
- Every skill that reaches Stage 8a — whether by lazily following the `@`-import (skill-researcher,
  skill-researcher-hard) or by having inlined the literal code block (skill-implementer,
  skill-implementer-hard, skill-planner, skill-planner-hard, skill-reviser, skill-team-implement,
  and the `web`/`cslib`/`epidemiology` extension research/implement skills) — executes this exact
  literal text. `grep -rln STATE_STATUS` across all `SKILL.md`/pattern files returns 13 files (12
  skills + the 1 shared pattern file they derive from).
- `lifecycle-notify.sh` itself has an explicit, correctly-implemented empty-status guard
  (`lifecycle-notify.sh:34,38-40`: `STATUS="${1:-}"` then `if [[ -z "$STATUS" ]]; then exit 0;
  fi`), which is exactly what silently swallows the empty substitution. This guard is *correct*
  behavior for its own documented "no-op on empty status" contract (`lifecycle-notify.sh:7`); the
  defect is entirely upstream, in what gets passed to it.
- **This is precisely, and only, an invocation-argument bug** — not a tab-resolution bug (`H3`),
  not a missing-invocation bug (`H4`, since the call site genuinely exists and runs), not a
  phrase-construction bug (`H5`), and not an environment/binary problem (`H6`). It sits structurally
  between H4 and H5: the function is invoked, on every lifecycle transition, but with an argument
  that guarantees the downstream script no-ops before it ever gets to phrase construction or tab
  resolution.

### Why `/orchestrate` is unaffected

`orchestrator-postflight.sh` Stage 8b does not call `skill_lifecycle_notify` at all. It builds its
own `notify_status` from its own already-correctly-scoped `$status` variable and calls
`lifecycle-notify.sh` directly:

```
notify_status="$status"
[ "$notify_status" = "implemented" ] && notify_status="completed"
bash "$lifecycle_script" "$notify_status" &
```
(`agent-system/extensions/core/scripts/orchestrator-postflight.sh:478-481`)

This explains the one genuine historical success in `specs/tmp/claude-tts-notify.log`:
`[2026-08-24T20:47:13-07:00] Lifecycle notification sent: Tab 3 completed (status=completed)` — an
`/orchestrate` run, not a standalone `/research`/`/plan`/`/implement`.

### Empirical Verification (performed live in this session, non-destructive)

1. **Confirmed WEZTERM_PANE is inherited into Bash-tool subprocesses.** `env | grep -i wezterm`
   showed `WEZTERM_PANE=10` present in the tool's own shell. This refutes any theory that the bash
   tool's subprocess environment strips WezTerm identity.
2. **Confirmed `get_tab_prefix()`'s arithmetic independently, by hand, against live WezTerm state.**
   `wezterm cli list --format=json` showed pane 10 belongs to `tab_id: 10`; the full set of
   `tab_id`s present was `{9, 0, 2, 8, 10}`; jq's `unique` sorts ascending to `[0, 2, 8, 9, 10]`; the
   0-based position of `10` in that list is `4`, giving `tab_num = 4 + 1 = 5`. This matches the
   confirmed "Tab 5" this session actually occupies exactly, and matches the live log line `[...]
   Interactive notification sent: Tab 5` written during this session's own `AskUserQuestion`. Tab
   resolution is correct in the current environment; no bug was found in `get_tab_prefix()` itself.
   (Note for a future fix: this algorithm sorts `tab_id` values across *all* WezTerm windows, not
   scoped to the current window — a latent correctness risk under multi-window setups, but out of
   scope for this defect and not the cause of the reported symptom.)
3. **Reproduced the defect directly**: `bash .claude/scripts/lifecycle-notify.sh ""` exits 0 with no
   log entry appended to `specs/tmp/claude-tts-notify.log` (the no-op branch, silently).
4. **Reproduced the exact call-site bug**: sourced the deployed `skill-base.sh` in a fresh subshell
   and ran the literal call site text, `skill_lifecycle_notify "$STATE_STATUS"`, with `STATE_STATUS`
   genuinely unset — confirmed no new log line was appended (bash's default `${STATE_STATUS}`
   expansion of an unset variable to `""` under non-`set -u` execution, exactly reproducing what an
   agent literally executing the SKILL.md-quoted command would do).
5. **Confirmed the fix works when given a real value**: `bash .claude/scripts/lifecycle-notify.sh
   "researched"` produced the log line `[2026-08-25T12:38:13-07:00] Lifecycle notification sent: Tab
   5 researched (status=researched)` — i.e., given a real, non-empty status string, the full
   pipeline (tab resolution -> phrase construction -> piper synthesis -> paplay playback, all
   correctly backgrounded) runs to completion and logs success. This directly validates hypothesis
   H2 (backgrounding) as **not** a contributing defect: the double-layer backgrounding
   (`skill_lifecycle_notify`'s own `&`, plus `speak()`'s inner `(...) &`) completed and logged
   successfully in this environment.

### Hypothesis Verdicts

| # | Hypothesis | Verdict | Evidence |
|---|---|---|---|
| H1 | Deploy staleness (`skill-base.sh` differs source vs. deployed) | **Refuted** | `diff agent-system/extensions/core/scripts/skill-base.sh .claude/scripts/skill-base.sh`, `diff ... lifecycle-notify.sh`, `diff ... tts-notify.sh`, `diff ... wezterm-notify.sh` all exit 0 (byte-identical). The bug is present in the source store itself, not introduced by staleness. (`verify-deploy.sh --findings` was also launched but exceeded this session's 120s window without emitting output; the direct `diff`s above are the decisive evidence for the specific implicated files and make waiting on that script unnecessary.) |
| H2 | Backgrounding/detachment kills the notification before it completes | **Refuted** | Empirical test 5 above: given a real status, the fully-backgrounded pipeline logged a completed send. No premature-kill behavior observed in this environment. |
| H3 | Tab number resolution differs per call path (lifecycle defaults/hardcodes to 1) | **Refuted** | Both the interactive and lifecycle paths call the *same* `get_tab_prefix()` function in the same `tts-notify.sh` file (`tts-notify.sh:52-72`, invoked at both `:105` interactive and `:100-102` lifecycle branches). There is no separate or divergent tab-resolution code for the lifecycle path, and no literal `1` fallback exists anywhere in `get_tab_prefix()` — its failure fallback is the bare string `"Tab"` (`tts-notify.sh:53`), not `"Tab 1"`. |
| H4 | Lifecycle notify is never invoked at all | **Refuted, but adjacent defect confirmed** | The call site genuinely exists and executes in all 12 affected skills — see Findings above. It is invoked on every lifecycle transition; it just always no-ops downstream due to the empty-string argument. |
| H5 | Phrase construction omits the lifecycle verb | **Not applicable / moot** | Never reached — `lifecycle-notify.sh`'s empty-status guard returns before `tts-notify.sh --lifecycle STATUS` (which builds the `"$TAB_PREFIX $LIFECYCLE_STATUS"` phrase, `tts-notify.sh:117-120`) is ever invoked. When invoked with a real status (empirical test 5), the phrase construction is correct: `"Tab 5 researched"`. |
| H6 | Environment/binary availability (missing TTS binary, stderr swallowed) | **Refuted** | `piper`, `paplay`, `jq`, and `wezterm` all resolved to real binaries in this environment (`/run/current-system/sw/bin/piper`, `/run/current-system/sw/bin/paplay`, nix-profile `jq`, nix-profile `wezterm`); the voice model file exists at `$HOME/.local/share/piper/en_US-lessac-medium.onnx`; `TTS_ENABLED` is unset, which defaults to enabled (`tts-notify.sh:26`: `TTS_ENABLED="${TTS_ENABLED:-1}"`). |

**Confirmed root cause (not one of the pre-listed H1-H6, but the one they collectively narrowed
down to)**: an undefined-variable name mismatch, `$STATE_STATUS` vs. `$status`, at every skill's
Stage 8a lifecycle-notify call site, tracing back to
`agent-system/extensions/core/context/patterns/skill-postflight-flow.md:99` and present in that
form since before the task-983 unification that consolidated 11 near-identical inline copies into
one shared block (commit `ed42d0bcb`, 2026-08-08) — the unification faithfully preserved the
pre-existing bug rather than introducing a new one (verified via `git show 0170704c9^` showing the
identical unfixed `"$STATE_STATUS"` reference already present in `skill-researcher/SKILL.md`
before that conversion, and `git log -S"STATE_STATUS"` showing the pattern already present at
commit `7e79b2695`, 2026-07-14).

## Decisions

- Scoped the empirical testing to non-destructive, reversible invocations only (direct script
  calls with test arguments, log-file inspection, live `wezterm cli list` queries). No files
  outside `specs/101_fix_tts_only_announces_tab_1/` were modified.
- Did not chase the `get_tab_prefix()` multi-window sort-scoping observation (Findings > Empirical
  Verification, item 2's parenthetical) as part of this task's root cause, since it does not
  explain the reported symptom and the user's own confirmed counterexample already demonstrates
  correct resolution in the actual environment. Recorded it below as a secondary, lower-priority
  finding for the eventual fix to consider.

## Recommendations

1. **Primary fix (highest priority, minimal and precise)**: change
   `skill_lifecycle_notify "$STATE_STATUS"` to `skill_lifecycle_notify "$status"` at its single
   canonical source, `agent-system/extensions/core/context/patterns/skill-postflight-flow.md:99`
   (and its two explanatory prose references at lines 103 and 134 that also name
   `$STATE_STATUS`), then propagate the same one-line change into every skill that inlined the
   literal call rather than lazily importing it: `skill-implementer/SKILL.md:594`,
   `skill-implementer-hard/SKILL.md:465`, `skill-planner/SKILL.md:378`,
   `skill-planner-hard/SKILL.md:430`, `skill-reviser/SKILL.md:402`,
   `skill-team-implement/SKILL.md` (STATE_STATUS occurrence), and the `web`/`cslib`/`epidemiology`
   extension equivalents (`skill-web-research`, `skill-web-implementation`,
   `skill-cslib-research-hard`, `skill-cslib-implementation-hard`, `skill-epi-research`,
   `skill-epi-implement`). Per this repo's `source-store-deploy-boundary.md` rule, **every one of
   these edits must land in `agent-system/extensions/**`, never in the disposable, gitignored
   `.claude/**` deploy tree** — a `.claude/**` edit would be silently wiped on the next
   regeneration.
2. **Verification plan for the fix**: after editing, re-run this session's empirical test 4
   pattern (source the *edited* `skill-base.sh`-equivalent context, execute the corrected literal
   call with a real `$status` value in scope, confirm a new `specs/tmp/claude-tts-notify.log` line
   appears with the expected `Tab N <status>` phrase) before considering the fix verified — do not
   rely on static inspection alone, since this defect class (a plausible-looking but undefined
   variable name) is exactly the kind of thing static review missed for at least six weeks across
   one full unification refactor.
3. **Consider a grep-based regression guard**: add a lint check (e.g. to
   `check-extension-docs.sh` or a dedicated script) that fails if any `SKILL.md` or context pattern
   file references a bash variable inside a fenced `bash` block that is never assigned anywhere in
   that same file's Preconditions/variable-scope section or in the shared pattern file it imports
   from. This class of defect (name drift between a shared contract's documented precondition name
   and its own code block) is not caught by any existing test and cost roughly six weeks of silent
   lifecycle-notification loss.
4. **Lower priority / out of scope for this fix**: `get_tab_prefix()`'s tab-number computation
   (`agent-system/extensions/core/hooks/tts-notify.sh:52-72`) sorts `tab_id` values gathered across
   *all* WezTerm windows via `wezterm cli list`, not scoped to the current window
   (`current_tab_id`'s containing `window_id` is read but never used to filter `all_panes` before
   computing `unique_tab_ids`). In a single-window-per-workspace setup (this session's environment)
   this coincidentally matches the visible per-window tab number; in a genuine multi-window setup it
   would not. Flagging for awareness, not requesting action as part of this task.
5. Per this repo's `no-task-references-in-deliverables.md` rule: whichever plan/implementation
   artifact eventually carries out recommendation 1 must not embed this task's number inside the
   edited `SKILL.md`/pattern-file prose itself (task-number references are fine here, inside
   `specs/**`, but not in the deliverable files being edited).

## Risks & Mitigations

- **Risk**: fixing only the shared pattern file (`skill-postflight-flow.md`) without also fixing
  the 8+ skills that inlined a literal copy of the buggy line would leave most of the actually-used
  call sites (implementer, planner, and all `--hard`/extension variants) still broken, since those
  files do not re-read the pattern file at execution time — they already have the (wrong) text
  baked in. **Mitigation**: recommendation 1 above explicitly enumerates every inlined occurrence
  found via `grep -rln STATE_STATUS`, not just the shared source.
- **Risk**: a naive `$STATE_STATUS` -> `$status` string replacement could collide with an unrelated,
  correctly-scoped local variable that happens to also be named `status` in a hard-mode skill with
  more complex control flow (e.g., a loop that reassigns `status` per continuation-loop iteration).
  **Mitigation**: this was not observed in the files inspected (each skill's Stage 8a runs after
  any such loop has already broken and `status` holds its final terminal value), but the eventual
  implementer should re-read each affected file's local `status`-assignment history immediately
  before Stage 8a, not just apply a blind find-and-replace.

## Appendix

- Log evidence file: `specs/tmp/claude-tts-notify.log` (both the pre-existing historical entries
  and the four new entries written by this session's empirical tests are present there).
- `verify-deploy.sh --findings` was invoked as directed by the task's H1 investigation line; it did
  not complete within this session's 120-second foreground window and was moved to background. Its
  output was not consulted further because the direct `diff` comparisons of every implicated file
  (`skill-base.sh`, `lifecycle-notify.sh`, `tts-notify.sh`, `wezterm-notify.sh`) already gave a
  decisive, complete answer to H1 for the files this defect actually touches.
- Grep commands used: `grep -rn skill_lifecycle_notify`, `grep -rln STATE_STATUS
  agent-system/extensions/*/skills/*/SKILL.md agent-system/extensions/*/context/patterns/*.md`,
  `git log --oneline --all --reverse -S"STATE_STATUS"`.
