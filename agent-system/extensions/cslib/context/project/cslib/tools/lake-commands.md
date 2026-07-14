# CSLib Lake Commands

All lake commands for CSLib development. Derived from CONTRIBUTING.md and `lakefile.toml`.

## Cache Management Commands

### `lake exe cache get`

Downloads pre-built Mathlib `.olean` files from the Mathlib S3 cache. Avoids a
near-full Mathlib rebuild (30+ minutes) when working on a branch based on upstream/main
whose local fork's main has diverged.

```bash
lake exe cache get
```

**Usage**: Run once per branch setup. Re-run after `lake update` if the Mathlib revision
changes. Not needed on every build.

**Expected behavior**: Downloads compiled `.olean` artifacts for the pinned Mathlib commit
in `lake-manifest.json`. On success, subsequent `lake build` runs only compile CSLib
itself (seconds to minutes, not 30+ minutes).

## Build Commands

### `lake build`

Builds the entire Cslib library. Also runs **syntax linters** automatically during build.

```bash
lake build
```

### `lake build Module.Name`

Builds a single module. Preferred during development for faster feedback.

```bash
lake build Cslib.Logics.Modal.Basic
lake build Cslib.Foundations.Logic.Axioms
```

### `lake clean && lake build`

Full clean rebuild. Use when the build cache is stale or after major changes.

```bash
lake clean && lake build
```

## Test Commands

### `lake test`

Runs the test suite in `CslibTests/`.

```bash
lake test
```

## Lint Commands

### `lake lint`

Runs environment linters. Checks the elaborated environment (not just syntax).
Alternative: use `#lint` command in your editor for targeted checking.

```bash
lake lint
```

### `lake exe lint-style`

Runs text linters for style conformance (whitespace, formatting, etc.).

```bash
lake exe lint-style
```

### `lake exe lint-style --fix`

Auto-fixes text lint issues where possible.

```bash
lake exe lint-style --fix
```

## Import Management Commands

### `lake exe checkInitImports`

Verifies that all CSLib source files import `Cslib.Init`. This is a required CI check.

```bash
lake exe checkInitImports
```

Note: `weak.linter.checkInitImports` is disabled in `lakefile.toml` (compatibility issue),
but this standalone executable is still active and required by CI. See
`standards/ci-pipeline.md` for details.

### `lake exe mk_all --module`

Updates `Cslib.lean` to be a complete barrel import of all library modules. Only needed
when **adding new files** to the library.

```bash
lake exe mk_all --module
```

## Import Minimization Commands

### `lake shake --add-public --keep-implied --keep-prefix`

Checks that imports are minimized. Identifies unnecessary imports.

```bash
lake shake --add-public --keep-implied --keep-prefix
```

### `lake shake --add-public --keep-implied --keep-prefix --fix`

Auto-fixes import minimization issues.

```bash
lake shake --add-public --keep-implied --keep-prefix --fix
```

**Shake comments**: Some imports must be preserved even if not directly used:
```lean
-- shake: keep-downstream   -- needed by downstream modules
-- shake: keep-all          -- needed by all callers
```

## Quick Reference

| Command | Purpose | When to use |
|---------|---------|-------------|
| `lake exe cache get` | Download Mathlib `.olean` cache | Once per branch setup |
| `lake build` | Build + syntax linters | Phase end, always |
| `lake build Module.Name` | Scoped build | During development (faster) |
| `lake test` | Run test suite | Before PR |
| `lake lint` | Environment linters | Before PR |
| `lake exe lint-style` | Text linters | Before PR |
| `lake exe lint-style --fix` | Auto-fix text lint | Before PR |
| `lake exe checkInitImports` | Verify Cslib.Init imports | Before PR |
| `lake exe mk_all --module` | Update Cslib.lean barrel | When adding new files |
| `lake shake ...` | Check import minimization | Before PR |
| `lake shake ... --fix` | Auto-fix imports | Before PR |
| `lake clean && lake build` | Clean rebuild | When cache is stale |

See `standards/ci-pipeline.md` for the recommended order of CI verification steps.
