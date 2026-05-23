import SwiftUI

struct CarParkListView: View {
    let viewModel: ParkingViewModel
    @State private var searchText = ""

    private var pinned: [BackendCarPark] {
        viewModel.carParks.filter { viewModel.isPinned($0) }
    }

    private var others: [BackendCarPark] {
        viewModel.carParks.filter { !viewModel.isPinned($0) }
    }

    private var filtered: [BackendCarPark] {
        let q = searchText.lowercased()
        return viewModel.carParks.filter {
            ($0.facility_name?.lowercased().contains(q) == true) ||
            ($0.location?.suburb?.lowercased().contains(q) == true)
        }
    }

    var body: some View {
        Group {
            if let error = viewModel.errorMessage {
                ContentUnavailableView {
                    Label("Unable to Load", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await viewModel.refresh() } }
                        .buttonStyle(.borderedProminent)
                }
            } else if viewModel.carParks.isEmpty && !viewModel.isLoading {
                ContentUnavailableView {
                    Label("No Car Parks", systemImage: "parkingsign.circle")
                } description: {
                    Text("Unable to load car parks. Pull down to retry.")
                }
            } else {
                List {
                    if searchText.isEmpty {
                        if !pinned.isEmpty {
                            Section("Pinned") {
                                ForEach(pinned) { carPark in row(carPark) }
                            }
                        }
                        Section(pinned.isEmpty ? "" : "All Car Parks") {
                            ForEach(others) { carPark in row(carPark) }
                        }
                    } else {
                        ForEach(filtered) { carPark in row(carPark) }
                    }

                }
                .refreshable { await viewModel.refresh() }
                .overlay {
                    if !searchText.isEmpty && filtered.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name or suburb")
    }

    @ViewBuilder
    private func row(_ carPark: BackendCarPark) -> some View {
        NavigationLink(destination: CarParkDetailView(carPark: carPark)) {
            CarParkRow(carPark: carPark, isPinned: viewModel.isPinned(carPark))
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { viewModel.togglePin(carPark) } label: {
                Label(
                    viewModel.isPinned(carPark) ? "Unpin" : "Pin",
                    systemImage: viewModel.isPinned(carPark) ? "pin.slash" : "pin"
                )
            }
            .tint(.yellow)
        }
    }
}

struct CarParkRow: View {
    let carPark: BackendCarPark
    var isPinned: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            OccupancyRing(fraction: carPark.occupancyFraction)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(carPark.facility_name ?? "Car Park \(carPark.facility_id)")
                        .font(.headline)
                        .lineLimit(2)
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                if let address = carPark.location?.address {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if let available = carPark.availableSpots, let total = carPark.totalSpots {
                    Text("\(available) of \(total) spaces free")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Availability unknown")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct OccupancyRing: View {
    let fraction: Double?

    private var pct: Double { fraction ?? 0 }

    private var ringColor: Color {
        guard let f = fraction else { return .secondary }
        if f < 0.60 { return .green }
        if f < 0.85 { return .orange }
        return .red
    }

    private var label: String {
        guard let f = fraction else { return "?" }
        return "\(Int((1 - f) * 100))%"
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.2), lineWidth: 5)
            Circle()
                .trim(from: 0, to: pct)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: pct)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ringColor)
        }
    }
}