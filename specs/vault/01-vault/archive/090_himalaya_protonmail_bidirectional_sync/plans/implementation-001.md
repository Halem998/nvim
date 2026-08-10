# Implementation Plan: Task #90

- **Task**: 90 - himalaya_protonmail_bidirectional_sync
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: Task #89 (Gmail implementation for reference pattern)
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general

## Overview

This plan implements bidirectional folder/label synchronization between Protonmail (via Bridge) and Himalaya by modifying the home-manager configuration in `~/.dotfiles/home.nix`. Following the pattern established in Task #89 for Gmail, we add channels for `Labels/*` and `Folders/*` patterns with bidirectional sync directives. Git version control in the dotfiles repo provides rollback capability.

### Research Integration

Key findings from research-001.md:
- Protonmail Bridge exposes labels as `Labels/*` and folders as `Folders/*` via IMAP (both are `\Noselect` containers)
- Root-level folder creation is NOT allowed; user items must be under `Labels/` or `Folders/`
- Current mbsyncrc only syncs 5 system folders (INBOX, Sent, Drafts, Trash, Archive)
- Solution: Add two new channels (`logos-labels` and `logos-folders`) with wildcard patterns and `Create Both`, `Expunge Both`, `Remove Both`
- Labels allow multiple per message (tagging); Folders allow one per message (organization)

### Configuration Location

The mbsyncrc is managed by home-manager in:
- **Source**: `~/.dotfiles/home.nix` (logos account section)
- **Generated**: `/nix/store/.../home-manager-files/.mbsyncrc`
- **Symlink**: `~/.mbsyncrc` -> Nix store path

## Goals & Non-Goals

**Goals**:
- Enable automatic discovery and sync of new Protonmail labels created in web interface
- Enable automatic discovery and sync of new Protonmail folders created in web interface
- Enable Himalaya-created labels/folders to sync to Protonmail without manual pattern list edits
- Enable bidirectional folder/label deletion propagation
- Add channels to the logos group for unified `mbsync logos` operation
- Use git for version control (no backup file copies)

**Non-Goals**:
- Modifying Himalaya's configuration or Lua integration (out of scope)
- Changing the Maildir backend architecture (keeping current two-tier design)
- Syncing system folders (Spam, All Mail, Starred) - can be added separately if needed
- Cleaning up duplicate Maildir directories (separate task)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Bridge not running during sync | High | Medium | Verify bridge status before sync; add to startup if needed |
| Labels with special characters fail | Low | Low | Test before creating; avoid slashes in names |
| Existing system folder conflicts | Medium | Low | Patterns target only Labels/* and Folders/* paths |
| Breaking existing sync behavior | High | Low | Git commit before changes; test incrementally; easy rollback |
| Home-manager rebuild failure | Low | Low | Nix syntax checked before apply; git revert if needed |

## Implementation Phases

### Phase 1: Modify home.nix for Labels Channel [COMPLETED]

**Goal**: Add a new `logos-labels` channel to sync all user-created labels bidirectionally.

**Tasks**:
- [ ] Commit current state of home.nix to git (ensure clean starting point)
- [ ] Locate logos mbsync configuration in `~/.dotfiles/home.nix`
- [ ] Add new `logos-labels` channel after existing logos channels
- [ ] Add channel to logos group

**Timing**: 10 minutes

**Files to modify**:
- `~/.dotfiles/home.nix` - Add logos-labels channel configuration

**Changes** (add after existing logos channels):
```
      Channel logos-labels
      Far :logos-remote:
      Near :logos-local:
      Patterns "Labels/*"
      Create Both
      Expunge Both
      Remove Both
      SyncState *
```

**Verification**:
- No Nix syntax errors in home.nix

---

### Phase 2: Add Folders Channel and Update Group [COMPLETED]

**Goal**: Add a new `logos-folders` channel and update the logos group to include both new channels.

**Tasks**:
- [ ] Add new `logos-folders` channel after logos-labels channel
- [ ] Update logos group to include logos-labels and logos-folders
- [ ] Commit changes with descriptive message

**Timing**: 10 minutes

**Files to modify**:
- `~/.dotfiles/home.nix` - Add logos-folders channel and update group

**Changes** (add after logos-labels):
```
      Channel logos-folders
      Far :logos-remote:
      Near :logos-local:
      Patterns "Folders/*"
      Create Both
      Expunge Both
      Remove Both
      SyncState *
```

**Group update** (add to existing logos group):
```
      Group logos
      Channel logos-inbox
      Channel logos-sent
      Channel logos-drafts
      Channel logos-trash
      Channel logos-archive
      Channel logos-labels
      Channel logos-folders
```

**Verification**:
- Git commit created with changes
- No Nix syntax errors in home.nix

---

### Phase 3: Rebuild Home-Manager and Test Sync [COMPLETED]

**Goal**: Apply the new configuration and verify basic sync still works.

**Tasks**:
- [ ] Run `home-manager switch` to rebuild and apply configuration
- [ ] Verify symlink updated: `ls -la ~/.mbsyncrc`
- [ ] Verify new channels in config: `grep -A 5 "Channel logos-labels" ~/.mbsyncrc`
- [ ] Verify Protonmail Bridge is running
- [ ] Run `mbsync logos` to test sync with existing folders
- [ ] Verify existing system folders (INBOX, Sent, Drafts, Trash, Archive) still sync correctly

**Timing**: 15 minutes

**Files to modify**:
- None (applying generated config)

**Commands**:
```bash
# Apply new configuration
home-manager switch

# Verify symlink points to new config
ls -la ~/.mbsyncrc

# Verify new channels
grep -A 7 "Channel logos-labels" ~/.mbsyncrc
grep -A 7 "Channel logos-folders" ~/.mbsyncrc

# Verify group includes new channels
grep -A 10 "Group logos" ~/.mbsyncrc

# Check Bridge is running
pgrep -f protonmail-bridge || echo "Bridge not running"

# Test sync
mbsync logos

# Check existing folders still present
himalaya folder list --account logos
```

**Verification**:
- Home-manager switch completes without errors
- ~/.mbsyncrc contains new logos-labels and logos-folders channels
- Existing folders still sync correctly
- Bridge is running (required for sync)

---

### Phase 4: Test Bidirectional Label/Folder Sync [COMPLETED]

**Goal**: Verify new labels/folders sync bidirectionally between Protonmail and Himalaya.

**Tasks**:
- [ ] **Protonmail -> Himalaya (Label)**: Create test label "TestLabel" in Protonmail web interface
- [ ] Run `mbsync logos-labels` and verify folder appears locally as `.Labels.TestLabel`
- [ ] Verify folder visible in `himalaya folder list --account logos`
- [ ] **Himalaya -> Protonmail (Label)**: Create test label via `himalaya folder add "Labels/TestLabel2" --account logos`
- [ ] Run `mbsync logos-labels` and verify label appears in Protonmail web interface
- [ ] **Protonmail -> Himalaya (Folder)**: Create test folder "TestFolder" in Protonmail web interface
- [ ] Run `mbsync logos-folders` and verify folder appears locally
- [ ] **Himalaya -> Protonmail (Folder)**: Create test folder via `himalaya folder add "Folders/TestFolder2" --account logos`
- [ ] Run `mbsync logos-folders` and verify folder appears in Protonmail web interface
- [ ] **Deletion test**: Delete test items and verify propagation
- [ ] Clean up any remaining test labels/folders

**Timing**: 20 minutes

**Files to modify**:
- None (testing only)

**Verification**:
- New Protonmail labels auto-sync to Himalaya after mbsync
- New Protonmail folders auto-sync to Himalaya after mbsync
- New Himalaya labels/folders sync to Protonmail
- Label/folder deletions propagate in both directions

---

### Phase 5: Update Documentation [COMPLETED]

**Goal**: Document the new workflow and configuration for future reference.

**Tasks**:
- [ ] Update `~/.dotfiles/docs/himalaya.md` with Protonmail folder sync behavior
- [ ] Document the workflow:
  - Creating labels in Protonmail (auto-syncs to Himalaya under Labels/*)
  - Creating folders in Protonmail (auto-syncs to Himalaya under Folders/*)
  - Creating labels/folders in Himalaya (syncs to Protonmail via mbsync)
  - Deleting items (propagates bidirectionally)
- [ ] Note the distinction between Labels (multiple per message) and Folders (one per message)
- [ ] Note that Bridge must be running for sync to work
- [ ] Commit documentation changes

**Timing**: 10 minutes

**Files to modify**:
- `~/.dotfiles/docs/himalaya.md` - Add Protonmail folder sync documentation

**Verification**:
- Documentation accurately describes new behavior
- Workflow steps are clear and actionable
- Changes committed to git

## Testing & Validation

- [ ] Git commit created before any changes
- [ ] home.nix modification applied without Nix syntax errors
- [ ] Home-manager switch completes successfully
- [ ] New logos-labels and logos-folders channels present in ~/.mbsyncrc
- [ ] Logos group includes new channels
- [ ] Existing system folders (INBOX, Sent, Drafts, Trash, Archive) remain synced
- [ ] New Protonmail labels auto-sync to Himalaya after `mbsync logos-labels`
- [ ] New Protonmail folders auto-sync to Himalaya after `mbsync logos-folders`
- [ ] Himalaya-created labels sync to Protonmail under Labels/*
- [ ] Himalaya-created folders sync to Protonmail under Folders/*
- [ ] Label/folder deletions propagate bidirectionally
- [ ] Full `mbsync logos` syncs all channels including new ones

## Artifacts & Outputs

- `~/.dotfiles/home.nix` - Modified configuration (git tracked)
- `~/.dotfiles/docs/himalaya.md` - Updated documentation (git tracked)
- `specs/090_himalaya_protonmail_bidirectional_sync/summaries/implementation-summary-YYYYMMDD.md` - Completion summary

## Rollback/Contingency

Git provides full rollback capability:

1. **Immediate Rollback**: Revert to previous commit
   ```bash
   cd ~/.dotfiles
   git revert HEAD
   home-manager switch
   ```

2. **Partial Rollback**: If only one channel causes issues
   - Edit home.nix to remove the problematic channel
   - Run `home-manager switch` to apply
   - Debug the specific channel configuration

3. **Bridge Issues**: If sync fails due to Bridge
   - Check Bridge is running: `pgrep -f protonmail-bridge`
   - Restart Bridge if needed
   - Verify IMAP connectivity: `telnet 127.0.0.1 1143`

4. **Investigation**: If unexpected folders sync or conflicts occur
   - Labels/* and Folders/* are isolated from system folders
   - Add exclusion patterns if specific labels/folders cause issues
   - Example: `Patterns "Labels/*" !"Labels/ProblemLabel"`
