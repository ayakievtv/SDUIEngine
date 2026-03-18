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
enum AppRoute: Hashable, Codable {
    case main                               // Root/main screen
    case screen(name: String)                // Named screen route

    /// Extract screen name for display purposes
    var screenName: String {
        switch self {
        case .main:
            return "main"
        case let .screen(name):
            return name
        }
    }

    /// Initialize with screen name, mapping "main" to main case
    init(screenName: String) {
        if screenName == "main" {
            self = .main
        } else {
            self = .screen(name: screenName)
        }
    }

    /// Custom decoder implementation for flexible route parsing
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

    /// Custom encoder implementation for route serialization
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

    /// Coding keys for route serialization
    private enum CodingKeys: String, CodingKey {
        case type
        case name
    }

    /// Internal route type for serialization
    private enum RouteType: String, Codable {
        case main
        case screen
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

/// Single source of truth for stack-based navigation state
@MainActor
final class NavigationRouter: ObservableObject, NavigationRouting {
    @Published var path: [AppRoute] = []
    @Published private(set) var modalRoute: AppRoute?

    /// Get current route from path
    var currentRoute: AppRoute? {
        path.last
    }

    /// Converts server intent into concrete stack mutations
    func handle(action: ServerAction) {
        print("🔍 DEBUG: NavigationRouter.handle called with action: \(action)")
        switch action.type {
        case .navigate:
            guard let route = action.route else { 
                print("❌ DEBUG: No route in navigate action")
                return 
            }
            if action.mode == .replace {
                print("🔍 DEBUG: Replacing with route: \(route)")
                replace(with: route)
            } else {
                print("🔍 DEBUG: Pushing route: \(route)")
                push(route)
            }
            
        case .navigateChain:
            let chain = action.routes
            guard !chain.isEmpty else { 
                print("❌ DEBUG: Empty route chain")
                return 
            }

            // Supports deep nested navigation when backend sends a full chain:
            // ["catalog", "product_42", "checkout"]
            if action.mode == .replace {
                print("🔍 DEBUG: Replacing with route chain: \(chain)")
                path.removeAll()
                chain.forEach { push($0) }
            } else {
                print("🔍 DEBUG: Pushing route chain: \(chain)")
                chain.forEach { push($0) }
            }
            
        case .pop:
            print("🔍 DEBUG: Popping current route")
            pop()
            
        case .popToRoot:
            print("🔍 DEBUG: Popping to root")
            path.removeAll()
        }
    }

    /// Navigate to route with specified mode
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

    /// Push route onto navigation stack
    func push(_ route: AppRoute) {
        print("🔍 DEBUG: Pushing route: \(route)")
        // "main" is a root route and should never live inside NavigationStack path
        if route == .main {
            print("🔍 DEBUG: Clearing path for main route")
            path.removeAll()
            return
        }
        path.append(route)
        print("🔍 DEBUG: Current path: \(path)")
    }

    /// Present route modally
    func modal(_ route: AppRoute) {
        modalRoute = route
    }

    /// Replace current route with new route
    func replace(with route: AppRoute) {
        // Replacing with root route means returning to root stack state
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

    /// Pop current route from stack
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Reset navigation to specific route
    func reset(to route: AppRoute?) {
        path = route.map { [$0] } ?? []
        modalRoute = nil
    }

    /// Dismiss current modal presentation
    func dismissModal() {
        modalRoute = nil
    }
}

// MARK: - Server Action Extensions

extension ServerAction {
    /// Maps event payload coming from SDUI components into a routing action
    static func from(event: EventModel) -> ServerAction? {
        print("🔍 DEBUG: ServerAction.from called with event: \(event)")
        print("🔍 DEBUG: Event type: \(event.type)")
        print("🔍 DEBUG: Event params: \(event.params)")
        print("🔍 DEBUG: Event targets: \(event.targets)")
        
        guard event.type == .onTap || event.type == .onSubmit || event.type == .onChange else {
            print("❌ DEBUG: Event type not supported for navigation: \(event.type)")
            return nil
        }

        // Handle actions array (new format)
        if let actions = event.params["actions"]?.arrayValue,
           !actions.isEmpty,
           let firstAction = actions.first?.objectValue {
            print("🔍 DEBUG: Processing actions array format")
            
            let rawType = firstAction["action"]?.stringValue ?? "navigate"
            let type = ActionType(rawValue: rawType) ?? .navigate
            
            let modeRaw = firstAction["mode"]?.stringValue ?? "push"
            let mode = NavigationModePayload(rawValue: modeRaw) ?? .push
            
            if let routeName = firstAction["route"]?.stringValue {
                let route = AppRoute(screenName: routeName)
                print("🔍 DEBUG: Created navigation from actions array - type: \(type), route: \(route), mode: \(mode)")
                return ServerAction(type: type, route: route, mode: mode)
            }
        }

        // Legacy format - direct params
        let rawType = event.params["type"]?.stringValue ?? event.params["actionType"]?.stringValue ?? "navigate"
        let type = ActionType(rawValue: rawType) ?? .navigate

        let modeRaw = event.params["mode"]?.stringValue ?? "push"
        let mode = NavigationModePayload(rawValue: modeRaw) ?? .push

        print("🔍 DEBUG: Parsed type: \(type), mode: \(mode)")

        // Handle navigation chain for multi-route navigation
        if type == .navigateChain,
           let routeValues = event.params["routes"]?.arrayValue {
            let routes = routeValues.compactMap { $0.stringValue }.map(AppRoute.init(screenName:))
            print("🔍 DEBUG: Created navigateChain with routes: \(routes)")
            return ServerAction(type: .navigateChain, routes: routes, mode: mode)
        }

        // Handle single route navigation
        if let routeName = event.params["route"]?.stringValue {
            let route = AppRoute(screenName: routeName)
            print("🔍 DEBUG: Created single route navigation to: \(route)")
            return ServerAction(type: type, route: route, mode: mode)
        }

        // Handle screen target navigation
        if let screenTarget = event.targets.first(where: { $0.hasPrefix("screen:") }) {
            let screenName = String(screenTarget.dropFirst("screen:".count))
            let route = AppRoute(screenName: screenName)
            print("🔍 DEBUG: Created screen target navigation to: \(route)")
            return ServerAction(type: .navigate, route: route, mode: mode)
        }

        print("❌ DEBUG: No valid navigation parameters found")
        return nil
    }
}
