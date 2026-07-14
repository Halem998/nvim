# CSLib Linters

The three linter categories and import minimization tooling in CSLib. Derived from
CONTRIBUTING.md and `lakefile.toml`.

## Linter Categories

### 1. Syntax Linters

Run automatically during `lake build`. Appear as inline warnings in the editor as you write code.

These catch:
- Syntax errors
- Style violations flagged by the mathlib standard linter set
- Type-level warnings visible at elaboration time

```bash
# Syntax linters run as part of the build:
lake build
```

No separate command to run syntax linters alone -- they are always active during builds.

### 2. Environment Linters

Run with `lake lint` or the `#lint` command in the editor. Check the elaborated environment
after type-checking.

These catch:
- Missing `@[simp]` attributes on expected lemmas
- Violations of environment-level linting rules inherited from Batteries/Mathlib
- Module-level documentation requirements

```bash
lake lint
```

Or in the editor: place `#lint` at the bottom of a file for targeted checking.

### 3. Text Linters

Run with `lake exe lint-style`. Check source file formatting and text conventions.

These catch:
- Trailing whitespace
- Incorrect line endings
- Header format violations
- Other text-level style issues

```bash
lake exe lint-style

# Auto-fix text lint issues:
lake exe lint-style --fix
```

## Import Minimization: `lake shake`

`lake shake` is not technically a linter, but is part of the CI process. It checks that
each file's imports are minimized (i.e., no unused imports are included).

```bash
# Check import minimization:
lake shake --add-public --keep-implied --keep-prefix

# Auto-fix:
lake shake --add-public --keep-implied --keep-prefix --fix
```

### Shake Comments

To preserve an import that `lake shake` would otherwise remove, add a comment:

```lean
-- shake: keep-downstream   -- preserve because downstream modules need it
-- shake: keep-all          -- preserve because all callers need it
```

These comments appear in `Cslib/Init.lean` to protect its critical imports from the
auto-fixer. When adding a `keep-` comment, document why the import must be preserved.

## Disabled Linters

The following linters are **disabled in `lakefile.toml`** due to incompatibility issues:

| Linter | Disabled Setting | Reason |
|--------|-----------------|--------|
| `pythonStyle` | `weak.linter.pythonStyle = false` | Does not work with CSLib codebase |
| `checkInitImports` | `weak.linter.checkInitImports = false` | Incompatible with current setup; use `lake exe checkInitImports` instead |
| `allScriptsDocumented` | `weak.linter.allScriptsDocumented = false` | Does not work with CSLib codebase |
| `unicodeLinter` | `weak.linter.unicodeLinter = false` | CSLib uses Unicode not in Mathlib |

**Important**: `checkInitImports` is disabled as a _lakefile linter option_, but
`lake exe checkInitImports` (the standalone executable) is **still active and required** by
CI. Always run `lake exe checkInitImports` before submitting a PR. See
`standards/ci-pipeline.md` for the full CI order.

## Enabled Linter Suites

From `lakefile.toml`:

```toml
weak.linter.mathlibStandardSet = true   # Enable mathlib standard linters
weak.linter.flexible = true             # Enable flexible linting mode
```

The `mathlibStandardSet` enables the standard set of linters inherited from Mathlib
(excluding the disabled ones above). The `flexible` option enables additional
context-sensitive lint checks.
