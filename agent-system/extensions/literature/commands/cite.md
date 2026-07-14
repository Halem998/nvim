---
description: Verify citation claims against Literature/ index and Zotero library
allowed-tools: Skill
argument-hint: N [--gaps] ["focus text"] | "description text"
---

# Command: /cite

**Purpose**: Verifies citation claims in task artifacts or freeform text against the `specs/literature/` index and Zotero library. Extracts citations, scores confidence, surfaces gaps, and creates tasks for unverified claims.
**Layer**: 2 (Command File - Argument Parsing Agent)
**Delegates To**: skill-cite (direct execution)

**Input**: $ARGUMENTS

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Parse arguments to determine invocation mode:

    **Invocation Modes** (evaluated in order):
    1. No arguments (bare `/cite`) -> usage error
    2. `N` only -> Task mode (verify citations for task N)
    3. `N --gaps` -> Task+gaps mode (focus on finding missing citations for task N)
    4. `N "focus text"` -> Task+focus mode (verify task N with focus text)
    5. `"description text"` (no leading number) -> Freeform mode (verify freeform text)

    **Parsing Logic**:
    ```
    args = $ARGUMENTS

    # Strip --gaps flag, record presence
    show_gaps = false
    if "--gaps" in args:
      show_gaps = true
      args = args with "--gaps" removed

    # Find first numeric token
    task_num = first token matching /^\d+$/ in args (or "" if none)

    # Remaining non-numeric, non-flag text is the description
    description = args with task_num removed, stripped of leading/trailing whitespace

    # Determine mode
    if args == "":
      mode = "error"  # bare /cite
    elif task_num != "" and show_gaps == true:
      mode = "task_gaps"
    elif task_num != "" and description != "":
      mode = "task_focus"
    elif task_num != "":
      mode = "task"
    else:
      mode = "freeform"
    ```

    **Examples**:
    - `/cite 42` -> task_num=42, show_gaps=false, description=""
    - `/cite 42 --gaps` -> task_num=42, show_gaps=true, description=""
    - `/cite 42 "modal logic"` -> task_num=42, show_gaps=false, description="modal logic"
    - `/cite "verify claims about S5"` -> task_num="", description="verify claims about S5"
    ```
  </step_1>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <step_1>
    <action>Validate Arguments</action>
    <process>
      If mode = "error":
        Print usage error (see Error Handling) and exit without delegating.

      If task_num is provided (modes: task, task_gaps, task_focus):
        Validate the task exists in specs/state.json:
        ```bash
        found=$(jq -r --arg n "$task_num" \
          '.active_projects[] | select(.project_number == ($n | tonumber)) | .project_number' \
          specs/state.json 2>/dev/null)
        if [ -z "$found" ] || [ "$found" = "null" ]; then
          error: "Error: Task $task_num not found in specs/state.json"
          exit
        fi
        ```
    </process>
  </step_1>

  <step_2>
    <action>Delegate to Cite Skill</action>
    <input>
      Construct args string based on mode:

      | Mode        | args passed to skill-cite                                 |
      |-------------|-----------------------------------------------------------|
      | task        | "task_num={N} show_gaps=false description="               |
      | task_gaps   | "task_num={N} show_gaps=true description="                |
      | task_focus  | "task_num={N} show_gaps=false description={focus text}"   |
      | freeform    | "task_num= show_gaps=false description={text}"            |

      - skill: "skill-cite"
      - args: constructed per table above
    </input>
    <expected_return>
      {
        "status": "completed",
        "verified": N,
        "unverified": M,
        "gaps": K,
        "report": "..."
      }
    </expected_return>
  </step_2>

  <step_3>
    <action>Present Results</action>
    <process>
      Pass through skill-cite output directly to the user. The skill handles:
      - Citation extraction and confidence scoring
      - Interactive selection of unverified claims
      - Task creation for items needing follow-up
      - Gap reporting when show_gaps=true
    </process>
  </step_3>
</workflow_execution>

---

## Error Handling

<error_handling>
  <argument_errors>
    - No arguments (bare `/cite`):
      ```
      Error: /cite requires an argument.

      Usage:
        /cite N             Verify citations for task N
        /cite N --gaps      Focus on finding missing citations for task N
        /cite N "focus"     Verify task N with focus text
        /cite "text"        Verify freeform description text

      Examples:
        /cite 42
        /cite 42 --gaps
        /cite 42 "modal logic axioms"
        /cite "verify claims about S5 completeness"
      ```

    - Task N not found in specs/state.json:
      "Error: Task {N} not found in specs/state.json. Check the task number and try again."

    - Unknown flag:
      "Error: Unknown flag: {flag}. Available flags: --gaps"
  </argument_errors>

  <execution_errors>
    - Skill failure -> Return error details from skill-cite
    - specs/literature/index.json missing -> skill-cite reports and gracefully degrades to Zotero-only search
  </execution_errors>
</error_handling>
