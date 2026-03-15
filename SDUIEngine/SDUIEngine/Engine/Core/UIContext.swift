import Foundation
import SwiftUI

protocol StateStoreManaging: AnyObject {
    var state: [String: JSONValue] { get }
    func value(for key: String) -> JSONValue?
    func set(_ value: JSONValue, for key: String)
}

final class InMemoryStateStore: StateStoreManaging {
    private(set) var state: [String: JSONValue] = [:]

    func value(for key: String) -> JSONValue? {
        state[key]
    }

    func set(_ value: JSONValue, for key: String) {
        state[key] = value
    }
}

protocol EventDispatching: AnyObject {
    func dispatch(_ event: EventModel, context: UIContext)
}

typealias EventHandler = (EventModel, UIContext) -> Void

// Dispatches both local UI events and backend dynamic actions.
final class EventDispatcher: EventDispatching {
    private var handlers: [EventType: EventHandler] = [:]
    private let componentStore: ComponentStore
    private let paramResolver: ParamResolver

    init(
        componentStore: ComponentStore = .shared,
        paramResolver: ParamResolver = ParamResolver()
    ) {
        self.componentStore = componentStore
        self.paramResolver = paramResolver
    }

    func register(_ type: EventType, handler: @escaping EventHandler) {
        handlers[type] = handler
    }

    func dispatch(_ event: EventModel, context: UIContext) {
        handlers[event.type]?(event, context)
    }

    // Executes one dynamic action if trigger matches current lifecycle/user trigger.
    func dispatch(_ componentEvent: ComponentEvent, for trigger: ComponentEventTrigger? = nil) {
        if let trigger, componentEvent.trigger != trigger.rawValue {
            return
        }

        let resolvedParams = paramResolver.resolve(params: componentEvent.params)
        for targetID in componentEvent.targets {
            componentStore.get(componentID: targetID)?.handle(action: componentEvent.action, params: resolvedParams)
        }
    }

    // Executes all actions for a given trigger.
    func dispatch(events: [ComponentEvent], for trigger: ComponentEventTrigger) {
        events.forEach { dispatch($0, for: trigger) }
    }
}

enum HTTPMethod: String, Codable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

protocol APIClient: AnyObject {
    func request(endpoint: String, method: HTTPMethod, body: [String: JSONValue]?) async throws -> JSONValue
}

final class MockAPIClient: APIClient {
    func request(endpoint: String, method: HTTPMethod, body: [String: JSONValue]?) async throws -> JSONValue {
        .object([
            "endpoint": .string(endpoint),
            "method": .string(method.rawValue),
            "body": .object(body ?? [:]),
        ])
    }
}

func makeDefaultAPIClient() -> APIClient {
    let remote = URLSessionRemoteClient()
    let dataLayer = OfflineDataLayer(remote: remote)
    return OfflineAPIClient(dataLayer: dataLayer)
}

@MainActor
// Runtime context shared by every component: state, events, navigation and API.
final class UIContext {
    let stateStore: StateStoreManaging
    let eventDispatcher: EventDispatching
    let navigation: NavigationRouting
    let apiClient: APIClient
    let componentRegistry: ComponentRegistry
    let dataSourceRegistry: DataSourceRegistry
    private let componentStore: ComponentStore

    init(
        stateStore: StateStoreManaging = InMemoryStateStore(),
        eventDispatcher: EventDispatching = EventDispatcher(),
        navigation: NavigationRouting? = nil,
        apiClient: APIClient = makeDefaultAPIClient(),
        componentRegistry: ComponentRegistry = ComponentRegistry(),
        dataSourceRegistry: DataSourceRegistry = DataSourceRegistry(),
        componentStore: ComponentStore = .shared
    ) {
        self.stateStore = stateStore
        self.eventDispatcher = eventDispatcher
        self.navigation = navigation ?? NavigationRouter()
        self.apiClient = apiClient
        self.componentRegistry = componentRegistry
        self.dataSourceRegistry = dataSourceRegistry
        self.componentStore = componentStore

        // Bridge common component events to backend-driven navigation actions.
        registerDefaultEventHandlers()
    }

    func setState(_ value: JSONValue, for key: String) {
        stateStore.set(value, for: key)
    }

    func setState(key: String, value: JSONValue) {
        setState(value, for: key)
    }

    func stateValue(for key: String) -> JSONValue? {
        stateStore.value(for: key)
    }

    func bindingString(for key: String, default defaultValue: String = "") -> Binding<String> {
        // Two-way binding between UI controls and state store string values.
        Binding(
            get: { self.stateValue(for: key)?.stringValue ?? defaultValue },
            set: { self.setState(key: key, value: .string($0)) }
        )
    }

    func bindingBool(for key: String, default defaultValue: Bool = false) -> Binding<Bool> {
        // Two-way binding between UI controls and state store bool values.
        Binding(
            get: { self.stateValue(for: key)?.boolValue ?? defaultValue },
            set: { self.setState(key: key, value: .bool($0)) }
        )
    }

    func dispatch(_ event: EventModel) {
        eventDispatcher.dispatch(event, context: self)
    }

    func trigger(_ event: EventModel) {
        dispatch(event)
    }

    func navigate(to route: String) {
        navigation.navigate(to: AppRoute(screenName: route), mode: .push)
    }

    func navigate(_ route: String) {
        navigate(to: route)
    }

    func push(_ route: String) {
        navigation.push(AppRoute(screenName: route))
    }

    func modal(_ route: String) {
        navigation.modal(AppRoute(screenName: route))
    }

    func replace(with route: String) {
        navigation.replace(with: AppRoute(screenName: route))
    }

    func handle(action: ServerAction) {
        navigation.handle(action: action)
    }

    func dismissModal() {
        navigation.dismissModal()
    }

    func goBack() {
        navigation.pop()
    }

    func callAPI(endpoint: String, method: HTTPMethod = .get, body: [String: JSONValue]? = nil) async throws -> JSONValue {
        try await apiClient.request(endpoint: endpoint, method: method, body: body)
    }

    func callAPI(_ endpoint: String, method: HTTPMethod = .get, body: [String: JSONValue]? = nil) async throws -> JSONValue {
        try await callAPI(endpoint: endpoint, method: method, body: body)
    }

    private func registerDefaultEventHandlers() {
        guard let dispatcher = eventDispatcher as? EventDispatcher else {
            return
        }

        // Standard tap action path: component event -> ServerAction -> router.
        dispatcher.register(.onTap) { event, context in
            context.dispatchComponentAction(event)
            guard let action = ServerAction.from(event: event) else { return }
            context.handle(action: action)
        }

        // Submit actions can navigate as well (for forms/search flows).
        dispatcher.register(.onSubmit) { event, context in
            context.dispatchComponentAction(event)
            guard let action = ServerAction.from(event: event) else { return }
            context.handle(action: action)
        }

        // Change actions support "event chains", e.g. TextField value update -> target component update.
        dispatcher.register(.onChange) { event, context in
            context.dispatchComponentAction(event)
            guard let action = ServerAction.from(event: event) else { return }
            context.handle(action: action)
        }
    }

    // Supports direct component-to-component actions from simple onTap/onSubmit event payloads.
    // Expected shape:
    // {
    //   "target": "title_text",
    //   "targets": ["title_text", "subtitle_text"],
    //   "params": { "action": "SET_TEXT", "value": "Hello" }
    // }
    private func dispatchComponentAction(_ event: EventModel) {
        let targets = event.targets
        guard !targets.isEmpty else { return }

        if let actions = event.params["actions"]?.arrayValue {
            for actionDefinition in actions {
                guard
                    let actionPayload = actionDefinition.objectValue,
                    let action = actionPayload["action"]?.stringValue
                else {
                    continue
                }

                let params = actionPayload.reduce(into: [String: String]()) { result, pair in
                    switch pair.value {
                    case let .string(value):
                        result[pair.key] = value
                    case let .number(value):
                        result[pair.key] = String(value)
                    case let .bool(value):
                        result[pair.key] = value ? "true" : "false"
                    default:
                        break
                    }
                }

                for target in targets {
                    componentStore.get(componentID: target)?.handle(action: action, params: params)
                }
            }
            return
        }

        guard let action = event.params["action"]?.stringValue else {
            return
        }

        let params = event.params.reduce(into: [String: String]()) { result, pair in
            switch pair.value {
            case let .string(value):
                result[pair.key] = value
            case let .number(value):
                result[pair.key] = String(value)
            case let .bool(value):
                result[pair.key] = value ? "true" : "false"
            default:
                break
            }
        }

        for target in targets {
            componentStore.get(componentID: target)?.handle(action: action, params: params)
        }
    }
}
