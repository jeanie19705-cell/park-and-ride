import Foundation

struct BackendService {
    static let shared = BackendService()

    private let base = Secrets.backendBaseURL
    private let apiKey = Secrets.backendAPIKey

    private var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: "backend_device_id") { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "backend_device_id")
        return id
    }

    // MARK: — Carparks

    func fetchAllCarParks() async throws -> [BackendCarPark] {
        try await get("/carparks")
    }

    func fetchCarPark(facilityId: String) async throws -> BackendCarPark {
        try await get("/carparks/\(facilityId)")
    }

    private struct HistoryCacheEntry {
        let readings: [OccupancyReading]
        let fetchedAt: Date
    }
    private static var historyCache: [String: HistoryCacheEntry] = [:]
    private let historyCacheTTL: TimeInterval = 60

    func fetchHistory(facilityId: String) async throws -> [OccupancyReading] {
        if let cached = Self.historyCache[facilityId],
           Date().timeIntervalSince(cached.fetchedAt) < historyCacheTTL {
            return cached.readings
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var req = URLRequest(url: URL(string: base + "/carparks/\(facilityId)/history")!)
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        let (data, _) = try await URLSession.shared.data(for: req)
        let readings = try decoder.decode([OccupancyReading].self, from: data)
        Self.historyCache[facilityId] = HistoryCacheEntry(readings: readings, fetchedAt: Date())
        return readings
    }

    // MARK: — Device

    func registerDevice(apnsToken: String) async throws {
        struct Body: Encodable { let device_id: String; let apns_token: String }
        try await post("/devices", body: Body(device_id: deviceId, apns_token: apnsToken), expectData: false)
    }

    // MARK: — Alerts

    func fetchAlert(facilityId: String) async throws -> ParkAlert? {
        struct AlertResponse: Decodable {
            let facility_id: String
            let threshold: Int
            let start_hour: Int
            let start_minute: Int
            let end_hour: Int
            let end_minute: Int
            let is_enabled: Bool
        }
        let alerts: [AlertResponse] = try await get("/alerts", deviceId: deviceId)
        guard let match = alerts.first(where: { $0.facility_id == facilityId }) else { return nil }
        return ParkAlert(
            isEnabled: match.is_enabled,
            startHour: match.start_hour, startMinute: match.start_minute,
            endHour: match.end_hour,     endMinute: match.end_minute,
            threshold: match.threshold
        )
    }

    func saveAlert(_ alert: ParkAlert, facilityId: String) async throws {
        struct Body: Encodable {
            let facility_id: String
            let threshold: Int
            let start_hour: Int; let start_minute: Int
            let end_hour: Int;   let end_minute: Int
            let is_enabled: Bool
        }
        try await post("/alerts", body: Body(
            facility_id: facilityId,
            threshold: alert.threshold,
            start_hour: alert.startHour, start_minute: alert.startMinute,
            end_hour: alert.endHour,     end_minute: alert.endMinute,
            is_enabled: alert.isEnabled
        ), deviceId: deviceId, expectData: false)
    }

    // MARK: — Helpers

    private func get<T: Decodable>(_ path: String, deviceId: String? = nil) async throws -> T {
        var req = URLRequest(url: URL(string: base + path)!)
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        if let id = deviceId { req.setValue(id, forHTTPHeaderField: "x-device-id") }

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<B: Encodable>(
        _ path: String, body: B, deviceId: String? = nil, expectData: Bool
    ) async throws {
        var req = URLRequest(url: URL(string: base + path)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        if let id = deviceId { req.setValue(id, forHTTPHeaderField: "x-device-id") }
        req.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
            throw URLError(.badServerResponse)
        }
    }
}
