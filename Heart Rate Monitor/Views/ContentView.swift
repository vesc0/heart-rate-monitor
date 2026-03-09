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
    @State private var selectedTab = 1
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MeasurementView(vm: vm)
                .tabItem {
                    Label("Measure", systemImage: "heart.fill")
                }
                .tag(1)

            StressView(vm: vm)
                .tabItem {
                    Label("Stress", systemImage: "brain.head.profile")
                }
                .tag(2)

            HistoryView(vm: vm)
                .tabItem {
                    Label("History", systemImage: "list.bullet")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(4)
        }
        .environmentObject(auth)
        // Sync heart-rate data when auth state changes
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                vm.refreshFromServer()
            } else {
                vm.clearForLogout()
            }
        }
    }
}

#Preview {
    ContentView()
}

