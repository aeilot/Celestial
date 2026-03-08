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
    @State private var selectionOverlayBounds: CGRect?
    @State private var selectionPageBounds: CGRect?
    @State private var selectionPageIndex: Int?
    @State private var activeHighlightID: UUID?
    @State private var activeHighlightOverlayBounds: CGRect?
    @State private var rightPanel: RightPanel = .none
    @State private var pageCount = 0
    @State private var isLoadingDocument = false
    @State private var displayMode: PDFKitView.PDFDisplayMode = .autoScale
    @AppStorage("useSerifFont") private var useSerifFont = false
    @AppStorage("showFloatingToolbar") private var showFloatingToolbarSetting = true
    @AppStorage("lastHighlightColorHex") private var lastHighlightColorHex = HighlightPalette.defaultHex
    private let minimumPDFPaneWidth: CGFloat = 720

    enum RightPanel {
        case none, notes, ai
    }

    var body: some View {
        GeometryReader { geometry in
            HSplitView {
                // PDF content
                VStack(spacing: 0) {
                    // Toolbar
                    readerToolbar
                    Divider()

                    // PDF view with floating toolbar overlay
                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            if isLoadingDocument {
                                VStack {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                PDFKitView(
                                    document: document,
                                    selectedText: $selectedText,
                                    currentPageIndex: $currentPageIndex,
                                    selectionOverlayBounds: $selectionOverlayBounds,
                                    selectionPageBounds: $selectionPageBounds,
                                    selectionPageIndex: $selectionPageIndex,
                                    highlights: currentBook.highlights,
                                    displayMode: displayMode,
                                    onHighlightAnnotationTapped: handleHighlightTapped
                                )
                            }

                            // Floating toolbar near selection
                            if shouldShowFloatingToolbar {
                                floatingToolbar
                                    .fixedSize()
                                    .position(
                                        floatingToolbarPosition(
                                            in: geo.size
                                        )
                                    )
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            }

                            if shouldShowHighlightPopover {
                                highlightActionPopover
                                    .position(highlightPopoverPosition(in: geo.size))
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                        }
                    }
                    .animation(.spring(response: 0.25), value: shouldShowFloatingToolbar)
                    .animation(.spring(response: 0.25), value: shouldShowHighlightPopover)

                    // Status bar
                    statusBar
                }
                .frame(minWidth: minimumPDFPaneWidth)

                // Right Panel
                if rightPanel != .none {
                    rightPanelView
                        .id(rightPanel)
                        .frame(
                            minWidth: rightPanel == .notes ? 560 : 280,
                            idealWidth: rightPanel == .notes ? 700 : 320,
                            maxWidth: rightPanel == .notes ? max(geometry.size.width * 0.75, 560) : geometry.size.width / 2
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.9), value: rightPanel)
        }
        .onAppear {
            Task {
                isLoadingDocument = true
                document = await Task.detached {
                    store.pdfDocument(for: book)
                }.value
                pageCount = document?.pageCount ?? 0
                isLoadingDocument = false
            }
            if !HighlightPalette.allHex.contains(lastHighlightColorHex) {
                lastHighlightColorHex = HighlightPalette.defaultHex
            }
        }
        .onChange(of: selectedText) { _, newValue in
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                clearHighlightPopoverState()
            }
        }
    }

    private var currentBook: PDFBook {
        store.books.first(where: { $0.id == book.id }) ?? book
    }

    private var selectionState: ReaderSelectionState {
        ReaderSelectionState(
            selectedText: selectedText,
            pageIndex: selectionPageIndex,
            overlayBounds: selectionOverlayBounds,
            pageBounds: selectionPageBounds
        )
    }

    private var shouldShowFloatingToolbar: Bool {
        showFloatingToolbarSetting && selectionState.isValidForToolbar && activeHighlightID == nil
    }

    private var shouldShowHighlightPopover: Bool {
        activeHighlightID != nil && activeHighlightOverlayBounds != nil
    }

    private var normalizedStoredHighlightColor: String {
        HighlightPalette.allHex.contains(lastHighlightColorHex) ? lastHighlightColorHex : HighlightPalette.defaultHex
    }

    // MARK: - Floating Toolbar

    private var floatingToolbar: some View {
        HStack(spacing: 2) {
            Menu {
                ForEach(HighlightPalette.allHex, id: \.self) { hex in
                    Button(action: {
                        lastHighlightColorHex = hex
                        highlightSelection(colorHex: hex)
                    }) {
                        Label {
                            Text("高亮")
                        } icon: {
                            Circle()
                                .fill(Color.fromHighlightHex(hex) ?? .yellow)
                                .frame(width: 10, height: 10)
                        }
                    }
                }
            } label: {
                Label("高亮", systemImage: "highlighter")
                    .labelStyle(.titleAndIcon)
                    .font(.system(.caption, design: useSerifFont ? .serif : .default))
            }
            .menuStyle(.borderlessButton)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()
                .frame(height: 16)

            Button(action: lookUpWord) {
                Label("查词", systemImage: "character.book.closed")
                    .labelStyle(.titleAndIcon)
                    .font(.system(.caption, design: useSerifFont ? .serif : .default))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()
                .frame(height: 16)

            Button(action: addNoteForSelection) {
                Label("笔记", systemImage: "note.text.badge.plus")
                    .labelStyle(.titleAndIcon)
                    .font(.system(.caption, design: useSerifFont ? .serif : .default))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()
                .frame(height: 16)

            Button(action: askAIAboutSelection) {
                Label("问 AI", systemImage: "sparkles")
                    .labelStyle(.titleAndIcon)
                    .font(.system(.caption, design: useSerifFont ? .serif : .default))
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
    }

    private var highlightActionPopover: some View {
        HStack(spacing: 8) {
            ForEach(HighlightPalette.allHex, id: \.self) { hex in
                Button(action: {
                    guard let highlightID = activeHighlightID else { return }
                    store.updateHighlightColor(in: book.id, highlightId: highlightID, colorHex: hex)
                    lastHighlightColorHex = hex
                    clearHighlightPopoverState()
                }) {
                    Circle()
                        .fill(Color.fromHighlightHex(hex) ?? .yellow)
                        .frame(width: 16, height: 16)
                        .overlay {
                            if hex == currentHighlightColorHex {
                                Circle()
                                    .strokeBorder(.primary.opacity(0.65), lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                            }
                        }
                }
                .buttonStyle(.plain)
            }

            Divider()
                .frame(height: 16)

            Button(role: .destructive, action: deleteActiveHighlight) {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
    }

    private var currentHighlightColorHex: String? {
        guard let highlightID = activeHighlightID else { return nil }
        return currentBook.highlights.first(where: { $0.id == highlightID })?.colorHex
    }

    /// Compute the position for the floating toolbar relative to the selection bounds.
    private func floatingToolbarPosition(in containerSize: CGSize) -> CGPoint {
        let toolbarSize = CGSize(width: 320, height: 40)
        let viewport = CGRect(origin: .zero, size: containerSize)
        let defaultPoint = CGPoint(x: containerSize.width / 2, y: toolbarSize.height / 2 + 8)

        guard let bounds = selectionOverlayBounds else {
            return defaultPoint
        }

        return FloatingToolbarPlacement.computeToolbarPoint(
            selection: bounds,
            viewport: viewport,
            toolbar: toolbarSize,
            margin: 8,
            defaultPoint: defaultPoint
        )
    }

    private func highlightPopoverPosition(in containerSize: CGSize) -> CGPoint {
        let popoverSize = CGSize(width: 240, height: 36)
        let viewport = CGRect(origin: .zero, size: containerSize)
        let defaultPoint = CGPoint(x: containerSize.width / 2, y: popoverSize.height / 2 + 8)
        guard let bounds = activeHighlightOverlayBounds else { return defaultPoint }

        return FloatingToolbarPlacement.computeToolbarPoint(
            selection: bounds,
            viewport: viewport,
            toolbar: popoverSize,
            margin: 8,
            defaultPoint: defaultPoint
        )
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
                .font(.system(.headline, design: useSerifFont ? .serif : .default))
                .lineLimit(1)

            Spacer()

            // Display mode buttons
            Menu {
                Button(action: { displayMode = .autoScale }) {
                    Label("自动缩放", systemImage: displayMode == .autoScale ? "checkmark" : "")
                }
                Button(action: { displayMode = .fitWidth }) {
                    Label("适应宽度", systemImage: displayMode == .fitWidth ? "checkmark" : "")
                }
                Button(action: { displayMode = .fitPage }) {
                    Label("适应页面", systemImage: displayMode == .fitPage ? "checkmark" : "")
                }
            } label: {
                Label("显示", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .help("显示模式")

            Divider()
                .frame(height: 20)

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
            Button(action: { highlightSelection(colorHex: normalizedStoredHighlightColor) }) {
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
                .font(.system(.caption, design: useSerifFont ? .serif : .default))
                .foregroundStyle(.secondary)
            Spacer()
            if !selectedText.isEmpty {
                Text("已选中 \(selectedText.count) 个字符")
                    .font(.system(.caption, design: useSerifFont ? .serif : .default))
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
            ReaderNotesView(
                book: currentBook,
                currentPage: currentPageIndex,
                selectedText: selectedText,
                onHighlightColorChange: { highlightID, colorHex in
                    store.updateHighlightColor(in: book.id, highlightId: highlightID, colorHex: colorHex)
                    lastHighlightColorHex = colorHex
                },
                onHighlightDelete: { highlightID in
                    store.detachNotesLinkedToHighlight(in: book.id, highlightId: highlightID)
                    store.removeHighlight(from: book.id, highlightId: highlightID)
                    if activeHighlightID == highlightID {
                        clearHighlightPopoverState()
                    }
                }
            )
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

    private func highlightSelection(colorHex: String) {
        guard let highlight = ReaderSelectionState.makeHighlight(from: selectionState) else {
            return
        }
        var mutable = highlight
        mutable.colorHex = HighlightPalette.allHex.contains(colorHex) ? colorHex : HighlightPalette.defaultHex
        store.addHighlight(to: book.id, highlight: mutable)
        clearSelectionState()
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
        clearSelectionState()
    }

    private func addNoteForSelection() {
        // Open notes panel highlighting scope
        if rightPanel != .notes {
            togglePanel(.notes)
        }
        clearSelectionState()
    }

    private func askAIAboutSelection() {
        // Open AI panel
        if rightPanel != .ai {
            togglePanel(.ai)
        }
        clearSelectionState()
    }

    private func clearSelectionState() {
        selectedText = ""
        selectionOverlayBounds = nil
        selectionPageBounds = nil
        selectionPageIndex = nil
    }

    private func handleHighlightTapped(id: UUID, bounds: CGRect) {
        activeHighlightID = id
        activeHighlightOverlayBounds = bounds
        clearSelectionState()
    }

    private func clearHighlightPopoverState() {
        activeHighlightID = nil
        activeHighlightOverlayBounds = nil
    }

    private func deleteActiveHighlight() {
        guard let highlightID = activeHighlightID else { return }
        store.detachNotesLinkedToHighlight(in: book.id, highlightId: highlightID)
        store.removeHighlight(from: book.id, highlightId: highlightID)
        clearHighlightPopoverState()
    }
}

enum FloatingToolbarPlacement {
    static func computeToolbarPoint(
        selection: CGRect,
        viewport: CGRect,
        toolbar: CGSize,
        margin: CGFloat,
        defaultPoint: CGPoint
    ) -> CGPoint {
        guard selection.width > 0, selection.height > 0 else { return defaultPoint }

        let minX = viewport.minX + toolbar.width / 2 + margin
        let maxX = viewport.maxX - toolbar.width / 2 - margin
        let clampedX = min(max(selection.midX, minX), maxX)

        let aboveCenter = CGPoint(x: clampedX, y: selection.minY - toolbar.height / 2 - 2)
        let belowCenter = CGPoint(x: clampedX, y: selection.maxY + toolbar.height / 2 + 2)
        let topEdge = CGPoint(x: clampedX, y: viewport.minY + toolbar.height / 2 + margin)
        let bottomEdge = CGPoint(x: clampedX, y: viewport.maxY - toolbar.height / 2 - margin)
        let candidates = [aboveCenter, belowCenter, topEdge, bottomEdge]

        if let firstNonOverlap = candidates.first(where: {
            viewport.contains(toolbarRect(center: $0, size: toolbar)) &&
            !toolbarRect(center: $0, size: toolbar).intersects(selection)
        }) {
            return firstNonOverlap
        }

        return candidates.min(by: {
            candidateScore(center: $0, selection: selection, viewport: viewport, toolbar: toolbar) <
            candidateScore(center: $1, selection: selection, viewport: viewport, toolbar: toolbar)
        }) ?? defaultPoint
    }

    private static func toolbarRect(center: CGPoint, size: CGSize) -> CGRect {
        CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }

    private static func candidateScore(
        center: CGPoint,
        selection: CGRect,
        viewport: CGRect,
        toolbar: CGSize
    ) -> CGFloat {
        let rect = toolbarRect(center: center, size: toolbar)
        let viewportPenalty: CGFloat = viewport.contains(rect) ? 0 : 10_000
        return intersectionArea(rect, selection) + viewportPenalty
    }
}
