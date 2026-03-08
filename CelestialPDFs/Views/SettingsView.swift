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
    @AppStorage("useSerifFont") private var useSerifFont = false
    @AppStorage("readerToolbarShowsLabels") private var readerToolbarShowsLabels = true

    var body: some View {
        TabView {
            aiSettingsTab
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }

            appearanceTab
                .tabItem {
                    Label("外观", systemImage: "paintbrush")
                }

            readingTab
                .tabItem {
                    Label("阅读", systemImage: "book")
                }
        }
        .frame(width: 500, height: 350)
        .onDisappear {
            AISettings.endpoint = endpoint
            AISettings.apiKey = apiKey
            AISettings.modelName = modelName
        }
    }

    private var aiSettingsTab: some View {
        Form {
            Section("AI 服务配置") {
                TextField("API Endpoint", text: $endpoint)
                    .textFieldStyle(.roundedBorder)

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
            }
        }
        .formStyle(.grouped)
    }

    private var appearanceTab: some View {
        Form {
            Section("字体") {
                Toggle("使用衬线字体", isOn: $useSerifFont)
            }
        }
        .formStyle(.grouped)
    }

    private var readingTab: some View {
        Form {
            Section("工具栏") {
                Toggle("工具栏显示文字", isOn: $readerToolbarShowsLabels)
            }
        }
        .formStyle(.grouped)
    }
}
