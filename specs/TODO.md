---
next_project_number: 891
---

# TODO

## Task Order

*Updated 2026-07-24. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 873,885 | -- | agent-system |
| 2 | 887 | 873 | agent-system |

**Grouped by Topic** (indented = depends on parent):

### Agent System

873 [PARTIAL] — Make /meta create tasks in the GLOBAL agent-system root by defaul
  └─ 887 [RESEARCHED] — RESEARCH-FIRST / HIGH PRIORITY. This is the design round. The use
885 [PARTIAL] — URGENT / HIGH PRIORITY. The 30-day transcript window is reaped da

## Tasks

### 887. Research: telemetry source architecture and /distill redesign
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 873
- **Research**: [887_research_telemetry_source_architecture_and_distill_redesign/reports/01_telemetry-source-architecture.md]

**Description**: RESEARCH-FIRST / HIGH PRIORITY. This is the design round. The user will /revise this and then /expand it into implementation tasks. Do NOT jump to implementation.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/ (and agent-system/extensions/memory/ for /distill and /learn). The .claude/ tree is a GITIGNORED, UNTRACKED, DISPOSABLE deploy artifact regenerated from the source store by the <leader>al picker/loader, which invokes agent-system/extensions/core/scripts/install-extension.sh from lua/neotex/plugins/ai/shared/extensions/loader.lua. Nothing under .claude/ is hand-authored; every deployed file has a source, enforced by the check-extension-docs.sh hard gate. ALL file edits MUST target agent-system/extensions/** and NEVER .claude/** -- a change written to .claude/ is silently wiped by the next regeneration.

SETTLED USER DECISION -- SIGNAL SOURCE: "OTel for outcomes + events.jsonl for semantics". Claude Code's OTel stream owns did-it-fail-and-why; events.jsonl owns ONLY what OTel cannot know (task numbers, phase boundaries, plan deviations, reflections, repo tag). Join on session_id + cwd. Research must settle this seam PRECISELY: which fields each owns, the exact join, and whether to borrow gen_ai.* names.

DESIGN THE FOUR-TIER SOURCE MODEL:
1. Claude Code OTel = outcome signal. Official opt-in stream: CLAUDE_CODE_ENABLE_TELEMETRY=1. Events include tool_result carrying {success, error_type, duration_ms, decision_source}, plus api_request/api_error/api_refusal/tool_decision/permission_mode_changed/mcp_server_connection/internal_error/hook_registered/hook_execution_start/hook_execution_complete/compaction/feedback_survey/user_prompt/assistant_response. Metrics: claude_code.session.count, .token.usage, .cost.usage, .code_edit_tool.decision, .active_time.total. Beta traces via CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1. Prompt content redacted by default unless OTEL_LOG_TOOL_DETAILS=1. Docs: code.claude.com/docs/en/monitoring-usage.
2. events.jsonl = agent-system semantics + repo tag.
3. history.jsonl = durable global prompt spine (23,758 prompts, 7 months, 33 projects; outlives transcripts).
4. transcripts/.meta.json = 30-day replay + bootstrap.

DEFINE THE SOURCE CONTRACT FOR EACH OF THE FIVE NEW FLAGS. SETTLED USER DECISION -- KEEP ALL FIVE DISTINCT (--meta, --review, --revise, --dream, --learn) alongside the existing seven (report/purge/merge/compress/refine/gc/auto) = 12 sub-modes. Overlap is resolved by REDEFINITION, not deletion: task 872's --dream currently emits BOTH memory revisions AND improvement proposals; that content migrates to --revise (revisions) and --meta (proposals), leaving --dream for speculative "new directions" only.
- --meta: cross-repo agent-system improvement. Creates tasks in the global agent-system root, checks which of the 20 extensions to contribute to, confirms via AskUserQuestion after basic investigation, and lets the user select/modify proposed tasks.
- --review: read-only inquiry over vault + sources.
- --revise: memory refactoring, inheriting 872's corroborated/contradicted/gap correlation machinery.
- --dream: speculative new directions ONLY (redefined).
- --learn: retroactive/batch harvest across already-completed tasks. Distinct from per-task /learn --task N and from /todo's archive-time harvest.

CRITICAL -- DO NOT REDESIGN CROSS-REPO RESOLUTION: task 873 ALREADY establishes GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}", the `cd "$GLOBAL_ROOT"` mechanism, and the --local opt-out, mirroring the LITERATURE_DIR pattern. /distill --meta MUST CONSUME that mechanism, not invent a parallel one. Likewise --meta MUST delegate task creation to the existing 1,429-line meta-builder-agent (whose global-mode semantics task 875 is teaching) rather than reimplementing it.

UNDERLYING CONSTRAINT THAT MOTIVATED 873: memory-retrieve.sh, memory-harvest.sh, and events-query.sh all resolve PROJECT_ROOT from their OWN deployed location (SCRIPT_DIR/../..), so a copy deployed in nvim/.claude/scripts/ can only ever see nvim's vault. Research MUST confirm whether 873's cd mechanism fully resolves this for the memory/event scripts or whether they need separate treatment.

ALSO DESIGN THE RESTRUCTURE (settled user decision -- YES): split skill-memory/SKILL.md (2,941 lines, carrying BOTH /learn and /distill; /distill occupies lines 1063-2941) into separate skill-learn and skill-distill. Factor the repeated per-sub-mode skeleton (Edge Case Checks -> Candidate Identification -> Dry-Run -> Interactive Selection MANDATORY STOP -> Execution -> Batch Index Regeneration -> Log Entry) into ONE shared section instead of six near-duplicate copies. Sub-modes are currently non-contiguous: purge sits ~1,170 lines after the dispatch table that lists it second, and gc is separated from purge, its logical pair.

ENCODE AS EXPLICIT DESIGN CONSTRAINTS (research-backed; cite these):
- ~70% v1 MISS-RATE EXPECTATION: the closest documented precedent (productowner.ro, "Building an AI Self-Improvement Loop from Claude Code Session History") self-reports keyword-based friction detection catching only ~20-30% of real friction, and "Claude speculates instead of querying actual data" in 6 of 10 analyzed groups. Design for iteration, not a one-shot heuristic.
- EVALUATOR OUTSIDE THE LOOP; PROPOSE-THEN-HUMAN-REVIEW, NEVER AUTO-APPLY. Per Lilian Weng, "Harness Engineering for Self-Improvement" (2026-07-04): file-based persistent memory is production-proven; six failure modes serve as a design checklist (stale-default bias, implementation drift toward simpler solutions under pressure, memory degradation absent persistent artifacts, over-optimism/declaring success on noisy signals, weak domain knowledge, poor scientific taste). HARD RULE: the evaluator must sit OUTSIDE the loop being evolved. "Humans should move up the stack, not be removed from the loop." Documented 2026 anti-pattern: an agent ran 220+ autonomous loops and began FABRICATING METRICS once its own optimistic summaries became the next loop's input. See also OpenReview, "Reward Hacking in Self-Improving Code Agents".
- NO NEW HYGIENE AUTOMATION BELOW ~100 VAULT ENTRIES. Every 2026 source ties scoring/decay/dedup automation to high volume, concurrent writers, or genuinely time-sensitive facts -- none describe this vault (19 memories, 2,616 tokens, single operator, static facts). "Add decay only when you have temporal claims worth decaying; if your agent does not track state changes, exponential decay just throws away stable facts" (Hindsight/Vectorize, 2026-05-21). Vendor benchmarks actively disputed (Zep vs Mem0 on LOCOMO) -- no canonical formula. Leave existing --purge/--merge/--compress/--refine/--gc/--auto behavior UNCHANGED.
- BORROW OTel GenAI FIELD NAMES ONLY, DO NOT REBUILD AS A SPAN/TRACE SYSTEM. Semconv maturity is MIXED: gen_ai.client spans stable (early 2026); gen_ai.agent spans EXPERIMENTAL; the canonical spec migrated to open-telemetry/semantic-conventions-genai with NO tagged releases (126 open issues / 40 open PRs). Borrow names (gen_ai.operation.name, gen_ai.provider.name, gen_ai.request.model, gen_ai.usage.input_tokens/output_tokens, error.type). A structurally OTel-compliant span/trace system with collector infra is disproportionate for a single-maintainer system across ~14 repos.
- HOOKS ARE THE SANCTIONED EXTENSION POINT: 30 documented hook event types; every hook receives session_id, prompt_id (v2.1.196+), transcript_path, cwd, permission_mode, hook_event_name. Stop/SubagentStop carry last_assistant_message explicitly BECAUSE transcript_path is written asynchronously and may lag. Docs: code.claude.com/docs/en/hooks.
- THE sess_{ts}_{rand} JOIN IS A DEAD END -- do not revive it. 1,800 distinct sess_* ids appear across 4,334 transcript files, but the top hits are documentation placeholders (sess_1736700000_abc123 appears 5,032x, decoding to Dec 2023 -- pulled in from CLAUDE.md/skill examples). ~1,109 are real but INCIDENTAL: they arrive as state.json content read INTO context, so the relation is many-to-many ("this session read a file mentioning sess_X", not "is sess_X"). The agent system mints ids at GATE IN that Claude Code never sees. NO structural link exists. Claude Code sessionId is UUIDv4, a different id space; a `session_id` (snake_case) field also coexists on some records and is a DIFFERENT UUID -- do not conflate.
- NO OSS TOOL DOES THE FULL MINE->PROPOSE LOOP. ccusage and claude-code-log parse transcripts and are actively maintained; reuse their parser rather than writing one. Neither extracts success/failure signal.

DEPENDS ON 873 (consumes the GLOBAL_ROOT/cd cross-repo mechanism).

DELIVERABLE RULE: honor no-task-references-in-deliverables in any file outside specs/**.

---

### 885. Enable and verify passive signal capture
- **Status**: [PARTIAL]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: Task 874
- **Research**: [885_enable_and_verify_passive_signal_capture/reports/01_enable-verify-passive-signal-capture.md]
- **Plan**: [885_enable_and_verify_passive_signal_capture/plans/01_passive-signal-capture-deploy.md]

**Description**: URGENT / HIGH PRIORITY. The 30-day transcript window is reaped daily, so every day without capture is permanently lost data.

SOURCE-STORE RULE (binding): the agent-system SOURCE of truth is agent-system/extensions/core/ (and agent-system/extensions/memory/ for /distill and /learn). The .claude/ tree is a GITIGNORED, UNTRACKED, DISPOSABLE deploy artifact regenerated from the source store by the <leader>al picker/loader, which invokes agent-system/extensions/core/scripts/install-extension.sh from lua/neotex/plugins/ai/shared/extensions/loader.lua. Nothing under .claude/ is hand-authored; every deployed file has a source, enforced by the check-extension-docs.sh hard gate. ALL file edits MUST target agent-system/extensions/** and NEVER .claude/** -- a change written to .claude/ is silently wiped by the next regeneration.

THE GAP AND ITS ACTUAL ROOT CAUSE (verified; do not re-derive): tasks 869/870/871/872 wrote a complete event/reflection store into agent-system/extensions/core/ but it was NEVER deployed. nvim's .claude/ last synced Jul 14 18:13, before the events work landed (Jul 15 01:19-08:10). The root cause is NOT a forgotten command -- it is the stale self-sync guard (the subject of task 874): nvim cannot regenerate its OWN deploy tree because load_all_globally() early-returns when project_dir == global_dir. Hence the dependency on 874; until that guard is removed nvim's .claude/ cannot be regenerated at all.

VERIFIED ABSENT from nvim's deployed .claude/: events-append.sh, events-query.sh, hooks/events-log-artifact.sh, hooks/events-log-lifecycle.sh, context/formats/events-format.md, context/schemas/events-schema.json. Live .claude/settings.json has 0 hook registrations (3 exist in source root-files/settings.json). Deployed skill-base.sh and orchestrator-postflight.sh have 0 event call sites.

WHY IT FAILS INVISIBLY: every call site is `bash .claude/scripts/events-append.sh ... || true` against a nonexistent path, so it fails SILENTLY. Consequences: specs/events.jsonl exists in NO repo; zero events ever recorded; zero tasks have a `reflection` or `memory_candidates` field; .memory/distill-log.json has operations: []; /distill has never completed a run; task 872's --dream is spec-only (deployed skill-memory/SKILL.md has zero `dream` matches).

SCOPE:
1. Get the events stack actually deployed and flowing; verify end-to-end AFTER regeneration, in nvim AND in at least one other repo.
2. Replace the `|| true` silent-fail idiom with something observable, so a missing helper can never again fail invisibly. This is the defect that hid the gap for a full day.
3. Enable CLAUDE_CODE_ENABLE_TELEMETRY=1 and wire an OTel exporter. NOTE: the env block in ~/.claude/settings.json is Home-Manager-managed from ~/.dotfiles/config/claude/settings.json, so that change likely belongs in the dotfiles repo, not here -- research must confirm the correct home before editing.
4. Raise cleanupPeriodDays to widen the 30-day transcript window. NEVER set 0: per anthropics/claude-code issue #23710, cleanupPeriodDays:0 silently DISABLES persistence entirely, contradicting the docs. Setting 0 would destroy the very data this task exists to preserve.
5. Add a `repo` field to the event schema, events-append.sh, and events-schema.json for cross-repo federation, or resolve it from cwd.
6. Add a deploy-drift check (source vs deployed) so this silent divergence cannot recur; consider extending the existing check-extension-docs.sh doc-lint hard gate rather than adding a new script.

DEPENDS ON 874 (self-sync guard removal). Reference: Claude Code OTel docs at code.claude.com/docs/en/monitoring-usage.

DELIVERABLE RULE: honor no-task-references-in-deliverables in any file outside specs/**.

---

### 873. Add global-default target resolution and --local flag to /meta
- **Status**: [PARTIAL]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None
- **Research**: [873_global_default_target_resolution_for_meta/reports/01_global_default_target_resolution.md]
- **Plan**: [873_global_default_target_resolution_for_meta/plans/01_global_default_target_resolution.md]

**Description**: Make /meta create tasks in the GLOBAL agent-system root by default, with `--local` as the only opt-out. There is NO interactive prompt.

DESIRED BEHAVIOR: /meta run from any repo other than ~/.config/nvim defaults to GLOBAL mode, creating tasks in ~/.config/nvim/specs/. `--local` creates tasks in the current repo's specs/ instead. /meta run from within ~/.config/nvim is already global, so the resolution must be a NO-OP there rather than a special-cased branch. The user regenerates each repo's local .claude/ agent system via the <leader>al loader as needed.

CANONICAL SOURCE vs DEPLOY TREE (critical): the agent-system SOURCE of truth is agent-system/extensions/core/. The nvim repo's .claude/ tree is a GITIGNORED, UNTRACKED deploy artifact (see the /.claude/ entry in .gitignore: the deploy tree is a disposable build artifact regenerated from the source store in agent-system/extensions/, selection pinned by the project-root .claude-extensions.json; nothing under it is hand-authored, every deployed file has a source, enforced by the check-extension-docs.sh hard gate). ALL file edits in this task MUST target agent-system/extensions/core/**, NEVER .claude/**. A change written to .claude/ would be silently wiped by the next <leader>al regeneration. Verified: core/commands/meta.md, core/skills/skill-meta/SKILL.md and core/agents/meta-builder-agent.md are currently byte-identical to their deployed .claude/ copies.

PATH-RESOLUTION MECHANISM (chosen; do NOT redesign): two strategies coexist in the script layer. Strategy A (script-location-relative): generate-todo.sh:28 and update-task-status.sh:27 use PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)", resolving from the SCRIPT's own location. Strategy B (bare relative, CWD-following): skill-base.sh (specs/state.json at :119, :302, :358), command-gate-in.sh:47, command-gate-out.sh:34, and all hooks in settings.json (invoked as `bash .claude/hooks/<name>.sh`). A `cd "$GLOBAL_ROOT"` at the start of the global-mode /meta flow makes BOTH strategies resolve to nvim consistently: Strategy B follows the new CWD, and Strategy A is reached via the CWD-relative `bash .claude/scripts/generate-todo.sh` invocation so it picks up nvim's own script. This cd is the chosen mechanism.

CONSTRAINTS: Do NOT refactor the ~49 scripts. Do NOT introduce CLAUDE_PROJECT_DIR -- it was proposed once in an archived hook research report and deliberately never adopted; it appears nowhere in live code.

GLOBAL ROOT RESOLUTION (user-confirmed): GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}". This mirrors the established LITERATURE_DIR pattern LIT_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}" found at skill-researcher/SKILL.md:171, skill-planner/SKILL.md:182, skill-implementer/SKILL.md:164 and the three -hard variants. The env block in ~/.claude/settings.json is Home-Manager-managed from ~/.dotfiles/config/claude/settings.json.

FLAG PATTERN: parse-command-args.sh already has an established convention -- regex match (`[[ "$remaining" =~ --clean ]]` at :103, `--force` at :106) plus sed-strip (:129-130). Follow it verbatim for --local.

EDIT TARGETS (all under agent-system/extensions/core/):
  - commands/meta.md -- document --local in Arguments, update the argument-hint frontmatter, document the global-default semantics and the source-store-vs-deploy-tree distinction.
  - skills/skill-meta/SKILL.md -- resolve GLOBAL_ROOT, cd into it for global mode, thread the resolved mode/root through to the agent invocation.
  - scripts/parse-command-args.sh -- add --local following the --clean pattern (regex match + sed strip).

RESEARCH MUST SETTLE:
  (a) Whether Claude Code's permission/sandbox model lets a session launched in another repo (e.g. ~/Projects/cslib) write to ~/.config/nvim/specs/ without prohibitive permission friction. This is the single biggest feasibility risk for the whole approach.
  (b) How shell-side CLAUDE_AGENT_GLOBAL_ROOT should relate to the Lua-side global_source_dir option (lua/neotex/plugins/ai/claude/config.lua:40-41, with a hardcoded ~/.config/nvim fallback at picker/utils/scan.lua:8-17) without creating two silently drifting sources of truth.
  (c) Whether the git postflight commit in skill-meta lands in the correct repo after the cd.

Honor the no-task-references-in-deliverables rule: no task-number citations in any file outside specs/**.
