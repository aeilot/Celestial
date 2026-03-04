//
//  BookStore.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import Foundation
import Observation
import PDFKit
import AppKit

@Observable
class BookStore {
    var books: [PDFBook] = []
    var vocabulary: [VocabularyEntry] = []
    var libraryPath: URL?
    var selectedBook: PDFBook?

    // Scanning state
    var isScanning = false
    var scanProgress: Double = 0  // 0.0 - 1.0
    var scanStatusMessage = ""

    // User profile
    var userAvatarData: Data? {
        get { UserDefaults.standard.data(forKey: "userAvatar") }
        set { UserDefaults.standard.set(newValue, forKey: "userAvatar") }
    }
    var userName: String {
        get { UserDefaults.standard.string(forKey: "userName") ?? "Reader" }
        set { UserDefaults.standard.set(newValue, forKey: "userName") }
    }

    private let fileManager = FileManager.default

    // MARK: - Paths

    private var appSupportDir: URL {
        let dir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CelestialPDFs", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var libraryJSONPath: URL {
        appSupportDir.appendingPathComponent("library.json")
    }

    private var vocabularyJSONPath: URL {
        appSupportDir.appendingPathComponent("vocabulary.json")
    }

    private var bookmarkKey: String { "libraryBookmark" }

    // MARK: - Init

    init() {
        loadLibraryBookmark()
        loadBooks()
        loadVocabulary()
    }

    // MARK: - Security-Scoped Bookmark

    func selectLibraryDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择 PDF 文件所在的目录"
        panel.prompt = "选择"

        if panel.runModal() == .OK, let url = panel.url {
            saveBookmark(for: url)
            libraryPath = url
            Task {
                await scanDirectoryAsync()
            }
        }
    }

    private func saveBookmark(for url: URL) {
        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        } catch {
            print("Failed to save bookmark: \(error)")
        }
    }

    private func loadLibraryBookmark() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                saveBookmark(for: url)
            }
            if url.startAccessingSecurityScopedResource() {
                libraryPath = url
            }
        } catch {
            print("Failed to resolve bookmark: \(error)")
        }
    }

    // MARK: - Scan Directory (Async with Progress)

    func scanDirectoryAsync() async {
        guard let dir = libraryPath else { return }

        isScanning = true
        scanProgress = 0
        scanStatusMessage = "正在扫描目录…"

        // Collect PDF files on a background thread (supports subdirectories)
        let pdfFiles: [URL] = await Task.detached {
            var files: [URL] = []
            let enumerator = FileManager.default.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            while let url = enumerator?.nextObject() as? URL {
                if url.pathExtension.lowercased() == "pdf" {
                    files.append(url)
                }
            }
            return files
        }.value

        let existingFileNames = Set(books.map { $0.fileName })
        let total = pdfFiles.count

        scanStatusMessage = "找到 \(total) 个 PDF 文件"

        // Process files with progress
        for (index, fileURL) in pdfFiles.enumerated() {
            // Use relative path from library root for subdirectories
            let relativePath = fileURL.path.replacingOccurrences(of: dir.path + "/", with: "")

            if !existingFileNames.contains(relativePath) {
                let title = fileURL.deletingPathExtension().lastPathComponent
                let book = PDFBook(title: title, fileName: relativePath)
                books.append(book)
            }

            scanProgress = Double(index + 1) / Double(max(total, 1))
            scanStatusMessage = "正在处理 \(index + 1) / \(total)…"

            // Yield to keep UI responsive
            if index % 10 == 0 {
                await Task.yield()
            }
        }

        // Remove books whose files no longer exist
        let currentFileNames = Set(pdfFiles.map {
            $0.path.replacingOccurrences(of: dir.path + "/", with: "")
        })
        books.removeAll { !currentFileNames.contains($0.fileName) }

        saveBooks()

        scanStatusMessage = "扫描完成，共 \(books.count) 本书"
        scanProgress = 1.0

        // Dismiss scanning state after a brief delay
        try? await Task.sleep(for: .seconds(0.8))
        isScanning = false
    }

    // Sync wrapper for backward compat
    func scanDirectory() {
        Task {
            await scanDirectoryAsync()
        }
    }

    // MARK: - Book CRUD

    func addBook(from url: URL) {
        guard let dir = libraryPath else { return }
        let destURL = dir.appendingPathComponent(url.lastPathComponent)

        if !fileManager.fileExists(atPath: destURL.path) {
            do {
                try fileManager.copyItem(at: url, to: destURL)
            } catch {
                print("Failed to copy PDF: \(error)")
                return
            }
        }

        let title = url.deletingPathExtension().lastPathComponent
        let book = PDFBook(title: title, fileName: url.lastPathComponent)
        books.append(book)
        saveBooks()
    }

    func removeBook(_ book: PDFBook) {
        books.removeAll { $0.id == book.id }
        saveBooks()
    }

    func updateBook(_ book: PDFBook) {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index] = book
            saveBooks()
        }
    }

    func markOpened(_ book: PDFBook) {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index].lastOpened = Date()
            saveBooks()
        }
    }

    // MARK: - Highlights

    func addHighlight(to bookId: UUID, highlight: BookHighlight) {
        if let index = books.firstIndex(where: { $0.id == bookId }) {
            books[index].highlights.append(highlight)
            saveBooks()
        }
    }

    func removeHighlight(from bookId: UUID, highlightId: UUID) {
        if let index = books.firstIndex(where: { $0.id == bookId }) {
            books[index].highlights.removeAll { $0.id == highlightId }
            saveBooks()
        }
    }

    // MARK: - Notes

    func addNote(to bookId: UUID, note: BookNote) {
        if let index = books.firstIndex(where: { $0.id == bookId }) {
            books[index].notes.append(note)
            saveBooks()
        }
    }

    func updateNote(in bookId: UUID, note: BookNote) {
        if let bIndex = books.firstIndex(where: { $0.id == bookId }),
           let nIndex = books[bIndex].notes.firstIndex(where: { $0.id == note.id }) {
            books[bIndex].notes[nIndex] = note
            saveBooks()
        }
    }

    func removeNote(from bookId: UUID, noteId: UUID) {
        if let index = books.firstIndex(where: { $0.id == bookId }) {
            books[index].notes.removeAll { $0.id == noteId }
            saveBooks()
        }
    }

    // MARK: - Vocabulary

    func addVocabulary(_ entry: VocabularyEntry) {
        // Guard against empty words
        let trimmedWord = entry.word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return }

        var safeEntry = entry
        safeEntry.word = trimmedWord
        vocabulary.append(safeEntry)
        saveVocabulary()
    }

    func removeVocabulary(_ entry: VocabularyEntry) {
        vocabulary.removeAll { $0.id == entry.id }
        saveVocabulary()
    }

    // MARK: - Thumbnail (with auto-cropping)

    func thumbnail(for book: PDFBook, size: CGSize = CGSize(width: 180, height: 260)) -> NSImage? {
        guard let dir = libraryPath else { return nil }
        let fileURL = dir.appendingPathComponent(book.fileName)
        guard let document = PDFDocument(url: fileURL) else { return nil }
        guard let page = document.page(at: 0) else { return nil }

        let pageBounds = page.bounds(for: .mediaBox)
        let pageAspect = pageBounds.width / pageBounds.height
        let targetAspect = size.width / size.height

        // Generate a larger thumbnail for cropping
        let rawSize: CGSize
        if pageAspect > targetAspect {
            // Page is wider — fit height, crop sides
            rawSize = CGSize(width: size.height * pageAspect, height: size.height)
        } else {
            // Page is taller — fit width, crop top/bottom
            rawSize = CGSize(width: size.width, height: size.width / pageAspect)
        }

        let rawThumbnail = page.thumbnail(of: rawSize, for: .mediaBox)

        // Crop to target size
        let cropRect = CGRect(
            x: (rawSize.width - size.width) / 2,
            y: (rawSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )

        let croppedImage = NSImage(size: size)
        croppedImage.lockFocus()
        rawThumbnail.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: cropRect.origin, size: cropRect.size),
            operation: .copy,
            fraction: 1.0
        )
        croppedImage.unlockFocus()
        return croppedImage
    }

    func pdfDocument(for book: PDFBook) -> PDFDocument? {
        guard let dir = libraryPath else { return nil }
        let fileURL = dir.appendingPathComponent(book.fileName)
        return PDFDocument(url: fileURL)
    }

    // MARK: - All Tags

    var allTags: [String] {
        let tags = books.flatMap { $0.tags }
        return Array(Set(tags)).sorted()
    }

    // MARK: - All Notes (across books)

    var allNotes: [(book: PDFBook, note: BookNote)] {
        books.flatMap { book in
            book.notes.map { (book: book, note: $0) }
        }.sorted { $0.note.dateModified > $1.note.dateModified }
    }

    // MARK: - Stats

    var totalHighlights: Int {
        books.reduce(0) { $0 + $1.highlights.count }
    }

    var totalNotes: Int {
        books.reduce(0) { $0 + $1.notes.count }
    }

    var totalPages: Int {
        // Approximate - would need to load each PDF
        books.count * 100 // Placeholder
    }

    var recentBooks: [PDFBook] {
        books.filter { $0.lastOpened != nil }
            .sorted { ($0.lastOpened ?? .distantPast) > ($1.lastOpened ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Persistence

    private func saveBooks() {
        do {
            let data = try JSONEncoder().encode(books)
            try data.write(to: libraryJSONPath)
        } catch {
            print("Failed to save books: \(error)")
        }
    }

    private func loadBooks() {
        guard fileManager.fileExists(atPath: libraryJSONPath.path) else { return }
        do {
            let data = try Data(contentsOf: libraryJSONPath)
            books = try JSONDecoder().decode([PDFBook].self, from: data)
        } catch {
            print("Failed to load books: \(error)")
            books = [] // Reset if corrupted
        }
    }

    private func saveVocabulary() {
        do {
            let data = try JSONEncoder().encode(vocabulary)
            try data.write(to: vocabularyJSONPath)
        } catch {
            print("Failed to save vocabulary: \(error)")
        }
    }

    private func loadVocabulary() {
        guard fileManager.fileExists(atPath: vocabularyJSONPath.path) else { return }
        do {
            let data = try Data(contentsOf: vocabularyJSONPath)
            vocabulary = try JSONDecoder().decode([VocabularyEntry].self, from: data)
        } catch {
            print("Failed to load vocabulary: \(error)")
            vocabulary = [] // Reset if corrupted instead of crashing
        }
    }
}
