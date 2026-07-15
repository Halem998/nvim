# Hard-Mode Routing: Composition Model

This document describes the `--hard` routing resolution implemented in
`command-route-skill.sh`. It covers the 5-step precedence, the
"extension overrides core" rule, and the safety gate that prevents
resolution to undeployed agents.

**Scope**: This document covers the script/skill routing layer only.
The CLAUDE.md "Routing Mechanism" and "Hard Mode" sections are maintained
separately by task 770. Do NOT edit CLAUDE.md based on this document.

---

## Overview

When a command is invoked with `--hard`, `command-route-skill.sh` receives
`effort_flag="hard"` as its 4th argument. After standard routing resolves
`SKILL_NAME` (Steps 1-3), the script applies a 5-step hard-mode resolution
to override `SKILL_NAME` with the appropriate hard-mode skill.

---

## 5-Step Resolution Precedence

Resolution proceeds in order; the **first match wins** and short-circuits
all remaining steps.

```
Given: operation ("research"|"plan"|"implement"), task_type, effort_flag="hard"

Step 4a: Search non-core extension manifests for routing_hard[$op][$task_type]
         → First non-core manifest hit → SKILL_NAME = that skill; DONE

Step 4b: If no hit and task_type contains ":", compute base_type (split on ":")
         Search non-core extension manifests for routing_hard[$op][$base_type]
         → First non-core manifest hit → SKILL_NAME = that skill; DONE

Step 4c: Search core manifest (routing_exempt: true) for routing_hard[$op][$task_type]
         → Hit → SKILL_NAME = that skill; DONE

Step 4d: If no hit and task_type contains ":", compound-key fallback against core
         Search core manifest for routing_hard[$op][$base_type]
         → Hit → SKILL_NAME = that skill; DONE

Step 4e: -hard append fallback (only reaches here if all manifest lookups failed)
         candidate = "${SKILL_NAME}-hard"
         if .claude/skills/${candidate}/SKILL.md exists:
           SKILL_NAME = candidate; DONE
         else:
           echo "[route] No hard variant for ${SKILL_NAME}; using standard skill" >&2
           SKILL_NAME unchanged (safe default = standard skill); DONE
```

---

## "Extension Overrides Core" Rule

Non-core extensions (Steps 4a-4b) are scanned **before** the core extension
(Steps 4c-4d). This is deterministic regardless of glob ordering because the
core manifest is identified by the `routing_exempt: true` field and explicitly
skipped during the non-core pass.

**Consequence**: If both a non-core extension and the core manifest declare a
`routing_hard` entry for the same `($op, $task_type)` pair, the non-core
extension's entry wins unconditionally.

**Example** (hypothetical override):
```
Core:    routing_hard.implement.meta = "skill-implementer-hard"
Non-core: routing_hard.implement.meta = "skill-myext-implementation-hard"
Result:  SKILL_NAME = "skill-myext-implementation-hard"
```

---

## SKILL.md Existence Safety Gate (Step 4e Only)

The `-hard` append fallback in Step 4e is the **only** step that gates on
`SKILL.md` existence. Steps 4a-4d trust that manifest-declared `routing_hard`
entries point to deployed skills (the manifest author is responsible).

Step 4e exists to handle task types where no manifest declares a `routing_hard`
entry but a hard variant of the standard skill happens to be deployed on disk.
The gate prevents silent routing to an undeployed agent in this fallback path.

```bash
# Step 4e safety gate (in command-route-skill.sh)
if [ -f ".claude/skills/${_candidate_hard}/SKILL.md" ]; then
  SKILL_NAME="$_candidate_hard"
else
  echo "[route] No hard variant for ${SKILL_NAME}; using standard skill" >&2
  # SKILL_NAME unchanged — falls back to the standard skill
fi
```

---

## Deployed Hard Skills (as of task 768)

The following hard skills have deployed SKILL.md files and are reachable via
the `-hard` append fallback (Step 4e) or via manifest routing (Steps 4a-4d):

| Skill | Reachable via |
|-------|---------------|
| `skill-researcher-hard` | Core manifest routing_hard + Step 4e fallback |
| `skill-planner-hard` | Core manifest routing_hard + Step 4e fallback |
| `skill-implementer-hard` | Core manifest routing_hard + Step 4e fallback |
| `skill-cslib-research-hard` | CSLib extension manifest routing_hard |
| `skill-cslib-implementation-hard` | CSLib extension manifest routing_hard |
| `skill-orchestrate-hard` | Separate path (see note below) |

---

## Orchestrate-Hard: Separate Reader

`skill-orchestrate-hard` (invoked by `/orchestrate --hard`) uses a **separate
inline manifest reader** in its own SKILL.md. That reader:

- Reads agent names (not skill names) from `routing_hard`
- Uses last-match-wins semantics (not first-match-wins)
- Does NOT call `command-route-skill.sh`

This is intentional and documented rather than refactored. The two paths
serve different purposes: `command-route-skill.sh` routes skills for single
invocations; `skill-orchestrate-hard` routes agents for autonomous lifecycle
orchestration.

---

## First-Match vs Last-Match Precedence

`command-route-skill.sh` uses **first-match-wins** within each pass (non-core
manifests and core manifest). This is consistent with the standard routing
(Steps 1-2) and provides predictable, auditable behavior.

`skill-orchestrate-hard` uses **last-match-wins** in its inline reader (a
consequence of its shell loop structure). Do not rely on this distinction
when declaring routing_hard entries intended for both code paths.

---

## Adding routing_hard Entries

To route a new task type to a hard skill, add a `routing_hard` block to the
relevant extension's `manifest.json`:

```json
{
  "routing_hard": {
    "research": {
      "mytype": "skill-mytype-research-hard"
    },
    "plan": {
      "mytype": "skill-planner-hard"
    },
    "implement": {
      "mytype": "skill-mytype-implementation-hard"
    }
  }
}
```

Ensure the declared skill directory and `SKILL.md` exist before adding the
entry. Undeclared-but-deployed skills are automatically reachable via Step 4e.

---

## Related Files

- `.claude/scripts/command-route-skill.sh` — Implementation (with inline comments)
- `.claude/extensions/core/manifest.json` — Core routing_hard entries
- `.claude/extensions/cslib/manifest.json` — CSLib routing_hard entries
- `.claude/extensions/lean/manifest.json` — Lean routing_hard entries (note: lean hard skills not yet deployed)
