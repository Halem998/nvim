-- Test suite for operations.sync module -- allow-list post-filter regression coverage
-- Run with: :TestFile
--
-- Regression guard for the allow-list post-filter defect: `provides.skills` names
-- DIRECTORIES (e.g. "skill-orchestrate") while every scanned skill file's basename is
-- the literal "SKILL.md", so a basename-only lookup silently dropped every skill. The
-- generalized post-filter in sync.lua's sync_scan() anchors on the scanned `subdir`
-- (not `filter_category`, which diverges for OpenCode agents) and falls back to a
-- basename check when the anchor does not apply. These specs build isolated scratch
-- trees rooted at vim.fn.tempname() and never read or write the real .claude/ or
-- agent-system/ trees.

describe("picker.operations.sync allow-list post-filter", function()
  local sync
  local scratch_root
  local project_dir

  before_each(function()
    sync = require("neotex.plugins.ai.claude.commands.picker.operations.sync")
    scratch_root = vim.fn.tempname()
    project_dir = vim.fn.tempname()
    pcall(vim.fn.mkdir, scratch_root, "p")
    pcall(vim.fn.mkdir, project_dir, "p")
  end)

  after_each(function()
    if scratch_root and vim.fn.isdirectory(scratch_root) == 1 then
      pcall(vim.fn.delete, scratch_root, "rf")
    end
    if project_dir and vim.fn.isdirectory(project_dir) == 1 then
      pcall(vim.fn.delete, project_dir, "rf")
    end
  end)

  local function write(path, lines)
    pcall(vim.fn.mkdir, vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile(lines, path)
  end

  local function write_core_manifest(provides)
    write(scratch_root .. "/agent-system/extensions/core/manifest.json", {
      vim.json.encode({
        name = "core",
        version = "1.0.0",
        description = "scratch core for sync_spec",
        provides = provides,
      }),
    })
  end

  it("admits directory-shaped skills entries (the defect's regression guard)", function()
    write_core_manifest({ skills = { "skill-alpha", "skill-beta" } })
    write(scratch_root .. "/agent-system/extensions/core/skills/skill-alpha/SKILL.md", { "# alpha" })
    write(scratch_root .. "/agent-system/extensions/core/skills/skill-beta/SKILL.md", { "# beta" })

    local artifacts = sync.scan_all_artifacts(scratch_root, project_dir, { base_dir = ".claude" })

    assert.equals(2, #(artifacts.skills or {}))
  end)

  it("leaves flat categories (commands, agents) unchanged", function()
    write_core_manifest({ commands = { "cmd-one.md" }, agents = { "agent-one.md" } })
    write(scratch_root .. "/agent-system/extensions/core/commands/cmd-one.md", { "# cmd" })
    write(scratch_root .. "/agent-system/extensions/core/agents/agent-one.md", { "# agent" })

    local artifacts = sync.scan_all_artifacts(scratch_root, project_dir, { base_dir = ".claude" })

    assert.equals(1, #(artifacts.commands or {}))
    assert.equals(1, #(artifacts.agents or {}))
    assert.equals("cmd-one.md", artifacts.commands[1].name)
    assert.equals("agent-one.md", artifacts.agents[1].name)
  end)

  it("preserves context's directory-shaped selection", function()
    write_core_manifest({ context = { "formats", "routing.md" } })
    write(scratch_root .. "/agent-system/extensions/core/context/formats/plan-format.md", { "# plan" })
    write(scratch_root .. "/agent-system/extensions/core/context/routing.md", { "# routing" })

    local artifacts = sync.scan_all_artifacts(scratch_root, project_dir, { base_dir = ".claude" })

    assert.equals(2, #(artifacts.context or {}))
    local names = {}
    for _, f in ipairs(artifacts.context) do
      names[f.name] = true
    end
    assert.is_true(names["plan-format.md"])
    assert.is_true(names["routing.md"])
  end)

  it("admits OpenCode agents when subdir diverges from filter_category (agent/subagents)", function()
    local opencode_extensions_dir = scratch_root .. "/.opencode/extensions/core"
    write(opencode_extensions_dir .. "/manifest.json", {
      vim.json.encode({
        name = "core",
        version = "1.0.0",
        description = "scratch core for sync_spec",
        provides = { agents = { "planner-agent.md" } },
      }),
    })
    write(scratch_root .. "/.opencode/agent/subagents/planner-agent.md", { "# planner" })

    local artifacts = sync.scan_all_artifacts(
      scratch_root,
      project_dir,
      { base_dir = ".opencode", agents_subdir = "agent/subagents" }
    )

    assert.equals(1, #(artifacts.agents or {}))
    assert.equals("planner-agent.md", artifacts.agents[1].name)
  end)

  it("still excludes a file absent from provides (allow-list is not a pass-through)", function()
    write_core_manifest({ skills = { "skill-alpha" } })
    write(scratch_root .. "/agent-system/extensions/core/skills/skill-alpha/SKILL.md", { "# alpha" })
    write(scratch_root .. "/agent-system/extensions/core/skills/skill-undeclared/SKILL.md", { "# undeclared" })

    local artifacts = sync.scan_all_artifacts(scratch_root, project_dir, { base_dir = ".claude" })

    assert.equals(1, #(artifacts.skills or {}))
    assert.equals("skill-alpha", vim.fn.fnamemodify(artifacts.skills[1].global_path, ":h:t"))
  end)
end)
