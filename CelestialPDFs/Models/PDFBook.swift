//
//  PDFBook.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import Foundation
import SwiftUI

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
