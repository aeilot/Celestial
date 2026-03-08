//
//  BookDetailSheet.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import SwiftUI

struct BookDetailSheet: View {
    @Environment(BookStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let book: PDFBook
    @State private var title: String = ""
    @State private var author: String = ""
    @State private var tags: [String] = []
    @State private var newTag: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("编辑书籍信息")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            Form {
                TextField("标题", text: $title)
                TextField("作者", text: $author)

                VStack(alignment: .leading, spacing: 8) {
                    Text("标签")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.caption)
                                Button(action: { removeTag(tag) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.2))
                            .clipShape(Capsule())
                        }
                    }

                    TextField("添加标签", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addTag()
                        }
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Actions
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 420)
        .onAppear {
            title = book.title
            author = book.author
            tags = book.tags
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            tags.append(trimmed)
            newTag = ""
        }
    }

    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    private func save() {
        var updated = book
        updated.title = title.trimmingCharacters(in: .whitespaces)
        updated.author = author.trimmingCharacters(in: .whitespaces)
        updated.tags = tags
        store.updateBook(updated)
        dismiss()
    }
}
