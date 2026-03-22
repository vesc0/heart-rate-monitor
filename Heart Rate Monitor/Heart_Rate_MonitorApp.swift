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
                .tint(.red) // Global red accent/tint for tabs, controls, etc.
        }
    }
}

