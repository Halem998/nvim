#!/usr/bin/env bash
# bootstrap-harvest-history.sh - One-shot, read-only mine of the durable ~/.claude/history.jsonl
# prompt spine into a per-session JSONL row. Unlike the transcript corpus (30-day rolling
# retention), history.jsonl is global and outlives the transcript retention cliff, so this pass
# is not itself time-sensitive -- it can be regenerated later without urgency. It is produced
# alongside the transcript pass here purely for a single coherent harvest run.
#
# READ-ONLY CONTRACT (binding): this script only reads the given history.jsonl path (default
# ~/.claude/history.jsonl). It never writes, deletes, moves, or truncates it. Output is JSONL on
# stdout; diagnostics go to stderr.
#
# WHOLE-STREAM PARSE REQUIREMENT (binding, empirically necessary): history.jsonl contains at
# least one record with a raw, unescaped embedded newline (pasted multi-line content in the
# `display` field), which is invalid JSON at the byte level and breaks any parser that assumes
# one JSON value per physical line (`sed -n '{n}p'`, `wc -l`-driven extraction, naive
# `split('\n')`). A plain whole-stream `jq -c '.'` pass was tested against the live file and
# found insufficient on its own: it correctly avoids the naive line-split failure mode, but jq
# has no native skip-and-continue for a fatal mid-stream parse error -- it aborts (non-zero
# exit) at the FIRST bad record and drops everything after it. This script instead uses Python's
# `json.JSONDecoder().raw_decode`, which supports true skip-and-continue: on a decode failure it
# advances past the bad record (to the next newline) and keeps decoding the rest of the file.
# Decode failures are counted and reported explicitly on stderr -- never silently dropped and
# never a reason to abort the whole pass.
#
# SELF-EXCLUSION (binding, applies here too even though history.jsonl carries no is_error
# signal to drift): the harvest's own current session logs its own prompt(s) into
# history.jsonl while it runs. Excluded via $CLAUDE_CODE_SESSION_ID if set, so the dataset's
# self-exclusion guarantee ("the excluded sessionId appears zero times across all dataset
# files") holds for the history spine as well as the transcript pass, not just the latter.
#
# Usage:
#   bootstrap-harvest-history.sh [history_jsonl_path]
#
# Emits one JSONL row per sessionId (or a `__no_session_id__` sentinel row for records that lack
# one, rather than dropping them), excluding the self session:
#   session_id, repo, prompt_count, first_timestamp, last_timestamp

set -uo pipefail

HISTORY_FILE="${1:-$HOME/.claude/history.jsonl}"
NO_SESSION_SENTINEL="__no_session_id__"
SELF_SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"

if [ ! -f "$HISTORY_FILE" ]; then
  echo "FATAL: history.jsonl not found: $HISTORY_FILE" >&2
  exit 1
fi

python3 - "$HISTORY_FILE" "$NO_SESSION_SENTINEL" "$SELF_SESSION_ID" <<'PYEOF'
import json
import sys
from collections import defaultdict

path, sentinel, self_session_id = sys.argv[1], sys.argv[2], (sys.argv[3] if len(sys.argv) > 3 else "")

decoder = json.JSONDecoder()
with open(path, "r", encoding="utf-8", errors="replace") as f:
    data = f.read()

idx = 0
n = len(data)
ok = 0
fail = 0
self_excluded = 0

sessions = defaultdict(lambda: {"prompt_count": 0, "repo": None, "first_timestamp": None, "last_timestamp": None})

while idx < n:
    while idx < n and data[idx] in " \t\r\n":
        idx += 1
    if idx >= n:
        break
    try:
        obj, end = decoder.raw_decode(data, idx)
        ok += 1
        idx = end
    except json.JSONDecodeError:
        fail += 1
        nxt = data.find("\n", idx + 1)
        if nxt == -1:
            break
        idx = nxt + 1
        continue

    if not isinstance(obj, dict):
        continue

    session_id = obj.get("sessionId") or sentinel
    if self_session_id and session_id == self_session_id:
        self_excluded += 1
        continue
    repo = obj.get("project")
    ts = obj.get("timestamp")

    row = sessions[session_id]
    row["prompt_count"] += 1
    if repo is not None and row["repo"] is None:
        row["repo"] = repo
    if ts is not None:
        if row["first_timestamp"] is None or ts < row["first_timestamp"]:
            row["first_timestamp"] = ts
        if row["last_timestamp"] is None or ts > row["last_timestamp"]:
            row["last_timestamp"] = ts

for session_id, row in sessions.items():
    out = {
        "session_id": session_id,
        "repo": row["repo"],
        "prompt_count": row["prompt_count"],
        "first_timestamp": row["first_timestamp"],
        "last_timestamp": row["last_timestamp"],
    }
    print(json.dumps(out))

distinct_repos = len({r["repo"] for r in sessions.values() if r["repo"] is not None})
total_prompts = sum(r["prompt_count"] for r in sessions.values())

print(
    f"bootstrap-harvest-history.sh: records_ok={ok} records_decode_failed={fail} "
    f"self_excluded_records={self_excluded} sessions_emitted={len(sessions)} "
    f"distinct_repos={distinct_repos} total_prompt_count={total_prompts}",
    file=sys.stderr,
)
PYEOF
