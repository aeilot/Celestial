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
    @State private var selectionBounds: CGRect?
    @State private var selectionPageIndex: Int?
    @State private var rightPanel: RightPanel = .none
    @State private var pageCount = 0
    @State private var showFloatingToolbar = false

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

                // PDF view with floating toolbar overlay
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        PDFKitView(
                            document: document,
                            selectedText: $selectedText,
                            currentPageIndex: $currentPageIndex,
                            selectionBounds: $selectionBounds,
                            selectionPageIndex: $selectionPageIndex,
                            highlights: currentBook.highlights
                        )

                        // Floating toolbar near selection
                        if showFloatingToolbar && !selectedText.isEmpty {
                            floatingToolbar
                                .fixedSize()
                                .position(
                                    floatingToolbarPosition(
                                        in: geo.size
                                    )
                                )
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                }
                .animation(.spring(response: 0.25), value: showFloatingToolbar)

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
        .onChange(of: selectedText) {
            showFloatingToolbar = !selectedText.isEmpty
        }
    }

    private var currentBook: PDFBook {
        store.books.first(where: { $0.id == book.id }) ?? book
    }

    // MARK: - Floating Toolbar

    private var floatingToolbar: some View {
        HStack(spacing: 2) {
            Button(action: highlightSelection) {
                Label("高亮", systemImage: "highlighter")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()
                .frame(height: 16)

            Button(action: lookUpWord) {
                Label("查词", systemImage: "character.book.closed")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()
                .frame(height: 16)

            Button(action: addNoteForSelection) {
                Label("笔记", systemImage: "note.text.badge.plus")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()
                .frame(height: 16)

            Button(action: askAIAboutSelection) {
                Label("问 AI", systemImage: "sparkles")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
        .padding(.top, 8)
    }

    /// Compute the position for the floating toolbar relative to the selection bounds.
    private func floatingToolbarPosition(in containerSize: CGSize) -> CGPoint {
        let toolbarWidth: CGFloat = 320  // approximate width of the floating toolbar
        let toolbarHeight: CGFloat = 40  // approximate height

        guard let bounds = selectionBounds else {
            // Fallback to center-top
            return CGPoint(x: containerSize.width / 2, y: toolbarHeight / 2 + 8)
        }

        // Center horizontally over the selection, clamped to container
        let idealX = bounds.midX
        let clampedX = min(
            max(idealX, toolbarWidth / 2 + 8),
            containerSize.width - toolbarWidth / 2 - 8
        )

        // Place above the selection (selectionBounds.minY is the top of selection in view coords)
        let idealY = bounds.minY - toolbarHeight / 2 - 8
        // If not enough space above, place below the selection
        let y: CGFloat
        if idealY < toolbarHeight / 2 + 4 {
            y = bounds.maxY + toolbarHeight / 2 + 8
        } else {
            y = idealY
        }

        return CGPoint(x: clampedX, y: y)
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

            // Zoom controls
            Button(action: { /* zoom handled via PDFView */ }) {
                Label("缩小", systemImage: "minus.magnifyingglass")
            }
            .help("缩小 (⌘-)")

            Button(action: { /* zoom handled via PDFView */ }) {
                Label("放大", systemImage: "plus.magnifyingglass")
            }
            .help("放大 (⌘+)")

            Divider()
                .frame(height: 20)

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

        let bounds = selectionBounds ?? CGRect(x: 0, y: 0, width: 100, height: 20)
        let page = selectionPageIndex ?? currentPageIndex

        let highlight = BookHighlight(
            pageIndex: page,
            text: selectedText,
            boundsX: bounds.origin.x,
            boundsY: bounds.origin.y,
            boundsWidth: bounds.width,
            boundsHeight: bounds.height
        )
        store.addHighlight(to: book.id, highlight: highlight)
        showFloatingToolbar = false
    }

    private func lookUpWord() {
        guard !selectedText.isEmpty else { return }
        let word = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }

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
        showFloatingToolbar = false
    }

    private func addNoteForSelection() {
        // Open notes panel highlighting scope
        if rightPanel != .notes {
            togglePanel(.notes)
        }
        showFloatingToolbar = false
    }

    private func askAIAboutSelection() {
        // Open AI panel
        if rightPanel != .ai {
            togglePanel(.ai)
        }
        showFloatingToolbar = false
    }
}
