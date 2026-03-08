# Floating Toolbar Position Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the reader floating toolbar anchor to the first selected line, 2px above text, and stay stable across scrolling and zooming.

**Architecture:** Persist toolbar anchor in PDF page coordinates (`pageIndex` + `firstLineRectInPage`) and reproject to overlay coordinates whenever PDF geometry changes. Keep highlight persistence (`selectionPageBounds`) separate so highlight behavior does not regress.

**Tech Stack:** SwiftUI, PDFKit (`PDFView`, `PDFSelection`, `PDFPage`), xcodebuild test/build.

---

### Task 1: Add Anchor Model and Placement Unit Tests

**Files:**
- Modify: `CelestialPDFs/Views/PDFReaderView.swift`
- Test: `CelestialPDFsTests.swift`

**Step 1: Write the failing tests**

Add tests for toolbar placement behavior:
- `testToolbarPrefers2pxAboveFirstLineWhenSpaceExists()`
- `testToolbarFallsBackBelowWhenAboveWouldClip()`
- `testToolbarClampsHorizontallyWithinViewport()`

Expected assertions:
- Above placement uses `selection.minY - toolbar.height / 2 - 2`.
- Fallback below uses `selection.maxY + toolbar.height / 2 + 2`.
- Returned x coordinate is clamped between viewport-safe bounds.

**Step 2: Run tests to verify they fail**

Run: `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug test -only-testing:CelestialPDFsTests`
Expected: FAIL because placement API does not yet expose exact deterministic rule needed by tests.

**Step 3: Implement minimal production changes**

In `PDFReaderView.swift`:
- Add a small `SelectionAnchor` model (page index + first-line rect in page coordinates).
- Update `FloatingToolbarPlacement.computeToolbarPoint` signature/logic so tests can validate exact 2px-above and below fallback behavior.

**Step 4: Run tests to verify pass**

Run: `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug test -only-testing:CelestialPDFsTests`
Expected: PASS for new placement tests.

**Step 5: Commit**

```bash
git add CelestialPDFs/Views/PDFReaderView.swift CelestialPDFsTests.swift
git commit -m "test: cover floating toolbar placement rules"
```

### Task 2: Emit First-Line Page-Space Anchor from PDFKitView

**Files:**
- Modify: `CelestialPDFs/Views/PDFKitView.swift`
- Modify: `CelestialPDFs/Views/PDFReaderView.swift`

**Step 1: Write the failing test**

Add an integration-style test in `CelestialPDFsTests.swift` for first-line extraction helper:
- `testSelectionAnchorUsesFirstLineOnFirstSelectedPage()`

Expected assertions:
- Multi-line selection chooses first line rect.
- Multi-page selection chooses first page.

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug test -only-testing:CelestialPDFsTests/testSelectionAnchorUsesFirstLineOnFirstSelectedPage`
Expected: FAIL because helper/extraction path does not exist.

**Step 3: Write minimal implementation**

In `PDFKitView.swift`:
- Add new binding for `selectionAnchor`.
- In `selectionChanged`, compute first-line rect on first selected page:
  - Prefer line-granularity extraction from `PDFSelection` fragments if available.
  - Fallback to page selection bounds when line extraction is unavailable.
- Populate:
  - `selectedText`
  - `selectionPageBounds`
  - `selectionPageIndex`
  - `selectionAnchor`

In `PDFReaderView.swift`:
- Add matching `@State` for `selectionAnchor`.
- Wire new binding into `PDFKitView`.

**Step 4: Run tests to verify pass**

Run: `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug test -only-testing:CelestialPDFsTests`
Expected: PASS for first-line anchor and placement tests.

**Step 5: Commit**

```bash
git add CelestialPDFs/Views/PDFKitView.swift CelestialPDFs/Views/PDFReaderView.swift CelestialPDFsTests.swift
git commit -m "feat: anchor floating toolbar to first selected line"
```

### Task 3: Reproject Anchor on Scroll/Zoom/Page Geometry Changes

**Files:**
- Modify: `CelestialPDFs/Views/PDFKitView.swift`
- Modify: `CelestialPDFs/Views/PDFReaderView.swift`

**Step 1: Write the failing test**

Add a focused test for geometry update behavior:
- `testAnchorProjectionUpdatesOnGeometryChange()`

Expected assertion:
- Reprojected overlay rect changes predictably when scale/viewport changes and does not clear valid anchor.

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug test -only-testing:CelestialPDFsTests/testAnchorProjectionUpdatesOnGeometryChange`
Expected: FAIL because no explicit geometry reproject path exists.

**Step 3: Write minimal implementation**

In `PDFKitView.Coordinator`:
- Observe geometry-relevant notifications/events (scale/page/layout/scroll updates available from PDFView or enclosing scroll view).
- On each event:
  - if selection anchor exists and page is valid, reproject page rect to overlay rect
  - publish refreshed overlay anchor state without mutating text selection
- Clear anchor safely when page/document becomes invalid.

In `PDFReaderView.swift`:
- Drive `shouldShowFloatingToolbar` from valid anchor+selection state.
- Compute final toolbar position from latest projected overlay anchor with exact 2px rule.

**Step 4: Run tests and build**

Run:
- `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug test -only-testing:CelestialPDFsTests`
- `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug build`

Expected:
- Tests PASS
- Build SUCCEEDS

**Step 5: Commit**

```bash
git add CelestialPDFs/Views/PDFKitView.swift CelestialPDFs/Views/PDFReaderView.swift CelestialPDFsTests.swift
git commit -m "fix: keep floating toolbar stable during zoom and scroll"
```

### Task 4: Manual Validation and Cleanup

**Files:**
- Modify: `docs/plans/2026-03-08-floating-toolbar-position-implementation.md` (checklist status only, optional)

**Step 1: Manual verification run**

Validate in app:
- Select text near top/middle/bottom of viewport.
- Confirm toolbar sits 2px above first selected line when space exists.
- Confirm fallback below only when above clips.
- Zoom in/out and scroll with selection active; confirm no jump.
- Confirm multi-line and multi-page anchor behavior uses first line on first page.

**Step 2: Regression check**

Confirm:
- Highlight creation still works.
- Highlight popover behavior still works.
- Selection clear still hides toolbar.

**Step 3: Final test/build run**

Run:
- `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug test`
- `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug build`

Expected:
- Full test target PASS
- Build SUCCEEDS

**Step 4: Final commit**

```bash
git add CelestialPDFs/Views/PDFKitView.swift CelestialPDFs/Views/PDFReaderView.swift CelestialPDFsTests.swift
git commit -m "feat: finalize stable floating toolbar positioning"
```
