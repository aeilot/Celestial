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
}

// MARK: - Sidebar

struct SidebarView: View {
    @Environment(BookStore.self) private var store
    @Binding var selection: SidebarItem?
    @Binding var searchText: String

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
    }

    private var userInfoSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(store.books.count) 本书")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("\(store.vocabulary.count) 个单词")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

#Preview {
    ContentView()
        .environment(BookStore())
}
