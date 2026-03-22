import SwiftUI
import AVFoundation

struct WelcomeView: View {
    let onContinue: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var isRequestingPermission = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.07, blue: 0.07), Color(red: 0.26, green: 0.05, blue: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer(minLength: 12)

                Text("Heart Rate Monitor")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Measure your heart rate and estimate stress with camera-based sessions.")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Quick daily heart checks", systemImage: "heart.fill")
                    Label("Monthly stats for heart rate and stress", systemImage: "chart.line.uptrend.xyaxis")
                    Label("AI stress estimation", systemImage: "brain.head.profile")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Important")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("This app is for educational and fitness purposes only. It is not a medical device and must not be used for diagnosis or treatment.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(spacing: 10) {
                    if cameraStatus == .authorized {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Camera Access Enabled")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    } else {
                        Button {
                            if cameraStatus == .denied || cameraStatus == .restricted {
                                openAppSettings()
                            } else {
                                requestCameraPermissionIfNeeded()
                            }
                        } label: {
                            HStack {
                                if isRequestingPermission {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text(cameraButtonTitle)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(isRequestingPermission)
                    }

                    Button("Continue") {
                        onContinue()
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundColor(.red)
                }

                Spacer()
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(20)
        }
        .onAppear {
            cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            if cameraStatus == .notDetermined {
                requestCameraPermissionIfNeeded()
            }
        }
    }

    private var cameraButtonTitle: String {
        switch cameraStatus {
        case .authorized: return "Camera Access Enabled"
        case .denied, .restricted: return "Open Settings for Camera"
        case .notDetermined: return "Enable Camera Access"
        @unknown default: return "Camera Permission"
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: "app-settings:") else { return }
        openURL(url)
    }

    private func requestCameraPermissionIfNeeded() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        cameraStatus = status
        guard status == .notDetermined else { return }

        isRequestingPermission = true
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                isRequestingPermission = false
                cameraStatus = granted ? .authorized : .denied
            }
        }
    }
}
