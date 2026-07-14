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
  inline `jq` logic in `skills/skill-literature/SKILL.md`. Quarantined task #847.
- **zotero-index-remove.sh** - Formerly removed entries from the Zotero index; superseded by
  the inline `jq` logic in `skills/skill-literature/SKILL.md`. Quarantined task #847.

## Migration Status

Neither script is declared in `manifest.json` `provides.scripts` and neither is invoked by any
active skill, agent, or command. The functionality they provided is handled inline via `jq` in
`skills/skill-literature/SKILL.md`.

## Using Deprecated Code

To reactivate a quarantined script:

1. Review the script to understand its original purpose and interface.
2. Confirm no equivalent inline logic already covers the same behavior.
3. If needed, `git mv` the script back to `.claude/extensions/literature/scripts/` and re-add
   it to `manifest.json` `provides.scripts`.
4. Test thoroughly before committing.

## Removal Policy

Quarantined scripts may be hard-deleted in a future task when:

- No reference value remains (confirmed by a fresh dead-code audit).
- No migration or recovery need exists.

## Related Documentation

- [Literature Extension README](../../README.md) - Deployment status and active script list
- [skill-literature/SKILL.md](../../skills/skill-literature/SKILL.md) - Active inline index logic
