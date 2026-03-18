import XCTest
@testable import SDUIEngine

@MainActor
final class NavigationSpy: NavigationRouting {
    var path: [AppRoute] = []
    var currentRoute: AppRoute? { path.last }
    var modalRoute: AppRoute?

    private(set) var pushes: [AppRoute] = []
    private(set) var modals: [AppRoute] = []
    private(set) var replaces: [AppRoute] = []
    private(set) var popCount = 0

    func handle(action: ServerAction) {
        switch action.type {
        case .navigate:
            if let route = action.route {
                push(route)
            }
        case .navigateChain:
            for route in action.routes {
                push(route)
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
        pushes.append(route)
        path.append(route)
    }

    func modal(_ route: AppRoute) {
        modals.append(route)
        modalRoute = route
    }

    func replace(with route: AppRoute) {
        replaces.append(route)
        if path.isEmpty {
            path = [route]
        } else {
            path[path.count - 1] = route
        }
    }

    func pop() {
        popCount += 1
        if !path.isEmpty {
            _ = path.removeLast()
        }
    }

    func reset(to route: AppRoute?) {
        path = route.map { [$0] } ?? []
    }

    func dismissModal() {
        modalRoute = nil
    }
}

final class RecordingAPIClient: APIClient {
    struct RequestRecord {
        let endpoint: String
        let method: HTTPMethod
        let body: [String: JSONValue]?
    }

    var onRequest: ((String, HTTPMethod, [String: JSONValue]?) async throws -> JSONValue)?
    private(set) var requests: [RequestRecord] = []

    func request(endpoint: String, method: HTTPMethod, body: [String: JSONValue]?) async throws -> JSONValue {
        requests.append(RequestRecord(endpoint: endpoint, method: method, body: body))
        if let onRequest {
            return try await onRequest(endpoint, method, body)
        }
        return .object([:])
    }
}

actor RemoteStub: RemoteRequesting {
    enum StubError: Error {
        case forced
    }

    struct PlanItem {
        let result: Result<JSONValue, Error>
    }

    private var plan: [PlanItem]
    private(set) var callCount = 0

    init(plan: [PlanItem]) {
        self.plan = plan
    }

    func request(endpoint: String, method: HTTPMethod, body: [String : JSONValue]?) async throws -> JSONValue {
        callCount += 1
        if !plan.isEmpty {
            let item = plan.removeFirst()
            return try item.result.get()
        }
        return .object(["ok": .bool(true)])
    }
}

func makeActionEvent(type: EventType = .onTap, actions: [[String: JSONValue]], targets: [String] = ["test_component"]) -> EventModel {
    let actionValues = actions.map { JSONValue.object($0) }
    return EventModel(type: type, targets: targets, params: ["actions": .array(actionValues)])
}

func waitUntil(
    timeout: TimeInterval = 1.5,
    poll: UInt64 = 20_000_000,
    condition: @escaping @MainActor () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await MainActor.run(body: condition) {
            return
        }
        try? await Task.sleep(nanoseconds: poll)
    }
}
