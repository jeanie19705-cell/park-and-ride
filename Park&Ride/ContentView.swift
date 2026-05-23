import SwiftUI

struct ContentView: View {
    @State private var viewModel = ParkingViewModel()
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
                    ParkMapView(carParks: viewModel.carParks)
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
        .task {
            viewModel.startAutoRefresh()
            await NotificationService.registerForPushNotifications()
        }
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var refreshStatus: some View {
        if viewModel.isLoading {
            ProgressView()
                .scaleEffect(0.8)
                .allowsHitTesting(false)
        } else if viewModel.lastUpdated != nil {
            Text("↻ \(viewModel.secondsUntilRefresh)s")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .fixedSize()
                .allowsHitTesting(false)
        }
    }
}

#Preview {
    ContentView()
}
