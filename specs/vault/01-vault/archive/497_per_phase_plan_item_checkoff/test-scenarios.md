# Test Scenario: Per-Phase Plan Item Check-Off

## Overview

This document demonstrates the expected before/after state of plan files when the general-implementation-agent applies per-phase checklist check-off.

---

## Scenario 1: Phase 2 in Progress, Tasks 2.1-2.3 Completed

### Before Implementation (Phase 2 in progress, no tasks completed)

```markdown
### Phase 2: Build the Core Module [IN PROGRESS]

**Tasks**:
- [ ] **Task 2.1**: Create module skeleton
- [ ] **Task 2.2**: Implement tool preference persistence
- [ ] **Task 2.3**: Implement active terminal detection
- [ ] **Task 2.4**: Implement smart_toggle() entry point
- [ ] **Task 2.5**: Implement setup() function
```

### After Completing Tasks 2.1-2.3, with 2.4 in Progress

```markdown
### Phase 2: Build the Core Module [IN PROGRESS]

**Tasks**:
- [x] **Task 2.1**: Create module skeleton *(completed)*
- [x] **Task 2.2**: Implement tool preference persistence *(completed)*
- [x] **Task 2.3**: Implement active terminal detection *(completed: both Claude and OpenCode detection working)*
- [ ] **Task 2.4**: Implement smart_toggle() entry point *(in progress)*
- [ ] **Task 2.5**: Implement setup() function
```

---

## Scenario 2: Phase 2 Fully Completed

### After Phase Complete

```markdown
### Phase 2: Build the Core Module [COMPLETED]

**Tasks**:
- [x] **Task 2.1**: Create module skeleton *(completed)*
- [x] **Task 2.2**: Implement tool preference persistence *(completed)*
- [x] **Task 2.3**: Implement active terminal detection *(completed)*
- [x] **Task 2.4**: Implement smart_toggle() entry point *(completed)*
- [x] **Task 2.5**: Implement setup() function *(completed)*
```

---

## Scenario 3: Context Exhaustion Handoff Mid-Phase

### Handoff Artifact Current State

```markdown
## Current State
- **File**: /home/user/project/src/handlers/data_processor.lua
- **Location**: Line 142, inside `process_batch` function
- **Work state**: Input validation framework set up, need to integrate with main processing loop
- **Plan**: specs/259_configure_feature/plans/02_implementation-plan.md — Phase 3: Tasks 3.1-3.2 checked off, Task 3.3 in progress
- **Progress**: specs/259_configure_feature/progress/phase-3-progress.json
```

---

## Verification Checklist

- [x] All 4 copies of general-implementation-agent.md contain Stage 4B-ii
- [x] All 4 copies contain updated Stage 1 successor guidance
- [x] Grep verification shows consistent content across all copies
- [x] Before/after examples match the specified `- [ ]` → `- [x]` conversion pattern
- [x] Optional completion notes follow `*(completed: {brief note})*` format
- [x] Handoff-artifact.md example includes plan file check-off reference
- [x] No malformed markdown or broken references introduced
