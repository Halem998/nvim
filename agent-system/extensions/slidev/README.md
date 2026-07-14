# Slidev Shared Resources Extension

Resource-only micro-extension providing shared Slidev primitives for deck and slide generation across multiple domain extensions.

## Purpose

Both the `founder` extension (pitch decks) and `present` extension (academic talks) use Slidev for slide generation. This extension extracts the 15 shared animation and style primitives into a single location, eliminating duplication and ensuring consistency.

## Resource Catalog

### Animations (6 files)

| File | Description | Complexity |
|------|-------------|------------|
| `fade-in.md` | CSS fade entrance via v-click opacity transition | Low |
| `slide-in-below.md` | v-motion y-axis entrance with spring physics | Medium |
| `metric-cascade.md` | Staggered v-motion for KPI slides | High |
| `rough-marks.md` | v-mark hand-drawn text highlighting | Medium |
| `staggered-list.md` | v-clicks progressive list reveal | Low |
| `scale-in-pop.md` | v-motion spring scale for CTAs | Medium |

### CSS Style Presets (9 files)

**Colors** (4 schemes):
- `light-blue-corp.css` -- White background, blue/navy accents
- `dark-blue-navy.css` -- Navy background, blue accents
- `dark-gold-premium.css` -- Near-black, gold accents
- `light-green-growth.css` -- Mint/white, green accents

**Typography** (3 stacks):
- `montserrat-inter.css` -- Montserrat headings, Inter body
- `playfair-inter.css` -- Playfair Display headings, Inter body
- `inter-only.css` -- All-sans clean look

**Textures** (2 overlays):
- `grid-overlay.css` -- Subtle grid for technical feel
- `noise-grain.css` -- Film grain SVG overlay

## Directory Structure

```
slidev/
  manifest.json
  EXTENSION.md
  README.md
  index-entries.json
  context/project/slidev/
    animation/
      fade-in.md
      slide-in-below.md
      metric-cascade.md
      rough-marks.md
      staggered-list.md
      scale-in-pop.md
    style/
      colors/
        light-blue-corp.css
        dark-blue-navy.css
        dark-gold-premium.css
        light-green-growth.css
      typography/
        montserrat-inter.css
        playfair-inter.css
        inter-only.css
      textures/
        grid-overlay.css
        noise-grain.css
```

## Dependency Usage

Extensions that need Slidev resources declare the dependency in their manifest:

```json
{
  "dependencies": ["slidev"]
}
```

The extension loader auto-loads slidev before the dependent extension. No manual loading required.

## Consuming Extensions

- **founder** -- Uses animations and styles for pitch deck generation (`/deck` command)
- **present** -- Uses animations and styles for academic talk generation (`/slides` command)
