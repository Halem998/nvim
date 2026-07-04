# Research Report: Task #814

**Task**: 814 - Synthesis capstone for the systematic .claude/ agent-system review
**Started**: 2026-07-04
**Completed**: 2026-07-04
**Effort**: synthesis/research only — no implementation performed
**Dependencies**: specs/811 (orchestration core audit), specs/812 (knowledge & standards audit), specs/813 (infrastructure audit) — all read in full
**Sources/Inputs**: `specs/811_audit_orchestration_core/reports/01_orchestration-core-audit.md` (20 findings), `specs/812_audit_knowledge_standards_layer/reports/01_knowledge-standards-audit.md` (15 findings), `specs/813_audit_infrastructure_layer/reports/01_infrastructure-audit.md` (15 findings); WebSearch (July 2026: Claude Agent Skills progressive disclosure, multi-agent orchestration patterns, context-rot/self-healing validation)
**Artifacts**: this report — `specs/814_synthesize_improvement_roadmap/reports/01_improvement-roadmap.md`
**Standards**: report-format.md, subagent-return.md, artifact-formats.md

## Executive Summary

- All **50 findings** from the three sibling audits (OC-01..OC-20, KS-01..KS-15, IN-01..IN-15) were ingested, cross-referenced, and re-prioritized into **4 tiers**: **P0 = 10** (correctness/robustness — currently broken or silently non-functional), **P1 = 20** (consistency — real gaps, no live breakage), **P2 = 13** (complexity-reduction/performance), **P3 = 7** (nice-to-have/policy decisions). No finding was dropped; every ID from 811/812/813 appears at least once below.
- **Three genuine cross-layer threads** were confirmed and merged (per the task brief's hypothesis), plus **one additional systemic thread this synthesis surfaces**: a "documented-but-not-actually-wired" pattern that recurs independently in all three layers (a command flag, a manifest routing entry, an index flag, and two validator scripts) — see Cross-Cutting Thread 4 below. This is the report's single most important synthesis finding: it is not four unrelated bugs, it is one recurring failure mode (declare capability in docs/config → never verify it actually executes) that a single unified validation gate would prevent from recurring.
- **Two flagship complexity-reduction candidates** are confirmed and sequenced: (1) **OC-13** — extracting ~5,400 lines of duplicated 11-stage skill boilerplate — is the single largest win, but it **should be preceded by OC-10** (converting 8 physically-duplicated core skill files to symlinks) so the extraction is authored once at the canonical source rather than twice; (2) applying the same progressive-disclosure fix (Anthropic's own Agent Skills guidance: split `SKILL.md` into `references/*.md`, loaded on demand) to the largest monolithic skills (OC-17) and oversized standards docs (KS-11), plus deduplicating shared script helpers (IN-06).
- Best-practices research (July 2026) directly validates several audit recommendations already made: progressive disclosure for skill/doc size, single-canonical-source-of-truth to avoid drift, per-stage validation gates to prevent cascade failure, and "don't have the LLM re-derive what a deterministic script already enforces." Each is mapped to a specific finding below rather than treated as generic advice.
- **REDUCE vs ADD**: of the 50 findings, **44 are REDUCE** (delete dead code, fix broken wiring, deduplicate, restore intended state — net complexity goes down or stays flat), **4 are ADD** (OC-02's `--hard` dispatch path, KS-10's six new index entries, IN-08's new validator call site, IN-12's one-line schema key — each is a small, narrowly-scoped completion of an already-documented capability, not new architecture), and **2 are policy-decisions-only** (OC-20, OC-18) with no default action recommended. This confirms the review found far more to remove/consolidate/fix than to add — consistent with the user's directive.
- **Spawn-first shortlist**: 9 ready-to-paste task descriptions are provided, sequenced by dependency, covering all 50 findings across roughly 5 batched "fix" tasks (P0/P1, low risk, mechanical) and 4 larger structural tasks (the two flagships, the validation-gate capstone, and a progressive-disclosure/dedup batch).

## Context & Scope

This is a pure synthesis task: no `.claude/` files were edited, no tasks were created, and no `state.json`/`TODO.md` changes were made. The three input reports were read in full (not sampled) and are treated as ground truth — this report does not re-verify their findings against the filesystem, it de-duplicates, cross-references, prioritizes, and sequences them, and adds external best-practices grounding. Batch context (tasks 804/808/809/810 — model-flag wiring, atomic marker creation, file-scope locking, unified gate path) is excluded throughout; none of the findings below re-recommend that work, and IN-13 (a newly-surfaced concurrency bug in `task-lock.sh`, the same script 808 touched) is a genuinely distinct defect, not a critique of 808's work.

## Methodology

1. Read all three reports in full (not excerpted), extracting all 50 findings with their ID, severity, category, affected files, and recommended change verbatim.
2. Built a cross-reference matrix across the three audits' Category/Affected-Files columns to detect genuine overlaps (same root cause manifesting in multiple layers) versus superficial keyword overlap (e.g., two findings both mentioning `.opencode/` but for unrelated reasons were kept separate, not force-merged).
3. Verified the three cross-layer threads named in the task brief against the source evidence (each is confirmed below with its constituent IDs), and identified one additional emergent thread (Cross-Cutting Thread 4) purely from pattern-matching across the "Recommended Change" columns of all three reports.
4. Ran three targeted WebSearches (July 2026) on: Claude Agent Skills progressive disclosure / duplication avoidance; multi-agent orchestration design patterns and CI/config-drift gates; context-rot mitigation and self-healing validation patterns. Mapped each surfaced practice to a specific finding rather than listing generic advice.
5. Assigned each of the 50 findings to one of 4 priority tiers using a consistent rule (see Priority Tiers section) derived from each finding's own severity + category fields, not re-litigated from scratch — this preserves the source audits' judgment while making cross-audit severities comparable (the three reports used the same severity vocabulary but audited different layers, so a "High" in 813 and a "High" in 811 needed to be checked for comparable meaning, which they were).
6. Sequenced a dependency-respecting roadmap and drafted the spawn-first shortlist as complete, pasteable `/task` descriptions.

## Consolidated Findings Register

Findings are grouped by cross-layer thread where a genuine shared root cause exists; all other findings are listed individually. Every one of the 50 source IDs appears exactly once below (cross-reference "Also relevant to" notes point to related-but-distinct entries without double-counting them in tier totals).

### Cross-Cutting Thread 1 — Dual-copy / no single source of truth

| Consolidated ID | Source IDs | Finding | Tier |
|---|---|---|---|
| CF-01 | OC-10 + KS-06 + IN-03 | Three independent instances of the same root cause — content is authored once but deployed/copied to multiple locations with no enforced single source of truth, so it silently forks: (a) 8 core skill file pairs are physically duplicated between `.claude/skills/` and `.claude/extensions/core/skills/` rather than symlinked, and this **already caused proven historical drift** (OC-10); (b) the shared extension source for `return-metadata-file.md` hardcodes `.opencode/`-prefixed paths that are only correct for one of its two deploy targets (KS-06); (c) three scripts (`task-lock.sh`, `orchestrator-postflight.sh`, `literature-briefing-invoke.sh`) are referenced repo-wide but declared in no extension's `provides.scripts`, meaning a fresh extension sync would silently omit them (IN-03). | P1 (OC-10, IN-03) / P1 (KS-06) — see Priority Tiers |

### Cross-Cutting Thread 2 — Dead code, dead references, unreachable content

| Consolidated ID | Source IDs | Finding | Tier |
|---|---|---|---|
| CF-02 | OC-01 + OC-03 + OC-15 + IN-09 | Four distinct instances of stale/dead artifacts with outsized "mislead a future maintainer" risk: `.claude/commands/README.md` mislabels the actively-maintained `.claude/commands/` as "DEPRECATED" (OC-01); `/zotero` command and `skill-zotero` are broken symlinks to a directory that no longer exists (OC-03); `skill-orchestrator` is fully orphaned dead code with a byte-identical stray `.archived` copy (OC-15); `literature-audit.sh` is a dated, zero-reference exploratory script (IN-09). | P1 (OC-01, OC-03, OC-15) / P2 (IN-09) |
| CF-03 | KS-06 + KS-07 + KS-08 + KS-10 | Systemic stale/broken cross-references within the knowledge layer: 35 occurrences of dead singular-form paths (`.claude/agent/`, `.claude/command/`) across 14 files (KS-07); docs pointing at 3 scripts that were never built (KS-08); 6 files with zero `index.json` entry, some load-bearing (KS-10); `.opencode/` path hardcoding (KS-06, also counted in CF-01). | P1 (all four) |

### Cross-Cutting Thread 3 — Flagship: duplicated skill/doc boilerplate (complexity reduction)

| Consolidated ID | Source IDs | Finding | Tier |
|---|---|---|---|
| CF-04 | OC-13 + OC-11 + OC-14 | ~5,400 lines of near-identical 11-stage boilerplate duplicated across `skill-researcher`/`skill-planner`/`skill-implementer`/`skill-reviser` (+ `-hard` variants); the `-hard` variants are kept in sync only by comment-level convention (OC-11, resolved as a side effect of extraction); 3-4 implementation agents separately duplicate a "Progressive Handoff Update" section verbatim (OC-14, same fix pattern, different file family). | P2 (flagship) |
| CF-05 | OC-17 + KS-11 + IN-06 | The same progressive-disclosure/dedup fix applied to three different file families: oversized monolithic skills with no `references/` split (OC-17: `skill-memory` 2,482 ln, `skill-literature` 1,781 ln, `skill-todo` 821 ln, `skill-fix-it` 620 ln); oversized `context/standards/` and `context/formats/` docs exceeding their own documented size budget (KS-11: `error-handling.md` 1056 ln vs 700 budget, `command-structure.md` 965 ln vs 600 budget); byte-for-byte duplicated shell helper functions across 5+ scripts (IN-06: `format_size()`, age-helpers, colors+counters preamble). | P2 |

### Cross-Cutting Thread 4 — "Documented-but-unwired" capability (emergent; not named in the task brief, surfaced by this synthesis)

This is the report's key original finding: a single failure mode — a capability is declared present in a manifest, a command's options table, a `load_when: always`, or a validator script exists — but nothing in the execution path actually invokes/enforces it — recurs independently across all three audits.

| Consolidated ID | Source IDs | Finding | Tier |
|---|---|---|---|
| CF-06 | IN-01 + KS-15 | **The flagship of this thread.** `validate-meta-write.sh` — the documented `/meta` anti-bypass safety hook, fully implemented, with a wired sibling (`validate-plan-write.sh`) proving the pattern works — is simply absent from `settings.json`'s `PostToolUse` array (IN-01, critical). Separately, `validate-context-index.sh` — a working validator that independently reproduced 3 of 812's top findings when run manually — is never wired into pre-commit or CI (KS-15). Both are "the enforcement code exists; nobody calls it." | P0 (IN-01) / P1 (KS-15) |
| CF-07 | OC-02 + OC-15 + IN-02 + IN-04 | Documented-but-broken/missing capability, four instances: `/orchestrate` has no `--hard` dispatch path despite `skill-orchestrate-hard` being fully documented as available (OC-02); `skill-orchestrator` is dead code no longer reflecting real routing (OC-15, also in CF-02); `literature`'s `keyword_overrides` uses the wrong JSON shape and has silently never worked, error swallowed by `2>/dev/null` (IN-02, high); `lean`'s `routing_hard` entries point at skills that don't exist, which would crash at runtime under the documented "Steps 1-4 are trusted, not existence-gated" precedence rule (IN-04, high). | P1 (OC-02) / P1 (OC-15, dup of CF-02) / P0 (IN-02, IN-04) |
| CF-08 | KS-01 | `repo/project-overview.md` has `load_when.always: true` and is unconditionally `@`-imported by CLAUDE.md, but the file does not exist on disk — every single command invocation silently loads nothing where it expects a baseline project overview. | P0 |
| CF-09 | IN-07 + IN-08 | Two purpose-built scripts (`check-vault-threshold.sh`, `validate-handoff.sh`) exist, are declared, even have test coverage in one case, but have **zero production callers** — the consuming skills (`skill-todo`, `skill-orchestrate`) reimplement the same logic inline instead of calling them, or skip validation entirely before consuming untrusted state (`skill-orchestrate` reads `.orchestrator-handoff.json` with no pre-validation, despite documenting it as "the ONLY file read after each dispatch"). | P1 (both) |

**Best-practice link**: current (July 2026) multi-agent orchestration guidance explicitly names this exact failure mode — "cascade failure is the failure mode... add per-stage output validation," and identifies unvalidated intermediate state (like an unvalidated handoff file feeding a state-machine loop) as a primary orchestration-level failure class. See Best-Practices Mapping below.

### Standalone findings (no cross-layer merge — each retains its severity-mapped tier)

| ID | Layer | One-line finding | Tier |
|---|---|---|---|
| OC-04 | commands | `skill-todo`/`skill-status-sync` labeled "(direct execution)" in CLAUDE.md but never actually invoked via the Skill tool by their commands | P3 |
| OC-05 | agents/skills | `.claude/{agents,skills,commands}` contain symlinks from unloaded extensions (cslib/literature/zotero); undocumented, causes count confusion | P3 |
| OC-06 | agents | 4/23 agents skip the Stage-0 early-metadata write with no documented exemption rationale | P1 |
| OC-07 | context | `early-metadata-pattern.md`'s "Audience" section understates real adoption (4 named vs. 19 actual) | P3 |
| OC-08 | skills | No documented rule for which lifecycle-marker tier (full/GATE-only/metadata-only/neither) applies to which skill category | P1 |
| OC-09 | skills | `skill-memory`'s ad hoc schema reuses the reserved value `"status": "completed"` — collision risk, not a live bug | P3 |
| OC-12 | skills | `skill-team-implement`'s lack of a synthesis-agent step (vs. team-research/team-plan) is undocumented asymmetry, though architecturally sound | P1 |
| OC-16 | skills | `skill-pr-implementation` appears fully subsumed by `skill-pr-review-implementation`'s fallback path — needs verification before retirement | P2 |
| OC-18 | skills | Neovim/Nix domain skill near-duplication is low-cost and not urgent at current scale (2 domains) | P3 |
| OC-19 | agents | 3 agents disagree on both the frontmatter key name and value format for tool restriction; the standard doesn't define either | P1 |
| OC-20 | agents | CSLib research uses `opus`, implementation uses `sonnet` — plausibly intentional, but the formal-reasoning carve-out doesn't address research-vs-implementation sub-roles | P3 (policy decision only) |
| KS-02 | context | `index.schema.json` declares `languages`; 74% of entries actually use `task_types` — schema-invalid under `additionalProperties: false` | P0 |
| KS-03 | context | `line_count` stale for 61% of index entries, undermining every documented token-budget calculation | P1 |
| KS-04 | context | `topic-assignment-pattern.md`'s index entry is missing `domain` and misuses `description` for `summary` — actively-referenced content, broken metadata | P0 |
| KS-05 | context | `meta-builder-agent` loads 2,434 lines of self-declared-deprecated orchestration content in addition to its replacements (4,534-line combined budget, >53% waste) — largest single quantified token win in the review | P1 |
| KS-09 | rules | `neovim-lua.md` alone lacks the `paths:` YAML frontmatter 9/10 sibling rule files use — may silently never auto-apply in this very repository | P0 |
| KS-12 | docs | `extension-slim-standard.md`'s 60-line cap and "14 extensions" baseline are stale; 6/19 `EXTENSION.md` files now exceed the cap | P2 |
| KS-13 | rules/context | Two same-topic `error-handling.md` docs (180-ln always-applied quick-reference vs. 1056-ln comprehensive) have no cross-link in either direction | P1 |
| KS-14 | context | `index.schema.json`'s `domain` enum includes an unused `"system"` value | P3 |
| IN-05 | scripts | `skill_validate_input()` uses `exit 1` instead of `return 1` in a sourced-library function, unlike its sibling `command-gate-in.sh` | P0 |
| IN-06 | scripts | (see CF-05) | P2 |
| IN-10 | scripts | `zotero-generate-export.sh` uses raw jq `!=` (the documented Issue #1132 anti-pattern) — not currently live-buggy since it's a static file, but inconsistent house style | P2 |
| IN-11 | scripts/hooks | 5 files use `#!/bin/bash` instead of the dominant `#!/usr/bin/env bash` convention | P2 |
| IN-12 | extensions | `email` extension manifest is the only one of 19 missing the top-level `hooks: {}` key (null-safe today, schema-consistency gap) | P2 |
| IN-13 | scripts | `task-lock.sh`'s scope-mutex wait timeout (5000ms) is shorter than its own staleness threshold (10000ms) — a live contender can never win the race under legitimate contention, directly relevant to this repo's own concurrent-batch-orchestration pattern | P0 |
| IN-14 | scripts | `generate-todo.sh` re-parses all of `state.json` once per active task (O(N) subprocess spawns) instead of once per invocation | P2 |
| IN-15 | hooks/settings | A dead `PreToolUse` conditional plus inconsistent path-substring matching between two `state.json`-guarding hooks | P1 |

## Best-Practices Mapping (July 2026 research → concrete findings here)

| Practice (source) | Concrete finding/gap it maps to |
|---|---|
| **Progressive disclosure**: keep `SKILL.md` bodies small; split detail into `references/*.md` loaded on demand; "detail files consume no tokens until accessed." ([Claude Platform Docs — Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices), [Anthropic Engineering — Equipping agents with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)) | Directly validates OC-17 (4 monolithic skills with no `references/` split) and KS-11 (oversized standards/formats docs exceeding their own stated budgets) as genuine, not cosmetic, complexity issues. Also validates OC-13's extraction target (shared 11-stage skeleton) as the correct fix shape — extract to referenced pattern files, don't just shrink in place. |
| **"Never duplicate the linter"**: don't have an LLM re-derive what a deterministic script/hook already enforces instantly. ([alexop.dev — Progressive Disclosure for AI Coding Tools](https://alexop.dev/posts/stop-bloating-your-claude-md-progressive-disclosure-ai-coding-tools/)) | Directly names the anti-pattern in IN-07 (`skill-todo` re-derives the `VAULT_THRESHOLD=1000` check inline instead of calling `check-vault-threshold.sh`) and IN-08 (`skill-orchestrate` inline-parses `.orchestrator-handoff.json` instead of calling the existing, tested `validate-handoff.sh`). Both are "an LLM-authored skill re-implements what a deterministic script already does correctly." |
| **Sequential-pipeline / stage-gate pattern**: "add per-stage output validation — cascade failure is the failure mode... a pipeline with no per-stage validation will happily produce a polished final answer built on a hallucinated first-stage result." ([Digital Applied — Multi-Agent Orchestration Patterns 2026](https://www.digitalapplied.com/blog/multi-agent-orchestration-patterns-producer-consumer)); "inter-phase boolean exit gates block agents from declaring completion unless explicit success criteria are set in a shared state file." | This is the precise architectural justification for CF-09 (wire `validate-handoff.sh` before `skill-orchestrate`'s state-machine loop consumes `.orchestrator-handoff.json`) — `skill-orchestrate` is exactly the sequential-pipeline-with-shared-state pattern this guidance describes, and it currently has no per-stage gate on its single most load-bearing artifact. |
| **Context rot**: "every frontier model degrades as its context window fills; curate the smallest high-signal set of tokens; use adaptive memory that automatically resolves contradictions and filters outdated information." ([mem0.ai — Context Engineering AI Agents Guide 2026](https://mem0.ai/blog/context-engineering-ai-agents-guide); cited independently by 811 and 812) | Directly grounds KS-05 (2,434 lines of self-declared-deprecated content still loaded per meta-task dispatch) as a textbook context-rot instance, and grounds KS-15's root-cause framing ("index.json populated once, never re-validated, silently rots") as the systemic driver behind KS-01/02/03/04/10. The project's own memory system already implements the recommended "validate-on-read" self-healing pattern (per CLAUDE.md's Memory Extension section); this review's single highest-leverage structural recommendation is extending that same validate-on-read discipline to `context/index.json`. |
| **Single canonical source of truth to prevent drift** (implicit across all three orchestration-pattern sources; explicit in self-healing-orchestrator literature: failures cluster at "boundaries between the model and execution environment" including "stale evidence" and "disagreement between sources") ([arXiv 2606.01416 — Self-Healing Agentic Orchestrators](https://arxiv.org/html/2606.01416v1)) | Grounds CF-01 (OC-10 + KS-06 + IN-03) as one architectural class of defect, not three unrelated ones: every instance is "the same content has two homes and nothing keeps them in sync." The proven fix pattern (symlinks, as already used correctly for cslib/literature/zotero extensions) is the existing in-repo template — OC-10's own audit already identifies this positive counter-example. |
| **Scoped tool identities / explicit governance as an architectural control locus**: 2026 orchestration surveys formalize "routing, scoped identities, tool permissions, approval gates" as the specific places systems attach controls. ([Lushbinary — Multi-Agent AI Orchestration Patterns](https://lushbinary.com/blog/multi-agent-orchestration-patterns-supervisor-swarm-pipeline-router-guide/); [arXiv 2604.19818 — Evidence-Synthesis Framework for Orchestrating Agentic AI](https://arxiv.org/pdf/2604.19818)) | Grounds OC-19 (agent frontmatter has no canonical `tools`/`allowed-tools` field despite 3 agents already restricting their own tool grants in two incompatible ways) as a real governance gap, not mere formatting inconsistency — tool-scoping is exactly the kind of "architectural control locus" 2026 guidance says should be formalized, not left ad hoc. |
| **"Start with the simplest pattern that fits; most teams over-architect."** ([Beam.ai — 6 Multi-Agent Orchestration Patterns for Production 2026](https://beam.ai/agentic-insights/multi-agent-orchestration-patterns-production)) | Directly supports this report's REDUCE-over-ADD bias: OC-08's lifecycle-marker tiering should be resolved by *classifying and documenting the existing 4-tier split* (already implicitly correct per OC-08's own "Verified consistent" note), not by adding a new formal instrumentation requirement to lightweight direct-execution skills. Similarly, OC-12's team-implement asymmetry should be documented as intentional, not "fixed" into false symmetry with team-research/team-plan. |

## Priority Tiers (P0-P3): Effort/Impact and REDUCE-vs-ADD

Legend — **Effort**: XS (≤15 min, single line/field), S (<1 hr, single file or small batch), M (1-3 hr, multi-file coordinated change), L (half-day+, careful before/after behavioral parity required). **Impact**: Low/Medium/High/Very High, scoped to blast radius (how many invocations/agents/files are affected). **Flag**: REDUCE (net complexity/surface area goes down or stays flat), ADD (small, narrowly-scoped completion of an already-documented capability), POLICY (decision needed, no default action).

### P0 — Correctness/Robustness (10 findings — fix first, all low-risk/mechanical)

| ID(s) | Effort | Impact | Flag | Why P0 |
|---|---|---|---|---|
| IN-01 | XS | High | REDUCE | Critical severity; safety hook never fires; fix is a single settings.json array entry mirroring an already-wired sibling |
| KS-01 | S | High | REDUCE | Critical; every command silently misses its `always:true` baseline context |
| KS-02 | S | High | REDUCE | Critical; schema is invalid for 74% of real entries today |
| KS-04 | XS | Medium | REDUCE | Actively-referenced content (8+ callers) with broken index metadata |
| KS-09 | XS | Medium-High | REDUCE | A rule in this very repo may silently never auto-apply |
| IN-02 | XS | Medium-High | REDUCE | High severity; literature/zotero task routing has never worked, error silently swallowed |
| IN-04 | S | Medium | REDUCE | High severity; would crash at runtime if `lean` + `--hard` were ever combined |
| IN-05 | XS | Medium | REDUCE | Sourced-library correctness bug; inconsistent with sibling script's contract |
| IN-13 | XS | Medium | REDUCE | Live concurrency bug in a script this repo's own batch-orchestration pattern already exercises |
| IN-03 | S | Medium | REDUCE | The project's own doc-lint (`check-extension-docs.sh`) currently fails (exit 1) |

### P1 — Consistency (20 findings — real gaps, no live breakage, fix soon)

| ID(s) | Effort | Impact | Flag |
|---|---|---|---|
| OC-01 | XS | Medium-High | REDUCE |
| OC-02 | S | Medium | ADD (completes documented capability) |
| OC-03 | XS | Low-Medium | REDUCE |
| OC-06 | S | Low | REDUCE |
| OC-08 | S | Low-Medium | REDUCE |
| OC-10 | M | High | REDUCE (flagship prerequisite) |
| OC-12 | XS | Low | REDUCE |
| OC-15 | XS | Medium | REDUCE |
| OC-19 | S | Medium | REDUCE |
| KS-03 | S | Medium | REDUCE |
| KS-05 | S | High | REDUCE (largest single quantified token win) |
| KS-06 | XS | Low-Medium | REDUCE |
| KS-07 | M | Medium | REDUCE |
| KS-08 | S | Low-Medium | REDUCE |
| KS-10 | S | Medium | ADD (registers existing files) |
| KS-13 | XS | Low | REDUCE |
| KS-15 | S | High (process) | REDUCE |
| IN-07 | XS | Low-Medium | REDUCE |
| IN-08 | S | Medium | ADD (new validation call site) |
| IN-15 | XS | Low | REDUCE |

### P2 — Complexity-Reduction / Performance (13 findings)

| ID(s) | Effort | Impact | Flag |
|---|---|---|---|
| OC-13 (+OC-11) | L | Very High | REDUCE (flagship) |
| OC-14 | S | Medium | REDUCE |
| OC-16 | S | Low-Medium | REDUCE |
| OC-17 | M-L | Medium-High | REDUCE |
| KS-11 | M | Medium | REDUCE |
| KS-12 | S | Low-Medium | REDUCE |
| IN-06 | S-M | Medium | REDUCE |
| IN-09 | XS | Low | REDUCE |
| IN-10 | XS | Low | REDUCE |
| IN-11 | XS | Low | REDUCE |
| IN-12 | XS | Low | ADD (one schema key, parity fix) |
| IN-14 | S | Low-Medium | REDUCE |

### P3 — Nice-to-Have / Policy (7 findings)

| ID(s) | Effort | Impact | Flag |
|---|---|---|---|
| OC-04 | XS-S | Low | REDUCE |
| OC-05 | XS | Low | REDUCE |
| OC-07 | XS | Low | REDUCE |
| OC-09 | XS | Low | REDUCE |
| OC-18 | — (deferred) | Low | POLICY |
| OC-20 | XS (doc decision) | Low | POLICY |
| KS-14 | XS | Very Low | REDUCE |

**Totals**: P0=10, P1=20, P2=13, P3=7 (sum = 50, matches source finding count exactly). **REDUCE=44, ADD=4, POLICY=2.**

## Dependency-Sequenced Roadmap

```
Wave 0 (parallel, no dependencies — all P0 + most low-risk P1/P3 doc fixes)
├─ IN-01, IN-02, IN-03, IN-04, IN-05, IN-13           (infra P0 batch)
├─ KS-01, KS-02, KS-04, KS-09                          (knowledge P0 batch)
├─ OC-01, OC-03, OC-15, OC-05, OC-09                   (dead-code/doc cleanup)
├─ IN-09, IN-10, IN-11, IN-12, IN-15                   (infra polish)
└─ KS-06, KS-13, KS-14, OC-20 (policy note only)

Wave 1 (depends on Wave 0's schema/data fixes landing first)
├─ KS-03  (line-count refresh — cleaner once KS-02's schema is stable)
├─ KS-05  (deprecate 5 orchestration files + trim meta-builder-agent load list)
├─ KS-07  (dead singular-path fixes — 14 files)
├─ KS-08, KS-10, KS-12                                  (reference-hygiene batch)
├─ OC-02, OC-04, OC-06, OC-08, OC-12, OC-16, OC-19       (consistency/doc batch)
└─ IN-14                                                (independent perf fix, any time)

Wave 2 (flagship groundwork — start once Wave 0/1 aren't mid-edit on the same files)
└─ OC-10  (convert 8 duplicated core skills to symlinks)
        │
        ▼  (must land BEFORE Wave 3 so extraction happens once, at the canonical source)
Wave 3 (flagship extraction — depends on Wave 2)
└─ OC-13 + OC-11 + OC-14  (extract shared 11-stage boilerplate + handoff-update section)

Wave 3b (parallel with Wave 3 — independent files, same fix pattern)
├─ OC-17   (split monolithic skills into references/)
├─ KS-11   (split oversized standards/formats docs)
└─ IN-06   (extract shared script helper libs)

Wave 4 (capstone — depends on Wave 0/1 data being correct; gating on stale data first would
        just re-encode the drift)
├─ KS-15  (wire validate-context-index.sh into pre-commit/CI)
├─ IN-08  (wire validate-handoff.sh into skill-orchestrate's read path)
└─ IN-07  (skill-todo calls check-vault-threshold.sh instead of reimplementing)
```

**Rationale for the two hard sequencing constraints**: (1) OC-10 before OC-13 — extracting shared boilerplate while the 8 skill files are still dual-copied means either doing the extraction twice or immediately re-creating the exact drift risk OC-10 exists to eliminate; symlinking first makes every subsequent edit automatically single-source. (2) Wave 4 (the validation-gate capstone) after Wave 0/1 — wiring `validate-context-index.sh` as a hard gate before KS-01/02/03/04/07/10 are fixed would either fail immediately on pre-existing drift or need to ship with the same drift baked in as an accepted baseline; fix the data, then gate against regression.

## Spawn-First Shortlist

Nine ready-to-paste `/task` descriptions, sequenced by the roadmap above. Each preserves all existing functionality per the constraint in every source finding's own "Preserve" note.

**1. [P0] Wire critical safety/routing fixes across scripts and hooks**
```
/task "Fix P0 infrastructure-layer defects found in task 813's audit: (1) add validate-meta-write.sh to settings.json's PostToolUse array (mirroring the already-wired validate-plan-write.sh entry); (2) fix literature extension's keyword_overrides JSON shape to match the nested {task_type:{keywords,aliases}} schema cslib/email already use correctly; (3) resolve lean extension's dangling routing_hard targets (remove entries or author the missing skills); (4) change skill_validate_input()'s two exit 1 calls to return 1 in skill-base.sh, matching command-gate-in.sh's sourced-script contract; (5) raise task-lock.sh's scope-mutex wait timeout to >= SCOPE_MUTEX_STALE_SEC*1000 (~11000ms) so legitimate contention can resolve instead of always timing out first; (6) add task-lock.sh, orchestrator-postflight.sh, and literature-briefing-invoke.sh to extensions/core/manifest.json's provides.scripts, staging the latter two files into extensions/core/scripts/. All six are independent, narrowly-scoped, behavior-preserving fixes (IN-01, IN-02, IN-04, IN-05, IN-13, IN-03 from specs/813)."
```

**2. [P0] Fix knowledge-layer critical index/schema/rule defects**
```
/task "Fix P0 knowledge-layer defects found in task 812's audit: (1) restore repo/project-overview.md (either run /project-overview or copy the generic-template source from extensions/core/context/repo/project-overview.md) so CLAUDE.md's always:true import resolves; (2) update context/index.schema.json's load_when sub-schema to declare task_types (used by 74% of entries) instead of/alongside the vestigial languages field, and formally add the tier/token_cost_estimate properties 7 pattern entries already use; (3) fix the topic-assignment-pattern.md index entry: add domain:'core' and rename description to summary; (4) add YAML paths: frontmatter to rules/neovim-lua.md matching the other 9 rule files' convention, since it may currently never auto-apply. All four preserve existing content/behavior — this is metadata/schema correction only (KS-01, KS-02, KS-04, KS-09 from specs/812)."
```

**3. [P1] Deprecate stale orchestration context and refresh index metadata**
```
/task "Clean up context/index.json metadata staleness found in task 812's audit: (1) set deprecated:true and replacement:<target> on the 5 self-declared-obsolete context/orchestration/{orchestrator,delegation,validation,subagent-validation,sessions}.md index entries, and remove orchestrator.md/delegation.md/validation.md from meta-builder-agent's load_when.agents list (their replacements are already present in the same list) — this removes 2,434 lines of duplicate content from every meta-task dispatch; (2) bulk-refresh the stale line_count field for the 95/155 index entries validate-context-index.sh already identifies as mismatched. Preserve: do not delete any of the 5 deprecated files' content, only their load-wiring and index metadata (KS-05, KS-03 from specs/812)."
```

**4. [P1] Fix dead/stale cross-references and unindexed files in the knowledge layer**
```
/task "Fix reference-hygiene defects found in task 812's audit: (1) repo-wide search-replace .claude/agent/ -> .claude/agents/ and .claude/command/ -> .claude/commands/ across the 14 affected files, with manual rewording (not just path fixes) of the 3 references describing the now-nonexistent agents/subagents/{git-workflow-manager,status-sync-manager}.md architecture, since that functionality is now direct-execution skills; (2) add context/index.json entries for the 6 unindexed files, prioritizing file-footprint-overlap.md and git-staging-scope.md (both load-bearing per direct cross-reference) and adhoc-navigation-directive.md (named directly in CLAUDE.md); (3) parameterize the 6 hardcoded .opencode/ paths in extensions/core/context/formats/return-metadata-file.md so both .claude/ and .opencode/ sync targets resolve correctly; (4) point context-loading-best-practices.md and frontmatter.md at the real validate-context-index.sh instead of 3 scripts that were never built, and fix that script's own Warnings:0 counter bug. Preserve: no content changes beyond path corrections and index registration (KS-07, KS-10, KS-06, KS-08 from specs/812)."
```

**5. [P1] Clean up dead commands-layer artifacts and doc mislabels**
```
/task "Fix commands/skills-layer dead-code and doc-accuracy defects found in task 811's audit: (1) rewrite commands/README.md to state that .claude/commands/ and .opencode/commands/ are two independently-versioned, actively-maintained command sets for two different tools (not a legacy/active pair) — remove the 'DEPRECATED' status line; (2) after a final repo-wide grep confirms zero live references (including .opencode/), delete the orphaned skill-orchestrator/SKILL.md, its stray byte-identical SKILL.md.archived, and the broken /zotero command + skill-zotero symlinks (which point at a directory that no longer exists); (3) verify no command/routing table routes to skill-pr-implementation independently of skill-pr-review-implementation's fallback path, and retire it if confirmed redundant. Preserve: /literature --search and all literature-extension Zotero functionality; the legacy no-sources PR-prep path via skill-pr-review-implementation's fallback (OC-01, OC-03, OC-15, OC-16 from specs/811)."
```

**6. [P2, flagship 1 of 2] Convert duplicated core skills to symlinks**
```
/task "Eliminate the proven skill-content drift vector found in task 811's audit (OC-10): convert the 8 physically-duplicated core skill file pairs (skill-researcher, skill-planner, skill-implementer, skill-orchestrate, each standard + -hard variant) from separate copies in .claude/skills/ and .claude/extensions/core/skills/ into symlinks, matching the pattern already proven correct for the cslib/literature/zotero extension skills. This is a pure mechanics change: every consumer that reads .claude/skills/* must see byte-identical content and identical resolved paths before and after. This task is a prerequisite for the larger boilerplate-extraction task (do not start the extraction task until this one is merged, so the shared-stage extraction is authored once at the canonical source, not twice)."
```

**7. [P2, flagship 2 of 2] Extract shared skill boilerplate and handoff-update sections**
```
/task "Extract the ~5,400 lines of near-identical 11-stage boilerplate skeleton shared by skill-researcher, skill-planner, skill-implementer, skill-reviser, and their -hard variants (8 files) into one or two referenced pattern files under .claude/context/patterns/ (split by concern: metadata I/O, git/cleanup, memory/lit injection), leaving only each skill's task-type-specific delta inline. This also resolves the -hard variants' manual-mirror drift risk (OC-11) as a structural side effect. Separately, extract the verbatim-duplicated 'Progressive Handoff Update' section from general-implementation-agent.md, neovim-implementation-agent.md, nix-implementation-agent.md (and cslib-implementation-agent.md if it matches) into a referenced pattern file, leaving each agent only its domain-specific example. Acceptance criterion: every skill/agent must produce byte-identical stage effects (same jq commands, same marker paths, same commit message format, same handoff file paths/format) after extraction — this is a pure refactor. Depends on the symlink-conversion task (OC-10) landing first (OC-13, OC-11, OC-14 from specs/811)."
```

**8. [P2] Progressive-disclosure splits for oversized skills, docs, and scripts**
```
/task "Apply progressive disclosure (per Anthropic's Agent Skills guidance: split large SKILL.md bodies into references/*.md loaded on demand) to the largest monolithic skills found in task 811's audit — skill-memory (2,482 ln), skill-literature (1,781 ln), skill-todo (821 ln), skill-fix-it (620 ln) — extracting detailed sub-workflows into references/ while preserving identical behavior for every invocation path. Apply the same split to the two most over-budget context/ docs found in task 812's audit: context/standards/error-handling.md (1056 ln vs 700-line budget) and context/formats/command-structure.md (965 ln vs 600-line budget), reorganizing into multiple files along logical section boundaries (originals may become index/overview stubs) without dropping content. Extract the duplicated format_size()/age-computation helpers (claude-cleanup.sh, claude-project-cleanup.sh) and the colors+counters preamble (reimplemented in 5+ scripts) found in task 813's audit into small shared cleanup-lib.sh/report-lib.sh files. Preserve: identical behavior and output for every listed skill/doc/script after reorganization (OC-17, KS-11, IN-06)."
```

**9. [P1, capstone] Wire the config-integrity validation gate**
```
/task "Close the 'documented-but-unwired validation' gap found across all three layer audits (this is task 814's synthesis Cross-Cutting Thread 4): (1) wire validate-context-index.sh into a pre-commit hook or CI check scoped to .claude/context/** changes, so index.json drift (stale line counts, schema violations, unindexed files) cannot silently reaccumulate; (2) wire validate-handoff.sh to run immediately before each .orchestrator-handoff.json read in skill-orchestrate's and skill-orchestrate-hard's state-machine loops, treating a nonzero exit the same as a missing handoff (existing documented failure path: mark task in failed_tasks, skip); (3) have skill-todo's vault-threshold check call check-vault-threshold.sh and branch on its exit code instead of re-deriving the VAULT_THRESHOLD=1000 logic inline. Run this task after the P0/P1 data-fix tasks above have landed, since gating on still-broken data would either fail immediately or bake the drift in as an accepted baseline (KS-15, IN-08, IN-07 from specs/812 and specs/813)."
```

## Decisions

- Findings were tiered using each finding's own reported severity + category fields (mapped consistently: robustness-risk+critical/high -> P0, doc-accuracy/consistency-gap -> P1, complexity-reduction/performance-cost -> P2, informational/policy -> P3), rather than re-litigating severity from scratch — this preserves the source audits' domain judgment while making cross-audit comparisons possible.
- The task brief's three hypothesized cross-layer threads were all confirmed with source evidence and are presented as CF-01 through CF-05 above. A fourth thread ("documented-but-unwired capability," CF-06 through CF-09) was independently surfaced by this synthesis and is flagged as the single most valuable original finding in this report, since it reframes what looked like 4+ unrelated defects (a hook, a manifest field, an index flag, two unused validators) as one recurring architectural failure mode with one class of fix.
- OC-10 (symlink conversion) is treated as a hard prerequisite for OC-13 (boilerplate extraction), not merely a "nice to do first" — doing the extraction before the symlink conversion would require either double work or immediately reintroducing the drift OC-10 exists to close.
- OC-20 and OC-18 are recorded as POLICY-only: this report does not recommend a default action for either, consistent with both source findings' own explicit framing ("requests a documented decision, not a default action" / "optional... not urgent given current scale").
- No finding was excluded from tiering, including the seemingly-informational ones (OC-05, OC-07, KS-14) — the constraint to preserve full traceability from source audit to roadmap outweighed the temptation to silently drop low-value items.

## Risks & Mitigations

- **Risk**: Bundling multiple P0 fixes into single spawn tasks (shortlist items 1-2) could make a single task larger than intended if any one sub-fix turns out to have hidden complexity (e.g., IN-04's lean routing_hard might require authoring real skills rather than just removing entries). **Mitigation**: each shortlist task description explicitly offers the "remove/simplify" option as the default resolution path per the source finding's own multiple-option recommendation, so the implementer isn't forced into the most expensive option.
- **Risk**: Wave 2/3's flagship sequencing (OC-10 then OC-13) creates a hard dependency that could stall the highest-value complexity win if OC-10 is deprioritized. **Mitigation**: OC-10 alone is a mechanical, low-risk, well-precedented change (the exact symlink pattern already exists and works for 3 other extensions) — it should be scheduled early precisely because it unblocks the largest downstream win.
- **Risk**: Wave 4's validation-gate capstone, if implemented before Wave 0/1's data fixes land, would either fail immediately (blocking all future `.claude/context/` commits) or need to special-case the pre-existing drift as an accepted baseline, defeating its purpose. **Mitigation**: explicitly sequenced last among the P0/P1-adjacent work in both the roadmap and the shortlist's task 9 description.
- **Risk**: The "preserve all functionality" constraint could be read as license to defer everything indefinitely. **Mitigation**: every tier assignment and shortlist task explicitly states what must remain byte-identical/behaviorally-unchanged, so "preserve" is scoped to output/behavior parity, not to avoiding the fix.

## Context Extension Recommendations

- **Topic**: Cross-layer synthesis findings register format. **Gap**: no existing document defines how to merge findings from parallel layer-scoped audits into a single register with cross-reference IDs. **Recommendation**: if multi-audit synthesis becomes a recurring pattern (this is the first instance), consider adding a short `.claude/context/patterns/audit-synthesis-format.md` documenting the CF-ID / source-ID-citation convention used in this report, so future syntheses don't need to invent the format from scratch.
- **Topic**: "Documented-but-unwired capability" as a named anti-pattern. **Gap**: no document in `.claude/context/` or `.claude/docs/` names this failure mode explicitly, despite it recurring independently across all three audited layers. **Recommendation**: once the P0/P1 fixes in this report's Wave 0/1 land, consider adding a short section (to `context/patterns/context-exhaustion-detection.md`'s sibling docs or a new `context/patterns/wiring-verification.md`) naming the pattern and pointing at `validate-context-index.sh`/`validate-handoff.sh`/`check-extension-docs.sh` as the existing tools that catch instances of it — this is exactly the kind of "adadptive memory that filters outdated information" the July 2026 context-engineering research recommends institutionalizing.

## Appendix

### Search queries used
- "Claude Code Agent Skills progressive disclosure best practices 2026 avoid duplication shared templates"
- "multi-agent orchestration system design patterns 2026 config drift validation CI gates"
- "agent system \"context rot\" mitigation stale configuration self-healing index validation 2026"

### References
- [Skill authoring best practices - Claude Platform Docs](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [Equipping agents for the real world with Agent Skills - Anthropic](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)
- [Stop Bloating Your CLAUDE.md: Progressive Disclosure for AI Coding Tools - alexop.dev](https://alexop.dev/posts/stop-bloating-your-claude-md-progressive-disclosure-ai-coding-tools/)
- [6 Multi-Agent Orchestration Patterns for Production (2026) - Beam.ai](https://beam.ai/agentic-insights/multi-agent-orchestration-patterns-production)
- [Multi-Agent Orchestration Patterns: Pattern Language 2026 - Digital Applied](https://www.digitalapplied.com/blog/multi-agent-orchestration-patterns-producer-consumer)
- [Multi-Agent AI Orchestration Patterns: Production Guide - Lushbinary](https://lushbinary.com/blog/multi-agent-orchestration-patterns-supervisor-swarm-pipeline-router-guide/)
- [Beyond Task Success: An Evidence-Synthesis Framework for Evaluating, Governing, and Orchestrating Agentic AI (arXiv 2604.19818)](https://arxiv.org/pdf/2604.19818)
- [Self-Healing Agentic Orchestrators for Reliable Tool-Augmented Large Language Model Systems (arXiv 2606.01416)](https://arxiv.org/html/2606.01416v1)
- [Context Engineering AI: How To Build Smarter LLM Agents In 2026 - mem0.ai](https://mem0.ai/blog/context-engineering-ai-agents-guide)

### Source finding-count summary (for cross-check against sibling reports)
- Task 811 (orchestration core): 20 findings — 4 high, 9 medium, 7 low
- Task 812 (knowledge & standards): 15 findings — 2 critical, 5 high, 6 medium, 2 low
- Task 813 (infrastructure): 15 findings — 1 critical, 3 high, 4 medium, 7 low
- **Total**: 50 findings, all accounted for in this synthesis's tier assignment (P0=10, P1=20, P2=13, P3=7)
