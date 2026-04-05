import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

struct SettingsView: View {
    @ObservedObject var vm: HeartRateViewModel
    @AppStorage("appTheme") private var appThemeRawValue: String = AppTheme.system.rawValue
    @State private var isExportingHistory = false
    @State private var healthExportMessage = ""
    @State private var showHealthExportAlert = false
    @State private var showExportConfirmAlert = false

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Theme", selection: $appThemeRawValue) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Apple Health") {
                    Toggle(isOn: Binding(
                        get: { vm.isAppleHealthSyncEnabled },
                        set: { vm.setAppleHealthSyncEnabled($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Save New Measurements")
                            Text("When enabled, each new BPM result is written to Apple Health.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.red)

                    Button {
                        if vm.log.isEmpty {
                            exportHistoryToAppleHealth()
                        } else {
                            showExportConfirmAlert = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if isExportingHistory {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.red)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Sync Past History")
                                    .foregroundColor(.primary)
                                Text("Export your existing records to Apple Health.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if !isExportingHistory {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isExportingHistory)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Export History?", isPresented: $showExportConfirmAlert) {
                Button("No", role: .cancel) {}
                Button("Yes") {
                    exportHistoryToAppleHealth()
                }
            } message: {
                Text("This will export \(vm.log.count) records to Apple Health. Are you sure?")
            }
            .alert("Apple Health Sync", isPresented: $showHealthExportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(healthExportMessage)
            }
        }
    }

    private func exportHistoryToAppleHealth() {
        guard !isExportingHistory else { return }
        isExportingHistory = true

        Task {
            let result = await vm.exportHistoryToAppleHealth()
            let message: String

            if result.totalCount == 0 {
                message = "No measurements found to export."
            } else if result.exportedCount == result.totalCount {
                message = "Export completed. Synced \(result.exportedCount) measurements to Apple Health."
            } else if result.exportedCount == 0 {
                message = "Export could not be completed. Please allow Apple Health access and try again."
            } else {
                message = "Partial export: \(result.exportedCount) synced, \(result.failedCount) failed."
            }

            await MainActor.run {
                healthExportMessage = message
                showHealthExportAlert = true
                isExportingHistory = false
            }
        }
    }
}
