import XCTest
@testable import CelestialPDFs

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
}
