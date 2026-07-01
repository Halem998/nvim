# Research Report: Task 794 — literature-discover.sh query fix + Zotero UX hint

**Confirmed baseline**: `.claude/extensions/literature/scripts/literature-discover.sh` (canonical, 613 lines) and `.claude/scripts/literature-discover.sh` (flat) are currently byte-identical (`diff` empty) — task-793 dual-copy model intact and must be preserved. No automated sync script exists; re-sync is a manual `cp` after editing canonical (executable bit preserved).

## FIX 1 — slug query is useless (lines 105–132)

Current: reads only `.project_name` from `specs/state.json`, converts `_`/`-` to spaces (line 118), uses as `task_terms`. This is bookkeeping-slug noise, not subject matter.

**Change**: replace single `task_name` lookup with two reads — `.description // ""` and `.title // ""` — plus an existence check independent of a non-null value (`title` can legitimately be `null` on healthy tasks — verified: task 795 has `title: null` with full `description`). Design:

```bash
if [ -n "$TASK_NUM" ]; then
  git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  state_file="$git_root/specs/state.json"

  if [ -f "$state_file" ]; then
    task_found=$(jq -r --arg n "$TASK_NUM" \
      '[.active_projects[] | select(.project_number == ($n|tonumber))] | length' \
      "$state_file" 2>/dev/null || echo "0")

    if [ "$task_found" -gt 0 ]; then
      task_description=$(jq -r --arg n "$TASK_NUM" \
        '.active_projects[] | select(.project_number == ($n|tonumber)) | .description // ""' \
        "$state_file" 2>/dev/null)
      task_title=$(jq -r --arg n "$TASK_NUM" \
        '.active_projects[] | select(.project_number == ($n|tonumber)) | .title // ""' \
        "$state_file" 2>/dev/null)

      task_terms=""
      [ -n "$task_description" ] && [ "$task_description" != "null" ] && task_terms="$task_description"
      [ -n "$task_title" ] && [ "$task_title" != "null" ] && task_terms="$task_terms $task_title"
      task_terms=$(echo "$task_terms" | sed -E 's/^ +| +$//g')

      if [ -z "$task_terms" ]; then
        echo "Error: Task $TASK_NUM has no description or title in specs/state.json to build a search query from" >&2
        exit 2
      fi

      if [ -n "$SEARCH_TERMS" ]; then
        SEARCH_TERMS="$task_terms $SEARCH_TERMS"
      else
        SEARCH_TERMS="$task_terms"
      fi
    else
      echo "Error: Task $TASK_NUM not found in specs/state.json" >&2
      exit 2
    fi
  else
    echo "Error: specs/state.json not found" >&2
    exit 2
  fi
fi
```

Key points:
- `.project_name` (slug) dropped entirely — matches user decision
- No new stopword code needed: `filter_terms()`/`FILTERED_TERMS` (lines 169–201, invoked line 196) already operates on final `SEARCH_TERMS` regardless of source, so description+title text gets <3-char and stop-word filtering for free. (Task desc's "~line 454" reference is `FILTERED_TERMS` *usage* inside `tier3_search`, not its definition; actual filter is 169–201/196 — no changes there)
- `--task N "extra terms"` unchanged — extra terms still append after `task_terms`
- Free-text path (`literature-discover.sh "terms"`, no `--task`) never enters the `if [ -n "$TASK_NUM" ]` block → provably unaffected
- Long descriptions (1000+ words) pass through filter_terms as-is (punctuation stays attached); harmless (noise tokens don't break Tier 1/Zotero substring matching, mildly dilute Tier 3 query) — known limitation, not blocking

## FIX 2 — silent missing Zotero export (lines 334–336) + swallow points

Current `tier2_search`:
```bash
tier2_search() {
  local zotero_library="$LITERATURE_DIR/zotero-library.json"
  if [ ! -f "$zotero_library" ]; then
    return 0
  fi
```

Add stderr hint matching `zotero-search.sh` wording (that script lines 143–169: "File -> Export Library...", format "Better CSL JSON", check "Keep updated", save to `~/Projects/Literature/zotero-library.json`):
```bash
  if [ ! -f "$zotero_library" ]; then
    echo "Tier 2 (Zotero) skipped: no export found at $zotero_library" >&2
    echo "  To enable: in Zotero, File -> Export Library -> format \"Better CSL JSON\", check \"Keep updated\", save to $zotero_library" >&2
    return 0
  fi
```
`tier2_search` runs once per invocation (no loop) → satisfies "once per run" without a guard flag. Exit status unchanged.

**CRITICAL: the hint must clear two stderr-swallow points:**
1. Lines 591–598 run each tier as `tier2_search 2>/dev/null || true`. This outer `2>/dev/null` discards the whole function's stderr — the new hint would be silently swallowed here UNLESS this call site is changed to `tier2_search || true` (drop the blanket redirect)
2. Inside `tier2_search`, everything else already redirects its own stderr (`jq ... 2>/dev/null`, `zotero_script` uses `2>/dev/null`) EXCEPT two `python3 -c` calls building `authors_arr` (~lines 403–408, 410) with no redirect. Low-risk; for defensive parity add `2>/dev/null` to those two calls when the outer blanket is removed, so only the intentional hint escapes
3. **Out of scope (noted gap)**: `.claude/extensions/literature/commands/literature.md` (~lines 125–139) invokes the script as `discover_results=$("$DISCOVER_SCRIPT" --task "$task_num" ... 2>/dev/null)`, capturing whole-script stderr. So after fixing 1+2 the hint surfaces on DIRECT invocation but NOT through the full `/literature N` command path. literature.md is not in PRIMARY FILES and touching the pipeline is out of scope — flag as follow-up

Verification (b) is best validated by invoking the script directly:
```bash
LITERATURE_DIR=/nonexistent-dir bash .claude/scripts/literature-discover.sh "some terms" 1>/tmp/out.json 2>/tmp/err.txt
jq . /tmp/out.json      # must still parse
grep -i "zotero" /tmp/err.txt   # hint present
```

## check-extension-docs.sh baseline (verification d)
Ran before changes: overall `FAIL: 2 issue(s)`, but both are **pre-existing and unrelated** — lean extension (`routing_hard target declared but not deployed: skill-lean-research-hard` / `skill-lean-implementation-hard`), because lean isn't installed in this repo. The `literature` extension section reports `PASS`. Verifier should confirm the `literature` line stays `PASS` (and lean's 2 failures unchanged), NOT that overall exit goes green (it won't, independent of this task).

## Files
- Canonical: `.claude/extensions/literature/scripts/literature-discover.sh`
- Flat (re-sync byte-identical, preserve executable bit): `.claude/scripts/literature-discover.sh`
- Wording reference: `.claude/extensions/literature/scripts/zotero-search.sh` (lines 143–169)
- Out-of-scope noted gap: `.claude/extensions/literature/commands/literature.md` (~lines 125–139)

## Memory candidates
1. Tier-call stderr-swallow pattern (outer `2>/dev/null || true` on tier functions)
2. task-793 dual-copy flat-deploy model (canonical extension script + byte-identical flat copy via provides.scripts)
3. state.json `title`/`description` nullability (title can be null on healthy tasks)
