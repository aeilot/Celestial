# Reader Highlighting, Toolbar, Editor, and Localization Design (2026-03-08)

## Scope
Implement five validated improvements:
1. Add multiple highlight color choices.
2. Support un-highlighting (delete existing highlights).
3. Fix floating toolbar placement when selection anchor is wrong.
4. Improve note editor experience with a richer Markdown toolbar.
5. Complete localization for the Stats/About Me page (currently underlocalized).

## User-Confirmed Interaction Decisions
- Highlight interaction model: Apple Books style.
  - First create highlight from text selection.
  - Then click existing highlight to open color/delete actions.
- Action entry points: dual entry.
  - In-PDF popover on highlight click.
  - Mirror actions in right-side Notes panel.
- Floating toolbar placement strategy: smart fallback.
  - Prefer above selection, fallback below, then viewport-edge fallback.
- Editor priority: Markdown toolbar (heading/bold/list/quote).

## Goals
- Highlights support multiple persistent colors and immediate visual feedback.
- Existing highlights can be recolored or deleted from both reader surfaces.
- Floating toolbar remains visible, stable, and non-overlapping in most cases.
- Note editing is faster with first-class Markdown authoring controls.
- StatsView and About-Me-related strings are fully localized through xcstrings keys (not hardcoded UI literals).

## Non-Goals
- No full reader architecture rewrite beyond a lightweight interaction state object.
- No background auto-draft persistence redesign for notes.
- No localization copy overhaul outside this scope except required key extraction tied to touched UI.

## Recommended Approach
Adopt a medium-scope state-centralized interaction design:
- Add `ReaderInteractionState` to coordinate selection state, highlight hit-testing state, and toolbar/popup anchors.
- Keep `PDFKitView` as event producer (selection changed, annotation clicked, page context), while `PDFReaderView` remains decision/control layer.
- Keep data persistence in existing `BookStore/PDFBook` structures, extending only where needed for color utilities.

Why this approach:
- Resolves all five requests without heavyweight refactor.
- Removes duplicated/fragile placement decisions across views.
- Keeps compatibility with existing persisted highlights (`colorHex` already exists).

## Architecture and Components

### 1) Reader Interaction State (new lightweight coordination layer)
Likely location: `CelestialPDFs/Views/PDFReaderView.swift` (nested/private type) or new file under `CelestialPDFs/Models/` if reuse grows.

Responsibilities:
- Hold normalized current text selection info.
- Hold current highlight target (if user clicked an existing annotation).
- Expose UI intents:
  - show selection toolbar
  - show highlight action popover
  - hide all transient overlays
- Provide computed anchors for floating components.

### 2) Highlight Color System
Files:
- `CelestialPDFs/Models/PDFBook.swift`
- `CelestialPDFs/Views/PDFReaderView.swift`
- `CelestialPDFs/Views/PDFKitView.swift`
- `CelestialPDFs/Views/ReaderNotesView.swift`

Design:
- Keep source of truth on `BookHighlight.colorHex`.
- Introduce canonical palette (6-8 colors) with stable hex IDs.
- Add color conversion utility (`hex -> NSColor/Color`) with safe fallback to default yellow.
- Add a persisted “last used highlight color” app setting (AppStorage) so new highlights default to user’s latest choice.

### 3) In-PDF Highlight Action Popover
Files:
- `PDFKitView` for annotation click reporting.
- `PDFReaderView` for presenting popover and dispatching actions.

Behavior:
- Clicking a Celestial-created highlight annotation opens a compact popover anchored to the annotation rect.
- Popover actions:
  - choose color (applies immediately)
  - delete highlight
- Popover closes on outside click, page change, or selection replacement.

### 4) Notes Panel Dual Entry for Highlight Actions
File:
- `ReaderNotesView.swift`

Behavior:
- For highlight-scoped notes and/or highlight-linked rows, show color swatch selector + delete highlight action.
- Action routes back to shared handlers (same mutation path as in-PDF popover).
- When deleting highlight:
  - Remove highlight entity.
  - Preserve associated note content but mark as detached (“original highlight deleted”) to prevent silent data loss.

### 5) Floating Toolbar Placement Engine
Files:
- `PDFReaderView.swift`
- optional helper in `PDFKitView.swift` for stable anchor rects

Algorithm:
- Inputs: selection rect in reader overlay coordinates, viewport bounds, toolbar size, margins.
- Candidate order:
  1. above-center
  2. below-center
  3. top-edge clamped
  4. bottom-edge clamped
- Clamp x in all cases to remain visible horizontally.
- Reject candidates that overlap selection rect (except final fallback).
- If all overlap, pick minimal-overlap candidate.
- Recompute on selection/scroll/zoom/resize with lightweight coalescing to reduce jitter.

### 6) Markdown Editor Toolbar Upgrade
File:
- `ReaderNotesView.swift` (`NoteEditorView`)

Behavior:
- Replace current minimal inline buttons with grouped Markdown tools:
  - `H1`, `H2`, Bold, Quote, Bullet list, Numbered list, Code.
- Editing actions should operate on current line/selection rather than append-only behavior.
- Keep save/cancel lifecycle unchanged for this phase.

### 7) Full Localization for Stats/About Me
Files:
- `Views/StatsView.swift`
- `Localizable.xcstrings`

Design:
- Replace hardcoded literals in Stats/About-Me flow with localization keys.
- Include labels/placeholders/buttons/picker messages and stat titles.
- Ensure all used keys have localized entries across current supported locales in `Localizable.xcstrings`.
- Avoid direct Chinese literals in view code except where intentionally non-localized (none expected in this scope).

## Data Flow

### New Highlight Creation
1. User selects text in `PDFView`.
2. `PDFKitView` emits normalized selection state (text, pageIndex, pageRect, overlayRect).
3. `PDFReaderView` shows selection floating toolbar.
4. User taps highlight action; new `BookHighlight` created using current palette default color.
5. `BookStore.addHighlight` persists; `PDFKitView.applyHighlights` redraws annotations with stored color.

### Existing Highlight Edit/Delete
1. User clicks highlight annotation in PDF or uses Notes panel control.
2. Interaction state stores target highlight ID + anchor rect.
3. Color change updates highlight record in store; annotation redraw reflects immediately.
4. Delete removes highlight; related notes stay but become detached with explicit scope messaging.

### Toolbar Positioning
1. Selection anchor updates from `PDFViewSelectionChanged`.
2. Placement engine computes best candidate point.
3. Toolbar renders at computed position; updates coalesced during rapid viewport changes.

## Error Handling and Edge Cases
- Ignore highlight creation if selection text is empty/whitespace.
- Guard invalid page indices and zero-size bounds.
- If clicked annotation cannot map to saved highlight, close popover gracefully.
- If `colorHex` parsing fails, use default yellow to avoid invisible highlights.
- Multi-line selections spanning pages: use first-page anchor for toolbar; highlight creation remains single-page per current model.
- Deleting a highlight with linked note should never delete note content implicitly.

## Testing Strategy

### Unit-Level (where practical)
- `colorHex` parsing and fallback behavior.
- Toolbar candidate selection logic with deterministic geometry fixtures.
- Highlight mutation helpers (recolor/delete) preserve expected invariants.

### Integration / UI-Behavior Checks
- Create highlight with each palette color and verify persistence after reopen.
- Click existing highlight in PDF: popover appears at sane location.
- Change highlight color from PDF popover and Notes panel; both paths update same record.
- Delete highlight from both paths; detached note behavior is consistent.
- Selection toolbar placement remains usable near top/bottom edges and after zoom.
- Stats/About-Me screens show localized strings under switched app language.

### Build Verification
- `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug build`

## Risks and Mitigations
- Risk: PDF annotation click handling can be brittle depending on PDFKit behaviors.
  - Mitigation: restrict to app-owned annotations (`userName == "CelestialPDFs"`) and maintain safe fallback.
- Risk: placement recalculations can jitter on continuous scroll.
  - Mitigation: coalesced updates and deterministic candidate ordering.
- Risk: localization key drift between code and xcstrings.
  - Mitigation: key naming convention and build-time localization validation via xcodebuild.

## Rollout and Compatibility
- Backward compatible with existing saved books/highlights.
- Existing highlights without valid color parse still render with fallback color.
- No storage migration required.
