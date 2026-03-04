//
//  PDFReaderView.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import SwiftUI
import PDFKit

struct PDFReaderView: View {
    @Environment(BookStore.self) private var store
    let book: PDFBook
    var onClose: () -> Void

    @State private var document: PDFDocument?
    @State private var selectedText = ""
    @State private var currentPageIndex = 0
    @State private var showNotes = false
    @State private var showAI = false
    @State private var rightPanel: RightPanel = .none
    @State private var pageCount = 0

    enum RightPanel {
        case none, notes, ai
    }

    var body: some View {
        HSplitView {
            // PDF content
            VStack(spacing: 0) {
                // Toolbar
                readerToolbar
                Divider()

                // PDF view
                PDFKitView(
                    document: document,
                    selectedText: $selectedText,
                    currentPageIndex: $currentPageIndex,
                    highlights: currentBook.highlights
                )

                // Status bar
                statusBar
            }

            // Right Panel
            if rightPanel != .none {
                rightPanelView
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
            }
        }
        .onAppear {
            document = store.pdfDocument(for: book)
            pageCount = document?.pageCount ?? 0
        }
    }

    private var currentBook: PDFBook {
        store.books.first(where: { $0.id == book.id }) ?? book
    }

    // MARK: - Toolbar

    private var readerToolbar: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: onClose) {
                Label("返回书架", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 20)

            Text(book.title)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            // Highlight button
            Button(action: highlightSelection) {
                Label("高亮", systemImage: "highlighter")
            }
            .disabled(selectedText.isEmpty)
            .help("高亮选中文字")

            // Look up word
            Button(action: lookUpWord) {
                Label("查词", systemImage: "character.book.closed")
            }
            .disabled(selectedText.isEmpty)
            .help("查询选中单词")

            Divider()
                .frame(height: 20)

            // Notes toggle
            Button(action: { togglePanel(.notes) }) {
                Label("笔记", systemImage: "note.text")
            }
            .foregroundStyle(rightPanel == .notes ? Color.accentColor : Color.primary)

            // AI toggle
            Button(action: { togglePanel(.ai) }) {
                Label("AI", systemImage: "sparkles")
            }
            .foregroundStyle(rightPanel == .ai ? Color.accentColor : Color.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Text("第 \(currentPageIndex + 1) / \(pageCount) 页")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if !selectedText.isEmpty {
                Text("已选中 \(selectedText.count) 个字符")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Right Panel

    @ViewBuilder
    private var rightPanelView: some View {
        switch rightPanel {
        case .notes:
            ReaderNotesView(book: currentBook, currentPage: currentPageIndex, selectedText: selectedText)
        case .ai:
            AIChatView(
                book: currentBook,
                selectedText: selectedText,
                currentPage: currentPageIndex,
                document: document
            )
        case .none:
            EmptyView()
        }
    }

    // MARK: - Actions

    private func togglePanel(_ panel: RightPanel) {
        withAnimation(.spring(response: 0.3)) {
            rightPanel = rightPanel == panel ? .none : panel
        }
    }

    private func highlightSelection() {
        guard !selectedText.isEmpty else { return }
        // We need to get the selection bounds from the PDF view
        // For now, create a placeholder highlight with approximate bounds
        let highlight = BookHighlight(
            pageIndex: currentPageIndex,
            text: selectedText,
            boundsX: 0,
            boundsY: 0,
            boundsWidth: 100,
            boundsHeight: 20
        )
        store.addHighlight(to: book.id, highlight: highlight)
    }

    private func lookUpWord() {
        guard !selectedText.isEmpty else { return }
        let word = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Save to vocabulary
        let entry = VocabularyEntry(
            word: word,
            bookId: book.id,
            bookTitle: book.title,
            pageIndex: currentPageIndex
        )
        store.addVocabulary(entry)

        // Open Dictionary.app
        let sanitized = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? word
        if let url = URL(string: "dict://\(sanitized)") {
            NSWorkspace.shared.open(url)
        }
    }
}
