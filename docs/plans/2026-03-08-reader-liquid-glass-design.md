# Reader Liquid Glass Design (2026-03-08)

## Scope
Apply a Liquid Glass redesign to the PDF reader with emphasis on immersive reading.

## Confirmed Requirements
- Use full reader Liquid Glass language for:
  - top toolbar
  - left TOC sidebar
  - right notes/AI sidebar
- Keep bottom status bar non-glass.
- Remove floating selection toolbar entirely.
- Top toolbar information architecture:
  - Left: back, left sidebar toggle, title
  - Right: color, Note, AI, right sidebar toggle
- Top bar visibility should be user-configurable with modes:
  - always visible (default)
  - show on hover near top
  - scroll-aware show/hide

## Goals
- Increase reading immersion by reducing heavy opaque chrome.
- Keep critical reading actions accessible from the top toolbar.
- Preserve current note/highlight/AI workflows.

## Non-Goals
- No data model changes for books/highlights/notes.
- No behavior changes to bottom status bar except optional spacing polish.

## Approaches Considered
1. Visual-only toolbar reskin
- Low risk but limited immersion gains.

2. Immersive top bar only
- Better, but leaves side surfaces inconsistent.

3. Full reader glass language (chosen)
- Highest visual consistency and immersion.
- Requires coordinated updates across top bar + side panels.

## Chosen Design

### Layout and Interaction
- Replace dense top bar with a floating glass capsule.
- Keep semantic order exactly as requested:
  - Left: back, left sidebar, title
  - Right: colors, Note, AI, right sidebar
- Keep selection-driven actions in top bar:
  - Color applies highlight/change color when selection exists.
  - Note creates page note when selection exists; otherwise creates book note.
  - AI opens AI tab with page context when selection exists; otherwise book context.
- Right sidebar toggle controls panel visibility.
- Note/AI buttons can switch right panel tab and ensure panel is opened.

### Visual System
- Shared glass styling tokens for top bar, TOC panel, right panel:
  - translucent fill with modest blur
  - subtle 1px border
  - soft highlight and shadow
  - rounded corners (capsule for top controls, large corners for panels)
- Circular icon buttons for all top controls.
- Interaction states:
  - hover: brighter/raised
  - pressed: slight compression
  - active: stronger accent border/fill

### Visibility Modes
- Add `readerTopBarVisibility` app setting:
  - `always`
  - `hover`
  - `scroll`
- Default value: `always`.

### Floating Toolbar Removal
- Remove floating selection toolbar from reader UI.
- Keep selection state from PDFKit so toolbar actions can still consume selected text.
- Remove anchor/projection plumbing that existed only for floating toolbar positioning.

## Component-Level Changes
- `CelestialPDFs/Views/PDFReaderView.swift`
  - Build new floating glass top bar and circular controls.
  - Route highlight/note/AI actions through top controls.
  - Introduce top bar visibility behavior and local UI state for hover/scroll.
  - Update side panel and TOC panel visuals to glass style.
  - Keep status bar non-glass.

- `CelestialPDFs/Views/PDFKitView.swift`
  - Keep selection/page binding updates needed by reader actions.
  - Remove `selectionAnchor` binding and related projection refresh code.

- `CelestialPDFs/Views/SettingsView.swift`
  - Add reader top bar visibility setting in reading section.

## Risks and Mitigations
- Risk: discoverability drop after floating toolbar removal.
- Mitigation: keep Note/AI/color controls always available in top bar and disable/enable states clear.

- Risk: glass effects reduce text contrast near toolbar.
- Mitigation: cap blur intensity and keep compact top bar footprint.

- Risk: top bar auto-visibility behavior may feel jumpy.
- Mitigation: use conservative thresholds and damped animations.

## Verification
### Manual
- Ensure highlight/note/AI flows work with and without selection.
- Verify top bar layout order and active states.
- Verify visibility mode switching (`always/hover/scroll`) and default value.
- Verify side panels match glass style and bottom status bar remains non-glass.
- Verify TOC and right panel toggles still function.

### Build
- `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug build`
