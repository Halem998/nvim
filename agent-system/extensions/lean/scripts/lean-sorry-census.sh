#!/usr/bin/env bash
# lean-sorry-census.sh -- shared Lean sorry census script
#
# Counts genuine code sorries in Lean 4 source files, correctly excluding
# comment/docstring/string-literal text. A `grep -rn "\bsorry\b" | grep -v ...`
# chain cannot do this correctly: Lean's `/- -/` block comments nest
# (`/- outer /- inner -/ still outer -/` is ONE comment), and nesting depth
# cannot be tracked by a fixed-depth regex/grep pipeline. This script instead
# runs a single-pass, depth-counting comment/string stripper (python3) that
# preserves newlines (so line numbers match the original file) before
# matching `\bsorry\b` on the stripped text.
#
# Handles:
#   - `--` line comments (stripped to end of line)
#   - nested `/- -/` and `/-- -/` block comments (depth-counted)
#   - `"..."` string literals with backslash escaping (interior masked with
#     spaces so a `sorry` appearing only as string *text*, e.g. inside a
#     display/eval string, is not counted as live proof debt -- it is not a
#     `sorry` term/tactic application)
#
# Usage:
#   lean-sorry-census.sh <dir-or-file> [<dir-or-file> ...] [--cross-check]
#
# Examples:
#   bash .claude/scripts/lean-sorry-census.sh Cslib/
#   bash .claude/scripts/lean-sorry-census.sh Theories/ --cross-check
#   bash .claude/scripts/lean-sorry-census.sh Cslib/Foo.lean Cslib/Bar.lean
#
# Output (always):
#   sorry_count: N
#   sorry_inventory:
#   <file>:<line>:<statement>
#   ...
#
# Output (with --cross-check, additionally):
#   Runs `lake build` in the current directory and greps its output for
#   "declaration uses 'sorry'" warnings, an authoritative compiler-backed
#   signal (comment-immune by construction -- comments are discarded during
#   lexing before this warning is ever emitted). Reports both numbers and
#   flags any mismatch. Opt-in because `lake build` is slow; intended for use
#   at wrap-up/final-verification time when a build has already run.
#
# Exit codes: 0 on success (including sorry_count > 0 -- this is a census,
# not a pass/fail gate); 64 on usage error.

set -uo pipefail

CROSS_CHECK=0
TARGETS=()

for arg in "$@"; do
  case "$arg" in
    --cross-check)
      CROSS_CHECK=1
      ;;
    *)
      TARGETS+=("$arg")
      ;;
  esac
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "Usage: lean-sorry-census.sh <dir-or-file> [<dir-or-file> ...] [--cross-check]" >&2
  exit 64
fi

# Collect .lean files from the targets (directories are scanned recursively).
LEAN_FILES=()
for target in "${TARGETS[@]}"; do
  if [[ -d "$target" ]]; then
    while IFS= read -r -d '' f; do
      LEAN_FILES+=("$f")
    done < <(find "$target" -type f -name '*.lean' -print0)
  elif [[ -f "$target" ]]; then
    LEAN_FILES+=("$target")
  else
    echo "Warning: '$target' is not a file or directory, skipping" >&2
  fi
done

if [[ ${#LEAN_FILES[@]} -eq 0 ]]; then
  echo "sorry_count: 0"
  echo "sorry_inventory:"
  exit 0
fi

strip_and_scan() {
  python3 - "$@" <<'PYEOF'
import sys, re

def strip_lean_comments(text: str) -> str:
    """Depth-counting Lean comment/string stripper. Single pass, O(n).
    Preserves newlines so grep-style line numbers on the output match the
    original file. String interiors are masked with spaces (not preserved
    verbatim) so a bare 'sorry' token appearing only as string text is not
    later matched by the \\bsorry\\b scan -- it is not a sorry term/tactic.
    """
    out, i, n, depth, in_str = [], 0, len(text), 0, False
    while i < n:
        c = text[i]
        if depth == 0 and not in_str:
            if text[i:i + 2] == "--":              # line comment
                j = text.find("\n", i)
                i = n if j == -1 else j
                continue
            if text[i:i + 2] == "/-":              # enter block comment (handles /-- too)
                depth, i = 1, i + 2
                continue
            if c == '"':
                in_str = True
                out.append(c)
                i += 1
                continue
            out.append(c)
            i += 1
        elif in_str:
            if c == "\\" and i + 1 < n:             # skip escaped char, masked
                out.append(" ")
                out.append(" ")
                i += 2
                continue
            if c == '"':
                out.append(c)
                in_str = False
                i += 1
                continue
            out.append("\n" if c == "\n" else " ")  # mask string interior
            i += 1
        else:                                       # inside block comment, depth >= 1
            if text[i:i + 2] == "/-":
                depth += 1
                i += 2
                continue
            if text[i:i + 2] == "-/":
                depth -= 1
                i += 2
                continue
            if c == "\n":
                out.append("\n")                     # preserve line numbers
            i += 1
    return "".join(out)


sorry_re = re.compile(r'\bsorry\b')
total = 0
inventory = []
for path in sys.argv[1:]:
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except OSError as e:
        print(f"Warning: could not read {path}: {e}", file=sys.stderr)
        continue
    stripped = strip_lean_comments(text)
    original_lines = text.split("\n")
    stripped_lines = stripped.split("\n")
    for lineno, line in enumerate(stripped_lines, start=1):
        if sorry_re.search(line):
            total += 1
            statement = original_lines[lineno - 1].strip() if lineno - 1 < len(original_lines) else ""
            inventory.append((path, lineno, statement))

print(f"sorry_count: {total}")
print("sorry_inventory:")
for path, lineno, statement in inventory:
    print(f"{path}:{lineno}:{statement}")
PYEOF
}

CENSUS_OUTPUT="$(strip_and_scan "${LEAN_FILES[@]}")"
echo "$CENSUS_OUTPUT"

STRIPPER_COUNT="$(echo "$CENSUS_OUTPUT" | grep -oE '^sorry_count: [0-9]+' | grep -oE '[0-9]+')"

if [[ $CROSS_CHECK -eq 1 ]]; then
  echo ""
  echo "--- Cross-check: lake build ---"
  if ! command -v lake >/dev/null 2>&1; then
    echo "cross_check: unavailable (lake not found in PATH)"
  else
    BUILD_OUTPUT="$(lake build 2>&1)"
    BUILD_STATUS=$?
    COMPILER_COUNT="$(echo "$BUILD_OUTPUT" | grep -c "declaration uses 'sorry'")"
    echo "compiler_sorry_count: $COMPILER_COUNT"
    echo "stripper_sorry_count: $STRIPPER_COUNT"
    if [[ "$COMPILER_COUNT" == "$STRIPPER_COUNT" ]]; then
      echo "cross_check: MATCH"
    else
      echo "cross_check: MISMATCH (stripper=$STRIPPER_COUNT, compiler=$COMPILER_COUNT)"
    fi
    if [[ $BUILD_STATUS -ne 0 ]]; then
      echo "Warning: lake build exited non-zero ($BUILD_STATUS); compiler_sorry_count may be incomplete" >&2
    fi
  fi
fi
