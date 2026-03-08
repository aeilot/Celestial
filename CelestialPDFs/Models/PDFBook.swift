//
//  PDFBook.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import Foundation
import SwiftUI
import AppKit

// MARK: - PDFBook

struct PDFBook: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var author: String
    var tags: [String]
    var fileName: String // relative to library directory
    var dateAdded: Date
    var lastOpened: Date?
    var highlights: [BookHighlight]
    var notes: [BookNote]

    init(
        id: UUID = UUID(),
        title: String,
        author: String = "",
        tags: [String] = [],
        fileName: String,
        dateAdded: Date = Date(),
        lastOpened: Date? = nil,
        highlights: [BookHighlight] = [],
        notes: [BookNote] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.tags = tags
        self.fileName = fileName
        self.dateAdded = dateAdded
        self.lastOpened = lastOpened
        self.highlights = highlights
        self.notes = notes
    }
}

// MARK: - BookHighlight

struct BookHighlight: Identifiable, Codable, Hashable {
    let id: UUID
    var pageIndex: Int
    var text: String
    var boundsX: CGFloat
    var boundsY: CGFloat
    var boundsWidth: CGFloat
    var boundsHeight: CGFloat
    var colorHex: String
    var dateCreated: Date

    init(
        id: UUID = UUID(),
        pageIndex: Int,
        text: String,
        boundsX: CGFloat,
        boundsY: CGFloat,
        boundsWidth: CGFloat,
        boundsHeight: CGFloat,
        colorHex: String = "#FFEB3B",
        dateCreated: Date = Date()
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.text = text
        self.boundsX = boundsX
        self.boundsY = boundsY
        self.boundsWidth = boundsWidth
        self.boundsHeight = boundsHeight
        self.colorHex = colorHex
        self.dateCreated = dateCreated
    }

    var bounds: CGRect {
        CGRect(x: boundsX, y: boundsY, width: boundsWidth, height: boundsHeight)
    }
}

enum HighlightPalette {
    static let defaultHex = "#FFEB3B"
    static let allHex: [String] = [
        "#FFEB3B", // yellow
        "#FFD54F", // amber
        "#AED581", // light green
        "#4FC3F7", // light blue
        "#B39DDB", // light purple
        "#F48FB1", // pink
        "#FFAB91", // orange
        "#B0BEC5"  // blue gray
    ]
}

extension NSColor {
    static func fromHighlightHex(_ hex: String) -> NSColor {
        guard let color = Color.fromHighlightHex(hex) else {
            return .yellow
        }
        return NSColor(color)
    }
}

extension Color {
    static func fromHighlightHex(_ hex: String) -> Color? {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count == 7, cleaned.hasPrefix("#") else { return nil }

        let rString = String(cleaned.dropFirst().prefix(2))
        let gString = String(cleaned.dropFirst(3).prefix(2))
        let bString = String(cleaned.dropFirst(5).prefix(2))

        guard let r = UInt8(rString, radix: 16),
              let g = UInt8(gString, radix: 16),
              let b = UInt8(bString, radix: 16) else {
            return nil
        }

        return Color(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0
        )
    }
}

// MARK: - Reader Selection State

struct ReaderSelectionState {
    var selectedText: String = ""
    var pageIndex: Int?
    var overlayBounds: CGRect?
    var pageBounds: CGRect?

    var normalizedText: String {
        selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValidForToolbar: Bool {
        !normalizedText.isEmpty &&
        (overlayBounds?.width ?? 0) > 0 &&
        (overlayBounds?.height ?? 0) > 0
    }

    var isValidForHighlight: Bool {
        !normalizedText.isEmpty &&
        pageIndex != nil &&
        (pageBounds?.width ?? 0) > 0 &&
        (pageBounds?.height ?? 0) > 0
    }

    static func makeHighlight(from state: ReaderSelectionState) -> BookHighlight? {
        guard state.isValidForHighlight,
              let pageIndex = state.pageIndex,
              let pageBounds = state.pageBounds else {
            return nil
        }

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

// MARK: - BookNote

enum NoteScope: Codable, Hashable {
    case highlight(UUID) // attached to a specific highlight
    case page(Int)       // attached to a specific page
    case book            // attached to the entire book
}

struct BookNote: Identifiable, Codable, Hashable {
    let id: UUID
    var scope: NoteScope
    var content: String
    var dateCreated: Date
    var dateModified: Date

    init(
        id: UUID = UUID(),
        scope: NoteScope,
        content: String,
        dateCreated: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.id = id
        self.scope = scope
        self.content = content
        self.dateCreated = dateCreated
        self.dateModified = dateModified
    }

    var scopeDescription: String {
        switch scope {
        case .highlight:
            return "划线笔记"
        case .page(let p):
            return "第 \(p + 1) 页"
        case .book:
            return "全书笔记"
        }
    }
}

// MARK: - VocabularyEntry

struct VocabularyEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var word: String
    var definition: String
    var bookId: UUID?
    var bookTitle: String?
    var pageIndex: Int?
    var dateAdded: Date

    init(
        id: UUID = UUID(),
        word: String,
        definition: String = "",
        bookId: UUID? = nil,
        bookTitle: String? = nil,
        pageIndex: Int? = nil,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.word = word
        self.definition = definition
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.pageIndex = pageIndex
        self.dateAdded = dateAdded
    }
}

// MARK: - Sidebar Selection

enum SidebarItem: Hashable {
    case bookshelf
    case notes
    case vocabulary
    case tag(String)
    case folder(String)
}
