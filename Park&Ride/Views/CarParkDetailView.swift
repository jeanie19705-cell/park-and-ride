import SwiftUI
import MapKit
import Charts

struct CarParkDetailView: View {
    let carPark: BackendCarPark
    @State private var refreshed: BackendCarPark?
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var history: [OccupancyReading] = []

    @State private var alertEnabled = false
    @State private var startTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: .now)!
    @State private var endTime   = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
    @State private var threshold = 20
    @State private var showPermissionDenied = false

    private var displayed: BackendCarPark { refreshed ?? carPark }

    private var chartColor: Color {
        guard let f = displayed.occupancyFraction else { return .secondary }
        if f < 0.60 { return .green }
        if f < 0.85 { return .orange }
        return .occupancyRed
    }

    var body: some View {
        List {
            if let error = errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.callout)
                }
            }

            Section("Live Occupancy") {
                if let available = displayed.availableSpots, let total = displayed.totalSpots {
                    let fraction = displayed.occupancyFraction ?? 0
                    let color = occupancyColor(fraction)

                    LabeledContent("Free spaces") {
                        Text("\(available)").foregroundStyle(color).fontWeight(.semibold)
                    }
                    LabeledContent("Total capacity", value: "\(total)")
                    ProgressView(value: fraction).tint(color).padding(.vertical, 4)
                } else {
                    Text("No occupancy data available").foregroundStyle(.secondary)
                }
            }

            if !history.isEmpty {
                Section("Today's Occupancy") {
                    Chart(history) { reading in
                        LineMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("Occupancy", reading.fraction * 100)
                        )
                        .foregroundStyle(chartColor)
                        .interpolationMethod(.catmullRom)
                        AreaMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("Occupancy", reading.fraction * 100)
                        )
                        .foregroundStyle(chartColor.opacity(0.1))
                        .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxis {
                        AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                            AxisGridLine()
                            AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%").font(.caption2) }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.hour())
                        }
                    }
                    .frame(height: 160)
                    .padding(.vertical, 8)
                }
            }

            if let loc = displayed.location {
                Section("Location") {
                    if let address = loc.address { LabeledContent("Address", value: address) }
                    if let suburb = loc.suburb   { LabeledContent("Suburb",  value: suburb)  }

                    if let mapItem = mapItem(for: loc) {
                        Button {
                            mapItem.openInMaps(launchOptions: [
                                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                            ])
                        } label: {
                            Label("Get Directions", systemImage: "map")
                        }
                    }
                }
            }

            Section {
                Toggle("Notify me", isOn: $alertEnabled)
                    .onChange(of: alertEnabled) { _, enabled in
                        Task { await handleToggle(enabled) }
                    }

                if alertEnabled {
                    DatePicker("From", selection: $startTime, displayedComponents: .hourAndMinute)
                        .onChange(of: startTime) { _, _ in Task { await saveAlert() } }
                    DatePicker("To", selection: $endTime, displayedComponents: .hourAndMinute)
                        .onChange(of: endTime) { _, _ in Task { await saveAlert() } }
                    Stepper("Below \(threshold)% available", value: $threshold, in: 5...100, step: 5)
                        .onChange(of: threshold) { _, _ in Task { await saveAlert() } }
                }
            } header: {
                Text("Notifications")
            } footer: {
                if alertEnabled {
                    Text("You'll be notified when availability drops below \(threshold)% between the selected times, checked every 60 seconds.")
                }
            }

            Section {
                if let updated = displayed.MessageDate {
                    LabeledContent("Data timestamp", value: updated).font(.callout)
                }
                if isRefreshing {
                    HStack {
                        ProgressView()
                        Text("Refreshing…").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color("AppBackground"))
        .navigationTitle(displayed.facility_name ?? "Car Park")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await fetchLatest() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isRefreshing)
            }
        }
        .task {
            await fetchLatest()
            await loadAlert()
            await loadHistory()
        }
        .alert("Notifications Disabled", isPresented: $showPermissionDenied) {
            Button("Open Settings") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow notifications for Park & Ride in Settings to use this feature.")
        }
    }

    // MARK: — Alert config

    private func loadAlert() async {
        guard let alert = try? await BackendService.shared.fetchAlert(facilityId: carPark.facility_id) else { return }
        alertEnabled = alert.isEnabled
        startTime    = timeToDate(hour: alert.startHour, minute: alert.startMinute)
        endTime      = timeToDate(hour: alert.endHour,   minute: alert.endMinute)
        threshold    = alert.threshold
    }

    private func handleToggle(_ enabled: Bool) async {
        if enabled {
            let granted = await NotificationService.requestPermission()
            if !granted {
                alertEnabled = false
                showPermissionDenied = true
                return
            }
        }
        await saveAlert()
    }

    private func saveAlert() async {
        let (sh, sm) = dateToTime(startTime)
        let (eh, em) = dateToTime(endTime)
        try? await BackendService.shared.saveAlert(
            ParkAlert(isEnabled: alertEnabled, startHour: sh, startMinute: sm,
                      endHour: eh, endMinute: em, threshold: threshold),
            facilityId: carPark.facility_id
        )
    }

    private func timeToDate(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }

    private func dateToTime(_ date: Date) -> (Int, Int) {
        let cal = Calendar.current
        return (cal.component(.hour, from: date), cal.component(.minute, from: date))
    }

    // MARK: — Maps / fetch

    private func mapItem(for loc: ParkLocation) -> MKMapItem? {
        guard let latStr = loc.latitude, let lonStr = loc.longitude,
              let lat = Double(latStr), let lon = Double(lonStr) else { return nil }
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        let item = MKMapItem(placemark: placemark)
        item.name = displayed.facility_name
        return item
    }

    private func loadHistory() async {
        history = (try? await BackendService.shared.fetchHistory(facilityId: carPark.facility_id)) ?? []
    }

    private func fetchLatest() async {
        isRefreshing = true
        errorMessage = nil
        do {
            refreshed = try await BackendService.shared.fetchCarPark(facilityId: carPark.facility_id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isRefreshing = false
    }

    private func occupancyColor(_ fraction: Double) -> Color {
        if fraction < 0.60 { return .green }
        if fraction < 0.85 { return .orange }
        return .occupancyRed
    }
}
