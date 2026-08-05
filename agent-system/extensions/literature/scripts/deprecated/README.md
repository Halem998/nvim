# Deprecated Scripts

Dead-code Zotero index scripts preserved for reference (never deleted).

## Purpose

This directory contains scripts that were confirmed to have zero live callers within the
literature extension and were quarantined rather than hard-deleted, per the
QUARANTINE-NEVER-DELETE posture. Files are retained for:

- Historical reference
- Understanding the evolution of the Zotero index workflow
- Recovery if equivalent functionality is ever needed again

## Contents

- **zotero-index-add.sh** - Formerly added entries to the Zotero index; superseded by the
  inline `jq` logic in `skills/skill-literature/SKILL.md`. Quarantined during the same removal
  that dropped it from `manifest.json`. Retired rather than repaired, for four concrete reasons:
  - **Schema mismatch**: it built a ~20-field entry (`zotero_key`, `citation_key`, `title`,
    `authors`, `year`, `item_type`, `abstract_snippet`, `keywords`, `tags`, `collections`,
    `has_pdf`, `pdf_path`, `has_chunks`, `chunk_dir`, `chunk_count`, `token_count`,
    `relevance_keywords`, `notes_summary`, `added_at`, `last_retrieved`), while
    `literature-briefing.sh` — the actual `--lit` consumer — reads only a 4-field shape:
    `{doc_id, relevance, added, source}`.
  - **Wrong target file**: it wrote `specs/zotero-index.json`; `literature-briefing.sh` reads
    `specs/literature-index.json`. These are different files, not different views of one file.
  - **Unmet dependencies**: it depends on the `zot` CLI (via `zotero-read.sh`) and prints setup
    instructions referencing `/zotero --setup`, a command that does not exist in this project's
    command set (`commands/` contains only `cite.md` and `literature.md`).
  - **Why retirement over repair**: repairing it would require schema translation plus a
    target-file change plus removing the `zot`/`--setup` dependency — a rewrite, not a fix.
    Sub-index registration instead uses the documented `jq` append pattern in
    `skills/skill-literature/SKILL.md`'s "Sub-Index Management" section ("Add: Append a
    Document Entry"), which already writes the correct 4-field shape to the correct file.
- **zotero-index-remove.sh** - Formerly removed entries from the Zotero index; superseded by
  the inline `jq` logic in `skills/skill-literature/SKILL.md`. Quarantined during the same removal that dropped it from `manifest.json`.

## Migration Status

Neither script is declared in `manifest.json` `provides.scripts` and neither is invoked by any
active skill, agent, or command. The functionality they provided is handled inline via `jq` in
`skills/skill-literature/SKILL.md`.

## Using Deprecated Code

To reactivate a quarantined script:

1. Review the script to understand its original purpose and interface.
2. Confirm no equivalent inline logic already covers the same behavior.
3. If needed, `git mv` the script back to `agent-system/extensions/literature/scripts/` and re-add
   it to `manifest.json` `provides.scripts`.
4. Test thoroughly before committing.

## Removal Policy

Quarantined scripts may be hard-deleted in a future task when:

- No reference value remains (confirmed by a fresh dead-code audit).
- No migration or recovery need exists.

## Related Documentation

- [Literature Extension README](../../README.md) - Deployment status and active script list
- [skill-literature/SKILL.md](../../skills/skill-literature/SKILL.md) - Active inline index logic
