# Multi-Instance Lean-LSP Optimization Guide

**Purpose**: Reduce MCP AbortError -32001 timeouts when running multiple Claude Code sessions

---

## Overview

Running multiple concurrent Claude Code sessions with Lean-LSP MCP tools can cause AbortError -32001 timeouts due to resource contention.

### Root Cause

Multiple concurrent lean-lsp-mcp instances via STDIO transport create:
- Memory pressure from parallel `lake build` processes (can exceed 16GB)
- File locking contention on `.olean` files in shared `.lake/` cache
- CPU saturation from parallel compilation workers
- Diagnostic processing delays under concurrent load

---

## The Build Guard

`lake-build-guard.sh` is the enforceable mechanism that supersedes the manual choreography this
guide used to recommend. It sits in front of `lake build` and provides, mechanically, what the
old advice to pause activity in several other concurrent sessions tried to achieve by human
coordination:

- **flock-based serialization**: concurrent `build` invocations against the same Lean package
  contend on a single lock file under that project's `.lake/` directory. Only one `lake build`
  runs at a time per package; every other caller waits.
- **Result sharing**: a waiter does not necessarily run a redundant build of its own. If a very
  recent build result already exists for the same project, the guard replays that prior result
  instead — a staleness policy decides whether the existing result is fresh enough to reuse or
  whether a fresh build is required.
- **PSI + swap preflight**: before starting a build, the guard reads the kernel's pressure-stall
  information and current swap usage. Under real memory pressure it either proceeds with a
  warning or, with `--defer-on-pressure`, refuses to start a new build until pressure subsides.
- **Opt-in memory bounding**: `--memory-bound` runs the build inside a `systemd-run --user
  --scope` cgroup with configurable `--memory-high` / `--memory-max` limits, so a runaway
  elaboration cannot alone drive the machine into swap. When user-scope cgroup delegation is
  unavailable on the host, the guard degrades audibly — it says so on stderr and still runs the
  build unbounded — rather than either silently skipping the bound or hard-failing.
- **Silent when there is no conflict**: on the common, uncontended path the guard emits zero
  bytes of its own output. This is what makes it safe to drop into an existing `$(... 2>&1)`
  command substitution at a call site (see `lean-sorry-census.sh`'s `--cross-check` branch) --
  the guard does not corrupt output a caller is already parsing.

## Invoking the guard

Three subcommands, and when a caller reaches for each:

- **`status`** — a read-only view of current lock/pressure state. Use this when a caller wants to
  know whether a build is already in flight or the machine is under memory pressure, without
  triggering anything.
- **`preflight`** — "should I start a build now?" A resource check only; it does not itself run
  `lake build`.
- **`build`** — runs one build, serialized against other concurrent `build` invocations for the
  same project and optionally memory-bounded. `build` passes `lake`'s own exit code through
  untouched in the normal case, and reserves a small band (75-79) for guard-specific outcomes
  (lock-wait timeout, deferred-on-pressure, usage error, no Lean project found, missing
  capability). A caller that needs to disambiguate a guard-specific outcome from one of `lake`'s
  own exit codes calls `status` / `preflight` separately rather than trying to decode `build`'s
  exit status into a full taxonomy.

## Detached builds and the guard: they must land together

Detaching a `lake build` so it survives past the current 10-minute foreground timeout cap is a
correct fix for a real problem: a build that is killed by the cap caches no `.olean` file for the
module it was mid-way through, so a retry restarts elaboration from that identical module rather
than resuming past it — a livelock under repeated retries. But today, that 10-minute cap is also
the only thing bounding how long a *redundant* concurrent build survives. If detachment ships
without serialization, removing the cap does not remove the redundant-build problem — it makes it
worse: instead of ten duplicate builds each dying at the ten-minute mark, ten duplicate builds now
run to full completion, each one holding a multi-gigabyte `lean` process for its entire duration.
Detached invocation and the guard's serialization are not independent improvements that can be
adopted one at a time; adopting either half alone makes the measured memory situation strictly
worse than today's baseline. See `operations/long-builds.md` for the detached-build mechanism and
passive progress-checking approach (that document covers the foreground-cap livelock in detail;
no claim is made here about its specific section headings or content, since it may land before or
after this guide depending on dispatch order).

## What an operator can still do by hand

The guard automates the coordination this guide used to ask operators to do manually, but manual
diagnosis is still a useful fallback when contention is observed:

- Check `ps`/`htop` (see Monitoring below) to see how many `lean`/`lake` processes are actually
  running and how much memory they hold.
- If contention is confirmed and no guard-mediated build is in flight, reducing the number of
  concurrent Lean sessions remains a valid manual mitigation — demoted here from primary remedy
  (as it was before the guard existed) to fallback.

### Configure Environment Variables

Add to `~/.claude.json`:

```json
{
  "mcpServers": {
    "lean-lsp": {
      "command": "uvx",
      "args": ["lean-lsp-mcp"],
      "env": {
        "LEAN_LOG_LEVEL": "WARNING",
        "LEAN_PROJECT_PATH": "/path/to/lean-project"
      }
    }
  }
}
```

**Benefits**:
- `LEAN_LOG_LEVEL: "WARNING"` reduces log I/O overhead
- Explicit `LEAN_PROJECT_PATH` prevents detection overhead

This is MCP-transport tuning, not a build-concurrency remedy — the guard does not supersede it,
and it remains recommended independently of guard adoption.

---

## Monitoring

### Check Resource Usage

```bash
# Memory usage by lean processes
ps aux --sort=-%mem | grep -E '(lean|lake)' | head -10

# CPU usage
htop -p $(pgrep -d, -f 'lean|lake')
```

### Identify Contention

If you see these symptoms, reduce concurrent sessions:
- lean-lsp calls consistently exceeding 30 seconds
- Memory usage spiking above 12GB
- Multiple `lake build` processes running simultaneously
- Diagnostic messages timing out repeatedly

---

## Measured Results

The following is one illustrative measurement taken on one machine during a period of
concurrent-build contention, not a predictive ceiling to be hardcoded as an assumption or
generalized to other hardware: 16 concurrent `lean` processes were observed holding 29.9 GB RSS
on a 30 GB machine, with 29 GB of swap in use and 3.1 GB available. This is the figure that
motivated the guard's memory-pressure preflight and opt-in memory bounding; it replaces an
earlier claim on this page that memory usage stayed under an eight-gigabyte ceiling (versus
sixteen-plus gigabyte spikes) and predicted a timeout-frequency reduction in the sixty-to-eighty
percent range with diagnostics completing within 30s (vs 60s+) — neither of those predictions was
backed by a measurement, and the eight-gigabyte ceiling claim is directly contradicted by the
29.9 GB figure above.

---

## Why there is no lean lifecycle hook

Routing the census's `--cross-check` build through the guard raised, and this section settles,
the question of whether the `lean` extension should also register a lifecycle hook that would run
the guard (or check its status) automatically around Lean work. The decision is **no hook**, for
four reasons:

1. **Hook resolution keys strictly on `task_type == "lean4"`.** `skill_get_extension_dir` selects
   which extension's hooks fire based only on the current task's `task_type`. A `general`- or
   `meta`-typed task that happens to be working inside a Lean repository — including the task
   that wrote this very section — would never trigger a lean-registered hook. A hook here would
   protect exactly the narrow slice of work already typed `lean4` and nothing else, which is not
   where an untyped or mistyped task doing Lean-adjacent work actually needs protecting.
2. **Hooks are non-blocking by design.** A lifecycle hook that exits non-zero has that failure
   caught and downgraded to a `[skill-base] WARNING`; it cannot stop a skill from proceeding. A
   preflight hook here would imply an enforced refusal — "no unguarded build" — that the hook
   mechanism is structurally unable to deliver. Advertising protection a hook cannot actually
   enforce is worse than advertising none.
3. **The enforceable mechanism already exists and needs no hook to be reached.** The guard's own
   PSI/swap preflight and `--defer-on-pressure` are directly invocable (`lake-build-guard.sh
   preflight`, or `build --defer-on-pressure`) by any caller that wants pressure-aware behavior,
   with no lifecycle-hook plumbing required to get there.
4. **Any actual refusal obligation belongs in contract text**, not in this scope. If a future
   change decides an agent contract should refuse to run an unguarded `lake build`, that belongs
   in the relevant agent/skill/rule prose (see the Non-Goals above on the eight files this task
   deliberately does not touch), which — unlike a hook — is not non-blocking and can genuinely be
   read and honored by an agent before acting.

Since no hook is added, the question of whether such a hook should self-filter on `operation`
(research vs. plan vs. implement) is moot and is recorded as such rather than left silently
unanswered. For the record, if a lean lifecycle hook is ever added later, `operation` is passed to
a hook as a positional argument rather than filtered by the dispatch mechanism itself, so a naive
implementation would fire for every operation including research unless the hook body itself
chose to filter.

**`manifest.json` therefore requires no edit.** `jq 'has("hooks")' agent-system/extensions/lean/manifest.json`
returns `false` and `provides.hooks` is `[]`; both were re-verified at implementation time against
the two live reference implementations that DO register hooks (`nix`, with a top-level `hooks`
object carrying `preflight` and `context_injection`; `nvim`, with `context_injection` only) to
confirm the decision is made against the real contract shape, not a summary of it. Leaving
`manifest.json` unmodified is the recorded outcome of this section, not an oversight.
