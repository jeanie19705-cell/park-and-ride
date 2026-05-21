import SwiftUI

struct ContentView: View {
    @State private var viewModel = ParkingViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            CarParkListView(viewModel: viewModel)
                .navigationTitle("Park & Ride")
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onChange(of: showSettings) { _, isPresented in
            if !isPresented {
                viewModel.startAutoRefresh()
            }
        }
        .task {
            let hasKey = !(UserDefaults.standard.string(forKey: "tfnsw_api_key") ?? "").isEmpty
            if hasKey {
                viewModel.startAutoRefresh()
            } else {
                showSettings = true
            }
        }
    }

    @ViewBuilder
    private var refreshStatus: some View {
        if viewModel.isLoading {
            ProgressView()
                .scaleEffect(0.8)
        } else if viewModel.lastUpdated != nil {
            Text("↻ in \(viewModel.secondsUntilRefresh)s")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

#Preview {
    ContentView()
}
