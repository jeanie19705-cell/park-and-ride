import SwiftUI

struct ParkAnimation: View {
    private let frames = ["1", "2", "3", "4"]
    private let fps = 0.2
    @State private var frameIndex = 0

    var body: some View {
        Image(frames[frameIndex])
            .resizable()
            .scaledToFit()
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: fps, repeats: true) { _ in
                    frameIndex = (frameIndex + 1) % frames.count
                }
            }
    }
}

struct SplashView: View {
    let canDismiss: Bool
    let onFinished: () -> Void

    @State private var opacity = 1.0
    @State private var minTimeDone = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ParkAnimation()
                .padding(40)
        }
        .opacity(opacity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                minTimeDone = true
            }
        }
        .onChange(of: minTimeDone) { _, done in
            if done && canDismiss { dismiss() }
        }
        .onChange(of: canDismiss) { _, ready in
            if ready && minTimeDone { dismiss() }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) { opacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onFinished() }
    }
}
