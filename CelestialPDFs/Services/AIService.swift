//
//  AIService.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import Foundation

// MARK: - AI Message

struct AIMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date

    enum Role: String, Codable {
        case system
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - AI Settings

struct AISettings {
    static var endpoint: String {
        get { UserDefaults.standard.string(forKey: "ai_endpoint") ?? "https://api.openai.com/v1" }
        set { UserDefaults.standard.set(newValue, forKey: "ai_endpoint") }
    }
    static var apiKey: String {
        get { UserDefaults.standard.string(forKey: "ai_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "ai_api_key") }
    }
    static var modelName: String {
        get { UserDefaults.standard.string(forKey: "ai_model") ?? "gpt-4o-mini" }
        set { UserDefaults.standard.set(newValue, forKey: "ai_model") }
    }
}

import Observation

// MARK: - AI Service

@Observable
class AIService {
    var messages: [AIMessage] = []
    var isLoading = false
    var errorMessage: String?

    func sendMessage(_ userMessage: String, context: String? = nil) async {
        guard !AISettings.apiKey.isEmpty else {
            errorMessage = "请在设置中配置 API Key"
            return
        }

        // Build messages
        var apiMessages: [[String: String]] = []

        // System prompt
        var systemContent = "你是一个 PDF 阅读助手。帮助用户理解文档内容、解答问题、总结段落。请使用中文回答。"
        if let context = context, !context.isEmpty {
            systemContent += "\n\n以下是用户当前正在阅读的内容：\n\(context)"
        }
        apiMessages.append(["role": "system", "content": systemContent])

        // Conversation history (last 10 messages)
        let recent = messages.suffix(10)
        for msg in recent {
            apiMessages.append(["role": msg.role.rawValue, "content": msg.content])
        }

        // Add new user message
        let userMsg = AIMessage(role: .user, content: userMessage)
        messages.append(userMsg)
        apiMessages.append(["role": "user", "content": userMessage])

        // Placeholder for assistant response
        let assistantMsg = AIMessage(role: .assistant, content: "")
        messages.append(assistantMsg)
        let assistantIndex = messages.count - 1

        isLoading = true
        errorMessage = nil

        do {
            let endpoint = AISettings.endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let url = URL(string: "\(endpoint)/chat/completions") else {
                errorMessage = "无效的 API Endpoint"
                isLoading = false
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(AISettings.apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "model": AISettings.modelName,
                "messages": apiMessages,
                "stream": true
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            // Stream response using URLSession bytes
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "无效的服务器响应"
                isLoading = false
                return
            }

            guard httpResponse.statusCode == 200 else {
                errorMessage = "API 错误：HTTP \(httpResponse.statusCode)"
                isLoading = false
                return
            }

            var fullContent = ""

            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let jsonStr = String(line.dropFirst(6))
                if jsonStr == "[DONE]" { break }

                guard let data = jsonStr.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let delta = choices.first?["delta"] as? [String: Any],
                      let content = delta["content"] as? String else { continue }

                fullContent += content
                messages[assistantIndex].content = fullContent
            }

        } catch {
            errorMessage = "请求失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    func clearMessages() {
        messages.removeAll()
        errorMessage = nil
    }
}
