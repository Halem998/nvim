# Research: Add --lit Flag to parse-command-args.sh

## Task
Task 688 | Type: meta | Status: researching

## Summary
Both `parse-command-args.sh` files (the live script and its extension core copy) are identical and follow a consistent three-part pattern for each boolean flag: initialize to "false", detect with a `[[ "$remaining" =~ --flag ]]` conditional, and strip with a `sed` expression in the FOCUS_PROMPT chain. Adding `--lit` requires inserting four lines — one in the header comment, one initialization, one detection block, one sed strip — plus updating the export line, mirrored identically in both files.

## Findings

### Current Flag Pattern

Each boolean flag (`--clean`, `--force`, `--exploit`, `--explore`) follows this exact three-part structure:

**Part 1 — Header comment** (lines 10–22): Each exported variable is documented.
```
#   EXPLORE_FLAG   — "true" or "false" (--explore mode hint for team research)
```

**Part 2 — Initialization** (lines 66–73, Step 4 block):
```bash
EXPLORE_FLAG="false"
```

**Part 3 — Detection** (lines 104–109):
```bash
if [[ "$remaining" =~ --exploit ]]; then
  EXPLOIT_FLAG="true"
fi
if [[ "$remaining" =~ --explore ]]; then
  EXPLORE_FLAG="true"
fi
```

**Part 4 — FOCUS_PROMPT stripping** (lines 111–124, Step 5 chain):
```bash
  | sed 's/--exploit//g' \
  | sed 's/--explore//g' \
  | xargs)
```

**Part 5 — Export line** (line 132):
```bash
export TASK_NUMBERS REMAINING_ARGS TEAM_MODE TEAM_SIZE EFFORT_FLAG MODEL_FLAG CLEAN_FLAG FORCE_FLAG EXPLOIT_FLAG EXPLORE_FLAG FOCUS_PROMPT
```

### Required Changes

The same four-part change applies to both files. Line numbers are identical since both files are character-for-character copies.

#### Change 1: Header comment — after line 21, insert:
```bash
#   LIT_FLAG       — "true" or "false" (--lit enables literature context injection)
```

#### Change 2: Step 4 initialization — after line 73, insert:
```bash
  LIT_FLAG="false"
```

#### Change 3: Step 4 detection — after line 109, insert:
```bash
  if [[ "$remaining" =~ --lit ]]; then
    LIT_FLAG="true"
  fi
```

#### Change 4: Step 5 FOCUS_PROMPT sed chain — replace line 123 (the `--explore` sed line):
```bash
    | sed 's/--explore//g' \
    | sed 's/--lit//g' \
    | xargs)
```
(i.e., insert `| sed 's/--lit//g' \` before `| xargs)`)

#### Change 5: Export line — append `LIT_FLAG` to line 132:
```bash
export TASK_NUMBERS REMAINING_ARGS TEAM_MODE TEAM_SIZE EFFORT_FLAG MODEL_FLAG CLEAN_FLAG FORCE_FLAG EXPLOIT_FLAG EXPLORE_FLAG LIT_FLAG FOCUS_PROMPT
```

### Extension Core Sync

The file at `.claude/extensions/core/scripts/parse-command-args.sh` is a byte-for-byte copy of `.claude/scripts/parse-command-args.sh` — same content, same line numbers. All five changes above must be applied to both files identically.

There are no other copies of `parse-command-args.sh` in the repository:
- Primary: `.claude/scripts/parse-command-args.sh`
- Extension core: `.claude/extensions/core/scripts/parse-command-args.sh`

## Recommendations

Apply changes in order to both files:

1. Insert LIT_FLAG header comment after the EXPLORE_FLAG comment line
2. Add `LIT_FLAG="false"` initialization in the Step 4 block after `EXPLORE_FLAG="false"`
3. Add the `--lit` detection `if` block after the `--explore` detection block
4. Add `| sed 's/--lit//g' \` to the Step 5 sed chain before `| xargs)`
5. Append `LIT_FLAG` to the export line (between `EXPLORE_FLAG` and `FOCUS_PROMPT`)

Both files are identical so the same diff applies to each. Use the Edit tool with exact `old_string`/`new_string` matching on unique surrounding context to make the edits safely.
