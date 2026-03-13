import Foundation
import SwiftUI

enum NavigationMode {
    case push
    case modal
    case replace
}

// Unified route model passed through NavigationStack path.
enum AppRoute: Hashable, Codable {
    case main
    case screen(name: String)

    var screenName: String {
        switch self {
        case .main:
            return "main"
        case let .screen(name):
            return name
        }
    }

    init(screenName: String) {
        if screenName == "main" {
            self = .main
        } else {
            self = .screen(name: screenName)
        }
    }

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let raw = try? singleValue.decode(String.self) {
            self = AppRoute(screenName: raw)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(RouteType.self, forKey: .type)

        switch type {
        case .main:
            self = .main
        case .screen:
            self = .screen(name: try container.decode(String.self, forKey: .name))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .main:
            try container.encode(RouteType.main, forKey: .type)
        case let .screen(name):
            try container.encode(RouteType.screen, forKey: .type)
            try container.encode(name, forKey: .name)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case name
    }

    private enum RouteType: String, Codable {
        case main
        case screen
    }
}

// Action contract expected from backend responses/events.
enum ActionType: String, Codable, Hashable {
    case navigate
    case navigateChain = "navigate_chain"
    case pop
    case popToRoot = "pop_to_root"
}

// Parsed navigation payload received from backend-driven actions.
struct ServerAction: Codable, Hashable {
    let type: ActionType
    let route: AppRoute?
    let routes: [AppRoute]
    let mode: NavigationModePayload

    init(
        type: ActionType,
        route: AppRoute? = nil,
        routes: [AppRoute] = [],
        mode: NavigationModePayload = .push
    ) {
        self.type = type
        self.route = route
        self.routes = routes
        self.mode = mode
    }
}

enum NavigationModePayload: String, Codable, Hashable {
    case push
    case replace
}

@MainActor
protocol NavigationRouting: AnyObject {
    var path: [AppRoute] { get }
    var currentRoute: AppRoute? { get }
    var modalRoute: AppRoute? { get }

    func handle(action: ServerAction)
    func navigate(to route: AppRoute, mode: NavigationMode)
    func push(_ route: AppRoute)
    func modal(_ route: AppRoute)
    func replace(with route: AppRoute)
    func pop()
    func reset(to route: AppRoute?)
    func dismissModal()
}

// Single source of truth for stack-based navigation state.
@MainActor
final class NavigationRouter: ObservableObject, NavigationRouting {
    @Published var path: [AppRoute] = []
    @Published private(set) var modalRoute: AppRoute?

    var currentRoute: AppRoute? {
        path.last
    }

    // Converts server intent into concrete stack mutations.
    func handle(action: ServerAction) {
        switch action.type {
        case .navigate:
            guard let route = action.route else { return }
            if action.mode == .replace {
                replace(with: route)
            } else {
                push(route)
            }
        case .navigateChain:
            let chain = action.routes
            guard !chain.isEmpty else { return }

            // Supports deep nested navigation when backend sends a full chain:
            // ["catalog", "product_42", "checkout"].
            if action.mode == .replace {
                path.removeAll()
                chain.forEach { push($0) }
            } else {
                chain.forEach { push($0) }
            }
        case .pop:
            pop()
        case .popToRoot:
            path.removeAll()
        }
    }

    func navigate(to route: AppRoute, mode: NavigationMode) {
        switch mode {
        case .push:
            push(route)
        case .modal:
            modal(route)
        case .replace:
            replace(with: route)
        }
    }

    func push(_ route: AppRoute) {
        // "main" is a root route and should never live inside NavigationStack path.
        if route == .main {
            path.removeAll()
            return
        }
        path.append(route)
    }

    func modal(_ route: AppRoute) {
        modalRoute = route
    }

    func replace(with route: AppRoute) {
        // Replacing with root route means returning to root stack state.
        if route == .main {
            path.removeAll()
            return
        }
        if path.isEmpty {
            path = [route]
        } else {
            path[path.count - 1] = route
        }
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func reset(to route: AppRoute?) {
        path = route.map { [$0] } ?? []
        modalRoute = nil
    }

    func dismissModal() {
        modalRoute = nil
    }
}

extension ServerAction {
    // Maps event payload coming from SDUI components into a routing action.
    static func from(event: EventModel) -> ServerAction? {
        guard event.type == .onTap || event.type == .onSubmit || event.type == .onChange else {
            return nil
        }

        let rawType = event.params["type"]?.stringValue ?? event.params["actionType"]?.stringValue ?? "navigate"
        let type = ActionType(rawValue: rawType) ?? .navigate

        let modeRaw = event.params["mode"]?.stringValue ?? "push"
        let mode = NavigationModePayload(rawValue: modeRaw) ?? .push

        if type == .navigateChain,
           let routeValues = event.params["routes"]?.arrayValue {
            let routes = routeValues.compactMap { $0.stringValue }.map(AppRoute.init(screenName:))
            return ServerAction(type: .navigateChain, routes: routes, mode: mode)
        }

        if let routeName = event.params["route"]?.stringValue {
            return ServerAction(type: type, route: AppRoute(screenName: routeName), mode: mode)
        }

        if event.target.hasPrefix("screen:") {
            let screenName = String(event.target.dropFirst("screen:".count))
            return ServerAction(type: .navigate, route: AppRoute(screenName: screenName), mode: mode)
        }

        return nil
    }
}
