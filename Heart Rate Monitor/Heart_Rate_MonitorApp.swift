//
//  Heart_Rate_MonitorApp.swift
//  Heart Rate Monitor
//
//  Created by Vesco on 9/1/25.
//

import SwiftUI

@main
struct Heart_Rate_MonitorApp: App {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("appTheme") private var appThemeRawValue: String = AppTheme.system.rawValue

    private var appTheme: AppTheme {
        AppTheme(rawValue: appThemeRawValue) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasSeenWelcome {
                    ContentView()
                } else {
                    WelcomeView {
                        hasSeenWelcome = true
                    }
                }
            }
            .tint(.red)
            .preferredColorScheme(appTheme.colorScheme)
        }
    }
}

