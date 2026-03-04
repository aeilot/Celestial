//
//  ContentView.swift
//  CelestialPDFs
//
//  Created by Chenluo Deng on 3/4/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(BookStore.self) private var store
    @State private var selectedSidebar: SidebarItem? = .bookshelf
    @State private var searchText = ""
    @State private var openedBook: PDFBook?

    var body: some View {
        ZStack {
            if let book = openedBook {
                PDFReaderView(book: book, onClose: { openedBook = nil })
                    .environment(store)
            } else {
                NavigationSplitView {
                    SidebarView(selection: $selectedSidebar, searchText: $searchText)
                } detail: {
                    detailView
                }
                .frame(minWidth: 900, minHeight: 600)
            }

            // Loading overlay for scanning
            if store.isScanning {
                scanningOverlay
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedSidebar {
        case .bookshelf:
            BookshelfView(searchText: searchText, onOpenBook: { book in openedBook = book })
        case .notes:
            NotesListView()
        case .vocabulary:
            VocabularyView()
        case .tag(let tag):
            BookshelfView(
                searchText: searchText,
                filterTag: tag,
                onOpenBook: { book in openedBook = book }
            )
        case nil:
            BookshelfView(searchText: searchText, onOpenBook: { book in openedBook = book })
        }
    }

    // MARK: - Scanning Overlay

    private var scanningOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView(value: store.scanProgress) {
                    Text("正在扫描 PDF 目录")
                        .font(.headline)
                } currentValueLabel: {
                    Text(store.scanStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .progressViewStyle(.linear)
                .frame(width: 320)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThickMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 20)
            )
        }
        .transition(.opacity)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Environment(BookStore.self) private var store
    @Binding var selection: SidebarItem?
    @Binding var searchText: String
    @State private var showStats = false

    var body: some View {
        List(selection: $selection) {
            // Fixed Tabs
            Section {
                Label("书架", systemImage: "books.vertical")
                    .tag(SidebarItem.bookshelf)
                Label("笔记", systemImage: "note.text")
                    .tag(SidebarItem.notes)
                Label("单词本", systemImage: "character.book.closed")
                    .tag(SidebarItem.vocabulary)
            }

            // Tags
            if !store.allTags.isEmpty {
                Section("标签") {
                    ForEach(store.allTags, id: \.self) { tag in
                        Label(tag, systemImage: "tag")
                            .tag(SidebarItem.tag(tag))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: "搜索书名、作者…")
        .safeAreaInset(edge: .bottom) {
            userInfoSection
        }
        .sheet(isPresented: $showStats) {
            StatsView()
                .environment(store)
        }
    }

    private var userInfoSection: some View {
        Button(action: { showStats = true }) {
            HStack(spacing: 10) {
                // Avatar
                Group {
                    if let data = store.userAvatarData,
                       let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.userName)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("\(store.books.count) 本书 · \(store.vocabulary.count) 单词")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environment(BookStore())
}
