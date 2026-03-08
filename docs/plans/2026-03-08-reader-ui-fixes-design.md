# Reader UI Fixes Design (2026-03-08)

## Scope
Implement and stabilize five user-reported issues:
1. Serif setting currently only affects note editing page.
2. Remove shelf row separators from the home bookshelf grid.
3. Floating toolbar after text selection never shows.
4. Notes side editor can become too narrow; needs adaptive, user-resizable split with stronger minimum widths.
5. Highlighting does not work.

## Goals
- Serif toggle applies consistently to app content text across major views.
- Shelf row separators are removed only in bookshelf grid mode.
- Floating toolbar appears reliably for non-empty PDF text selection.
- Notes editor panel supports user resizing while preserving readable minimum widths.
- Highlight creation uses true PDF selection geometry so highlights render correctly and persist across zoom/scroll.

## Non-Goals
- Redesigning the entire app typography system beyond current serif toggle behavior.
- Major reader architecture rewrites (e.g., introducing a full view model layer).
- Changing list-view divider behavior on the bookshelf page.

## Chosen Approach
Adopt a targeted, medium-scope fix set:
- Standardize serif usage via existing `appFont` modifier (plus targeted dynamic font updates where needed).
- Remove only bookshelf grid shelf separators.
- Keep existing floating toolbar UI but repair selection state propagation and visibility conditions.
- Store highlight bounds from PDF page-space selection geometry (not SwiftUI overlay coordinates).
- Strengthen notes editor split layout with user-resizable panes and larger minimum widths.

This balances fast delivery with low regression risk and avoids unnecessary architectural churn.

## Design Details

### 1. Serif Setting Propagation
Files: major SwiftUI views under `CelestialPDFs/Views/` and sidebar in `ContentView.swift`.

Implementation design:
- Keep source of truth as `@AppStorage("useSerifFont")`.
- Replace hardcoded serif/default font calls on content text with `.appFont(...)` or equivalent dynamic `design` usage tied to the setting.
- Apply to readable content across:
  - Bookshelf cards/list rows
  - Sidebar labels/info text
  - Notes list/editor preview text
  - Vocabulary list/detail text
  - AI chat text
  - Stats textual content
- Leave utility/icon-heavy controls unchanged where forcing serif would reduce clarity.

Expected result:
- Toggling serif in settings reflects throughout the app’s reading/content surfaces, not only note editor.

### 2. Home Page Divider Removal (Grid Only)
File: `Views/BookshelfView.swift`

Implementation design:
- Remove the row-level shelf separator rendering in grid mode (`shelfDivider` usage between rows).
- Keep list mode row separators unchanged.

Expected result:
- Grid view appears cleaner, with no shelf-style horizontal dividers.

### 3. Floating Toolbar Reliability
Files: `Views/PDFReaderView.swift`, `Views/PDFKitView.swift`

Implementation design:
- Preserve current toolbar component and actions.
- Ensure toolbar visibility is driven by valid non-empty selection state + user setting (`showFloatingToolbar`).
- In `PDFKitView.Coordinator`, normalize selection updates:
  - On non-empty selection: set selected text, selected page index, and overlay-space anchor bounds for positioning.
  - On cleared selection: reset text/bounds/page index.
- Keep toolbar anchored near selection and hidden when selection clears.

Expected result:
- Selecting text in PDF reliably shows floating toolbar near selection.

### 4. Adaptive Notes Sidebar Editor Width
File: `Views/ReaderNotesView.swift`

Implementation design:
- Keep split-based editor layout.
- Enforce stronger pane minimums (target: editor >= 420, preview >= 320; exact values may be tuned after runtime check).
- Ensure split is user-resizable and does not collapse below readable widths.

Expected result:
- Editor and preview remain usable even in narrower window sizes.

### 5. Highlighting Fix via PDF Selection Geometry
Files: `Views/PDFReaderView.swift`, `Views/PDFKitView.swift`, potentially `Models/PDFBook.swift` compatibility-preserving updates.

Implementation design:
- Capture highlight source bounds from PDF selection in page coordinate space (`PDFSelection` + page bounds), not from converted overlay rect used for toolbar placement.
- Persist those page-space bounds into `BookHighlight`.
- Continue rendering annotations by applying stored bounds directly to the corresponding `PDFPage`.
- Keep overlay-space rect only for toolbar positioning.

Expected result:
- New highlights render at the correct position, survive reopen, and remain aligned across zoom/scroll.

## Data Flow
1. User selects text in `PDFView`.
2. Coordinator emits:
   - `selectedText`
   - `selectionPageIndex`
   - overlay-space rect for toolbar anchor
   - page-space rect for highlight persistence
3. `PDFReaderView` shows toolbar when selection is valid.
4. On “高亮”, `BookHighlight` is created from page-space rect and stored in `BookStore`.
5. `PDFKitView.applyHighlights` re-applies persisted highlights as PDF annotations.

## Error Handling and Edge Cases
- Ignore highlight creation for empty/whitespace-only selection.
- Guard for missing document/page or invalid page index.
- Clear toolbar state on selection loss to avoid stale anchors.
- Preserve backward compatibility for existing persisted highlights (same stored rect fields).

## Verification Strategy

### Manual Checks
- Serif toggle updates typography in bookshelf, sidebar, notes list/editor, vocabulary, AI chat, and stats.
- Bookshelf grid has no row shelf separators; list separators remain.
- Selecting any non-empty text shows floating toolbar near selection.
- Notes editor split remains user-resizable and enforces readable pane minimum widths.
- Highlight action creates visible highlight immediately; highlight persists after app restart/reopen.

### Build Check
- Run:
  - `xcodebuild -project CelestialPDFs.xcodeproj -scheme CelestialPDFs -configuration Debug build`

## Risks
- Over-applying serif to control labels may reduce readability; mitigated by limiting to content text.
- PDF coordinate conversion mistakes can still break highlights; mitigated by separating overlay anchor rect and persisted page-space rect.
- Split minimum widths may require tuning depending on macOS layout behavior.

## Rollout
- Single patch touching reader, typography usage points, and bookshelf grid separators.
- No data migration expected.
