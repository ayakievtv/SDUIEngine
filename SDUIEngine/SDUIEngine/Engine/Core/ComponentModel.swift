import Foundation

// Canonical server-driven component node.
struct ComponentModel: Identifiable, Codable, Equatable {
    let id: String
    let type: String
    let props: [String: JSONValue]?
    let events: [String: JSONValue]?
    let children: [ComponentModel]?

    init(
        id: String,
        type: String,
        props: [String: JSONValue]? = nil,
        events: [String: JSONValue]? = nil,
        children: [ComponentModel]? = nil
    ) {
        self.id = id
        self.type = type
        self.props = props
        self.events = events
        self.children = children
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case props
        case events
        case children
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        props = try container.decodeIfPresent([String: JSONValue].self, forKey: .props)
        events = try container.decodeIfPresent([String: JSONValue].self, forKey: .events)
        children = try container.decodeIfPresent([ComponentModel].self, forKey: .children)
    }
}

extension ComponentModel {
    var resolvedProps: [String: JSONValue] { props ?? [:] }
    var resolvedEvents: [String: JSONValue] { events ?? [:] }
    var resolvedChildren: [ComponentModel] { children ?? [] }
}


extension JSONValue {
    func resolvingVariables(using r: ParamResolver) -> JSONValue {
        switch self {
        case .string(let s): return .string(r.resolve(value: s))
        case .array(let a):  return .array(a.map { $0.resolvingVariables(using: r) })
        case .object(let o): return .object(o.mapValues { $0.resolvingVariables(using: r) })
        default:             return self
        }
    }
}

extension ComponentModel {
    func resolvingVariables(using r: ParamResolver) -> ComponentModel {
        ComponentModel(
            id: id, type: type,
            props:    props?.mapValues { $0.resolvingVariables(using: r) },
            events:   events?.mapValues { $0.resolvingVariables(using: r) },
            children: children?.map { $0.resolvingVariables(using: r) }
        )
    }
}
