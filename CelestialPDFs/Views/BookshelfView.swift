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
    var onOpenBook: (PDFBook) -> Void

    @State private var editingBook: PDFBook?
    @State private var showImporter = false

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 24)
    ]

    private var filteredBooks: [PDFBook] {
        var result = store.books

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

    // Group books into rows for shelf dividers
    private var bookRows: [[PDFBook]] {
        let perRow = max(1, Int((NSScreen.main?.frame.width ?? 1200) / 200))
        return stride(from: 0, to: filteredBooks.count, by: perRow).map {
            Array(filteredBooks[$0..<min($0 + perRow, filteredBooks.count)])
        }
    }

    var body: some View {
        ScrollView {
            if store.libraryPath == nil {
                emptyLibraryView
            } else if filteredBooks.isEmpty {
                emptyBooksView
            } else {
                shelfGridView
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
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

    // MARK: - Shelf Grid with Dividers

    private var shelfGridView: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(bookRows.enumerated()), id: \.offset) { rowIndex, rowBooks in
                // Books row
                LazyVGrid(columns: columns, spacing: 20) {
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

                // Shelf divider with gradient shadow
                shelfDivider
            }
        }
    }

    private var shelfDivider: some View {
        VStack(spacing: 0) {
            // The shelf surface
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

            // Gradient shadow below the shelf board
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
