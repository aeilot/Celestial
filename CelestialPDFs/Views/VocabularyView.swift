//
//  VocabularyView.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import SwiftUI

struct VocabularyView: View {
    @Environment(BookStore.self) private var store
    @State private var searchWord = ""

    private var filteredVocabulary: [VocabularyEntry] {
        let vocab = store.vocabulary
        if searchWord.isEmpty {
            return vocab.sorted { $0.dateAdded > $1.dateAdded }
        }
        return vocab.filter {
            $0.word.localizedCaseInsensitiveContains(searchWord)
        }.sorted { $0.dateAdded > $1.dateAdded }
    }

    var body: some View {
        Group {
            if store.vocabulary.isEmpty {
                emptyView
            } else {
                vocabularyList
            }
        }
        .navigationTitle("单词本")
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索单词…", text: $searchWord)
                .textFieldStyle(.plain)
            if !searchWord.isEmpty {
                Button(action: { searchWord = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var vocabularyList: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            List {
            ForEach(filteredVocabulary) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(entry.word)
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                        Spacer()
                        if let bookTitle = entry.bookTitle, !bookTitle.isEmpty {
                            Text(bookTitle)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }

                    if !entry.definition.isEmpty {
                        Text(entry.definition)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    HStack {
                        if let page = entry.pageIndex {
                            Text("第 \(page + 1) 页")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text(entry.dateAdded, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
                .contextMenu {
                    Button("删除", role: .destructive) {
                        store.removeVocabulary(entry)
                    }
                }
            }
        }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("单词本为空")
                .font(.title3)
                .fontWeight(.medium)
            Text("在阅读 PDF 时选中单词查词，将自动记录到此处")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
