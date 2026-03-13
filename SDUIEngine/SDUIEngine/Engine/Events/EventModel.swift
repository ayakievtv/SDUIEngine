import Foundation

enum EventType: String, Codable, Equatable, CaseIterable {
    case onTap
    case onAppear
    case onDisappear
    case onChange
    case onSubmit
}

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
    func event(for type: EventType) -> EventModel? {
        guard let definition = events[type.rawValue] else {
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
