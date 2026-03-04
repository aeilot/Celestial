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
    @State private var tagsText: String = ""

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
                TextField("标签（逗号分隔）", text: $tagsText)
                    .help("多个标签用英文逗号分隔，例如：编程, Swift, macOS")
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
            tagsText = book.tags.joined(separator: ", ")
        }
    }

    private func save() {
        var updated = book
        updated.title = title.trimmingCharacters(in: .whitespaces)
        updated.author = author.trimmingCharacters(in: .whitespaces)
        updated.tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        store.updateBook(updated)
        dismiss()
    }
}
