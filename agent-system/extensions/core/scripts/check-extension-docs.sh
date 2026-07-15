#!/usr/bin/env bash
# check-extension-docs.sh
#
# Doc-lint script that iterates .claude/extensions/*/ and flags:
#   - missing README.md
#   - missing EXTENSION.md
#   - missing manifest.json
#   - manifest entries referencing nonexistent files (agents, skills, commands, rules, scripts,
#     context)
#   - rule files present in an extension's rules/ but absent from its provides.rules (reverse
#     direction: an unregistered rule never deploys and never reaches consuming repos)
#   - dangling .claude/context/contracts/*.md references in deployed skills/agents/rules that do
#     not resolve to an existing file in this project (project-wide, not per-extension)
#   - deployed .claude/scripts/<name> content drift from its extension-source counterpart, for
#     each manifest.provides.scripts entry where both copies exist (never-deployed extension-only
#     scripts are skipped, not failed)
#   - deployed .claude/rules/<name> content drift from its extension-source counterpart, for
#     each manifest.provides.rules entry where both copies exist (never-deployed extension-only
#     rules are skipped, not failed)
#   - README.md older than manifest.json (potential drift)
#   - commands listed in manifest but not mentioned in README.md
#   - deployed files under .claude/{agents,commands,context,scripts}/ that trace to ZERO
#     manifest.provides.<category> declaration in any extension ("every deployed file has a
#     source" gate; project-wide, not per-extension; severity controlled by ORPHAN_GATE_MODE)
#   - broken deployed symlinks under .claude/{agents,commands,skills}/ (install-extension.sh's
#     parallel symlink-deploy mechanism; distinct from the orphan checks above -- a dangling
#     symlink DOES have a declared source, its target path is simply wrong)
#
# Rule letter index (checks named "Rule X" in function comments below, in first-introduced
# order; unlettered checks are unnamed/structural and are not part of this index):
#   A - check_undeclared_skills            : skill dir on disk not in provides.skills
#   B - check_routing_consistency          : routing/routing_hard target not resolvable anywhere
#   C - check_routing_consistency          : routing/routing_hard target resolvable but not deployed
#   D - check_deployed_skill_agents        : deployed skill's subagent_type not in .claude/agents/
#   E - check_referenced_scripts_declared  : script referenced in docs but not in provides.scripts
#   F - check_deployed_script_drift        : deployed script content drift from extension source
#   G - check_dangling_contract_references : dangling .claude/context/contracts/*.md reference
#   H - check_undeclared_rules             : rule file on disk not in provides.rules
#   I - check_deployed_rule_drift          : deployed rule content drift from extension source
#   J - check_flat_category_orphans(agents)   : deployed agent with no provides.agents source
#   K - check_flat_category_orphans(commands) : deployed command with no provides.commands source
#   L - check_context_orphans              : deployed context file with no provides.context source
#   M - check_flat_category_orphans(scripts)  : deployed script with no provides.scripts source
#   N - check_broken_deployed_symlinks     : dangling install-extension.sh-created symlink
#
# Exit codes:
#   0 - all extensions pass
#   1 - one or more extensions have failures
#
# Usage:
#   bash .claude/scripts/check-extension-docs.sh
#   bash .claude/scripts/check-extension-docs.sh --quiet   (suppress info output)

set -uo pipefail

QUIET=0
if [[ "${1:-}" == "--quiet" ]]; then
  QUIET=1
fi

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
EXT_DIR="${EXT_DIR:-$REPO_ROOT/agent-system/extensions}"

if [[ ! -d "$EXT_DIR" ]]; then
  echo "ERROR: $EXT_DIR does not exist" >&2
  exit 1
fi

FAILURES=0
declare -A EXTENSION_STATUS

info() { [[ $QUIET -eq 0 ]] && echo "  $*"; }
fail() {
  echo "  FAIL: $*"
  FAILURES=$((FAILURES + 1))
  EXTENSION_STATUS["$CURRENT_EXT"]="FAIL"
}

check_file() {
  local f="$1"
  local label="$2"
  if [[ ! -f "$f" ]]; then
    fail "$label missing ($f)"
    return 1
  fi
  if [[ ! -s "$f" ]]; then
    fail "$label is empty ($f)"
    return 1
  fi
  return 0
}

check_manifest_entries() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  # agents (file references)
  local agents
  agents=$(jq -r '.provides.agents[]? // empty' "$manifest" 2>/dev/null)
  for a in $agents; do
    if [[ ! -f "$ext_path/agents/$a" ]]; then
      fail "manifest agent entry missing on disk: agents/$a"
    fi
  done

  # skills (directory references with SKILL.md)
  local skills
  skills=$(jq -r '.provides.skills[]? // empty' "$manifest" 2>/dev/null)
  for s in $skills; do
    if [[ ! -f "$ext_path/skills/$s/SKILL.md" ]]; then
      fail "manifest skill entry missing on disk: skills/$s/SKILL.md"
    fi
  done

  # commands (file references)
  local cmds
  cmds=$(jq -r '.provides.commands[]? // empty' "$manifest" 2>/dev/null)
  for c in $cmds; do
    if [[ ! -f "$ext_path/commands/$c" ]]; then
      fail "manifest command entry missing on disk: commands/$c"
    fi
  done

  # rules
  local rules
  rules=$(jq -r '.provides.rules[]? // empty' "$manifest" 2>/dev/null)
  for r in $rules; do
    if [[ ! -f "$ext_path/rules/$r" ]]; then
      fail "manifest rule entry missing on disk: rules/$r"
    fi
  done

  # scripts
  local scripts
  scripts=$(jq -r '.provides.scripts[]? // empty' "$manifest" 2>/dev/null)
  for s in $scripts; do
    if [[ ! -f "$ext_path/scripts/$s" ]]; then
      fail "manifest script entry missing on disk: scripts/$s"
    fi
  done

  # context (file OR directory references, e.g. "README.md" or "contracts")
  #
  # Mirrors the agents/skills/commands/rules/scripts pattern above for the one manifest.provides
  # category previously left unchecked: context. A declared provides.context entry must exist on
  # disk under <ext_path>/context/<entry>; otherwise the extension's context never propagates
  # through copy_context_dirs() / the "Load Core" allow-list, and downstream repos silently never
  # receive it. Confirmed live in cslib's stale `lean` extension copy (task 837).
  local context_entries
  context_entries=$(jq -r '.provides.context[]? // empty' "$manifest" 2>/dev/null)
  local ce
  for ce in $context_entries; do
    if [[ ! -e "$ext_path/context/$ce" ]]; then
      fail "manifest provides.context entry missing on disk: context/$ce"
    fi
  done
}

# Rule F: Deployed-vs-source content drift for manifest.provides.scripts entries.
#
# copy_scripts()/copy_file() in lua/neotex/plugins/ai/shared/extensions/loader.lua performs a
# byte-for-byte overwrite of .claude/scripts/<name> from <extension>/scripts/<name> on every
# extension load/reload, with no path substitution or templating. If a script is later hotfixed
# directly in the deployed .claude/scripts/ copy (instead of the extension source), that fix
# silently regresses on the next sync. This check fails when a manifest.provides.scripts entry's
# deployed copy differs in content from its extension-source copy.
#
# CRITICAL: only compare when BOTH copies exist. Several extension-only scripts (e.g. the
# opposite-direction never-deployed zotero-*/cite-extract.sh/test-lit-pipeline.sh scripts) are
# intentionally absent from .claude/scripts/ -- an absent deployed copy is NOT drift and must be
# skipped (with an optional info note), never a FAIL.
check_deployed_script_drift() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  local scripts
  scripts=$(jq -r '.provides.scripts[]? // empty' "$manifest" 2>/dev/null)
  local s deployed source
  for s in $scripts; do
    deployed="$REPO_ROOT/.claude/scripts/$s"
    source="$ext_path/scripts/$s"

    if [[ ! -f "$deployed" ]]; then
      info "script not deployed, skipping drift check: $s"
      continue
    fi
    if [[ ! -f "$source" ]]; then
      # Already reported by check_manifest_entries; do not double-report here.
      continue
    fi

    if ! cmp -s "$deployed" "$source"; then
      fail "deployed script content drift (deployed != extension source): scripts/$s"
    fi
  done
}

# Rule I: Deployed-vs-source content drift for manifest.provides.rules entries.
#
# Mirrors check_deployed_script_drift (Rule F) for the rules category. Rules deploy by
# byte-for-byte copy from <extension>/rules/<name> to .claude/rules/<name> via the same sync
# mechanism as scripts. If a rule is later hotfixed directly in the deployed .claude/rules/
# copy (instead of the extension source), that fix silently regresses on the next sync.
#
# CRITICAL: only compare when BOTH copies exist. An extension's rules are not deployed in
# every consuming repo -- an absent deployed copy is NOT drift and must be skipped (with an
# info note), never a FAIL.
check_deployed_rule_drift() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  local rules
  rules=$(jq -r '.provides.rules[]? // empty' "$manifest" 2>/dev/null)
  local r deployed source
  for r in $rules; do
    deployed="$REPO_ROOT/.claude/rules/$r"
    source="$ext_path/rules/$r"

    if [[ ! -f "$deployed" ]]; then
      info "rule not deployed, skipping drift check: $r"
      continue
    fi
    if [[ ! -f "$source" ]]; then
      # Already reported by check_manifest_entries; do not double-report here.
      continue
    fi

    if ! cmp -s "$deployed" "$source"; then
      fail "deployed rule content drift (deployed != extension source): rules/$r"
    fi
  done
}

check_routing_block() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  # Skip routing check if extension declares routing_exempt: true
  local routing_exempt
  routing_exempt=$(jq -r '.routing_exempt // false' "$manifest" 2>/dev/null)
  if [[ "$routing_exempt" == "true" ]]; then
    return 0
  fi

  # If manifest declares non-empty provides.skills, verify routing block exists
  local skill_count
  skill_count=$(jq -r '.provides.skills | length' "$manifest" 2>/dev/null)
  if [[ "$skill_count" -gt 0 ]]; then
    local has_routing
    has_routing=$(jq -r 'has("routing")' "$manifest" 2>/dev/null)
    if [[ "$has_routing" == "false" ]]; then
      fail "manifest declares $skill_count skill(s) but has no routing block"
    fi
  fi
}

# Rule A: Undeclared skill dirs in extension source not in provides.skills
check_undeclared_skills() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  [[ -d "$ext_path/skills" ]] || return 0

  for skill_dir in "$ext_path/skills/"/skill-*/; do
    [[ -d "$skill_dir" ]] || continue
    local skill_name
    skill_name=$(basename "$skill_dir")
    if ! jq -e --arg s "$skill_name" '.provides.skills[]? | select(. == $s)' \
        "$manifest" > /dev/null 2>&1; then
      fail "skill dir on disk NOT in provides.skills: $skill_name"
    fi
  done
}

# Rule H: Undeclared rule files in extension source not in provides.rules.
#
# Reverse direction of check_manifest_entries' rules loop, which only validates that declared
# entries exist on disk. This catches the opposite bug: a rule file that exists on disk but was
# never added to provides.rules, so copy_file()/the "Load Core" allow-list never deploys it and
# consuming repos silently never receive it. Mirrors check_undeclared_skills (Rule A) for the
# rules category.
#
# Motivating case: core/rules/pr-prohibition.md existed on disk, was absent from core's
# provides.rules, and was correspondingly absent from every consuming repo's .claude/rules/ --
# meaning the rule barring agents from creating PRs and pushing to remotes never propagated
# downstream. Because it was unregistered, the loader also never overwrote its deployed copy, so
# the live version silently accumulated 35 lines of content absent from the extension source.
check_undeclared_rules() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  [[ -d "$ext_path/rules" ]] || return 0

  local rule_file rule_name
  for rule_file in "$ext_path/rules/"*.md; do
    [[ -f "$rule_file" ]] || continue
    rule_name=$(basename "$rule_file")
    if ! jq -e --arg r "$rule_name" '.provides.rules[]? | select(. == $r)' \
        "$manifest" > /dev/null 2>&1; then
      fail "rule file on disk NOT in provides.rules: rules/$rule_name"
    fi
  done
}

# Rules B + C: Routing target consistency and deployment
#
# Policy rationale (restored per task #771, re-applied by task #843 after #792 sync regression):
#   Both routing and routing_hard share the same deployment-dimension severity rule:
#     - FAIL if the extension is installed but the target is not deployed
#     - WARN (info) if the extension is not installed (expected undeployed state)
#   routing_hard adds ONE stricter requirement beyond the deployment dimension:
#     1. Source-grounding: the target must exist in some extension's SOURCE provides.skills
#   task #771 deliberately downgraded the uninstalled-extension case for routing_hard from
#   FAIL to WARN: command-route-skill.sh does not implement routing_hard dispatch at all (it
#   takes 3 positional args and never reads .routing_hard), so the "unconditional dispatch"
#   rationale that previously justified FAIL here is false -- an uninstalled extension with a
#   source-grounded but undeployed routing_hard target is the expected state, not a live
#   correctness bug. Task #792's sync reverted this from the stale extension-source copy;
#   task #843 restores it in both copies.
#   Rule B (resolvability): any routing or routing_hard target that does not exist in any
#   extension's provides.skills AND is not deployed is a FAIL (manifest typo/stale entry).
check_routing_consistency() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  # Determine if this extension is "installed":
  # installed = at least one of its source skills appears in .claude/skills/ OR
  #             at least one of its source agents appears in .claude/agents/
  local installed=0
  if [[ -d "$ext_path/skills" ]]; then
    local sdir
    for sdir in "$ext_path/skills/"/*/; do
      [[ -d "$sdir" ]] || continue
      local sn
      sn=$(basename "$sdir")
      if [[ -d "$REPO_ROOT/.claude/skills/$sn" || -L "$REPO_ROOT/.claude/skills/$sn" ]]; then
        installed=1
        break
      fi
    done
  fi
  if [[ $installed -eq 0 && -d "$ext_path/agents" ]]; then
    local af
    for af in "$ext_path/agents/"*.md; do
      [[ -f "$af" ]] || continue
      local an
      an=$(basename "$af")
      if [[ -f "$REPO_ROOT/.claude/agents/$an" ]]; then
        installed=1
        break
      fi
    done
  fi

  # Helper: check if a skill target is resolvable (in any extension's provides.skills
  # OR deployed under .claude/skills/)
  target_resolvable() {
    local target="$1"
    # Check deployed first (fast path for cross-extension core skills)
    if [[ -d "$REPO_ROOT/.claude/skills/$target" || -L "$REPO_ROOT/.claude/skills/$target" ]]; then
      return 0
    fi
    # Check all extension manifests for provides.skills
    local m
    for m in "$EXT_DIR"/*/manifest.json; do
      [[ -f "$m" ]] || continue
      if jq -e --arg s "$target" '.provides.skills[]? | select(. == $s)' \
          "$m" > /dev/null 2>&1; then
        return 0
      fi
    done
    return 1
  }

  # --- routing targets ---
  local routing_targets
  routing_targets=$(jq -r '.routing // {} | to_entries[] | .value | to_entries[] | .value' \
    "$manifest" 2>/dev/null)
  local t base_t
  for t in $routing_targets; do
    # Routing values may use colon notation (e.g., skill-grant:assemble) where the part
    # before the colon is the actual skill name and the colon suffix is a sub-operation mode.
    # Strip the suffix for skill-resolution purposes.
    base_t="${t%%:*}"
    if [[ ! -d "$REPO_ROOT/.claude/skills/$base_t" && ! -L "$REPO_ROOT/.claude/skills/$base_t" ]]; then
      # Rule B: target not resolvable to any provides.skills and not deployed
      if ! target_resolvable "$base_t"; then
        fail "routing target not resolvable (not in any provides.skills, not deployed): $t"
      elif [[ $installed -eq 1 ]]; then
        # Rule C (routing, installed): deployed dimension violation
        fail "routing target not deployed (extension is installed): $t"
      else
        # Rule C (routing, uninstalled): warn only
        info "WARN: routing target not deployed (extension not installed): $t"
      fi
    fi
  done

  # --- routing_hard targets ---
  local hard_targets
  hard_targets=$(jq -r '.routing_hard // {} | to_entries[] | .value | to_entries[] | .value' \
    "$manifest" 2>/dev/null)
  for t in $hard_targets; do
    # Strip colon sub-operation suffix for skill-resolution (same as routing above)
    base_t="${t%%:*}"
    if [[ ! -d "$REPO_ROOT/.claude/skills/$base_t" && ! -L "$REPO_ROOT/.claude/skills/$base_t" ]]; then
      # Rule B: target not resolvable to any provides.skills and not deployed
      if ! target_resolvable "$base_t"; then
        fail "routing_hard target not resolvable (not in any provides.skills, not deployed): $t"
      elif [[ $installed -eq 1 ]]; then
        # Rule C (routing_hard, installed): deployment violation
        fail "routing_hard target not deployed (extension is installed): $t"
      else
        # Rule C (routing_hard, uninstalled): warn only. command-route-skill.sh does not
        # implement routing_hard dispatch at all, so an uninstalled extension with a
        # source-grounded but undeployed routing_hard target is expected, not a live bug
        # (task #771; restored here after #792's stale-source-copy regression).
        info "WARN: routing_hard target declared but not deployed (extension not installed): $t"
      fi
    fi
  done
}

# Rule D: Deployed skills must reference agents that exist
check_deployed_skill_agents() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  local skills
  skills=$(jq -r '.provides.skills[]? // empty' "$manifest" 2>/dev/null)
  local s
  for s in $skills; do
    local deployed_skill="$REPO_ROOT/.claude/skills/$s/SKILL.md"
    [[ -f "$deployed_skill" ]] || continue  # not deployed, skip

    # Extract subagent_type from SKILL.md body
    local agent_name
    agent_name=$(grep -o 'subagent_type: "[^"]*"' "$deployed_skill" 2>/dev/null \
      | head -1 | cut -d'"' -f2)
    [[ -z "$agent_name" ]] && continue      # direct-execution skill, no agent
    [[ "$agent_name" == "fork" ]] && continue  # fork pattern, not a named agent file

    if [[ ! -f "$REPO_ROOT/.claude/agents/${agent_name}.md" ]]; then
      fail "deployed skill $s references agent $agent_name NOT in .claude/agents/"
    fi
  done
}

check_readme_vs_manifest() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"
  local readme="$ext_path/README.md"

  # Compare mtimes: warn if README older than manifest (possible drift)
  if [[ -f "$readme" && -f "$manifest" ]]; then
    local readme_mtime manifest_mtime
    readme_mtime=$(stat -c %Y "$readme" 2>/dev/null || stat -f %m "$readme")
    manifest_mtime=$(stat -c %Y "$manifest" 2>/dev/null || stat -f %m "$manifest")
    if [[ "$readme_mtime" -lt "$manifest_mtime" ]]; then
      info "WARN: README.md older than manifest.json (possible drift)"
    fi
  fi

  # Commands listed in manifest must be mentioned in README.md
  if [[ -f "$readme" ]]; then
    local cmds
    cmds=$(jq -r '.provides.commands[]? // empty' "$manifest" 2>/dev/null)
    for c in $cmds; do
      local cmd_name="${c%.md}"
      if ! grep -q "/$cmd_name" "$readme"; then
        fail "command /$cmd_name listed in manifest but not mentioned in README.md"
      fi
    done
  fi
}

# Rule E: Scripts referenced in an extension's docs/skills/agents but NOT declared in the
# extension's own provides.scripts (reverse direction of check_manifest_entries, which only
# validates that declared entries exist on disk -- this catches the opposite bug: a script that
# exists and is referenced but was never added to the manifest, so it never gets deployed to a
# consuming repo). See task 793 (script packaging bug: literature-discover.sh and 6 siblings were
# referenced but undeclared) for the motivating case.
check_referenced_scripts_declared() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  # 1. Extract .sh/.sql filename tokens referenced in this extension's docs/skills/agents.
  # Strip http(s) URLs first so remote install-script references (e.g.
  # "https://astral.sh/uv/install.sh | sh", "https://elan.lean-lang.org/elan-init.sh") are not
  # mistaken for local extension scripts. The trailing \b prevents partial-word matches inside
  # unrelated identifiers that merely start with "sh"/"sql" after a dot (e.g. Python
  # `df.shape`, `wb.sheetnames`, `slide.shapes`, `vim.opt.shiftwidth`).
  local referenced
  referenced=$(
    {
      for f in "$ext_path"/commands/*.md "$ext_path"/skills/*/SKILL.md \
               "$ext_path"/agents/*.md "$ext_path/README.md" "$ext_path/EXTENSION.md"; do
        [[ -f "$f" ]] || continue
        sed -E 's#https?://[^[:space:]]+##g' "$f" 2>/dev/null \
          | grep -oE '[A-Za-z0-9_-]+\.(sh|sql)\b'
      done
    } | sort -u
  )
  [[ -z "$referenced" ]] && return 0

  # 2. Exclude names already owned/declared by the core extension, in EITHER
  # provides.scripts or provides.hooks (cross-referenced against core's own manifest) to avoid
  # false positives on core-owned scripts/hooks that other extensions legitimately mention by
  # name (e.g. literature-retrieve.sh, generate-todo.sh, lifecycle-notify.sh).
  local core_manifest="$EXT_DIR/core/manifest.json"
  local core_declared=""
  if [[ -f "$core_manifest" ]]; then
    core_declared=$(jq -r '(.provides.scripts // [])[]?, (.provides.hooks // [])[]?' \
      "$core_manifest" 2>/dev/null)
  fi

  # 3. Exclude names declared in ANY extension's provides.scripts (cross-extension
  # invocation is legitimate -- e.g. core's --lit integration code invokes literature's
  # already-packaged scripts by name via the shared flat .claude/scripts/ directory).
  local all_declared_scripts=""
  local m
  for m in "$EXT_DIR"/*/manifest.json; do
    [[ -f "$m" ]] || continue
    all_declared_scripts+=$'\n'"$(jq -r '.provides.scripts[]? // empty' "$m" 2>/dev/null)"
  done

  # 4. Exclude names already declared in this extension's own provides.hooks (a script
  # legitimately mentioned in its own docs need not be in provides.scripts if it is already
  # tracked as a hook).
  local own_hooks
  own_hooks=$(jq -r '.provides.hooks[]? // empty' "$manifest" 2>/dev/null)

  # 5. Verdict: fail on any remaining referenced name not covered by any exclusion set.
  local name
  for name in $referenced; do
    if grep -qxF "$name" <<< "$core_declared"; then
      continue
    fi
    if grep -qxF "$name" <<< "$all_declared_scripts"; then
      continue
    fi
    if grep -qxF "$name" <<< "$own_hooks"; then
      continue
    fi
    fail "script referenced in docs/skills/agents but NOT in provides.scripts: $name"
  done
}

# Rule G: Project-wide dangling .claude/context/contracts/*.md reference scan (task 837).
#
# NOT per-extension: deployed skills/agents/rules/commands across the WHOLE project may
# reference a specific contracts/*.md file by path (e.g. skill-orchestrate-hard/SKILL.md citing
# `.claude/context/contracts/territory.md`). If the referenced path does not exist under this
# project's `.claude/` root, the reference is dangling -- this is the exact BimodalLogic/cslib
# defect: a downstream repo's skill-orchestrate-hard referenced contracts absent from that
# repo's deployed layer because core's `provides.context` never registered `contracts` (fixed in
# Phase 1), so the contracts never propagated through "Load Core". This check is reference-driven
# (only validates what deployed content actually cites in THIS project), never presence-driven,
# so a project that references nothing missing passes even if it lacks some contracts files
# entirely (e.g. a project not loading `lean`, correctly lacking lean-only contract overrides).
#
# Scoped strictly to `.claude/context/contracts/*.md`-shaped references per task 837's
# Non-Goals -- a broader generic `@.claude/...` dangling-path linter is deliberately NOT
# implemented here (left as a documented, disabled extension point below) to avoid false
# positives on legitimately extension-conditional references (e.g. lean-only context files
# referenced only from lean-scoped skills, which are correctly absent in non-lean projects).
check_dangling_contract_references() {
  local f ref refs
  for f in "$REPO_ROOT"/.claude/skills/*/SKILL.md \
           "$REPO_ROOT"/.claude/agents/*.md \
           "$REPO_ROOT"/.claude/rules/*.md \
           "$REPO_ROOT"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    refs=$(grep -oE '\.claude/context/contracts/[a-zA-Z0-9_-]+\.md' "$f" 2>/dev/null | sort -u)
    for ref in $refs; do
      if [[ ! -f "$REPO_ROOT/$ref" ]]; then
        fail "dangling contract reference in ${f#"$REPO_ROOT"/}: $ref"
      fi
    done
  done

  # Extension point (NOT enabled -- stretch goal, see task 837 Non-Goals): a future generic
  # dangling-path scan could widen the pattern above to `@\.claude/[a-zA-Z0-9_/.-]+\.md`
  # broadly across the same file set. This is intentionally left unimplemented; wiring it in
  # without first auditing every extension-conditional `@.claude/...` reference in this repo
  # would produce false-positive FAILs on references that are valid only when a specific
  # extension is loaded.
}

# ---------------------------------------------------------------------------
# Rules J/K/L/M/N: "Every deployed file has a source" gate.
#
# Distinct direction from check_manifest_entries (declared-but-missing-on-source, per-extension)
# and check_undeclared_skills/check_undeclared_rules (Rules A/H, present-on-source-but-undeclared,
# per-extension). This block is project-wide: for each provides category not already covered
# end-to-end by a content-drift check (rules is already fully covered by
# check_deployed_rule_drift + check_undeclared_rules), find every deployed file under
# .claude/<category>/ that traces to ZERO manifest.provides.<category> declaration in ANY
# extension. A deployed-only orphan like this vanishes on a clean rebuild from source, since
# nothing in any extension's source tree would ever recreate it.
#
# ORPHAN_GATE_MODE controls severity for this whole block (orphan checks J/K/L/M AND the broken-
# symlink check N): "advisory" (info-only, does not increment FAILURES) during the remediation-
# verification window (this task's Phase 5), "hard" (fail, increments FAILURES) once promoted
# (this task's Phase 6). Promoted to "hard" by default now that Phases 1-4 remediation has landed
# and Phase 5 confirmed a clean (0 orphans, 0 broken symlinks) advisory run -- override to
# "advisory" only for temporary local debugging, never in committed config.
ORPHAN_GATE_MODE="${ORPHAN_GATE_MODE:-hard}"

orphan_report() {
  local msg="$1"
  if [[ "$ORPHAN_GATE_MODE" == "hard" ]]; then
    fail "$msg"
  else
    info "ADVISORY (not yet blocking): $msg"
  fi
}

# Enumeration method: git ls-files (not find), matching the research audit method -- naturally
# excludes gitignored runtime artifacts (literature-pyenv/venv/, __pycache__/) without extra
# path filtering, since they were never tracked.
_git_deployed_files() {
  local category="$1"
  git -C "$REPO_ROOT" ls-files ".claude/$category" 2>/dev/null
}

# Rules J/K/M: flat-category orphan check (agents, commands, scripts).
#
# "Flat" here means one directory level of copy_simple_files()/copy_scripts() semantics -- but
# for scripts, an individual provides.scripts entry may itself contain a "/" (e.g.
# "lint/lint-postflight-boundary.sh", "tests/generate-test-fixtures.py"), so entries are matched
# by their full relative path under the category root, not by basename alone.
check_flat_category_orphans() {
  local category="$1"
  local rule_label="$2"

  # Build the declared set: union of every extension's provides.<category> entries (regardless
  # of whether that extension's own source file exists -- a missing source is already reported
  # by check_manifest_entries; this check only asks "does ANY manifest acknowledge this deployed
  # name").
  local declared=""
  local m
  for m in "$EXT_DIR"/*/manifest.json; do
    [[ -f "$m" ]] || continue
    declared+=$'\n'"$(jq -r --arg c "$category" '.provides[$c][]? // empty' "$m" 2>/dev/null)"
  done

  local rel f full
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    full="$REPO_ROOT/$rel"
    # Symlinks are governed by check_broken_deployed_symlinks (Rule N), not this content-source
    # check -- explicit [[ -L ]] skip so a dangling symlink never reaches cmp/orphan logic here
    # and is never silently mistaken for an ordinary unsourced regular file either.
    [[ -L "$full" ]] && continue
    [[ -f "$full" ]] || continue
    f="${rel#.claude/$category/}"
    if ! grep -qxF "$f" <<< "$declared"; then
      orphan_report "$rule_label: deployed $category/$f traces to no provides.$category entry in any extension manifest"
    fi
  done < <(_git_deployed_files "$category")
}

# Rule L: context orphan check (recursive).
#
# provides.context entries are either a bare filename at context root (matches itself) or a
# directory name (deployed recursively, preserving substructure, via copy_context_dirs()). The
# declared set must therefore be expanded to individual FILES, not just top-level entry names,
# to correctly diff against a flat git-ls-files enumeration of .claude/context/. Multiple
# extensions may legitimately declare the same directory-name entry (e.g. both core and
# literature declare "guides") -- each extension's own files are unioned in, not overwritten.
#
# Excludes any file produced by a merge_targets entry whose target lives under .claude/context/
# (e.g. context/index.json, built from index-entries.json fragments across extensions) -- these
# are not produced by provides.context copy-deploy at all and must never be flagged.
check_context_orphans() {
  local declared_files=""
  local m ext_path entries e src rel_prefix

  # Build merge_targets exclusion set (paths relative to .claude/context/).
  local excludes=""
  for m in "$EXT_DIR"/*/manifest.json; do
    [[ -f "$m" ]] || continue
    while IFS= read -r tgt; do
      [[ -z "$tgt" ]] && continue
      case "$tgt" in
        .claude/context/*)
          excludes+=$'\n'"${tgt#.claude/context/}"
          ;;
      esac
    done < <(jq -r '.merge_targets // {} | to_entries[]? | .value.target // empty' "$m" 2>/dev/null)
  done

  # Build the declared file-set across every extension's own context/ source tree.
  for m in "$EXT_DIR"/*/manifest.json; do
    [[ -f "$m" ]] || continue
    ext_path="$(dirname "$m")"
    entries=$(jq -r '.provides.context[]? // empty' "$m" 2>/dev/null)
    for e in $entries; do
      src="$ext_path/context/$e"
      if [[ -d "$src" ]]; then
        while IFS= read -r f; do
          rel_prefix="${f#"$ext_path"/context/}"
          declared_files+=$'\n'"$rel_prefix"
        done < <(find "$src" -type f 2>/dev/null)
      elif [[ -f "$src" ]]; then
        declared_files+=$'\n'"$e"
      fi
      # If neither exists on disk, check_manifest_entries already reports it; nothing to add here.
    done
  done

  local rel full f
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    full="$REPO_ROOT/$rel"
    [[ -L "$full" ]] && continue
    [[ -f "$full" ]] || continue
    f="${rel#.claude/context/}"
    if grep -qxF "$f" <<< "$excludes"; then
      continue
    fi
    if ! grep -qxF "$f" <<< "$declared_files"; then
      orphan_report "Rule L: deployed context/$f traces to no provides.context entry in any extension manifest"
    fi
  done < <(_git_deployed_files "context")
}

# Rule N: broken deployed symlink health check (distinct from the has-a-source orphan checks
# above). install-extension.sh is a separate, parallel deploy mechanism from provides.*
# copy-deploy: it creates real symlinks under .claude/{agents,commands,skills}/ pointing back
# into an extension's source tree. A dangling one of these technically DOES have a
# manifest-declared source (the extension does declare the agent/command/skill) -- the symlink's
# *target path* is simply wrong, most often because install-extension.sh's hardcoded relative
# path math no longer matches the current depth of the source-store root relative to
# .claude/{agents,commands,skills}/ (the exact regression repaired in this task's Phase 1).
# Surfaced as its own check with its own message so a future reader is pointed at
# install-extension.sh's relative-path math, not a missing extension source.
check_broken_deployed_symlinks() {
  local dir f
  for dir in "$REPO_ROOT/.claude/agents" "$REPO_ROOT/.claude/commands" "$REPO_ROOT/.claude/skills"; do
    [[ -d "$dir" ]] || continue
    for f in "$dir"/*; do
      [[ -L "$f" ]] || continue
      if [[ ! -e "$f" ]]; then
        orphan_report "Rule N: broken deployed symlink ${f#"$REPO_ROOT"/} -- target does not resolve; likely install-extension.sh relative-path drift (see its rel_path construction), not a missing extension source"
      fi
    done
  done
}

echo "Checking .claude/extensions/ documentation..."
echo

for ext_path in "$EXT_DIR"/*/; do
  ext_name=$(basename "$ext_path")
  CURRENT_EXT="$ext_name"
  EXTENSION_STATUS["$ext_name"]="PASS"

  echo "[$ext_name]"

  # Required files
  check_file "$ext_path/manifest.json" "manifest.json"
  check_file "$ext_path/EXTENSION.md" "EXTENSION.md"
  check_file "$ext_path/README.md" "README.md"

  # Manifest entry validation (only if manifest exists and is valid)
  if [[ -f "$ext_path/manifest.json" ]]; then
    if jq empty "$ext_path/manifest.json" 2>/dev/null; then
      check_manifest_entries "$ext_path"
      check_deployed_script_drift "$ext_path"
      check_routing_block "$ext_path"
      check_undeclared_skills "$ext_path"
      check_undeclared_rules "$ext_path"
      check_deployed_rule_drift "$ext_path"
      check_routing_consistency "$ext_path"
      check_deployed_skill_agents "$ext_path"
      check_readme_vs_manifest "$ext_path"
      check_referenced_scripts_declared "$ext_path"
    else
      fail "manifest.json is not valid JSON"
    fi
  fi

  if [[ "${EXTENSION_STATUS[$ext_name]}" == "PASS" ]]; then
    info "OK"
  fi
  echo
done

# Project-wide checks (not scoped to a single extension).
CURRENT_EXT="project-wide"
EXTENSION_STATUS["project-wide"]="PASS"
echo "[project-wide]"
check_dangling_contract_references
check_flat_category_orphans "agents" "Rule J"
check_flat_category_orphans "commands" "Rule K"
check_context_orphans
check_flat_category_orphans "scripts" "Rule M"
check_broken_deployed_symlinks
if [[ "${EXTENSION_STATUS[project-wide]}" == "PASS" ]]; then
  info "OK"
fi
echo

# Summary table
echo "====================================="
echo "Summary"
echo "====================================="
printf "%-15s %s\n" "Extension" "Status"
printf "%-15s %s\n" "---------" "------"
for ext in "${!EXTENSION_STATUS[@]}"; do
  printf "%-15s %s\n" "$ext" "${EXTENSION_STATUS[$ext]}"
done | sort
echo

if [[ "$FAILURES" -gt 0 ]]; then
  echo "FAIL: $FAILURES issue(s) found"
  exit 1
else
  echo "PASS: all extensions OK"
  exit 0
fi
