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
    @State private var selectionPageBounds: CGRect?
    @State private var selectionPageIndex: Int?
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
    @State private var isHoveringTopEdge = false
    @State private var didScrollUpRecently = true
    @AppStorage("useSerifFont") private var useSerifFont = false
    @AppStorage("readerTopBarVisibility") private var readerTopBarVisibilityRaw = ReaderTopBarVisibility.defaultValue.rawValue
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

                VStack(spacing: 0) {
                    GeometryReader { _ in
                        ZStack(alignment: .top) {
                            if isLoadingDocument {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                PDFKitView(
                                    document: document,
                                    selectedText: $selectedText,
                                    currentPageIndex: $currentPageIndex,
                                    selectionPageBounds: $selectionPageBounds,
                                    selectionPageIndex: $selectionPageIndex,
                                    jumpToPageIndex: $jumpToPageIndex,
                                    highlights: currentBook.highlights,
                                    displayMode: displayMode,
                                    onHighlightAnnotationTapped: handleHighlightTapped,
                                    onBackgroundTapped: handleBackgroundTapped
                                )
                            }

                            Color.clear
                                .frame(height: 96)
                                .contentShape(Rectangle())
                                .onHover { hovering in
                                    isHoveringTopEdge = hovering
                                }

                            if isTopBarVisible {
                                readerTopBar
                                    .padding(.top, 12)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                    }

                    statusBar
                }
                .frame(minWidth: minimumPDFPaneWidth)

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
        .animation(.spring(response: 0.24, dampingFraction: 0.9), value: isTopBarVisible)
        .onAppear {
            Task {
                isLoadingDocument = true
                document = await Task.detached {
                    await store.pdfDocument(for: book)
                }.value
                pageCount = document?.pageCount ?? 0
                tocItems = makeTOCItems(from: document)
                isLoadingDocument = false
            }
            if !HighlightPalette.allHex.contains(lastHighlightColorHex) {
                lastHighlightColorHex = HighlightPalette.defaultHex
            }
        }
        .onChange(of: currentPageIndex) { oldValue, newValue in
            if newValue < oldValue {
                didScrollUpRecently = true
            } else if newValue > oldValue {
                didScrollUpRecently = false
            }
        }
        .onChange(of: selectedText) { _, newValue in
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                clearActiveHighlightState()
            }
        }
    }

    private var topBarVisibilityMode: ReaderTopBarVisibility {
        ReaderTopBarVisibility.parse(readerTopBarVisibilityRaw)
    }

    private var isTopBarVisible: Bool {
        ReaderTopBarVisibilityState.isTopBarVisible(
            mode: topBarVisibilityMode,
            isHoveringTopEdge: isHoveringTopEdge,
            didScrollUpRecently: didScrollUpRecently
        )
    }

    private var currentBook: PDFBook {
        store.books.first(where: { $0.id == book.id }) ?? book
    }

    private var selectionState: ReaderSelectionState {
        ReaderSelectionState(
            selectedText: selectedText,
            pageIndex: selectionPageIndex,
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

    private var hasSelectionText: Bool {
        !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Top Bar

    private var readerTopBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                circularButton("chevron.left", help: "返回书架", isActive: false, action: onClose)
                circularButton("sidebar.left", help: "显示或隐藏左侧目录", isActive: isTOCVisible, action: toggleTOCSidebar)

                Text(book.title)
                    .font(.system(.headline, design: useSerifFont ? .serif : .default))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(book.title)
            }

            Spacer(minLength: 16)

            HStack(spacing: 10) {
                highlightPaletteButtons

                circularButton("note.text.badge.plus", help: "为选中文字添加笔记；无选中时新建全书笔记", isActive: selectedSidebarTab == .notes && isSidebarVisible, action: addNoteForSelection)
                circularButton("sparkles", help: "基于选中文字提问；无选中时按全书上下文提问", isActive: selectedSidebarTab == .ai && isSidebarVisible, action: askAIAboutSelection)
                circularButton("sidebar.right", help: "显示或隐藏右侧面板", isActive: isSidebarVisible, action: toggleSidebar)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 1100)
        .modifier(ReaderGlassSurface(cornerRadius: 24))
    }

    private var highlightPaletteButtons: some View {
        HStack(spacing: 8) {
            ForEach(HighlightPalette.allHex, id: \.self) { hex in
                Button(action: { handleHighlightColorTap(hex) }) {
                    Circle()
                        .fill(Color.fromHighlightHex(hex) ?? .yellow)
                        .frame(width: 26, height: 26)
                        .overlay {
                            if hex == currentHighlightColorHex {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay {
                            if shouldShowHighlightSelectionRing(for: hex) {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                            }
                        }
                        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .help(highlightColorHelpText(for: hex))
                .opacity(hasSelectionText || activeHighlightID != nil ? 1.0 : 0.85)
            }
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func circularButton(
        _ systemImage: String,
        help: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 34)
                .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                .background(
                    Circle()
                        .fill(.thinMaterial)
                )
                .overlay(
                    Circle()
                        .stroke(
                            isActive ? Color.accentColor.opacity(0.45) : Color.white.opacity(0.28),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(isActive ? 0.12 : 0.08), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .help(help)
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
        .padding(10)
        .modifier(ReaderGlassSurface(cornerRadius: 20))
        .padding(.vertical, 10)
        .padding(.trailing, 10)
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
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
        .padding(10)
        .modifier(ReaderGlassSurface(cornerRadius: 20))
        .padding(.vertical, 10)
        .padding(.leading, 10)
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
        selectionPageBounds = nil
        selectionPageIndex = nil
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

private struct ReaderGlassSurface: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 14, y: 5)
    }
}
