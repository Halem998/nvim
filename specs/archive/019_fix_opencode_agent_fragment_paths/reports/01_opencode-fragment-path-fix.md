# Research Report: Fix opencode agent-fragment path resolution and validator fail-fast

- **Task**: 19 - Fix opencode agent-fragment path resolution and validator fail-fast
- **Started**: 2026-08-11T00:00:00Z
- **Completed**: 2026-08-11T00:00:00Z
- **Effort**: 3h (research phase)
- **Dependencies**: None
- **Sources/Inputs**:
  - `lua/neotex/plugins/ai/shared/extensions/merge.lua` (validator, generator, config-aware call chain)
  - `lua/neotex/plugins/ai/shared/extensions/config.lua`, `loader.lua`, `verify.lua`, `init.lua`
  - All 12 `agent-system/extensions/*/opencode-agents.json` fragments in file_scope
  - Corresponding `manifest.json` (`provides.agents`) and `agents/*.md` source files for each extension
  - Deployed `.claude/agents/` and `.opencode/agent/subagents/` directories in this repo
  - `.claude-extensions.json` (this repo's active-extension state)
  - Archived reports/plans/summaries: prior investigations into the same opencode.json / agent
    file-reference subsystem (Website-repo path-mismatch investigation; the design report that
    proposed the `opencode_json` merge target; the implementation summary that closed later gaps
    in that mechanism)
  - `.opencode/extensions/` (the separately-tracked, non-canonical mirror tree referenced by the
    task's own "ALSO NOTE" pointer) for divergence comparison only — no edits made there
- **Artifacts**: this report
- **Standards**: report-format.md, return-metadata-file.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Executive Summary

- All three recorded root causes re-confirmed to still hold in the source store, with one minor
  count correction: **11 of 12** fragments (not 10) use `{file:.opencode/agent/subagents/...}`;
  only `lean` uses the third, also-broken convention.
- **Recommendation: Option (a) — repoint every fragment's `{file:...}` reference at
  `.claude/agents/<agent>.md`**, using the exact basename each extension's own
  `manifest.json` `provides.agents` array already declares. Verified basename-for-basename
  against all 12 manifests: 10 extensions match with a directory-only fix, `lean` matches with a
  directory-only fix, and `present` additionally needs its `slides` entry's basename corrected
  (its `{file:...}` value, and optionally its agent key) to match the real deployed file.
- This works with **zero new deploy machinery** because `.claude/agents/` is already populated,
  for every currently-active extension, by the exact same reload event
  (`manager.load`/`manager.unload` in `init.lua`) that calls `generate_opencode_json` — and that
  population (`copy_category("agents", ...)`) runs strictly before the opencode-generation call
  in both call sites, so ordering is safe.
- **Explicitly not recommending** (b) a new deploy step for `.opencode/agent/subagents/`, or (c)
  gating opencode fragment processing off while dormant. Reasoning for both rejections below.
- **Important caveat surfaced by this research, not in the original task framing**: `.claude/agents/*.md`
  files are Claude-Code-flavored (YAML `model:` frontmatter, internal `@.claude/context/...`
  self-references) and are byte-identical to their `agent-system/extensions/<ext>/agents/*.md`
  sources — there is no OpenCode-flavored equivalent content anywhere in the source store for the
  ten non-core, non-lean extensions. Repointing at `.claude/agents/` silences the validator and
  is the right move now, but it does not produce content that is semantically correct for actual
  OpenCode consumption. That gap is pre-existing (it is not introduced or worsened by this fix)
  and is out of this task's scope; it should be named explicitly when OpenCode work resumes, not
  silently assumed solved.
- **Verdict on fail-fast behavior**: change it. Recommend two independent, complementary
  changes to `merge.lua`: (1) `validate_opencode_fragment` should collect and report *all*
  missing references in one fragment, not return on the first miss; (2)
  `generate_opencode_json` should degrade per-agent-key rather than per-fragment — merge every
  agent whose own `{file:...}` resolves, and only skip the individual key(s) that don't, rather
  than discarding an entire extension's agent set for one bad reference.
- **Noise elimination estimate for the sibling task**: after this fix, essentially 100% of the
  ~60 reported warning lines should disappear under normal operation, because every one of the 30
  agent-key file references across the 12 fragments becomes resolvable. The sibling task's scope
  should narrow to (i) confirming zero residual noise, and (ii) deciding whether to implement the
  fail-fast → report-all / per-key-degradation change recommended above (which itself doubles as
  the noise-quality improvement that task was framed around) — not to re-diagnosing or re-fixing
  the path/stale-name bugs, which are fully addressed here.
- **Interaction with the future `.opencode/extensions/` sync/drift task**: that mirror tree has
  already diverged from `agent-system/extensions/` for at least `nix` and `present`, and in a
  way that is *more correct* than the canonical source for those two — the mirror's `present`
  fragment already uses the key `slides-research` (matching its manifest) instead of the stale
  `slides`, and `nix`'s mirror fragment uses a self-contained
  `{file:.opencode/extensions/nix/agents/<name>.md}` convention instead of the shared
  `.opencode/agent/subagents/` path. A naive one-directional "copy canonical → mirror" sync would
  regress both of those already-fixed spots. This task does not touch `.opencode/extensions/`
  (out of file_scope and out of the source-store boundary), but the sync task needs this fact
  before choosing a sync direction.

## Context & Scope

Task 19 asks for a decision — not an implementation — on how to stop `opencode.json` generation
from silently dropping 18 of 33 agents across 12 extension fragments, and on whether the
validator's fail-fast, whole-fragment-discarding failure mode should change. The `.opencode/`
tree is not in active use in any project today; the cost of the bug is latent (it resurfaces the
moment OpenCode is picked back up) rather than active. This report re-confirms the task's
recorded evidence against the current source tree, traces the full call chain that produces the
warning, and evaluates the three named options plus a fourth architectural wrinkle the research
surfaced (a divergent, partially-already-fixed mirror tree) that materially affects how "done"
this fix can be.

## Findings

### Codebase Patterns

**The validator and its caller (`lua/neotex/plugins/ai/shared/extensions/merge.lua`)**

- `M.validate_opencode_fragment` (merge.lua:887-908) iterates an extension's parsed
  `opencode-agents.json` with `pairs()` (nondeterministic order) and, for each `agent_def.prompt`
  matching `^%{file:(.+)%}$`, resolves `project_dir .. "/" .. file_path` and checks
  `vim.fn.filereadable`. **It `return`s `false` on the first unreadable path** — it never checks
  the remaining agents in the same fragment.
- `M.generate_opencode_json` (merge.lua:922-1032) calls the validator once per fragment. On
  failure it discards the **entire fragment** (no agents from that extension are merged) and
  emits one `vim.notify(WARN)` line naming only the single agent that happened to trip the
  first-miss check. Because `pairs()` order is nondeterministic, repeated reloads report a
  different "first" agent, which is why the noise looks inconsistent/repetitive without ever
  revealing the true (larger) count.
- Ordering confirmed safe for the repoint fix: `copy_category("agents", ...)` runs inside the
  per-extension load loop (init.lua ~467) and `generate_opencode_json` runs after the loop, once
  state is written (init.lua ~643, and again at ~824 for the unload path). `.claude/agents/` is
  therefore always fully populated for every *currently active* extension before
  `generate_opencode_json` reads it.
- `generate_opencode_json` is a no-op unless `opencode.json.managed` exists in `project_dir`
  (Step 1.2, merge.lua ~931-933) — confirmed in this repo directly: neither `opencode.json` nor
  its `.managed` sidecar exists here, so the whole code path is currently inert in this
  particular repo. The reported noise originates in some other consuming repo that has opted
  into managed `opencode.json` generation while `.opencode/` itself sits unused.

**Root Cause 1 re-confirmed, with a count correction**

`grep -rn "opencode/agent" lua/` still returns exactly one hit, and it is the test fixture at
`lua/neotex/plugins/ai/claude/commands/picker/operations/sync_spec.lua:100`. No deploy/copy path
in `lua/` populates a project's `.opencode/agent/subagents/`. Extracting every `{file:...}` value
from the 12 in-scope fragments:

| Fragment | Path convention used |
|---|---|
| epidemiology, filetypes, formal, latex, nix, nvim, present, python, typst, web, z3 (11 total) | `.opencode/agent/subagents/<name>.md` |
| lean (1 total) | `.claude/extensions/lean/agents/<name>.md` |

The task text says "ten of twelve"; the correct count is **eleven of twelve** use the
`.opencode/agent/subagents/` convention. This doesn't change the diagnosis, only the tally, and
is noted so the acceptance-criteria bookkeeping stays accurate.

**Root Cause 2 re-confirmed**: `lean`'s fragment references
`{file:.claude/extensions/lean/agents/lean-research-agent.md}` and the implementation variant —
a directory that exists nowhere in this repo's filesystem. `agent-system/extensions/lean/agents/lean-research-agent.md`
and `lean-implementation-agent.md` do exist as source files, and would deploy to
`.claude/agents/lean-research-agent.md` / `.claude/agents/lean-implementation-agent.md` when the
`lean` extension is active (confirmed via the same `provides.agents` → `copy_category` mechanism
verified for every other extension below) — the fragment's directory string is simply wrong.

**Root Cause 3 re-confirmed, and independently corroborated by a second, unrelated checker**:
`present`'s fragment key `slides` points at `{file:...slides-agent.md}`, which exists nowhere in
`agent-system/extensions/`. The real file is `agent-system/extensions/present/agents/slides-research-agent.md`,
and it is listed in `present`'s `manifest.json` `provides.agents` as `slides-research-agent.md`.
Separately, `lua/neotex/plugins/ai/shared/extensions/verify.lua`'s `verify_opencode_json_merge`
(added years after the original fragment mechanism, wired into `verify_extension`) already
performs an independent, path-blind symmetric-difference check between fragment agent *keys* and
manifest-filename-derived names, and — because it strips the `-agent.md` suffix from every
manifest filename and compares key sets — it already flags `slides` (in the fragment) as
"missing from manifest" and `slides-research` (among others) as "missing from fragment", as a
non-fatal warning. This is a second, independent signal confirming the same stale-rename bug via
a completely different code path (name-set comparison, never inspects `{file:...}` contents),
which is reassuring corroboration rather than a second bug.

**Verification that Option (a) is airtight for all 12 fragments** — cross-checked every
fragment's `{file:...}` basename against its own extension's `manifest.json` `provides.agents`
array:

| Extension | Basenames match manifest? | Fix needed beyond directory swap |
|---|---|---|
| epidemiology, filetypes, formal, latex, nix, nvim, python, typst, web, z3 (10 total) | Yes, exact match | None |
| lean | Yes, exact match (manifest's 2 extra hard-mode agents are simply unreferenced by the fragment, which is fine) | None |
| present | No — fragment says `slides`, manifest lists `slides-research-agent.md` | Fix the `slides` entry's `{file:...}` basename (and, recommended, rename the key to `slides-research` to also clear the `verify.lua` key-parity warning noted above — this is a same-file edit, no new files touched, and safe now precisely because `.opencode/` has no live external callers depending on the exact key name today) |

Every basename this task needs to point at `.claude/agents/` was independently confirmed to
exist as a real, deployed file under that mechanism (spot-checked directly for `nix-research`,
`nix-implementation`, `neovim-research`, `neovim-implementation` via the currently-deployed
`.claude/agents/` in this repo, and confirmed structurally for every other extension via the
`provides.agents` → `copy_category("agents", ...)` → flat `.claude/agents/<filename>` copy
mechanism in `loader.lua`/`init.lua`, which does not restructure or rename files).

**The content-mismatch caveat (new finding, not in the original task text)**

`agent-system/extensions/nix/agents/nix-research-agent.md` is byte-identical
(`diff` exit 0) to the currently-deployed `.claude/agents/nix-research-agent.md`. It carries
Claude-Code-specific YAML frontmatter (`model: sonnet`) and internal `@.claude/context/...`
self-references throughout its body. The **only** genuinely OpenCode-flavored agent bodies
anywhere in this repo are the 9 legacy files under `.opencode/agent/subagents/` (all core-only:
`general-research-agent.md`, `planner-agent.md`, etc.), which predate the current
manifest-driven extension architecture and use `@.opencode/context/...` self-references and no
`model:` frontmatter — matching the `opencode.json` template's own tool-name and prompt
conventions. **No extension in `agent-system/extensions/` has ever had an OpenCode-flavored
agent body authored for it.** Repointing `{file:...}` at `.claude/agents/` fixes file-existence
(silences the validator, restores all 18 currently-dropped agents to the generated
`opencode.json`) but the resulting OpenCode subagent prompt will literally contain unresolved
`@.claude/context/...` references and an inert `model:` field when actually invoked under
OpenCode. This is a pre-existing gap — it exists today regardless of which path convention wins,
because the content was only ever written once, for Claude Code — and is explicitly out of this
task's scope to close. It should be named as a known, deliberate limitation of the recommended
fix, not silently treated as "OpenCode agents will now work end-to-end."

**The two-profile architecture (new finding)**

`lua/neotex/plugins/ai/shared/extensions/config.lua` defines two parameterized presets:
`M.claude()` (`base_dir=".claude"`, `agents_subdir="agents"`, source =
`agent-system/extensions`) and `M.opencode()` (`base_dir=".opencode"`,
`agents_subdir="agent/subagents"`, source = `.opencode/extensions` — a *global*, absolute path
under `~/.config/nvim`, not project-relative). The original 2026-03 design for the
`opencode_json` merge target (recorded in an archived research report) explicitly intended
`.opencode/agent/subagents/` to be populated by "the core agent system loader" under the
OpenCode profile — i.e., Option (b) was always the notionally "correct" long-term architecture,
not an afterthought.

However: `validate_opencode_fragment`'s `abs_path = project_dir .. "/" .. file_path` is a **literal
string resolution**, independent of which profile (`config.claude()` vs `config.opencode()`)
triggered the call. This repo's `file_scope` (`agent-system/extensions/*/opencode-agents.json`)
confirms the reported noise comes from the **Claude-profile** reload path — the same event that
already deploys `.claude/agents/` but never touches `.opencode/agent/subagents/` under any
profile, unless the OpenCode-profile loader is *also* separately exercised in that project. Since
`.opencode/` is dormant by the task's own framing, that second exercise isn't happening, so
Option (b)'s originally-intended deploy step, even if it existed, would not by itself explain why
today's Claude-triggered reload is noisy — a *second*, Claude-profile-side deploy step (writing
agent files into `.opencode/agent/subagents/` as a side effect of a Claude reload) would be
needed to close that gap under Option (b), which is more new code than Option (a) requires, for
content (per the caveat above) that would still be Claude-flavored either way.

**The `.opencode/extensions/` mirror has already partially fixed this, independently and
inconsistently (new finding — read-only comparison, no edits made)**

`.opencode/extensions/` is a second, git-tracked (not gitignored) tree of the same 17 extensions,
predating the migration that established `agent-system/extensions/` as canonical (visible in git
history: the mirror's `nix/opencode-agents.json` was last touched by an earlier "implementation"
commit; the canonical copy's most recent touch is a later "relocate store and repoint canonical
default" commit). Comparing fragment content:

- `nix`: the mirror already uses a **third** convention entirely —
  `{file:.opencode/extensions/nix/agents/nix-research-agent.md}` — a self-contained,
  per-extension path that resolves against the extension's own directory rather than a shared
  flat namespace. The referenced files exist. This convention is not used anywhere else in the
  mirror (checked latex, typst, formal, z3, web, lean, epidemiology, filetypes — all still use
  the shared `.opencode/agent/subagents/` convention there too), so it reads as an isolated
  experiment on one extension, not an established alternate direction.
- `present`: the mirror's fragment already has 9 correctly-named keys including
  `slides-research` (matching its manifest) — the stale `slides` key does not exist in the
  mirror at all.
- `lean`: the mirror correctly uses `.opencode/agent/subagents/lean-*-agent.md` — the canonical
  copy's `.claude/extensions/lean/agents/...` bug (Root Cause 2) is specific to
  `agent-system/extensions/`; the mirror never had it.

None of these mirror files were edited as part of this research (out of `file_scope` and outside
the source-store boundary for this task). This is reported purely as information a future sync
task needs: a one-directional canonical→mirror sync would silently regress content in the
mirror that is demonstrably more correct today for `nix`, `present`, and `lean`.

### External Resources

Not applicable — this is an internal architecture question with no external documentation
dependency. OpenCode's own `{file:...}` config-reference mechanism was already characterized
from this repo's own template (`.opencode/templates/opencode.json`) and from a prior archived
investigation of a real OpenCode startup failure caused by exactly this class of path bug (see
Sources/Inputs); no new external lookup was needed or performed.

### Recommendations

1. **Repoint all 12 fragments' `{file:...}` values from `.opencode/agent/subagents/<name>.md` /
   `.claude/extensions/lean/agents/<name>.md` to `.claude/agents/<name>.md`**, using each
   extension's own `manifest.json` `provides.agents` basenames as the source of truth for the
   exact filename. This is a mechanical, low-risk edit across exactly the 12 files already in
   `file_scope`.
2. **For `present` specifically**, also correct the `slides` entry's target basename to
   `slides-research-agent.md`, and rename the agent key itself from `slides` to
   `slides-research` to also clear the independent `verify.lua` key-name-parity warning — safe
   now because there is no live external OpenCode caller depending on the `slides` key today.
3. **Change `validate_opencode_fragment` to collect and return every missing reference in a
   fragment**, not just the first, so any future regression reports its full, deterministic
   extent in one line instead of a single nondeterministic name per reload.
4. **Change `generate_opencode_json`'s degrade granularity from per-fragment to per-agent-key**:
   merge every agent in a fragment whose own `{file:...}` resolves; skip only the individual key
   whose reference is missing. This directly prevents the amplifier behavior recorded in the task
   (one bad key silently dropping an entire extension's agent set) from recurring for any future
   typo or stale rename.
5. **Do not** attempt to reconcile `agent-system/extensions/*/opencode-agents.json` with the
   `.opencode/extensions/` mirror as part of this task — that tree is out of `file_scope`, is
   outside this task's source-store boundary, and (per the finding above) needs a real
   reconciliation decision, not a copy, once the dedicated sync/drift task takes it up.

## Decisions

- **Path convention: Option (a) — repoint at `.claude/agents/<agent>.md`.** Chosen over (b)
  "add a deploy step for `.opencode/agent/subagents/`" because (b) requires new, currently
  nonexistent loader code for a directory only reachable today via a dormant second profile, and
  — per the content-mismatch caveat — would not produce more functionally-correct OpenCode
  content than (a) anyway, since the only source material available for either target is
  identically Claude-flavored. (b) is not wrong in the abstract (it matches the original 2026-03
  design intent for the OpenCode profile), but building it now, before anyone commits to
  authoring genuine OpenCode-native agent bodies, is premature investment in a currently-dormant
  subsystem. Revisit (b) specifically when OpenCode usage resumes for real and someone is ready to
  write OpenCode-flavored content — at that point the self-contained
  `.opencode/extensions/<ext>/agents/` convention already piloted for `nix` in the mirror is
  worth considering over the shared `agent/subagents/` flat namespace.
- **Rejected: Option (c) — gate opencode fragment processing off entirely.** Rejected because it
  suppresses the symptom without fixing the underlying path bugs; the 18-agent silent-drop defect
  would remain latent and would resurface immediately, now hidden behind an even quieter gate,
  the moment `.opencode/` returns to use — exactly the outcome the task frames as unacceptable.
  Silencing belongs to the sibling task's narrower, now-mostly-moot scope (see below), not to a
  blanket processing gate here.
- **Fail-fast verdict: change it**, per Recommendations 3 and 4 above — report all missing
  references per fragment, and degrade per-agent-key rather than per-fragment. This is a small,
  bounded, in-scope (`merge.lua` is in `file_scope`) resilience improvement independent of the
  path fix, defending against the *next* stale rename rather than only today's three.

## Risks & Mitigations

- **Risk**: renaming `present`'s `slides` key could break an external OpenCode invocation that
  already targets `--agent slides`. **Mitigation**: `.opencode/` is confirmed dormant
  project-wide (no `opencode.json`/`.managed` marker in this repo, and the task states no current
  reliance); safe to rename now, before real usage resumes.
- **Risk**: the content-mismatch caveat could be read as "this fix doesn't really work."
  **Mitigation**: it does work for the task's actual acceptance criterion (validator noise and
  silent agent-dropping stop) — the caveat is about a separate, pre-existing content-authoring
  gap that this task was never scoped to close, and should be flagged rather than either silently
  ignored or used to block the (still net-positive) path fix.
- **Risk**: a future sync of `.opencode/extensions/` could regress this fix by overwriting
  `agent-system/extensions/` with mirror content, or vice versa lose the mirror's already-better
  `present`/`nix`/`lean` state. **Mitigation**: flagged explicitly above for the dedicated sync
  task; no action taken on the mirror in this task.

## Appendix

- Fragment path-convention extraction: `grep -o '{file:[^}]*}' agent-system/extensions/*/opencode-agents.json`
- Manifest cross-check: per-extension `diff` of fragment basenames vs. `jq -r '.provides.agents[]?'`
  output from each `manifest.json`.
- Deploy-chain confirmation: `lua/neotex/plugins/ai/shared/extensions/init.lua` lines ~467
  (`copy_category("agents", ...)`), ~634-646 and ~815-826 (`generate_claudemd` /
  `generate_opencode_json` call sites, load and unload paths respectively).
- Validator/generator source: `lua/neotex/plugins/ai/shared/extensions/merge.lua` lines 887-908
  (`validate_opencode_fragment`) and 922-1032 (`generate_opencode_json`).
- Two-profile config: `lua/neotex/plugins/ai/shared/extensions/config.lua` `M.claude()` /
  `M.opencode()`.
- Independent key-parity checker: `lua/neotex/plugins/ai/shared/extensions/verify.lua`
  `verify_opencode_json_merge` (~line 497 onward).
- Historical design/precedent (archived reports, read-only, referenced by content not task
  number per this repo's deliverable convention): the report that first diagnosed a real
  OpenCode startup failure caused by exactly this class of stale path reference in a consuming
  repo; the design report that proposed the `opencode_json` merge target and named
  `.opencode/agent/subagents/` as the intended deploy target; the implementation summary that
  later closed four related gaps in that mechanism while explicitly marking `{file:...}`
  resolution itself as a non-goal at that time.
- Mirror divergence check (read-only): `diff` of `.opencode/extensions/{nix,present}/opencode-agents.json`
  against their `agent-system/extensions/` counterparts; `git log --oneline` on both paths to
  establish edit-order relative to the store-relocation commit.
