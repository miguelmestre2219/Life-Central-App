import SwiftUI
import LocalAuthentication

enum FaceID {
    /// Asks for Face ID (or the passcode if Face ID fails).
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode set on the phone: nothing to check against.
            return true
        }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}

/// Covers the app until Face ID succeeds, when "Face ID to open the app" is on.
struct LockScreen: View {
    @Binding var isUnlocked: Bool

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("Life Central is locked").font(.title3.weight(.semibold))
                Button("Unlock") { unlock() }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
            }
        }
        .task { unlock() }
    }

    private func unlock() {
        Task {
            if await FaceID.authenticate(reason: "Unlock Life Central") {
                isUnlocked = true
            }
        }
    }
}
