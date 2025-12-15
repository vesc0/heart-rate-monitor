import SwiftUI

struct HeartTimerView: View {
    let heartScale: CGFloat
    let secondsLeft: Int
    let totalSeconds: Int
    // Bigger default size
    var heartSize: CGFloat = 160
    let color: Color
    
    // Bigger gap and thicker ring for balance
    private let ringInset: CGFloat = 72   // was 48
    private let ringLineWidth: CGFloat = 14 // was 12
    
    private var progress: CGFloat {
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(max(0, min(1, Double(secondsLeft) / Double(totalSeconds))))
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.15), style: StrokeStyle(lineWidth: ringLineWidth))
                .frame(width: heartSize + ringInset, height: heartSize + ringInset)
            
            // Foreground countdown ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: heartSize + ringInset, height: heartSize + ringInset)
                .animation(.easeInOut(duration: 0.25), value: progress)
            
            // Heart
            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .frame(width: heartSize, height: heartSize)
                .foregroundColor(.red)
                .scaleEffect(heartScale)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        HeartTimerView(heartScale: 1.0, secondsLeft: 7, totalSeconds: 12, heartSize: 160, color: .red)
        HeartTimerView(heartScale: 1.2, secondsLeft: 3, totalSeconds: 10, heartSize: 160, color: .blue)
    }
    .padding()
}
