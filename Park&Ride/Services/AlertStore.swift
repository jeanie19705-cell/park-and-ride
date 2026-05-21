import Foundation

struct AlertStore {
    private static let key = "park_alerts_v1"

    static func load(for facilityId: String) -> ParkAlert? {
        all()[facilityId]
    }

    static func save(_ alert: ParkAlert, for facilityId: String) {
        var current = all()
        current[facilityId] = alert
        persist(current)
    }

    static func remove(for facilityId: String) {
        var current = all()
        current.removeValue(forKey: facilityId)
        persist(current)
    }

    static func all() -> [String: ParkAlert] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: ParkAlert].self, from: data)
        else { return [:] }
        return decoded
    }

    private static func persist(_ alerts: [String: ParkAlert]) {
        if let data = try? JSONEncoder().encode(alerts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}