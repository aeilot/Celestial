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
    @State private var filteredVocabulary: [VocabularyEntry] = []

    private func updateFilteredVocabulary() {
        Task {
            let vocab = store.vocabulary
            let filtered: [VocabularyEntry]
            if searchWord.isEmpty {
                filtered = vocab.sorted { $0.dateAdded > $1.dateAdded }
            } else {
                filtered = vocab.filter {
                    $0.word.localizedCaseInsensitiveContains(searchWord)
                }.sorted { $0.dateAdded > $1.dateAdded }
            }
            await MainActor.run {
                filteredVocabulary = filtered
            }
        }
    }

    var body: some View {
        Group {
            if store.vocabulary.isEmpty {
                emptyView
            } else {
                vocabularyList
            }
        }
        .navigationTitle(LocalizedStringKey("vocabulary.title"))
        .onAppear {
            updateFilteredVocabulary()
        }
        .onChange(of: searchWord) {
            updateFilteredVocabulary()
        }
        .onChange(of: store.vocabulary.count) {
            updateFilteredVocabulary()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(LocalizedStringKey("vocabulary.search"), text: $searchWord)
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
                            Text(String(format: NSLocalizedString("vocabulary.page", comment: ""), page + 1))
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
                    Button(LocalizedStringKey("vocabulary.delete"), role: .destructive) {
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
            Text(LocalizedStringKey("vocabulary.empty.title"))
                .font(.title3)
                .fontWeight(.medium)
            Text(LocalizedStringKey("vocabulary.empty.hint"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
