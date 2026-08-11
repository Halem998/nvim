# Implementation Plan: MCP Registration/Permission Ownership Boundary

- **Task**: 23 - Document MCP registration vs permission ownership boundary; reconcile lean-lsp three-way duplication
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/023_document_mcp_registration_ownership_boundary/reports/01_mcp-registration-ownership-boundary.md
- **Artifacts**: plans/01_mcp-ownership-boundary.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research established empirically that `mcpServers` keys in `settings.json`/`settings.local.json`
are inert -- only user-scope `~/.claude.json` registers an MCP server -- and that permission
grants are a fully independent axis that lives in the settings files. This plan writes that
two-axis ownership decision into one canonical source-store document, corrects the four existing
docs that currently assert the wrong registration path, and collapses the lean-lsp three-way
duplication down to one registration mechanism plus one permission grant. Definition of done: a
future extension author reading `context/patterns/mcp-server-ownership.md` alone knows where to
declare a new server and its permissions, every doc that previously said otherwise now points
there, and lean-lsp is registered/permitted in exactly one place each.

All edits target `agent-system/extensions/core/**` and `agent-system/extensions/lean/**` (plus one
file in `agent-system/extensions/nix/**`). No file under any deployed `.claude/**` tree is edited
-- that tree is gitignored, disposable, and regenerated from the source store, so hand-edits there
are silently wiped.

### Research Integration

The plan is built directly on the report's Decisions 1-5:

- **Decision 1 (registration owner)**: user-scope `~/.claude.json` only, written either by a
  host-level activation block (static servers) or by a `core/scripts/` setup script (servers
  needing per-project computed args). Extension `settings-fragment.json` files must not declare
  `mcpServers`.
- **Decision 2 (permission owner)**: domain-specific `mcp__{server}__*` grants belong in that
  extension's `settings-fragment.json`; core's `root-files/settings.json` carries only
  domain-agnostic grants.
- **Decision 3 (composition)**: registration and permission are independent axes; both must hold
  for prompt-free tool use.
- **Decision 4 (lean-lsp)**: remove the domain-specific wildcard from core, replace lean's drifted
  21-tool enumeration with a single wildcard, delete the dead `mcpServers` block, keep
  `setup-lean-mcp.sh` as sole registration path.
- **Decision 5 (doc fixes)**: new canonical pattern file plus corrections to
  `permission-configuration.md`, `extension-system.md`, `creating-extensions.md`, the lean and nix
  READMEs, and a cross-link from `mcp-tool-recovery.md`.

The report's nuance on the subagent claim is also carried in: the operative rule (register in user
scope) is correct, but the causal mechanism is an interactive-approval deadlock for
project-scoped `.mcp.json` servers, not a categorical access wall. Phase 6 restates
`setup-lean-mcp.sh`'s header accordingly.

The report's systemic finding -- the same dead `mcpServers` pattern in nix, memory, filetypes,
founder, and epidemiology -- is deliberately **named but not fixed** here. Registering those
servers requires host-level or home-manager changes a documentation task cannot verify or perform.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and no roadmap consultation was
performed; no ROADMAP.md phases are included.

## Goals & Non-Goals

**Goals**:
- Record the registration-vs-permission ownership decision in exactly one canonical source-store
  document under `agent-system/extensions/core/context/patterns/`.
- Register that document in core's `index-entries.json` so it is discoverable and passes the
  index-truth doc-lint gate.
- Correct every existing source-store assertion that a settings file or `manifest.json` registers
  an MCP server.
- Collapse the lean-lsp duplication to one registration mechanism (`setup-lean-mcp.sh`) and one
  permission grant (a wildcard in lean's own fragment).
- Name, in the canonical document, the five other extensions carrying dead `mcpServers`
  declarations so a future author is not misled by their example.

**Non-Goals**:
- Registering `mcp-nixos`, `obsidian-memory`, `rmcp`, `openpyxl`, `superdoc`, `firecrawl`, or
  `sec-edgar` in user scope. Named as a follow-up only.
- Removing the dead `mcpServers` blocks from the nix, memory, filetypes, founder, and epidemiology
  fragments. Only lean's is removed here, as part of its reconciliation; the others are a
  follow-up so that a single documentation change is not silently coupled to five extensions'
  behavior.
- Changing `setup-lean-mcp.sh`'s logic. Only its header prose changes.
- Editing anything under a deployed `.claude/**` tree, or performing a redeploy/regeneration.
  Regeneration is a manual, user-performed operation.
- Changing the merge machinery (`merge_settings()`/`unmerge_settings()`) itself.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing core's `mcp__lean-lsp__*` wildcard before lean's fragment carries its replacement leaves a window with no lean grant | M | M | Phase 5 is declared `Commit Mode: atomic-batch` over both JSON files; intermediate single-file states are expected red and are not committed |
| Doc corrections land but the misleading `mcpServers` example survives somewhere unsearched, recreating the fifth path | H | M | Phase 7 runs a repo-wide grep sweep over `agent-system/**` for `mcpServers` and for "Configured automatically in `manifest.json`", and reconciles every hit against the decision |
| New context file is written but not registered in `index-entries.json`, failing the index-truth doc-lint gate | M | M | Phase 2 exists solely for registration and runs `generate-context-line-counts.sh --check` |
| `line_count` in the index entry drifts as the doc is edited in later phases | L | M | Phase 7 re-runs the line-count check after all prose edits are final, not only in Phase 2 |
| Source-store edits create apparent deploy drift versus the current `.claude/**` tree | L | H | Expected and non-blocking: `.claude/**` is regenerated manually by the user; Phase 7 records this rather than attempting a redeploy |
| Task-number citations leak into deliverable files outside `specs/**` | M | L | Phase 7 runs `check-task-references.sh`; every new/edited deliverable cites durable anchors (filenames, section headings) instead |
| JSON edits break `settings.json`/`settings-fragment.json`/`index-entries.json` parseability | H | L | `jq empty` validity check on every touched JSON file in the phase that touches it, and again in Phase 7 |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6 | 5 |
| 4 | 7 | 2, 3, 4, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Author the canonical ownership document [COMPLETED]

**Goal**: Create `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` as the
single document that answers "where do I declare a new MCP server and its permissions?"

**Tasks**:
- [x] Create `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`. *(completed)*
- [x] Open with a one-paragraph statement of the two independent axes: REGISTRATION (which file
      makes a server exist and connect) and PERMISSION (which file grants its tools without a
      prompt). State plainly that neither substitutes for the other. *(completed)*
- [x] Write the **Registration** section: user-scope `~/.claude.json` is the only mechanism that
      registers a server for agent use. Two sanctioned ways to write it: (a) a host-level /
      home-manager activation block, for servers with no per-project computed arguments; (b) a
      setup script under `core/scripts/`, mirroring `setup-lean-mcp.sh`'s shape (detect/compute
      per-project args, then `jq`-merge into `~/.claude.json`'s top-level `mcpServers`), for
      servers that need one. *(completed)*
- [x] Write the **Not registration** subsection stating, as an empirically verified fact, that an
      `mcpServers` key inside `settings.json`/`settings.local.json` (and therefore inside an
      extension's `settings-fragment.json`) has no effect: Claude Code never reads those files for
      server definitions. Record the evidence shape (a `claude mcp list` run showing only
      user-scope servers as `Connected`, while settings-declared servers are absent entirely
      rather than failing to connect) and the doc-side corroboration (the settings reference
      documents only `enabledMcpjsonServers`, `disabledMcpjsonServers`,
      `enableAllProjectMcpServers`, `allowedMcpServers`, `deniedMcpServers`,
      `allowManagedMcpServersOnly` -- all of which approve or deny servers defined elsewhere, none
      of which define one). *(completed)*
- [x] Write the **Permission** section: domain-specific `mcp__{server}__*` grants go in that
      extension's `settings-fragment.json` `permissions.allow`; core's `root-files/settings.json`
      `permissions.allow` is reserved for grants that apply regardless of which extensions are
      loaded. State the wildcard-over-enumeration preference and why (an enumeration silently
      under-grants as a server's tool surface grows; a wildcard cannot drift), with the observed
      lean-lsp enumeration drift as the worked example. *(completed)*
- [x] Write the **Composition** section: a tool is usable without a prompt only if its server shows
      `Connected` in `claude mcp list` AND an active `permissions.allow` list matches it. Give the
      two failure shapes (connected-but-prompting, granted-but-absent) and which axis to fix for
      each. *(completed)*
- [x] Write a short **Decision procedure** the author can follow top to bottom: pick a registration
      mechanism (a or b), write the permission grant in the extension's own fragment, verify with
      `claude mcp list` plus a tool call. *(completed)*
- [x] Write a **Known gaps** section naming the five extensions whose `settings-fragment.json`
      still declares a non-functional `mcpServers` block (`nix`, `memory`, `filetypes`, `founder`,
      `epidemiology`) and the servers thereby unregistered (`mcp-nixos`, `obsidian-memory`,
      `openpyxl`, `superdoc`, `firecrawl`, `sec-edgar`, `rmcp`), explicitly flagged as a pending
      follow-up so their presence is not read as a counter-example to this document. *(completed)*
- [x] Write a **Related Documentation** section linking `permission-configuration.md`,
      `extension-system.md` (Settings Merging), `creating-extensions.md`, and
      `mcp-tool-recovery.md`. *(completed)*
- [x] Verify no task-number citations appear anywhere in the file; cite filenames and section
      headings as anchors instead. *(completed: grep for task-number patterns returns clean)*

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` - new file, the canonical
  ownership reference

**Verification**:
- File exists and is non-empty.
- Every one of the four sections (Registration, Permission, Composition, Known gaps) is present by
  heading.
- `grep -nE 'task [0-9]+|tasks [0-9]+' agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
  returns nothing.
- Read-through confirms the document answers the acceptance question standalone, without requiring
  the reader to consult the other four docs first.

---

### Phase 2: Register the new context file in core's index [COMPLETED]

**Goal**: Add an `index-entries.json` entry for the new pattern file so it is discoverable by the
context-discovery machinery and passes the index-truth and schema-conformance doc-lint gates.

**Tasks**:
- [x] Add an entry to `agent-system/extensions/core/index-entries.json` for
      `patterns/mcp-server-ownership.md`, copying the field shape of the adjacent
      `patterns/mcp-tool-recovery.md` entry: `path`, `domain` (`core`), `subdomain` (`patterns`),
      `summary`, `line_count`, `keywords`, `topics`, `load_when` (`agents`, `commands`,
      `task_types`). *(completed)*
- [x] Use only the schema's real field set -- no `description`, no `tags`, and no `load_when` keys
      beyond `agents`/`commands`/`task_types`; the schema-conformance gate rejects those.
      *(completed)*
- [x] Choose keywords that a future author would actually query on (for example `mcp`,
      `registration`, `permissions`, `settings`, `patterns`) and place the entry adjacent to the
      existing `mcp-tool-recovery.md` entry for readability. *(completed)*
- [x] Set `line_count` from `wc -l` of the file as written in Phase 1, or run
      `bash .claude/scripts/generate-context-line-counts.sh --write` and confirm it fills the value
      rather than hand-guessing it. *(completed: line_count 160 confirmed by --check with 0
      mismatches under core)*

**Timing**: 20 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly ONE new index entry is required, and that no other
manifest change is needed because core's `manifest.json` `provides.context` declares the `patterns`
directory rather than individual files. Confirm at implementation time with
`jq '.provides.context' agent-system/extensions/core/manifest.json` (expect a `patterns` directory
entry, not a file list) before concluding no manifest edit is owed.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - one added entry for the new pattern file

**Verification**:
- `jq empty agent-system/extensions/core/index-entries.json` exits 0.
- `jq '[.entries[] | select(.path == "patterns/mcp-server-ownership.md")] | length'` returns 1.
- `bash .claude/scripts/generate-context-line-counts.sh --check` reports no mismatch for the new
  entry.

---

### Phase 3: Correct the architecture and extension-authoring docs [COMPLETED]

**Goal**: Remove the two source-store assertions that a settings fragment or manifest field
registers an MCP server, and point both docs at the canonical reference.

**Tasks**:
- [x] In `agent-system/extensions/core/docs/architecture/extension-system.md`, `## Settings
      Merging`: replace the `settings-fragment.json` example that shows an `mcpServers` block (the
      `latex-compile` example) with a `permissions.allow` example, so the illustrative example no
      longer demonstrates a non-functional pattern. *(completed)*
- [x] In the same section, replace the existing note about `mcp_servers` with a plain statement
      that **neither** `manifest.json`'s `mcp_servers` field **nor** an `mcpServers` key inside a
      settings fragment registers a server, and link to
      `../../context/patterns/mcp-server-ownership.md` for where registration actually happens.
      *(completed)*
- [x] Update the manifest-schema `Note on mcp_servers` earlier in the same file so it no longer
      says "MCP server configurations must be in a `settings-fragment.json` file" -- that sentence
      is the specific wrong instruction this task exists to retire. *(completed)*
- [x] In `agent-system/extensions/core/docs/guides/creating-extensions.md`, correct the
      `mcp_servers` row of the manifest Field Reference table so it states the field is inert and
      points to the canonical reference instead of describing it as "MCP server configs to merge".
      *(completed)*
- [x] In the same file, remove or annotate the `"mcp_servers": {}` line in the example manifest so
      a copy-paste author does not reproduce a dead field. *(completed: removed and replaced with
      an explanatory "On `mcp_servers`" note)*
- [x] Confirm the `MCP Tool Setup` README-section guidance in that file still reads correctly given
      the corrected registration path. *(completed: guidance is conditional prose, "if the
      extension configures MCP servers", unaffected by the registration-path correction)*

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts there are exactly TWO wrong-assertion sites in
`extension-system.md` (the Settings Merging example plus its note, and the manifest-schema note)
and TWO in `creating-extensions.md` (the field-reference row and the example-manifest line).
Confirm at implementation time with `grep -ni 'mcp' <file>` on each of the two files and reconcile
every hit before closing the phase; if a hit outside these four sites asserts registration, treat
it as in scope for this phase.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/extension-system.md` - Settings Merging example
  and note, manifest-schema `mcp_servers` note
- `agent-system/extensions/core/docs/guides/creating-extensions.md` - `mcp_servers` field row and
  example-manifest line

**Verification**:
- `grep -n 'mcpServers' agent-system/extensions/core/docs/architecture/extension-system.md` returns
  only occurrences that state the key is non-functional -- never one presented as a working
  example.
- Both files link to `context/patterns/mcp-server-ownership.md` by a path that resolves from the
  file's own location.
- Diff read-through confirms every changed hunk is prose or fenced example text.

---

### Phase 4: Add the ownership section to the permission guide and cross-link recovery [NOT STARTED]

**Goal**: Give `permission-configuration.md` -- the doc an author reaches for when asking "where do
permissions go?" -- an explicit MCP subsection stating the two axes, and cross-link the pattern
from `mcp-tool-recovery.md`.

**Tasks**:
- [ ] In `agent-system/extensions/core/docs/guides/permission-configuration.md`, add a top-level
      section covering MCP servers: the registration/permission split, that settings files grant
      but never register, and the extension-fragment vs. core-settings scoping rule for
      `mcp__{server}__*` grants.
- [ ] State the wildcard-over-enumeration preference in that section, since this is the guide an
      author consults when writing a `permissions.allow` entry.
- [ ] Link to `../../context/patterns/mcp-server-ownership.md` as the canonical reference, so the
      guide carries the decision summary and the pattern file carries the full procedure.
- [ ] Add the new section to the file's `## Table of Contents` numbered list, keeping the existing
      numbering contiguous and the anchor slug matching the heading.
- [ ] Extend the existing `### Settings File Location: a Host-App Constraint` subsection, which
      currently says these settings files hold "MCP server configuration", to say instead that they
      hold MCP *permission grants* -- that phrase is itself one of the wrong assertions.
- [ ] In `agent-system/extensions/core/context/patterns/mcp-tool-recovery.md`, add a
      `mcp-server-ownership.md` link to its `## Related Documentation` section, and make the
      existing "may indicate MCP not in user scope (check ~/.claude.json)" guidance point at the
      canonical doc for the reason.

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/docs/guides/permission-configuration.md` - new MCP ownership
  section, ToC entry, corrected host-app-constraint wording
- `agent-system/extensions/core/context/patterns/mcp-tool-recovery.md` - Related Documentation
  cross-link

**Verification**:
- The new section's heading appears in both the ToC and the body, with matching anchor text.
- `grep -n 'mcp-server-ownership' <both files>` returns at least one hit each.
- Diff read-through confirms all changed hunks are prose.

---

### Phase 5: Reconcile the lean-lsp permission duplication [NOT STARTED]

**Goal**: Collapse the three-way lean-lsp duplication on the permission axis to a single wildcard
in lean's own fragment, and remove the dead registration block.

**Tasks**:
- [ ] In `agent-system/extensions/core/root-files/settings.json`, remove the `"mcp__lean-lsp__*"`
      entry from `permissions.allow` -- a domain-specific grant does not belong in the
      domain-agnostic core file.
- [ ] In `agent-system/extensions/lean/settings-fragment.json`, replace the 21-entry
      `mcp__lean-lsp__lean_*` enumeration in `permissions.allow` with the single wildcard
      `"mcp__lean-lsp__*"`.
- [ ] In the same file, delete the `mcpServers` block entirely -- it is non-functional and its
      presence is exactly the misleading example the canonical doc now warns against.
- [ ] Keep both files valid JSON with the surrounding structure otherwise untouched (no reordering
      or reformatting of unrelated keys).
- [ ] Treat these two edits as one unit: the intermediate state where core's wildcard is gone but
      lean's replacement is not yet in place is expected-red and must not be committed.

**Timing**: 20 minutes

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: atomic-batch

**Scope Hypothesis**: This phase asserts core's `settings.json` contains exactly ONE
`mcp__lean-lsp__*` occurrence and lean's fragment contains exactly 21 enumerated
`mcp__lean-lsp__lean_*` entries plus one `mcpServers` block. Confirm at implementation time with
`grep -c 'mcp__lean-lsp' <each file>` and `jq '.permissions.allow | length'` on the fragment before
editing; if the counts differ, reconcile against the actual file rather than the numbers asserted
here.

**Files to modify**:
- `agent-system/extensions/core/root-files/settings.json` - remove one domain-specific wildcard
  from `permissions.allow`
- `agent-system/extensions/lean/settings-fragment.json` - wildcard replaces enumeration;
  `mcpServers` block deleted

**Verification**:
- `jq empty` exits 0 on both files.
- `grep -c 'mcp__lean-lsp' agent-system/extensions/core/root-files/settings.json` returns 0.
- `jq '.mcpServers' agent-system/extensions/lean/settings-fragment.json` returns `null`.
- `jq '.permissions.allow' agent-system/extensions/lean/settings-fragment.json` contains exactly
  the one wildcard entry.
- The rest of core's `permissions.allow` is unchanged (diff shows a single removed line).

---

### Phase 6: Correct the extension-facing registration statements [NOT STARTED]

**Goal**: Make the lean and nix READMEs describe the actual registration path, and restate
`setup-lean-mcp.sh`'s header claim precisely rather than categorically.

**Tasks**:
- [ ] In `agent-system/extensions/lean/README.md`'s `## MCP Tool Setup` section, replace
      "Configured automatically in `manifest.json`" with the accurate path: registration is
      performed by the operator running `core/scripts/setup-lean-mcp.sh`, which writes the server
      into user-scope `~/.claude.json` with a computed project path; permissions are granted by
      this extension's own `settings-fragment.json`. Link the canonical pattern document.
- [ ] Confirm the invocation line in that section matches what `setup-lean-mcp.sh` actually
      configures, and correct it if it does not.
- [ ] In `agent-system/extensions/nix/README.md`'s `## MCP Tool Setup` section, replace
      "Configured automatically in `manifest.json`" with an accurate statement that `mcp-nixos` is
      **not currently registered** by anything in this repo, that the `mcpServers` block in the
      extension's settings fragment has no effect, and that agents therefore fall back to the
      WebSearch/CLI path already documented in `context/project/nix/tools/mcp-nixos-integration.md`.
      Link the canonical pattern document and note that registration is a pending follow-up.
- [ ] In `agent-system/extensions/core/scripts/setup-lean-mcp.sh`'s header comment, replace the
      categorical claim that custom subagents cannot access project-scoped MCP servers with the
      precise mechanism: project-scoped `.mcp.json` servers require an interactive approval prompt
      that a subagent cannot satisfy, so user-scope registration (never gated by per-server
      approval) is the reliable choice. Leave the operative conclusion -- user scope is required --
      intact, and change no executable line.
- [ ] Confirm no task-number citations were introduced in any of the three files.

**Timing**: 30 minutes

**Depends on**: 5

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/lean/README.md` - MCP Tool Setup registration statement
- `agent-system/extensions/nix/README.md` - MCP Tool Setup registration statement
- `agent-system/extensions/core/scripts/setup-lean-mcp.sh` - header comment wording only

**Verification**:
- `bash -n agent-system/extensions/core/scripts/setup-lean-mcp.sh` exits 0.
- `git diff -- agent-system/extensions/core/scripts/setup-lean-mcp.sh` shows only comment-line
  changes (every changed line begins with `#`).
- `grep -n 'Configured automatically in' agent-system/extensions/lean/README.md
  agent-system/extensions/nix/README.md` returns nothing.
- Both READMEs link `mcp-server-ownership.md`.

---

### Phase 7: Repo-wide consistency sweep and gate run [NOT STARTED]

**Goal**: Confirm no residual wrong assertion survives anywhere in the source store, and that every
mechanical gate this change can be checked against passes at source level.

**Tasks**:
- [ ] Run `grep -rn 'mcpServers' agent-system/` and classify every hit: a settings-fragment
      declaration in nix/memory/filetypes/founder/epidemiology is expected and named in the Known
      gaps section; a prose hit presenting it as a working registration path is a defect this task
      must fix.
- [ ] Run `grep -rni 'Configured automatically in' agent-system/` and confirm no MCP registration
      claim remains.
- [ ] Run `grep -rn 'mcp_servers' agent-system/extensions/core/docs/` and confirm every remaining
      mention describes the field as inert.
- [ ] Run `jq empty` over every JSON file touched by this plan
      (`core/root-files/settings.json`, `lean/settings-fragment.json`, `core/index-entries.json`).
- [ ] Re-run `bash .claude/scripts/generate-context-line-counts.sh --check` now that all prose edits
      are final, and correct the new entry's `line_count` if the earlier value drifted.
- [ ] Run `bash .claude/scripts/check-task-references.sh` and confirm no new finding traces to a
      file this plan touched.
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and triage its output: source-vs-deployed
      drift findings for files this plan edited are EXPECTED (the `.claude/**` tree is regenerated
      manually by the user and this plan does not redeploy) and are not defects; any finding that
      is not explained by that drift must be resolved.
- [ ] Record in the implementation summary that a manual regeneration is required for these
      source-store changes to reach the deployed tree, and that the systemic
      dead-`mcpServers` finding across five extensions remains an open follow-up.

**Timing**: 25 minutes

**Depends on**: 2, 3, 4, 6

**Verification Tier**: full

**Scope Hypothesis**: This phase assumes the residual-assertion surface is confined to
`agent-system/extensions/{core,lean,nix}/**` and that hits in the other four extensions carrying
dead `mcpServers` blocks (`memory`, `filetypes`, `founder`, `epidemiology`) are declaration-only,
with no accompanying prose asserting the wrong registration path. Confirm with the repo-wide greps
above; if one of those four carries such prose, correct that prose (not the declaration) as part of
this phase and note the widened scope.

**Files to modify**:
- None expected; corrective edits to files already listed in Phases 1-6 if a sweep hit demands one

**Verification**:
- All greps return only classified, expected hits.
- All `jq empty` invocations exit 0.
- `generate-context-line-counts.sh --check` reports no mismatch.
- `check-task-references.sh` reports no new finding attributable to this plan's files.
- `check-extension-docs.sh` output fully triaged, with each finding either resolved or explicitly
  attributed to expected pre-regeneration drift.

---

## Testing & Validation

- [ ] `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` exists, is non-empty,
      and answers the acceptance question standalone: a reader learns where to declare a new MCP
      server and where to grant its permissions without consulting another file.
- [ ] `jq empty` passes on `core/root-files/settings.json`, `lean/settings-fragment.json`, and
      `core/index-entries.json`.
- [ ] `grep -c 'mcp__lean-lsp' agent-system/extensions/core/root-files/settings.json` returns 0.
- [ ] `jq '.mcpServers' agent-system/extensions/lean/settings-fragment.json` returns `null` and
      `.permissions.allow` holds exactly one wildcard entry.
- [ ] `bash .claude/scripts/generate-context-line-counts.sh --check` reports no mismatch for the new
      index entry.
- [ ] `bash .claude/scripts/check-task-references.sh` reports no new finding in any file this plan
      touched.
- [ ] `bash -n agent-system/extensions/core/scripts/setup-lean-mcp.sh` exits 0 and its diff is
      comment-only.
- [ ] Every one of the four corrected docs (`permission-configuration.md`, `extension-system.md`,
      `creating-extensions.md`, `mcp-tool-recovery.md`) plus both READMEs links the canonical
      pattern document.
- [ ] No file outside `specs/**` touched by this plan contains a task-number citation.

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md` (new)
- `agent-system/extensions/core/index-entries.json` (one entry added)
- `agent-system/extensions/core/docs/architecture/extension-system.md` (corrected)
- `agent-system/extensions/core/docs/guides/creating-extensions.md` (corrected)
- `agent-system/extensions/core/docs/guides/permission-configuration.md` (new section + ToC entry)
- `agent-system/extensions/core/context/patterns/mcp-tool-recovery.md` (cross-link)
- `agent-system/extensions/core/root-files/settings.json` (domain-specific wildcard removed)
- `agent-system/extensions/lean/settings-fragment.json` (wildcard replaces enumeration;
  `mcpServers` deleted)
- `agent-system/extensions/lean/README.md`, `agent-system/extensions/nix/README.md` (corrected
  registration statements)
- `agent-system/extensions/core/scripts/setup-lean-mcp.sh` (header comment precision fix)
- `specs/023_document_mcp_registration_ownership_boundary/summaries/01_mcp-ownership-boundary-summary.md`

## Rollback/Contingency

Every change is a source-store text or JSON edit with no runtime side effect until a manual
regeneration is performed, so rollback is a `git revert` of this task's commits -- no deployed
state needs unwinding.

Phase-level contingency:

- **Phase 5 is the only phase with a live behavioral effect** (after regeneration): if lean tool
  calls begin prompting, the wildcard did not land in the deployed `settings.local.json`. Confirm
  with `jq '.permissions.allow' .claude/settings.local.json` after regeneration; the fix is a
  regeneration, not a re-edit, unless the fragment itself is wrong.
- If Phase 2's index entry proves to need a manifest change after all (contrary to its Scope
  Hypothesis), add the declaration rather than dropping the index entry -- an unregistered context
  file fails the index-truth gate and is worse than a slightly wider manifest edit.
- If the Phase 7 sweep uncovers substantially more wrong-assertion sites than the four extensions
  anticipated, correct the in-scope ones and record the remainder as an explicit
  `#### Reasoned Exclusions` record on Phase 7 rather than silently widening the task.
