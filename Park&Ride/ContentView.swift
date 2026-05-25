import SwiftUI

struct ContentView: View {
    let viewModel: ParkingViewModel
    @State private var showSettings = false

    var body: some View {
        TabView {
            Tab("Car Parks", systemImage: "list.bullet") {
                NavigationStack {
                    CarParkListView(viewModel: viewModel)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button { showSettings = true } label: {
                                    Image(systemName: "gearshape")
                                }
                            }
                            ToolbarItem(placement: .topBarLeading) {
                                refreshStatus
                            }
                        }
                }
            }

            Tab("Map", systemImage: "map") {
                NavigationStack {
                    ParkMapView(viewModel: viewModel)
                        .navigationTitle("Map")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button { showSettings = true } label: {
                                    Image(systemName: "gearshape")
                                }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onChange(of: showSettings) { _, isPresented in
            if !isPresented { Task { await viewModel.refresh() } }
        }

    }

    @ViewBuilder
    private var refreshStatus: some View {
        if viewModel.isLoading {
            ProgressView()
                .scaleEffect(0.8)
        } else if viewModel.lastUpdated != nil {
            Button { viewModel.startAutoRefresh() } label: {
                Text("↻ \(viewModel.secondsUntilRefresh)s")
                    .font(.caption2)
                    .monospacedDigit()
                    .fixedSize()
            }
        }
    }
}

func applyColorScheme(_ scheme: String) {
    let style: UIUserInterfaceStyle = scheme == "dark" ? .dark : scheme == "light" ? .light : .unspecified
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .forEach { window in
            window.overrideUserInterfaceStyle = style
            applyStyle(style, to: window.rootViewController)
        }
}

private func applyStyle(_ style: UIUserInterfaceStyle, to vc: UIViewController?) {
    guard let vc else { return }
    vc.overrideUserInterfaceStyle = style
    vc.children.forEach { applyStyle(style, to: $0) }
    if let presented = vc.presentedViewController { applyStyle(style, to: presented) }
}

#Preview {
    ContentView(viewModel: ParkingViewModel())
}
