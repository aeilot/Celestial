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

        // Try streaming first, fallback to non-streaming
        do {
            try await sendStreamingRequest(apiMessages: apiMessages, assistantIndex: assistantIndex)
        } catch {
            // If streaming failed and we got no content, try non-streaming
            if messages[assistantIndex].content.isEmpty {
                do {
                    try await sendNonStreamingRequest(apiMessages: apiMessages, assistantIndex: assistantIndex)
                } catch {
                    errorMessage = "请求失败：\(error.localizedDescription)"
                }
            }
        }

        isLoading = false
    }

    // MARK: - Streaming Request

    private func sendStreamingRequest(apiMessages: [[String: String]], assistantIndex: Int) async throws {
        let (request, _) = try buildRequest(apiMessages: apiMessages, stream: true)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            // Collect error body from stream
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
                if errorBody.count > 1000 { break }
            }
            let detail = parseAPIError(from: errorBody, statusCode: httpResponse.statusCode)
            throw AIError.apiError(detail)
        }

        var fullContent = ""

        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("data: ") else { continue }
            let jsonStr = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            if jsonStr == "[DONE]" { break }
            if jsonStr.isEmpty { continue }

            guard let data = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else { continue }

            fullContent += content
            messages[assistantIndex].content = fullContent
        }

        if fullContent.isEmpty {
            throw AIError.emptyResponse
        }
    }

    // MARK: - Non-Streaming Fallback

    private func sendNonStreamingRequest(apiMessages: [[String: String]], assistantIndex: Int) async throws {
        let (request, _) = try buildRequest(apiMessages: apiMessages, stream: false)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            let detail = parseAPIError(from: body, statusCode: httpResponse.statusCode)
            throw AIError.apiError(detail)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.parseError
        }

        messages[assistantIndex].content = content
    }

    // MARK: - Helpers

    private func buildRequest(apiMessages: [[String: String]], stream: Bool) throws -> (URLRequest, URL) {
        let endpoint = AISettings.endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(endpoint)/chat/completions") else {
            errorMessage = "无效的 API Endpoint"
            throw AIError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(AISettings.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": AISettings.modelName,
            "messages": apiMessages,
            "stream": stream
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return (request, url)
    }

    private func parseAPIError(from body: String, statusCode: Int) -> String {
        // Try to extract error message from JSON response
        if let data = body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return "API 错误 (\(statusCode)): \(message)"
        }
        return "API 错误：HTTP \(statusCode)"
    }

    func clearMessages() {
        messages.removeAll()
        errorMessage = nil
    }
}

// MARK: - AI Errors

enum AIError: LocalizedError {
    case invalidEndpoint
    case invalidResponse
    case apiError(String)
    case emptyResponse
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "无效的 API Endpoint"
        case .invalidResponse:
            return "无效的服务器响应"
        case .apiError(let detail):
            return detail
        case .emptyResponse:
            return "服务器返回了空响应"
        case .parseError:
            return "无法解析服务器响应"
        }
    }
}
