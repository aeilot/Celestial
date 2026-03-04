//
//  CelestialPDFsApp.swift
//  CelestialPDFs
//
//  Created by Chenluo Deng on 3/4/26.
//

import SwiftUI

@main
struct CelestialPDFsApp: App {
    @State private var store = BookStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
