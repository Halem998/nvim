# Locked-Region Manifest — Orchestrate Skill Dedup

Phase 1 evidence artifact. Established BEFORE any byte is moved (Phases 2-6). Anchors are
recorded as literal text, never line numbers — line numbers drift on every edit in this plan.

## Scope confirmation

`grep -l 'skill-orchestrate' agent-system/extensions/core/scripts/tests/*.sh` plus a check for
`eval`/`bash -n`/`grep -oP` per hit confirms **six** test files read literal SKILL.md text, two of
which `eval` an extracted region. This matches the plan's Research Integration table exactly; no
scope widening beyond it was found.

## The six tests

### 1. `test-handoff-reader-parity.sh`
- Mechanism: `grep -oP` regex-extracts `VAR=$(echo "$handoff" | jq -[rc] '...')` literals for
  ~13 fields (`handoff_dispatch_seq`, `handoff_artifact_{path,type,summary}`, `skeleton`,
  `sorry_inventory`, `blocker_target`, `verbatim_goal`, etc.) directly out of both SKILL.md files.
  Also awk-extracts the `dispatch-seq-gate:begin`/`:end` sentinel region
  (`awk '/dispatch-seq-gate:begin/{flag=1} flag{print} /dispatch-seq-gate:end/{if(flag){exit}}'`)
  and compares base vs. hard for byte identity.
- Comparison only — no `eval`.
- Consequence: the literal `VAR=$(echo "$handoff" | jq ... '...')` one-liners must stay literal,
  named `$handoff`, in both files. The `dispatch-seq-gate:begin`…`:end` region must stay
  byte-identical (after normalization) between engines.
- Resolved anchors (both files): `# --- dispatch-seq-gate:begin ---` … `# --- dispatch-seq-gate:end ---`.
  Base: lines 717–750. Hard: lines 1189–1223 (line numbers as of Phase 1; anchors are the
  authoritative locator, not these numbers).

### 2. `test-handoff-dispatch-identity.sh`
- Mechanism: awk-extracts from `# ── Staleness gate ─` (STALENESS_ANCHOR, a prefix match) through
  `dispatch-seq-gate:end` (END_MARKER) in **both** files (`extract_combined_region`). Prepends a
  local `append_detected_defect_def` **stub** (faithful signature: class, attributed_path, site,
  detail, record_result). Runs `bash -n` on `stub + region`. Then, in `run_region()`, `eval`s
  `$append_detected_defect_def` followed by `eval "$region"` inside `( cd "$WORKDIR" || exit 1; ... )`
  — cwd is a mktemp workdir, NEVER the repo root.
- Consequence: **the whole `Staleness gate` → `dispatch-seq-gate:end` region must remain
  self-contained inline bash.** A `bash .claude/scripts/foo.sh` call inside it would not resolve
  (relative path, wrong cwd). Any call to `append_detected_defect` inside this region MUST keep
  that literal identifier — the test's stub only intercepts that exact name.
- Resolved anchors: `# ── Staleness gate ────` (prefix `# ── Staleness gate ─`) through
  `# --- dispatch-seq-gate:end ---`. Base: lines 671–750 (80 lines). Hard: lines 1143–1223 (81
  lines).
- Identifier locked by stub: `append_detected_defect` (exact name, both files, at every call site
  inside this region — base has 2 call sites in-region at lines 709 and 741; hard has 2 at 1181
  and 1214).

### 3. `test-loop-guard-budget-override.sh`
- Mechanism: awk-extracts from `budget-continuation-override:begin` (BEGIN_MARKER) through a
  per-engine **resume-anchor substring match** (`index($0, r) > 0`, not regex) —
  `'Resuming — cycle $cycle_count of $MAX_CYCLES (infra failures'` for base,
  `'Resuming — cycle $cycle_count of $MAX_CYCLES (burnout signals so far'` for hard — appending a
  synthetic `fi` after the matched line and exiting. Runs `bash -n`, then `eval "$region"` inside
  a `cd "$WORKDIR"` subshell. Also greps the Stage 7 MAX_CYCLES message text for
  `--continue-budget` in both files (structural, not eval'd).
- Consequence: the **Stage 2 budget-override + immediately-following resume-read echo line**
  region must remain self-contained inline bash in both files. Nothing between
  `budget-continuation-override:begin` and the `Resuming — cycle …` echo line (inclusive) may be
  replaced by a script call. Text strictly BEFORE `:begin` and strictly AFTER the echo line is NOT
  covered by this extraction and is available for Phase 6 to move.
- Resolved anchors: `# --- budget-continuation-override:begin ---` through the line containing
  `echo "[orchestrate] Resuming — cycle $cycle_count of $MAX_CYCLES (infra failures: ...)"` (base,
  lines 116–175) / `echo "[hard-orchestrate] Resuming — cycle $cycle_count of $MAX_CYCLES (burnout
  signals so far: ...)"` (hard, lines 321–371).
- Stage 7 MAX_CYCLES message: both files' Stage 7 section names `--continue-budget` literally;
  left untouched by every phase (no phase modifies Stage 7).

### 4. `test-routing-resolution.sh`
- Mechanism: greps each SKILL.md for count of `command-route-agent.sh` invocations, asserts
  `>= 3` per file (Assert 3), and asserts no case-table/sed-derivation pattern remains.
- Baseline count (Phase 1 measurement): **base = 3** (Stage 1b, `research`/`plan`/`implement`
  lines), **hard = 3** (Stage 1b, same three call sites). Both already at the floor — no phase in
  this plan touches Stage 1b, so the count must not change.

### 5. `test-loop-guard-staleness.sh`
- Mechanism: sentinel-pair (`loop-guard-staleness:begin`/`:end`) extraction from the **hard file
  only** (`SKILL_FILE` is hard-only), `bash -n`, `eval` inside `cd "$WORKDIR"`.
- Resolved anchors: `# --- loop-guard-staleness:begin ---` … `# --- loop-guard-staleness:end ---`,
  hard file only, lines 251–319. Intentionally hard-only asymmetry (Non-Goal); out of scope for
  every phase in this plan — never touched.

### 6. `test-resume-scan-nonconformance.sh`
- Mechanism: sentinel-pair (`resume-scan-conformance-gate:begin`/`:end`) extraction from three
  sites, one of which (`SITE_A_FILE`) is `skill-orchestrate-hard/SKILL.md`. `bash -n`, `eval`.
- Resolved anchor in scope for this task: `# --- resume-scan-conformance-gate:begin ---` …
  `# --- resume-scan-conformance-gate:end ---`, hard file, lines 738–760 (Stage 5 H1-location
  `marker-handoff-crosscheck`). Left untouched — Non-Goal (intentionally non-parallel with the
  base file's Stage-5-location equivalent).

## Locked identifiers (must not be renamed at any call site inside a locked region)

| Identifier | Locked by | Treatment |
|---|---|---|
| `append_detected_defect` | test-handoff-dispatch-identity.sh (stub) | Named-shim: <=3-line local def in each engine delegating to `skill_orchestrate_append_detected_defect` (Phase 2). Call sites inside the Staleness-gate→dispatch-seq-gate:end region keep the bare name unchanged. |
| `mint_dispatch_seq` | test-loop-guard-budget-override.sh (region contains no call, but the function definition sits adjacent to Stage 2 prologue and is referenced by Stage 5 comments); also referenced by name in prose | Named-shim: <=3-line local def in each engine delegating to `skill_orchestrate_mint_dispatch_seq` (Phase 2). Definition itself sits OUTSIDE both the budget-override region and the staleness/dispatch-seq region in both files (confirmed: base def at 224–231, region ends at 175 in base and 750 in the earlier one — not overlapping; hard def at 423–430, staleness region ends 319, budget region ends 371 — not overlapping). Safe to shim. |
| `$handoff` (variable name in `VAR=$(echo "$handoff" | jq ...)`) | test-handoff-reader-parity.sh (regex requires literal `$handoff`) | Left untouched; the ~13 one-line jq reads stay inline verbatim in both files (explicit Non-Goal). |
| `handoff_artifact_{path,type,summary}` | test-handoff-reader-parity.sh + test-reconcile-handoff-status.sh grep | Preserved as literal `VAR=$(echo "$handoff" | jq -r ...)` reads (Phase 4 task explicitly keeps these three). |
| `skeleton`, `sorry_inventory`, `blocker_target`, `verbatim_goal` | test-handoff-reader-parity.sh (hard-only filters) | Hard-only reads; untouched (Non-Goal — intentional asymmetry). |

## `command-route-agent.sh` invocation count (floor = 3 per file)

- `skill-orchestrate/SKILL.md`: 3 (Stage 1b: research, plan, implement)
- `skill-orchestrate-hard/SKILL.md`: 3 (Stage 1b: research, plan, implement)

## Baseline byte accounting (Phase 1, before any edit)

| File | Bytes |
|---|---|
| `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` | 196,171 |
| `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` | 127,145 |
| `agent-system/extensions/core/scripts/skill-base.sh` | 51,859 |
| `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` | 33,855 |
| `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` | 32,072 |
| `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` | 27,325 |
| `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` | 13,667 |
| `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` | 17,814 |

**Accounting-denominator files** (read-only reference for Phase 7's eager-prefix + command +
skill + agent total; never written by this task):
| File | Bytes |
|---|---|
| `.claude/CLAUDE.md` (deployed, generated) | 33,215 |
| `.claude/commands/orchestrate.md` (deployed) | 43,180 |
| Eager `.claude/rules/*.md` set (state-management, git-workflow, error-handling, artifact-formats, workflows, plan-format-enforcement, no-task-references-in-deliverables, source-store-deploy-boundary, pr-prohibition — the 8 explicitly `@`-imported by CLAUDE.md's Rules References section plus pr-prohibition.md, which is natively path-glob-loaded for every path via `paths: "**/*"`) | 30,707 (sum) |

Both orchestrate skills are direct-execution (no agent dispatch of their own) — the "agent" term
in the eager-prefix + command + skill + agent total is 0 for both, stated explicitly per the
plan's Phase 7 task rather than omitted.

## Baseline test suite (`run-all.sh`)

```
42 passed, 0 failed, 0 skipped, 42 total
```

No pre-existing failures. Any regression detected in a later phase is attributable to that
phase's edit, not pre-existing breakage.
