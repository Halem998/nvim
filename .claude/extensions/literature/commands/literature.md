---
description: Manage specs/literature/ — scan, convert PDFs/DJVUs, maintain index.json, and discover sources
allowed-tools: Skill
argument-hint: [N|"query"|~/path.pdf|~/dir/|--validate|--index FILE|--convert [FILE]]
---

# Command: /literature

**Purpose**: Manages `specs/literature/` via two modes: (A) Discover — find academic sources by task number or keywords; (B) Integrate — scan/convert PDFs/DJVUs and maintain `index.json`. Also supports `--validate` for index consistency checks.
**Layer**: 2 (Command File - Argument Parsing Agent)
**Delegates To**: skill-literature (direct execution)

**Input**: $ARGUMENTS

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Classify arguments into one of three top-level modes:

    **Mode Detection Priority** (first match wins):

    1. `--validate` flag anywhere -> Validate mode (kept as-is)
    2. `--index FILE` -> Index mode (kept as-is, integrate path)
    3. `--convert [FILE]` -> Convert mode (kept as-is, integrate path)
    4. No arguments, OR path-like argument -> Integrate mode (Mode B)
    5. Numeric argument (task number), OR text without path characters -> Discover mode (Mode A)

    **Path-like detection**: An argument is path-like if it:
    - Starts with `/`, `~`, or `.`
    - Contains `.pdf` or `.djvu` (case-insensitive)
    - Contains a `/` separator

    **Numeric detection**: An argument is numeric if it matches `^[0-9]+$`

    **Text-only detection**: An argument is a discover query if it:
    - Is NOT path-like
    - Is NOT a flag (does not start with `--`)

    ```
    sub_mode = "integrate"  # default (Mode B)

    args = $ARGUMENTS.split()

    if "--validate" in args:
      sub_mode = "validate"
    elif "--index" in args:
      sub_mode = "index"
      file = extract_arg_after("--index", args) or ""
    elif "--convert" in args:
      sub_mode = "convert"
      file = extract_arg_after("--convert", args) or ""
    elif len(args) == 0:
      sub_mode = "integrate"  # bare /literature -> status/scan
    else:
      # Check first non-flag argument for path-like vs. discover
      first_arg = first_non_flag(args)

      is_path_like = (
        first_arg.startswith("/") or
        first_arg.startswith("~") or
        first_arg.startswith(".") or
        ".pdf" in first_arg.lower() or
        ".djvu" in first_arg.lower() or
        "/" in first_arg
      )

      is_numeric = re.match(r'^[0-9]+$', first_arg)

      if is_path_like:
        sub_mode = "integrate"
        file = first_arg  # path to scan/convert
      elif is_numeric:
        sub_mode = "discover"
        task_num = first_arg
        extra_terms = join(remaining_args_after(first_arg, args))
      else:
        sub_mode = "discover"
        query = join(args)  # entire ARGUMENTS treated as search query
    ```

    **Sub-mode summary**:

    | sub_mode  | Triggered By                             | Delegates To          |
    |-----------|------------------------------------------|-----------------------|
    | discover  | Numeric N, or text without path chars    | Mode A workflow below |
    | integrate | No args, or path-like arg                | skill-literature      |
    | validate  | `--validate` flag                        | skill-literature      |
    | index     | `--index FILE`                           | skill-literature      |
    | convert   | `--convert [FILE]`                       | skill-literature      |
  </step_1>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <step_1>
    <action>Validate Sub-Mode and Arguments</action>
    <process>
      Validation rules by sub_mode:

      | Sub-Mode  | FILE Required | QUERY/TASK Required | Description |
      |-----------|--------------|---------------------|-------------|
      | discover  | No           | Yes (task_num or query) | Source discovery via three-tier pipeline |
      | integrate | No           | No                  | Scan/convert/status (no args = status) |
      | validate  | No           | No                  | Check index.json consistency |
      | index     | Yes          | No                  | Add/update entry for existing markdown file |
      | convert   | Optional     | No                  | Convert specific file or all unprocessed |

      Error messages:
      - index without FILE: "Error: --index requires a FILE argument. Usage: /literature --index path/to/file.md"
      - discover with no terms: "Error: discover mode requires a task number or search query. Usage: /literature N or /literature \"search terms\""
    </process>
  </step_1>

  <step_2>
    <action>Mode A: Discover — Three-Tier Source Discovery</action>
    <process>
      When sub_mode = "discover":

      0. **Assisted Zotero export offer** (runs BEFORE `literature-discover.sh`, via a
         SEPARATE invocation with its own capture -- explicitly NOT `2>/dev/null`, so the
         offer is never swallowed the way the plain `tier2_search()` stderr hint is):

         ```bash
         STATUS_SCRIPT=".claude/scripts/zotero-export-status.sh"
         GENERATE_SCRIPT=".claude/scripts/zotero-generate-export.sh"

         # Both stdout (directive token) AND stderr (rationale) are captured -- neither is
         # discarded. orchestrator_mode is the delegation-context field (true for /orchestrate
         # and other autonomous callers; false for a human-invoked /literature).
         zotero_directive=$("$STATUS_SCRIPT" --orchestrator-mode "$orchestrator_mode" 2>/tmp/zotero-status-rationale.txt)
         zotero_rationale=$(cat /tmp/zotero-status-rationale.txt)
         ```

         Branch on `zotero_directive`:

         - **`ZOTERO_EXPORT_PRESENT`**: No offer. Proceed directly to step 1 (main discover
           call) as today.

         - **`ZOTERO_EXPORT_MISSING_RUNNING`** or **`ZOTERO_EXPORT_MISSING_NOT_RUNNING`**
           (interactive context, `orchestrator_mode != true`): Issue `AskUserQuestion`
           mirroring the three-option precedent style of `literature-lit-flag-resolve.sh`'s
           `--lit` prompt:

           ```json
           {
             "question": "No Zotero export found at {resolved_path}. Generate one now from your local Zotero library?",
             "header": "Assisted Zotero Export Generation",
             "multiSelect": false,
             "options": [
               {
                 "label": "Generate now (recommended)",
                 "description": "{path-specific detail, see below} This writes a ONE-TIME SNAPSHOT (not Zotero's auto-refreshing \"Keep updated\" export) plus a staleness stamp; re-run the generator later to refresh."
               },
               {
                 "label": "Skip this run",
                 "description": "Continue without a Zotero export; Tier 2 stays skipped for this discovery pass. You can generate it later via zotero-generate-export.sh."
               }
             ]
           }
           ```

           Path-specific detail for the first option's description:
           - If directive is `ZOTERO_EXPORT_MISSING_RUNNING`: "Zotero is running -- pulls your
             whole library live via its local API (and enriches citation-keys via Better
             BibTeX if installed)."
           - If directive is `ZOTERO_EXPORT_MISSING_NOT_RUNNING`: "Zotero is closed, so this
             reconstructs a snapshot directly from ~/Zotero/zotero.sqlite. For the richer live
             API path instead, open Zotero first, then re-run `/literature`."

           On "Generate now": run `"$GENERATE_SCRIPT" --orchestrator-mode false`, capturing
           stdout (resolved output path) and stderr (progress/rationale, including the
           staleness-stamp note); on success (exit 0), proceed to step 1 (main discover call,
           Tier 2 now populated). On failure (non-zero exit, e.g. a race where Zotero closed
           mid-run), surface the generator's stderr and fall back to step 1 as today (Tier 2
           stays skipped, non-fatal).

           On "Skip this run": log a visible, explicit "Zotero export generation skipped by
           user choice" notice (non-silent because it is a chosen option, not a default), then
           proceed to step 1.

         - **`ZOTERO_EXPORT_UNAVAILABLE`**: No offer. Surface the zotero-search.sh-matching
           manual-setup steps directly (no local Zotero data source exists to generate from):

           ```
           No Zotero export found, and no local Zotero installation was detected either
           (Zotero's local API is unreachable and ~/Zotero/zotero.sqlite does not exist).

           To set up Zotero CSL-JSON export manually:
           1. Install the Better BibTeX plugin for Zotero: https://retorque.re/zotero-better-bibtex/
           2. In Zotero, go to: File -> Export Library...
           3. Choose format: "Better CSL JSON"  Check "Keep updated" for automatic re-export.
           4. Save to one of: $ZOTERO_LIBRARY / ${LITERATURE_DIR}/zotero-library.json / ~/Projects/Literature/zotero-library.json
           ```

           Then proceed to step 1 (Tier 2 stays skipped, non-fatal, as today).

         - **Orchestrator / non-interactive default** (`orchestrator_mode == true`):
           `AskUserQuestion` cannot prompt a human, so it MUST NOT be called for
           `ZOTERO_EXPORT_MISSING_RUNNING` / `ZOTERO_EXPORT_MISSING_NOT_RUNNING`. Instead, take
           the deterministic default "generate now": run
           `"$GENERATE_SCRIPT" --orchestrator-mode true` and emit a visible `[zotero:auto]`
           notice (surfacing the generator's own `[zotero:auto]`-prefixed stderr line when the
           directive was actually `ZOTERO_EXPORT_UNAVAILABLE` and the generator itself found no
           data source) explaining the autonomous choice -- this is NEVER a silent no-op, and
           mirrors the `AUTONOMOUS_GLOBAL` precedent from the `--lit` flow (see CLAUDE.md
           "Literature Mode" section). Then proceed to step 1 regardless of the generation
           outcome (Tier 2 either becomes populated or stays skipped, non-fatal).

         This offer is a SEPARATE classifier invocation from the main discover call below; it
         never touches `literature-discover.sh`'s pure-JSON-array stdout contract, and it does
         NOT modify the existing `2>/dev/null` capture on the main call (that remains a
         separate, intentionally out-of-scope follow-up).

      1. **Run `literature-discover.sh`**:
         ```bash
         DISCOVER_SCRIPT=".claude/scripts/literature-discover.sh"

         if [ -n "$task_num" ] && [ -n "$extra_terms" ]; then
           discover_results=$("$DISCOVER_SCRIPT" --task "$task_num" "$extra_terms" 2>/dev/null)
           discover_exit=$?
         elif [ -n "$task_num" ]; then
           discover_results=$("$DISCOVER_SCRIPT" --task "$task_num" 2>/dev/null)
           discover_exit=$?
         else
           discover_results=$("$DISCOVER_SCRIPT" "$query" 2>/dev/null)
           discover_exit=$?
         fi
         ```

      2. **Handle no-results case** (exit code 1):
         ```
         No sources found for: "{query}"

         Suggestions:
           - Try broader search terms
           - Check that LITERATURE_DIR is set correctly (currently: {LITERATURE_DIR})
           - Ensure network connectivity for online search (Tier 3)
         ```

      3. **Present results via AskUserQuestion** (multi-select):
         ```json
         {
           "question": "Found {N} sources for '{query}'. Select sources to add to SOURCES.md:",
           "header": "Source Discovery Results",
           "multiSelect": true,
           "options": [
             {
               "label": "[Tier 1 - LOCAL] Title of Available Paper",
               "description": "Authors: Author Name | Year: 2023 | Status: available | Path: ~/Projects/Literature/..."
             },
             {
               "label": "[Tier 2 - ZOTERO] Title of Zotero Paper",
               "description": "Authors: Author Name | Year: 2022 | Status: in_zotero | doc_id: author2022_title"
             },
             {
               "label": "[Tier 3 - OPEN ACCESS] Title of OA Paper",
               "description": "Authors: Author Name | Year: 2021 | Status: open_access | PDF: https://arxiv.org/..."
             },
             {
               "label": "[Tier 3 - PAYWALL] Title of Paywalled Paper",
               "description": "Authors: Author Name | Year: 2020 | Status: paywall | DOI: 10.1234/..."
             },
             {
               "label": "Done — no selection",
               "description": "Exit without adding to SOURCES.md"
             }
           ]
         }
         ```

      4. **Update `specs/literature/SOURCES.md`** for selected entries:

         For each selected result:
         - If status = "available": skip SOURCES.md entry (already imported), show path
         - If status = "in_zotero": add row with status `[IN_ZOTERO]`
         - If status = "in_zotero_no_pdf": add row with status `[PENDING]`
         - If status = "open_access": add row with status `[FOUND]`, include PDF URL in Notes
         - If status = "paywall": add row with status `[PAYWALL]`, include DOI in Notes

         SOURCES.md format:
         ```markdown
         # Literature Sources

         | Title | Authors | Year | DOI | Status | Notes |
         |-------|---------|------|-----|--------|-------|
         | Paper Title | Author Name | 2023 | 10.1234/x | [IN_ZOTERO] | zotero: citation_key |
         | OA Paper | Author2 | 2022 | 10.5678/y | [FOUND] | pdf: https://arxiv.org/pdf/2201.1234 |
         | Paywalled | Author3 | 2021 | 10.9012/z | [PAYWALL] | |
         ```

         If `specs/literature/SOURCES.md` does not exist, create it with the header row.
         If it already exists, append new rows (check for duplicate titles before appending).

      5. **Update `specs/literature-index.json`** sub-index (only for "available" and "in_zotero" entries):
         - For "available" entries that resolve to a path in LITERATURE_DIR: add entry to local sub-index
         - Skip sub-index update for online/paywall sources (not yet local)

         ```bash
         LOCAL_INDEX="specs/literature-index.json"
         if [ ! -f "$LOCAL_INDEX" ]; then
           echo '{"entries": []}' > "$LOCAL_INDEX"
         fi
         # Add entries for local sources with doc_id, title, authors, year, path, status
         ```
    </process>
  </step_2>

  <step_3>
    <action>Mode B: Integrate — Delegate to Literature Skill</action>
    <process>
      When sub_mode = "integrate" (no args or path-like arg):

      If a path argument was given (file path to PDF/DJVU or directory):
        - Set mode = "convert", file = {path_arg}
        - Delegate to skill-literature with args: "mode=convert file={path_arg}"
      Else (no arguments):
        - Set mode = "status"
        - Delegate to skill-literature with args: "mode=status"
    </process>
  </step_3>

  <step_4>
    <action>Modes: validate, index, convert — Delegate to Literature Skill</action>
    <input>
      - skill: "skill-literature"
      - args: "mode={sub_mode} file={file}" (for validate/index/convert)
    </input>
    <expected_return>
      {
        "status": "completed",
        "mode": "{sub_mode}",
        "files_processed": N,
        "index_entries": M,
        "report": "..."
      }
    </expected_return>
  </step_4>

  <step_5>
    <action>Present Results</action>
    <process>
      Discover mode:
        - Show Tier breakdown (N local, M Zotero, P online)
        - Show count of entries added to SOURCES.md
        - Suggest: "Run /literature ~/path/to/file.pdf to convert a paper, or use --lit to inject literature into agent prompts"

      Integrate mode (status):
        - Display processed vs unprocessed file counts
        - Show index.json health summary
        - Show any warnings (missing files, stale entries)
        - Suggest next actions

      Convert mode:
        - Display converted file names and token counts
        - Show index.json entries added/updated
        - Report any files skipped (scanned-only PDFs, missing djvutxt)

      Validate mode:
        - List stale entries (path in index.json but file missing)
        - List unindexed files (markdown files not in index.json)
        - Show token count drift warnings (>20% change)
        - Suggest: "Run /literature --index FILE to add unindexed entries"

      Index mode:
        - Confirm entry added/updated in index.json
        - Show keywords and summary used
    </process>
  </step_5>
</workflow_execution>

---

## Error Handling

<error_handling>
  <argument_errors>
    - Unknown flag -> "Unknown flag: {flag}. Available: --validate, --convert [FILE], --index FILE, or pass a task number N or search query for discovery"
    - --index without FILE -> "Error: --index requires a FILE argument. Usage: /literature --index path/to/file.md"
    - discover with no terms -> "Error: discover mode requires a task number or search query. Usage: /literature 714 or /literature \"modal logic\""
    - Task N not found in state.json -> "Error: Task N not found in specs/state.json. Check the task number and try again."
  </argument_errors>

  <execution_errors>
    - literature-discover.sh not found -> "Error: literature-discover.sh not found at .claude/scripts/literature-discover.sh"
    - literature-discover.sh returns exit 1 (no results) -> Show "No sources found" message with suggestions (see Workflow step 2)
    - literature-discover.sh returns exit 2 (arg error) -> Pass through error message from script
    - specs/literature/ missing -> "No specs/literature/ directory found. Create it and add PDF/DJVU files to convert."
    - pdftotext not available -> "pdftotext not found. Install with: nix-env -iA nixpkgs.poppler_utils"
    - djvutxt not available -> "djvutxt not found (DJVU files will be skipped). Install with: nix-env -iA nixpkgs.djvulibre"
    - Skill failure -> Return error details
  </execution_errors>
</error_handling>

---

## State Management

<state_management>
  <reads>
    Mode A (discover):
    - $LITERATURE_DIR/index.json (Tier 1: global index search)
    - $LITERATURE_DIR/zotero-library.json (Tier 2: via zotero-search.sh)
    - https://api.semanticscholar.org/ (Tier 3: online API)
    - https://api.unpaywall.org/ (Tier 3: OA fallback for DOIs)
    - specs/state.json (when --task N given: read task slug for search terms)

    Mode B (integrate):
    - specs/literature/ (PDF/DJVU source files — gitignored, co-located with markdown)
    - specs/literature/ (markdown conversion files)
    - specs/literature/index.json (current index state)
  </reads>

  <writes>
    Mode A (discover):
    - specs/literature/SOURCES.md (append discovered sources as markdown table rows)
    - specs/literature-index.json (sub-index entries for "available" and "in_zotero" sources)

    Mode B (integrate):
    - specs/literature/*.md (flat document conversions)
    - specs/literature/{docname}/sectionNN_{slug}.md (content-aware chunked sections)
    - specs/literature/{docname}/{docname}_partNN.md (mechanical fallback chunks)
    - specs/literature/index.json (index entries with enriched schema: authors, title, year, doc_type, source_format, parent_doc, page_range)
    - $LITERATURE_DIR/pdfs/{citation_key}.pdf (symlink to Zotero PDF, for import)
    - $LITERATURE_DIR/index.json (Zotero metadata fields: bib_key, zotero_key, zotero_path, project_tags)
  </writes>

  <source_file_convention>
    Source PDFs/DJVUs are placed in the same directory as their converted markdown.
    Gitignore patterns `specs/literature/**/*.pdf` and `specs/literature/**/*.djvu` prevent
    committing source files. Users re-add source files manually after checkout.
  </source_file_convention>

  <sources_md_convention>
    `specs/literature/SOURCES.md` is created by Mode A (discover) on first use.
    It serves as a human-readable tracking table for papers identified but not yet imported.
    Status progression: [PENDING] -> [IN_ZOTERO] -> [FOUND] -> [RESOLVED]
    Papers marked [PAYWALL] require manual acquisition before they can progress.
    Papers marked [RESOLVED] have been fully imported and indexed via Mode B (integrate).
  </sources_md_convention>
</state_management>
