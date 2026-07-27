# Test Project Roadmap (table format, no checkboxes)

This fixture exercises the table-row annotation path end to end: a column-agnostic parser, a
line-reference-based annotator, and a still-in-progress row that must be left untouched.

## Component Status

| Component | Hardware Port | Status | Location |
|-----------|----------------|--------|----------|
| Widget Driver | GPIO4 | Complete (task 501) | src/widget.lua |
| Gadget Sensor | GPIO7 | In Progress | src/gadget.lua |

## Extended Status

| Component | Owner | Region | Status | Location |
|-----------|-------|--------|--------|----------|
| Sprocket Cache | teamA | us-east | Resolved (task 502) | src/sprocket.lua |
| Widget Driver | teamB | us-west | Not started | src/widget-b.lua |
