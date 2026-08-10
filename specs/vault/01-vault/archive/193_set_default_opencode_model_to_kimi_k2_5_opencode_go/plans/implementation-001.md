# Implementation Plan: Set Default Opencode Model to Kimi K2.5 OpenCode Go

- **Task**: 193 - set_default_opencode_model_to_kimi_k2_5_opencode_go
- **Status**: [NOT STARTED]
- **Effort**: 15 minutes
- **Dependencies**: None
- **Research Inputs**: specs/193_set_default_opencode_model_to_kimi_k2_5_opencode_go/reports/research-193.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: true

## Overview

Change the default opencode model from 'Kimi K2.5 OpenCode Zen' to 'Kimi K2.5 OpenCode Go' by updating the model field in the Nix home-managed configuration file.

### Research Integration

Research identified the exact file location and model identifiers:
- Current model: `opencode/kimi-k2.5` (Kimi K2.5 OpenCode Zen)
- Target model: `opencode-go/kimi-k2.5` (Kimi K2.5 OpenCode Go)
- Configuration file: `/home/benjamin/.dotfiles/config/opencode.json` (line 3)
- Change required: Modify the `model` field value from `"opencode/kimi-k2.5"` to `"opencode-go/kimi-k2.5"`

## Goals & Non-Goals

**Goals**:
- Update opencode configuration to use `opencode-go/kimi-k2.5` as default model
- Apply configuration changes via home-manager
- Verify the new model is active in new opencode sessions

**Non-Goals**:
- No changes to other opencode settings
- No impact on existing opencode sessions

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Invalid model identifier | High | Low | Research confirmed the exact target model name |
| Home-manager syntax errors | Medium | Low | Edit only the model field value, validate JSON syntax after edit |

## Implementation Phases

### Phase 1: Update Configuration File [COMPLETED]

**Goal**: Modify the opencode configuration file to use the new default model.

**Tasks**:
- [ ] Read `/home/benjamin/.dotfiles/config/opencode.json` to verify current state
- [ ] Edit line 3: change `"opencode/kimi-k2.5"` to `"opencode-go/kimi-k2.5"`
- [ ] Verify JSON syntax is valid

**Timing**: 5 minutes

**Files to modify**:
- `/home/benjamin/.dotfiles/config/opencode.json` - Update model field on line 3

**Verification**:
- File contains `"model": "opencode-go/kimi-k2.5"` on line 3
- JSON parses without errors

---

### Phase 2: Apply and Verify [COMPLETED]

**Goal**: Apply configuration changes and verify the new model is active.

**Tasks**:
- [ ] Run `home-manager switch` to apply the configuration change
- [ ] Start a new opencode session in a fresh terminal
- [ ] Verify the model indicator shows 'Kimi K2.5 OpenCode Go'
- [ ] Run a simple test query to confirm the model is working

**Timing**: 10 minutes

**Verification**:
- Home-manager switch completes without errors
- New opencode sessions use the correct model
- Model indicator in UI shows expected model name

## Testing & Validation

- [ ] JSON syntax validates correctly
- [ ] Home-manager switch applies without errors
- [ ] New opencode session uses 'Kimi K2.5 OpenCode Go'
- [ ] Simple test query completes successfully

## Artifacts & Outputs

- Updated `/home/benjamin/.dotfiles/config/opencode.json`

## Rollback/Contingency

If issues occur:
1. Edit the configuration file to revert model value to `"opencode/kimi-k2.5"`
2. Run `home-manager switch` to apply rollback
3. Verify original behavior is restored
