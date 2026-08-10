# Research Report: Task #396 — Teammate C (The Critic)

**Task**: 396 - Review .claude/ agent system architecture and documentation audit
**Role**: TEAMMATE C — THE CRITIC
**Started**: 2026-04-10T00:00:00Z
**Completed**: 2026-04-10T00:30:00Z
**Effort**: ~30 min
**Sources/Inputs**: Direct file reads — present/README.md, founder/README.md, memory/README.md, all EXTENSION.md files (14 extensions), manifest.json files, extensions/README.md, CLAUDE.md

---

## Key Findings (Bluntly Stated)

1. **present/README.md is a mixed bag, not a gold standard.** It has clear command docs but is 87 lines long for 5 commands, contains no architectural explanation, and its "Related Files" section is a flat link list with no navigational rationale. founder/README.md (390 lines) is demonstrably better and should be the reference model.

2. **10 of 14 extensions have no README.md at all.** The missing READMEs are for: epidemiology, filetypes, formal, latex, lean, nix, nvim, python, typst, web, z3 — all the domain extensions except founder, present, and memory. This is the correct count the task is working from.

3. **Every extension already has EXTENSION.md and manifest.json.** These two files together cover: what the extension does, what commands exist, what skill-agent mappings exist, what routing rules apply, and what context files are available. A README mostly duplicates this. The question "is there a gap?" requires proving the existing files leave users lost — which is not obvious.

4. **EXTENSION.md is the machine-consumed doc; README.md is human-facing.** But the system does not primarily have human readers browsing the extensions directory. Agents load EXTENSION.md content into CLAUDE.md automatically. Humans primarily interact through Neovim keybindings. The audience for a README is a developer browsing the repository — a narrow secondary audience.

5. **Documentation drift is guaranteed.** The manifest.json is the authoritative source of truth for what the extension provides. Any README or EXTENSION.md that duplicates that information will diverge. founder/README.md already shows v3.0 version notes and "legacy workflow" docs that signal drift has occurred. Adding more files means more drift surface.

6. **The `lean` extension is the canary.** It has no README but has EXTENSION.md, manifest.json, a setup script, MCP server configuration, and a detailed rules file. A README here would add almost nothing that isn't already captured. For simple tooling extensions (z3, nix, python) the same applies.

---

## Critique of the Reference Model (present/README.md)

**What is good:**
- Concise (87 lines — the shortest of the three READMEs that exist)
- Command-focused: each command gets a heading, syntax examples, and available modes
- The table summarizing features at the top is effective at a glance

**What is bad:**
- **No architecture section.** There is no explanation of where things live, why the extension is structured as it is, or what the skill-agent split means. Compare founder/README.md which has a full `## Architecture` tree diagram.
- **"Related Files" is a lazy link dump.** The section lists `EXTENSION.md`, `context/project/present/domain/`, `context/project/present/patterns/`, etc. — no explanation of when to consult which, what relationship they have, or what agents load them.
- **Missing: loading instructions.** How do you load this extension? Not mentioned. founder/README.md has `## Installation` and `## MCP Tool Setup` sections. memory/README.md explains `<leader>ac`. present/README.md is silent.
- **Missing: workflow diagram.** present has a `grant -> budget -> timeline` natural workflow. It's not documented. founder shows the full phased workflow explicitly.
- **Missing: output artifacts.** Where do the generated files go? founder documents this with a table. present does not.
- **Missing: troubleshooting.** memory/README.md has a full troubleshooting section. present has nothing.

**Verdict:** If the task copies present/README.md as a template, the resulting READMEs will be the weakest of the three existing README styles. founder/README.md is more thorough. memory/README.md is the best-structured. Neither was chosen as the reference model. This is a mistake.

---

## Unchallenged Assumptions

### Assumption 1: Each extension NEEDS a README at its top level.

**Challenge:** The README lives at `extensions/{name}/README.md`. The primary consumers of that directory are:
- The extension loader script (reads manifest.json, EXTENSION.md)
- A developer browsing the repo who wants to understand an extension

The loader ignores README.md entirely. For the developer use case, EXTENSION.md plus manifest.json already tells you what the extension does, what it provides, and how it routes. The "gap" the task is solving for may be illusory for most extensions.

**Counter-evidence from the codebase:** extensions/README.md (the directory-level README) explicitly documents what each extension does in a table and how to load them. A developer landing at `extensions/` already gets a complete overview without opening any individual extension README.

### Assumption 2: The "missing docs" are helpful to users.

**Challenge:** For a simple extension like `z3` or `nix`, what user-facing content would a README add? The EXTENSION.md already documents routing, skill-agent mappings, and common patterns. A README would be a rehash of EXTENSION.md for human readability — but EXTENSION.md is already human-readable.

**Specific case — `latex` EXTENSION.md:** 30 lines. VimTeX keybindings, routing table, document structure conventions. A README here would either duplicate these 30 lines or add filler padding to match a template.

### Assumption 3: Documentation drift is a real user-facing problem here.

**Challenge:** This is a personal configuration repository, not a shared library. The "users" are essentially one person (plus Claude agents). When routing breaks or a skill doesn't work, the failure mode is immediate and concrete — a command throws an error, not "the docs were wrong." Documentation drift matters most in team-maintained public libraries where newcomers are onboarded via READMEs. That is not this system's use case.

### Assumption 4: A blanket README write is the right scope boundary.

**Challenge:** The most practically drifted documentation in this system is likely the CLAUDE.md files and EXTENSION.md sections — not the README gap. EXTENSION.md files are injected into CLAUDE.md when an extension loads. If an EXTENSION.md drifts from manifest.json's `provides`, an agent gets wrong routing information. That is a concrete, agent-impacting drift problem. README absence is not.

---

## Blind Spots in Task Scope

### 1. CLAUDE.md injection drift is unexamined.

EXTENSION.md content is merged into `.claude/CLAUDE.md` at load time. If an extension is loaded, modified, but CLAUDE.md is not regenerated, the active agent instructions diverge from the extension files. This is a higher-severity problem than missing READMEs, and it is not in scope.

Verification: `grep -n "extension_nvim\|extension_present" .claude/CLAUDE.md` returned nothing — suggesting either no extensions are currently loaded, or the merge mechanism hasn't run recently. This is exactly the kind of drift that would confuse agents.

### 2. Agent frontmatter descriptions are minimally documented.

All 14+ agents have `description:` frontmatter fields that appear in `tool_use` contexts when Claude Code displays available agents. These descriptions are the first thing a human or agent reads when selecting a tool. They are one-liners. No audit of their quality or accuracy is in scope.

Example from neovim-research-agent.md:
```
description: Research Neovim configuration and plugin tasks
```
This tells you almost nothing about when to use this vs. general-research-agent for neovim questions.

### 3. Skill SKILL.md files are in scope ambiguity.

The present extension has 5 SKILL.md files (grant, budget, timeline, funds, talk). The founder extension has 12 SKILL.md files. These are loaded by agents. Their quality and accuracy matters more to agent behavior than whether a README exists. They are not mentioned in the task scope.

### 4. The `nvim` extension specifically has a self-referential problem.

The `nvim` extension (for Neovim configuration development) has no README. Yet this is the most heavily used extension in the system. If documentation gaps were user-facing problems, this one would surface first — and it hasn't, because developers find what they need through CLAUDE.md and EXTENSION.md.

### 5. Machine-checkable validation already exists.

`validate-wiring.sh --all` checks extension integrity. The task wants to fix documentation. But if the problem is "things drift," the solution is a lint/validation rule, not prose documents. A README cannot be validated. A manifest can.

---

## Better Questions to Ask

**Q1: Who reads these README files, and when?**
If the answer is "a developer unfamiliar with the extension structure," then the extensions/README.md directory README already serves this purpose. If the answer is "agents," then README.md is the wrong format — agents load EXTENSION.md, not README.md.

**Q2: What failure mode does this documentation fix?**
A concrete failure mode should be stated. "I couldn't figure out how to use the lean extension" is different from "the agent routed to the wrong skill." These have different documentation remedies.

**Q3: Should the gap be filled with documentation or with automation?**
For the problem "extension metadata drifts," the correct fix is updating `validate-wiring.sh` to cross-check EXTENSION.md against manifest.json. For the problem "humans can't navigate the extension system," the correct fix is improving the top-level extensions/README.md. Both are better-targeted than adding READMEs to each extension.

**Q4: Which three extensions, if documented, would provide 80% of the value?**
Not all extensions are equal. The `lean` extension has setup complexity (MCP, lake, scripts). The `epidemiology` extension has R toolchain requirements. The `filetypes` extension has 5 commands and 6 agents. Documenting these three is probably more valuable than uniform coverage of all eleven.

**Q5: Is "README as documentation" the right format, or should this be a wiki-style context file?**
The system already has context files for domain knowledge (`context/project/{ext}/README.md`). Several extensions (epidemiology, lean4) have context-level READMEs. The difference between an extension-top-level README and a context-level README is unclear and potentially creates two competing entry points.

---

## Recommendation

**Rescope.**

The task as stated ("write READMEs for 11 extensions using present/README.md as reference") has three problems:

1. It chose the weakest existing README as the template. Use founder/README.md instead, or ideally extract a template from the best elements of founder + memory.

2. It treats all 11 missing extensions equally. They aren't equal. Simple extensions (z3, nix, python, latex) don't need READMEs — their EXTENSION.md is already complete. Complex ones with setup steps (lean, epidemiology), multiple commands (filetypes, founder-style), or non-obvious routing (formal) do benefit from READMEs.

3. It ignores higher-priority drift: EXTENSION.md vs. manifest.json consistency, agent frontmatter descriptions, skill SKILL.md accuracy. These affect agent behavior. README absence does not.

**If the task proceeds, the minimum viable rescope is:**
- Target only the 4-5 extensions with non-trivial setup or command complexity: lean, epidemiology, filetypes, formal, and possibly nvim
- Use founder/README.md as the template (not present/README.md)
- Add one validation step: cross-check that new READMEs don't contradict manifest.json

**If the task is reconsidered entirely:**
- The highest-value meta-documentation work is: (a) a guide on how to create new extensions that captures when each file type is needed, and (b) improving validate-wiring.sh to detect EXTENSION.md/manifest.json drift.

---

## Confidence Level

**High** on findings 1-5 (based on direct file reads).
**Medium** on the CLAUDE.md injection drift finding (couldn't confirm current injection state).
**Medium** on the "README adds no value for simple extensions" argument (depends on whether the repository has other contributors).
