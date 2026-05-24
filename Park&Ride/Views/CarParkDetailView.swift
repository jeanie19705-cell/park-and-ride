import SwiftUI
import MapKit
import Charts

struct CarParkDetailView: View {
    let carPark: BackendCarPark
    @State private var refreshed: BackendCarPark?
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var history: [OccupancyReading] = []
    @State private var isLoadingHistory = true
    @State private var selectedReading: OccupancyReading?

    @State private var alertEnabled = false
    @State private var startTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: .now)!
    @State private var endTime   = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
    @State private var threshold = 20
    @State private var showPermissionDenied = false

    private var displayed: BackendCarPark { refreshed ?? carPark }

    private var chartColor: Color {
        guard let f = displayed.occupancyFraction else { return .secondary }
        return Self.occupancyColor(f)
    }

    private static func occupancyColor(_ fraction: Double) -> Color {
        if fraction < 0.60 { return .green }
        if fraction < 0.85 { return .orange }
        return .occupancyRed
    }

    private var colorSegments: [(readings: [OccupancyReading], color: Color)] {
        guard !history.isEmpty else { return [] }
        var segments: [(readings: [OccupancyReading], color: Color)] = []
        var current: [OccupancyReading] = [history[0]]
        var currentColor = Self.occupancyColor(history[0].fraction)

        for i in 1..<history.count {
            let reading = history[i]
            let color = Self.occupancyColor(reading.fraction)
            if color == currentColor {
                current.append(reading)
            } else {
                current.append(reading) // boundary point connects segments
                segments.append((current, currentColor))
                current = [reading]
                currentColor = color
            }
        }
        segments.append((current, currentColor))
        return segments
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

            Section("Today's Occupancy") {
                if isLoadingHistory {
                    ChartSkeleton()
                        .frame(height: 160)
                        .padding(.vertical, 8)
                } else if history.isEmpty {
                    Text("No data yet — check back shortly.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 32)
                } else {
                    Chart {
                        ForEach(Array(colorSegments.enumerated()), id: \.offset) { idx, segment in
                            ForEach(segment.readings) { reading in
                                LineMark(
                                    x: .value("Time", reading.timestamp),
                                    y: .value("Occupancy", reading.fraction * 100),
                                    series: .value("s", idx)
                                )
                                .foregroundStyle(segment.color)
                                .interpolationMethod(.catmullRom)
                            }
                        }
                        ForEach(history) { reading in
                            AreaMark(
                                x: .value("Time", reading.timestamp),
                                y: .value("Occupancy", reading.fraction * 100)
                            )
                            .foregroundStyle(chartColor.opacity(0.08))
                            .interpolationMethod(.catmullRom)
                        }
                        if let sel = selectedReading {
                            RuleMark(x: .value("Time", sel.timestamp))
                                .foregroundStyle(.secondary.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                                .annotation(position: .top, overflowResolution: .init(x: .fit, y: .fit)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sel.timestamp, format: .dateTime.hour().minute())
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("\(sel.available) spaces free")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.primary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                                }
                        }
                    }
                    .chartXScale(domain: Calendar.current.startOfDay(for: .now)...Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!)
                    .chartYScale(domain: 0...100)
                    .chartYAxis {
                        AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                            AxisGridLine()
                            AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%").font(.caption2) }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date, format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let x = value.location.x - geo[proxy.plotFrame!].origin.x
                                            if let date: Date = proxy.value(atX: x) {
                                                selectedReading = history.min(by: {
                                                    abs($0.timestamp.timeIntervalSince(date)) <
                                                    abs($1.timestamp.timeIntervalSince(date))
                                                })
                                            }
                                        }
                                        .onEnded { _ in selectedReading = nil }
                                )
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
        isLoadingHistory = true
        history = (try? await BackendService.shared.fetchHistory(facilityId: carPark.facility_id)) ?? []
        isLoadingHistory = false
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
        Self.occupancyColor(fraction)
    }
}

struct ChartSkeleton: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let chartH = geo.size.height - 20
            let points: [CGFloat] = [0.5, 0.45, 0.55, 0.4, 0.35, 0.5, 0.6, 0.55, 0.65, 0.7, 0.6]
            let tickCount = 8
            let now = Date()
            let calendar = Calendar.current

            VStack(spacing: 4) {
                ZStack {
                    SkeletonLinePath(points: points, size: CGSize(width: w, height: chartH), filled: true)
                        .fill(Color(.systemFill).opacity(0.4))
                    SkeletonLinePath(points: points, size: CGSize(width: w, height: chartH), filled: false)
                        .stroke(Color(.systemFill), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    Rectangle()
                        .fill(Color(.systemFill))
                        .frame(width: w, height: 1)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    ProgressView()
                }
                .frame(height: chartH)

                HStack(spacing: 0) {
                    ForEach(0..<tickCount, id: \.self) { i in
                        let hoursAgo = (tickCount - 1 - i) * 3
                        let tickDate = calendar.date(byAdding: .hour, value: -hoursAgo, to: now) ?? now
                        Text(tickDate, format: .dateTime.hour())
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

struct SkeletonLinePath: Shape {
    let points: [CGFloat]
    let size: CGSize
    let filled: Bool

    func path(in rect: CGRect) -> Path {
        guard points.count > 1 else { return Path() }
        let w = size.width
        let h = size.height
        let step = w / CGFloat(points.count - 1)

        var path = Path()
        let start = CGPoint(x: 0, y: h * points[0])
        path.move(to: start)

        for i in 1..<points.count {
            let prev = CGPoint(x: step * CGFloat(i - 1), y: h * points[i - 1])
            let curr = CGPoint(x: step * CGFloat(i), y: h * points[i])
            let control = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
            path.addQuadCurve(to: control, control: prev)
            path.addQuadCurve(to: curr, control: control)
        }

        if filled {
            path.addLine(to: CGPoint(x: w, y: h))
            path.addLine(to: CGPoint(x: 0, y: h))
            path.closeSubpath()
        }

        return path
    }
}
