//
//  BookshelfView.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct BookshelfView: View {
    @Environment(BookStore.self) private var store
    var searchText: String = ""
    var filterTag: String? = nil
    var filterFolder: String? = nil
    var onOpenBook: (PDFBook) -> Void

    @State private var editingBook: PDFBook?
    @State private var showImporter = false
    @AppStorage("bookshelfViewMode") private var viewMode: BookshelfViewMode = .grid

    enum BookshelfViewMode: String, CaseIterable {
        case grid
        case list
    }

    private var filteredBooks: [PDFBook] {
        var result = store.books

        if let folder = filterFolder {
            let prefix = folder + "/"
            result = result.filter { $0.fileName.hasPrefix(prefix) }
        }

        if let tag = filterTag {
            result = result.filter { $0.tags.contains(tag) }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.author.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result.sorted { ($0.lastOpened ?? $0.dateAdded) > ($1.lastOpened ?? $1.dateAdded) }
    }

    /// Calculate uniform column count based on container width.
    private func columnCount(for width: CGFloat) -> Int {
        let minCardWidth: CGFloat = 180
        let horizontalPadding: CGFloat = 48 // 24 per side
        let spacing: CGFloat = 24
        let availableWidth = width - horizontalPadding
        let count = max(1, Int((availableWidth + spacing) / (minCardWidth + spacing)))
        return count
    }

    /// Build uniform fixed-width grid columns.
    private func gridColumns(for width: CGFloat) -> [GridItem] {
        let count = columnCount(for: width)
        return Array(repeating: GridItem(.flexible(), spacing: 24), count: count)
    }

    /// Group books into rows of uniform size for shelf dividers.
    private func bookRows(for width: CGFloat) -> [[PDFBook]] {
        let perRow = columnCount(for: width)
        return stride(from: 0, to: filteredBooks.count, by: perRow).map {
            Array(filteredBooks[$0..<min($0 + perRow, filteredBooks.count)])
        }
    }

    @State private var containerWidth: CGFloat = 800

    var body: some View {
        ScrollView {
            if store.libraryPath == nil {
                emptyLibraryView
            } else if filteredBooks.isEmpty {
                emptyBooksView
            } else {
                switch viewMode {
                case .grid:
                    shelfGridContent(width: containerWidth)
                case .list:
                    listView
                }
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { containerWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newWidth in
                        containerWidth = newWidth
                    }
            }
        )
        .background(Color(nsColor: .controlBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // View mode toggle
                Picker("视图模式", selection: $viewMode) {
                    Image(systemName: "square.grid.2x2")
                        .help("网格视图")
                        .tag(BookshelfViewMode.grid)
                    Image(systemName: "list.bullet")
                        .help("列表视图")
                        .tag(BookshelfViewMode.list)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)

                Button(action: { store.selectLibraryDirectory() }) {
                    Label("选择目录", systemImage: "folder.badge.plus")
                }
                .help("选择 PDF 库目录")

                Button(action: { showImporter = true }) {
                    Label("添加 PDF", systemImage: "plus")
                }
                .help("导入 PDF 文件")
                .disabled(store.libraryPath == nil)

                Button(action: { store.scanDirectory() }) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .help("重新扫描目录")
                .disabled(store.libraryPath == nil)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                for url in urls {
                    if url.startAccessingSecurityScopedResource() {
                        store.addBook(from: url)
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            }
        }
        .sheet(item: $editingBook) { book in
            BookDetailSheet(book: book)
        }
    }

    // MARK: - Shelf Grid with Dividers (Uniform Columns)

    private func shelfGridContent(width: CGFloat) -> some View {
        let cols = gridColumns(for: width)
        let rows = bookRows(for: width)

        return LazyVStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, rowBooks in
                LazyVGrid(columns: cols, spacing: 20) {
                    ForEach(rowBooks) { book in
                        BookCardView(book: book)
                            .onTapGesture {
                                store.markOpened(book)
                                onOpenBook(book)
                            }
                            .contextMenu {
                                Button("编辑信息") { editingBook = book }
                                Divider()
                                Button("删除", role: .destructive) {
                                    store.removeBook(book)
                                }
                            }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                shelfDivider
            }
        }
    }

    // MARK: - List View

    private var listView: some View {
        LazyVStack(spacing: 0) {
            ForEach(filteredBooks) { book in
                bookListRow(book)
                    .onTapGesture {
                        store.markOpened(book)
                        onOpenBook(book)
                    }
                    .contextMenu {
                        Button("编辑信息") { editingBook = book }
                        Divider()
                        Button("删除", role: .destructive) {
                            store.removeBook(book)
                        }
                    }

                Divider()
                    .padding(.leading, 76)
            }
        }
        .padding(.vertical, 8)
    }

    private func bookListRow(_ book: PDFBook) -> some View {
        HStack(spacing: 14) {
            // Thumbnail
            Group {
                if let img = store.thumbnail(for: book) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .controlBackgroundColor))
                        Image(systemName: "doc.richtext")
                            .font(.title3)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(width: 48, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !book.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(book.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(tagColor(for: tag).opacity(0.15))
                                .foregroundStyle(tagColor(for: tag))
                                .clipShape(Capsule())
                        }
                        if book.tags.count > 3 {
                            Text("+\(book.tags.count - 3)")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Spacer()

            // Date
            if let lastOpened = book.lastOpened {
                Text(lastOpened, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .background(Color.clear)
    }

    private func tagColor(for tag: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .cyan, .indigo, .mint]
        let hash = abs(tag.hashValue)
        return colors[hash % colors.count]
    }

    // MARK: - Shelf Divider

    private var shelfDivider: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(nsColor: .separatorColor).opacity(0.6),
                            Color(nsColor: .separatorColor).opacity(0.3)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.12),
                            Color.black.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 12)
        }
    }

    // MARK: - Empty States

    private var emptyLibraryView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("尚未选择 PDF 目录")
                .font(.title2)
                .fontWeight(.medium)
            Text("点击上方「选择目录」按钮来指定 PDF 文件所在的文件夹")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("选择目录") {
                store.selectLibraryDirectory()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var emptyBooksView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "book.closed")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("没有找到 PDF 文件")
                .font(.title2)
                .fontWeight(.medium)
            if !searchText.isEmpty {
                Text("试试其他搜索关键词")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
