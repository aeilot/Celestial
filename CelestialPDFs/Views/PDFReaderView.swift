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
    @State private var selectionAnchor: ReaderSelectionAnchor?
    @State private var activeHighlightID: UUID?
    @State private var isTOCVisible = false
    @State private var tocItems: [ReaderOutlineItem] = []
    @State private var jumpToPageIndex: Int?
    @State private var isSidebarVisible = false
    @State private var selectedSidebarTab: SidebarTab = .notes
    @State private var aiContextMode: AIChatView.ContextMode = .page
    @State private var pageCount = 0
    @State private var isLoadingDocument = false
    @State private var displayMode: PDFKitView.PDFDisplayMode = .autoScale
    @AppStorage("useSerifFont") private var useSerifFont = false
    @AppStorage("readerToolbarShowsLabels") private var readerToolbarShowsLabels = true
    @AppStorage("lastHighlightColorHex") private var lastHighlightColorHex = HighlightPalette.defaultHex
    private let minimumPDFPaneWidth: CGFloat = 720

    enum SidebarTab: Hashable {
        case notes, ai
    }

    var body: some View {
        GeometryReader { geometry in
            HSplitView {
                if isTOCVisible {
                    tocSidebar
                        .frame(minWidth: 220, idealWidth: 260, maxWidth: 360)
                }

                // PDF content
                VStack(spacing: 0) {
                    // Toolbar
                    readerToolbar
                    Divider()

                    // PDF view
                    GeometryReader { _ in
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
                                    selectionAnchor: $selectionAnchor,
                                    jumpToPageIndex: $jumpToPageIndex,
                                    highlights: currentBook.highlights,
                                    displayMode: displayMode,
                                    onHighlightAnnotationTapped: handleHighlightTapped,
                                    onBackgroundTapped: handleBackgroundTapped
                                )
                            }
                        }
                    }

                    // Status bar
                    statusBar
                }
                .frame(minWidth: minimumPDFPaneWidth)

                // Right sidebar
                if isSidebarVisible {
                    rightPanelView
                        .frame(
                            minWidth: 420,
                            idealWidth: 520,
                            maxWidth: max(geometry.size.width * 0.7, 420)
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.9), value: isSidebarVisible)
        }
        .onAppear {
            Task {
                isLoadingDocument = true
                document = await Task.detached {
                    store.pdfDocument(for: book)
                }.value
                pageCount = document?.pageCount ?? 0
                tocItems = makeTOCItems(from: document)
                isLoadingDocument = false
            }
            if !HighlightPalette.allHex.contains(lastHighlightColorHex) {
                lastHighlightColorHex = HighlightPalette.defaultHex
            }
        }
        .onChange(of: selectedText) { _, newValue in
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                clearActiveHighlightState()
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

    private var normalizedStoredHighlightColor: String {
        HighlightPalette.allHex.contains(lastHighlightColorHex) ? lastHighlightColorHex : HighlightPalette.defaultHex
    }

    private var currentHighlightColorHex: String? {
        guard let highlightID = activeHighlightID else { return nil }
        return currentBook.highlights.first(where: { $0.id == highlightID })?.colorHex
    }

    // MARK: - Toolbar

    private var readerToolbar: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: onClose) {
                toolbarLabel("返回书架", systemImage: "chevron.left")
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
                toolbarLabel("显示", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .help("显示模式")

            Divider()
                .frame(height: 20)

            // Zoom controls
            Button(action: { /* zoom handled via PDFView */ }) {
                toolbarLabel("缩小", systemImage: "minus.magnifyingglass")
            }
            .help("缩小 (⌘-)")

            Button(action: { /* zoom handled via PDFView */ }) {
                toolbarLabel("放大", systemImage: "plus.magnifyingglass")
            }
            .help("放大 (⌘+)")

            Divider()
                .frame(height: 20)

            // Highlight colors
            HStack(spacing: 10) {
                ForEach(HighlightPalette.allHex, id: \.self) { hex in
                    Button(action: { handleHighlightColorTap(hex) }) {
                        Circle()
                            .fill(Color.fromHighlightHex(hex) ?? .yellow)
                            .frame(width: 22, height: 22)
                            .overlay {
                                if hex == currentHighlightColorHex {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .overlay {
                                if shouldShowHighlightSelectionRing(for: hex) {
                                    Circle()
                                        .strokeBorder(.primary.opacity(0.5), lineWidth: 1.5)
                                        .frame(width: 26, height: 26)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .help(highlightColorHelpText(for: hex))
                }
            }

            // Look up word
            Button(action: lookUpWord) {
                toolbarLabel("查词", systemImage: "character.book.closed")
            }
            .disabled(selectedText.isEmpty)
            .help("查询选中单词")

            Button(action: addNoteForSelection) {
                toolbarLabel("笔记+", systemImage: "note.text.badge.plus")
            }
            .help("为选中文字添加笔记；无选中时新建全书笔记")

            Button(action: askAIAboutSelection) {
                toolbarLabel("问 AI", systemImage: "sparkles")
            }
            .help("基于选中文字提问；无选中时按全书上下文提问")

            Divider()
                .frame(height: 20)

            Button(action: toggleTOCSidebar) {
                toolbarLabel("目录", systemImage: "sidebar.left")
            }
            .foregroundStyle(isTOCVisible ? Color.accentColor : Color.primary)
            .help("显示或隐藏左侧目录")

            Button(action: toggleSidebar) {
                toolbarLabel("面板", systemImage: "sidebar.right")
            }
            .foregroundStyle(isSidebarVisible ? Color.accentColor : Color.primary)
            .help("显示或隐藏右侧面板")
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
        TabView(selection: $selectedSidebarTab) {
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
                        clearActiveHighlightState()
                    }
                }
            )
            .tabItem {
                Label("笔记", systemImage: "note.text")
            }
            .tag(SidebarTab.notes)

            AIChatView(
                book: currentBook,
                selectedText: selectedText,
                currentPage: currentPageIndex,
                document: document,
                contextMode: aiContextMode
            )
            .tabItem {
                Label("AI", systemImage: "sparkles")
            }
            .tag(SidebarTab.ai)
        }
    }

    private var tocSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("目录")
                    .font(.system(.headline, design: useSerifFont ? .serif : .default))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if tocItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("此 PDF 没有目录")
                        .font(.system(.caption, design: useSerifFont ? .serif : .default))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    OutlineGroup(tocItems, children: \.children) { item in
                        Button(action: { jumpToOutline(item) }) {
                            HStack(spacing: 6) {
                                Text(item.title)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                if let pageIndex = item.pageIndex {
                                    Text("\(pageIndex + 1)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .foregroundStyle(
                                item.pageIndex == currentPageIndex ? Color.accentColor : Color.primary
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(item.pageIndex == nil)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Actions

    private func toggleSidebar() {
        withAnimation(.spring(response: 0.3)) {
            isSidebarVisible.toggle()
        }
    }

    private func toggleTOCSidebar() {
        withAnimation(.spring(response: 0.3)) {
            isTOCVisible.toggle()
        }
    }

    @ViewBuilder
    private func toolbarLabel(_ title: String, systemImage: String) -> some View {
        if readerToolbarShowsLabels {
            Label(title, systemImage: systemImage)
        } else {
            Image(systemName: systemImage)
        }
    }

    private func shouldShowHighlightSelectionRing(for hex: String) -> Bool {
        if let activeColor = currentHighlightColorHex {
            return activeColor == hex
        }
        return normalizedStoredHighlightColor == hex
    }

    private func highlightColorHelpText(for hex: String) -> String {
        if currentHighlightColorHex == hex {
            return "删除当前高亮"
        }
        if activeHighlightID != nil {
            return "修改当前高亮颜色"
        }
        return "使用该颜色高亮选中文字"
    }

    private func handleHighlightColorTap(_ colorHex: String) {
        let normalizedHex = HighlightPalette.allHex.contains(colorHex) ? colorHex : HighlightPalette.defaultHex
        let action = ReaderHighlightToolbarAction.resolve(
            tappedColorHex: normalizedHex,
            activeHighlightID: activeHighlightID,
            currentHighlightColorHex: currentHighlightColorHex
        )

        switch action {
        case .deleteHighlight:
            deleteActiveHighlight()
        case .applyColor(let hex):
            lastHighlightColorHex = hex
            if let highlightID = activeHighlightID {
                store.updateHighlightColor(in: book.id, highlightId: highlightID, colorHex: hex)
                clearActiveHighlightState()
            } else {
                highlightSelection(colorHex: hex)
            }
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
        let content = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = BookNote(
            scope: content.isEmpty ? .book : .page(selectionPageIndex ?? currentPageIndex),
            content: content.isEmpty ? "新建全书笔记" : content
        )
        store.addNote(to: book.id, note: note)
        selectedSidebarTab = .notes
        isSidebarVisible = true
        clearSelectionState()
    }

    private func askAIAboutSelection() {
        let content = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        aiContextMode = content.isEmpty ? .book : .page
        selectedSidebarTab = .ai
        isSidebarVisible = true
    }

    private func clearSelectionState() {
        selectedText = ""
        selectionOverlayBounds = nil
        selectionPageBounds = nil
        selectionPageIndex = nil
        selectionAnchor = nil
    }

    private func handleHighlightTapped(id: UUID, bounds _: CGRect) {
        activeHighlightID = id
        clearSelectionState()
    }

    private func handleBackgroundTapped() {
        clearSelectionState()
        clearActiveHighlightState()
    }

    private func clearActiveHighlightState() {
        activeHighlightID = nil
    }

    private func deleteActiveHighlight() {
        guard let highlightID = activeHighlightID else { return }
        store.detachNotesLinkedToHighlight(in: book.id, highlightId: highlightID)
        store.removeHighlight(from: book.id, highlightId: highlightID)
        clearActiveHighlightState()
    }

    private func jumpToOutline(_ item: ReaderOutlineItem) {
        guard let pageIndex = item.pageIndex else { return }
        jumpToPageIndex = pageIndex
    }

    private func makeTOCItems(from document: PDFDocument?) -> [ReaderOutlineItem] {
        guard let root = document?.outlineRoot else { return [] }

        func build(from outline: PDFOutline) -> ReaderOutlineItem {
            let title = (outline.label?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
                $0.isEmpty ? nil : $0
            } ?? "未命名章节"

            let pageIndex: Int? = {
                guard let document else { return nil }
                if let page = outline.destination?.page {
                    let index = document.index(for: page)
                    return index >= 0 ? index : nil
                }
                return nil
            }()

            var children: [ReaderOutlineItem] = []
            for childIndex in 0..<outline.numberOfChildren {
                if let child = outline.child(at: childIndex) {
                    children.append(build(from: child))
                }
            }

            return ReaderOutlineItem(
                title: title,
                pageIndex: pageIndex,
                children: children.isEmpty ? nil : children
            )
        }

        var items: [ReaderOutlineItem] = []
        for index in 0..<root.numberOfChildren {
            if let child = root.child(at: index) {
                items.append(build(from: child))
            }
        }
        return items
    }
}

enum ReaderHighlightToolbarAction: Equatable {
    case applyColor(String)
    case deleteHighlight

    static func resolve(
        tappedColorHex: String,
        activeHighlightID: UUID?,
        currentHighlightColorHex: String?
    ) -> ReaderHighlightToolbarAction {
        if activeHighlightID != nil && tappedColorHex == currentHighlightColorHex {
            return .deleteHighlight
        }
        return .applyColor(tappedColorHex)
    }
}

private struct ReaderOutlineItem: Identifiable {
    let id = UUID()
    let title: String
    let pageIndex: Int?
    let children: [ReaderOutlineItem]?
}
