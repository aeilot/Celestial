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

    @State private var editingNote: BookNote?
    @State private var showEditor = false

    private var currentBook: PDFBook {
        store.books.first(where: { $0.id == book.id }) ?? book
    }

    var body: some View {
        VStack(spacing: 0) {
            if showEditor {
                NoteEditorView(
                    book: book,
                    currentPage: currentPage,
                    note: editingNote,
                    onSave: { note in
                        if let existing = editingNote {
                            store.updateNote(in: book.id, note: note)
                        } else {
                            store.addNote(to: book.id, note: note)
                        }
                        showEditor = false
                        editingNote = nil
                    },
                    onCancel: {
                        showEditor = false
                        editingNote = nil
                    }
                )
            } else {
                notesList
            }
        }
    }

    private var notesList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("笔记")
                    .font(.headline)
                Spacer()
                Button(action: { showEditor = true }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            List {
                ForEach(currentBook.notes.sorted { $0.dateCreated > $1.dateCreated }) { note in
                    Button(action: {
                        editingNote = note
                        showEditor = true
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.content)
                                .font(.system(.body, design: .serif))
                                .lineLimit(3)
                            Text(note.dateModified, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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

struct NoteEditorView: View {
    let book: PDFBook
    let currentPage: Int
    let note: BookNote?
    let onSave: (BookNote) -> Void
    let onCancel: () -> Void

    @State private var content: String = ""
    @State private var scope: NoteScope = .page(0)

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Button("取消", action: onCancel)
                    Spacer()
                    Button("保存") {
                        let newNote = BookNote(
                            id: note?.id ?? UUID(),
                            scope: scope,
                            content: content,
                            dateCreated: note?.dateCreated ?? Date(),
                            dateModified: Date()
                        )
                        onSave(newNote)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()

                Divider()

                TextEditor(text: $content)
                    .font(.system(.body, design: .serif))
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("预览")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)

                Divider()

                ScrollView {
                    MarkdownTextView(content: content)
                        .font(.system(.body, design: .serif))
                        .padding()
                }
            }
            .frame(minWidth: 200)
        }
        .onAppear {
            content = note?.content ?? ""
            scope = note?.scope ?? .page(currentPage)
        }
    }
}
