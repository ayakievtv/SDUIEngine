import Foundation

struct DataSourceConfig: Equatable {
    let id: String
    let endpoint: String
    let fetchPolicy: String
    let pageSize: Int
    let queryParam: String
    let cursorParam: String
    let localFiltering: Bool
    let remoteFiltering: Bool
    let debounceMs: Int
    let sorting: Bool
    let defaultSortField: String?
    let defaultSortAscending: Bool
    let prefetchThreshold: Int
    let keyField: String

    static func makeDefault(id: String, endpoint: String) -> DataSourceConfig {
        DataSourceConfig(
            id: id,
            endpoint: endpoint,
            fetchPolicy: "NETWORK_FIRST_LOCAL_FALLBACK",
            pageSize: 25,
            queryParam: "q",
            cursorParam: "offset",
            localFiltering: true,
            remoteFiltering: true,
            debounceMs: 450,
            sorting: true,
            defaultSortField: nil,
            defaultSortAscending: true,
            prefetchThreshold: 3,
            keyField: "id"
        )
    }
}

final class DataSourceRegistry {
    private var storage: [String: DataSourceConfig] = [:]

    func register(_ config: DataSourceConfig) {
        storage[config.id] = config
    }

    func get(_ id: String) -> DataSourceConfig? {
        storage[id]
    }
}
