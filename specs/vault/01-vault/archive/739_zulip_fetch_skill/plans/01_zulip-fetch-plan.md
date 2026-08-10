# Implementation Plan: Task #739

- **Task**: 739 - Create /zulip skill to fetch Zulip threads and dump to file
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/739_zulip_fetch_skill/reports/01_zulip-fetch-research.md
- **Artifacts**: plans/01_zulip-fetch-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a direct-execution skill and matching command file that fetches Zulip thread messages via the REST API and writes formatted JSON output to a file. The skill parses a Zulip URL to extract channel/topic, authenticates using ~/.zuliprc credentials, fetches messages via curl, and formats output with jq. Research confirmed all API patterns, URL encoding, and credential parsing work on this system.

### Research Integration

Key findings from the research report:
- Zulip GET /api/v1/messages with narrow=[stream,topic], anchor=newest, num_before=5000 fetches full threads (tested live, 16 messages returned successfully)
- ~/.zuliprc uses INI [api] section with email=, key=, site= fields; grep -oP parsing is sufficient
- Zulip URLs use custom dot-encoding (.XX -> %XX) in URL fragments requiring python3 for decoding
- curl 8.20, jq 1.8.1, python3 3.13 all available on this system
- Direct execution skill pattern (like skill-refresh, skill-literature) is appropriate

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly relate to this task. This is a standalone utility skill for fetching Zulip threads.

## Goals & Non-Goals

**Goals**:
- Create a working /zulip command that fetches a Zulip thread given its URL
- Output formatted JSON (sender, date, content) to a user-specified file
- Handle both `channel` and `stream` URL formats
- Prompt user for output path when not provided via AskUserQuestion

**Non-Goals**:
- Markdown conversion of message content (raw JSON only, per task description)
- Pagination for threads exceeding 5000 messages
- Multi-server support (single ~/.zuliprc assumed)
- Posting or replying to Zulip threads

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Stream name slug parsing fails for special chars | M | L | Use numeric stream ID from URL as primary operand; fall back to name |
| ~/.zuliprc missing or malformed | H | L | Check file exists and all 3 fields parse before API call; show clear error |
| Dot-encoding ambiguity with literal dots in topic | L | L | Accept edge case; real Zulip topics rarely have .XX hex-like patterns |
| python3 not available on some systems | M | L | Check `which python3` at skill startup; document requirement |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Create Skill SKILL.md [COMPLETED]

**Goal**: Create the complete direct-execution skill file with URL parsing, credential reading, API fetching, and output formatting.

**Tasks**:
- [x] Create `.claude/skills/skill-zulip/SKILL.md` with frontmatter (name, description, allowed-tools: Bash, AskUserQuestion) *(completed)*
- [x] Implement Step 1: Parse arguments -- extract `<zulip-url>` and optional `[output-path]` from command input *(completed)*
- [x] Implement Step 2: Validate prerequisites -- check ~/.zuliprc exists, check curl/jq/python3 available *(completed)*
- [x] Implement Step 3: Read credentials -- parse email, key, site from ~/.zuliprc using grep -oP *(completed)*
- [x] Implement Step 4: Parse Zulip URL -- extract base URL, channel segment (handle both `channel/` and `stream/` prefixes), topic segment, optional near/ID anchor *(completed)*
- [x] Implement Step 5: Decode URL components -- strip numeric ID prefix from channel slug, convert hyphens to spaces for stream name, decode dot-encoded topic via python3 *(completed)*
- [x] Implement Step 6: Prompt for output path if not provided -- use AskUserQuestion with options for stdout display or file path entry *(completed)*
- [x] Implement Step 7: Build narrow JSON and fetch messages -- construct narrow parameter with python3 json.dumps, URL-encode with urllib.parse.quote, execute curl with Basic Auth *(completed)*
- [x] Implement Step 8: Format and write output -- pipe through jq to extract sender, date (timestamp | todate), content; write to output path or display inline *(completed)*
- [x] Implement Step 9: Report result -- echo confirmation with message count and output location *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-zulip/SKILL.md` - Create new file (complete skill definition)

**Verification**:
- SKILL.md has valid YAML frontmatter with name, description, allowed-tools
- All 9 execution steps are present and contain embedded bash snippets
- URL parsing handles both `channel/` and `stream/` URL patterns
- Credential parsing uses correct field name `key=` (not `api_key=`)
- jq format produces `{sender, date, content}` objects

---

### Phase 2: Create Command File [COMPLETED]

**Goal**: Create the command entry point that delegates to skill-zulip.

**Tasks**:
- [x] Create `.claude/commands/zulip.md` with frontmatter (description, allowed-tools, argument-hint, model) *(completed)*
- [x] Write command body with syntax section showing `/zulip <zulip-url> [output-path]` *(completed)*
- [x] Include examples section with sample Zulip URLs *(completed)*
- [x] Add execution section that invokes `skill: skill-zulip` with args passthrough *(completed)*

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/commands/zulip.md` - Create new file (command definition)

**Verification**:
- Command file has valid YAML frontmatter
- argument-hint matches expected usage pattern
- Execution section correctly references skill-zulip
- Description is concise and matches SKILL.md description

---

### Phase 3: Verification and Testing [COMPLETED]

**Goal**: Verify the skill works end-to-end with a live Zulip URL and confirm all files are correctly structured.

**Tasks**:
- [x] Verify SKILL.md frontmatter parses correctly (no YAML syntax errors) *(completed)*
- [x] Verify command file frontmatter parses correctly *(completed)*
- [x] Test URL parsing logic with the known test URL: `https://leanprover.zulipchat.com/#narrow/channel/113489-new-members/topic/Subgroups.2C.20their.20carrier.20set.2C.20and.20their.20coercion.20to.20Set` *(completed: stream_name="new members", topic="Subgroups, their carrier set, and their coercion to Set")*
- [x] Verify credential parsing reads correct values from ~/.zuliprc *(completed)*
- [x] Test full API call and jq formatting against a live Zulip thread *(completed: 19 messages fetched, API result=success, 15135 bytes written)*
- [x] Confirm output file is written correctly when output-path is provided *(completed: /tmp/zulip-test-output.json verified)*

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- None (verification only; may fix issues in Phase 1/2 files if found)

**Verification**:
- Live API call returns messages successfully
- jq output contains sender, date, content fields
- Output file is written to specified path
- Error messages appear for missing ~/.zuliprc or invalid URL

## Testing & Validation

- [ ] SKILL.md has valid YAML frontmatter (name, description, allowed-tools)
- [ ] Command file has valid YAML frontmatter (description, allowed-tools, argument-hint)
- [ ] URL parsing extracts stream name and topic from known test URL
- [ ] Credential parsing reads email, key, site from ~/.zuliprc
- [ ] curl API call returns `result: "success"` with messages array
- [ ] jq formatting produces readable {sender, date, content} objects
- [ ] Output is written to file when output-path is provided
- [ ] AskUserQuestion prompts when output-path is omitted

## Artifacts & Outputs

- `.claude/skills/skill-zulip/SKILL.md` - Direct execution skill definition
- `.claude/commands/zulip.md` - Command entry point
- `specs/739_zulip_fetch_skill/plans/01_zulip-fetch-plan.md` - This plan

## Rollback/Contingency

To revert: delete the two created files:
```bash
rm -rf .claude/skills/skill-zulip/
rm -f .claude/commands/zulip.md
```
No existing files are modified, so rollback is a clean removal.
