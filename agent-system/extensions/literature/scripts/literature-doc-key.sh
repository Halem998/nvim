#!/usr/bin/env bash
# literature-doc-key.sh - Single sourced anchor for the index-entry -> FTS-key derivation
#
# Usage (sourced):
#   source literature-doc-key.sh
#   key="$(derive_doc_key "$path")"     # derive one key from one index-entry .path value
#
# Usage (CLI, non-bash consumers e.g. SKILL.md, tests):
#   literature-doc-key.sh --list-keys <index.json>
#     Prints one derived key per line (deduplicated), covering every entry in the index:
#     the path-derived directory key when .path is "sources/"-prefixed, falling back to
#     the entry's own .id when it is not (or is absent). This is the UNION set consumed
#     by get_project_doc_ids() in literature-search.sh -- see Decision C of
#     specs/077_unify_literature_global_index_schema/plans/01_unify-global-index-fts-namespace.md.
#
# THE INVARIANT (read this before touching any id in this extension):
#   The literature corpus has two independent id namespaces that have drifted apart:
#     - index.json's curated `.id` field (human-facing, e.g. "blackburn_2002_book")
#     - chunks_data.doc_id in .literature.db (machine-authoritative, fixed at ingest/chunk
#       time, e.g. "blackburn_2002" -- the bare sources/<dir>/ directory name)
#   Renaming a curated `.id` to match its FTS doc_id (or vice versa) is the specific
#   operation known to break `literature-search.sh --toc`: `--toc` addresses FTS directly
#   by doc_id, so an id that no longer matches any chunks_data row returns [] where it
#   used to return real chunks. This was discovered by hand (corpus commit history) and by
#   execution, not by reading code -- reading the code did not reveal it.
#   THE FIX IS NEVER TO RENAME. Instead: the directory-name component of a `sources/`-
#   prefixed index entry's `.path` field IS the FTS doc_id. Any reader that must address
#   FTS derives its key from `.path` this way, falling back to `.id` only when `.path` is
#   absent or not `sources/`-prefixed. `.id` stays free to be the curated, human-facing
#   name; `--toc` and `--read` are untouched by construction because no id is ever rewritten.
#
#   This mirrors the four existing inline `prefix = "sources/"` derivation sites already
#   in literature-search.sh (load_fidelity_map() and its three siblings), which are
#   deliberately left in place as precedent and are not refactored to call this script --
#   see the plan's Non-Goals. This file is the single NEW sourced anchor for callers that
#   do not already inline the derivation, and the sole CLI-callable form for non-bash
#   consumers.
#
# Derivation rule:
#   Given an index-entry `.path` value:
#     - if it starts with "sources/", the key is the first path component after that
#       prefix (i.e. the directory name): "sources/blackburn_2002/" -> "blackburn_2002",
#       "sources/blackburn_2002/chunk_0001.md" -> "blackburn_2002"
#     - otherwise (path absent, null, or not "sources/"-prefixed): no path-derived key;
#       callers fall back to the entry's own `.id`.

set -euo pipefail

# derive_doc_key <path>
# Prints the path-derived key on stdout, or nothing (empty output, exit 0) if the path is
# absent/null/not "sources/"-prefixed. Callers combine this with a fallback to `.id`.
derive_doc_key() {
  local path="${1:-}"
  case "$path" in
    sources/*)
      local rest="${path#sources/}"
      printf '%s\n' "${rest%%/*}"
      ;;
    *)
      return 0
      ;;
  esac
}

# --- CLI mode ---
# Only runs when invoked directly (not when sourced), so `source literature-doc-key.sh`
# from another script never triggers argument parsing or a usage error.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  if [ "${1:-}" != "--list-keys" ] || [ -z "${2:-}" ]; then
    echo "Usage: literature-doc-key.sh --list-keys <index.json>" >&2
    exit 1
  fi
  index_file="$2"
  if [ ! -f "$index_file" ]; then
    echo "literature-doc-key.sh: index file not found: $index_file" >&2
    exit 1
  fi
  # Union of path-derived key and .id for every entry (children included) -- the same
  # union get_project_doc_ids() emits, deduplicated, one key per line.
  jq -r '
    .entries[]? |
    (
      (if (.path? // "" | tostring | startswith("sources/"))
        then (.path | ltrimstr("sources/") | split("/")[0])
        else empty
       end),
      (.id // empty)
    )
  ' "$index_file" | sort -u
fi
