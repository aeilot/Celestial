# Reader Highlighting, Toolbar, Editor, and Localization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deliver multi-color highlight editing/deletion, robust floating toolbar placement, richer Markdown note tools, and full Stats/About-Me localization coverage.

**Architecture:** Keep persistence in `BookStore`/`PDFBook` and add a lightweight reader interaction state in the reader layer. `PDFKitView` emits selection/annotation events; `PDFReaderView` controls transient UI and dispatches actions. Notes panel and in-PDF popover share the same highlight mutation path.

**Tech Stack:** SwiftUI, PDFKit, AppStorage, xcstrings localization, XCTest, xcodebuild.

---

### Task 1: Add Highlight Color Utilities and Palette

**Files:**
- Modify: `CelestialPDFs/Models/PDFBook.swift`
- Test: `CelestialPDFsTests.swift`

**Step 1: Write the failing test**
```swift
func testHighlightColorHexFallbackAndNormalization() {
    let fallback = BookHighlight(pageIndex: 0, text: "x", boundsX: 0, boundsY: 0, boundsWidth: 1, boundsHeight: 1)
    XCTAssertEqual(fallback.colorHex, "#FFEB3B")
}
```

**Step 2: Run test to verify it fails**
Run: `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -destination 'platform=macOS' -only-testing:CelestialPDFsTests test`
Expected: FAIL if helpers/palette APIs referenced by next tests do not exist yet.

**Step 3: Write minimal implementation**
```swift
enum HighlightPalette {
    static let defaultHex = "#FFEB3B"
    static let allHex = ["#FFEB3B", "#FFD54F", "#AED581", "#4FC3F7", "#B39DDB", "#F48FB1", "#FFAB91", "#B0BEC5"]
}
```

**Step 4: Run test to verify it passes**
Run same command.
Expected: PASS for palette/default tests.

**Step 5: Commit**
```bash
git add CelestialPDFs/Models/PDFBook.swift CelestialPDFsTests.swift
git commit -m "feat: add highlight color palette utilities"
```

### Task 2: Render Stored Highlight Colors in PDFKit

**Files:**
- Modify: `CelestialPDFs/Views/PDFKitView.swift`
- Test: `CelestialPDFsTests.swift`

**Step 1: Write the failing test**
```swift
func testHexToColorFallbackUsesYellow() {
    XCTAssertNotNil(NSColor.fromHighlightHex("#FFEB3B"))
    XCTAssertEqual(NSColor.fromHighlightHex("bad").usingColorSpace(.deviceRGB), NSColor.yellow.usingColorSpace(.deviceRGB))
}
```

**Step 2: Run test to verify it fails**
Run: `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -destination 'platform=macOS' -only-testing:CelestialPDFsTests test`
Expected: FAIL with missing conversion API.

**Step 3: Write minimal implementation**
```swift
annotation.color = NSColor.fromHighlightHex(highlight.colorHex).withAlphaComponent(0.4)
```

**Step 4: Run test to verify it passes**
Run same command.
Expected: PASS.

**Step 5: Commit**
```bash
git add CelestialPDFs/Views/PDFKitView.swift CelestialPDFsTests.swift
git commit -m "fix: render persisted highlight colors in pdf annotations"
```

### Task 3: Add Highlight Update APIs in Store

**Files:**
- Modify: `CelestialPDFs/Models/BookStore.swift`
- Test: `CelestialPDFsTests.swift`

**Step 1: Write the failing test**
```swift
func testUpdateHighlightColorAndDeleteHighlight() {
    // Arrange test store + one book + one highlight
    // Act update color, then delete
    // Assert updated color persisted and highlight removed
}
```

**Step 2: Run test to verify it fails**
Run: `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -destination 'platform=macOS' -only-testing:CelestialPDFsTests test`
Expected: FAIL because mutation APIs do not exist.

**Step 3: Write minimal implementation**
```swift
func updateHighlightColor(in bookId: UUID, highlightId: UUID, colorHex: String)
func detachNotesLinkedToHighlight(in bookId: UUID, highlightId: UUID)
```

**Step 4: Run test to verify it passes**
Run same command.
Expected: PASS.

**Step 5: Commit**
```bash
git add CelestialPDFs/Models/BookStore.swift CelestialPDFsTests.swift
git commit -m "feat: add highlight color mutation and safe detach behavior"
```

### Task 4: Capture Annotation Clicks and Selection Anchors in PDFKitView

**Files:**
- Modify: `CelestialPDFs/Views/PDFKitView.swift`
- Test: `CelestialPDFsTests.swift`

**Step 1: Write the failing test**
```swift
func testSelectionStateRejectsEmptyBounds() {
    let state = ReaderSelectionState(selectedText: "x", pageIndex: 1, overlayBounds: .zero, pageBounds: .zero)
    XCTAssertFalse(state.isValidForToolbar)
}
```

**Step 2: Run test to verify it fails**
Run test command.
Expected: FAIL if new selection contract helpers are not present.

**Step 3: Write minimal implementation**
```swift
var onHighlightAnnotationTapped: ((UUID, CGRect) -> Void)?
```
Implement hit-testing for app-owned highlight annotations and emit tapped highlight ID + overlay rect.

**Step 4: Run test to verify it passes**
Run test command.
Expected: PASS for selection-state-related assertions; manual validation still required for click behavior.

**Step 5: Commit**
```bash
git add CelestialPDFs/Views/PDFKitView.swift CelestialPDFsTests.swift
git commit -m "feat: emit highlight annotation tap events from pdf view"
```

### Task 5: Implement Smart Floating Toolbar Placement Engine

**Files:**
- Modify: `CelestialPDFs/Views/PDFReaderView.swift`
- Test: `CelestialPDFsTests.swift`

**Step 1: Write the failing test**
```swift
func testToolbarPlacementFallsBackBelowWhenNoSpaceAbove() {
    // feed geometry fixture to placement function
    // assert returned y is below selection
}
```

**Step 2: Run test to verify it fails**
Run test command.
Expected: FAIL with missing placement helper.

**Step 3: Write minimal implementation**
Create deterministic helper:
```swift
func computeToolbarPoint(selection: CGRect, viewport: CGRect, toolbar: CGSize, margin: CGFloat) -> CGPoint
```
Apply candidate order: above -> below -> top edge -> bottom edge -> minimal overlap fallback.

**Step 4: Run test to verify it passes**
Run test command.
Expected: PASS.

**Step 5: Commit**
```bash
git add CelestialPDFs/Views/PDFReaderView.swift CelestialPDFsTests.swift
git commit -m "fix: add robust floating toolbar placement strategy"
```

### Task 6: Add In-PDF Highlight Popover (Color + Delete)

**Files:**
- Modify: `CelestialPDFs/Views/PDFReaderView.swift`
- Modify: `CelestialPDFs/Views/PDFKitView.swift`
- Modify: `CelestialPDFs/Models/BookStore.swift`

**Step 1: Write the failing test**
```swift
func testLastUsedHighlightColorPersistsInAppStorage() {
    UserDefaults.standard.removeObject(forKey: "lastHighlightColorHex")
    UserDefaults.standard.set("#AED581", forKey: "lastHighlightColorHex")
    XCTAssertEqual(UserDefaults.standard.string(forKey: "lastHighlightColorHex"), "#AED581")
}
```

**Step 2: Run test to verify it fails**
Run test command.
Expected: FAIL when app storage key path behavior is not wired.

**Step 3: Write minimal implementation**
- Add `@AppStorage("lastHighlightColorHex")` defaulting to palette default.
- Show highlight popover when annotation tap event arrives.
- Wire actions:
  - recolor -> `updateHighlightColor`
  - delete -> `detachNotesLinkedToHighlight` + `removeHighlight`

**Step 4: Run test to verify it passes**
Run test command.
Expected: PASS for storage behavior; manual UI verification for popover action flow.

**Step 5: Commit**
```bash
git add CelestialPDFs/Views/PDFReaderView.swift CelestialPDFs/Views/PDFKitView.swift CelestialPDFs/Models/BookStore.swift CelestialPDFsTests.swift
git commit -m "feat: add in-pdf highlight action popover"
```

### Task 7: Add Notes Panel Highlight Color/Delete Controls

**Files:**
- Modify: `CelestialPDFs/Views/ReaderNotesView.swift`
- Modify: `CelestialPDFs/Models/BookStore.swift`

**Step 1: Write the failing test**
```swift
func testDeletingHighlightDetachesLinkedNotesWithoutDeletingContent() {
    // arrange highlight-scoped note
    // delete highlight
    // assert note still exists with detached scope/text marker
}
```

**Step 2: Run test to verify it fails**
Run test command.
Expected: FAIL until detach behavior is integrated end-to-end.

**Step 3: Write minimal implementation**
- Add per-highlight row actions in notes panel: color picker chips + delete.
- Reuse same store APIs as in-PDF popover.

**Step 4: Run test to verify it passes**
Run test command.
Expected: PASS.

**Step 5: Commit**
```bash
git add CelestialPDFs/Views/ReaderNotesView.swift CelestialPDFs/Models/BookStore.swift CelestialPDFsTests.swift
git commit -m "feat: add notes panel highlight edit actions"
```

### Task 8: Upgrade Markdown Toolbar in NoteEditorView

**Files:**
- Modify: `CelestialPDFs/Views/ReaderNotesView.swift`
- Test: `CelestialPDFsTests.swift`

**Step 1: Write the failing test**
```swift
func testMarkdownLinePrefixHelperForQuoteAndList() {
    XCTAssertEqual(applyLinePrefix("line", prefix: "> "), "> line")
}
```

**Step 2: Run test to verify it fails**
Run test command.
Expected: FAIL with missing helper.

**Step 3: Write minimal implementation**
- Add toolbar buttons: H1, H2, bold, quote, bullet, numbered, code.
- Refactor insertion from append-only to line/selection-aware helper functions.

**Step 4: Run test to verify it passes**
Run test command.
Expected: PASS.

**Step 5: Commit**
```bash
git add CelestialPDFs/Views/ReaderNotesView.swift CelestialPDFsTests.swift
git commit -m "feat: improve markdown note editor toolbar"
```

### Task 9: Complete Stats/About-Me Localization

**Files:**
- Modify: `CelestialPDFs/Views/StatsView.swift`
- Modify: `CelestialPDFs/Localizable.xcstrings`

**Step 1: Write the failing test**
```swift
func testStatsLocalizationKeysResolve() {
    XCTAssertFalse(String(localized: "stats.title").isEmpty)
    XCTAssertFalse(String(localized: "stats.recent.empty").isEmpty)
}
```

**Step 2: Run test to verify it fails**
Run test command.
Expected: FAIL until keys exist in `Localizable.xcstrings`.

**Step 3: Write minimal implementation**
- Replace hardcoded strings with localization keys.
- Add missing translations for all used keys across supported locales.

**Step 4: Run test to verify it passes**
Run test command.
Expected: PASS.

**Step 5: Commit**
```bash
git add CelestialPDFs/Views/StatsView.swift CelestialPDFs/Localizable.xcstrings CelestialPDFsTests.swift
git commit -m "i18n: fully localize stats and about-me surface"
```

### Task 10: Final Verification and Cleanup

**Files:**
- Verify only (no required file edits unless fixes found)

**Step 1: Run full test/build verification**
Run:
```bash
xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -destination 'platform=macOS' test
xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug build
```
Expected: both commands succeed.

**Step 2: Manual QA checklist**
- Selection -> highlight with chosen default color.
- Click existing highlight -> recolor/delete popover appears and works.
- Notes panel actions mirror in-PDF behavior.
- Toolbar location follows smart fallback near viewport edges.
- Markdown toolbar operations apply to line/selection correctly.
- Stats/About-Me strings localize under language switch.

**Step 3: Commit verification artifacts/fixes if needed**
```bash
git add <fixed-files>
git commit -m "test: finalize reader highlight and localization verification fixes"
```
