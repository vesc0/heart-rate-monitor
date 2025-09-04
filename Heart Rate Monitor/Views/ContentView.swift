//
//  ContentView.swift
//  Heart Rate Monitor
//
//  Created by Vesco on 9/3/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = HeartRateViewModel()
    
    var body: some View {
        TabView {
            ManualView(vm: vm)
                .tabItem {
                    Label("Manual", systemImage: "hand.tap")
                }

            AutoView(vm: vm)
                .tabItem {
                    Label("Automatic", systemImage: "camera")
                }

            HistoryView(vm: vm)
                .tabItem {
                    Label("History", systemImage: "list.bullet")
                }
        }
    }
}

#Preview {
    ContentView()
}
