//
//  ReaderNotesView.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import SwiftUI

struct ReaderNotesView: View {
    @Environment(BookStore.self) private var store
    @AppStorage("useSerifFont") private var useSerifFont = false
    let book: PDFBook
    var currentPage: Int
    var selectedText: String
    var onHighlightColorChange: ((UUID, String) -> Void)? = nil
    var onHighlightDelete: ((UUID) -> Void)? = nil

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
                        withAnimation(.spring(response: 0.3)) {
                            showEditor = false
                            editingNote = nil
                        }
                    },
                    onCancel: {
                        withAnimation(.spring(response: 0.3)) {
                            showEditor = false
                            editingNote = nil
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                notesList
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: showEditor)
    }

    private var notesList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("笔记")
                    .font(.system(.headline, design: useSerifFont ? .serif : .default))
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
                    VStack(alignment: .leading, spacing: 6) {
                        Button(action: {
                            editingNote = note
                            showEditor = true
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.content)
                                    .font(.system(.body, design: useSerifFont ? .serif : .default))
                                    .lineLimit(3)
                                Text(note.dateModified, style: .relative)
                                    .font(.system(.caption2, design: useSerifFont ? .serif : .default))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        if case .highlight(let highlightID) = note.scope {
                            highlightActions(highlightID: highlightID)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func highlightActions(highlightID: UUID) -> some View {
        HStack(spacing: 8) {
            ForEach(HighlightPalette.allHex, id: \.self) { hex in
                Button(action: {
                    onHighlightColorChange?(highlightID, hex)
                }) {
                    Circle()
                        .fill(Color.fromHighlightHex(hex) ?? .yellow)
                        .frame(width: 12, height: 12)
                        .overlay {
                            if currentBook.highlights.first(where: { $0.id == highlightID })?.colorHex == hex {
                                Circle()
                                    .strokeBorder(.primary.opacity(0.7), lineWidth: 1.2)
                                    .frame(width: 15, height: 15)
                            }
                        }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(role: .destructive, action: {
                onHighlightDelete?(highlightID)
            }) {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Markdown Text View

struct MarkdownTextView: View {
    let content: String
    @AppStorage("useSerifFont") private var useSerifFont = false

    var body: some View {
        if let attributed = try? AttributedString(markdown: content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
                .font(.system(.callout, design: useSerifFont ? .serif : .default))
                .textSelection(.enabled)
        } else {
            Text(content)
                .font(.system(.callout, design: useSerifFont ? .serif : .default))
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
    @AppStorage("useSerifFont") private var useSerifFont = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消", action: onCancel)
                Spacer()

                HStack(spacing: 8) {
                    Button(action: insertHeading1) {
                        Text("H1")
                            .font(.caption.weight(.semibold))
                    }
                    Button(action: insertHeading2) {
                        Text("H2")
                            .font(.caption.weight(.semibold))
                    }
                    Button(action: toggleBold) {
                        Image(systemName: "bold")
                    }
                    Button(action: applyQuote) {
                        Image(systemName: "text.quote")
                    }
                    Button(action: applyBulletList) {
                        Image(systemName: "list.bullet")
                    }
                    Button(action: applyNumberedList) {
                        Image(systemName: "list.number")
                    }
                    Button(action: toggleCode) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                    }
                }
                .buttonStyle(.plain)

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
                .font(.system(.body, design: useSerifFont ? .serif : .default))
                .padding(8)
        }
        .onAppear {
            content = note?.content ?? ""
            scope = note?.scope ?? .page(currentPage)
        }
    }

    private func insertHeading1() {
        content = applyPrefixToLastLine("# ", in: content)
    }

    private func insertHeading2() {
        content = applyPrefixToLastLine("## ", in: content)
    }

    private func applyQuote() {
        content = applyPrefixToLastLine("> ", in: content)
    }

    private func applyBulletList() {
        content = applyPrefixToLastLine("- ", in: content)
    }

    private func applyNumberedList() {
        content = applyPrefixToLastLine("1. ", in: content)
    }

    private func toggleBold() {
        content = wrapLastLine(in: content, prefix: "**", suffix: "**")
    }

    private func toggleCode() {
        content = wrapLastLine(in: content, prefix: "`", suffix: "`")
    }

    private func applyPrefixToLastLine(_ prefix: String, in source: String) -> String {
        var lines = source.components(separatedBy: "\n")
        if lines.isEmpty {
            return prefix
        }
        let lastIndex = lines.count - 1
        let current = lines[lastIndex].trimmingCharacters(in: .whitespaces)
        lines[lastIndex] = current.isEmpty ? prefix : prefix + current
        return lines.joined(separator: "\n")
    }

    private func wrapLastLine(in source: String, prefix: String, suffix: String) -> String {
        var lines = source.components(separatedBy: "\n")
        if lines.isEmpty {
            return prefix + suffix
        }
        let lastIndex = lines.count - 1
        let raw = lines[lastIndex].trimmingCharacters(in: .whitespaces)
        lines[lastIndex] = raw.isEmpty ? "\(prefix)\(suffix)" : "\(prefix)\(raw)\(suffix)"
        return lines.joined(separator: "\n")
    }
}
