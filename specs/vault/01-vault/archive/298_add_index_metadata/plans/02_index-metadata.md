# Plan: Add domain/subdomain metadata to index.json entries

**Task**: 298
**Date**: 2026-03-26
**Based on**: [01_index-metadata.md](../reports/01_index-metadata.md)

## Overview

Add `domain` and `subdomain` fields to 134 entries in Website `.claude/context/index.json` that currently have these fields set to `null`.

## Phase 1: Update index.json [NOT STARTED]

**Action**: Run a single jq command against the index.json file.

**Logic**:
- For each entry where `domain == null`: set `domain` to `"project"`
- For each entry where `subdomain == null`: extract the second path component (`path | split("/")[1]`)
- Special case: if second component is `"lean4"`, use `"lean"` instead
- Write back with 2-space indentation

**Command**:
```bash
jq --indent 2 '
  .entries |= [.[] |
    if .domain == null then
      .domain = "project" |
      .subdomain = (.path | split("/")[1] | if . == "lean4" then "lean" else . end)
    else .
    end
  ]
' index.json > index_updated.json && mv index_updated.json index.json
```

## Phase 2: Verify [NOT STARTED]

**Checks**:
1. Count entries with null domain (expect 0)
2. Count entries with null subdomain (expect 0)
3. Total entry count unchanged (expect 256)
4. Validate lean4 entries use subdomain "lean"
5. Spot-check a few entries from different path prefixes

## Risks

- **Low**: jq may reorder keys. Acceptable as long as all fields are preserved.
- **Mitigation**: Verify total entry count and spot-check before committing.
