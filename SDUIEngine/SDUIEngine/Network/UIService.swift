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
    static let useLocalScreens = false //true

    private let baseURL: URL?
    private let session: URLSession
    private let decoder: JSONDecoder
    private let cache = UIScreenCache()

    init(baseURL: URL? = nil, session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }

    func loadScreen(screenName: String, appId: String) async throws -> ComponentModel {
        do {
            let backendData = try await loadFromBackend(screenName: screenName, appId: appId)
            await cache.set(cacheKey(screenName: screenName, appId: appId), data: backendData)
            return try decodeComponent(from: backendData)
        } catch {
            let localData = try loadLocalScreenData(screenName: screenName)
            return try decodeComponent(from: localData)
        }
    }

    private func cacheKey(screenName: String, appId: String) -> String {
        "\(appId)::\(screenName)"
    }

    private func loadFromBackend(screenName: String, appId: String) async throws -> Data {
        let key = cacheKey(screenName: screenName, appId: appId)
        if let cached = await cache.get(key) {
            return cached
        }
        guard let baseURL else { throw UIServiceError.invalidBackendBaseURL }

        let endpoint = baseURL.appendingPathComponent("api").appendingPathComponent("run")
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: true) else {
            throw UIServiceError.invalidBackendBaseURL
        }
        components.queryItems = [
            URLQueryItem(name: "1", value: "1"),
            URLQueryItem(name: "module", value: "dsapi"),
            URLQueryItem(name: "action", value: "GET_SCREEN"),
            URLQueryItem(name: "screenId", value: screenName),
            URLQueryItem(name: "app_id", value: appId),
        ]
        guard let finalURL = components.url else { throw UIServiceError.invalidBackendBaseURL }

        let (data, response) = try await session.data(from: finalURL)
        guard let httpResponse = response as? HTTPURLResponse else { throw UIServiceError.invalidResponse }
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
            
            Log.d("Loading screen data from local file: \(resourceURL)",resourceURL)
            return try Data(contentsOf: resourceURL)
        }

        // Extra safety for projects where resources are flattened in bundle root.
        if let rootURL = Bundle.main.url(forResource: screenName, withExtension: "json") {
            return try Data(contentsOf: rootURL)
        }

        throw UIServiceError.screenFileNotFound(screenName: screenName)
    }

    private func decodeComponent(from data: Data) throws -> ComponentModel {
        let data = resolveVariables(in: data)
        
        // Supports multiple backend payload envelopes for compatibility.
        if let component = try? decoder.decode(ComponentModel.self, from: data) {
            return component
        }

        if let payload = try? decoder.decode(ScreenPayload.self, from: data) {
            return payload.screen
        }

        return try decoder.decode(RootPayload.self, from: data).root
    }

    /// Data -> JSONValue -> подстановка @TOKEN -> Data.
    /// При любой ошибке возвращает исходные данные, чтобы не ломать загрузку экрана.
    private func resolveVariables(in data: Data, using store: GlobalVariablesStore = .shared) -> Data {
        guard let json = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            return data
        }
        
        let resolved = json.resolvingVariables(using: ParamResolver(store: store))
        
        return (try? JSONEncoder().encode(resolved)) ?? data
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
