import Foundation

enum NavigationMode {
    case push
    case modal
    case replace
}

protocol NavigationRouting: AnyObject {
    var path: [String] { get }
    var currentRoute: String? { get }
    var modalRoute: String? { get }

    func navigate(to route: String, mode: NavigationMode)
    func push(_ route: String)
    func modal(_ route: String)
    func replace(with route: String)
    func pop()
    func reset(to route: String?)
    func dismissModal()
}

final class NavigationEngine: NavigationRouting {
    private(set) var path: [String] = []
    private(set) var modalRoute: String?

    var currentRoute: String? {
        path.last
    }

    func navigate(to route: String, mode: NavigationMode) {
        switch mode {
        case .push:
            push(route)
        case .modal:
            modal(route)
        case .replace:
            replace(with: route)
        }
    }

    func push(_ route: String) {
        path.append(route)
    }

    func modal(_ route: String) {
        modalRoute = route
    }

    func replace(with route: String) {
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

    func reset(to route: String?) {
        path = route.map { [$0] } ?? []
        modalRoute = nil
    }

    func dismissModal() {
        modalRoute = nil
    }
}
