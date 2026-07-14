# Slidev Shared Resources

Resource-only micro-extension providing shared Slidev animation patterns and CSS style presets. No agents, commands, or routing -- used as a dependency by extensions that produce Slidev decks (founder, present).

## Resources

- **6 animation patterns**: fade-in, slide-in-below, metric-cascade, rough-marks, staggered-list, scale-in-pop
- **9 CSS style presets**: 4 color schemes, 3 typography stacks, 2 texture overlays

## Usage

Declare `"dependencies": ["slidev"]` in your extension manifest. The extension loader will auto-load slidev before your extension.
