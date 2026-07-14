# CSLib CI Pipeline

The complete ordered verification checklist for CSLib contributions. Derived from CONTRIBUTING.md
and `lakefile.toml`.

## Verification Order

Run these steps in order before submitting a PR. Each step catches different issues.

### Step 0: `lake exe cache get`

**Purpose**: Download pre-built Mathlib `.olean` files from the Mathlib cache.

Run this once when setting up a new branch that is based on upstream/main. This is
especially critical when the local fork's main has diverged from upstream — without
cache fetching, `lake build` triggers a near-full rebuild of Mathlib (30+ minutes).

```bash
lake exe cache get
```

**When to run**: Once per branch setup, not on every build. Re-run only if switching
to a different Mathlib revision (e.g., after a `lake update`).

### Step 1: `lake build`

**Purpose**: Compile the library and run syntax linters.

Syntax linters run during build and appear as warnings inline. This catches:
- Syntax errors
- Style warnings from the mathlib standard linter set
- Type errors

```bash
lake build
# Or for a single module (faster during development):
lake build Cslib.Logics.Modal.Basic
```

### Step 2: `lake exe checkInitImports`

**Purpose**: Verify all CSLib files import `Cslib.Init`.

Every CSLib file must begin with `import Cslib.Init`. This sets up default linting rules
and common tactics for the library.

```bash
lake exe checkInitImports
```

**Important distinction**: `weak.linter.checkInitImports` is **disabled in lakefile.toml**
(due to incompatibility with the current setup), but `lake exe checkInitImports` is a
**standalone executable** that remains active and required. The CI enforces this check via
the executable, not the lakefile linter option.

### Step 3: `lake lint`

**Purpose**: Run environment linters.

Environment linters check the elaborated environment (not just syntax). They catch issues
that only manifest after type-checking, such as:
- Missing `@[simp]` attributes
- Linting rule violations from Batteries/Mathlib

```bash
lake lint
# Alternatively, use the #lint command in your editor for targeted checking
```

### Step 4: `lake exe lint-style`

**Purpose**: Run text linters for style conformance.

Text linters check source file formatting and style conventions.

```bash
lake exe lint-style
# Auto-fix style issues:
lake exe lint-style --fix
```

### Step 5: `lake test`

**Purpose**: Run the test suite in `CslibTests/`.

```bash
lake test
```

### Step 6: `lake exe mk_all --module`

**Purpose**: Update `Cslib.lean` to import all library files.

Only needed when **adding new files** to the library. Ensures `Cslib.lean` remains a
complete barrel import of all modules.

```bash
lake exe mk_all --module
```

### Step 7: `lake shake --add-public --keep-implied --keep-prefix`

**Purpose**: Check that imports are minimized.

Identifies unnecessary imports and ensures the import graph is clean.

```bash
lake shake --add-public --keep-implied --keep-prefix
# Auto-fix minimization issues:
lake shake --add-public --keep-implied --keep-prefix --fix
```

**Special shake comments**: Some imports must be preserved even if unused directly:
```lean
-- shake: keep-downstream   -- preserve for downstream modules
-- shake: keep-all          -- preserve for all callers
```

These comments appear in `Cslib/Init.lean` to prevent its critical imports from being
removed by the auto-fixer.

## Quick Reference

| Step | Command | When |
|------|---------|------|
| 0 | `lake exe cache get` | Once per branch setup (when based on upstream/main) |
| 1 | `lake build` | Always |
| 2 | `lake exe checkInitImports` | Always |
| 3 | `lake lint` | Always |
| 4 | `lake exe lint-style` | Always |
| 5 | `lake test` | Always |
| 6 | `lake exe mk_all --module` | Only when adding new files |
| 7 | `lake shake ...` | Before PR (import cleanup) |

See `tools/lake-commands.md` for all available lake commands and their options.
