# Research Report: Task #768 — Hard Routing Resolution and Composition

**Task**: 768 - Implement `--hard` routing behavior in `command-route-skill.sh`
**Started**: 2026-06-24T00:00:00Z
**Completed**: 2026-06-24T00:30:00Z
**Effort**: ~1 hour (codebase research, no web search needed)
**Dependencies**: Task 767 (core/manifest.json routing_hard — COMPLETED, commit bb42d80cc)
**Sources/Inputs**: Codebase (all files listed below)
**Artifacts**: specs/768_routing_hard_resolution_composition/reports/01_hard-routing-research.md
**Standards**: report-format.md

---

## Executive Summary

- `command-route-skill.sh` currently accepts 3 args (operation, task_type, default_skill) and has NO awareness of a 4th effort_flag argument or `routing_hard` manifests.
- `skill-orchestrate-hard` (Stage 1b) is the ONLY current consumer of `routing_hard` from extension manifests — but it reads it directly inline, not via `command-route-skill.sh`.
- The `/research`, `/plan`, `/implement` commands parse `effort_flag` in STAGE 1.5 but pass it only as a "prompt context hint" to skills — they do NOT pass it to `command-route-skill.sh`.
- `/implement` STAGE 2 is the ONLY command that calls `command-route-skill.sh` today; `/research` and `/plan` replicate the manifest-scan inline in their own STAGE 2.
- All 6 hard-mode skills (`skill-{researcher,planner,implementer,cslib-research,cslib-implementation,orchestrate}-hard`) exist as deployed SKILL.md files; all 3 core hard agents (`general-research-hard-agent`, `general-implementation-hard-agent`, `planner-hard-agent`) exist in `.claude/agents/`.
- The -hard fallback "skill exists" check must test `.claude/skills/${skill}-hard/SKILL.md`, not the agent file.
- Extension precedence: extensions override core. The first manifest with a hit wins (loop order = glob order over `.claude/extensions/*/manifest.json`).

---

## Context & Scope

Task 767 completed, landing `routing_hard` in `core/manifest.json` for 3 operations × 3 task types (general, meta, markdown). Task 768 must wire the 4th argument to `command-route-skill.sh` and implement the resolution algorithm CLAUDE.md documents. This research establishes every file that must change and the exact algorithm to implement.

---

## Findings

### 1. Exact Current Contents of `command-route-skill.sh`

**File**: `.claude/scripts/command-route-skill.sh`
**Arguments today**: `$1=operation`, `$2=task_type`, `$3=default_skill`
**Exports**: `SKILL_NAME`

**Full current logic** (66 lines):

```bash
_route_operation="$1"
_route_task_type="$2"
_route_default_skill="$3"

SKILL_NAME=""

# Step 1: Search extension manifests for exact task_type match
for _manifest in .claude/extensions/*/manifest.json; do
  if [ -f "$_manifest" ]; then
    _ext_skill=$(jq -r --arg op "$_route_operation" --arg tt "$_route_task_type" \
      '.routing[$op][$tt] // empty' "$_manifest" 2>/dev/null)
    if [ -n "$_ext_skill" ]; then
      SKILL_NAME="$_ext_skill"
      break
    fi
  fi
done

# Step 2: If compound key (contains ":"), try base type as fallback
if [ -z "$SKILL_NAME" ] && echo "$_route_task_type" | grep -q ":"; then
  _base_type=$(echo "$_route_task_type" | cut -d: -f1)
  for _manifest in .claude/extensions/*/manifest.json; do
    if [ -f "$_manifest" ]; then
      _ext_skill=$(jq -r --arg op "$_route_operation" --arg tt "$_base_type" \
        '.routing[$op][$tt] // empty' "$_manifest" 2>/dev/null)
      if [ -n "$_ext_skill" ]; then
        SKILL_NAME="$_ext_skill"
        break
      fi
    fi
  done
fi

# Step 3: Fall back to default skill if no extension routing found
SKILL_NAME="${SKILL_NAME:-$_route_default_skill}"

unset _route_operation _route_task_type _route_default_skill _manifest _ext_skill _base_type
export SKILL_NAME
```

**Key structural facts**:
- It is `source`d (not executed) so local vars must be prefixed `_route_` to avoid pollution
- It uses `jq` with `--arg` for safe interpolation, no shell interpolation in jq paths
- The compound-key fallback (step 2) already uses `_base_type` — same pattern needed for `routing_hard`
- `break` after first match means first manifest glob hit wins (no priority within extension group)

**Where the 4th arg slots in**: After `_route_default_skill="$3"`, add `_effort_flag="${4:-}"`. The new logic activates only when `_effort_flag == "hard"`.

---

### 2. How `routing_hard` Is Currently Consumed

**Only one consumer**: `skill-orchestrate-hard/SKILL.md`, Stage 1b (lines 106–117).

Exact code:
```bash
# Check routing_hard extension manifests for overrides
for manifest in .claude/extensions/*/manifest.json; do
  if [ -f "$manifest" ]; then
    ext_hard_research=$(jq -r --arg tt "$TASK_TYPE" '.routing_hard.research[$tt] // empty' "$manifest" 2>/dev/null)
    ext_hard_implement=$(jq -r --arg tt "$TASK_TYPE" '.routing_hard.implement[$tt] // empty' "$manifest" 2>/dev/null)
    if [ -n "$ext_hard_research" ]; then
      RESEARCH_AGENT=$(echo "$ext_hard_research" | sed 's/^skill-//' | sed 's/$/-agent/')
    fi
    if [ -n "$ext_hard_implement" ]; then
      IMPLEMENT_AGENT=$(echo "$ext_hard_implement" | sed 's/^skill-//' | sed 's/$/-agent/')
    fi
  fi
done
```

**Critical observation**: skill-orchestrate-hard converts skill names to agent names via `sed 's/^skill-//' | sed 's/$/-agent/'` for direct subagent dispatch. The new `command-route-skill.sh` resolves to skill names (not agent names) — the downstream skill-to-agent mapping is handled separately by the Skill tool dispatch chain. So the new resolver returns skill names as-is.

**No priority enforcement in orchestrate-hard**: The `for` loop iterates all manifests and LAST match wins (no `break`). This is inconsistent with `command-route-skill.sh`'s current behavior where FIRST match wins. The new implementation should define canonical precedence (see algorithm below).

---

### 3. Precise Precedence / Composition Algorithm

Given inputs: `(operation, task_type, effort_flag)` where `effort_flag == "hard"`:

**Step H1: Extension `routing_hard` lookup (exact task_type)**
```
for each manifest in .claude/extensions/*/manifest.json (glob order):
  skill = manifest.routing_hard[operation][task_type]
  if skill is non-empty:
    SKILL_NAME = skill
    break  # First match wins — extension overrides core
```

**Step H2: Extension `routing_hard` lookup (base type, compound keys only)**
```
if SKILL_NAME is empty AND task_type contains ":":
  base_type = task_type.split(":")[0]
  for each manifest in .claude/extensions/*/manifest.json:
    skill = manifest.routing_hard[operation][base_type]
    if skill is non-empty:
      SKILL_NAME = skill
      break
```

**Step H3: Append `-hard` to the standard skill (resolved via normal routing)**
```
if SKILL_NAME is empty:
  # First, resolve the standard skill the same way the normal path does
  [run existing Steps 1-3 from current script against .routing (not .routing_hard)]
  candidate_hard = standard_skill + "-hard"  # e.g., "skill-planner-hard"
  if file exists ".claude/skills/${candidate_hard}/SKILL.md":
    SKILL_NAME = candidate_hard
  else:
    echo "[route] No hard variant for ${candidate_hard}; using standard skill" >&2
    SKILL_NAME = standard_skill  # graceful fallback
```

**Precedence summary (highest to lowest)**:
1. Extension `routing_hard.$op.$task_type` (explicit extension hard override)
2. Extension `routing_hard.$op.$base_type` (compound key fallback)
3. Core `routing_hard.$op.$task_type` (in core/manifest.json — covered by Step H1 since core is an extension dir)
4. Append `-hard` to the standard skill if SKILL.md exists
5. Standard skill (no hard variant)

**Note on core vs extension**: Since `core/manifest.json` lives in `.claude/extensions/core/manifest.json`, it is found by the glob in Steps H1/H2. The precedence is determined by glob order. On typical Linux filesystems, alphabetic glob order puts `core` before `cslib`. If a task type (e.g., `cslib`) appears in a non-core extension manifest, it will be found first by the glob AND is more specific than core — this is the desired behavior. The algorithm naturally gives extension overrides (non-core) priority IF non-core manifests come first in glob order. However, the current `for` loop uses `break` on first match, so glob order determines priority. This may need explicit ordering (non-core first) if priority among extensions matters. For the common case (distinct task types per extension), this is not a problem.

**Cleaner approach for explicit precedence**: Scan non-core manifests first, then core. This ensures non-core extensions always override core:
```bash
# Non-core extensions first, then core (explicit precedence)
for _manifest in .claude/extensions/*/manifest.json; do
  [ "$_manifest" = ".claude/extensions/core/manifest.json" ] && continue
  # ... check routing_hard
done
# Then core as final fallback before the -hard append
```

---

### 4. How `/research`, `/plan`, `/implement` Currently Pass `effort_flag`

#### `/research` (commands/research.md, STAGE 1.5 + STAGE 2):

STAGE 1.5 parses `--hard` → `effort_flag = "hard"`.

STAGE 2 calls the Skill tool directly (NOT via `command-route-skill.sh`):
```
skill: "{skill-name from extension routing inline scan}"
args: "... effort_flag={effort_flag} ..."
```

The inline routing scan in STAGE 2 reads only `.routing.research[$tt]` — no `routing_hard` lookup.
`effort_flag` is passed as an `args` string to the Skill tool as "prompt context".

**Gap**: `/research` would need to either: (a) call `command-route-skill.sh "research" "$TASK_TYPE" "skill-researcher" "hard"` to resolve the hard skill, or (b) inline the same logic.

#### `/plan` (commands/plan.md, STAGE 1.5 + STAGE 2):

Same pattern as `/research`. STAGE 1.5 parses effort flags. STAGE 2 does inline manifest scan for `.routing.plan[$tt]`, then calls Skill tool with `effort_flag` as args.

No call to `command-route-skill.sh`. `effort_flag` is a prompt hint only.

#### `/implement` (commands/implement.md, STAGE 2):

**Only command that calls `command-route-skill.sh`**:
```bash
source .claude/scripts/command-route-skill.sh "implement" "$TASK_TYPE" "skill-implementer"
skill_name="$SKILL_NAME"
```

Then calls Skill tool with `effort_flag={EFFORT_FLAG}` as args. The script call does NOT pass `EFFORT_FLAG` as a 4th argument — it's passed only downstream to the skill as a prompt hint.

**Gap**: `/implement` needs to pass `"$EFFORT_FLAG"` as 4th arg when `EFFORT_FLAG == "hard"`.

#### `/orchestrate` (commands/orchestrate.md):

Does not call `command-route-skill.sh`. Agent resolution done inline in skill-orchestrate-hard Stage 1b (which already reads `routing_hard` but uses agent names, not skill names).

**Summary of changes needed in commands**:
- `/implement`: add `"$EFFORT_FLAG"` as 4th arg to the existing `command-route-skill.sh` call
- `/research` and `/plan`: decide whether to call `command-route-skill.sh` (centralizing routing) or inline the `routing_hard` lookup alongside the existing inline routing scan

---

### 5. What CLAUDE.md Claims (The 4-Step Resolution)

From the "Routing Mechanism" section of CLAUDE.md:

> `--hard` is resolved by `command-route-skill.sh` as a 4th `effort_flag` argument:
> 1. Check `routing_hard.$operation.$task_type` in extension manifests
> 2. If not found: construct candidate by appending `-hard` to the resolved skill name
> 3. If candidate skill exists (`.claude/skills/${skill}-hard/SKILL.md`): use it
> 4. If not: fall back to standard skill with stderr note `[route] No hard variant for $skill; using standard skill`

**Discrepancies / gaps to note for task 770**:

1. **Compound key fallback not mentioned**: CLAUDE.md step 1 says "check `routing_hard.$op.$task_type`" but doesn't mention the compound key base-type fallback that the normal routing implements. The implementation should add this for consistency.

2. **"Resolved skill name" in step 2**: CLAUDE.md says "resolved skill name" — this means the skill resolved by the NORMAL routing (not the hard routing). The implementation must first determine the standard skill, then attempt the `-hard` suffix.

3. **No mention of compound key for routing_hard**: The normal routing script already handles compound keys for `.routing`. The `routing_hard` lookup should follow the same pattern.

4. **Precedence between extension routing_hard and core routing_hard not stated**: CLAUDE.md says "check routing_hard.$op.$task_type in extension manifests" — implicitly treating core as just another extension. This aligns with the glob-based approach.

5. **Current reality gap**: CLAUDE.md claims this script behavior EXISTS today, but it does NOT — the script has no 4th arg and no `routing_hard` logic. Task 768 bridges this gap.

---

### 6. Skill-to-Agent Resolution and Deployed Agent Safety

**Skill-to-agent mapping for hard skills** (from CLAUDE.md Skill-to-Agent Mapping table):

| Skill | Agent |
|-------|-------|
| `skill-researcher-hard` | `general-research-hard-agent` |
| `skill-planner-hard` | `planner-hard-agent` |
| `skill-implementer-hard` | `general-implementation-hard-agent` |
| `skill-cslib-research-hard` | `cslib-research-hard-agent` |
| `skill-cslib-implementation-hard` | `cslib-implementation-hard-agent` |
| `skill-orchestrate-hard` | (direct execution, no agent) |

**Deployed agent files** (verified via `ls .claude/agents/`):
- `general-research-hard-agent.md` — EXISTS
- `general-implementation-hard-agent.md` — EXISTS
- `planner-hard-agent.md` — EXISTS
- `cslib-research-hard-agent.md` — EXISTS
- `cslib-implementation-hard-agent.md` — EXISTS

**Deployed skill directories** (verified via `ls .claude/skills/ | grep hard`):
- `skill-researcher-hard` — EXISTS (has SKILL.md)
- `skill-planner-hard` — EXISTS (has SKILL.md)
- `skill-implementer-hard` — EXISTS (has SKILL.md)
- `skill-cslib-research-hard` — EXISTS (has SKILL.md)
- `skill-cslib-implementation-hard` — EXISTS (has SKILL.md)
- `skill-orchestrate-hard` — EXISTS (has SKILL.md)

**Safety guarantee for fallback**: The `-hard` append fallback tests `.claude/skills/${candidate}-hard/SKILL.md`. If that file exists, the skill is deployed. The skill's SKILL.md internally declares its `subagent_type` (agent). Since all 5 deployed hard skills have matching deployed hard agents, the fallback is safe for all currently known skill→agent pairs.

**The "undeclared agent" risk**: Only arises if an extension declares `routing_hard` pointing to a skill whose underlying agent is NOT in `.claude/agents/`. Current state: cslib's `routing_hard` points to `skill-cslib-research-hard` and `skill-cslib-implementation-hard` — both deployed. The `-hard` append fallback only resolves if `SKILL.md` exists, so undeclared agents cannot be reached via the fallback path (they'd require explicit `routing_hard` entries in a manifest). Validation of `routing_hard` manifest entries against deployed SKILL.md files is a task-770 concern, not required for task 768.

---

## Decisions

1. **4th arg as `effort_flag` string**: Accept `"hard"` as the meaningful value; treat anything else (or empty/absent) as standard routing.

2. **Non-core extensions first in glob scan**: Scan `routing_hard` from non-core manifests first, then core, to implement the documented "extension overrides core" precedence. Use `continue` to skip `core/manifest.json` in the first pass, then check core in the second pass.

3. **`command-route-skill.sh` resolves skills (not agents)**: The script returns a skill name. Agent resolution happens downstream via the Skill tool.

4. **`/implement` only needs a 1-line change**: Add `"$EFFORT_FLAG"` as 4th arg to the existing `command-route-skill.sh` call.

5. **`/research` and `/plan` should centralize through `command-route-skill.sh`**: Replace the inline manifest-scan blocks in their STAGE 2 with a call to `command-route-skill.sh` — this is the intended architecture. The effort_flag wiring comes for free.

6. **Compound key fallback for `routing_hard`**: Match the existing compound-key logic for `.routing` — try exact `task_type` first, then `base_type` if compound.

7. **stderr note format**: `[route] No hard variant for ${skill_name}-hard; using standard skill` — matching the documented format.

---

## Implementation Plan (for task planner)

### Phase 1: Extend `command-route-skill.sh` (1 file, ~40 lines added)

Add after line 29 (`_route_default_skill="$3"`):
```bash
_effort_flag="${4:-}"
```

Add new block between Step 2 and Step 3 — activates when `_effort_flag == "hard"`:

```bash
# Step 2b: Hard-mode routing (when effort_flag=hard)
if [ "$_effort_flag" = "hard" ]; then
  _hard_skill=""

  # 2b-1: Extension routing_hard lookup (non-core first for precedence)
  for _manifest in .claude/extensions/*/manifest.json; do
    [ "$_manifest" = ".claude/extensions/core/manifest.json" ] && continue
    if [ -f "$_manifest" ]; then
      _ext_hard=$(jq -r --arg op "$_route_operation" --arg tt "$_route_task_type" \
        '.routing_hard[$op][$tt] // empty' "$_manifest" 2>/dev/null)
      if [ -n "$_ext_hard" ]; then
        _hard_skill="$_ext_hard"
        break
      fi
    fi
  done

  # 2b-2: Compound key fallback for routing_hard (non-core)
  if [ -z "$_hard_skill" ] && echo "$_route_task_type" | grep -q ":"; then
    _base_type_hard=$(echo "$_route_task_type" | cut -d: -f1)
    for _manifest in .claude/extensions/*/manifest.json; do
      [ "$_manifest" = ".claude/extensions/core/manifest.json" ] && continue
      if [ -f "$_manifest" ]; then
        _ext_hard=$(jq -r --arg op "$_route_operation" --arg tt "$_base_type_hard" \
          '.routing_hard[$op][$tt] // empty' "$_manifest" 2>/dev/null)
        if [ -n "$_ext_hard" ]; then
          _hard_skill="$_ext_hard"
          break
        fi
      fi
    done
  fi

  # 2b-3: Core routing_hard lookup (fallback after non-core extensions)
  if [ -z "$_hard_skill" ]; then
    _core_manifest=".claude/extensions/core/manifest.json"
    if [ -f "$_core_manifest" ]; then
      _ext_hard=$(jq -r --arg op "$_route_operation" --arg tt "$_route_task_type" \
        '.routing_hard[$op][$tt] // empty' "$_core_manifest" 2>/dev/null)
      [ -n "$_ext_hard" ] && _hard_skill="$_ext_hard"
    fi
  fi

  # 2b-4: Compound key fallback for core routing_hard
  if [ -z "$_hard_skill" ] && echo "$_route_task_type" | grep -q ":"; then
    _base_type_hard=$(echo "$_route_task_type" | cut -d: -f1)
    _core_manifest=".claude/extensions/core/manifest.json"
    if [ -f "$_core_manifest" ]; then
      _ext_hard=$(jq -r --arg op "$_route_operation" --arg tt "$_base_type_hard" \
        '.routing_hard[$op][$tt] // empty' "$_core_manifest" 2>/dev/null)
      [ -n "$_ext_hard" ] && _hard_skill="$_ext_hard"
    fi
  fi

  # 2b-5: Append -hard to the standard skill resolved above (SKILL_NAME at this point)
  if [ -z "$_hard_skill" ]; then
    _candidate_hard="${SKILL_NAME}-hard"
    if [ -f ".claude/skills/${_candidate_hard}/SKILL.md" ]; then
      _hard_skill="$_candidate_hard"
    else
      echo "[route] No hard variant for ${_candidate_hard}; using standard skill" >&2
    fi
  fi

  # Apply hard skill if found
  [ -n "$_hard_skill" ] && SKILL_NAME="$_hard_skill"

  unset _ext_hard _candidate_hard _base_type_hard _core_manifest _hard_skill
fi
```

The step 2b-5 block uses `SKILL_NAME` — which at that point holds the result of normal routing (Steps 1-3 produce the standard skill). The hard block must be inserted AFTER the normal routing resolves `SKILL_NAME` (i.e., after the current Step 3 line). **Correction**: Insert step 2b AFTER the current Step 3 (after `SKILL_NAME="${SKILL_NAME:-$_route_default_skill}"`).

### Phase 2: Wire effort_flag into command callers

**`/implement` STAGE 2** — 1 line change:
```bash
# Before:
source .claude/scripts/command-route-skill.sh "implement" "$TASK_TYPE" "skill-implementer"
# After:
source .claude/scripts/command-route-skill.sh "implement" "$TASK_TYPE" "skill-implementer" "${EFFORT_FLAG:-}"
```

**`/research` STAGE 2** — Replace inline manifest scan with:
```bash
source .claude/scripts/command-route-skill.sh "research" "$task_type" "skill-researcher" "${effort_flag:-}"
skill_name="$SKILL_NAME"
```

**`/plan` STAGE 2** — Replace inline manifest scan with:
```bash
source .claude/scripts/command-route-skill.sh "plan" "$task_type" "skill-planner" "${effort_flag:-}"
skill_name="$SKILL_NAME"
```

**Note**: The `/research` and `/plan` commands currently use inline Bash scan (not the script). Centralizing through `command-route-skill.sh` is a refactor, not just a bug fix. The implementation plan should treat this as optional (the `--hard` wiring can be inlined first if preferred, and centralization done in a follow-up).

### Phase 3: Document extension composition model

Update `core/manifest.json` or a context doc to state:
> "Extension `routing_hard` entries override core `routing_hard` entries for the same (operation, task_type) pair. The resolution order is: non-core extension manifests (glob order) > core manifest > `-hard` append fallback > standard skill."

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Glob order of extensions is nondeterministic across OS versions | Skip `core/manifest.json` explicitly in first pass; scan all non-core then core — guarantees consistent priority |
| `-hard` fallback resolves to nonexistent agent | Safety check: fallback only activates when `SKILL.md` exists; all current hard skills have deployed agents |
| `routing_hard` in an uninstalled extension manifest is on-disk | Extension manifests are always present (they're not deleted on uninstall in current system) — not a concern for currently deployed extensions |
| Variable pollution from new `_hard_skill` etc. | Add to `unset` at end of script |
| `/research` and `/plan` refactor scope creep | Treat as Phase 2b (optional); the core fix (Phase 1 + Phase 2a for `/implement`) is self-contained |
| skill-orchestrate-hard's inline `routing_hard` reader becomes redundant | Leave it in place for now; it reads agent names (not skill names) and the orchestrate code path doesn't use command-route-skill.sh anyway |

---

## Context Extension Recommendations

- **Topic**: `routing_hard` composition model for extension authors
- **Gap**: No documentation for extension authors on how `routing_hard` interacts with core `routing_hard` and the `-hard` append fallback
- **Recommendation**: Add a section to `.claude/extensions/core/context/routing.md` (or create `.claude/docs/guides/hard-mode-routing.md`) explaining the 5-step resolution order

---

## Appendix

### Files Read
- `.claude/scripts/command-route-skill.sh` — full content
- `.claude/extensions/core/manifest.json` — full content (routing_hard section)
- `.claude/extensions/cslib/manifest.json` — routing_hard section
- `.claude/skills/skill-orchestrate-hard/SKILL.md` — Stage 1b (lines 73-120)
- `.claude/skills/skill-orchestrate/SKILL.md` — Stage 1b (lines 58-98)
- `.claude/commands/research.md` — STAGE 1.5 + STAGE 2
- `.claude/commands/plan.md` — STAGE 1.5 + STAGE 2
- `.claude/commands/implement.md` — STAGE 2
- `.claude/agents/` directory listing

### Key jq patterns already used (for consistency)
```bash
jq -r --arg op "$op" --arg tt "$tt" '.routing[$op][$tt] // empty'
jq -r --arg tt "$tt" '.routing_hard.research[$tt] // empty'  # orchestrate-hard pattern
jq -r --arg op "$op" --arg tt "$tt" '.routing_hard[$op][$tt] // empty'  # new unified pattern
```
