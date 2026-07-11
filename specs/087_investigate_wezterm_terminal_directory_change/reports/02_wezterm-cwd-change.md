# Research Report: Task #87 (Re-Research)

- **Task**: 87 - Investigate WezTerm terminal directory change
- **Started**: 2026-07-11T20:16:08Z
- **Completed**: 2026-07-11T21:10:00Z
- **Effort**: 2 hours
- **Dependencies**: None
- **Sources/Inputs**: Live headless nvim diagnostics, live `/proc` process inspection of running WezTerm panes, `wezterm cli list`, this repo's nvim config, `~/.dotfiles/` (home-manager-deployed fish/wezterm config and git history)
- **Artifacts**: specs/087_investigate_wezterm_terminal_directory_change/reports/02_wezterm-cwd-change.md
- **Standards**: report-format.md, subagent-return.md

## Project Context (optional)
- **Upstream Dependencies**: `lua/neotex/config/autocmds.lua` (OSC 7 emission), `lua/neotex/plugins/ai/claude/core/worktree.lua` and `lua/neotex/plugins/tools/worktree.lua` (user-triggered `tcd`/`cd`), `~/.dotfiles/config/wezterm.lua` (pane spawn keybinding), `~/.dotfiles/config/config.fish` (OSC 7 shell hook, deployed via home-manager)
- **Downstream Dependents**: Claude Code worktree/session switching UX, WezTerm tab titles, telescope/dashboard "recent project" workflows
- **Alternative Paths**: None identified beyond the WezTerm-side fix already attempted and reverted upstream (see Findings)
- **Potential Extensions**: A `VimLeavePre` OSC 7 restore hook; a corrected `LEADER+c` spawn action

## Executive Summary
- **Root cause is definitively identified and is NOT in Neovim's own cwd handling.** Live headless testing (bare `nvim`, `nvim <file-in-a-different-git-repo>`, `autochdir?`, `exrc?`) conclusively proves Neovim never automatically changes its own working directory. This refutes the "further investigation needed" framing in the Feb 13 report — that part of the report's negative finding was correct, but it stopped one layer too early.
- **The actual mechanism is a WezTerm-side stale-cwd propagation bug**, live-reproduced by inspecting 5 real, currently-running WezTerm panes on this machine via `/proc/<pid>/cwd`: in **every single pane**, the fish shell's real cwd differs from the nvim process it spawned, and each new pane's fish shell inherited the *previous* pane's nvim cwd rather than starting at `$HOME`.
- **Causal chain**: (1) a user action inside Neovim (worktree `tcd`/`cd`, or manual `:cd`) changes Neovim's own cwd; (2) `autocmds.lua`'s `DirChanged`/`VimEnter`/`BufEnter` handlers emit an OSC 7 sequence reporting that path to WezTerm; (3) WezTerm caches this as the pane's tracked "current working directory" (visible via `wezterm cli list`); (4) **there is no `VimLeave`/`VimLeavePre` OSC 7 re-emission**, so this cached value is never corrected back to the shell's real `$PWD` when Neovim exits; (5) fish's own OSC 7 hook (`__wezterm_osc7`) only fires `--on-variable PWD`, i.e. only on an actual `cd`, so it never re-asserts the correct value either; (6) when the user later opens a new tab via the `LEADER+c` keybinding (`act.SpawnTab("CurrentPaneDomain")`, no explicit `cwd`), WezTerm — per its own documented behavior for unset `cwd` — spawns the new shell in the *stale, cached* directory, not `$HOME`; (7) the user then runs bare `nvim` in that new tab (confirmed live: **zero file arguments** in every nvim process inspected) and perceives "opening nvim from home" as the trigger, when the pane was already contaminated before nvim ever ran.
- **Independent corroboration found in `~/.dotfiles` git history**: on 2026-02-24 (11 days after the original Feb 13 report), a commit (`3af0978`, "task 94 phase 1: replace Leader+c keybinding") attempted exactly this fix, with a code comment stating verbatim: *"This bypasses WezTerm's OSC 7 metadata which may be stale (e.g., after exiting Neovim, OSC 7 still reports Neovim's directory)."* It was reverted less than an hour later (`3d82539`) with no recorded rationale — no spec artifact for that work could be located (likely lost to a subsequent `specs/vault` renumbering in the dotfiles repo).
- **What depends on the current behavior**: the Claude Code worktree/session feature's own tab-spawning path (`terminal-commands.lua:22`, `wezterm cli spawn --cwd '%s' ...`) is unaffected — it always passes an explicit `--cwd` and does not rely on WezTerm's stale-cwd fallback. Only the plain `LEADER+c` "new tab" keybinding and the tab-title display are affected.
- **Recommended minimally-invasive fix**: reinstate a corrected version of the reverted `LEADER+c` fix in `~/.dotfiles/config/wezterm.lua` (read the pane's live foreground-process cwd via `pane:get_foreground_process_info()` instead of trusting OSC 7), **and** add a `VimLeavePre` OSC 7 re-emit in `autocmds.lua` reporting the *shell's* real cwd (or simply cease being the source of truth) so the pane's tracked cwd self-heals the moment Neovim exits, independent of the WezTerm-side fix.

## Context & Scope

This re-research resolves task 87, which the 2026-02-13 report (`research-001.md`) left **inconclusive**: it found no automatic cwd-changing code in Neovim and punted to "further investigation needed." Per the dispatch instructions, this round went deeper, using live diagnostics rather than static grep alone, and re-verified every claim in the Feb report against the current state of both `~/.config/nvim` and `~/.dotfiles/` (config files there are now home-manager-managed symlinks into the Nix store, not directly-edited dotfiles).

**Scope covered**: (1) live headless-nvim reproduction of the reported symptom; (2) exhaustive static search for any remaining cwd-changing mechanism in the current nvim config; (3) live inspection of currently-running WezTerm panes' real vs. tracked cwd via `/proc` and `wezterm cli list`; (4) the shell and WezTerm sides of the OSC 7 chain in `~/.dotfiles/`; (5) dependency check (what relies on the current tcd/OSC7 behavior); (6) git-history check for prior fix attempts.

**Out of scope**: no config was modified (research-only, per dispatch constraints); no `home-manager switch` was run.

## Findings

### 1. Neovim itself never automatically changes its own cwd — VERIFIED LIVE (confirms and strengthens Feb report)

Ran headless diagnostics with clean `redir`-captured output (avoids OSC 7 escape-code interference seen in raw stdout):

```
$ cd ~ && nvim --headless -c 'redir! > out' -c 'echo getcwd()' -c 'redir END' -c 'qa'
=> /home/benjamin

$ cd ~ && nvim --headless /home/benjamin/.config/nvim/init.lua -c 'redir! > out' -c 'echo getcwd()' -c 'redir END' -c 'qa'
=> /home/benjamin   (unchanged, even though the file is inside a different git repo)

$ cd ~ && nvim --headless /home/benjamin/.dotfiles/config/wezterm.lua -c 'redir! > out' -c 'echo getcwd()' -c 'redir END' -c 'qa'
=> /home/benjamin   (unchanged, again a different git repo)

$ nvim --headless -c 'redir! > out' -c 'set autochdir? exrc?' -c 'redir END' -c 'qa'
=> noautochdir
=> noexrc
```

This rules out `autochdir`, `exrc`, and any rooter/project-detection auto-`chdir` even when opening a file that lives inside a *different* git repository than the shell's cwd — a scenario the Feb report did not explicitly test.

**Exhaustive static confirmation** (broader/deeper than Feb's grep): searched the entire `lua/` and `after/` trees for every `chdir`, `vim.cmd("*cd ...")`, `:lcd`, `DirChanged`-driven side effect, and any LSP `root_dir`/`on_init`/`workspace_folders` callback that might call chdir. Result: the only 8 `cd`/`tcd` call sites in the whole config are in `lua/neotex/plugins/tools/worktree.lua:209` and `lua/neotex/plugins/ai/claude/core/worktree.lua:311,383,505,877,930,1491,1981` — every one of them is inside a `vim.ui.select`/telescope-picker callback or a user-invoked worktree/session-switch function, never an autocmd fired without a prior user selection. `snacks.nvim` (new since the Feb report — added to `lazy-lock.json`) has neither `explorer` nor `picker` modules enabled, so its known root-changing behaviors are inactive; the only cwd-related snacks usage is a picker-scoped `cwd` param for the dashboard's "Config" button (`snacks/dashboard.lua:12`), which does not call `:cd`/`:tcd`. The one `VimEnter` autocmd in the Claude worktree module (`worktree.lua:2329`, `ClaudeWorktreeHealth`) is guarded by `isdirectory(".git") == 1` in the *current* directory and only repairs stale session bookkeeping — it never calls `cd`/`tcd`.

**Conclusion**: the "no automatic directory-changing code" claim from Feb is correct and now live-verified, not just grep-inferred. **This part of the Feb report should NOT be revisited or second-guessed by future work.**

### 2. Live process inspection reveals nvim's cwd differs from its own parent shell's cwd in every currently-running pane (NEW — the actual mechanism)

This machine's Bash tool session is itself running inside a live WezTerm session (`WEZTERM_PANE=4`, `TERM_PROGRAM=WezTerm`). `wezterm cli list --format json` was used to enumerate real, currently-open panes, and each pane's foreground/nvim process was cross-checked against ground truth via `/proc/<pid>/cwd`, `/proc/<pid>/cmdline`, and `/proc/<pid>/environ` (`PWD=`).

| pane (tty) | fish's real cwd (`/proc/PID/cwd`) | nvim's real cwd (`/proc/PID/cwd`) | nvim argv | WezTerm-tracked cwd (`wezterm cli list`) |
|---|---|---|---|---|
| pts/0 | `/home/benjamin` (= `$HOME`) | `/home/benjamin/.dotfiles` | none (bare `nvim`) | `.dotfiles` |
| pts/2 | `/home/benjamin/.dotfiles` | `/home/benjamin/Projects/BimodalLogic` | none | `BimodalLogic` |
| pts/3 | `/home/benjamin/Projects/BimodalLogic` | `/home/benjamin/Mail` | none | `Mail` |
| pts/6 | `/home/benjamin/Mail` | `/home/benjamin/Projects/Logos/Hardware` | none | `Logos/Hardware` |
| pts/7 (this session) | `/home/benjamin/Projects/Logos/Hardware` | `/home/benjamin/.config/nvim` | none | `.config/nvim` |

Every `nvim` process was launched with **zero file/directory arguments** (`cmdline` shows only the Nix wrapper's `--cmd lua dofile(...)`, no positional args) — confirming the user pattern described in the task ("opening neovim... from the home directory") is a bare `nvim` invocation, not `nvim <project-path>`.

Two facts fall directly out of this table:
- **Chain pattern**: each pane's fish `$PWD` at spawn time equals the *previous* pane's nvim cwd (pts/0's nvim cwd `.dotfiles` = pts/2's fish cwd; pts/2's nvim cwd `BimodalLogic` = pts/3's fish cwd; and so on). This is the signature of new-tab cwd inheriting from the *previously active pane's tracked cwd*, not from `$HOME`.
- **Within a pane, nvim's cwd ≠ its own parent fish shell's cwd** in all 5 cases — even though §1 proved nvim never auto-`chdir`s. The only way this is possible is that the *shell itself* already had a different cwd than `$HOME`/its own prior state at the moment nvim was launched — i.e., the fish shell in each pane never actually "started at home"; it inherited a project directory from WezTerm's pane-spawn cwd default. Neovim faithfully inherited that (already wrong) directory via normal fork/exec and did nothing further to it — consistent with §1.
- The `wezterm cli list` "cwd" field matches each pane's **current** foreground process's cwd at the instant of the query (it was accurate for the live nvim processes above) — confirming WezTerm's OSC-7-derived cwd tracking is working as designed, and that the "staleness" problem specifically manifests **after the reporting process (nvim) exits and control returns to a shell that never re-asserts its own OSC 7**, and/or **when that stale value is used as the default `cwd` for spawning a subsequent new tab**.

### 3. OSC 7 emission code (nvim side) — confirms Feb report, plus a gap Feb did not flag

`lua/neotex/config/autocmds.lua:139-183` (unchanged in substance since Feb; only guarded by `vim.env.WEZTERM_PANE`):
- `emit_osc7()` (lines 145-153) writes `\027]7;file://<hostname><cwd>\007` via `io.write`/`io.flush`.
- Emitted on `DirChanged` (line 156), `VimEnter` (line 163), and `BufEnter` for non-terminal buffers (line 171).
- **Gap (not previously flagged)**: there is **no `VimLeave`/`VimLeavePre` autocmd that re-emits OSC 7** with the shell's original cwd before Neovim hands control back to the shell. The only `VimLeavePre` autocmd in this file (line 235) is unrelated Claude-Code task-number cleanup. This means whatever cwd Neovim last reported (which may be a `tcd`'d worktree/project path, not the shell's real starting directory) remains WezTerm's cached value for that pane **indefinitely** after Neovim exits, until the shell's real `$PWD` variable happens to change (triggering the fish hook below) or something else emits a fresh OSC 7.

### 4. Shell + WezTerm side in `~/.dotfiles/` — VERIFIED against currently-deployed config (Feb report examined the same file; contents are byte-identical)

- **Actual shell used inside WezTerm panes**: `~/.dotfiles/config/wezterm.lua:133` sets `config.default_prog = { "fish" }` — WezTerm always launches fish in new panes/tabs regardless of the outer session's `$SHELL` (this Bash tool session itself reports `$SHELL=/run/current-system/sw/bin/bash`, which is irrelevant to what runs inside WezTerm panes; do not be misled by it as this researcher initially was — it is a red herring). Fish is confirmed correct, matching the Feb report's assumption.
- `~/.config/fish/config.fish` is a home-manager-generated symlink (`readlink -f` → `/nix/store/3nkjlpwv43s676vj7pf4f074vyp2vja2-hm_config.fish`), sourced from `~/.dotfiles/config/config.fish`. Diffed the deployed store file against the dotfiles source: **byte-identical**, unchanged since Feb.
- Fish's OSC 7 hook (`config.fish:7-14`):
  ```fish
  if set -q WEZTERM_PANE
      function __wezterm_osc7 --on-variable PWD
          printf "\033]7;file://%s%s\033\\" (hostname) (pwd)
      end
      __wezterm_osc7
  end
  ```
  `--on-variable PWD` means this only fires when fish's `$PWD` *actually changes value* (i.e., on an explicit `cd`). It does **not** re-fire merely because a subprocess (nvim) exited and control returned to the prompt — this is exactly the gap identified in §3: nothing corrects WezTerm's cached cwd back to the shell's true value after nvim exits.
- `~/.config/wezterm/wezterm.lua` → `/nix/store/s9gyjwahbld1vwmaacbn8bgmbniahrrb-hm_wezterm.lua`, sourced from `~/.dotfiles/config/wezterm.lua`.
- **The actual bug-triggering keybinding**, `~/.dotfiles/config/wezterm.lua:452-457`:
  ```lua
  {
    key = "c",
    mods = "LEADER",
    action = act.SpawnTab("CurrentPaneDomain"),
  },
  ```
  No `cwd` field is specified. Per WezTerm's documented `SpawnCommand` semantics, when `cwd` is unset, WezTerm defaults the new pane's working directory to **the current pane's tracked cwd** (the OSC-7-derived value discussed above) — not `$HOME` and not a fresh shell-rc-driven default. This is the exact propagation point where a stale, nvim-derived cwd leaks into a brand-new tab that the user believes is "starting fresh."
  - Confirmed no other spawn/split keybindings exist in this file (`grep` for `SplitPane`/`SplitHorizontal`/`SpawnWindow`/`SpawnCommandInNewTab` returned nothing beyond this one `SpawnTab` binding), and no `HOME`/explicit-cwd override exists anywhere in the file.
- Contrast: the Claude Code worktree feature's own tab-spawn path, `lua/neotex/plugins/ai/claude/claude-session/terminal-commands.lua:22`, constructs `wezterm cli spawn --cwd '%s' -- %s` — it **always** passes an explicit `--cwd`, so it is immune to the stale-OSC7 fallback. This confirms the bug is specific to the plain manual "new tab" keybinding, not the Claude worktree workflow.

### 5. Independent corroboration in `~/.dotfiles` git history (NEW — strongest evidence)

`git log --since=2026-02-01 -- config/wezterm.lua config/config.fish` in `~/.dotfiles` surfaced a prior, independent fix attempt for this exact issue, 11 days after the original Feb 13 report:

- **`3af0978`** ("task 94 phase 1: replace Leader+c keybinding", 2026-02-24 09:15) replaced the `LEADER+c` action with:
  ```lua
  action = wezterm.action_callback(function(window, pane)
    -- Read the foreground process's actual CWD from /proc/PID/cwd
    -- This bypasses WezTerm's OSC 7 metadata which may be stale
    -- (e.g., after exiting Neovim, OSC 7 still reports Neovim's directory)
    local info = pane:get_foreground_process_info()
    if info and info.cwd and info.cwd ~= "" then
      window:perform_action(
        act.SpawnCommandInNewTab { domain = "CurrentPaneDomain", cwd = info.cwd },
        pane
      )
    else
      window:perform_action(act.SpawnTab("CurrentPaneDomain"), pane)
    end
  end),
  ```
  The code comment is a verbatim, independent statement of the exact root cause this report re-derives from live evidence.
- **`3d82539`** ("Revert 'task 94 phase 1: replace Leader+c keybinding'", 2026-02-24 10:09, ~54 minutes later) fully reverted it back to plain `act.SpawnTab("CurrentPaneDomain")` with **no explanatory commit body**.
- No spec artifact for this "task 94" (dotfiles-repo numbering) could be located — the dotfiles `specs/` directory has since undergone at least one vault-renumbering cycle (per the vault mechanism described in this repo's own `.claude/CLAUDE.md`), and the current task 94 in `~/.dotfiles/specs/state.json` is an unrelated, later "review_nixos_config_documentation" task. **The revert's rationale is genuinely unrecoverable from the repository as it stands.** Plausible reasons (not verified): `pane:get_foreground_process_info()` may have been unavailable/unreliable in the WezTerm version installed at the time (Feb 2026); it may return the *shell's* PID rather than a nested TUI's PID inconsistently; or it may have broken some other workflow (e.g. the Claude worktree explicit-`--cwd` spawns, though those use a different code path via `wezterm cli spawn`, not this keybinding).

### 6. Dependency check — what relies on the current (buggy) behavior

- **Nothing identified depends on OSC 7 under-reporting or on `LEADER+c` inheriting a stale cwd.** The one legitimate consumer of "new pane should start where the user currently is" is arguably desirable *only while still in the same directory nvim was in* — but that is already handled correctly by `wezterm cli spawn --cwd` in the worktree feature, which does not use this keybinding at all.
- Tab titles (`format-tab-title` handler in `wezterm.lua`, documented in `~/.dotfiles/.claude/context/project/neovim/hooks/wezterm-integration.md`) consume the OSC 7 path for **display only** — cosmetic, not functional; suppressing/fixing OSC 7 propagation does not break tab titles, it just makes them accurate again after Neovim exits.
- No LSP, telescope `find_files` scoping, session, or statusline/tabline logic in this nvim repo depends on Neovim's own cwd auto-changing (confirmed in §1 — nothing auto-changes it, so nothing can depend on that auto-change).
- The Claude worktree/session switching feature (`tcd`/`cd` call sites in §1) is a **deliberate, user-invoked, and desirable** behavior that must be preserved by any fix — a fix should target OSC 7 staleness after the fact, not the `tcd`/`cd` calls themselves.

## Decisions

1. **The Feb 13 report's "no automatic directory-changing code" finding is CONFIRMED and now live-verified** — no further investigation of Neovim's own auto-chdir behavior is warranted; this line of inquiry is closed.
2. **Root cause is definitively WezTerm-side stale OSC-7 cwd propagation**, not a Neovim bug: Neovim faithfully reports its own cwd (including deliberate `tcd`/`cd` from worktree switching) via OSC 7, but (a) never corrects that report on exit, and (b) WezTerm's `LEADER+c` new-tab keybinding trusts the stale report as the new tab's starting directory instead of the real shell's `$PWD` or `$HOME`.
3. A prior, independent fix for this exact issue exists in `~/.dotfiles` git history (`3af0978`) but was reverted (`3d82539`) without a recorded reason — any new fix should be treated as **new work informed by, not a blind reapplication of**, that commit, given the unknown revert cause.

## Recommendations

Ordered by leverage / invasiveness (lowest-risk first). All are config-only changes; none require nvim plugin changes.

1. **(Recommended, WezTerm-side, ~dotfiles repo)** Reinstate a corrected `LEADER+c` keybinding in `~/.dotfiles/config/wezterm.lua` that reads the pane's live foreground-process cwd (`pane:get_foreground_process_info()`) instead of the OSC-7-cached value, falling back to `act.SpawnTab` only if that API returns nothing. Before reapplying: (a) test with the currently-installed WezTerm version (`wezterm-0-unstable-2026-03-31`, newer than the Feb 24 attempt — the original revert reason may no longer apply), (b) test specifically the case where the foreground process is nvim itself with `tcd`'d cwd (should follow nvim, which is correct/expected), and the case where nvim has exited (should follow the shell, which is the bug being fixed). Trade-off: depends on a WezTerm Lua API (`get_foreground_process_info`) whose reliability across WezTerm versions is the leading suspect for the 2026-02-24 revert — verify it does not silently return nil/stale data before trusting it again.
2. **(Recommended, Neovim-side, this repo, complementary/independent)** Add a `VimLeavePre` (or `ExitPre`) autocmd in `lua/neotex/config/autocmds.lua` alongside the existing `emit_osc7` calls that re-emits OSC 7 using the *shell's original* cwd (e.g., cached from `$PWD` at `VimEnter` time, or simply `vim.fn.getcwd(-1, -1)` for the global/initial cwd if no `tcd` occurred) immediately before Neovim exits. This closes the staleness gap at the source regardless of whether the WezTerm-side fix (#1) is ever reapplied, and is lower-risk since it only touches this repo (no `home-manager switch` required to test — headless/interactive nvim testing suffices). Trade-off: does not fix the *tab title* going stale *while* a `tcd`'d Neovim session is still open (that reflects the live worktree cwd, which is correct/intentional), only the post-exit state.
3. **(Lowest risk, immediate mitigation, no config change)** Until either fix lands, advise the user that `LEADER+c` new tabs after using worktree/`tcd`-switching sessions may start in a stale project directory; `wezterm cli spawn --cwd ~ -- fish` (or a one-off keybinding bound to an explicit `cwd = wezterm.home_dir`) is a zero-risk manual workaround that does not require touching the shared `LEADER+c` binding.

Recommendation #1 lands in `~/.dotfiles/` (requires `home-manager switch`, out of scope for this read-only research task). Recommendation #2 lands in this nvim repo. Both are independent and can be implemented separately.

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `pane:get_foreground_process_info()` is unreliable on this WezTerm version (possible cause of the original revert) | Medium | Test interactively before committing; add the `nil`/`""` fallback already present in the reverted commit's code |
| Fixing OSC 7 staleness changes tab-title behavior in a way some user habit relies on (e.g., using stale tab title as a "last visited project" cue) | Low | No evidence found that any workflow depends on stale titles; the Claude worktree feature already uses explicit `--cwd`, independent of tab titles |
| Re-applying Recommendation #1 without knowing why it was reverted could reintroduce whatever broke | Medium | Explicitly test both the worktree-spawn path (`terminal-commands.lua`) and plain `LEADER+c` after the change, side by side, before considering it verified |

## Appendix

### Live diagnostic commands run (exact, with actual output)

```
$ cd ~ && nvim --headless -c 'redir! > /tmp/t1.txt' -c 'echo getcwd()' -c 'redir END' -c 'qa'
/tmp/t1.txt: /home/benjamin

$ cd ~ && nvim --headless /home/benjamin/.config/nvim/init.lua -c 'redir! > /tmp/t2.txt' -c 'echo getcwd()' -c 'redir END' -c 'qa'
/tmp/t2.txt: /home/benjamin

$ cd ~ && nvim --headless /home/benjamin/.dotfiles/config/wezterm.lua -c 'redir! > /tmp/t3.txt' -c 'echo getcwd()' -c 'redir END' -c 'qa'
/tmp/t3.txt: /home/benjamin

$ nvim --headless -c 'redir! > /tmp/opts.txt' -c 'set autochdir? exrc?' -c 'redir END' -c 'qa'
/tmp/opts.txt: noautochdir / noexrc

$ wezterm cli list --format json   # (run from inside this live WezTerm session, WEZTERM_PANE=4)
# see table in Findings §2 for extracted pane_id/tty_name/title/cwd

$ for pts in 0 2 3 6 7; do
    for pid in $(ps -o pid=,comm= -t pts/$pts | awk '{print $1}'); do
      comm=$(ps -o comm= -p $pid); realcwd=$(readlink -f /proc/$pid/cwd)
      echo "pts/$pts pid=$pid comm=$comm cwd=$realcwd"
    done
  done
# output: see table in Findings §2 ("fish's real cwd" / "nvim's real cwd" columns)

$ for pid in 3972 4740 15622 9846 11021; do
    tr '\0' ' ' < /proc/$pid/cmdline; readlink -f /proc/$pid/cwd
    tr '\0' '\n' < /proc/$pid/environ | grep -E "^PWD=|^WEZTERM_PANE="
  done
# confirmed: every nvim invocation had zero positional args; each PWD= differed from
# the process's own /proc/PID/cwd only where a tcd/cd had occurred inside that nvim session
```

### Grep queries used (deeper/broader than Feb report)

```bash
grep -rn "autochdir\|exrc\b" lua/
grep -rnE "vim\.cmd\([\"'](l|t)?cd |vim\.cmd\.cd|vim\.fn\.chdir|:cd |:lcd |:tcd " lua/
grep -rn "DirChanged" lua/
grep -rn "chdir" lua/
grep -rniE "rooter|project_root|find_root|root_dir|project\.nvim" lua/ | grep -v "lspconfig\|root_markers"
grep -rn "root_dir\|on_init\|workspace_folders" lua/neotex/plugins/lsp/*.lua
grep -niE "rooter|project.nvim|snacks" lazy-lock.json
grep -rniE "root|chdir|cwd" $(grep -rln "snacks" lua/neotex/plugins/)
```

### Files examined (new/re-verified this round)

- `/home/benjamin/.config/nvim/lua/neotex/config/autocmds.lua` (re-read in full around OSC 7 block, lines 90-235)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/core/worktree.lua` (all 8 cd/tcd call sites read in context, plus the `VimEnter` health-check autocmd at line 2329, plus `_resume_claude_session` at line 1975)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/tools/snacks/init.lua` (full read — confirmed explorer/picker modules disabled)
- `/home/benjamin/.config/nvim/lazy-lock.json` (confirmed `snacks.nvim` present, new since Feb; no rooter/project.nvim)
- `/home/benjamin/.dotfiles/config/config.fish` and deployed `/nix/store/3nkjlpwv43s676vj7pf4f074vyp2vja2-hm_config.fish` (byte-identical, confirmed via full diff)
- `/home/benjamin/.dotfiles/config/wezterm.lua` (keybindings section, lines 440-465, plus full-file grep for spawn/cwd)
- `/home/benjamin/.dotfiles/.claude/context/project/neovim/hooks/wezterm-integration.md` (OSC 7/OSC 1337 architecture doc; confirmed OSC 7 consumer is tab-title display via `format-tab-title`)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/claude-session/terminal-commands.lua:22` (`wezterm cli spawn --cwd`, the unaffected worktree spawn path)
- `~/.dotfiles` git history: `3af0978` (fix attempt) and `3d82539` (revert), 2026-02-24
- `~/.dotfiles/specs/state.json` (confirmed current task-94 numbering is unrelated; original fix's spec artifact not recoverable)

### What changed since the Feb 13 report

- `snacks.nvim` was added to the plugin set (confirmed via `lazy-lock.json`); investigated and ruled out as a factor (explorer/picker disabled).
- `~/.config/fish/config.fish` and `~/.config/wezterm/wezterm.lua` are now home-manager-generated Nix-store symlinks rather than directly-edited files; contents are unchanged from the `~/.dotfiles/config/` sources examined in Feb.
- A prior, independent attempt to fix this exact bug was made and reverted in `~/.dotfiles` on 2026-02-24, 11 days after the original report — this is new evidence not available to (or not found by) the Feb investigation.
- The login shell reported by `$SHELL` in a plain non-WezTerm bash tool session is `bash`, not `fish` — this is irrelevant to the actual WezTerm-pane shell (`config.default_prog = { "fish" }` forces fish in all WezTerm panes) but is flagged here since it could mislead a future investigator running diagnostics outside of WezTerm.
