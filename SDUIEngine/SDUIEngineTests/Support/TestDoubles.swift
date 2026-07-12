import XCTest
@testable import SDUIEngine

/// Тестовый шпион для отслеживания навигационных действий
/// Реализует протокол NavigationRouting и записывает все вызовы для проверки в тестах
@MainActor
final class NavigationSpy: NavigationRouting {
    /// Стек маршрутов навигации
    var path: [AppRoute] = []

    /// Текущий маршрут (последний в стеке)
    var currentRoute: AppRoute? { path.last }

    /// Текущий модальный маршрут
    var modalRoute: AppRoute?

    /// История push-операций
    private(set) var pushes: [AppRoute] = []

    /// История modal-операций
    private(set) var modals: [AppRoute] = []

    /// История replace-операций
    private(set) var replaces: [AppRoute] = []

    /// Счетчик pop-операций
    private(set) var popCount = 0

    /// Обрабатывает серверные действия навигации (ServerAction)
    /// - .navigate: добавляет маршрут в стек
    /// - .navigateChain: добавляет несколько маршрутов в стек
    /// - .pop: удаляет последний маршрут из стека
    /// - .popToRoot: очищает стек маршрутов
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

    /// Навигация к маршруту с указанным режимом
    func navigate(to route: AppRoute, mode: NavigationMode) {
        switch mode {
        case .push: push(route)
        case .modal: modal(route)
        case .replace: replace(with: route)
        }
    }

    /// Добавляет маршрут в стек (push)
    func push(_ route: AppRoute) {
        pushes.append(route)
        path.append(route)
    }

    /// Открывает модальное окно с маршрутом
    func modal(_ route: AppRoute) {
        modals.append(route)
        modalRoute = route
    }

    /// Заменяет текущий маршрут на новый
    func replace(with route: AppRoute) {
        replaces.append(route)
        if path.isEmpty {
            path = [route]
        } else {
            path[path.count - 1] = route
        }
    }

    /// Удаляет последний маршрут из стека (pop/back)
    func pop() {
        popCount += 1
        if !path.isEmpty {
            _ = path.removeLast()
        }
    }

    /// Сбрасывает стек маршрутов к указанному маршруту
    func reset(to route: AppRoute?) {
        path = route.map { [$0] } ?? []
    }

    /// Закрывает модальное окно
    func dismissModal() {
        modalRoute = nil
    }
}

/// Тестовый клиент API, записывающий все запросы для последующей проверки
/// Позволяет настраивать ответы через замыкание onRequest
final class RecordingAPIClient: APIClient {
    /// Запись одного запроса с параметрами
    struct RequestRecord {
        let endpoint: String
        let method: HTTPMethod
        let body: [String: JSONValue]?
    }

    /// Замыкание для настройки кастомных ответов на запросы
    /// Принимает endpoint, метод и тело запроса, возвращает JSONValue
    var onRequest: ((String, HTTPMethod, [String: JSONValue]?) async throws -> JSONValue)?

    /// История всех выполненных запросов
    private(set) var requests: [RequestRecord] = []

    /// Выполняет запрос и записывает его в историю
    /// Если задан onRequest, использует его для генерации ответа
    /// Иначе возвращает пустой объект
    func request(endpoint: String, method: HTTPMethod, body: [String: JSONValue]?) async throws -> JSONValue {
        requests.append(RequestRecord(endpoint: endpoint, method: method, body: body))
        if let onRequest {
            return try await onRequest(endpoint, method, body)
        }
        return .object([:])
    }
}

/// Заглушка удаленного сервера с планируемыми ответами
/// Позволяет тестировать различные сценарии (успех, ошибка, последовательность ответов)
actor RemoteStub: RemoteRequesting {
    /// Ошибка заглушки
    enum StubError: Error {
        case forced
    }

    /// Элемент плана ответа - содержит результат (успех или ошибка)
    struct PlanItem {
        let result: Result<JSONValue, Error>
    }

    /// План ответов - последовательность результатов, которые будут возвращены
    private var plan: [PlanItem]

    /// Счетчик вызовов request
    private(set) var callCount = 0

    /// Инициализирует заглушку с планом ответов
    init(plan: [PlanItem]) {
        self.plan = plan
    }

    /// Выполняет запрос и возвращает следующий результат из плана
    /// Если план пуст, возвращает успешный ответ по умолчанию
    func request(endpoint: String, method: HTTPMethod, body: [String : JSONValue]?) async throws -> JSONValue {
        callCount += 1
        if !plan.isEmpty {
            let item = plan.removeFirst()
            return try item.result.get()
        }
        return .object(["ok": .bool(true)])
    }
}

/// Создает EventModel с цепочкой действий для тестирования
/// - Parameters:
///   - type: тип события (по умолчанию .onTap)
///   - actions: массив действий, где каждое действие - словарь с параметрами
///   - targets: целевые компоненты для события
/// - Returns: сформиррованный EventModel
func makeActionEvent(type: EventType = .onTap, actions: [[String: JSONValue]], targets: [String] = ["test_component"]) -> EventModel {
    let actionValues = actions.map { JSONValue.object($0) }
    return EventModel(type: type, targets: targets, params: ["actions": .array(actionValues)])
}

/// Ожидает выполнения асинхронного условия в течение указанного времени
/// - Parameters:
///   - timeout: таймаут ожидания в секундах (по умолчанию 1.5)
///   - poll: интервал опроса в наносекундах (по умолчанию 20ms)
///   - condition: асинхронное замыкание, возвращающее Bool (выполнено ли условие)
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
