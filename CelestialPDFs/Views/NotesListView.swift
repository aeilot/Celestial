//
//  NotesListView.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import SwiftUI

struct NotesListView: View {
    @Environment(BookStore.self) private var store

    var body: some View {
        Group {
            if store.allNotes.isEmpty {
                emptyView
            } else {
                notesList
            }
        }
        .navigationTitle("笔记")
    }

    private var notesList: some View {
        List {
            // Group notes by book
            ForEach(booksWithNotes, id: \.id) { book in
                Section {
                    ForEach(book.notes.sorted(by: { $0.dateModified > $1.dateModified })) { note in
                        NoteRow(book: book, note: note)
                    }
                } header: {
                    HStack(spacing: 8) {
                        Image(systemName: "book.closed")
                            .foregroundStyle(.secondary)
                        Text(book.title)
                            .font(.headline)
                    }
                }
            }
        }
    }

    private var booksWithNotes: [PDFBook] {
        store.books.filter { !$0.notes.isEmpty }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("暂无笔记")
                .font(.title3)
                .fontWeight(.medium)
            Text("在阅读 PDF 时可以添加笔记")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NoteRow: View {
    let book: PDFBook
    let note: BookNote

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Scope badge
            HStack(spacing: 6) {
                scopeIcon
                Text(note.scopeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(note.dateModified, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Markdown rendered content
            MarkdownTextView(content: note.content)

            // If it's a highlight note, show the highlighted text
            if case .highlight(let hId) = note.scope,
               let highlight = book.highlights.first(where: { $0.id == hId }) {
                Text("「\(highlight.text)」")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var scopeIcon: some View {
        switch note.scope {
        case .highlight:
            Image(systemName: "highlighter")
                .foregroundStyle(.yellow)
                .font(.caption)
        case .page:
            Image(systemName: "doc.text")
                .foregroundStyle(.blue)
                .font(.caption)
        case .book:
            Image(systemName: "book.closed")
                .foregroundStyle(.green)
                .font(.caption)
        }
    }
}
