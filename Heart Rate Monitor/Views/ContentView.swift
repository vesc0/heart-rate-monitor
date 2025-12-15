//
//  ContentView.swift
//  Heart Rate Monitor
//
//  Created by Vesco on 9/3/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = HeartRateViewModel()
    @StateObject private var auth = AuthViewModel()
    @State private var selectedTab = 2
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ManualView(vm: vm)
                .tabItem {
                    Label("Manual", systemImage: "hand.tap")
                }
                .tag(1)

            AutoView(vm: vm)
                .tabItem {
                    Label("Automatic", systemImage: "camera")
                }
                .tag(2)
            
            HistoryView(vm: vm)
                .tabItem {
                    Label("History", systemImage: "list.bullet")
                }
                .tag(3)
            
            ProfileView()
                .environmentObject(auth)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(4)
        }
    }
}

#Preview {
    ContentView()
}

