# Reader Liquid Glass Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement an immersive Liquid Glass reader UI with top-bar-driven actions, remove floating selection toolbar, and keep bottom status bar non-glass.

**Architecture:** Keep existing reader data flows (selection/highlight/note/AI) and refactor only presentation and toolbar action entry points. Introduce a small visibility-mode state model for top bar behavior, then apply unified glass style tokens to reader surfaces (top bar + side panels).

**Tech Stack:** SwiftUI (macOS), PDFKit (`NSViewRepresentable`), XCTest.

---

### Task 1: Add failing tests for new reader top bar behavior model

**Files:**
- Modify: `CelestialPDFsTests.swift`
- Modify: `CelestialPDFs/Models/PDFBook.swift`

**Step 1: Write failing tests**
- Add tests for a new `ReaderTopBarVisibility` enum default and decoding fallback behavior.
- Add tests for a pure helper (`ReaderTopBarVisibilityState`) that decides if top bar should be visible under `always/hover/scroll`.

**Step 2: Run tests to verify fail**
Run: `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug -destination 'platform=macOS' test -only-testing:CelestialPDFsTests`
Expected: FAIL because new types/logic are not implemented.

**Step 3: Minimal implementation**
- Implement `ReaderTopBarVisibility` and `ReaderTopBarVisibilityState` in `PDFBook.swift`.

**Step 4: Run tests to verify pass**
Run same test command.
Expected: New tests PASS.

**Step 5: Commit**
```bash
git add CelestialPDFs/Models/PDFBook.swift CelestialPDFsTests.swift
git commit -m "test: add reader top bar visibility behavior coverage"
```

### Task 2: Add failing tests for selection-state after floating toolbar removal

**Files:**
- Modify: `CelestialPDFsTests.swift`
- Modify: `CelestialPDFs/Models/PDFBook.swift`

**Step 1: Write failing tests**
- Update selection state tests to assert highlight validity no longer depends on overlay bounds.
- Remove/replace floating toolbar placement tests with tests around top-bar action eligibility based on selection text.

**Step 2: Run tests to verify fail**
Run: `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug -destination 'platform=macOS' test -only-testing:CelestialPDFsTests`
Expected: FAIL with old assumptions.

**Step 3: Minimal implementation**
- Remove `isValidForToolbar` / floating-toolbar-centric assumptions from `ReaderSelectionState`.
- Add small helper for top bar action enabled state if needed.

**Step 4: Run tests to verify pass**
Run same command.
Expected: Updated tests PASS.

**Step 5: Commit**
```bash
git add CelestialPDFs/Models/PDFBook.swift CelestialPDFsTests.swift
git commit -m "refactor: align selection state with top-bar action model"
```

### Task 3: Implement reader UI Liquid Glass surfaces and top bar action routing

**Files:**
- Modify: `CelestialPDFs/Views/PDFReaderView.swift`

**Step 1: Write failing test/verification note**
- Since this is SwiftUI visual structure, codify behavior with existing unit-testable helpers first (done in Task 1/2).
- Define manual checks for control order and action routing.

**Step 2: Implement minimal UI refactor**
- Replace old toolbar container with floating glass top bar.
- Keep control order: left `back/left-sidebar/title`, right `colors/Note/AI/right-sidebar`.
- Remove floating toolbar references.
- Apply glass styling to TOC + right panel; keep status bar non-glass.

**Step 3: Run build**
Run: `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug build`
Expected: BUILD SUCCEEDED.

**Step 4: Manual verification**
- Confirm top bar control order and actions.
- Confirm no floating toolbar appears on selection.
- Confirm status bar remains non-glass.

**Step 5: Commit**
```bash
git add CelestialPDFs/Views/PDFReaderView.swift
git commit -m "feat: apply liquid glass reader top bar and panel styling"
```

### Task 4: Remove obsolete PDFKit anchor plumbing and expose top bar visibility setting

**Files:**
- Modify: `CelestialPDFs/Views/PDFKitView.swift`
- Modify: `CelestialPDFs/Views/SettingsView.swift`

**Step 1: Write failing test/verification note**
- Add/adjust unit tests only where pure logic changed.
- Manual verify that selection-based actions still work.

**Step 2: Minimal implementation**
- Remove `selectionAnchor` binding + projection-only code from `PDFKitView`.
- Add reading setting for top bar visibility mode in `SettingsView`.

**Step 3: Run tests + build**
- `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug -destination 'platform=macOS' test -only-testing:CelestialPDFsTests`
- `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug build`
Expected: all pass.

**Step 4: Commit**
```bash
git add CelestialPDFs/Views/PDFKitView.swift CelestialPDFs/Views/SettingsView.swift
 git commit -m "feat: remove floating-toolbar anchor plumbing and add top bar visibility setting"
```

### Task 5: Final verification and cleanup

**Files:**
- Modify if needed: `CelestialPDFsTests.swift`

**Step 1: Full verification**
- Run focused tests and Debug build once more.

**Step 2: Review diff for scope correctness**
- Ensure bottom status bar styling unchanged from non-glass baseline.
- Ensure no floating-toolbar code paths remain.

**Step 3: Final commit (if needed)**
```bash
git add -A
git commit -m "chore: finalize reader liquid glass rollout"
```
