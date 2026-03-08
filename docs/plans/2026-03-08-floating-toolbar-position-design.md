# Floating Toolbar Position Design (2026-03-08)

## Scope
Improve PDF reader floating toolbar positioning so it is stable and predictable when selecting text at different locations.

## Goals
- Anchor toolbar to the first selected text line.
- Place toolbar 2px above the selected text by default.
- Keep toolbar responsive to PDF scrolling and zooming.
- Avoid unpredictable jumps when selection location changes.

## Non-Goals
- Redesign toolbar actions or visual style.
- Change highlight persistence model beyond what is needed for toolbar positioning.

## Approaches Considered
1. Overlay snapshot only
- Keep using transient overlay bounds and only tweak placement math.
- Rejected because stale coordinate transforms still cause jumpy behavior.

2. Page-space anchor + live reprojection (chosen)
- Store first-line anchor in page coordinates and reproject into overlay coordinates on geometry changes.
- Chosen because it is stable across zoom/scroll and deterministic.

3. Quad-point anchoring
- Use low-level selection quad points for maximum precision.
- Rejected for current scope because complexity is higher than needed.

## Chosen Design

### Positioning Architecture
- Replace toolbar positioning source from `selectionOverlayBounds` to a persistent page-space anchor:
  - `pageIndex`
  - `firstLineRectInPage`
- On selection change:
  - derive first selected line rect on the first selected page
  - store it as anchor state
  - project anchor to overlay space for immediate toolbar placement
- On zoom/scroll/page transform changes:
  - keep anchor in page space unchanged
  - reproject anchor to overlay space and update toolbar location

### Placement Rules
- Default placement:
  - toolbar x follows anchor and is clamped to viewport width
  - toolbar bottom edge is 2px above anchor rect top edge
- Vertical fallback:
  - if above placement clips out of viewport, place below anchor instead
- Multi-line/multi-page selection:
  - always anchor to first selected line on first selected page

### Component Changes
- `CelestialPDFs/Views/PDFKitView.swift`
  - add selection anchor binding payload for toolbar
  - compute first-line page-space anchor in `selectionChanged`
  - observe geometry-changing events and trigger reprojection updates
- `CelestialPDFs/Views/PDFReaderView.swift`
  - use anchor-driven projection for floating toolbar position
  - enforce 2px above-first-line placement rule with viewport clamping/fallback
- Keep `selectionPageBounds` highlight persistence path unchanged.

## Data Flow
1. User selects text in `PDFView`.
2. Coordinator extracts:
- `selectedText`
- `selectionPageIndex`
- `selectionPageBounds` (for highlight creation)
- `selectionAnchor` (first-line page-space toolbar anchor)
3. Reader projects anchor into overlay coordinates.
4. Toolbar position is recomputed on selection and geometry updates.

## Edge Cases and Error Handling
- Empty/whitespace selection clears anchor and hides toolbar.
- Missing page/document for stored anchor clears anchor safely.
- Selection spanning pages still uses first page anchor only.

## Verification
### Manual
- Select text at top/middle/bottom of viewport and verify stable placement.
- Zoom in/out with selection active and verify anchor tracking.
- Scroll with selection active and verify toolbar reprojects without jumps.
- Multi-line selection anchors to first line.
- Multi-page selection anchors to first page first line.

### Build
- `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug build`

## Risks
- PDFView notification coverage for geometry changes may vary; mitigation is to combine selection/page/scale/scroll-related updates.
- First-line extraction may be inconsistent for unusual PDFs; mitigation is to fallback to selection bounds on first page when line granularity is unavailable.
