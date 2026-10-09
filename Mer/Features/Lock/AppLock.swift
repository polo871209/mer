import LocalAuthentication
import SwiftUI
import UIKit

struct AppLockModifier: ViewModifier {
    @AppStorage(DefaultsKey.lockEnabled) private var lockEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked = UserDefaults.standard.bool(forKey: DefaultsKey.lockEnabled)
    @State private var unlockOnActive = false

    func body(content: Content) -> some View {
        content
            .background {
                LockCover(
                    isCovered: lockEnabled && (isLocked || scenePhase != .active),
                    screen: LockScreen(isLocked: isLocked) { Task { await unlock() } }
                )
            }
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
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            isLocked = false
            return
        }
        let reason = String(localized: "Unlock your money notes.")
        if (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) == true {
            isLocked = false
        }
    }
}

// The lock screen gets its own window, because sheets present above any overlay in the app's window.
private struct LockCover: UIViewRepresentable {
    let isCovered: Bool
    let screen: LockScreen

    func makeUIView(context: Context) -> CoverAnchor { CoverAnchor() }

    func updateUIView(_ anchor: CoverAnchor, context: Context) {
        anchor.screen = screen
        anchor.isCovered = isCovered
    }
}

private final class CoverAnchor: UIView {
    private var cover: UIWindow?
    private var host: UIHostingController<LockScreen>?

    var screen: LockScreen? {
        didSet { if let screen { host?.rootView = screen } }
    }

    var isCovered = false {
        didSet { sync() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        sync()
    }

    private func sync() {
        if isCovered, cover == nil, let screen, let scene = window?.windowScene {
            let host = UIHostingController(rootView: screen)
            host.view.accessibilityViewIsModal = true
            let cover = UIWindow(windowScene: scene)
            cover.windowLevel = .alert + 1
            cover.rootViewController = host
            cover.makeKeyAndVisible()
            self.cover = cover
            self.host = host
        } else if !isCovered, let cover {
            self.cover = nil
            host = nil
            UIView.animate(withDuration: 0.2) {
                cover.alpha = 0
            } completion: { _ in
                cover.isHidden = true
                self.window?.makeKey()
            }
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
