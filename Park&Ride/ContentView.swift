import SwiftUI

struct ContentView: View {
    @State private var viewModel = ParkingViewModel()
    @State private var showSettings = false
    @AppStorage("app_color_scheme") private var colorSchemePreference = "system"

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        TabView {
            Tab("Car Parks", systemImage: "list.bullet") {
                NavigationStack {
                    CarParkListView(viewModel: viewModel)
                        .navigationTitle("Park & Ride")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button { showSettings = true } label: {
                                    Image(systemName: "gearshape")
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                ThemeToggleButton()
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
                            ToolbarItem(placement: .topBarTrailing) {
                                ThemeToggleButton()
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onChange(of: showSettings) { _, isPresented in
            if !isPresented { viewModel.startAutoRefresh() }
        }
        .task {
            let hasKey = !(UserDefaults.standard.string(forKey: "tfnsw_api_key") ?? "").isEmpty
            if hasKey {
                viewModel.startAutoRefresh()
            } else {
                showSettings = true
            }
        }
        .preferredColorScheme(preferredColorScheme)
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

struct ThemeToggleButton: View {
    @AppStorage("app_color_scheme") private var preference = "system"

    private var icon: String {
        switch preference {
        case "light": return "sun.max.fill"
        case "dark":  return "moon.fill"
        default:      return "circle.lefthalf.filled"
        }
    }

    private var next: String {
        switch preference {
        case "system": return "light"
        case "light":  return "dark"
        default:       return "system"
        }
    }

    var body: some View {
        Button { preference = next } label: {
            Image(systemName: icon)
        }
    }
}

#Preview {
    ContentView()
}
