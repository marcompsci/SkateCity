// SkateCityApp.swift
// SkateCity — App entry point.
//
// Copyright © 2026 MAR / SkateCity. All rights reserved.
// Unauthorized reproduction, distribution, reverse engineering, or modification
// of this software or any portion thereof is strictly prohibited.
// Protected under U.S. and international copyright law.

import SwiftUI
import SwiftData

/// Global physics category bitmask used by GameEngine + World.
let solidCategory: Int = 2

@main
struct SkateCityApp: App {
    @StateObject private var model       = GameModel()
    @StateObject private var cloudKit    = CloudKitManager.shared

    init() {
        // Run integrity checks at cold launch.
        // strict: false in DEBUG so development builds aren't killed.
        #if DEBUG
        AppSecurityManager.shared.enforce(strict: false)
        #else
        AppSecurityManager.shared.enforce(strict: true)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .environmentObject(cloudKit)
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
                .task {
                    // Check iCloud account status in the background on launch.
                    await cloudKit.checkAccountStatus()
                }
        }
        .modelContainer(for: [PlayerProfile.self, SkateComboRecord.self])
    }
}
