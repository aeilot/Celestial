import XCTest
@testable import CelestialPDFs
import AppKit

final class CelestialPDFsTests: XCTestCase {

    // MARK: - BookStore Tests

    func testAddVocabulary() {
        let store = BookStore()
        let entry = VocabularyEntry(word: "test", bookTitle: "Book1")

        store.addVocabulary(entry)

        XCTAssertEqual(store.vocabulary.count, 1)
        XCTAssertEqual(store.vocabulary.first?.word, "test")
    }

    func testAddVocabularyTrimsWhitespace() {
        let store = BookStore()
        let entry = VocabularyEntry(word: "  test  ", bookTitle: "Book1")

        store.addVocabulary(entry)

        XCTAssertEqual(store.vocabulary.first?.word, "test")
    }

    func testRemoveVocabulary() {
        let store = BookStore()
        let entry = VocabularyEntry(word: "test", bookTitle: "Book1")
        store.addVocabulary(entry)

        store.removeVocabulary(entry)

        XCTAssertEqual(store.vocabulary.count, 0)
    }

    // MARK: - Tag Tests

    func testUpdateBookTags() {
        let store = BookStore()
        var book = PDFBook(title: "Test", fileName: "test.pdf")
        book.tags = ["swift", "ios"]
        store.books.append(book)

        var updated = book
        updated.tags = ["swift", "macos"]
        store.updateBook(updated)

        XCTAssertEqual(store.books.first?.tags.count, 2)
        XCTAssertTrue(store.books.first?.tags.contains("macos") ?? false)
    }

    func testAllTags() {
        let store = BookStore()
        store.books = [
            PDFBook(title: "Book1", fileName: "1.pdf", tags: ["swift", "ios"]),
            PDFBook(title: "Book2", fileName: "2.pdf", tags: ["swift", "macos"])
        ]

        let tags = store.allTags

        XCTAssertEqual(tags.count, 3)
        XCTAssertTrue(tags.contains("swift"))
    }

    // MARK: - Subfolder Tests

    func testAllFolders() {
        let store = BookStore()
        store.books = [
            PDFBook(title: "Book1", fileName: "folder1/book1.pdf"),
            PDFBook(title: "Book2", fileName: "folder1/subfolder/book2.pdf"),
            PDFBook(title: "Book3", fileName: "folder2/book3.pdf")
        ]

        let folders = store.allFolders

        XCTAssertTrue(folders.contains("folder1"))
        XCTAssertTrue(folders.contains("folder2"))
        XCTAssertTrue(folders.contains("folder1/subfolder"))
    }

    // MARK: - Reader Selection State Tests

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

    func testHighlightUsesPageBoundsNotOverlayBounds() {
        let state = ReaderSelectionState(
            selectedText: "sample",
            pageIndex: 1,
            overlayBounds: CGRect(x: 0, y: 0, width: 100, height: 20),
            pageBounds: CGRect(x: 40, y: 300, width: 100, height: 20)
        )

        let highlight = ReaderSelectionState.makeHighlight(from: state)
        XCTAssertEqual(highlight?.pageIndex, 1)
        XCTAssertEqual(highlight?.boundsX, 40)
        XCTAssertEqual(highlight?.boundsY, 300)
        XCTAssertEqual(highlight?.text, "sample")
    }

    func testHighlightPaletteDefaults() {
        XCTAssertEqual(HighlightPalette.defaultHex, "#FFEB3B")
        XCTAssertTrue(HighlightPalette.allHex.contains(HighlightPalette.defaultHex))
    }

    func testHexToColorFallbackUsesYellow() {
        let valid = NSColor.fromHighlightHex("#FFEB3B")
        let invalid = NSColor.fromHighlightHex("invalid")

        XCTAssertNotNil(valid.usingColorSpace(.deviceRGB))
        XCTAssertEqual(
            invalid.usingColorSpace(.deviceRGB),
            NSColor.yellow.usingColorSpace(.deviceRGB)
        )
    }

    func testFloatingToolbarPlacementFallsBackBelowWhenNoSpaceAbove() {
        let selection = CGRect(x: 120, y: 2, width: 80, height: 20)
        let viewport = CGRect(x: 0, y: 0, width: 400, height: 300)
        let point = FloatingToolbarPlacement.computeToolbarPoint(
            selection: selection,
            viewport: viewport,
            toolbar: CGSize(width: 220, height: 40),
            margin: 8,
            defaultPoint: .zero
        )

        XCTAssertGreaterThan(point.y, selection.maxY)
    }

    func testDetachNotesOnHighlightDeletePreservesContent() {
        let store = BookStore()
        let highlightID = UUID()
        let bookID = UUID()
        let note = BookNote(scope: .highlight(highlightID), content: "example note")
        let highlight = BookHighlight(
            id: highlightID,
            pageIndex: 0,
            text: "txt",
            boundsX: 0,
            boundsY: 0,
            boundsWidth: 1,
            boundsHeight: 1
        )
        store.books = [
            PDFBook(id: bookID, title: "A", fileName: "a.pdf", highlights: [highlight], notes: [note])
        ]

        store.detachNotesLinkedToHighlight(in: bookID, highlightId: highlightID)
        store.removeHighlight(from: bookID, highlightId: highlightID)

        XCTAssertEqual(store.books.first?.highlights.count, 0)
        XCTAssertEqual(store.books.first?.notes.count, 1)
        XCTAssertEqual(store.books.first?.notes.first?.scope, .book)
        XCTAssertTrue(store.books.first?.notes.first?.content.contains("原高亮已删除") ?? false)
    }
}
