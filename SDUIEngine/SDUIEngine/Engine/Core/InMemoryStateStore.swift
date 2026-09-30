import SwiftUI
/// In-memory implementation of state store
final class InMemoryStateStore: StateStoreManaging {
    private(set) var state: [String: JSONValue] = [:]

    func getValue(for key: String) -> JSONValue? {
        state[key]
    }

    func set(_ value: JSONValue, for key: String) {
        state[key] = value
    }
    
    func merge(_ json: JSONValue, withPrefix prefix: String) {
        guard let object = json.objectValue else { return }
        for (key, value) in object {
            self.set(value, for: "\(prefix).\(key)")
        }
    }
    
    func getValues(forPrefix prefix: String) -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]
        let searchPrefix = prefix.hasSuffix(".") ? prefix : "\(prefix)."
        
        for (key, value) in state {
            if key.hasPrefix(searchPrefix) {
                let cleanKey = String(key.dropFirst(searchPrefix.count))
                result[cleanKey] = value
            }
        }
        return result
    }
}
