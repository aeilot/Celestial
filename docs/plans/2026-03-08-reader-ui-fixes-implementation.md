# Reader UI Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix serif typography propagation, bookshelf grid shelf separators, floating selection toolbar visibility, adaptive notes sidebar sizing, and PDF highlight persistence.

**Architecture:** Keep the current SwiftUI + PDFKit structure and apply focused fixes in `PDFReaderView`, `PDFKitView`, `ReaderNotesView`, and typography call sites. Split selection state into overlay-anchor geometry (for toolbar position) and page-space geometry (for persisted highlights). Use existing `@AppStorage` and `BookHighlight` persistence fields to avoid migrations.

**Tech Stack:** SwiftUI (macOS 14), PDFKit, Swift Observation (`@Environment(BookStore.self)`), XCTest.

---

References: @test-driven-development, @verification-before-completion, @requesting-code-review

### Task 1: Add tests for reader selection/highlight state helpers

**Files:**
- Create: `CelestialPDFs/Models/ReaderSelectionState.swift`
- Modify: `CelestialPDFsTests.swift`

**Step 1: Write the failing test**

```swift
func testReaderSelectionStateRequiresNonEmptyTextAndPositiveBounds() {
    let invalid = ReaderSelectionState(
        selectedText: "   ",
        pageIndex: 0,
        overlayBounds: .zero,
        pageBounds: CGRect(x: 10, y: 10, width: 20, height: 8)
    )
    XCTAssertFalse(invalid.isValidForToolbar)

    let valid = ReaderSelectionState(
        selectedText: "word",
        pageIndex: 2,
        overlayBounds: CGRect(x: 5, y: 5, width: 30, height: 12),
        pageBounds: CGRect(x: 12, y: 200, width: 30, height: 12)
    )
    XCTAssertTrue(valid.isValidForToolbar)
    XCTAssertTrue(valid.isValidForHighlight)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -destination 'platform=macOS' -only-testing:CelestialPDFsTests/CelestialPDFsTests/testReaderSelectionStateRequiresNonEmptyTextAndPositiveBounds test`
Expected: FAIL with missing `ReaderSelectionState` symbols.

**Step 3: Write minimal implementation**

```swift
struct ReaderSelectionState {
    var selectedText: String
    var pageIndex: Int?
    var overlayBounds: CGRect?
    var pageBounds: CGRect?

    var normalizedText: String { selectedText.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValidForToolbar: Bool {
        !normalizedText.isEmpty && (overlayBounds?.width ?? 0) > 0 && (overlayBounds?.height ?? 0) > 0
    }
    var isValidForHighlight: Bool {
        !normalizedText.isEmpty && pageIndex != nil && (pageBounds?.width ?? 0) > 0 && (pageBounds?.height ?? 0) > 0
    }
}
```

**Step 4: Run test to verify it passes**

Run: same command as Step 2.
Expected: PASS.

**Step 5: Commit**

```bash
git add CelestialPDFs/Models/ReaderSelectionState.swift CelestialPDFsTests.swift
git commit -m "test: add reader selection state validation coverage"
```

### Task 2: Fix floating toolbar signal path and highlight geometry source

**Files:**
- Modify: `CelestialPDFs/Views/PDFKitView.swift`
- Modify: `CelestialPDFs/Views/PDFReaderView.swift`
- Test: `CelestialPDFsTests.swift`

**Step 1: Write the failing test**

```swift
func testHighlightUsesPageBoundsNotOverlayBounds() {
    let state = ReaderSelectionState(
        selectedText: "sample",
        pageIndex: 1,
        overlayBounds: CGRect(x: 0, y: 0, width: 100, height: 20),
        pageBounds: CGRect(x: 40, y: 300, width: 100, height: 20)
    )
    let h = ReaderSelectionState.makeHighlight(from: state)
    XCTAssertEqual(h?.pageIndex, 1)
    XCTAssertEqual(h?.boundsX, 40)
    XCTAssertEqual(h?.boundsY, 300)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -destination 'platform=macOS' -only-testing:CelestialPDFsTests/CelestialPDFsTests/testHighlightUsesPageBoundsNotOverlayBounds test`
Expected: FAIL because `makeHighlight` doesn’t exist yet.

**Step 3: Write minimal implementation**

```swift
extension ReaderSelectionState {
    static func makeHighlight(from state: ReaderSelectionState) -> BookHighlight? {
        guard state.isValidForHighlight,
              let pageIndex = state.pageIndex,
              let pageBounds = state.pageBounds else { return nil }
        return BookHighlight(
            pageIndex: pageIndex,
            text: state.normalizedText,
            boundsX: pageBounds.origin.x,
            boundsY: pageBounds.origin.y,
            boundsWidth: pageBounds.width,
            boundsHeight: pageBounds.height
        )
    }
}
```

Then wire into views:
- `PDFKitView.Coordinator.selectionChanged` emits both overlay bounds and page-space bounds.
- `PDFReaderView` derives toolbar visibility from valid selection state + `showFloatingToolbarSetting`.
- `highlightSelection()` uses `ReaderSelectionState.makeHighlight`.

**Step 4: Run focused tests + full test target**

Run:
- `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -destination 'platform=macOS' -only-testing:CelestialPDFsTests/CelestialPDFsTests/testHighlightUsesPageBoundsNotOverlayBounds test`
- `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -destination 'platform=macOS' test`
Expected: PASS.

**Step 5: Commit**

```bash
git add CelestialPDFs/Views/PDFKitView.swift CelestialPDFs/Views/PDFReaderView.swift CelestialPDFs/Models/ReaderSelectionState.swift CelestialPDFsTests.swift
git commit -m "fix: restore floating toolbar and page-space highlighting"
```

### Task 3: Remove bookshelf grid shelf row separators

**Files:**
- Modify: `CelestialPDFs/Views/BookshelfView.swift`
- Test: manual UI verification notes in plan

**Step 1: Write the failing test/check definition**

```text
Manual acceptance check (failing before fix):
- Bookshelf in grid mode currently shows shelf row separators between rows.
- Expected: no row separators.
```

**Step 2: Run baseline check to confirm failure**

Run app via Xcode (`⌘R`) and open bookshelf grid.
Expected: separators are visible.

**Step 3: Write minimal implementation**

```swift
// In shelfGridContent loop, remove shelfDivider insertion.
// Keep listView Divider() calls unchanged.
```

**Step 4: Re-run manual check**

Expected: grid row separators are gone; list view separators still present.

**Step 5: Commit**

```bash
git add CelestialPDFs/Views/BookshelfView.swift
git commit -m "ui: remove bookshelf grid shelf row separators"
```

### Task 4: Apply serif toggle consistently to major content text

**Files:**
- Modify: `CelestialPDFs/ContentView.swift`
- Modify: `CelestialPDFs/Views/BookshelfView.swift`
- Modify: `CelestialPDFs/Views/BookCardView.swift`
- Modify: `CelestialPDFs/Views/ReaderNotesView.swift`
- Modify: `CelestialPDFs/Views/NotesListView.swift`
- Modify: `CelestialPDFs/Views/VocabularyView.swift`
- Modify: `CelestialPDFs/Views/AIChatView.swift`
- Modify: `CelestialPDFs/Views/StatsView.swift`

**Step 1: Write failing checks**

```text
Manual acceptance checks (currently failing):
- Toggle serif in Settings.
- Typography in bookshelf/sidebar/vocabulary/AI/stats does not fully switch.
```

**Step 2: Confirm failures in running app**

Run app and verify unchanged fonts outside note editor.
Expected: mismatch observed.

**Step 3: Write minimal implementation**

```swift
// Replace hardcoded .font(...) on content text with .appFont(...)
// or dynamic design based on `useSerifFont`.
Text(book.title).appFont(.body, weight: .semibold)
Text(store.userName).appFont(.caption)
```

Rules:
- Apply to content/readable text.
- Avoid forcing serif on icon-only controls and tiny utility UI that should remain system-default.

**Step 4: Re-run manual checks**

Expected: serif toggle visibly updates all targeted content surfaces.

**Step 5: Commit**

```bash
git add CelestialPDFs/ContentView.swift CelestialPDFs/Views/BookshelfView.swift CelestialPDFs/Views/BookCardView.swift CelestialPDFs/Views/ReaderNotesView.swift CelestialPDFs/Views/NotesListView.swift CelestialPDFs/Views/VocabularyView.swift CelestialPDFs/Views/AIChatView.swift CelestialPDFs/Views/StatsView.swift CelestialPDFs/AppFontModifier.swift
git commit -m "feat: apply serif typography setting across content views"
```

### Task 5: Make notes editor split user-resizable with stronger minimum widths

**Files:**
- Modify: `CelestialPDFs/Views/ReaderNotesView.swift`
- Test: manual resize behavior verification

**Step 1: Write failing checks**

```text
Manual acceptance checks (currently failing):
- Open note editor and resize window/split.
- Editor or preview can become too narrow to read.
```

**Step 2: Confirm failure in app**

Run app, open reader -> notes editor, drag split and resize window.
Expected: one pane can collapse too much.

**Step 3: Write minimal implementation**

```swift
// Keep HSplitView and enforce stronger min widths.
.editorPane.frame(minWidth: 420, idealWidth: 520)
.previewPane.frame(minWidth: 320, idealWidth: 420)
```

If needed, track split behavior in state and clamp sizes.

**Step 4: Re-run manual checks**

Expected: split remains user-resizable, but panes remain readable at minimum widths.

**Step 5: Commit**

```bash
git add CelestialPDFs/Views/ReaderNotesView.swift
git commit -m "fix: improve adaptive widths for notes editor split"
```

### Task 6: Full verification and review prep

**Files:**
- Modify (if needed): any touched files from Tasks 1-5

**Step 1: Run full automated verification**

Run:
- `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -destination 'platform=macOS' test`
- `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug build`
Expected: PASS.

**Step 2: Run end-to-end manual regression sweep**

Checklist:
- Serif setting propagates across target views.
- Grid shelf separators removed only in grid mode.
- Floating toolbar appears on selection and hides when selection clears.
- Highlighting creates accurate, persistent annotations.
- Notes editor split resizes with safe minimum widths.

Expected: all pass.

**Step 3: Request code review**

Use @requesting-code-review workflow and capture findings.

**Step 4: Address review feedback (if any)**

Apply minimal deltas and rerun impacted checks.

**Step 5: Final commit (only if Step 4 made changes)**

```bash
git add <changed-files>
git commit -m "chore: address review feedback for reader ui fixes"
```

## Notes
- Worktree recommendation: execute this in an isolated `codex/<topic>` branch/worktree.
- Keep changes DRY and avoid unrelated UI refactors.
- Preserve existing Chinese UI copy.
