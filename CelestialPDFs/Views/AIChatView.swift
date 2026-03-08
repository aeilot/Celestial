//
//  AIChatView.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import SwiftUI
import PDFKit

struct AIChatView: View {
    @Environment(BookStore.self) private var store
    @AppStorage("useSerifFont") private var useSerifFont = false
    @State private var aiService = AIService()

    let book: PDFBook
    var selectedText: String
    var currentPage: Int
    var document: PDFDocument?
    var contextMode: ContextMode = .page

    enum ContextMode {
        case page
        case book
    }

    @State private var inputText = ""
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("AI 助手")
                    .font(.system(.headline, design: useSerifFont ? .serif : .default))
                Spacer()
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                Button(action: { aiService.clearMessages() }) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("清除对话")
            }
            .padding()

            Divider()

            // Context indicator
            if !selectedText.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "text.quote")
                        .font(.caption2)
                    Text("已选中文本将作为上下文")
                        .font(.system(.caption2, design: useSerifFont ? .serif : .default))
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.05))
            }

            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if aiService.messages.isEmpty {
                            welcomeView
                        }

                        ForEach(aiService.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: aiService.messages.count) {
                    if let last = aiService.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            // Error
            if let error = aiService.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.system(.caption, design: useSerifFont ? .serif : .default))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }

            Divider()

            // Input area
            inputArea
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(.purple.opacity(0.6))
            Text("有什么想问的？")
                .font(.system(.callout, design: useSerifFont ? .serif : .default))
                .foregroundStyle(.secondary)
            Text("选中 PDF 中的文字可以作为上下文提问")
                .font(.system(.caption, design: useSerifFont ? .serif : .default))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Message Bubble

    private func messageBubble(_ message: AIMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.purple)
                    .padding(.top, 4)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content.isEmpty && aiService.isLoading ? "思考中…" : message.content)
                    .font(.system(.callout, design: useSerifFont ? .serif : .default))
                    .textSelection(.enabled)
                    .padding(10)
                    .background(
                        message.role == .user
                            ? Color.accentColor.opacity(0.12)
                            : Color(nsColor: .textBackgroundColor)
                    )
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.03), radius: 1, y: 1)
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        }
    }

    // MARK: - Input

    private var inputArea: some View {
        HStack(spacing: 8) {
            TextField("输入问题…", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .onSubmit {
                    if !inputText.isEmpty && !aiService.isLoading {
                        sendMessage()
                    }
                }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespaces).isEmpty || aiService.isLoading
                            ? Color.secondary
                            : Color.accentColor
                    )
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || aiService.isLoading)
        }
        .padding(12)
        .background(.bar)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""

        // Build context from selected text, current page, or whole book
        var context = ""
        if !selectedText.isEmpty {
            context = "用户选中的文字：\n\(selectedText)"
        } else if contextMode == .book, let document {
            context = wholeBookContext(from: document)
        } else if let document = document,
                  let page = document.page(at: currentPage),
                  let pageText = page.string {
            let truncated = String(pageText.prefix(2000))
            context = "当前页面（第\(currentPage + 1)页）内容：\n\(truncated)"
        }

        Task {
            await aiService.sendMessage(text, context: context.isEmpty ? nil : context)
        }
    }

    private func wholeBookContext(from document: PDFDocument) -> String {
        let maxCharacters = 6000
        var collected = ""

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex),
                  let text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                continue
            }

            let block = "第\(pageIndex + 1)页：\n\(text)\n\n"
            if collected.count + block.count >= maxCharacters {
                let remaining = max(0, maxCharacters - collected.count)
                if remaining > 0 {
                    collected += String(block.prefix(remaining))
                }
                break
            }
            collected += block
        }

        if collected.isEmpty {
            return ""
        }
        return "全书内容摘录：\n\(collected)"
    }
}
