import SwiftUI

// MARK: - In-Call Full-Screen View

struct InCallView: View {
    @EnvironmentObject var callManager: CallManager
    var onMinimize: () -> Void

    @State private var elapsed: Int = 0
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(white: 0.13), Color(white: 0.07)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Minimize chevron
                HStack {
                    Spacer()
                    Button(action: onMinimize) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding()
                    }
                }

                Spacer()

                // Caller info
                Text(callManager.activeCallerName)
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.white)

                Text(elapsedString)
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
                    .padding(.top, 6)

                Spacer()

                // Fake action buttons (visual only — it is a fake call)
                HStack(spacing: 40) {
                    fakeButton(icon: "mic.slash.fill",           label: "Mute")
                    fakeButton(icon: "square.grid.3x3.fill",     label: "Keypad")
                    fakeButton(icon: "speaker.wave.3.fill",      label: "Speaker")
                }
                .padding(.bottom, 28)

                HStack(spacing: 40) {
                    fakeButton(icon: "phone.badge.plus",         label: "Add Call")
                    fakeButton(icon: "video.fill",               label: "FaceTime")
                    fakeButton(icon: "person.crop.circle",       label: "Contacts")
                }
                .padding(.bottom, 48)

                // End Call
                Button(action: callManager.endCall) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                        .frame(width: 76, height: 76)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .padding(.bottom, 60)
            }
        }
        .onReceive(ticker) { _ in
            guard callManager.isCallActive, let start = callManager.callStartTime else { return }
            elapsed = Int(Date().timeIntervalSince(start))
        }
        .onChange(of: callManager.isCallActive) { _, active in
            if !active { onMinimize() }
        }
    }

    private var elapsedString: String {
        String(format: "%d:%02d", elapsed / 60, elapsed % 60)
    }

    private func fakeButton(icon: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(.white.opacity(0.15))
                .clipShape(Circle())
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

// MARK: - In-Call Floating Banner (shown when InCallView is minimized)

struct InCallBanner: View {
    @EnvironmentObject var callManager: CallManager
    var onTap: () -> Void

    @State private var elapsed: Int = 0
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            // Green pulsing dot
            Circle()
                .fill(Color.green)
                .frame(width: 10, height: 10)

            Text(callManager.activeCallerName)
                .font(.subheadline.weight(.semibold))
            Text(elapsedString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer()

            Button(action: callManager.endCall) {
                Text("End")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onReceive(ticker) { _ in
            guard callManager.isCallActive, let start = callManager.callStartTime else { return }
            elapsed = Int(Date().timeIntervalSince(start))
        }
    }

    private var elapsedString: String {
        String(format: "%d:%02d", elapsed / 60, elapsed % 60)
    }
}
