# Research Report: Task #856

**Task**: 856 - Retroactive cleanup of pre-existing task-number citations in wrapper-contracts.md
**Started**: 2026-07-13T00:00:00Z
**Completed**: 2026-07-13T00:00:00Z
**Effort**: 1-2 hours (research phase)
**Dependencies**: None
**Sources/Inputs**:
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` (target file, 387 lines)
- `.claude/extensions/email/context/project/email/domain/staleness-detection.md` (sibling)
- `.claude/extensions/email/context/project/email/domain/archive-mode-risk.md` (sibling)
- `.claude/rules/no-task-references-in-deliverables.md` (policy)
- `.claude/hooks/validate-no-task-references.sh` (detection regex)
- `~/.dotfiles/specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md` (the frozen
  handoff this file summarizes — cross-repo, read for anchor names only)
- `~/.dotfiles/specs/080_verify_logos_wrapper_contract_close_phase6/` (source of the named
  verification function)
- `specs/854_diagnose_and_repair_xapian_directorybookkeeping_ghost_blocking_22_logos_inbox_files/summaries/01_diagnose-repair-xapian-ghost-summary.md`
  (confirmed exists; referenced by one citation)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The hook regex `\btasks?[:,]?[[:space:]]+[0-9]` (case-insensitive) matches **23 lines** in
  `wrapper-contracts.md`. A 24th real citation exists but is **invisible to the single-line
  regex** because the phrase wraps across a line break (`... task\n80 ...` at lines 263–264).
  The implementer must fix this one too even though the hook won't flag it.
- Every citation falls into one of four patterns, each with a concrete non-task durable anchor
  already discoverable either inline in the same sentence, in a sibling `domain/` doc, or in the
  cross-repo `.dotfiles` handoff/task-080 project:
  1. **`Task 72` (frozen contract provenance, lines 1 & 4)** → the `.dotfiles` handoff document
     `wrapper-contract.md` (confirmed at
     `~/.dotfiles/specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md`),
     whose own §1–§9 map 1:1 onto this file's §1–§9. Cite the document, not the task number.
  2. **`task 80` / `.dotfiles task 80` (2 occurrences, lines 33 and 263–264)** → the task
     description's own worked example applies verbatim: drop "task 80", keep the named
     verification function `verify_logos_wrapper_contract_close_phase6` (confirmed as the real
     `.dotfiles` task-080 project name at
     `~/.dotfiles/specs/080_verify_logos_wrapper_contract_close_phase6/`).
  3. **`task 805, Phase 1` (ground-truth verification provenance, 3 occurrences: lines 10, 58,
     168)** → the file already states the real durable anchor right next to every occurrence:
     verification against `agent-tools.nix` (and, at line 170, `classify.nix`). Drop the task
     reference, keep/tighten the file-name anchor.
  4. **`task 820` (4 occurrences: lines 18, 128, 215, 241)** → `--emit-tagged`'s own in-file
     section numbers (§10, §10a) and the `.dotfiles` addendum section (`.dotfiles` handoff §12,
     confirmed to literally be titled "Task-820 ADDENDUM" in the cross-repo doc) are the durable
     anchors already present in the same sentences. Drop the task number, keep the section refs.
  5. **`tasks 823-824`, `tasks 823, 827`, `task 827` ×3 (§13 freshness/reindex provenance, 6
     occurrences: lines 285, 303, 309, 318, 332)** → `staleness-detection.md` is the durable
     sibling doc that already fully documents this mechanism; `mbsync.nix` is the config source
     for `email-reindex`. Drop task numbers, cite the sibling doc / config file already named
     in-sentence.
  6. **`task 852` / `task 854` (§13 hook-race hazard + follow-up, 7 occurrences: lines 337–338,
     346, 350, 359, 372, 381, 383)** → this narrative is entirely self-contained prose describing
     a specific historical incident and its correction; every task number here can be deleted
     cleanly (replaced with "that run" / "this section" / "the diff above" self-references) since
     the concrete technical facts (script name `logos-reclone.sh`, xapian-check findings, the
     `search.exclude_tags` mechanism) are already stated inline. One occurrence (line 383) also
     embeds a raw `specs/854_.../` path — that must be dropped too, not just reworded, since a
     path into another task's specs/ directory from OUTSIDE specs/ is the same kind of ephemeral
     leak the rule prohibits.
- No section headings, numbering, or technical content need to change beyond the task-citation
  text itself. Recommended edits preserve every `##`/`###` heading number (`## 13.` stays
  `## 13.`, etc.) per the task's constraint.
- **Pre-existing, out-of-scope oddity noted for awareness only**: the file has no `## 12.`
  section — numbering jumps from `### 11a.` directly to `## 13.`. Several sibling files
  (`skill-email-cleanup/SKILL.md` lines 306, 351, 363) cite "wrapper-contracts.md §12", which
  does not exist in this file. This is unrelated to task-number citations and is explicitly out
  of scope per the task's "preserve all technical content and section numbering" constraint — do
  not renumber sections as part of this cleanup. Flagged here only so the implementer doesn't
  mistake it for something this task caused.

## Context & Scope

Task 856 requires a line-by-line inventory of every task-number citation in
`.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` (the sole copy; no
deployed duplicate exists), each mapped to either (a) a durable replacement anchor, or (b) a
"delete — adds nothing" verdict. This report is the deliverable; a separate implementation phase
will apply the edits.

The hook regex used for detection (from `.claude/hooks/validate-no-task-references.sh`):

```
grep -Eqi '\btasks?[:,]?[[:space:]]+[0-9]' "$FILE"
```

This is a **single-line** regex (grep operates line-by-line by default), which is why the
line-wrapped `task\n80` citation at lines 263–264 is invisible to the hook despite being a real
citation. The task's own creation-time grep count (23) reflects this single-line limitation; the
true count of citations requiring judgment is **24**.

## Findings

### Full Citation Inventory

Each entry: line number(s), exact quoted text (as it appears today), and the specific durable
anchor to substitute. Line numbers are current as of this research pass (2026-07-13); re-verify
line numbers before editing if the file has changed since.

---

**1. Line 1 (H1 heading)**
> `# Wrapper Contracts (Frozen, Task 72 §1-§9)`

Replace with a document-name anchor instead of the task number. Confirmed: the `.dotfiles`
handoff at `~/.dotfiles/specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md`
has its own `## 1.` through `## 9.` sections that map 1:1 to this file's §1–§9 (both are titled
"The five/Five binaries", "Global flag contract", etc.). Recommended:
```
# Wrapper Contracts (Frozen — summarizes `.dotfiles` handoff `wrapper-contract.md` §1-§9)
```
(Section-number range `§1-§9` is retained because it is real, useful, doc-to-doc cross-reference
information — durable as long as it's attached to the document name, not a task number.)

---

**2. Line 4**
> `contract itself lives in the `.dotfiles` repo (Task 72 handoff, FROZEN); this file records the`

Same anchor as #1. Recommended:
```
contract itself lives in the `.dotfiles` repo (`wrapper-contract.md` handoff, FROZEN); this file
records the
```

---

**3. Line 10**
> `(task 805, Phase 1). The wrapper is frozen: nothing in this extension may modify it, add flags`

This is the tail of the "Ground-truth verification" sentence (lines 8–11) that already states the
real anchor: verification was against `agent-tools.nix` on 2026-07-03. The task/phase adds no
information beyond what the sentence already contains. Recommended: delete the parenthetical
cleanly.
```
verbatim against `~/.dotfiles/modules/home/email/agent-tools.nix` (718 lines) on 2026-07-03.
The wrapper is frozen: nothing in this extension may modify it, add flags
```

---

**4. Line 18 (table cell, § 1 binaries table)**
> `` | `email-classify` | apply provisional `+proposed-*` notmuch tags; emit candidate manifest; `--append-approved`; `--emit-tagged` (read-only tag-derived re-emit, task 820 — see §10) | ... ``

Drop "task 820", keep the durable in-doc section pointer already present:
```
`--emit-tagged` (read-only tag-derived re-emit — see §10)
```

---

**5. Line 33**
> `Gmail (verified `.dotfiles` task 80, `verify_logos_wrapper_contract_close_phase6`: all 9`

This is the task description's own worked example. Drop "task 80", keep the named function —
confirmed as the real `.dotfiles` task-080 project name
(`~/.dotfiles/specs/080_verify_logos_wrapper_contract_close_phase6/`):
```
Gmail (verified via `verify_logos_wrapper_contract_close_phase6`: all 9
```

---

**6. Line 58**
> `Verified details (task 805 Phase 1):`

Same "task 805, Phase 1" pattern as #3 — the section that follows (lines 60–67) is entirely
line-numbered against `agent-tools.nix`. Recommended:
```
Verified details (line-referenced against `agent-tools.nix`):
```

---

**7. Line 128**
> `` 4. `email-classify --emit-tagged` (task 820, §10) is **not** an approval or classification act — ``

Drop "task 820,", keep "§10" (the in-doc forward reference is intentional — §10 introduces
`--emit-tagged` before §10a details it; do not change to §10a, that would be an unrelated
technical-content edit outside this task's scope):
```
4. `email-classify --emit-tagged` (§10) is **not** an approval or classification act —
```

---

**8. Line 168 (H2 heading, §10)**
> `## 10. email-classify Pagination Contract (verified, task 805 Phase 1)`

Same "task 805, Phase 1" verification-provenance pattern. Recommended:
```
## 10. email-classify Pagination Contract (verified against `agent-tools.nix`)
```

---

**9. Line 170**
> `` **Correction (task 820, verified against `classify.nix`): `email-classify`'s default mode is ``

This is the task description's other worked example ("cite the config source... rather than the
task"). The config-source anchor is already present in the same parenthetical — just drop the
task number:
```
**Correction (verified against `classify.nix`):** `email-classify`'s default mode is
```

---

**10. Line 215 (H3 heading, §10a)**
> `` ### 10a. `--emit-tagged`: read-only tag-derived re-emit (task 820, `.dotfiles` addendum §12) ``

The `.dotfiles` addendum section number is already present and durable — confirmed: the
`.dotfiles` handoff `wrapper-contract.md` §12 is literally titled `"Task-820 ADDENDUM:
email-classify --emit-tagged (read-only re-emit) (2026-07-05)"`. Just drop "task 820,":
```
### 10a. `--emit-tagged`: read-only tag-derived re-emit (`.dotfiles` addendum §12)
```

---

**11. Line 241**
> `` - **Consumer**: `skill-email-cleanup`'s `--all` mode (task 820) uses `--emit-tagged` for its ``

Adds nothing beyond the feature name already stated and the `SKILL.md` cross-reference later in
the same bullet. Delete cleanly:
```
- **Consumer**: `skill-email-cleanup`'s `--all` mode uses `--emit-tagged` for its
```

---

**12. Lines 263–264 (NOT caught by the single-line hook regex — wraps across a line break)**
> Line 263: `` `gmail`-account case specifically. Verified per-account folder-token summary (`.dotfiles` task ``
> Line 264: `` 80, `verify_logos_wrapper_contract_close_phase6`, all 9 contract rows PASS, zero divergence): ``

Identical pattern to #5 (same underlying fact, cited a second time near §11a). Drop "task 80",
keep the function name:
```
`gmail`-account case specifically. Verified per-account folder-token summary via
`verify_logos_wrapper_contract_close_phase6` (all 9 contract rows PASS, zero divergence):
```
**Implementer note**: because this citation spans a line break, re-running the hook's single-line
regex after editing will NOT confirm this one was fixed — verify it by manual `grep -n
'\bTask\b'`/reading, not just by re-running `validate-no-task-references.sh`'s exact pattern.

---

**13. Line 285 (H2 heading, §13)**
> `## 13. Index Freshness, Reindex, and the Absence of an Auto-Indexer (tasks 823-824)`

This is the literal example already used in `.claude/rules/no-task-references-in-deliverables.md`
as the "Before" anti-pattern (that rule doc's own worked "After" example drops the parenthetical
entirely). Delete cleanly, matching the rule's own worked example exactly:
```
## 13. Index Freshness, Reindex, and the Absence of an Auto-Indexer
```

---

**14. Line 303**
> `` **Freshness disclosure (tasks 823, 827).** `email-census` emits an ``

`staleness-detection.md` is the sibling doc that fully documents the freshness-line mechanism
(see its "Detection: the census freshness line" section) — a stronger, durable cross-reference
than the task numbers. Recommended:
```
**Freshness disclosure** (full mechanism in `staleness-detection.md`). `email-census` emits an
```

---

**15. Line 309**
> `` folder:<ACCOUNT_FOLDER>` used before task 827 (see staleness-detection.md for why the deduped ``

The sibling-doc cross-reference is already present in the same sentence; only "before task 827"
needs to lose the task number. Recommended (keep temporal framing without the task number):
```
folder:<ACCOUNT_FOLDER>` used previously (see staleness-detection.md for why the deduped
```

---

**16. Line 318**
> `` **Sanctioned reindex: `email-reindex` (tasks 824, 827).** A sixth operator helper (`mbsync.nix`, ``

The config source `mbsync.nix` is already named immediately after — drop the task parenthetical:
```
**Sanctioned reindex: `email-reindex`.** A sixth operator helper (`mbsync.nix`,
```

---

**17. Line 332**
> `` - `email-reindex` also writes the reindex-ran marker (task 827): after `notmuch new --no-hooks` ``

The marker mechanism is self-describing in the rest of the sentence (the exact file path is
given). Delete cleanly:
```
- `email-reindex` also writes the reindex-ran marker: after `notmuch new --no-hooks`
```

---

**18. Lines 337–338**
> Line 337: `` **Known hazard: raw `notmuch new` self-triggered hook race can permanently strand files ``
> Line 338: `` (task 852).** A raw (non-`--no-hooks`) `notmuch new` invocation fires its own `preNew` hook ``

Delete cleanly — the paragraph fully describes the hazard mechanism without needing the task
number:
```
**Known hazard: raw `notmuch new` self-triggered hook race can permanently strand files.** A raw
(non-`--no-hooks`) `notmuch new` invocation fires its own `preNew` hook
```

---

**19. Line 346**
> `` files traced to `logos-reclone.sh` invoking a raw `notmuch new` at its reindex step (task 852 ``
> (continues line 347: `research report). The first-line remediation is...`)

The concrete durable anchor (`logos-reclone.sh`, the script where the bug was found) is already
named in the same clause. Delete the task/report parenthetical cleanly:
```
files traced to `logos-reclone.sh` invoking a raw `notmuch new` at its reindex step. The
first-line remediation is
```

---

**20. Line 350**
> `` in the task 852 live run, `--full-scan` successfully cleared 5 unrelated ordinary-staleness files ``

Delete the task number, using a self-referencing phrase for continuity with the prior sentence's
described incident:
```
in that live run, `--full-scan` successfully cleared 5 unrelated ordinary-staleness files
```

---

**21. Line 359**
> `` **Follow-up finding (task 854): the "22 permanently-unindexed files" were a false positive — ``

Delete cleanly — "Follow-up finding" plus the quoted label already carries the needed framing:
```
**Follow-up finding: the "22 permanently-unindexed files" were a false positive —
```

---

**22. Line 372**
> `` of the 22 individually returning the expected file path. Task 852's on-disk-vs-indexed diff ``

This is a self-reference to the diff methodology described earlier in the SAME section (the
"Known hazard" paragraph above, lines 337–357). Replace with a self-referential phrase rather than
a task number:
```
of the 22 individually returning the expected file path. The earlier on-disk-vs-indexed diff
```

---

**23. Line 381**
> `` (which is not tag-filtered) as the indexed-side ground truth. Task 852's "22 permanently-unindexed ``

Same self-reference pattern as #22 — this section already established the "22
permanently-unindexed files" label as its running term; no task number needed to point back to
it:
```
(which is not tag-filtered) as the indexed-side ground truth. The earlier "22
permanently-unindexed
```
(sentence continues unchanged: `files" conclusion is corrected by this finding: those files were
never unindexed.`)

---

**24. Line 383 (also embeds a `specs/` path leak, not just a task-number phrase)**
> `` needed or attempted in task 854; no mail file was mutated and no message-document surgery was ``
> (continues line 384: `` performed (see `specs/854_.../summaries/01_diagnose-repair-xapian-ghost-summary.md` for full ``)
> (continues line 385: `evidence). Whether these 22 messages *should* carry ...`)

Two problems in one spot: "task 854" AND a raw pointer into another task's `specs/` directory
from a file OUTSIDE `specs/` — confirmed to resolve to a real file at
`specs/854_diagnose_and_repair_xapian_directorybookkeeping_ghost_blocking_22_logos_inbox_files/summaries/01_diagnose-repair-xapian-ghost-summary.md`,
which is exactly the kind of ephemeral cross-reference the rule prohibits (that task directory
would be renumbered on a future vault operation, silently breaking the link). The full technical
finding (Xapian glass-backend health, `search.exclude_tags` mechanism, confirmed counts) is
already stated inline in the preceding sentences of this same paragraph (lines 366–376), so the
"for full evidence" pointer is convenience, not load-bearing. Delete both the task number and the
`specs/` path cleanly:
```
needed or attempted; no mail file was mutated and no message-document surgery was performed.
Whether these 22 messages *should* carry
```

---

### Verified Durable Anchors Used Above

| Anchor | What it is | Verified how |
|---|---|---|
| `` `~/.dotfiles/modules/home/email/agent-tools.nix` `` | The frozen wrapper source, 718 lines | Already named in the file's own "Ground-truth verification" intro (lines 8-11) |
| `` `~/.dotfiles/modules/home/email/mbsync.nix` `` | Source of `email-reindex`, `email-freeze`/`email-thaw`, mbsync groups | Already named in §13 and §11a of this file |
| `` `classify.nix` `` | Source of `email-classify` default-mode behavior | Already named at line 170 of this file |
| `` `logos-reclone.sh` `` | Script that triggered the raw `notmuch new` hook race | Already named at line 346 of this file |
| `verify_logos_wrapper_contract_close_phase6` | Named verification project/function for the `--account` enum contract check | Confirmed as the real `.dotfiles` task-080 project name at `~/.dotfiles/specs/080_verify_logos_wrapper_contract_close_phase6/`; also appears as a function name in that project's summary |
| `` `.dotfiles` handoff `wrapper-contract.md` `` | The frozen wrapper contract document this file summarizes | Confirmed to exist at `~/.dotfiles/specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md`, with §1-§9 matching this file's §1-§9, and its own §12 literally titled "Task-820 ADDENDUM: email-classify --emit-tagged" |
| `staleness-detection.md` | Sibling doc fully documenting the freshness-line algorithm | Read in full; confirmed it already cross-references `wrapper-contracts.md §13` in both directions |
| §10 / §10a (in-file section numbers) | This file's own sections on `--emit-tagged` | Read in full; confirmed §10 introduces `--emit-tagged` forward-referencing §10a, and §10a is the detailed treatment |
| Self-reference ("the earlier...", "that live run", "the diff above") | For the task-852/854 narrative, which is a single self-contained incident report within §13 | The whole narrative (lines 337-386) already reads as one continuous story; task numbers there were citing sibling sentences in the SAME section, not external docs |

### Sibling Docs Checked (no index-architecture.md exists)

The task description's illustrative examples mentioned "staleness-detection.md, index-architecture.md,
etc." as sibling docs to cite. Only two sibling files actually exist in
`.claude/extensions/email/context/project/email/domain/`:
- `staleness-detection.md` — used above (findings #14, #15, #16 area context)
- `archive-mode-risk.md` — read in full; contains no task-number citations itself and does not
  need to be an edit target, but confirms the correct cross-reference style already in use
  elsewhere in this extension (`wrapper-contracts.md §N` without task numbers) — i.e. it is a
  positive example of the target end-state for wrapper-contracts.md's own internal style.

No `index-architecture.md` exists in this directory; the task description's mention of it was
illustrative only.

## Decisions

- Every citation gets a durable replacement or clean deletion; none require inventing new
  cross-reference material not already present in the file or its siblings/upstream sources.
- The two `.dotfiles`-repo anchors used (`wrapper-contract.md` handoff document name, and
  `verify_logos_wrapper_contract_close_phase6` function/project name) are referenced by NAME
  only, never by their own task numbers (72, 80) — consistent with the rule's intent even though
  those numbers live in a different repo's specs/ tree.
- The line-354/355 area ("per this section's existing `email-reindex` contract") already uses the
  self-referencing style this report recommends elsewhere — confirms it's an established pattern
  in this file, not a novel proposal.
- Recommend the implementer re-verify all line numbers against the file's current state before
  editing (this report's line numbers are accurate as of the research pass, 2026-07-13), and use
  `grep -niE '\btasks?[:,]?[[:space:]]+[0-9]' wrapper-contracts.md` PLUS a manual scan for
  line-wrapped occurrences (like #12) as the post-edit verification step, since the hook's
  single-line regex cannot catch wraps.

## Risks & Mitigations

- **Risk**: mechanically deleting "(task N)" parentheticals could leave awkward doubled
  punctuation or dangling parens (e.g. two entries in a row inside one sentence). **Mitigation**:
  each recommended replacement above is written as full replacement text, not a diff instruction,
  specifically to avoid this — implementer should copy the "Recommended" block verbatim rather
  than deleting substrings in place.
- **Risk**: the hook's single-line regex will report a false "PASS" after editing even if the
  line-wrapped citation (#12) or a newly-introduced wrap is missed. **Mitigation**: called out
  explicitly above; verification step must include a manual read-through of §11/§11a and §13, not
  just a hook re-run.
- **Risk**: over-eager section renumbering to "fix" the missing `## 12.` gap noted in the Executive
  Summary. **Mitigation**: explicitly flagged as out of scope; the task's own constraint says
  preserve section numbering.

## Context Extension Recommendations

None — this is a one-off retroactive cleanup of a single file; no new context file or pattern
documentation is warranted. The rule (`no-task-references-in-deliverables.md`) and its hook
already fully document the policy going forward.

## Appendix

### Search queries / commands used

```bash
grep -niE '\btasks?[:,]?[[:space:]]+[0-9]' wrapper-contracts.md   # 23 single-line hits
grep -niE '#[0-9]{2,4}\b|\bphase[[:space:]]*[0-9]\b' wrapper-contracts.md  # confirm no missed #NNN style refs
grep -rn "verify_logos_wrapper_contract_close_phase6" ~/.dotfiles/  # confirm durable function/project name
grep -n "^#" ~/.dotfiles/specs/072_.../handoffs/wrapper-contract.md  # confirm §1-§9 and §12 mapping
find specs/854_.../ -iname "*summary*"  # confirm the specs/ path cited at line 383-384 is real
```

### Full 23-line mechanical grep output (for cross-check)

```
1, 4, 10, 18, 33, 58, 128, 168, 170, 215, 241, 285, 303, 309, 318, 332, 338, 346, 350, 359, 372, 381, 383
```
(24th citation at lines 263-264 found by manual read, not by the mechanical grep — see finding
#12 above.)
