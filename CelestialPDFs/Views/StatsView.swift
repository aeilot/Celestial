//
//  StatsView.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct StatsView: View {
    @Environment(BookStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("useSerifFont") private var useSerifFont = false
    @State private var editingName = false
    @State private var nameInput = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(LocalizedStringKey("个人统计"))
                    .font(.system(.headline, design: useSerifFont ? .serif : .default))
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

            ScrollView {
                VStack(spacing: 24) {
                    // Avatar & Name
                    avatarSection

                    Divider()

                    // Stats Grid
                    statsGrid

                    Divider()

                    // Recent Books
                    recentBooksSection
                }
                .padding(24)
            }
        }
        .frame(width: 480, height: 520)
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(spacing: 12) {
            // Avatar
            Button(action: pickAvatar) {
                Group {
                    if let data = store.userAvatarData,
                       let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 2)
                )
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white, Color.accentColor)
                        .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.plain)

            // Name
            if editingName {
                HStack {
                    TextField(LocalizedStringKey("你的名字"), text: $nameInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .onSubmit {
                            store.userName = nameInput
                            editingName = false
                        }
                    Button(LocalizedStringKey("保存")) {
                        store.userName = nameInput
                        editingName = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            } else {
                Button(action: {
                    nameInput = store.userName
                    editingName = true
                }) {
                    HStack(spacing: 4) {
                        Text(store.userName)
                            .font(.system(.title3, design: useSerifFont ? .serif : .default))
                            .fontWeight(.semibold)
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            statCard(title: LocalizedStringKey("书架"), value: "\(store.books.count)", icon: "book.closed", color: .blue)
            statCard(title: LocalizedStringKey("高亮"), value: "\(store.totalHighlights)", icon: "highlighter", color: .yellow)
            statCard(title: LocalizedStringKey("笔记"), value: "\(store.totalNotes)", icon: "note.text", color: .green)
            statCard(title: LocalizedStringKey("单词本"), value: "\(store.vocabulary.count)", icon: "character.book.closed", color: .purple)
        }
    }

    private func statCard(title: LocalizedStringKey, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: useSerifFont ? .serif : .rounded))
            Text(title)
                .font(.system(.caption, design: useSerifFont ? .serif : .default))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - Recent Books

    private var recentBooksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("最近阅读"))
                .font(.system(.subheadline, design: useSerifFont ? .serif : .default))
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if store.recentBooks.isEmpty {
                Text(LocalizedStringKey("暂无阅读记录"))
                    .font(.system(.callout, design: useSerifFont ? .serif : .default))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(store.recentBooks) { book in
                    HStack(spacing: 10) {
                        Image(systemName: "book.closed.fill")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.title)
                                .font(.system(.callout, design: useSerifFont ? .serif : .default))
                                .lineLimit(1)
                            if let date = book.lastOpened {
                                Text(date, style: .relative)
                                    .font(.system(.caption2, design: useSerifFont ? .serif : .default))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Avatar Picker

    private func pickAvatar() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.message = String(localized: "stats.avatarPicker.message")

        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url) {
                store.userAvatarData = data
            }
        }
    }
}
