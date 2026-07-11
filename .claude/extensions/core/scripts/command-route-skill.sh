#!/usr/bin/env bash
# command-route-skill.sh — Resolve task_type to skill_name via extension manifest lookup
#
# USAGE:
#   source .claude/scripts/command-route-skill.sh "$operation" "$TASK_TYPE" "$default_skill" "${effort_flag:-}"
#   echo "$SKILL_NAME"  # resolved skill name
#
# PARAMETERS:
#   $1 = operation      : "research" | "plan" | "implement"
#   $2 = task_type      : TASK_TYPE exported by command-gate-in.sh
#                         May be simple ("neovim") or compound ("founder:deck")
#   $3 = default_skill  : fallback if no extension routing found
#                         e.g., "skill-researcher", "skill-planner", "skill-implementer"
#   $4 = effort_flag    : (optional) "hard" | "fast" | "" | unset
#                         When "hard", Steps 4a-4e resolve to the hard-mode skill.
#
# EXPORTS:
#   SKILL_NAME          : resolved skill name (from extension, default, or hard variant)
#
# EDGE CASES:
#   - No extensions loaded: SKILL_NAME = $default_skill (or hard variant thereof)
#   - Missing manifest files: skipped silently
#   - Empty routing section: falls back to default
#   - Compound keys (e.g., "founder:deck"): tries exact key first, then base type
#   - Hard mode with no hard variant: emits stderr note, uses standard skill
#
# NOTE: This script uses source semantics. It must be sourced (not executed) to
#       export SKILL_NAME to the calling shell environment. It must NEVER call
#       exit — a faulty resolution at worst leaves SKILL_NAME at the standard
#       skill, which is the safe default.

_route_operation="$1"
_route_task_type="$2"
_route_default_skill="$3"
_effort_flag="${4:-}"

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

# Step 4: Hard-mode resolution (only when effort_flag="hard")
#
# Precedence (first match wins, non-core scanned before core):
#   4a. Non-core extension routing_hard[$op][$task_type] exact match
#   4b. Non-core extension routing_hard[$op][$base_type] compound-key fallback
#   4c. Core extension   routing_hard[$op][$task_type] exact match
#   4d. Core extension   routing_hard[$op][$base_type] compound-key fallback
#   4e. Append -hard to the resolved standard SKILL_NAME; use only if
#       .claude/skills/${candidate}-hard/SKILL.md exists on disk.
#       Otherwise: emit a stderr note and leave SKILL_NAME unchanged (safe default).
#
# "Extension overrides core" is guaranteed because non-core manifests are scanned
# first (Steps 4a-4b) before the dedicated core pass (Steps 4c-4d), regardless of
# glob ordering. The CORE manifest is identified by the routing_exempt:true field.

if [ "$_effort_flag" = "hard" ]; then
  _hard_skill=""

  # Step 4a — non-core extension routing_hard exact match (first hit wins)
  for _manifest in .claude/extensions/*/manifest.json; do
    if [ -f "$_manifest" ]; then
      # Skip the core manifest in the non-core pass
      _is_core=$(jq -r '.routing_exempt // false' "$_manifest" 2>/dev/null)
      if [ "$_is_core" = "true" ]; then
        continue
      fi
      _ext_hard=$(jq -r --arg op "$_route_operation" --arg tt "$_route_task_type" \
        '.routing_hard[$op][$tt] // empty' "$_manifest" 2>/dev/null)
      if [ -n "$_ext_hard" ]; then
        _hard_skill="$_ext_hard"
        break
      fi
    fi
  done

  # Step 4b — non-core compound-key fallback (base_type) if no exact hit yet
  if [ -z "$_hard_skill" ] && echo "$_route_task_type" | grep -q ":"; then
    _base_type_hard=$(echo "$_route_task_type" | cut -d: -f1)
    for _manifest in .claude/extensions/*/manifest.json; do
      if [ -f "$_manifest" ]; then
        _is_core=$(jq -r '.routing_exempt // false' "$_manifest" 2>/dev/null)
        if [ "$_is_core" = "true" ]; then
          continue
        fi
        _ext_hard=$(jq -r --arg op "$_route_operation" --arg tt "$_base_type_hard" \
          '.routing_hard[$op][$tt] // empty' "$_manifest" 2>/dev/null)
        if [ -n "$_ext_hard" ]; then
          _hard_skill="$_ext_hard"
          break
        fi
      fi
    done
  fi

  # Step 4c — core routing_hard exact match (dedicated pass on core manifest)
  if [ -z "$_hard_skill" ]; then
    _core_manifest=""
    for _manifest in .claude/extensions/*/manifest.json; do
      if [ -f "$_manifest" ]; then
        _is_core=$(jq -r '.routing_exempt // false' "$_manifest" 2>/dev/null)
        if [ "$_is_core" = "true" ]; then
          _core_manifest="$_manifest"
          break
        fi
      fi
    done
    if [ -n "$_core_manifest" ]; then
      _ext_hard=$(jq -r --arg op "$_route_operation" --arg tt "$_route_task_type" \
        '.routing_hard[$op][$tt] // empty' "$_core_manifest" 2>/dev/null)
      if [ -n "$_ext_hard" ]; then
        _hard_skill="$_ext_hard"
      fi
    fi
  fi

  # Step 4d — core compound-key fallback (base_type against core manifest)
  if [ -z "$_hard_skill" ] && echo "$_route_task_type" | grep -q ":"; then
    _base_type_hard=$(echo "$_route_task_type" | cut -d: -f1)
    if [ -z "$_core_manifest" ]; then
      for _manifest in .claude/extensions/*/manifest.json; do
        if [ -f "$_manifest" ]; then
          _is_core=$(jq -r '.routing_exempt // false' "$_manifest" 2>/dev/null)
          if [ "$_is_core" = "true" ]; then
            _core_manifest="$_manifest"
            break
          fi
        fi
      done
    fi
    if [ -n "$_core_manifest" ]; then
      _ext_hard=$(jq -r --arg op "$_route_operation" --arg tt "$_base_type_hard" \
        '.routing_hard[$op][$tt] // empty' "$_core_manifest" 2>/dev/null)
      if [ -n "$_ext_hard" ]; then
        _hard_skill="$_ext_hard"
      fi
    fi
  fi

  # Step 4e — -hard append fallback: only if SKILL.md exists (safety gate)
  # This guarantees the fallback NEVER resolves to an undeployed agent.
  if [ -n "$_hard_skill" ]; then
    SKILL_NAME="$_hard_skill"
  else
    _candidate_hard="${SKILL_NAME}-hard"
    if [ -f ".claude/skills/${_candidate_hard}/SKILL.md" ]; then
      SKILL_NAME="$_candidate_hard"
    else
      echo "[route] No hard variant for ${SKILL_NAME}; using standard skill" >&2
    fi
  fi
fi

# Clean up local variables to avoid polluting caller's environment
unset _route_operation _route_task_type _route_default_skill _manifest _ext_skill _base_type
unset _effort_flag _hard_skill _ext_hard _candidate_hard _base_type_hard _core_manifest _is_core

export SKILL_NAME
