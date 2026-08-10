# Supplemental Research Report: Labels vs Flags vs Folders

- **Task**: 91 - himalaya_label_management_keybindings
- **Started**: 2026-02-13T00:00:00Z
- **Completed**: 2026-02-13T01:00:00Z
- **Effort**: 60 minutes
- **Dependencies**: research-001.md (Himalaya CLI commands and basic patterns)
- **Sources/Inputs**:
  - RFC 9051 (IMAP4rev2) and RFC 5788 (IMAP Keyword Registry)
  - Gmail IMAP Extensions documentation
  - Protonmail Bridge documentation
  - ~/.dotfiles/home.nix (mbsync configuration)
  - Himalaya CLI help output
- **Artifacts**: This supplemental research report
- **Standards**: report-format.md, artifact-formats.md

## Executive Summary

- **IMAP Flags** are server-stored message state indicators (5 standard: \Seen, \Answered, \Flagged, \Deleted, \Draft) plus optional custom keywords
- **Gmail Labels** are implemented via X-GM-LABELS extension AND as virtual folders - a message can have multiple labels, each appearing as a folder in IMAP
- **Protonmail Labels** are mapped to folders under `Labels/*` via Bridge - moving to a label folder applies the label
- **Himalaya's `flag add/remove` works with both accounts** for standard IMAP flags but custom flags/keywords have variable support
- **Recommended approach**: Use `himalaya flag add/remove` for standard flags (seen, answered, flagged), use `himalaya message copy/move` for label/folder-based organization

## Context & Scope

This supplemental research clarifies the conceptual differences between labels, flags, and folders in the context of:
1. Standard IMAP protocol
2. Gmail's IMAP implementation
3. Protonmail Bridge's IMAP implementation
4. Himalaya CLI's abstraction layer

The goal is to determine a unified implementation strategy for the Neovim integration that works across both Gmail and Protonmail (logos) accounts.

## Findings

### 1. IMAP Protocol: Flags and Keywords

According to RFC 9051 (IMAP4rev2), there are two types of flags:

#### System Flags (Standard)
| Flag | Meaning | Himalaya Name |
|------|---------|---------------|
| `\Seen` | Message has been read | `seen` |
| `\Answered` | Message has been replied to | `answered` |
| `\Flagged` | Message is starred/important | `flagged` |
| `\Deleted` | Message marked for deletion | `deleted` |
| `\Draft` | Message is a draft | `draft` |

These are universally supported across all IMAP servers.

#### Keywords (Custom Flags)
- User or client-defined flags that don't begin with `\`
- Server support is OPTIONAL - not all IMAP servers support custom keywords
- When supported, they function like tags that can be added/removed from messages
- According to RFC 5788, custom keywords should not start with `$` or `\` to avoid collisions

**Key Insight**: Custom keywords are NOT universally supported. Gmail and Protonmail handle them differently.

### 2. Gmail's IMAP Implementation

Gmail uses a unique hybrid approach documented in the [Gmail IMAP Extensions](https://developers.google.com/workspace/gmail/imap/imap-extensions):

#### Labels as Folders
- Gmail treats **labels as folders** for IMAP purposes
- Each label appears as a separate folder in IMAP
- System labels are prefixed with `[Gmail]/` (e.g., `[Gmail]/Sent Mail`, `[Gmail]/Trash`)
- User labels appear as top-level folders

#### X-GM-LABELS Extension
- Gmail provides a proprietary `X-GM-LABELS` extension
- Allows fetching all labels for a message: `FETCH 1 (X-GM-LABELS)`
- Allows adding labels: `STORE 1 +X-GM-LABELS (labelname)`
- **Not available via standard IMAP clients** without special support

#### Key Behaviors
| Operation | How Gmail Handles It |
|-----------|---------------------|
| Copy to folder | Adds label, keeps original |
| Move to folder | Adds label, removes from source |
| Delete from label folder | Removes label only |
| Standard IMAP flags | Work normally |
| Custom IMAP keywords | Limited support |

**Current Gmail Folders (from Himalaya)**:
```json
["Spam", "All_Mail", "EuroTrip", "Sent", "Letters", "Drafts", "CrazyTown", "Trash"]
```

The Gmail-specific labels like "EuroTrip", "Letters", "CrazyTown" are user-created Gmail labels appearing as folders.

### 3. Protonmail Bridge Implementation

According to [Protonmail Bridge documentation](https://proton.me/support/labels-in-bridge):

#### Labels as Folders
- Bridge interprets Protonmail labels as folders
- Labels appear under a `Labels/` prefix in IMAP
- Folders appear under a `Folders/` prefix

#### Label Operations
| Operation | Behavior |
|-----------|----------|
| Move to label folder | **Applies** the label |
| Move out of label folder | **Removes** the label |
| Copy to label folder | Applies label, keeps original |
| Standard IMAP flags | Work normally |
| Custom IMAP keywords | NOT synchronized to Protonmail |

**Important**: Protonmail Bridge explicitly states that email client tags (like Thunderbird's tagging) "will not work the same as Proton Mail's Labels, they are not synchronized to Proton Mail servers."

**Current Logos Folders (from Himalaya)**:
```json
["Sent", "Archive", "Drafts", "Trash"]
```

From `~/.dotfiles/home.nix` mbsync configuration:
```
Channel logos-labels
Patterns "Labels/*"

Channel logos-folders
Patterns "Folders/*"
```

**Note**: The current Logos account setup syncs `Labels/*` and `Folders/*` patterns, but currently shows no labels synced. This may indicate:
1. No labels created in Protonmail yet
2. Labels need to be created via Protonmail web interface first
3. mbsync needs to run to sync labels

### 4. Himalaya's Abstraction Layer

Himalaya provides a unified interface that abstracts both backends:

#### Flag Commands
```bash
# Standard flags work with both accounts
himalaya flag add <ID> seen -a gmail     # Mark as read
himalaya flag add <ID> flagged -a logos  # Star message
himalaya flag remove <ID> seen -a gmail  # Mark as unread
```

**Flag Command Structure**:
```
himalaya flag add <ID-OR-FLAG>... [-f FOLDER] [-a ACCOUNT]
```
- Arguments that parse as integers = envelope IDs
- Other arguments = flag names
- Supports multiple IDs and multiple flags in one command

#### Folder Operations
```bash
# Create folder/label
himalaya folder add "MyLabel" -a gmail

# List folders
himalaya folder list -a logos -o json

# Delete folder
himalaya folder delete "MyLabel" -a gmail
```

#### Message Move/Copy (for label management)
```bash
# Copy message to folder (applies label without removing from source)
himalaya message copy "LabelName" <ID> -f INBOX -a gmail

# Move message to folder (applies label, removes from source)
himalaya message move "LabelName" <ID> -f INBOX -a gmail
```

### 5. Cross-Account Compatibility Matrix

| Feature | Gmail | Protonmail | Himalaya Command | Universal? |
|---------|-------|------------|------------------|------------|
| Mark read/unread | Yes | Yes | `flag add/remove seen` | **Yes** |
| Star/flag | Yes | Yes | `flag add/remove flagged` | **Yes** |
| Mark answered | Yes | Yes | `flag add/remove answered` | **Yes** |
| Custom flags/keywords | Limited | **No** | `flag add <custom>` | **No** |
| Apply label (Gmail) | Yes | N/A | `message copy <label> <id>` | Gmail only |
| Apply label (PM) | N/A | Yes | `message move Labels/<label> <id>` | PM only |
| Create label | Yes | Yes | `folder add <name>` | **Yes** |
| Delete label | Yes | Yes | `folder delete <name>` | **Yes** |
| List labels | Yes | Yes | `folder list` | **Yes** |

### 6. What Works the Same Across Both Accounts

**Fully Compatible Operations**:
1. **Standard IMAP flags** (`seen`, `answered`, `flagged`, `deleted`, `draft`)
2. **Folder listing** via `himalaya folder list`
3. **Folder creation** via `himalaya folder add`
4. **Folder deletion** via `himalaya folder delete`
5. **Message copy** via `himalaya message copy`
6. **Message move** via `himalaya message move`

**Provider-Specific Operations**:
1. **Custom flags/keywords**: Gmail has limited support, Protonmail has none
2. **Label paths**: Gmail labels are top-level, Protonmail labels are under `Labels/`

## Recommendations for Neovim Integration

### Recommended Keybindings Architecture

Based on cross-account compatibility, implement a two-tier system:

#### Tier 1: Universal Flag Operations (Both Accounts)
| Key | Action | Command |
|-----|--------|---------|
| `u` | Toggle read/unread | `flag add/remove seen` |
| `*` or `s` | Toggle star/flag | `flag add/remove flagged` |
| (auto) | Mark answered on reply | `flag add answered` |

These work identically on Gmail and Protonmail.

#### Tier 2: Label/Folder Operations (Account-Aware)
| Key | Action | Implementation |
|-----|--------|----------------|
| `l` | Apply label to email(s) | Show folder picker, use `message copy` |
| `L` | Remove label | Account-dependent logic |
| `gl` prefix | Label management | `folder add/delete` |

**Implementation Strategy**:
```lua
function apply_label(email_ids, label_name)
  local account = config.get_current_account_name()

  -- Gmail: Labels are top-level folders
  -- Protonmail: Labels are under "Labels/" prefix
  local target_folder = label_name
  if account == "logos" and not label_name:match("^Labels/") then
    target_folder = "Labels/" .. label_name
  end

  -- Use copy to apply label (keeps in current folder too)
  for _, id in ipairs(email_ids) do
    cli_utils.execute_himalaya(
      { 'message', 'copy', target_folder, id },
      { account = account, folder = current_folder }
    )
  end
end
```

### Label Picker Design

Show available folders/labels filtered appropriately:

**Gmail**:
- Exclude system folders (`[Gmail]/*`)
- Show user-created labels

**Protonmail**:
- Show `Labels/*` folders
- May need to create labels in Protonmail web first

### What NOT to Implement

1. **Custom flag/keyword labels**: Not portable across accounts
2. **Gmail X-GM-LABELS**: Requires special IMAP extension, not available via Himalaya
3. **Direct Protonmail label API**: Bridge doesn't expose this

## Decisions

1. **Use standard IMAP flags** for read/star operations - universal support
2. **Use folder-based approach** for labels - works via `message copy`
3. **Account-aware label paths** - Gmail top-level, Protonmail under `Labels/`
4. **Skip custom flags** for labeling - not portable between accounts
5. **Label creation via `folder add`** - works for both accounts

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Protonmail labels not synced | High | Document that labels must exist first; mbsync required |
| Gmail label duplication | Medium | Use `copy` not `move` to avoid accidental data loss |
| Flag operation failures | Low | Use existing `manage_tag` with error handling |
| Label path differences | Medium | Abstract in Lua layer with account detection |

## Implementation Approach Summary

### For Standard Flags (Universal)
```lua
-- These work identically for both accounts
utils.manage_tag(email_id, "seen", "add")     -- Mark read
utils.manage_tag(email_id, "flagged", "add")  -- Star
utils.manage_tag(email_id, "seen", "remove")  -- Mark unread
```

### For Labels (Account-Aware)
```lua
-- Apply label (copies message to label folder)
local args = { 'message', 'copy', normalized_label, email_id }
cli_utils.execute_himalaya(args, opts)

-- Remove label (moves out of label folder - more complex, need to track original location)
-- May require moving to INBOX or Archive
```

## Appendix

### References
- [RFC 9051: IMAP4rev2](https://www.rfc-editor.org/rfc/rfc9051.html)
- [RFC 5788: IMAP Keyword Registry](https://datatracker.ietf.org/doc/html/rfc5788)
- [Gmail IMAP Extensions](https://developers.google.com/workspace/gmail/imap/imap-extensions)
- [Labels in Protonmail Bridge](https://proton.me/support/labels-in-bridge)
- [Himalaya GitHub](https://github.com/pimalaya/himalaya)
- [Fastmail Labels & IMAP](https://www.fastmail.help/hc/en-us/articles/1500000278282-Labels-IMAP)

### Protonmail mbsync Configuration (from home.nix)
```nix
# Logos Labs IMAP account (via Protonmail Bridge)
IMAPAccount logos
Host 127.0.0.1
Port 1143
User benjamin@logos-labs.ai
PassCmd "secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai"
TLSType None
AuthMechs LOGIN

Channel logos-labels
Far :logos-remote:
Near :logos-local:
Patterns "Labels/*"
Create Both
Expunge Both
Remove Both
SyncState *

Channel logos-folders
Far :logos-remote:
Near :logos-local:
Patterns "Folders/*"
Create Both
Expunge Both
Remove Both
SyncState *
```

### Current Himalaya Version
```
himalaya 1.1.0
```

### Key Findings Summary
1. Standard IMAP flags are the only universal mechanism for message state
2. Gmail and Protonmail both treat labels as folders in IMAP
3. Custom IMAP keywords are not portable between providers
4. Label application should use `message copy` for safety
5. Account detection is needed for proper label path construction
