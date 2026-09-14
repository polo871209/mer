import LocalAuthentication
import SwiftUI

enum AppLock {
    static var canAuthenticate: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }
}

struct AppLockModifier: ViewModifier {
    @AppStorage(DefaultsKey.lockEnabled) private var lockEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked = UserDefaults.standard.bool(forKey: DefaultsKey.lockEnabled)
    @State private var unlockOnActive = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if lockEnabled && (isLocked || scenePhase != .active) {
                    LockScreen(isLocked: isLocked) { Task { await unlock() } }
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isLocked)
            .task {
                if isLocked { await unlock() }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background where lockEnabled:
                    isLocked = true
                    unlockOnActive = true
                // Only prompt after a real return from background. The Face ID sheet itself makes the scene
                // inactive, so prompting on every `.active` would loop after a cancel.
                case .active where unlockOnActive:
                    unlockOnActive = false
                    Task { await unlock() }
                default:
                    break
                }
            }
    }

    private func unlock() async {
        guard isLocked else { return }
        let reason = String(localized: "Unlock your money notes.")
        if (try? await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) == true {
            isLocked = false
        }
    }
}

private struct LockScreen: View {
    let isLocked: Bool
    let unlock: () -> Void

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 24) {
                Image(.merArt)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240)
                    .clipShape(SketchyRect(cornerRadius: 24, wobble: 2, seed: 30))
                    .overlay {
                        SketchyRect(cornerRadius: 24, wobble: 2, seed: 30)
                            .stroke(Palette.ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                    .accessibilityHidden(true)
                Text("Mer is guarding your money")
                    .font(.crayon(22, relativeTo: .title2))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                if isLocked {
                    Button("Unlock", systemImage: "faceid", action: unlock)
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                }
            }
            .padding()
        }
    }
}
