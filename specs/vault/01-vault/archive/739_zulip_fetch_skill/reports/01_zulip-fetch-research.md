# Research Report: Task #739

**Task**: 739 - Create a /zulip skill to fetch Zulip threads and dump to file
**Started**: 2026-06-17T19:00:00Z
**Completed**: 2026-06-17T19:30:00Z
**Effort**: ~1.5 hours (research + API testing)
**Dependencies**: None
**Sources/Inputs**: Live Zulip API testing, ~/.zuliprc, codebase skill/command structure exploration
**Artifacts**: specs/739_zulip_fetch_skill/reports/01_zulip-fetch-research.md
**Standards**: report-format.md

---

## Executive Summary

- The Zulip REST API `GET /messages` endpoint with a `narrow` filter on `stream` + `topic` successfully fetches all messages in a thread. Tested live against `leanprover.zulipchat.com`.
- The `~/.zuliprc` file uses an INI `[api]` section with `email`, `key`, and `site` fields; `grep` parsing is sufficient — no INI parser needed.
- Zulip URLs use a custom dot-encoding in URL fragments (`#narrow/channel/ID-stream-name/topic/topic.2C.20encoded`) that requires translating `.XX` hex pairs to `%XX` before standard URL decoding.
- The skill should be a direct-execution SKILL.md (like `skill-refresh` and `skill-literature`) with a matching command file in `.claude/commands/zulip.md`.
- Recommended implementation: pure bash script using `curl` + `jq` + `python3` (all available on this system). No new dependencies needed.

---

## Context & Scope

Researched: Zulip REST API, `.zuliprc` credential format, Zulip URL fragment encoding, existing skill/command structure in this repo.

Scope: A simple, single-purpose skill that reads a Zulip thread URL, fetches all messages, and writes formatted output (sender + date + content) to a file.

---

## Findings

### Zulip API: Message Fetching

**Endpoint**: `GET /api/v1/messages`

**Authentication**: HTTP Basic Auth using `email:api_key` from `~/.zuliprc`.

```bash
curl --user "$email:$api_key" "$site/api/v1/messages?..."
```

**Key Parameters**:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `anchor` | `newest` or message ID | Start point for fetching |
| `num_before` | `1000` (or large number) | Messages to fetch before anchor |
| `num_after` | `0` | Messages after anchor (0 = none) |
| `narrow` | URL-encoded JSON array | Filter by stream and topic |

**Narrow JSON format** (must be URL-encoded when passed as query param):
```json
[
  {"operator": "stream", "operand": "channel-name"},
  {"operator": "topic", "operand": "topic text here"}
]
```

**Live test results**:
- Successfully fetched 16 messages from `new members` stream, `Subgroups, their carrier set, and their coercion to Set` topic
- Response has `result: "success"` and `messages: [...]` array
- Each message has: `id`, `sender_full_name`, `sender_email`, `timestamp`, `content`, `subject` (= topic), `stream_id`, `display_recipient` (= stream name)

**Pagination**: The API returns up to 5000 messages per call (Zulip default). For large threads, `num_before=5000` covers typical use. For very large threads, would need to paginate using `anchor=oldest_id` — but this is an edge case the task description does not require.

**Message anchor for URL with `near/ID`**: When a URL contains `/near/604256516`, that message ID can be passed as `anchor` to start fetching from that point. The skill can use it optionally; default behavior (anchor=newest, num_before=5000) fetches the full thread regardless.

**jq output format** (tested, works):
```bash
jq '.messages[] | {sender: .sender_full_name, date: (.timestamp | todate), content: .content}'
```

### .zuliprc File Format and Parsing

**Location**: `~/.zuliprc`

**Format** (confirmed from actual file):
```ini
[api]
email=benjamin@logos-labs.ai
key=REDACTED
site=https://leanprover.zulipchat.com
```

**Parsing with grep/sed** (no INI library needed):
```bash
zuliprc="${HOME}/.zuliprc"
email=$(grep -oP '(?<=email=)\S+' "$zuliprc")
api_key=$(grep -oP '(?<=key=)\S+' "$zuliprc")
site=$(grep -oP '(?<=site=)\S+' "$zuliprc")
```

Note: The field is `key=` not `api_key=`. This was confirmed from the actual file.

### Zulip URL Format and Parsing

**URL structure**:
```
https://REALM.zulipchat.com/#narrow/channel/ID-stream-name/topic/Topic.2C.20encoded
```

**Components**:
- `base`: `https://REALM.zulipchat.com` — the API endpoint base
- `channel`: `ID-stream-name` — numeric ID prefix followed by hyphenated stream name
- `topic`: dot-encoded topic name

**Zulip's custom dot-encoding** (URL fragment cannot use % in browser URLs):
- Uses `.XX` (hex pair) instead of `%XX`
- `.2C` = comma, `.20` = space, `.3A` = colon, `.28` = `(`, `.29` = `)`
- Note: regular `-` hyphens in the topic are literal hyphens, NOT encoding

**Parsing algorithm**:
```bash
# Extract base URL (strip fragment and path)
base=$(echo "$url" | grep -oP 'https?://[^/#]+')

# Extract channel segment (between /channel/ and /topic/ or end)
channel_raw=$(echo "$url" | grep -oP '(?<=#narrow/channel/)[^/]+')

# Extract topic segment (after /topic/)  
topic_raw=$(echo "$url" | grep -oP '(?<=/topic/)[^/]+')

# Strip numeric ID prefix from channel (e.g., "113489-new-members" -> "new-members")
channel_slug=$(echo "$channel_raw" | sed 's/^[0-9]*-//')

# Convert hyphen-stream-slug to space-separated stream name
# Note: Zulip slugs just replace spaces with hyphens. Numbers/punctuation in stream names
# are more complex, but this handles the common case.
stream_name=$(echo "$channel_slug" | tr '-' ' ')

# Decode topic: replace .XX dot-encoding with %XX, then URL-decode
topic=$(python3 -c "
import re, sys
from urllib.parse import unquote
raw = sys.argv[1]
pct = re.sub(r'\.([0-9A-Fa-f]{2})', r'%\1', raw)
print(unquote(pct))
" "$topic_raw")

# Extract optional near/ID anchor
near_id=$(echo "$url" | grep -oP '(?<=/near/)[0-9]+' || echo "")
```

**Alternative: stream by ID** (more reliable than name-parsing): The channel URL segment contains the numeric stream ID (`113489`). We can use the stream ID directly in the narrow:
```json
[{"operator": "stream", "operand": 113489}, {"operator": "topic", "operand": "topic"}]
```
However, the API also accepts string stream names, so either approach works.

**Edge cases**:
- URL may use `stream` instead of `channel` (older Zulip format): `#narrow/stream/name/topic/...`
- URL may have no topic (just a stream link): must handle gracefully
- Topic names with `.` already in them are ambiguous with dot-encoding — unlikely in practice

### Existing Skill/Command Structure

**Skill files**: `.claude/skills/skill-NAME/SKILL.md`

**Command files**: `.claude/commands/NAME.md`

**Skill SKILL.md frontmatter**:
```yaml
---
name: skill-NAME
description: Brief description
allowed-tools: Bash, AskUserQuestion  # (and/or Read, Write, Edit, Glob, Grep)
---
```

**Command file frontmatter**:
```yaml
---
description: Brief description for /NAME command
allowed-tools: Skill  # commands typically just delegate to a skill
argument-hint: <arg1> [optional-arg]
model: opus  # optional
---
```

**Direct execution skills** (like skill-refresh, skill-literature): The skill body IS the implementation. Steps are written as prose with embedded bash snippets. The skill executes inline — no subagent dispatch.

**AskUserQuestion**: Used when interactive input is needed (e.g., "where should I pipe the output?"). The AskUserQuestion tool presents an interactive prompt and returns the user's selection.

**Pattern for output-path prompting** (when no path given):
```json
{
  "question": "Where should I write the Zulip thread output?",
  "options": [
    {"label": "stdout (print to terminal)", "description": "Display thread inline"},
    {"label": "Enter a file path", "description": "Specify output path"}
  ]
}
```

### Recommended Implementation Approach

**Files to create**:
1. `.claude/skills/skill-zulip/SKILL.md` — direct execution skill
2. `.claude/commands/zulip.md` — command entry point

**Skill execution flow**:

1. **Parse args**: Extract `<zulip-url>` and optional `[output-path]` from `$ARGUMENTS`
2. **Read credentials**: Parse `~/.zuliprc` for `email`, `key`, `site`
3. **Parse URL**: Extract `base`, `stream_name` (or stream ID), `topic`, optional `near_id`
4. **If no output path**: Ask user via AskUserQuestion (options: stdout, enter path)
5. **Build narrow JSON**: Construct the `narrow` parameter
6. **Fetch messages**: `curl --user "$email:$api_key" "..."`
7. **Format with jq**: Extract `sender_full_name`, `timestamp | todate`, `content`
8. **Write output**: Either to file or stdout

**curl + jq command**:
```bash
narrow=$(python3 -c "
import json, sys
print(json.dumps([
  {'operator': 'stream', 'operand': sys.argv[1]},
  {'operator': 'topic', 'operand': sys.argv[2]}
]))
" "$stream_name" "$topic")

narrow_encoded=$(python3 -c "from urllib.parse import quote; import sys; print(quote(sys.argv[1]))" "$narrow")

curl -s --user "$email:$api_key" \
  "${site}/api/v1/messages?anchor=newest&num_before=5000&num_after=0&narrow=${narrow_encoded}" \
| jq '[.messages[] | {sender: .sender_full_name, date: (.timestamp | todate), content: .content}]'
```

**Output to file vs stdout**:
```bash
if [ -n "$output_path" ]; then
  ... | jq '...' > "$output_path"
  echo "Thread written to: $output_path"
else
  ... | jq '...'
fi
```

**Tool availability** (confirmed on this system):
- `curl`: 8.20.0 — available
- `jq`: 1.8.1 — available
- `python3`: 3.13.13 — available (needed for URL encoding/decoding)

---

## Decisions

- **Direct execution skill** (not subagent dispatch): Consistent with `skill-refresh` and `skill-literature` patterns. The task is simple enough to run inline.
- **python3 for URL encoding**: `bash`-only URL encoding of JSON strings with spaces/commas is error-prone. `python3 -c` one-liners are cleaner and more robust.
- **Stream name from URL slug**: Parse stream name by stripping numeric ID prefix and converting hyphens to spaces. This handles the common case. If it fails, the API returns a clear error.
- **num_before=5000**: Fetches effectively all messages in most threads. The Zulip API allows up to 5000 per call. Very large threads are an edge case not required by the task.
- **jq output format**: Array of objects `[{sender, date, content}]` — readable, parseable, includes all required fields. The task says "formatted with jq" so this is appropriate.
- **AskUserQuestion for missing output path**: Consistent with the interactivity pattern used across all skills in this repo.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Stream name slug parsing fails (special chars in name) | Use stream ID from URL instead of name; or show error and let user correct |
| Thread has >5000 messages | Document limitation; implement pagination only if requested |
| API key or credentials missing | Check `~/.zuliprc` exists before proceeding; show clear error |
| Zulip instance uses `stream` not `channel` in URL | Handle both URL patterns in parser |
| Topic with `.` chars before 2-digit hex may mis-decode | Accept this edge case; real Zulip topics rarely have this pattern |
| `python3` not available | Check with `which python3`; fall back to `perl -MURI::Escape` if needed |
| Output file path doesn't exist (parent dir missing) | Check with `mkdir -p $(dirname "$output_path")` before writing |

---

## Context Extension Recommendations

- **Topic**: Zulip API integration pattern
- **Gap**: No existing context for fetching Zulip threads or using `.zuliprc` credentials
- **Recommendation**: After implementation, the skill itself serves as the reference. No separate context file needed given task scope.

---

## Appendix

### API Test Results

```
GET /api/v1/messages?anchor=newest&num_before=5&num_after=0&narrow=[stream+topic]
Status: 200, result: "success"
Messages fetched: 16 (full thread)
Fields confirmed: sender_full_name, timestamp, content, display_recipient, subject
```

### URL Parsing Test

```
Input:  https://leanprover.zulipchat.com/#narrow/channel/113489-new-members/topic/Subgroups.2C.20their.20carrier.20set.2C.20and.20their.20coercion.20to.20Set
base:   https://leanprover.zulipchat.com
channel_raw: 113489-new-members
stream: new members
topic:  Subgroups, their carrier set, and their coercion to Set (correctly decoded)
```

### .zuliprc Format Confirmed

```ini
[api]
email=benjamin@logos-labs.ai
key=<api_key>
site=https://leanprover.zulipchat.com
```

### References

- Zulip REST API: https://zulip.com/api/get-messages
- Zulip narrow operators: https://zulip.com/api/construct-narrow
- Existing skill patterns: `.claude/skills/skill-refresh/SKILL.md`, `.claude/skills/skill-literature/SKILL.md`
- Command patterns: `.claude/commands/refresh.md`, `.claude/commands/literature.md`
