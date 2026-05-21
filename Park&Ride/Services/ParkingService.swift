import Foundation

enum ParkingError: LocalizedError {
    case noAPIKey
    case httpError(Int, String)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key set. Tap the gear icon to add your TfNSW API key."
        case .httpError(let code, let body):
            return "Server returned HTTP \(code). \(body)"
        case .decodingFailed(let error):
            return "Could not parse response: \(error.localizedDescription)"
        }
    }
}

struct ParkingService {
    static let shared = ParkingService()
    private let base = "https://api.transport.nsw.gov.au/v1"

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "tfnsw_api_key") ?? ""
    }

    func fetchAllCarParks() async throws -> [CarPark] {
        let data = try await get(path: "/carpark/full-list")
        return try decode([CarPark].self, from: data)
    }

    func fetchCarPark(facilityId: String) async throws -> CarPark? {
        let data = try await get(path: "/carpark", query: ["facility": facilityId])
        return try decode(CarPark.self, from: data)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw ParkingError.decodingFailed(error)
        }
    }

    private func get(path: String, query: [String: String] = [:]) async throws -> Data {
        guard !apiKey.isEmpty else { throw ParkingError.noAPIKey }

        var components = URLComponents(string: base + path)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var request = URLRequest(url: components.url!)
        request.setValue("apikey \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ParkingError.httpError(http.statusCode, body)
        }

        return data
    }
}