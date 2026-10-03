import Foundation
import SwiftUI

// MARK: - Navigation Types

/// Navigation modes for route transitions
enum NavigationMode {
    case push      // Push new route onto stack
    case modal     // Present route modally
    case replace   // Replace current route
}

/// Unified route model passed through NavigationStack path
//enum AppRoute: Hashable, Codable {
//    case main                               // Root/main screen
//    case screen(name: String)                // Named screen route
//
//    /// Extract screen name for display purposes
//    var screenName: String {
//        switch self {
//        case .main:
//            return "main"
//        case let .screen(name):
//            return name
//        }
//    }
//
//    /// Initialize with screen name, mapping "main" to main case
//    init(screenName: String) {
//        if screenName == "main" {
//            self = .main
//        } else {
//            self = .screen(name: screenName)
//        }
//    }
//
//    /// Custom decoder implementation for flexible route parsing
//    init(from decoder: Decoder) throws {
//        if let singleValue = try? decoder.singleValueContainer(),
//           let raw = try? singleValue.decode(String.self) {
//            self = AppRoute(screenName: raw)
//            return
//        }
//
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        let type = try container.decode(RouteType.self, forKey: .type)
//
//        switch type {
//        case .main:
//            self = .main
//        case .screen:
//            self = .screen(name: try container.decode(String.self, forKey: .name))
//        }
//    }
//
//    /// Custom encoder implementation for route serialization
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//
//        switch self {
//        case .main:
//            try container.encode(RouteType.main, forKey: .type)
//        case let .screen(name):
//            try container.encode(RouteType.screen, forKey: .type)
//            try container.encode(name, forKey: .name)
//        }
//    }
//
//    /// Coding keys for route serialization
//    private enum CodingKeys: String, CodingKey {
//        case type
//        case name
//    }
//
//    /// Internal route type for serialization
//    private enum RouteType: String, Codable {
//        case main
//        case screen
//    }
//}

struct AppRoute: Hashable, Codable {
    let appId: String
    let name: String

    var screenName: String { name }

    init(appId: String, screenName: String) {
        self.appId = appId
        self.name = screenName
    }
}


/// Action contract expected from backend responses/events
enum ActionType: String, Codable, Hashable {
    case navigate                     // Navigate to single route
    case navigateChain = "navigate_chain"  // Navigate through multiple routes
    case pop                         // Pop current route
    case popToRoot = "pop_to_root"       // Pop to root route
}

/// Parsed navigation payload received from backend-driven actions
struct ServerAction: Codable, Hashable {
    let type: ActionType                    // Action type to perform
    let route: AppRoute?                   // Target route (for single navigation)
    let routes: [AppRoute]                 // Route chain (for navigateChain)
    let mode: NavigationModePayload        // Navigation mode (push/replace)

    /// Initialize server action with default values
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

/// Navigation mode payload from server
enum NavigationModePayload: String, Codable, Hashable {
    case push        // Push onto navigation stack
    case replace     // Replace current route
}

// MARK: - Navigation Protocol

/// Protocol defining navigation behavior contract
@MainActor
protocol NavigationRouting: AnyObject {
    var path: [AppRoute] { get }
    var currentRoute: AppRoute? { get }
    var modalRoute: AppRoute? { get }

    /// Handle server navigation action
    func handle(action: ServerAction)
    
    /// Navigate to specific route with mode
    func navigate(to route: AppRoute, mode: NavigationMode)
    
    /// Push route onto stack
    func push(_ route: AppRoute)
    
    /// Present route modally
    func modal(_ route: AppRoute)
    
    /// Replace current route
    func replace(with route: AppRoute)
    
    /// Pop current route
    func pop()
    
    /// Reset navigation to specific route
    func reset(to route: AppRoute?)
    
    /// Dismiss current modal
    func dismissModal()
}

// MARK: - Navigation Router Implementation

@MainActor
final class NavigationRouter: ObservableObject, NavigationRouting {
    @Published var path: [AppRoute] = []
    @Published private(set) var modalRoute: AppRoute?

    var currentRoute: AppRoute? {
        path.last
    }

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
        case .push: push(route)
        case .modal: modal(route)
        case .replace: replace(with: route)
        }
    }

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func modal(_ route: AppRoute) {
        modalRoute = route
    }

    func replace(with route: AppRoute) {
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

// MARK: - Server Action Extensions

extension ServerAction {
    static func from(event: EventModel, currentAppId: String) -> ServerAction? {
        guard event.type == .onTap || event.type == .onSubmit || event.type == .onChange else {
            return nil
        }

        if let actions = event.params["actions"]?.arrayValue,
           !actions.isEmpty,
           let firstAction = actions.first?.objectValue {

            let rawType = firstAction["action"]?.stringValue ?? "navigate"
            let type = ActionType(rawValue: rawType) ?? .navigate
            let modeRaw = firstAction["mode"]?.stringValue ?? "push"
            let mode = NavigationModePayload(rawValue: modeRaw) ?? .push
            let targetAppId = firstAction["appId"]?.stringValue ?? currentAppId

            if let routeName = firstAction["route"]?.stringValue {
                let route = AppRoute(appId: targetAppId, screenName: routeName)
                return ServerAction(type: type, route: route, mode: mode)
            }
        }

        let rawType = event.params["type"]?.stringValue ?? event.params["actionType"]?.stringValue ?? "navigate"
        let type = ActionType(rawValue: rawType) ?? .navigate
        let modeRaw = event.params["mode"]?.stringValue ?? "push"
        let mode = NavigationModePayload(rawValue: modeRaw) ?? .push
        let targetAppId = event.params["appId"]?.stringValue ?? currentAppId

        if type == .navigateChain,
           let routeValues = event.params["routes"]?.arrayValue {
            let routes = routeValues.compactMap { $0.stringValue }.map { AppRoute(appId: targetAppId, screenName: $0) }
            return ServerAction(type: .navigateChain, routes: routes, mode: mode)
        }

        if let routeName = event.params["route"]?.stringValue {
            let route = AppRoute(appId: targetAppId, screenName: routeName)
            return ServerAction(type: type, route: route, mode: mode)
        }

        if let screenTarget = event.targets.first(where: { $0.hasPrefix("screen:") }) {
            let screenName = String(screenTarget.dropFirst("screen:".count))
            let route = AppRoute(appId: targetAppId, screenName: screenName)
            return ServerAction(type: .navigate, route: route, mode: mode)
        }

        return nil
    }
}
