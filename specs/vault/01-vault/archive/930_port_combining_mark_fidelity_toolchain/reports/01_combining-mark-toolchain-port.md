# Research Report: Task #930

**Task**: 930 - Port combining-mark fidelity toolchain
**Started**: 2026-07-27T00:00:00Z
**Completed**: 2026-07-27T00:00:00Z
**Effort**: small (1-2 phases: file copy + manifest registration + verification)
**Dependencies**: None
**Sources/Inputs**: - Direct `cmp`/`diff` comparison of `/home/benjamin/Projects/BimodalLogic/.claude/scripts/` (downstream deploy tree) against `agent-system/extensions/literature/scripts/` (source of truth); `agent-system/extensions/literature/manifest.json`; `agent-system/extensions/core/scripts/check-extension-docs.sh`
**Artifacts**: - This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The originating census undercounted the divergence by one file. A fresh, content-compared
  (not mtime-compared) re-census confirms **4 new files** and **2 modified files** need
  porting — not 4 new + 1 modified as the captured divergence stated. `literature-fidelity-audit.sh`
  has since landed the anticipated second signal (an additive combining-mark check) and is now
  22,458 B downstream vs. 18,685 B upstream; it must be ported alongside `literature-convert.sh`.
- The port is a pure file copy for all 6 files — no merge conflicts, no upstream-only content
  to reconcile. `literature-convert.sh`'s diff is a clean superset (+113/-1, the removed line
  is a `SCRIPT_DIR` assignment relocated to the top). `literature-fidelity-audit.sh`'s diff is
  likewise additive-only.
- Three other apparent "diffs" in the downstream tree (`literature-audit.sh`,
  `zotero-export-status.sh`, `zotero-search.sh`, `zotero-setup.sh`) are **stale-downstream, not
  new-downstream** — upstream has advanced past the deploy tree's snapshot on unrelated work.
  These must NOT be ported; porting them backward would regress upstream. `literature-retrieve.sh`
  appears "only in DOWN" only because its upstream home is `extensions/core/scripts/`, not
  `extensions/literature/scripts/` — it is a pre-existing, deprecated, unrelated file.
- `agent-system/extensions/literature/manifest.json` currently declares 33 `provides.scripts`
  entries and none of the 4 new files. All 4 (2 `.py` modules + 2 `.sh` tools) must be added as
  flat top-level entries (no path prefix — they live directly in `scripts/`, not a subdirectory).
- The two new `.py` modules are non-executable (644) downstream, while the one existing `.py`
  entry in `provides.scripts` (`literature-decode-font-offset.py`) is 755 upstream. Neither
  module has a shebang or is directly invoked (both are imported via `sys.path.insert`), so 644
  is functionally correct, but matching the existing 755 convention is a low-cost consistency fix
  worth making during the copy.
- A verification plan combining `check-extension-docs.sh`, a consuming-repo deploy, and
  `literature-convert.sh --self-test` is fully specified below (Findings > Verification Plan).

## Context & Scope

The task ports a combining-mark (U+0338 COMBINING LONG SOLIDUS OVERLAY) fidelity toolchain that
was developed directly inside a gitignored deploy tree
(`/home/benjamin/Projects/BimodalLogic/.claude/scripts/`) back to the agent-system source of
truth (`agent-system/extensions/literature/scripts/` + its manifest). The deploy tree is
destroyed on the next extension reload in that repo, so this is a time-sensitive rescue, not a
routine sync.

The originating census (captured in the delegation prompt) was taken while the downstream work
was still in flight and was explicitly flagged as untrustworthy. This report re-derives the
divergence from scratch via `cmp`/`diff`, per the binding instruction to compare content, not
mtime.

Scope is bounded to the combining-mark toolchain and its manifest registration. Other
downstream/upstream divergences discovered incidentally (stale zotero-* scripts, `.claude/scripts/`
entries belonging to other extensions entirely, `zotero-index-add.sh`/`zotero-index-remove.sh`
appearing only downstream) are noted for completeness but are explicitly out of scope — see
Risks & Mitigations.

## Findings

### Authoritative Re-Census (content-compared)

Comparing every `literature*` file in the downstream `scripts/` directory against its
`agent-system/extensions/literature/scripts/` counterpart by content (`cmp -s`, not `stat`
mtime):

**NEW — absent upstream, must be added as new files:**

| File | Size | Role |
|---|---|---|
| `literature_combining_overlay.py` | 4,267 B | Shared overlay-composition logic (`compose_combining_overlays()`); reorders a combining mark separated from its base by up to 2 horizontal-whitespace characters, maps non-canonical ASCII bases (e.g. `\|`) to their true NFC-composable canonical base, then NFC-composes. Imported by `literature-convert.sh` (inline, at conversion time) and by `literature-convert.sh --self-test` (fixture-based, no PDF conversion). No shebang, no `__main__` block — pure importable module. |
| `literature_combining_detect.py` | 16,541 B | Shared PDF-vs-markdown ground-truth detection and anchoring (`scan_directory()`, `PRECOMPOSED`). Imported by both `literature-combining-audit.sh` and `literature-repair-combining.sh`, and — as of the current downstream state — also by `literature-fidelity-audit.sh` (see "escalation" below). No shebang, no `__main__` block. |
| `literature-combining-audit.sh` | 6,585 B | Read-only, corpus-wide silent-drop detector; imports `scan_directory` from `literature_combining_detect`. |
| `literature-repair-combining.sh` | 18,177 B | Backup-guarded, anchored, dry-run-default in-place repair engine; imports `scan_directory` and `PRECOMPOSED` from `literature_combining_detect`. |

**MODIFIED — present upstream but diverged, must be overwritten with the downstream copy:**

| File | Downstream | Upstream | Diff shape |
|---|---|---|---|
| `literature-convert.sh` | 34,500 B | 30,073 B | Clean superset: +113 / -1 lines. The one removed line is a `SCRIPT_DIR="$(cd ...)"` assignment that moved earlier in the file (to support the new `--self-test` early-exit branch, which needs `SCRIPT_DIR` before the rest of the script's setup). Everything else is pure addition: the `--self-test` branch (imports `compose_combining_overlays`, runs ~7 named fixture checks including a whitelist-restricted reorder, a non-interference guard for ordinary accented letters, and a newline-must-not-reorder safety check) plus the live-pipeline call site that invokes `compose_combining_overlays()` during conversion. |
| `literature-fidelity-audit.sh` | 22,458 B | 18,685 B | **Escalation since the originating census** (which recorded this file as byte-identical at 18,685 B on both sides). The downstream copy now imports `scan_directory` from `literature_combining_detect` and adds an additive, clearly-separated "combining-mark signal": a `combining_mark_check()` helper returning a 3-tuple `(checked, dropped, missing)` where `checked=False` is a distinct "not applicable" state from `checked=True, dropped=False` (never coerced to 0/false). Three new output columns (`combining_mark_checked`, `combining_mark_dropped`, `combining_marks_missing`) are appended to the TSV row, an additive stderr summary block is printed, and the diff-suppression / persistence logic is extended to compare and persist the three new fields alongside the existing `prev_fidelity`/`prev_ratio` comparison — so a rerun that only differs in the new fields still surfaces as changed. The diff is additive-only (4 removed lines are all pure relocations/reformattings of existing lines, not semantic removals — confirmed by reading full context, not diff line counts alone). |

**Confirmed unchanged, no porting needed:**

- `tests/generate-test-fixtures.py` and `tests/test-literature-convert.sh` — byte-identical
  (`cmp` confirms, not just matching size) on both sides. No new fixture files were added
  downstream for the new tools.
- `literature-decode-font-offset.py`, `literature-schema.sql`, and all other `literature-*`/`zotero-*`
  files not listed above as MODIFIED or NEW are byte-identical.

### Files That Look Like Divergence But Are NOT In Scope

Two distinct false-positive shapes were found and must be excluded from the port:

1. **Stale-downstream (upstream is ahead, not behind)**: `literature-audit.sh` differs
   (downstream 12,974 B / mtime 2026-07-18, upstream 13,206 B / mtime 2026-07-25). Reading the
   diff shows upstream removed a hardcoded `$HOME/Zotero/storage` fallback in favor of deriving
   the Zotero data directory from the canonical `zotero-resolve-sqlite-path.sh` resolver — an
   unrelated fix that landed upstream after this deploy tree's last full sync. The same pattern
   recurs for `zotero-export-status.sh`, `zotero-search.sh`, and `zotero-setup.sh` (all differ,
   all have older downstream mtimes than their upstream counterparts), and
   `zotero-export-freshness.sh` is missing downstream entirely despite being registered upstream.
   **None of these should be touched by this port** — copying them downstream-to-upstream would
   silently regress an already-landed upstream fix. They will self-correct on the next extension
   reload/sync into that repo.
2. **Wrong-directory false positive**: `literature-retrieve.sh` appears "only in the downstream
   `scripts/` dir" only because the deploy tree flattens every extension's scripts into one
   directory, while its upstream source actually lives in `agent-system/extensions/core/scripts/
   literature-retrieve.sh`, not the literature extension. Its own header marks it DEPRECATED
   ("superseded by literature-briefing.sh"), and its downstream mtime (2026-07-18) predates the
   combining-mark work entirely (which starts 2026-07-27 03:xx per the new files' mtimes). Not
   part of this task's divergence.

Also observed but explicitly out of scope (not investigated further, per task framing which
scopes strictly to the combining-mark toolchain): `zotero-index-add.sh` and
`zotero-index-remove.sh` exist only downstream and are not in `provides.scripts` upstream. If
these represent real unported work, they warrant a separate task/investigation — porting them
here would be scope creep beyond "the combining-mark fidelity toolchain."

### Manifest Registration Plan

`agent-system/extensions/literature/manifest.json` → `provides.scripts` currently has 33
entries, none of the 4 new files. All entries in this array are flat basenames except the two
`tests/` entries, which carry an explicit relative path prefix
(`tests/generate-test-fixtures.py`, `tests/test-literature-convert.sh`) — confirming the
documented convention that subdirectory files need the prefix, and top-level `scripts/` files do
not.

Since all 4 new files live directly in `scripts/` (verified — not in `scripts/tests/` or any
other subdirectory), they need **flat, unprefixed** entries:

```json
"literature_combining_overlay.py",
"literature_combining_detect.py",
"literature-combining-audit.sh",
"literature-repair-combining.sh"
```

Existing entries are not strictly alphabetized (e.g. `literature-fidelity-audit.sh` sits before
`literature-build-index.sh` and `literature-convert.sh`); they are loosely grouped by feature
cluster. The natural insertion point is adjacent to the existing `literature-fidelity-audit.sh`
/ `literature-convert.sh` / `literature-normalize-authors.sh` cluster (manifest lines ~44-51),
since all four new/modified files are functionally part of that same conversion/fidelity
pipeline and share the two new `.py` modules as common dependencies.

`literature-convert.sh` and `literature-fidelity-audit.sh` are already registered (they are
MODIFIED, not NEW) — only their file *content* needs replacing; no manifest change is needed for
those two.

### Permissions Note

Downstream permissions: the two new `.py` modules are 644 (non-executable); the two new `.sh`
tools and the two modified `.sh` files are 755. Upstream's one existing `provides.scripts` `.py`
entry, `literature-decode-font-offset.py`, is 755. Neither new `.py` module has a shebang line
or a `__main__` block — both are pure importables reached only via `sys.path.insert(0, ...)`
from the `.sh` tools, so 644 is functionally sufficient. Recommend `chmod +x` on both `.py`
modules when copying into `agent-system/` purely for consistency with the existing convention,
not because it is functionally required.

### Verification Plan

1. **Content match after copy**: for each of the 6 files, `cmp` the newly-written
   `agent-system/extensions/literature/scripts/<file>` against the downstream deploy-tree
   original to confirm a byte-exact copy (the port is a straight copy, not a re-transcription —
   any diff after copying indicates a mistake).
2. **Manifest completeness**: re-run the same "files present in `scripts/` vs. entries in
   `provides.scripts`" comparison used in this report's Findings section against the *updated*
   manifest — confirm all 4 new files now appear and no entry references a nonexistent file.
3. **Doc-lint (undeclared scripts)**: run `bash agent-system/extensions/core/scripts/
   check-extension-docs.sh` (or the deployed `.claude/scripts/check-extension-docs.sh`
   equivalent) and confirm it exits 0 with the literature extension clean — specifically its
   "flat category orphans" check (a deployed script with no `provides.scripts` source) and its
   "referenced but undeclared" check (a script named in docs/skills/agents but missing from
   `provides.scripts`), both of which are the exact failure modes this port must avoid.
4. **Live deploy into a consuming repo**: trigger (or simulate) an extension reload/sync in a
   repo that has the literature extension loaded, and confirm the 4 new files and 2 modified
   files land in that repo's `.claude/scripts/` with matching content and (for the `.sh` files)
   executable permissions.
5. **Functional self-test**: from the *deployed* copy (not the source tree — to catch any
   deploy-time path/permission issue), run `literature-convert.sh --self-test` and confirm all
   fixture checks reported by the script (mark-immediately-before-base,
   mark-space-before-base, mark-tab-before-base, mark-after-base-canonical-order,
   accented-letter-non-interference, newline-must-not-reorder, plus the corpus-derived base
   additions such as the turnstile/divides case) print `[self-test] PASS` with zero failures.

## Decisions

- Port all 6 files (4 new, 2 modified) as direct byte-for-byte copies from the downstream deploy
  tree into `agent-system/extensions/literature/scripts/` — no merge is needed for any of them.
- Do NOT port `literature-audit.sh`, `zotero-export-status.sh`, `zotero-search.sh`, or
  `zotero-setup.sh` — these are stale-downstream, and copying them would regress already-landed
  upstream work.
- Do NOT treat `literature-retrieve.sh` as in-scope — it belongs to a different extension
  (`core`) and predates this work.
- Register all 4 new files as flat (unprefixed) entries in `manifest.json` →
  `provides.scripts`, inserted adjacent to the existing fidelity/convert cluster.
- Recommend (not require) `chmod +x` on the two new `.py` modules during the copy, matching the
  existing `.py`-in-`provides.scripts` convention.

## Risks & Mitigations

- **Risk**: the deploy tree could be destroyed by an extension reload before the port lands.
  **Mitigation**: this report treats the census as final and actionable; implementation should
  proceed directly from the file list and diffs captured here rather than re-reading the
  downstream tree at implementation time, in case it has already been reloaded away.
- **Risk**: accidentally porting one of the stale-downstream files (`literature-audit.sh` et al.)
  would silently regress upstream fixes. **Mitigation**: explicitly enumerated as out-of-scope
  above with the specific unrelated fix each one would clobber (e.g. the Zotero data-dir resolver
  fix in `literature-audit.sh`).
- **Risk**: forgetting the manifest registration would make the port silently inert — files
  present in `scripts/` but never deployed to any consuming repo. **Mitigation**: Verification
  Plan step 3 (`check-extension-docs.sh`) is specifically designed to catch this class of error.
- **Risk**: `literature-fidelity-audit.sh`'s further evolution (it changed once already since the
  original census) could continue to drift if the deploy tree is touched again before the port
  lands. **Mitigation**: none available from research; flagged for the implementer to re-`cmp`
  immediately before writing, as a final freshness check.

## Context Extension Recommendations

None. This is a one-off rescue-port of in-flight work; no new context file or documented pattern
is warranted. The census methodology used here (content-compare via `cmp`, not mtime) is already
documented as the binding instruction in the task delegation and does not need a separate
context artifact.

## Appendix

Commands used (illustrative, not exhaustive):
```bash
# Byte-identical files, both directories
comm -23/-13 <(find ... -name 'literature*') <(find ... -name 'literature*')

# Content diff for name-matched files
cmp -s "$DOWN/$f" "$UP/$f" || echo "DIFFERS: $f"

# Full unified diffs for MODIFIED files
diff -u "$UP/literature-convert.sh" "$DOWN/literature-convert.sh"
diff -u "$UP/literature-fidelity-audit.sh" "$DOWN/literature-fidelity-audit.sh"
diff -u "$UP/literature-audit.sh" "$DOWN/literature-audit.sh"

# Whole-tree diff, both dirs, to catch anything outside the literature*/zotero* naming pattern
diff -rq "$UP" "$DOWN"

# Manifest provides.scripts enumeration
python3 -c "import json; print(json.load(open('manifest.json'))['provides']['scripts'])"
```

Paths referenced:
- Downstream deploy tree: `/home/benjamin/Projects/BimodalLogic/.claude/scripts/`
- Upstream source of truth: `/home/benjamin/.config/nvim/agent-system/extensions/literature/scripts/`
- Manifest: `/home/benjamin/.config/nvim/agent-system/extensions/literature/manifest.json`
- Doc-lint: `/home/benjamin/.config/nvim/agent-system/extensions/core/scripts/check-extension-docs.sh`
