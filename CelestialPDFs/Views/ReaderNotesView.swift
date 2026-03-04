//
//  ReaderNotesView.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import SwiftUI

struct ReaderNotesView: View {
    @Environment(BookStore.self) private var store
    let book: PDFBook
    var currentPage: Int
    var selectedText: String

    @State private var newNoteContent = ""
    @State private var newNoteScope: NoteScopeChoice = .page

    enum NoteScopeChoice: String, CaseIterable {
        case highlight = "划线笔记"
        case page = "页面笔记"
        case book = "全书笔记"
    }

    private var currentBook: PDFBook {
        store.books.first(where: { $0.id == book.id }) ?? book
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("笔记")
                    .font(.headline)
                Spacer()
                Text("\(currentBook.notes.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding()

            Divider()

            // Notes list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(sortedNotes) { note in
                        noteCard(note)
                    }
                }
                .padding()
            }

            Divider()

            // Add note section
            addNoteSection
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var sortedNotes: [BookNote] {
        currentBook.notes.sorted { $0.dateCreated > $1.dateCreated }
    }

    private func noteCard(_ note: BookNote) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                scopeLabel(note.scope)
                Spacer()
                Text(note.dateModified, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Button(action: { store.removeNote(from: book.id, noteId: note.id) }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Markdown rendered content
            MarkdownTextView(content: note.content)

            // Show highlight text if applicable
            if case .highlight(let hId) = note.scope,
               let h = currentBook.highlights.first(where: { $0.id == hId }) {
                Text("「\(h.text)」")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(6)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(4)
            }
        }
        .padding(10)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    @ViewBuilder
    private func scopeLabel(_ scope: NoteScope) -> some View {
        switch scope {
        case .highlight:
            Label("划线", systemImage: "highlighter")
                .font(.caption)
                .foregroundStyle(.yellow)
        case .page(let p):
            Label("第 \(p + 1) 页", systemImage: "doc.text")
                .font(.caption)
                .foregroundStyle(.blue)
        case .book:
            Label("全书", systemImage: "book.closed")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }

    // MARK: - Add Note

    private var addNoteSection: some View {
        VStack(spacing: 8) {
            Picker("类型", selection: $newNoteScope) {
                ForEach(NoteScopeChoice.allCases, id: \.self) { choice in
                    Text(choice.rawValue).tag(choice)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 4) {
                Text("支持 Markdown 语法")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                HStack(alignment: .top) {
                    TextEditor(text: $newNoteContent)
                        .font(.callout)
                        .frame(minHeight: 40, maxHeight: 100)
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )

                    Button(action: addNote) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(newNoteContent.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .padding(12)
        .background(.bar)
    }

    private func addNote() {
        let content = newNoteContent.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }

        let scope: NoteScope
        switch newNoteScope {
        case .highlight:
            // Find the most recent highlight on the current page
            if let lastHighlight = currentBook.highlights
                .filter({ $0.pageIndex == currentPage })
                .sorted(by: { $0.dateCreated > $1.dateCreated })
                .first {
                scope = .highlight(lastHighlight.id)
            } else {
                scope = .page(currentPage) // fallback
            }
        case .page:
            scope = .page(currentPage)
        case .book:
            scope = .book
        }

        let note = BookNote(scope: scope, content: content)
        store.addNote(to: book.id, note: note)
        newNoteContent = ""
    }
}

// MARK: - Markdown Text View

struct MarkdownTextView: View {
    let content: String

    var body: some View {
        if let attributed = try? AttributedString(markdown: content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
                .font(.callout)
                .textSelection(.enabled)
        } else {
            Text(content)
                .font(.callout)
                .textSelection(.enabled)
        }
    }
}
