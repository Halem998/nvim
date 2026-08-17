# Research Report: Task #57

**Task**: 57 - Cut the generated .claude/CLAUDE.md eager surface without losing capability, refactoring capabilities to remove redundancy where a workflow can be preserved rather than merely trimmed.
**Started**: 2026-08-12
**Completed**: 2026-08-12
**Effort**: research (deep, evidence-verification-heavy)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/*/manifest.json`, `merge-sources/claudemd.md` (core, literature), `EXTENSION.md` (all 16 shape-(b) extensions), `.claude/CLAUDE.md` (deployed), `.claude-extensions.json`, `check-extension-docs.sh`, `extension-slim-standard.md`, `hard-mode-routing.md`, `lit-stage4a-flow.md`, `creating-extensions.md`, `specs/TODO.md`/`specs/state.json` (task 28 status)
- Live harness behavior observed directly in this session (Skill and Agent tool listings)
**Artifacts**:
- This report: `specs/057_cut_generated_claudemd_eager_surface/reports/01_cut-claudemd-eager-surface.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Re-measured baseline confirmed exact**: deployed `.claude/CLAUDE.md` is 42,798 B right now, matching the task description's figure precisely (no drift since that measurement — no `deploy-headless.sh` re-run was needed). Source breakdown: `core/merge-sources/claudemd.md` 24,770 B (58%), `literature/merge-sources/claudemd.md` 8,673 B (20%), and four `EXTENSION.md` files (email 2,185, memory 4,054, nix 1,385, nvim 1,491 = 9,115 B, 21%), plus ~240 B of assembly joins.
- **LEVER A — ADOPT.** Literature's "Literature Mode" section (6,569 B) substantially restates mechanics that live verbatim, and more precisely, in `context/patterns/lit-stage4a-flow.md` — confirmed by grep that all six `--lit`-capable skills (`skill-researcher`, `skill-planner`, `skill-implementer`, and their `-hard` variants) import that file directly, never through CLAUDE.md. ~4,600 B of the section (What `--lit` Does, Ad-Hoc/Conversational, Interactive Sub-Index Setup Detection, orchestrator_mode Dual-Consumer) is mechanically redundant; ~2,000 B (When to Use, Relationship to `--clean`, specs/literature/ convention, Composability) is compact decision-relevant content with no duplicate elsewhere and should stay. Estimated hard saving: **~4,300 B**.
- **LEVER B — ADOPT, reframed as consolidation, not just a cut.** Hard Mode's "Routing Mechanism" subsection (1,951 B, 43% of the 4,502 B Hard Mode section) restates the exact 5-step `--hard` routing ladder already documented, in more detail, in `context/guides/hard-mode-routing.md` — which explicitly says "The CLAUDE.md 'Routing Mechanism' and 'Hard Mode' sections are maintained directly in CLAUDE.md itself, independently of this document. Do NOT edit CLAUDE.md based on this document." That sentence is itself evidence of a known, deliberately-tolerated two-copy duplication. CLAUDE.md's subsection already ends with a pointer to this same file — the fix is to delete the restated ladder and keep the trailing pointer. Estimated hard saving: **~1,750 B**. The remaining Hard Mode content (What Hard Mode Does, When to Use, Cost Impact, Composability, Per-Invocation Only — 2,308 B combined) has no duplicate elsewhere and is compact pre-action decision content; leave as-is.
- **LEVER C — REJECT the "invent shape (a)" framing; ADOPT a scope-extension instead.** The premise "the file that documents the extension for a human reader is the same file injected into every session" is **false today**: `docs/guides/creating-extensions.md` and `docs/reference/standards/extension-slim-standard.md` show the README.md/EXTENSION.md split (README.md = user-facing overview, never injected; EXTENSION.md = terse routing-only content, injected) is **already implemented and already lint-enforced** — `check-extension-docs.sh` Rule U caps EXTENSION.md at 60 lines in **hard (blocking) mode by default**, and all 16 EXTENSION.md-shaped extensions currently comply (22–60 lines each; `formal` sits exactly at the 60-line ceiling). Verified zero violators. The real uncapped surface is the opposite one: `extension-slim-standard.md` explicitly scopes itself **out** of any extension whose `merge_targets.claudemd.source` is not `EXTENSION.md` — i.e., it explicitly exempts `core` and `literature`'s shape-(a) `merge-sources/claudemd.md` files, which is exactly where the actual size (24,770 B + 8,673 B = 33,443 B, 78% of the assembled file) lives, with **no size discipline at all**. Recommendation: extend Rule U's content-type-migration table and a size ceiling to shape-(a) sources instead of building anything new (no deploy-engine change needed either way — confirmed live via literature's already-working shape-(a) merge). No manifest-schema change: task 28 (`correct_mcp_ownership_model_and_purge_dead_declarations`) is confirmed **`[IMPLEMENTING]`** in `specs/state.json`/TODO.md right now, i.e. manifest-schema-adjacent work is in flight — per the task's own coordinate-first instruction, land the ceiling as an **external config** (e.g. a small JSON map keyed by `section_id` alongside `check-extension-docs.sh`), not a new `manifest.json` field, and defer the field to a follow-up once task 28 settles.
- **LEVER D — verdict SPLIT, and the "load-bearing" premise is empirically weaker than stated.** Grep-verified: `/research`, `/plan`, `/implement` all resolve skills via `command-route-skill.sh` reading `manifest.json` `routing`/`routing_hard` blocks — **no script or skill anywhere parses CLAUDE.md's "Skill-to-Agent Mapping" or "Command Reference" tables to make a routing decision.** Two sub-findings sharpen this: (1) the "Utility Scripts" subsection (2,988 B, 58% of the 5,145 B Command Reference section) lists ~15 scripts, several explicitly marked "no automated caller by design" — pure human/operator reference, never consulted by an agent mid-task; (2) **directly observed in this very session**, the harness itself injects a complete Skill-tool listing (skill name + one-line purpose) and a complete Agent-tool listing (agent name + one-line purpose) as native system-reminders, at zero CLAUDE.md cost, regardless of CLAUDE.md content — meaning CLAUDE.md's "Purpose" column in Skill-to-Agent Mapping (part of 2,422 B) and the entire "### Agents" subtable (858 B) restate information the harness already provides for free every session. Command names + one-line descriptions (the compact core of Command Reference, 2,157 B) remain genuinely pre-action (an agent/root session needs to know a command exists to invoke it, and command-route-skill.sh is what to invoke — this discoverability layer has no automated substitute). The Skill↔Agent *pairing itself* (which agent name a given skill dispatches to) is unique information not available elsewhere and should stay for operators/`meta-builder-agent`, but the Purpose/Model columns and Utility Scripts subsection are the droppable ~5,700 B (soft, or harness-duplicate, per the case).
- **Capability consolidation identified and named explicitly** (not silent): the Hard Mode Routing Mechanism duplication (LEVER B) is a genuine convergent-workflow case — see "Capability Consolidation" section below for the required before/after description.
- **Target math**: verified/estimated cuts total roughly 4,300 (A) + 1,750 (B) + up to ~5,700 (D, mixed hard/soft) ≈ 11,750 B, bringing the assembled file to roughly **31,000 B** — short of the description's illustrative ~26 KB target. Reaching 26 KB would require additional, not-yet-verified cuts to Task Management/Project Structure prose that this report did not find clean duplication evidence for; per the task's own acceptance framing ("a smaller measured cut with no capability loss beats a larger one that strands a workflow"), this report recommends banking the ~11.7 KB of evidence-backed cuts first and treating further reduction as a separate, later-verified pass rather than forcing unverified cuts now.

## Context & Scope

Task 57 asks for a research pass that measures the generated `.claude/CLAUDE.md` (assembled at deploy time from `core`'s and `literature`'s dedicated `merge-sources/claudemd.md` files plus 4 other loaded extensions' `EXTENSION.md` files), evaluates four candidate levers (A–D) against evidence rather than assumption, identifies genuine capability-consolidation opportunities, and recommends where a per-extension byte ceiling should live. The binding constraint throughout: no capability may disappear, only relocate or consolidate; every claimed saving must be labeled hard (removes real duplication or points at a file consumers already read directly) or soft (moves prose off the eager path but the content is still only reachable by explicit Read).

All figures below were measured directly against the source-store files in `agent-system/extensions/**` (never the deployed `.claude/**` tree, per the source-store/deploy-boundary rule) and cross-checked against the live-deployed `.claude/CLAUDE.md`, which matched the source-store sum exactly (42,558 B of source + 240 B of assembly joins = 42,798 B deployed), confirming no staleness.

## Findings

### Generation Mechanism (Confirmed, Not Re-Derived)

`.claude-extensions.json` shows the currently-loaded extension set is exactly: `core`, `email`, `literature`, `memory`, `nix`, `nvim`. Querying every extension's `manifest.json` for `merge_targets.claudemd` confirms the task description's claim precisely:

| Shape | Extensions | Source file |
|---|---|---|
| (a) dedicated `merge-sources/claudemd.md` | `core`, `literature` | — |
| (b) whole `EXTENSION.md` | all other 17 (`cslib`, `email`, `epidemiology`, `filetypes`, `formal`, `founder`, `latex`, `lean`, `memory`, `nix`, `nvim`, `present`, `python`, `typst`, `web`, `z3`) | — |
| none (resource-only) | `slidev` | no `merge_targets.claudemd` key at all |

Both shapes are live in the same deploy engine today with zero engine changes needed to add more shape-(a) files (literature's shape-(a) file is already flowing through the identical `generate_claudemd()` path core's does — verified by exact byte-for-byte match between `literature/merge-sources/claudemd.md` and the "Literature Extension"/"Literature Mode" sections in the deployed CLAUDE.md).

### Current Byte Breakdown (Re-Measured Live)

**Top level** (deployed `.claude/CLAUDE.md` = 42,798 B):

| Source | Bytes | % of total |
|---|---|---|
| `core/merge-sources/claudemd.md` | 24,770 | 57.9% |
| `literature/merge-sources/claudemd.md` | 8,673 | 20.3% |
| `memory/EXTENSION.md` | 4,054 | 9.5% |
| `email/EXTENSION.md` | 2,185 | 5.1% |
| `nvim/EXTENSION.md` | 1,491 | 3.5% |
| `nix/EXTENSION.md` | 1,385 | 3.2% |
| assembly joins/header | ~240 | 0.6% |

**core's 18 top-level `##` sections** (bytes):

| Section | Bytes |
|---|---|
| Quick Reference | 186 |
| Project Structure | 985 |
| Task Management (incl. Status Markers, Artifact Paths, Task-Type-Based Routing) | 3,861 |
| **Command Reference** (table+multi-task 2,157 + **Utility Scripts 2,988**) | **5,145** |
| State Synchronization | 198 |
| Git Commit Conventions | 279 |
| **Skill-to-Agent Mapping** (table 2,422 + Agents 858 + prose 2,066) | **5,346** |
| **Hard Mode** (header 243 + What HM Does 823 + When to Use 631 + Cost Impact 159 + Composability 436 + **Routing Mechanism 1,951** + Per-Invocation 259) | **4,502** |
| Literature Mode — Extension Pointer | 401 |
| Rules References | 1,340 |
| Context Discovery | 181 |
| Context Architecture | 169 |
| Context Imports | 257 |
| Multi-Task Creation Standards | 200 |
| Error Handling | 230 |
| jq Command Safety | 404 |
| Syncprotect | 583 |
| Important Notes | 369 |

**literature's 2 top-level `##` sections** (bytes):

| Section | Bytes |
|---|---|
| Literature Extension (header + Skill-Agent Mapping + Commands + Context Pointers) | 2,104 |
| **Literature Mode** (header 259 + **What `--lit` Does 2,214** + **Ad-Hoc/Conversational 687** + **Interactive Sub-Index Setup Detection 1,021** + **orchestrator_mode Dual-Consumer 675** + specs/literature/ convention 553 + When to Use 320 + Relationship to `--clean` 432 + Composability 213 + Per-Invocation Only 195) | 6,569 |

Bolded rows above mark the sections the lever verdicts below act on.

### LEVER A: Literature Mode Section — ADOPT

**Claim to verify**: "the canonical, executable contract already exists at `context/patterns/lit-stage4a-flow.md` and the six `--lit`-capable skills already import it directly rather than through CLAUDE.md."

**Verification performed**: `grep -rl "lit-stage4a-flow.md" agent-system/` confirms `skill-researcher`, `skill-planner`, `skill-implementer`, `skill-researcher-hard`, `skill-planner-hard`, `skill-implementer-hard` (exactly the six `--lit`-capable skills) all reference the file directly in their own `SKILL.md`. `lit-stage4a-flow.md`'s own header states it explicitly: "This file is the SINGLE canonical Stage 4a literature block. ... all reference this file instead of maintaining six near-duplicate copies." Direct content comparison of `lit-stage4a-flow.md`'s sections (Step 1 resolve directive, `LIT_DISABLED`/`GLOBAL_MISSING`/`SUBINDEX_PRESENT`/`AUTONOMOUS_GLOBAL`/`SPARSE_PROMPT_NEEDED`/`PROMPT_NEEDED` branches, the Four Options, Two-Checkpoint Sparse Detection) against CLAUDE.md's "What `--lit` Does" + "Ad-Hoc/Conversational" + "Interactive Sub-Index Setup Detection" + "orchestrator_mode Dual-Consumer" subsections confirms the latter is a prose restatement of the former's mechanics — genuinely redundant, not merely similar. **Claim verified true.**

**Verdict**: ADOPT. Cut the four mechanically-redundant subsections (2,214 + 687 + 1,021 + 675 = 4,597 B) to a single short pointer paragraph (~250–350 B) naming `lit-stage4a-flow.md` as the canonical contract. Keep the four subsections with no duplicate elsewhere and genuine pre-action decision value: When to Use `--lit` (320 B), Relationship to `--clean` (432 B), specs/literature/ Directory Convention (553 B, unique — confirmed via grep, no other file states this convention), Composability (213 B), Per-Invocation Only (195 B). **Estimated saving: ~4,300 B, hard (the canonical file is already read directly by all six consumers that need it).**

### LEVER B: Hard Mode Section — ADOPT (as consolidation)

**Claim to verify**: does `context/guides/hard-mode-routing.md` already exist as the detailed home for the 5-step routing precedence?

**Verification performed**: Read the full file. It contains the identical 5-step `--hard` resolution ladder (Steps 4a–4e) that CLAUDE.md's "Routing Mechanism" subsection restates (Steps 1–5, same content, same "extension overrides core" rule, same Step-4e-only safety-gate rule), plus additional detail CLAUDE.md does not carry (a "Deployed Hard Skills" inventory table, an "Adding routing_hard Entries" how-to). Critically, the file's own **Scope** note reads: *"The CLAUDE.md 'Routing Mechanism' and 'Hard Mode' sections are maintained directly in CLAUDE.md itself, independently of this document. Do NOT edit CLAUDE.md based on this document."* This is the codebase's own acknowledgment of a deliberately-tolerated two-copy duplication — exactly the class of "converged near-duplicate documented workflow" the task asks to look for. **Claim verified true, and stronger than the task description assumed**: this is not merely "a detailed home exists," it is "a detailed home exists and the two copies are known to have drifted enough that someone added a note forbidding cross-editing."

Also checked: is the routing-precedence prose actually consumed by any agent making a live decision, or is `--hard` resolution purely code-driven? Confirmed code-driven — `manifest-routing-lib.sh` executes the ladder in bash; no agent reads either doc to decide routing. Both `hard-mode-routing.md` and CLAUDE.md's restatement are reference documentation for humans/`meta-builder-agent`, not pre-action agent input. This affects how the saving is labeled: it is not "already read directly by a runtime consumer" in the strict LEVER-A sense, but it is a genuine identical-content duplication whose owner has already flagged the drift risk, so consolidating into one canonical source (with CLAUDE.md keeping only the pointer sentence it already has at the end of the subsection) is squarely the task's preferred "refactor away the redundancy" outcome. See Capability Consolidation below for the required before/after naming.

**Verdict**: ADOPT (as consolidation). Delete the restated 5-step ladder (1,951 B) and keep the existing trailing cross-reference sentence pointing to `context/guides/hard-mode-routing.md` (which the subsection already has). **Estimated saving: ~1,750 B**, labeled as **duplication-elimination / consolidation** rather than a pure hard-vs-soft pointer move (see next section). The remaining Hard Mode subsections (What Hard Mode Does 823 B — an index of the 8 H-technique names only, each with its own canonical contract at `context/contracts/*.md` that hard-mode agents already `@`-import directly at their own dispatch time, confirmed via grep on `general-implementation-hard-agent.md`; When to Use `--hard` 631 B — unique, no duplicate found anywhere else in the repo; Cost Impact 159 B; Composability 436 B; Per-Invocation Only 259 B) have no duplication evidence and should stay.

### LEVER C: Per-Extension `merge-sources/claudemd.md` — REJECT the framing, ADOPT the underlying goal via scope extension

**Claim to verify**: "this requires NO deploy-engine change — shape (a) is already implemented and already in production use by core and literature."

**Verification performed**: Confirmed true (see Generation Mechanism above) — no engine work needed either way.

**Deeper premise that needed verification and was found false**: the task description's motivating claim is *"for 17 of 19 extensions the file that documents the extension for a HUMAN READER is the same file injected into EVERY session. There is no way to write reader-facing detail without paying per-session token cost."* Reading `docs/guides/creating-extensions.md` directly contradicts this:

> "Every extension must provide a `README.md` file in its root directory. This is the **user-facing overview** of the extension, **distinct from** `EXTENSION.md` (which is included in `.claude/CLAUDE.md` via `generate_claudemd()` when the extension is loaded)."

This split is not aspirational — it is implemented, documented, and lint-enforced today via `docs/reference/standards/extension-slim-standard.md`:
- **Size Limit**: "Maximum: 60 lines for any EXTENSION.md file. Lint-enforced: `check-extension-docs.sh`'s Rule U... `SCHEMA_CONFORMANCE_GATE_MODE`, defaulting `hard`" (verified against the script source: `SCHEMA_CONFORMANCE_GATE_MODE="${SCHEMA_CONFORMANCE_GATE_MODE:-hard}"` at line 653 — i.e. **blocking by default**, not merely advisory as the standard doc's prose still says in one place; this is a minor doc/code staleness worth a one-line fix but does not change the substantive finding).
- **Required Sections** table restricts EXTENSION.md to exactly Header, Routing Table, Command List, Context Pointers (max 5).
- A **"Sections That Must Move to Context Files"** table already enumerates exactly the content-type migration the task's LEVER C envisions (usage examples → patterns/, architecture docs → domain/, troubleshooting → domain/, etc.).
- **Verified compliance**: measured line counts for all 16 EXTENSION.md-shaped extensions — range 22 (`latex`) to 60 (`formal`, exactly at the ceiling); zero violators today.

So the mechanism LEVER C proposes inventing **already exists, is already the "cap future growth" lever, and is already working** — just not under the name the task used. The real gap is the opposite of what the task assumed: `extension-slim-standard.md` **explicitly scopes itself out** of any extension whose `merge_targets.claudemd.source` is not `EXTENSION.md`:

> "core points `merge_targets.claudemd.source` at `merge-sources/claudemd.md` instead of `EXTENSION.md`, and has no `EXTENSION.md` file at all" — named as one of two cases "outside this standard's scope entirely."

That means the two files carrying 78% of the assembled CLAUDE.md's bytes (`core` 24,770 B, `literature` 8,673 B) are the two files with **zero size discipline of any kind**, while all 16 capped `EXTENSION.md` files sum to a maximum possible ~27 KB even if every extension in the repo were loaded simultaneously (measured: summing all 16 current `EXTENSION.md` byte counts = 26,774 B) — i.e., core alone already outweighs the entire capped extension population.

**Verdict**: REJECT the "invent a new per-extension merge-sources/claudemd.md" framing (it already exists as EXTENSION.md, already works, already caps growth for 16/17 extensions). **ADOPT** the underlying growth-control goal by extending `extension-slim-standard.md`'s scope and `check-extension-docs.sh`'s Rule U to cover shape-(a) sources (`core`, `literature`, and any future shape-(a) extension), since that is where the actual uncapped growth risk lives. This is a **hard, structural** fix — it is the only lever of the four that caps future growth, exactly as the task's own framing intended, just aimed at the correct target file.

**No byte saving from this lever alone today** (current shape-(a) content, after Levers A and B are applied, is not itself further reducible without additional verified findings) — its value is preventing the next regression, which is precisely what the task asked LEVER C to establish.

### Manifest-Schema Coordination Check (Required Before Any Ceiling Field)

The task instructs: "consider whether that ceiling belongs in manifest.json as a declarable field — COORDINATE FIRST if other manifest-schema work is in flight, and fall back to an external config if it is."

**Verification performed**: `specs/state.json`/`specs/TODO.md` show task 28, "Correct mcp ownership model and purge dead declarations," status **`[IMPLEMENTING]`** right now — confirmed via `grep -n -B3 "mcp ownership"` in TODO.md ("28 [IMPLEMENTING] — Rewrite the canonical MCP ownership document...") and its plan file `specs/028_correct_mcp_ownership_model_and_purge_dead_declarations/plans/01_mcp-ownership-hybrid-rewrite.md`. This is the exact task a separate, already-planned "warning-first context-budget gate" TODO item (which itself proposes a `merge_targets.claudemd.max_bytes` manifest field) names as the coordination dependency ("NOTE THE SEQUENCING DEPENDENCY: manifest-schema changes must coordinate with the in-flight manifest-schema work (correct-mcp-ownership / extension-manifest efforts)").

Spot-checked task 28's plan for direct collision risk on the `merge_targets.claudemd` manifest key specifically: it touches `manifest.json`'s `mcp_servers` field and MCP-related declarations, not `merge_targets`. Direct field-name collision risk is low, but the task's own instruction is unconditional ("if that work is unsettled when this task starts... fall back to external config"), and task 28 is unsettled (`[IMPLEMENTING]`, not `[COMPLETED]`).

**Recommendation**: land the per-extension/per-shape byte ceiling as an **external config** — e.g. a small JSON map (`{"core": <bytes>, "literature": <bytes>, "_extension_default_lines": 60}`) living alongside `check-extension-docs.sh` in `agent-system/extensions/core/scripts/` or `agent-system/extensions/core/context/config/`, read by an extended Rule U check. Defer promoting this to a `manifest.json` field until task 28 (and any related extension-manifest-schema work it spawns) reaches `[COMPLETED]`.

### LEVER D: Command Reference & Skill-to-Agent Mapping — SPLIT verdict, empirical correction to the "load-bearing" premise

**Claim to verify**: "these are genuinely load-bearing — agents route from them." Task instruction: "Establish empirically which columns any consumer actually reads before removing anything."

**Verification performed**: `grep -n "command-route-skill\|SKILL_NAME="` on `research.md`, `plan.md`, `implement.md` shows all three commands resolve their skill via `source .claude/scripts/command-route-skill.sh "<op>" "$task_type" "<default-skill>" "$effort_flag"` — i.e. routing is 100% code-driven against `manifest.json`'s `routing`/`routing_hard` blocks, never by an agent reading CLAUDE.md's tables. A repo-wide grep for `"Skill-to-Agent Mapping"` and `"## Command Reference"` outside the merge sources themselves found only two incidental hits: `skill-tag/SKILL.md` (cites the table as evidence a skill is intentionally *absent* from it, not as a lookup) and `skill-orchestrate/SKILL.md` (has its own, differently-shaped internal "Skill-to-Agent Mapping" table with `Operation | subagent_type | Notes` columns — a self-contained table for its Agent-tool dispatch decisions, not a reference to CLAUDE.md's table). **No functional consumer parses either table to make a decision.** The "genuinely load-bearing" claim as literally stated (agents route *from* these tables) is not supported by evidence and should be treated as refuted for the routing-mechanism sense; it is, however, correct in the weaker "discoverability" sense described below.

Two further, more actionable findings:

1. **"Utility Scripts" subsection (2,988 B, 58% of Command Reference's 5,145 B)** lists ~15 scripts, several explicitly annotated "no automated caller by design" (`install-aliases.sh`, `install-systemd-timer.sh`, `migrate-directory-padding.sh`, `verify-lean-mcp.sh`) or "not automated beyond that — no other automated caller" (`lint-contract-compliance.sh`). This is operator/lint-only reference material: no agent workflow invokes these scripts as part of normal task execution. No canonical duplicate of this content exists elsewhere yet (checked `docs/` for an existing scripts inventory — none found), so relocating it is a genuine **soft** saving (moves it off the eager path into a new context/docs pointer target) rather than duplication-elimination.

2. **Harness-native duplication, directly observed in this session** (not inferred): at the start of this very conversation, the harness independently injected (a) a complete list of Skill-tool names with one-line purposes, and (b) a complete list of Agent-tool names with one-line purposes — both **regardless of CLAUDE.md content**, at zero CLAUDE.md token cost. Comparing that native listing against CLAUDE.md's "Skill-to-Agent Mapping" table's "Purpose" column (part of the 2,422 B table) and the entire "### Agents" subtable (858 B, 11 agents each with a one-line Purpose) shows substantial content overlap — the harness already tells any session "what a skill/agent is for" for free. This is a real, verifiable, zero-information-loss redundancy, though it does not fit the task's strict hard/soft binary cleanly (there is no "canonical file consumers already read" to point at — the duplication is against a runtime harness feature, not a project artifact). It is flagged here precisely so the planner does not silently assume it is either category without knowing its actual nature.

**Verdict — split**:
- Command names + one-line usage + flags (the compact 2,157 B core of Command Reference, minus Utility Scripts) — **KEEP eager**. An agent/root session genuinely needs to know a command exists and roughly what flags it accepts before invoking it; there is no automated substitute for this discoverability layer (the harness does not natively list slash-commands the way it lists Skills/Agents).
- **Utility Scripts subsection (2,988 B) — CUT to a pointer.** Soft saving, ~2,700 B (keep ~300 B pointer sentence naming a new canonical scripts-inventory doc).
- **Skill-to-Agent Mapping's "Purpose" column and the "### Agents" subtable — CUT or compress**, since both substantially restate harness-native content at zero information gain. Keep the Skill↔Agent **pairing** itself (which concrete agent name a skill dispatches to) since that is unique information not available via the harness's Skill listing and is genuinely useful to `meta-builder-agent`/operators auditing the system. Estimated combined saving if Purpose column and Agents subtable are cut/compressed to a minimal Skill|Agent-only table: **~1,000–1,500 B** (needs a planner-stage line-by-line pass to size precisely; not claimed as tightly verified as Levers A/B above).
- The "Model Enforcement" paragraph (part of the 2,066 B post-Agents prose) is a compact restatement of `docs/reference/standards/agent-frontmatter-standard.md` (289 lines) and already ends with a "See ... for details" pointer — minor further tightening possible but not large; not separately quantified here.

## Capability Consolidation (Named Explicitly, Per Task Requirement)

**Before**: Two independently-maintained documents describe the identical `--hard` 5-step skill/agent routing-resolution ladder: CLAUDE.md's "Hard Mode → Routing Mechanism" subsection (terse, table-adjacent prose, 1,951 B) and `context/guides/hard-mode-routing.md` (fuller prose with worked examples, an "Extension Overrides Core" walkthrough, a "Deployed Hard Skills" inventory, and an "Adding routing_hard Entries" how-to). The guide file's own header explicitly forbids syncing the two ("Do NOT edit CLAUDE.md based on this document"), i.e. the codebase already tolerates known drift between them as a matter of policy rather than fixing it.

**After**: CLAUDE.md's "Routing Mechanism" subsection is reduced to its existing trailing cross-reference sentence (already present: "See `context/guides/manifest-routing-schema.md` for the full routing model ... and `context/guides/hard-mode-routing.md` for `--hard`-specific detail"), removing the restated ladder entirely. `hard-mode-routing.md` becomes the sole edit target for any future change to the `--hard` routing-precedence rules; its own Scope note should be updated to drop the "Do NOT edit CLAUDE.md based on this document" caveat, since there is no longer a second copy to protect against.

**What a user can still do, unchanged**: anyone (human operator, `meta-builder-agent`, or an agent debugging routing) who needs the exact 5-step ladder still finds it, now via the same backticked path CLAUDE.md already names — no capability is lost, only the duplicate copy and its associated drift risk.

## Decisions

- Treat LEVER A and LEVER B cuts as hard/consolidation savings, safe to plan for directly (~4,300 B + ~1,750 B).
- Treat LEVER C as a structural/process fix (extend `extension-slim-standard.md` scope + Rule U to shape-(a) sources) rather than a new file-type invention; zero immediate byte saving claimed from it, all of its value is regression-prevention.
- Treat LEVER D's Utility Scripts relocation and the Skill-to-Agent Mapping Purpose/Agents-table compression as real but less tightly quantified (soft, and harness-duplicate respectively) savings requiring a planner-stage sizing pass before being committed to a specific byte figure.
- Do not force additional cuts to Task Management, Project Structure, or Rules References — no duplication or redundancy evidence was found for these sections in this pass; per the task's explicit acceptance framing, an unverified cut is worse than an honestly smaller verified one.
- Recommend the byte-ceiling mechanism be an external config, not a `manifest.json` field, because task 28 (`correct_mcp_ownership_model_and_purge_dead_declarations`) is confirmed `[IMPLEMENTING]` right now.

## Risks & Mitigations

- **Risk**: cutting the Hard Mode Routing Mechanism subsection could strand a reader who only ever consults CLAUDE.md and never follows pointers. **Mitigation**: the pointer sentence already exists in the current text; nothing new needs to be authored, only the restated ladder needs deletion — verify the pointer sentence survives the edit.
- **Risk**: cutting literature's four mechanical subsections could leave `--lit` behavior undocumented for a reader who is not one of the six skills that `@`-import `lit-stage4a-flow.md` (e.g., a human auditing the system via CLAUDE.md alone). **Mitigation**: keep a one-paragraph pointer naming the file explicitly rather than deleting the cross-reference entirely (matches the existing "Literature Mode — Extension Pointer" stub's own style in core's section).
- **Risk**: the extension-slim-standard.md doc's stated default ("advisory") does not match the script's actual default (`hard`/blocking) — a real, if minor, doc/code drift. **Mitigation**: flag as a one-line doc fix for whoever picks up the plan; it does not change any of this report's verdicts since the blocking behavior is what's actually in force.
- **Risk**: Utility Scripts relocation needs a landing spot; none exists yet. **Mitigation**: the plan should create one canonical scripts-inventory context/docs file as part of this change, not merely delete the CLAUDE.md content.

## Context Extension Recommendations

- **Topic**: shape-(a) `merge-sources/claudemd.md` size discipline
- **Gap**: `extension-slim-standard.md` explicitly excludes `core` and `literature`'s shape-(a) sources from its 60-line/content-migration rules, leaving 78% of the assembled CLAUDE.md's bytes with zero size governance.
- **Recommendation**: extend `extension-slim-standard.md` (and `check-extension-docs.sh`'s Rule U) to declare an explicit ceiling for shape-(a) sources, sourced from an external config file (not a manifest field, per the task-28-coordination finding above) until manifest-schema work settles.

## Appendix

### Search Queries / Commands Used

- `jq -r '.merge_targets.claudemd // empty' agent-system/extensions/*/manifest.json` — confirmed shape (a)/(b) split across all 19 extensions
- `jq -r '.extensions | keys[]' .claude-extensions.json` — confirmed currently-loaded extension set
- `wc -c`, Python byte-offset scripts against `## `/`### ` header boundaries — all per-section byte figures above
- `grep -rl "lit-stage4a-flow.md" agent-system/` — LEVER A verification
- `grep -rn "hard-mode-routing.md"` / direct read of that file and of `core/merge-sources/claudemd.md` lines 251–278 — LEVER B verification
- `grep -n "EXTENSION.md\|README.md" agent-system/extensions/core/docs/guides/creating-extensions.md` and full read of `extension-slim-standard.md` — LEVER C's central finding
- `for d in agent-system/extensions/*/EXTENSION.md; do wc -l "$d"; done` — confirmed zero Rule U violators today
- `grep -n "command-route-skill\|SKILL_NAME=" agent-system/extensions/core/commands/{research,plan,implement}.md` — LEVER D routing-mechanism verification
- `grep -n -B3 -i "mcp ownership"` / `grep -n -i "correct-mcp-ownership"` against `specs/TODO.md` — manifest-schema-in-flight confirmation (task 28, `[IMPLEMENTING]`)
- Direct observation of this session's own harness-injected Skill-tool and Agent-tool listings — LEVER D harness-duplication finding

### Files Read In Full

- `agent-system/extensions/literature/merge-sources/claudemd.md`
- `agent-system/extensions/core/context/patterns/lit-stage4a-flow.md`
- `agent-system/extensions/core/context/guides/hard-mode-routing.md`
- `agent-system/extensions/core/docs/reference/standards/extension-slim-standard.md`
- `agent-system/extensions/{nvim,email,memory,nix}/EXTENSION.md`
- Relevant excerpts of `agent-system/extensions/core/docs/guides/creating-extensions.md`, `agent-system/extensions/core/scripts/check-extension-docs.sh`, `agent-system/extensions/core/agents/general-implementation-hard-agent.md`
