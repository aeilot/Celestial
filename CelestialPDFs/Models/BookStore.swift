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

    // MARK: - Thumbnail Cache

    /// In-memory thumbnail cache (evicts automatically under memory pressure)
    private let thumbnailMemoryCache = NSCache<NSUUID, NSImage>()

    // MARK: - Paths

    private var appSupportDir: URL {
        let dir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CelestialPDFs", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var thumbnailCacheDir: URL {
        let dir = appSupportDir.appendingPathComponent("thumbnails", isDirectory: true)
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
        thumbnailMemoryCache.countLimit = 200
        loadLibraryBookmark()
        loadBooks()
        loadVocabulary()

        // Background scan on launch (silent, no overlay)
        if libraryPath != nil {
            Task {
                await scanInBackground()
            }
        }
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

        await performScan(dir: dir, showProgress: true)

        scanStatusMessage = "扫描完成，共 \(books.count) 本书"
        scanProgress = 1.0

        // Dismiss scanning state after a brief delay
        try? await Task.sleep(for: .seconds(0.8))
        isScanning = false
    }

    /// Silent background scan on launch — no overlay, no progress UI.
    func scanInBackground() async {
        guard let dir = libraryPath else { return }
        await performScan(dir: dir, showProgress: false)
    }

    /// Core scan logic shared by foreground and background modes.
    private func performScan(dir: URL, showProgress: Bool) async {
        // Collect PDF files on a background thread (recursive subdirectories)
        let pdfFiles: [URL] = await Task.detached {
            var files: [URL] = []
            let enumerator = FileManager.default.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            while let url = enumerator?.nextObject() as? URL {
                if url.pathExtension.lowercased() == "pdf" {
                    files.append(url)
                }
            }
            return files
        }.value

        // Build lookup of existing books by fileName for O(1) check
        let existingFileNames = Set(books.map { $0.fileName })
        let total = pdfFiles.count

        if showProgress {
            scanStatusMessage = "找到 \(total) 个 PDF 文件"
        }

        // Process files — add new ones
        for (index, fileURL) in pdfFiles.enumerated() {
            let relativePath = fileURL.path.replacingOccurrences(of: dir.path + "/", with: "")

            if !existingFileNames.contains(relativePath) {
                let title = fileURL.deletingPathExtension().lastPathComponent
                let book = PDFBook(title: title, fileName: relativePath)
                books.append(book)
            }

            if showProgress {
                scanProgress = Double(index + 1) / Double(max(total, 1))
                scanStatusMessage = "正在处理 \(index + 1) / \(total)…"
            }

            // Yield to keep UI responsive
            if index % 20 == 0 {
                await Task.yield()
            }
        }

        // Remove books whose files no longer exist
        let currentFileNames = Set(pdfFiles.map {
            $0.path.replacingOccurrences(of: dir.path + "/", with: "")
        })
        books.removeAll { !currentFileNames.contains($0.fileName) }

        saveBooks()

        // Pre-warm thumbnail cache in background
        let booksSnapshot = books
        let cacheDir = thumbnailCacheDir
        let libPath = libraryPath
        let memCache = thumbnailMemoryCache
        Task.detached(priority: .utility) {
            for book in booksSnapshot {
                let nsid = book.id as NSUUID
                if memCache.object(forKey: nsid) == nil {
                    // Try disk cache first
                    let diskPath = cacheDir.appendingPathComponent("\(book.id.uuidString).jpg")
                    if FileManager.default.fileExists(atPath: diskPath.path),
                       let diskImage = NSImage(contentsOf: diskPath) {
                        memCache.setObject(diskImage, forKey: nsid)
                    } else if let dir = libPath {
                        // Render from PDF
                        let fileURL = dir.appendingPathComponent(book.fileName)
                        if let document = PDFDocument(url: fileURL),
                           let page = document.page(at: 0) {
                            let size = CGSize(width: 180, height: 260)
                            let pageBounds = page.bounds(for: .mediaBox)
                            let pageAspect = pageBounds.width / pageBounds.height
                            let targetAspect = size.width / size.height
                            let rawSize: CGSize
                            if pageAspect > targetAspect {
                                rawSize = CGSize(width: size.height * pageAspect, height: size.height)
                            } else {
                                rawSize = CGSize(width: size.width, height: size.width / pageAspect)
                            }
                            let rawThumbnail = page.thumbnail(of: rawSize, for: .mediaBox)
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
                            memCache.setObject(croppedImage, forKey: nsid)
                            // Save to disk
                            if let tiffData = croppedImage.tiffRepresentation,
                               let bitmapRep = NSBitmapImageRep(data: tiffData),
                               let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                                try? jpegData.write(to: diskPath)
                            }
                        }
                    }
                }
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
    }

    // Sync wrapper for backward compat
    func scanDirectory() {
        Task {
            await scanDirectoryAsync()
        }
    }

    // MARK: - Thumbnail (with Disk + Memory Cache)

    /// Fast cache-only lookup (memory → disk). No PDF rendering.
    /// Safe to call on main thread — always fast.
    func cachedThumbnail(for book: PDFBook) -> NSImage? {
        let nsid = book.id as NSUUID

        // 1. Memory cache hit
        if let cached = thumbnailMemoryCache.object(forKey: nsid) {
            return cached
        }

        // 2. Disk cache hit
        if let diskImage = loadThumbnailFromDisk(bookId: book.id) {
            thumbnailMemoryCache.setObject(diskImage, forKey: nsid)
            return diskImage
        }

        return nil
    }

    /// Render thumbnail from PDF and store in both caches.
    /// Intended to be called from a background thread.
    @Sendable
    nonisolated func renderAndCacheThumbnail(for book: PDFBook, size: CGSize = CGSize(width: 180, height: 260)) -> NSImage? {
        let cacheDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CelestialPDFs/thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let diskPath = cacheDir.appendingPathComponent("\(book.id.uuidString).jpg")

        // Check disk again (may have been cached by pre-warming)
        if FileManager.default.fileExists(atPath: diskPath.path),
           let diskImage = NSImage(contentsOf: diskPath) {
            return diskImage
        }

        // Read libraryPath from UserDefaults bookmark to avoid actor isolation
        guard let bookmarkData = UserDefaults.standard.data(forKey: "libraryBookmark"),
              let dir = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &(UnsafeMutablePointer<Bool>.allocate(capacity: 1).pointee)) else {
            return nil
        }

        let fileURL = dir.appendingPathComponent(book.fileName)
        guard let document = PDFDocument(url: fileURL),
              let page = document.page(at: 0) else { return nil }

        let pageBounds = page.bounds(for: .mediaBox)
        let pageAspect = pageBounds.width / pageBounds.height
        let targetAspect = size.width / size.height

        let rawSize: CGSize
        if pageAspect > targetAspect {
            rawSize = CGSize(width: size.height * pageAspect, height: size.height)
        } else {
            rawSize = CGSize(width: size.width, height: size.width / pageAspect)
        }

        let rawThumbnail = page.thumbnail(of: rawSize, for: .mediaBox)
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

        // Save to disk cache
        if let tiffData = croppedImage.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            try? jpegData.write(to: diskPath)
        }

        return croppedImage
    }

    /// Full lookup: memory → disk → render (legacy, still used internally).
    func thumbnail(for book: PDFBook, size: CGSize = CGSize(width: 180, height: 260)) -> NSImage? {
        if let cached = cachedThumbnail(for: book) {
            return cached
        }
        if let rendered = renderThumbnail(for: book, size: size) {
            let nsid = book.id as NSUUID
            thumbnailMemoryCache.setObject(rendered, forKey: nsid)
            saveThumbnailToDisk(rendered, bookId: book.id)
            return rendered
        }
        return nil
    }

    /// Load or render (used by background pre-warming).
    private func loadOrRenderThumbnail(for book: PDFBook, size: CGSize = CGSize(width: 180, height: 260)) -> NSImage? {
        if let diskImage = loadThumbnailFromDisk(bookId: book.id) {
            return diskImage
        }
        if let rendered = renderThumbnail(for: book, size: size) {
            saveThumbnailToDisk(rendered, bookId: book.id)
            return rendered
        }
        return nil
    }

    private func thumbnailCachePath(bookId: UUID) -> URL {
        thumbnailCacheDir.appendingPathComponent("\(bookId.uuidString).jpg")
    }

    private func loadThumbnailFromDisk(bookId: UUID) -> NSImage? {
        let path = thumbnailCachePath(bookId: bookId)
        guard fileManager.fileExists(atPath: path.path) else { return nil }
        return NSImage(contentsOf: path)
    }

    private func saveThumbnailToDisk(_ image: NSImage, bookId: UUID) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return
        }
        let path = thumbnailCachePath(bookId: bookId)
        try? jpegData.write(to: path)
    }

    private func renderThumbnail(for book: PDFBook, size: CGSize) -> NSImage? {
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
            rawSize = CGSize(width: size.height * pageAspect, height: size.height)
        } else {
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
        // Clean up thumbnail cache
        let cachePath = thumbnailCachePath(bookId: book.id)
        try? fileManager.removeItem(at: cachePath)
        thumbnailMemoryCache.removeObject(forKey: book.id as NSUUID)
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

    // MARK: - All Tags

    var allTags: [String] {
        let tags = books.flatMap { $0.tags }
        return Array(Set(tags)).sorted()
    }

    // MARK: - All Folders (subfolder structure)

    /// Returns sorted list of unique subfolder paths extracted from book file names.
    var allFolders: [String] {
        var folders = Set<String>()
        for book in books {
            let components = book.fileName.split(separator: "/").dropLast() // remove file name
            if !components.isEmpty {
                // Add the immediate parent folder and all ancestor folders
                var path = ""
                for component in components {
                    path = path.isEmpty ? String(component) : path + "/" + String(component)
                    folders.insert(path)
                }
            }
        }
        return folders.sorted()
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
            books = []
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
            vocabulary = []
        }
    }
}
