# Research Report: Task #769

**Task**: 769 - Add routing/deployment consistency guard
**Started**: 2026-06-24T00:00:00Z
**Completed**: 2026-06-24T00:30:00Z
**Effort**: ~2 hours (implementation)
**Dependencies**: None (all source material gathered)
**Sources/Inputs**: Codebase (check-extension-docs.sh, command-route-skill.sh, all extension manifests, install-extension.sh, extensions.json)
**Artifacts**: specs/769_routing_hard_consistency_guard/reports/01_routing-guard-research.md
**Standards**: report-format.md

---

## Executive Summary

- **Current gap**: `check-extension-docs.sh` validates that `provides.skills` entries exist in extension source (`extensions/{ext}/skills/`), but does NOT validate routing/routing_hard targets against the DEPLOYED tree (`.claude/skills/`) nor verify that routing targets are in `provides.skills`.
- **Concrete known violations confirmed**: `skill-lean-research-hard` and `skill-lean-implementation-hard` are declared in `lean/manifest.json routing_hard` but absent from `.claude/skills/`. They ARE present in the extension source (`.claude/extensions/lean/skills/`) but the lean extension is not installed.
- **Recommended approach**: Add three new check functions to `check-extension-docs.sh`: (1) undeclared skill dirs, (2) routing/routing_hard target validation against `provides.skills` and deployed tree, (3) deployed-skill agent existence. Scope routing-vs-deployed checks to "installed" extensions (determined heuristically from deployed symlinks/dirs); routing-vs-provides checks apply to ALL extensions.
- **Pre-existing failures**: 2 failures from `core` extension (`dispatch-agent.sh` missing, `/zulip` README gap) must not be masked. New checks should add to `FAILURES`, not replace existing logic.

---

## Context & Scope

The guard must catch the class of bug where:
- A skill directory is present in extension source but not declared in `provides.skills` (silent omission)
- A routing or routing_hard entry names a skill that is not declared in `provides.skills` and/or not deployed to `.claude/skills/`
- A hard-mode fallback target maps to an agent that does not exist in `.claude/agents/`

This research establishes the exact current code structure, the naming conventions, the check rules, the tree authority question, and the CI integration strategy.

---

## Findings

### 1. Exact Current Structure of check-extension-docs.sh

The script iterates `$EXT_DIR/*/` (all subdirectories of `.claude/extensions/`), runs four check functions per extension, and accumulates a `FAILURES` counter. Exit code: 0 if `$FAILURES == 0`, else 1.

**`check_manifest_entries()`** (lines ~56–95):
```bash
# agents: checks each .provides.agents[] entry exists at ext_path/agents/$a
# skills: checks each .provides.skills[] entry has SKILL.md at ext_path/skills/$s/SKILL.md
# commands, rules, scripts: similar file existence checks
```
It validates that `provides.*` entries exist in the EXTENSION SOURCE directory. It does NOT check:
- Whether skill dirs on disk are declared in `provides.skills`
- Whether routing/routing_hard targets are in `provides.skills`
- Whether routing/routing_hard targets are deployed to `.claude/skills/`

**`check_routing_block()`** (lines ~97–115):
```bash
# If routing_exempt != true AND provides.skills has entries, require routing block exists
# Does NOT check routing target names at all
```

**`check_readme_vs_manifest()`** (lines ~117–137): README drift check and command mention check. Unrelated to routing.

**Pre-existing failures** (confirmed by running the script):
```
[core]
  FAIL: manifest script entry missing on disk: scripts/dispatch-agent.sh
  FAIL: command /zulip listed in manifest but not mentioned in README.md
```
Exit code is currently 1 due to these two failures. Any new checks MUST add to `FAILURES` and will change the failure count, not reset it.

---

### 2. Skill -> Agent Mapping Convention

**Authoritative source**: The skill's SKILL.md body references the agent by name in a `subagent_type:` code block. There is NO machine-readable `agent:` frontmatter field on most skills — only two skills (skill-meta, skill-slide-planning, skill-slide-critic) use an `agent:` frontmatter key.

**Naming convention** (from `thin-wrapper-skill.md` and observed patterns):
- `skill-{ext}-research` → `{ext}-research-agent`
- `skill-{ext}-implementation` → `{ext}-implementation-agent`
- `skill-{ext}-research-hard` → `{ext}-research-hard-agent`
- `skill-{ext}-implementation-hard` → `{ext}-implementation-hard-agent`

**Evidence — lean/SKILL.md files**:
```
extensions/lean/skills/skill-lean-research/SKILL.md:     subagent_type: "lean-research-agent"
extensions/lean/skills/skill-lean-research-hard/SKILL.md: subagent_type: "lean-research-hard-agent"
extensions/lean/skills/skill-lean-implementation/SKILL.md: subagent_type: "lean-implementation-agent"
extensions/lean/skills/skill-lean-implementation-hard/SKILL.md: subagent_type: "lean-implementation-hard-agent"
```

**Provides.agents declaration**: The manifest `provides.agents` lists `{agent-name}.md` files. These entries are the machine-readable list of agents belonging to an extension.

**Guard approach for agent check**: Since `subagent_type` is only in SKILL.md body (not reliably parseable as structured data), the guard should:
- For each deployed skill (`SKILL.md` exists in `.claude/skills/{skill}/`), check that the agent declared in the owning extension's `provides.agents` list is also deployed at `.claude/agents/{agent}.md`.
- Alternatively (simpler): for each routing/routing_hard target that IS deployed, grep its SKILL.md for `subagent_type:` and verify the referenced agent file exists at `.claude/agents/{agent_name}.md`.

**Hard-skill to hard-agent mapping**: `skill-lean-research-hard` → `lean-research-hard-agent`. The `-hard` suffix applies symmetrically to both the skill and agent names. `provides.agents` for the lean extension explicitly lists both `lean-research-hard-agent.md` and `lean-implementation-hard-agent.md`.

---

### 3. Check Rules and Violation Definitions

#### Check Rule A: Undeclared Skill Dirs (extension source)
**What**: For each extension with a `skills/` dir, every `skill-*` subdirectory on disk must appear in `provides.skills`.

**Applied to**: ALL extensions.

**Violation**:
```
FAIL: skill dir on disk NOT in provides.skills: extensions/{ext}/skills/{skill-name}
```

**jq pattern** (not needed — use bash `find`):
```bash
for skill_dir in "$ext_path/skills/"/skill-*/; do
  skill_name=$(basename "$skill_dir")
  if ! jq -e --arg s "$skill_name" '.provides.skills[]? | select(. == $s)' "$manifest" > /dev/null 2>&1; then
    fail "skill dir on disk NOT in provides.skills: $skill_name"
  fi
done
```

#### Check Rule B: Routing Target Consistency (against provides.skills)
**What**: Every skill named in `routing.*.* ` or `routing_hard.*.*` must appear in `provides.skills` of SOME extension (not necessarily the declaring one, since extensions reference core's `skill-planner`).

**Applied to**: ALL extensions with routing or routing_hard blocks.

**Sub-rule B1**: If the routing target begins with the extension's own skill prefix (i.e., it's NOT a cross-extension reference like `skill-planner`), it MUST be in `provides.skills` of that extension AND its SKILL.md must exist in the extension source.

**Sub-rule B2**: For routing_hard targets: the target skill must be in `provides.skills` of SOME extension AND have a SKILL.md in the corresponding extension source.

**Violation** (B1):
```
FAIL: routing_hard.{op}.{task_type} -> {skill} NOT in extension provides.skills
```

**Cross-extension skills** (B-cross): Routing references to core skills like `skill-planner`, `skill-implementer`, `skill-researcher` should be checked only against the DEPLOYED tree (they exist in `.claude/skills/`). Skip the "belongs to provides.skills of THIS extension" check for known cross-extension targets. A practical approach: check that the target exists in ANY extension's `provides.skills` OR is deployed in `.claude/skills/`.

#### Check Rule C: Deployed Skill Existence (routing vs .claude/skills/)
**What**: For each routing or routing_hard target in an INSTALLED extension's manifest, verify the skill is deployed at `.claude/skills/{skill}/SKILL.md`.

**Applied to**: INSTALLED extensions only (heuristic: has at least one skill or agent deployed in `.claude/`).

**Violation**:
```
FAIL: routing_hard.{op}.{task_type} -> {skill} NOT deployed at .claude/skills/{skill}/SKILL.md
```

**NOTE on uninstalled extensions**: For extensions with NO deployed skills/agents (epidemiology, filetypes, formal, founder, latex, lean, present, python, typst, web, z3), routing failures are expected and are classified as WARN, not FAIL. Exception: routing_hard is a FAIL even for uninstalled extensions because routing_hard is scanned unconditionally (no guard in command-route-skill.sh for uninstalled extensions — Steps 4a-4d trust manifest entries).

**Wait — revisiting this**: The task description says: "skill-lean-research-hard is declared in lean/manifest.json routing_hard but NOT deployed on disk." This is the CONCRETE KNOWN INSTANCE to catch. Lean is not installed, yet this should FAIL. Therefore: routing_hard targets ALWAYS fail if not deployed (regardless of installation status). Routing (non-hard) targets for uninstalled extensions are WARNs.

**Revised rule C**:
- `routing_hard` target not in `.claude/skills/`: FAIL (regardless of extension install status)
- `routing` target not in `.claude/skills/` AND extension is installed: FAIL
- `routing` target not in `.claude/skills/` AND extension NOT installed: WARN (expected, not deployed yet)

#### Check Rule D: Agent Existence for Deployed Skills
**What**: For each routing or routing_hard target that IS deployed (`.claude/skills/{skill}/SKILL.md` exists), extract the `subagent_type:` from SKILL.md and verify `.claude/agents/{agent}.md` exists.

**Applied to**: All deployed skills (both real dirs and symlinks).

**Implementation**: `grep -o 'subagent_type: "[^"]*"' .claude/skills/{skill}/SKILL.md | head -1 | cut -d'"' -f2`

**Violation**:
```
FAIL: deployed skill {skill} references agent {agent} NOT in .claude/agents/
```

**Note on direct-execution skills**: Skills that do not use a subagent (skill-lake-repair, skill-lean-version, skill-status-sync, skill-refresh, etc.) will have no `subagent_type:` match. The check should skip those gracefully.

---

### 4. Which Tree Is Authoritative?

**Two trees exist**:
- **Extension source**: `.claude/extensions/{ext}/skills/{skill}/SKILL.md` and `.claude/extensions/{ext}/agents/{agent}.md`
- **Deployed tree**: `.claude/skills/{skill}/` (symlinks to extension source OR real dirs for core) and `.claude/agents/{agent}.md`

**Deployment mechanism** (`install-extension.sh`): Creates symlinks from `.claude/skills/{skill} → ../extensions/{ext}/skills/{skill}` and `.claude/agents/{agent}.md → ../extensions/{ext}/agents/{agent}.md`. Core extension files are real directories/files (not symlinks).

**Authority per check type**:

| Check | Authoritative Tree | Rationale |
|-------|-------------------|-----------|
| provides.skills vs source dirs | Extension source | Validates manifest accuracy |
| routing target in provides.skills | Extension source | Validates manifest self-consistency |
| routing/routing_hard target deployed | Deployed (.claude/skills/) | What is actually usable at runtime |
| routing_hard target deployed | Deployed (.claude/skills/) | Critical — 4a-4d trust manifest, no 4e safety gate |
| Agent exists for deployed skill | Deployed (.claude/agents/) | What Claude Code can actually spawn |

**Concrete lean situation**:
- Extension source: `extensions/lean/skills/skill-lean-research-hard/SKILL.md` EXISTS
- Extension source: `extensions/lean/skills/skill-lean-research-hard/` in `provides.skills` = YES
- Deployed: `.claude/skills/skill-lean-research-hard/` = NOT PRESENT (lean not installed)
- Manifest routing_hard: `lean4 → skill-lean-research-hard` = YES
- **Verdict**: FAIL under Check Rule C (routing_hard target not deployed)

---

### 5. CI Integration and Pre-existing Failures

**How check-extension-docs.sh is invoked**:
- Direct: `bash .claude/scripts/check-extension-docs.sh` or `bash .claude/scripts/check-extension-docs.sh --quiet`
- Listed in `.claude/extensions.json` under core extension (entry `check-extension-docs.sh` in scripts list)
- Permissions granted in `settings.local.json`
- Referenced in `CLAUDE.md` Utility Scripts section
- Core extension source has a copy at `.claude/extensions/core/scripts/check-extension-docs.sh`

**Current exit behavior**: exits 1 due to 2 pre-existing failures. Adding new checks adds to `$FAILURES`. The exit code remains 1 (non-zero) — CI was already failing. The new checks will correctly add more failures.

**Distinguishing new vs pre-existing**: 
Option A: Do nothing special — all failures are treated equally, let CI report the total.
Option B: Add a `# KNOWN:` prefix or separate counter for "known pre-existing failures" vs "new failures". This is complex and not standard for this script's style.

**Recommendation**: Option A. The task says "exit non-zero on violations so CI catches regressions" — the script already exits non-zero. Adding new checks increases the violation count, which is the desired behavior. The core extension's `dispatch-agent.sh` missing and `/zulip` README gap remain as existing failures and should be fixed in a separate task (or the new plan can note them as pre-existing).

**Important integration note**: The new checks must be added to `check-extension-docs.sh` (and its copy at `extensions/core/scripts/check-extension-docs.sh`). The `check-extension-docs.sh` pattern already has `CURRENT_EXT` tracking per extension and the `fail()` function increments `FAILURES`. New functions follow the same pattern.

---

## Decisions

1. **Scope routing_hard failures as FAIL regardless of extension installation status** (because command-route-skill.sh Steps 4a-4d scan all manifests without an install guard, so routing_hard entries are always live).
2. **Scope routing (non-hard) failures as WARN for uninstalled extensions** and FAIL for installed ones. This avoids noise from the 11 uninstalled extensions while still enforcing correctness for active ones.
3. **Use heuristic for "installed"**: an extension is installed if at least one of its skills appears as a real dir OR symlink under `.claude/skills/`, OR at least one of its agents appears under `.claude/agents/`.
4. **Do NOT add a machine-readable `agent:` frontmatter field to every SKILL.md** as part of this task. Use grep-based extraction of `subagent_type:` from SKILL.md body. The existing pattern is sufficient and adding frontmatter is out of scope for a guard script.
5. **Keep the guard as additions to `check-extension-docs.sh`** rather than a separate script, to maintain the single-script CI integration point. A function `check_routing_consistency()` follows the existing pattern.
6. **Both `check-extension-docs.sh` and its core copy** must be updated atomically to keep them in sync.

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Guard produces 90+ false positives from uninstalled extensions | CI noise drowns real failures | Only FAIL on uninstalled routing (non-hard); WARN is non-blocking |
| Agent grep on SKILL.md is brittle (multiline, formatting) | Miss agent references | Use `grep -o` with narrow pattern; accept false negatives over false positives |
| `routing_hard` check marks lean as FAIL despite being intentionally undeployed | Breaks CI until lean is deployed | Option: add `routing_hard_exempt` flag to manifest; OR fix lean by deploying via /install or noting in report |
| dispatch-agent.sh and /zulip pre-existing failures obscure new failures | Hard to tell which failures are new | Impossible to avoid without separate counter; accept as-is, address pre-existing in a follow-up |
| Core extension copy at `extensions/core/scripts/check-extension-docs.sh` diverges | Extension mechanism deploys stale copy | Implementation plan must update BOTH files |

---

## Concrete Implementation Sketch

Three new functions to add to `check-extension-docs.sh`:

### Function 1: `check_undeclared_skills()`
```bash
check_undeclared_skills() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"
  
  if [[ ! -d "$ext_path/skills" ]]; then return 0; fi
  
  for skill_dir in "$ext_path/skills/"/skill-*/; do
    [[ -d "$skill_dir" ]] || continue
    local skill_name; skill_name=$(basename "$skill_dir")
    if ! jq -e --arg s "$skill_name" '.provides.skills[]? | select(. == $s)' \
        "$manifest" > /dev/null 2>/dev/null; then
      fail "skill dir on disk NOT in provides.skills: $skill_name"
    fi
  done
}
```

### Function 2: `check_routing_consistency()`
```bash
check_routing_consistency() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"
  
  # Determine if extension is "installed" (has any deployed skill or agent)
  local installed=0
  if [[ -d "$ext_path/skills" ]]; then
    for skill_dir in "$ext_path/skills/"/*/; do
      local sn; sn=$(basename "$skill_dir")
      if [[ -d "$REPO_ROOT/.claude/skills/$sn" ]]; then
        installed=1; break
      fi
    done
  fi
  if [[ $installed -eq 0 && -d "$ext_path/agents" ]]; then
    for af in "$ext_path/agents/"*.md; do
      local an; an=$(basename "$af")
      if [[ -f "$REPO_ROOT/.claude/agents/$an" ]]; then
        installed=1; break
      fi
    done
  fi

  # Check routing targets
  local skills
  skills=$(jq -r '.routing // {} | to_entries[] | .value | to_entries[] | .value' "$manifest" 2>/dev/null)
  for s in $skills; do
    if [[ ! -d "$REPO_ROOT/.claude/skills/$s" ]]; then
      if [[ $installed -eq 1 ]]; then
        fail "routing target not deployed: $s"
      else
        info "WARN: routing target not deployed (extension not installed): $s"
      fi
    fi
  done

  # Check routing_hard targets — ALWAYS fail, even if extension not installed
  local hard_skills
  hard_skills=$(jq -r '.routing_hard // {} | to_entries[] | .value | to_entries[] | .value' "$manifest" 2>/dev/null)
  for s in $hard_skills; do
    if [[ ! -d "$REPO_ROOT/.claude/skills/$s" ]]; then
      fail "routing_hard target not deployed: $s"
    fi
  done
}
```

### Function 3: `check_deployed_skill_agents()`
```bash
check_deployed_skill_agents() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  local skills
  skills=$(jq -r '.provides.skills[]? // empty' "$manifest" 2>/dev/null)
  for s in $skills; do
    local deployed_skill="$REPO_ROOT/.claude/skills/$s/SKILL.md"
    [[ -f "$deployed_skill" ]] || continue  # not deployed, skip
    
    # Extract subagent_type from SKILL.md body
    local agent_name
    agent_name=$(grep -o 'subagent_type: "[^"]*"' "$deployed_skill" 2>/dev/null | head -1 | cut -d'"' -f2)
    [[ -z "$agent_name" ]] && continue  # direct-execution skill, no agent
    [[ "$agent_name" == "fork" ]] && continue  # fork pattern, not a named agent
    
    if [[ ! -f "$REPO_ROOT/.claude/agents/${agent_name}.md" ]]; then
      fail "deployed skill $s references agent $agent_name NOT in .claude/agents/"
    fi
  done
}
```

**Call site**: Add the three function calls inside the existing `if jq empty ...; then` block in the main loop, after `check_routing_block` and before `check_readme_vs_manifest`:
```bash
check_undeclared_skills "$ext_path"
check_routing_consistency "$ext_path"
check_deployed_skill_agents "$ext_path"
```

**REPO_ROOT availability**: The script already sets `REPO_ROOT` at line 20. All new functions reference `$REPO_ROOT/.claude/skills/` and `$REPO_ROOT/.claude/agents/`.

---

## Predicted Output After Implementation

The new checks will produce the following additional failures (confirmed against live filesystem):

**check_routing_consistency() — routing_hard FAILs**:
```
[lean]
  FAIL: routing_hard target not deployed: skill-lean-research-hard
  FAIL: routing_hard target not deployed: skill-lean-implementation-hard
```

**check_routing_consistency() — routing WARNs (uninstalled)**:
```
[lean] WARN: routing target not deployed (extension not installed): skill-lean-research
[lean] WARN: routing target not deployed (extension not installed): skill-lake-repair
... (similar for epidemiology, filetypes, formal, founder, latex, present, python, typst, web, z3)
```

**check_deployed_skill_agents()**: No additional FAILs for currently deployed extensions (core, cslib, nix, nvim, literature, memory all have their agents deployed).

**Total FAIL count increase**: +2 (the two lean routing_hard failures) on top of the existing 2 core failures.

---

## Context Extension Recommendations

- **Topic**: Deployment status tracking in extensions.json vs actual deployed artifacts
- **Gap**: `extensions.json` only tracks 4 extensions (core, memory, nix, nvim) but cslib, literature, and others are actually deployed via symlinks. A more complete tracking mechanism would help the guard determine "installed" extensions more reliably.
- **Recommendation**: Consider updating `install-extension.sh` to always write to `extensions.json` when installing, and update the guard to use `extensions.json` as the primary installed-extension oracle once it's more complete.

---

## Appendix

### Files Examined
- `/home/benjamin/.config/nvim/.claude/scripts/check-extension-docs.sh` (complete)
- `/home/benjamin/.config/nvim/.claude/scripts/command-route-skill.sh` (complete)
- `/home/benjamin/.config/nvim/.claude/scripts/install-extension.sh` (complete)
- `/home/benjamin/.config/nvim/.claude/scripts/validate-wiring.sh` (complete)
- `/home/benjamin/.config/nvim/.claude/extensions/lean/manifest.json` (complete)
- `/home/benjamin/.config/nvim/.claude/extensions/core/manifest.json` (complete)
- `/home/benjamin/.config/nvim/.claude/extensions/*/manifest.json` (all, via jq enumeration)
- `/home/benjamin/.config/nvim/.claude/extensions/lean/skills/skill-lean-research-hard/SKILL.md`
- `/home/benjamin/.config/nvim/.claude/context/guides/hard-mode-routing.md`
- `/home/benjamin/.config/nvim/.claude/extensions/core/context/patterns/thin-wrapper-skill.md`
- `/home/benjamin/.config/nvim/.claude/extensions.json`

### Confirmed Violations (live filesystem)
| Violation | Extension | Severity | Rule |
|-----------|-----------|----------|------|
| `skill-lean-research-hard` in routing_hard but not deployed | lean | FAIL | Rule C |
| `skill-lean-implementation-hard` in routing_hard but not deployed | lean | FAIL | Rule C |
| `dispatch-agent.sh` in provides.scripts but missing | core | FAIL | Pre-existing |
| `/zulip` command not in README.md | core | FAIL | Pre-existing |

### Deployed Skills with Agents (spot check)
| Deployed Skill | Agent Reference | Agent Deployed |
|----------------|-----------------|---------------|
| skill-neovim-research | neovim-research-agent | YES |
| skill-nix-research | nix-research-agent | YES |
| skill-cslib-research | cslib-research-agent | YES |
| skill-researcher | general-research-agent | YES |
| skill-implementer | general-implementation-agent | YES |
| skill-planner | planner-agent | YES |

### Extension Install Status
| Extension | Installed | Has routing | Has routing_hard |
|-----------|-----------|-------------|------------------|
| core | YES | NO (routing_exempt) | YES |
| cslib | YES | YES | YES |
| nvim | YES | YES | NO |
| nix | YES | YES | NO |
| memory | YES | YES | NO |
| literature | YES | NO (routing_exempt) | NO |
| lean | **NO** | YES | **YES** |
| epidemiology-z3 (11 extensions) | NO | YES | NO |
