# Research Report: Task #90

**Task**: 90 - himalaya_protonmail_bidirectional_sync
**Started**: 2026-02-13T14:30:00Z
**Completed**: 2026-02-13T15:00:00Z
**Effort**: Low (research only)
**Dependencies**: Task #89 (Gmail research for comparison)
**Sources/Inputs**: Himalaya CLI, mbsync configuration, Protonmail Bridge IMAP testing, web documentation
**Artifacts**: This report
**Standards**: report-format.md

## Executive Summary

- Protonmail Bridge exposes labels as `Labels/*` and folders as `Folders/*` via IMAP; folder creation at root level is NOT allowed
- Current mbsyncrc only syncs 5 system folders (INBOX, Sent, Drafts, Trash, Archive); custom labels/folders are NOT synced
- Bidirectional folder sync is supported but requires adding channels for `Labels/*` and `Folders/*` patterns
- Unlike Gmail, Protonmail has a clear separation: Labels (for tagging/categorization) vs Folders (for organization)

## Context & Scope

This research investigates bidirectional label/folder synchronization between Protonmail (via Bridge) and Himalaya, building on Task #89's Gmail findings. Key questions:

1. How does Protonmail Bridge expose labels/folders via IMAP?
2. What is the current sync architecture?
3. What configuration changes enable bidirectional sync?
4. What are the differences from Gmail's implementation?

## Findings

### 1. Protonmail Bridge IMAP Folder Structure

Testing via direct IMAP connection to Protonmail Bridge (127.0.0.1:1143) reveals the following folder structure:

| Folder | Attributes | Description |
|--------|------------|-------------|
| INBOX | \Noinferiors \Unmarked | Standard inbox |
| Sent | \Noinferiors \Sent \Marked | Sent messages |
| Drafts | \Drafts \Noinferiors \Unmarked | Draft messages |
| Trash | \Noinferiors \Trash \Unmarked | Deleted messages |
| Archive | \Archive \Noinferiors \Unmarked | Archived messages |
| Spam | \Junk \Noinferiors \Marked | Spam folder |
| All Mail | \All \Noinferiors \Marked | Virtual folder (all messages) |
| Starred | \Flagged \Noinferiors \Marked | Starred messages |
| Labels | \Noselect \Unmarked | **Container** for user labels |
| Folders | \Noselect \Unmarked | **Container** for user folders |

**Key insight**: `Labels` and `Folders` are marked `\Noselect`, meaning they are container folders that cannot be directly selected. User-created labels appear as `Labels/LabelName` and folders as `Folders/FolderName`.

### 2. Folder Creation Behavior (Tested)

Direct IMAP testing confirmed:

```python
# Successful operations:
imap.create('Labels/TestLabel')   # OK - creates label in Protonmail
imap.create('Folders/TestFolder') # OK - creates folder in Protonmail
imap.delete('Labels/TestLabel')   # OK - deletes label
imap.delete('Folders/TestFolder') # OK - deletes folder

# Failed operation:
imap.create('TestRoot')           # NO - "operation not allowed"
```

**Conclusion**: Unlike Gmail (which allows root-level labels), Protonmail requires all user-created items to be under `Labels/` or `Folders/`.

### 3. Labels vs Folders in Protonmail

Protonmail distinguishes between:

| Type | IMAP Path | Purpose | Behavior |
|------|-----------|---------|----------|
| Labels | Labels/* | Tagging/categorization | Message can have multiple labels |
| Folders | Folders/* | Organization | Message exists in one folder |

This is architecturally different from Gmail where labels and folders are unified concepts.

Reference: [Labels in Bridge - Proton](https://proton.me/support/labels-in-bridge)

### 4. Current Sync Architecture

The logos account uses the same two-tier architecture as Gmail:

```
Protonmail Server <--> Bridge IMAP <--> mbsync <--> Local Maildir <--> Himalaya
```

**Current mbsyncrc configuration (logos section)**:
```
IMAPAccount logos
Host 127.0.0.1
Port 1143
TLSType None
AuthMechs LOGIN

Channel logos-inbox    # Far: INBOX → Near: root
Channel logos-sent     # Far: Sent → Near: Sent
Channel logos-drafts   # Far: Drafts → Near: Drafts
Channel logos-trash    # Far: Trash → Near: Trash
Channel logos-archive  # Far: Archive → Near: Archive
```

**Missing from current configuration**:
- Spam folder
- All Mail folder
- Starred folder
- **Labels/* subfolders** (any user-created labels)
- **Folders/* subfolders** (any user-created folders)

### 5. Himalaya's Current View

Himalaya folder list for logos account shows only:
```
| NAME    | DESC                               |
|---------|------------------------------------|
| Sent    | /home/benjamin/Mail/Logos/.Sent    |
| Archive | /home/benjamin/Mail/Logos/.Archive |
| Drafts  | /home/benjamin/Mail/Logos/.Drafts  |
| Trash   | /home/benjamin/Mail/Logos/.Trash   |
```

**Notable**: INBOX is not shown because Himalaya reads the root Maildir (cur/new/tmp) as the inbox, not a separate `.INBOX` subfolder.

### 6. Local Maildir Structure Issues

The local Maildir has duplicate folders:
```
/home/benjamin/Mail/Logos/
├── .Archive/  (Maildir++ format - dot prefix)
├── Archive/   (standard directory)
├── .Sent/
├── Sent/
...
```

This duplication may cause confusion. The `.Archive` (dot-prefixed) folders are the Maildir++ format that Himalaya reads; the non-dot-prefixed folders appear to be from a different sync configuration.

### 7. Comparison: Protonmail vs Gmail

| Aspect | Gmail | Protonmail |
|--------|-------|------------|
| Label location | Root level | Labels/* |
| Folder location | Root level | Folders/* |
| Root creation | Allowed | Not allowed |
| System folders | [Gmail]/* prefix | No prefix (INBOX, Sent, etc.) |
| Multiple labels | Via IMAP copies | Native support |
| Label/Folder distinction | Unified | Separate concepts |
| Bridge required | No | Yes |
| IMAP auth | XOAUTH2 | Plain (local bridge) |

## Recommendations

### Option A: Enable Bidirectional Label/Folder Sync (Recommended)

Add new channels to `~/.mbsyncrc` for labels and folders:

```
# Sync all user labels
Channel logos-labels
Far :logos-remote:
Near :logos-local:
Patterns "Labels/*"
Create Both
Expunge Both
Remove Both
SyncState *

# Sync all user folders
Channel logos-folders
Far :logos-remote:
Near :logos-local:
Patterns "Folders/*"
Create Both
Expunge Both
Remove Both
SyncState *

# Add to group
Group logos
Channel logos-inbox
Channel logos-sent
Channel logos-drafts
Channel logos-trash
Channel logos-archive
Channel logos-labels
Channel logos-folders
```

This enables:
- Auto-discovery of new labels/folders created in Protonmail web
- Auto-sync of new Himalaya labels/folders to Protonmail
- Folder deletion propagation

### Option B: Explicit Label List (Alternative)

If predictable sync is preferred, use explicit patterns:

```
Channel logos-labels
Far :logos-remote:
Near :logos-local:
Patterns "Labels/Work" "Labels/Personal" "Labels/Archive"
Create Both
Expunge Both
SyncState *
```

### Additional Recommended Channels

Consider adding channels for other useful folders:

```
Channel logos-spam
Far :logos-remote:Spam
Near :logos-local:Spam
Create Both
Expunge Both
SyncState *

Channel logos-starred
Far :logos-remote:Starred
Near :logos-local:Starred
Create Both
Expunge Both
SyncState *
```

### Himalaya Folder Configuration

Update `/home/benjamin/.config/himalaya/config.toml` to add folder aliases:

```toml
[accounts.logos]
# ... existing config ...

# Folder configuration for Protonmail's special folders
folder.alias.inbox = "INBOX"
folder.alias.sent = "Sent"
folder.alias.drafts = "Drafts"
folder.alias.trash = "Trash"
folder.alias.spam = "Spam"
folder.alias.archive = "Archive"
folder.sent.name = "Sent"
```

### Workflow for Creating New Labels/Folders

**From Himalaya**:
```bash
# Create a label
himalaya folder add "Labels/Work" --account logos
mbsync logos-labels

# Create a folder
himalaya folder add "Folders/Projects" --account logos
mbsync logos-folders
```

**From Protonmail Web**:
1. Create label/folder in Protonmail web interface
2. Run `mbsync logos` (if using wildcard patterns)
3. New label/folder appears in Himalaya

## Decisions

1. **Use wildcard patterns for Labels/* and Folders/***: Unlike Gmail where exclusion patterns are needed for `[Gmail]/*`, Protonmail's structure is cleaner
2. **Keep system folders explicit**: INBOX, Sent, Drafts, Trash, Archive should remain as dedicated channels for clarity
3. **Add Remove Both**: Enable folder deletion propagation for full bidirectional sync
4. **Clean up duplicate directories**: The non-dot-prefixed folders in ~/Mail/Logos/ should be investigated and potentially removed

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Bridge must be running | High | Add startup script or systemd service |
| Local network auth (TLSType None) | Low | Bridge runs locally; acceptable for 127.0.0.1 |
| Duplicate Maildir directories | Medium | Clean up non-Maildir++ directories after backup |
| Labels with special characters | Low | Test before creating; avoid slashes in names |

## Appendix

### Search Queries Used
- "Protonmail Bridge IMAP folder structure Labels Folders hierarchy create 2025 2026"
- "Protonmail Bridge mbsync bidirectional sync labels folders create"

### References
- [Labels in Bridge - Proton](https://proton.me/support/labels-in-bridge)
- [Protonmail Bridge IMAP Service - DeepWiki](https://deepwiki.com/ProtonMail/proton-bridge/3.1-imap-service)
- [Quick notes on Proton Mail Bridge, mbsync - plrj.org](https://plrj.org/2025/01/02/quick-notes-on-proton-mail-bridge-mbsync-msmtp-mu-mu4e/)
- [Setting up Protonmail in Emacs - shom.dev](https://shom.dev/posts/20220108_setting-up-protonmail-in-emacs/)

### Local Files Examined
- `/home/benjamin/.config/himalaya/config.toml`
- `/home/benjamin/.mbsyncrc`
- `/home/benjamin/Mail/Logos/` (directory structure)

### Direct IMAP Testing Results

**Folder listing (Python imaplib)**:
```
(\Noselect \Unmarked) "/" "Labels"
(\Noselect \Unmarked) "/" "Folders"
(\Noinferiors \Unmarked) "/" "INBOX"
(\Marked \Noinferiors \Sent) "/" "Sent"
(\Drafts \Noinferiors \Unmarked) "/" "Drafts"
(\Noinferiors \Trash \Unmarked) "/" "Trash"
(\Archive \Noinferiors \Unmarked) "/" "Archive"
(\Junk \Marked \Noinferiors) "/" "Spam"
(\All \Marked \Noinferiors) "/" "All Mail"
(\Flagged \Marked \Noinferiors) "/" "Starred"
```

**Create/Delete testing**:
- `Labels/TestLabel`: CREATE OK, DELETE OK
- `Folders/TestFolder`: CREATE OK, DELETE OK
- `TestRoot`: CREATE NO ("operation not allowed")
