//
//  NotesListView.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import SwiftUI

struct NotesListView: View {
    @Environment(BookStore.self) private var store
    @AppStorage("useSerifFont") private var useSerifFont = false
    @State private var containerWidth: CGFloat = 800

    var body: some View {
        Group {
            if store.allNotes.isEmpty {
                emptyView
            } else {
                notesGrid
            }
        }
        .navigationTitle("笔记")
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { containerWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newWidth in
                        containerWidth = newWidth
                    }
            }
        )
    }

    private var notesGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 16)], spacing: 16) {
                ForEach(store.allNotes, id: \.note.id) { item in
                    NoteCard(book: item.book, note: item.note)
                }
            }
            .padding(16)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("暂无笔记")
                .font(.system(.title3, design: useSerifFont ? .serif : .default))
                .fontWeight(.medium)
            Text("在阅读 PDF 时可以添加笔记")
                .font(.system(.body, design: useSerifFont ? .serif : .default))
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

struct NoteCard: View {
    let book: PDFBook
    let note: BookNote
    @AppStorage("useSerifFont") private var useSerifFont = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(book.title)
                    .font(.system(.caption, design: useSerifFont ? .serif : .default))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }

            Text(note.content)
                .font(.system(.body, design: useSerifFont ? .serif : .default))
                .lineLimit(6)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Text(note.dateModified, style: .date)
                .font(.system(.caption2, design: useSerifFont ? .serif : .default))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(width: 280, height: 200)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
