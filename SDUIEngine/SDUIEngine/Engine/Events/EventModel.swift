import Foundation

enum EventType: String, Codable, Equatable, CaseIterable {
    case onTap
    case onAppear
    case onDisappear
    case onChange
    case onSubmit
}

// Trigger types used by backend-driven component events.
enum ComponentEventTrigger: String, Codable, CaseIterable {
    case onInit = "ON_INIT"
    case onTap = "ON_TAP"
    case onChange = "ON_CHANGE"
}

// JSON model for dynamic actions:
// {
//   "trigger": "ON_INIT",
//   "targets": ["dataset1"],
//   "action": "REFRESH",
//   "params": { "USERID": "@USERID" }
// }
struct ComponentEvent: Codable, Equatable {
    let trigger: String
    let targets: [String]
    let action: String
    let params: [String: String]?
}

// Optional root payload helper when backend returns { "events": [...] }.
struct ComponentEventsPayload: Codable, Equatable {
    let events: [ComponentEvent]
}

// Contract that target components implement to receive dynamic actions.
protocol EventActionHandler {
    func handle(action: String, params: [String: String]?)
}

// Type-erased component handler stored in ComponentStore.
final class AnyComponent: EventActionHandler {
    private let actionHandler: (String, [String: String]?) -> Void

    init(actionHandler: @escaping (String, [String: String]?) -> Void) {
        self.actionHandler = actionHandler
    }

    func handle(action: String, params: [String: String]?) {
        actionHandler(action, params)
    }
}

// Resolves dynamic placeholders used in backend params, e.g. @USERID.
final class ParamResolver {
    private let variableProviders: [String: () -> String]

    init(
        currentUserIDProvider: @escaping () -> String = { "demo_user" },
        extraProviders: [String: () -> String] = [:]
    ) {
        var providers: [String: () -> String] = [
            "@USERID": currentUserIDProvider,
        ]
        extraProviders.forEach { key, provider in
            let token = key.hasPrefix("@") ? key.uppercased() : "@\(key.uppercased())"
            providers[token] = provider
        }
        variableProviders = providers
    }

    func resolve(params: [String: String]?) -> [String: String]? {
        guard let params else { return nil }
        return params.reduce(into: [String: String]()) { result, pair in
            result[pair.key] = resolve(value: pair.value)
        }
    }

    private func resolve(value: String) -> String {
        var resolved = value
        for (token, provider) in variableProviders {
            if resolved.contains(token) {
                resolved = resolved.replacingOccurrences(of: token, with: provider())
            }
        }
        return resolved
    }
}

// Event descriptor attached to components in JSON config.
struct EventModel: Codable, Equatable {
    let type: EventType
    let target: String
    let params: [String: JSONValue]

    init(type: EventType, target: String, params: [String: JSONValue] = [:]) {
        self.type = type
        self.target = target
        self.params = params
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case target
        case params
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(EventType.self, forKey: .type)
        target = try container.decode(String.self, forKey: .target)
        params = try container.decodeIfPresent([String: JSONValue].self, forKey: .params) ?? [:]
    }
}

extension ComponentModel {
    // Reads event JSON and normalizes it to EventModel format.
    func event(for type: EventType) -> EventModel? {
        guard let definition = resolvedEvents[type.rawValue] else {
            return nil
        }

        switch definition {
        case let .string(target):
            return EventModel(type: type, target: target)
        case let .object(object):
            let target = object["target"]?.stringValue ?? id
            let params = object["params"]?.objectValue ?? [:]
            return EventModel(type: type, target: target, params: params)
        default:
            return EventModel(type: type, target: id)
        }
    }
}
