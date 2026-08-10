# `LITERATURE_DIR` Configuration

## Default and Override

`LITERATURE_DIR` defaults to `~/Projects/Literature` (resolved via `$HOME`). The default is set
in `literature-discover.sh`:

```bash
LITERATURE_DIR="${LITERATURE_DIR:-$HOME/Projects/Literature}"
```

It is an optional override env var / settings key: set `LITERATURE_DIR=/path/to/repo` in
`.claude/settings.json` to point at a different centralized repository. The `--lit` flag and all
`/literature` commands operate on whichever directory `LITERATURE_DIR` resolves to.

When `LITERATURE_DIR` is set, content directories use a `sources/` subdirectory prefix.

## Two-Tier Fallback

| Condition | Resolution |
|-----------|------------|
| `LITERATURE_DIR` set, directory exists | Use the centralized repository |
| `LITERATURE_DIR` set, directory missing | Fall back to per-project `specs/literature/` |
| `LITERATURE_DIR` unset | Use per-project directories directly |

## Related

- `domain/literature-index.md` — what lives inside `$LITERATURE_DIR`
- `patterns/literature-command-modes.md` — commands that read this variable
