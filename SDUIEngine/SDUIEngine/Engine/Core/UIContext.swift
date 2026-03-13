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

final class EventDispatcher: EventDispatching {
    private var handlers: [EventType: EventHandler] = [:]

    func register(_ type: EventType, handler: @escaping EventHandler) {
        handlers[type] = handler
    }

    func dispatch(_ event: EventModel, context: UIContext) {
        handlers[event.type]?(event, context)
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

@MainActor
final class UIContext {
    let stateStore: StateStoreManaging
    let eventDispatcher: EventDispatching
    let navigation: NavigationRouting
    let apiClient: APIClient
    let componentRegistry: ComponentRegistry

    init(
        stateStore: StateStoreManaging = InMemoryStateStore(),
        eventDispatcher: EventDispatching = EventDispatcher(),
        navigation: NavigationRouting = NavigationEngine(),
        apiClient: APIClient = MockAPIClient(),
        componentRegistry: ComponentRegistry = ComponentRegistry()
    ) {
        self.stateStore = stateStore
        self.eventDispatcher = eventDispatcher
        self.navigation = navigation
        self.apiClient = apiClient
        self.componentRegistry = componentRegistry
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
        Binding(
            get: { self.stateValue(for: key)?.stringValue ?? defaultValue },
            set: { self.setState(key: key, value: .string($0)) }
        )
    }

    func bindingBool(for key: String, default defaultValue: Bool = false) -> Binding<Bool> {
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
        navigation.navigate(to: route, mode: .push)
    }

    func navigate(_ route: String) {
        navigate(to: route)
    }

    func push(_ route: String) {
        navigation.push(route)
    }

    func modal(_ route: String) {
        navigation.modal(route)
    }

    func replace(with route: String) {
        navigation.replace(with: route)
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
}
