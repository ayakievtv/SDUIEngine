import Foundation

// Errors produced while fetching and decoding remote/local screen definitions.
enum UIServiceError: Error {
    case invalidBackendBaseURL
    case invalidResponse
    case badStatusCode(Int)
    case screenFileNotFound(screenName: String)
}

actor UIScreenCache {
    private var storage: [String: Data] = [:]

    func get(_ key: String) -> Data? {
        storage[key]
    }

    func set(_ key: String, data: Data) {
        storage[key] = data
    }
}

// Loads SDUI screen JSON from backend with local fallback and in-memory cache.
final class UIService {
    static let useLocalScreens = true

    private let baseURL: URL?
    private let session: URLSession
    private let decoder: JSONDecoder
    private let cache = UIScreenCache()

    init(baseURL: URL? = nil, session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }

    func loadScreen(_ screenName: String) async throws -> ComponentModel {
        try await loadScreen(screenName: screenName)
    }

    func loadScreen(name: String) async throws -> ComponentModel {
        try await loadScreen(screenName: name)
    }

    func loadScreen(screenName: String) async throws -> ComponentModel {
        // Fallback strategy:
        // 1) In development/local mode, always use bundle JSON.
        // 2) Otherwise try backend first.
        // 3) If backend fails for any reason, fallback to bundle JSON.
        if Self.useLocalScreens || Self.isDebugBuild {
            let localData = try loadLocalScreenData(screenName: screenName)
            print("Loaded UI from local JSON fallback")
            return try decodeComponent(from: localData)
        }

        do {
            let backendData = try await loadFromBackend(screenName: screenName)
            await cache.set(screenName, data: backendData)
            print("Loaded UI from backend")
            return try decodeComponent(from: backendData)
        } catch {
            let localData = try loadLocalScreenData(screenName: screenName)
            print("Loaded UI from local JSON fallback")
            return try decodeComponent(from: localData)
        }
    }

    private func loadFromBackend(screenName: String) async throws -> Data {
        // Avoid duplicate network calls for previously loaded screens.
        if let cached = await cache.get(screenName) {
            return cached
        }

        guard let baseURL else {
            throw UIServiceError.invalidBackendBaseURL
        }

        let endpoint = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("ui")
            .appendingPathComponent(screenName)

        let (data, response) = try await session.data(from: endpoint)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UIServiceError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw UIServiceError.badStatusCode(httpResponse.statusCode)
        }

        return data
    }

    private func loadLocalScreenData(screenName: String) throws -> Data {
        // Expected path: Resources/<screenName>.json in the app bundle.
        if let resourceURL = Bundle.main.url(
            forResource: screenName,
            withExtension: "json",
            subdirectory: "Resources"
        ) {
            return try Data(contentsOf: resourceURL)
        }

        // Extra safety for projects where resources are flattened in bundle root.
        if let rootURL = Bundle.main.url(forResource: screenName, withExtension: "json") {
            return try Data(contentsOf: rootURL)
        }

        throw UIServiceError.screenFileNotFound(screenName: screenName)
    }

    private func decodeComponent(from data: Data) throws -> ComponentModel {
        // Supports multiple backend payload envelopes for compatibility.
        if let component = try? decoder.decode(ComponentModel.self, from: data) {
            return component
        }

        if let payload = try? decoder.decode(ScreenPayload.self, from: data) {
            return payload.screen
        }

        return try decoder.decode(RootPayload.self, from: data).root
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}

private struct ScreenPayload: Decodable {
    let screen: ComponentModel
}

private struct RootPayload: Decodable {
    let root: ComponentModel
}
