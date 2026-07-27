# Standard Census Methodology

This is the standard method for producing and trusting any repo-wide count in this agent
system — a count of occurrences, a count of files, a count of anything else derived by scanning
the tree. It exists because repo-wide counts are easy to get wrong in one of three specific,
recurring ways (see "The Three Bug Classes" below), and a wrong count that looks authoritative is
worse than no count at all.

The shipped tool implementing this method is `scripts/census-count.sh`. Its fixture-tested
regression suite is `scripts/tests/test-census-count.sh`. See
`context/standards/shell-script-testing.md` for the shell-test harness convention both follow.

## The Three-Part Rule

1. **Derive once.** A repo-wide count is produced by a single named method. Re-deriving a count
   ad hoc mid-discussion, by a different method, produces a second number, not a confirmation of
   the first. If a number needs re-checking, that is what cross-checking (part 3) is for — done
   deliberately, not accidentally by re-running a slightly different grep later and hoping it
   agrees.
2. **Record the exact command.** The count is published together with the verbatim command
   string that produced it. A count without its command is an assertion, not a measurement — a
   future reader (including a future version of the same agent) cannot verify it, reproduce it,
   or tell whether it is still accurate. `census-count.sh`'s every subcommand emits a fixed,
   greppable record block (`=== census-count <method> record === ... === end record ===`)
   containing at minimum the count, the method name, and the verbatim command string, precisely
   so this requirement is mechanically satisfiable rather than merely aspirational.
3. **Cross-check before publishing or acting.** A second, independent method must produce the
   same number before the count is trusted. Independence means a genuinely different mechanism,
   not the same grep with a different flag. `lean-sorry-census.sh`'s `--cross-check` mode is the
   reference shape for this: a Python comment/string stripper as the primary method, and `lake
   build`'s own `declaration uses 'sorry'` compiler warnings as an independent, comment-immune
   authority. When the two disagree, that disagreement is itself the finding — investigate it,
   do not average the two numbers or pick whichever one you expected.

## The Three Bug Classes

Each bug class below is a specific, previously-observed way a repo-wide count silently comes out
wrong, together with the `census-count.sh` subcommand built to catch it.

### Bug class 1: a keyword inside a comment, directive, or string literal, miscounted as a real occurrence

A naive `grep -c KEYWORD` (or equivalent) counts every textual appearance of a keyword, including
ones inside comments, directive lines, and string literals that are not actual live-code
occurrences. This silently inflates the count.

**Addressed by**: `census-count.sh occurrences`. It reports two numbers side by side —
`naive_count` (raw, unstripped, what a plain `grep` would find) and `real_count` (after stripping
line comments per `--comment-style`, non-nested `/* */` block comments for `slash` style, and
double-quoted string-literal interiors) — so the gap between them is visible rather than silently
absorbed into a single number.

### Bug class 2: a file present in the tree but outside the declared build/target graph

A count of "files matching pattern X" that is silently missing files never declared to a build
system, manifest, or target list (or, conversely, declares files that no longer exist) produces
an undercount or overcount with no visible warning.

**Addressed by**: `census-count.sh membership`. It takes a tree-enumeration command and a
declared-set command (each emitting one path per line), and reports both counts plus the set
difference in both directions: `ONLY_IN_TREE` (present but undeclared) and `ONLY_IN_DECLARED`
(declared but missing). This checks **declared** membership only — it is not a build-graph
parser and does not attempt transitive reachability analysis.

### Bug class 3: separator and suffix variants missed by a naive regex

A regex written assuming only one separator form (typically bare whitespace) silently misses
hyphenated, underscored, or suffixed variants of the same thing. This is the exact bug class
`hooks/validate-no-task-references.sh` shipped with — see its `TASK_SEP` alternation group for
the fixed reference pattern. A bracket class containing `-` compounds the risk: depending on
position, `-` inside `[...]` can be silently read as a range operator instead of a literal
character.

**Addressed by**: `census-count.sh occurrences --pattern <ERE>` accepting any caller-supplied
extended regular expression — the tool does not impose its own separator assumptions; it is the
caller's responsibility to write a separator-aware pattern (following the `([[:space:]]+#?|[-_#])`
alternation shape, never a bracket class containing a bare `-`) and verify it against the full set
of named variant forms before trusting the count it produces.

## Tool Boundaries

State these explicitly so a caller knows what `census-count.sh` does and does not guarantee:

- `occurrences` handles line comments (`#`, `//`, `--`) and simple, non-nested `/* ... */` block
  comments. It does not handle nested block comments (e.g. Lean's `/- outer /- inner -/ still
  outer -/`) — that requires a depth-counting stripper, which `lean-sorry-census.sh` already
  implements for Lean specifically. `--comment-style none` is the escape hatch: pass in content
  that has already been stripped by a language-specific tool, and `occurrences` will not attempt
  its own stripping on top.
- `membership` checks declared membership only, never transitive reachability. It answers "is
  this file in both lists," not "is this file actually reachable from the build."
- `cross-check` takes the LAST integer-looking token in each command's combined stdout as that
  command's count. Commands whose output is not a clean count (or ends with an unrelated trailing
  number) will produce a wrong reading — write cross-check commands that emit a single clear
  number.

## Worked Examples

These use the real `census-count.sh` CLI. Each was run once while writing this doc to confirm it
produces the documented shape of output; re-running them may produce different numbers as the
repository changes, but the shape (record block, field names) is stable.

### `occurrences` — naive vs. real count

```
$ cat > /tmp/example-widget.py <<'EOF'
# WIDGET appears here as a comment
def make_widget():
    WIDGET = 1  # WIDGET appears here too
    return WIDGET
EOF
$ census-count.sh occurrences --pattern '\bWIDGET\b' --path /tmp/example-widget.py --comment-style hash
=== census-count occurrences record ===
method: occurrences
pattern: \bWIDGET\b
path: /tmp/example-widget.py
comment_style: hash
files_scanned: 1
naive_count: 4
real_count: 2
command: census-count.sh occurrences --pattern '\bWIDGET\b' --path '/tmp/example-widget.py' --comment-style hash --file-glob '*'
=== end record ===
```

`naive_count` (4) counts every textual "WIDGET"; `real_count` (2) counts only the two live-code
occurrences (the assignment and the `return` statement), correctly excluding the two comment
occurrences.

### `cross-check` — an agreeing pair (MATCH, exit 0)

```
$ census-count.sh cross-check --a-cmd "wc -l < /tmp/example-widget.py" --a-label wc \
    --b-cmd "grep -c '' /tmp/example-widget.py" --b-label grep_c
=== census-count cross-check record ===
method: cross-check
wc_count: 4
wc_command: wc -l < /tmp/example-widget.py
grep_c_count: 4
grep_c_command: grep -c '' /tmp/example-widget.py
result: MATCH
=== end record ===
```

Exits 0. Two genuinely independent line-counting mechanisms (`wc -l`, `grep -c ''`) agree.

### `cross-check` — a disagreeing pair (MISMATCH, exit non-zero)

```
$ census-count.sh cross-check \
    --a-cmd "grep -oE '\bWIDGET\b' /tmp/example-widget.py | wc -l" --a-label naive_grep \
    --b-cmd "census-count.sh occurrences --pattern '\bWIDGET\b' --path /tmp/example-widget.py --comment-style hash | grep -E '^real_count:' | grep -oE '[0-9]+'" --b-label census_real
=== census-count cross-check record ===
method: cross-check
naive_grep_count: 4
naive_grep_command: grep -oE '\bWIDGET\b' /tmp/example-widget.py | wc -l
census_real_count: 2
census_real_command: census-count.sh occurrences --pattern '\bWIDGET\b' --path /tmp/example-widget.py --comment-style hash | grep -E '^real_count:' | grep -oE '[0-9]+'
result: MISMATCH
=== end record ===
```

Exits non-zero. This is the mechanism working as intended: a naive grep and the tool's
comment-aware real count genuinely disagree (bug class 1), and `cross-check` surfaces that
disagreement instead of letting either number pass unquestioned. A MISMATCH is a signal to
investigate which method is right for the question being asked, not a tool malfunction.

### `membership` — dogfooding example (worked example only, never a test assertion)

Comparing core's own `manifest.json` `provides.scripts` array against the `.sh` files actually
present on disk under `scripts/`:

```
$ census-count.sh membership \
    --tree-cmd "cd agent-system/extensions/core/scripts && find . -type f -name '*.sh' | sed 's|^\./||'" \
    --declared-cmd "jq -r '.provides.scripts[]' agent-system/extensions/core/manifest.json"
=== census-count membership record ===
method: membership
tree_count: 65
tree_command: cd agent-system/extensions/core/scripts && find . -type f -name '*.sh' | sed 's|^\./||'
declared_count: 65
declared_command: jq -r '.provides.scripts[]' agent-system/extensions/core/manifest.json
ONLY_IN_TREE:
ONLY_IN_DECLARED:
note: checks DECLARED membership only, never transitive reachability
=== end record ===
```

At the time this doc was written, both counts were 65 and both difference lists were empty —
every `.sh` file under `scripts/` was registered, and every registered entry existed on disk.
This is a live-repo-state example, included here only to illustrate the invocation shape; it is
**not** a regression-suite assertion (asserting against live repo state would make the suite
fragile and repo-state-dependent — see `context/standards/shell-script-testing.md`). If you run
this yourself and the counts differ or a list is non-empty, that reflects the current state of
the tree, not a broken example.

## Related

- `context/standards/shell-script-testing.md` — the shell-test harness convention
  `census-count.sh`'s own regression suite follows (location rule, helper naming, fixture and
  mutation-check discipline).
- `context/standards/testing.md` — a generic JS/AAA-pattern testing primer, predating this doc
  and covering a different domain (unit-test frameworks, mocks). Complementary, not superseded.
