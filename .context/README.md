# .context/ -- Project Conventions

User-defined project conventions and domain knowledge specific to this
repository that no extension covers.

## What belongs here

- Project-specific coding conventions (e.g., naming rules, indent overrides)
- Domain knowledge unique to this project
- Standards specific to THIS repository that no extension provides

Files are indexed in `index.json` for automated discovery by agents.

## What does NOT belong here

| Content type | Correct location |
|---|---|
| Agent system patterns (orchestration, formats, workflows) | `.claude/context/` |
| Language-specific standards and tool references | Extensions (`agent-system/extensions/*/context/`) |
| Learned facts from development work | `.memory/` |
| User preferences and behavioral corrections | Claude auto-memory (`~/.claude/projects/`) |

## How it works

Agents query `.context/index.json` alongside `.memory/` when loading
project knowledge. Both systems are independent and loaded in parallel.
The extension loader does not manage this directory -- it is entirely
user-managed.

For the full context architecture, see `.claude/context/architecture/context-layers.md`.

## Adding entries

Add files to this directory, then register them in `index.json`:

```json
{
  "path": "my-convention.md",
  "description": "Brief description of the convention",
  "line_count": 25,
  "load_when": {
    "languages": ["neovim"],
    "agents": ["general-research-agent"]
  }
}
```

Paths are relative to `.context/`.
