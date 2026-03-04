//
//  SettingsView.swift
//  CelestialPDFs
//
//  Created by CelestialPDFs on 3/4/26.
//

import SwiftUI

struct SettingsView: View {
    @State private var endpoint: String = AISettings.endpoint
    @State private var apiKey: String = AISettings.apiKey
    @State private var modelName: String = AISettings.modelName
    @State private var showKey = false

    var body: some View {
        Form {
            Section("AI 服务配置") {
                TextField("API Endpoint", text: $endpoint)
                    .textFieldStyle(.roundedBorder)
                    .help("OpenAI 兼容接口地址，例如 https://api.openai.com/v1")

                HStack {
                    if showKey {
                        TextField("API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(action: { showKey.toggle() }) {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }

                TextField("模型名称", text: $modelName)
                    .textFieldStyle(.roundedBorder)
                    .help("例如 gpt-4o-mini, deepseek-chat, moonshot-v1-8k")
            }

            Section {
                Text("支持任何 OpenAI 兼容 API（DeepSeek、Moonshot、Ollama 等）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 280)
        .onDisappear {
            AISettings.endpoint = endpoint
            AISettings.apiKey = apiKey
            AISettings.modelName = modelName
        }
    }
}
