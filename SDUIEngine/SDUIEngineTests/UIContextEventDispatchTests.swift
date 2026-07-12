import XCTest
@testable import SDUIEngine

/// Тесты для проверки механизма диспетчеризации событий в UIContext
/// Проверяет, что события корректно распределяются между компонентами
@MainActor
final class UIContextEventDispatchTests: XCTestCase {

    /// Тест проверяет, что цепочка действий (action chain) корректно распределяется по нескольким целевым компонентам
    /// Каждое действие в цепочке должно быть доставлено ровно один раз каждому указанному компоненту
    func testActionChainDispatchesToMultipleTargetsOnceEach() async {
        // Создаем мок-объекты для тестирования
        let api = RecordingAPIClient()
        let navigation = NavigationSpy()
        let componentStore = ComponentStore()

        // Создаем контекст с тестовыми зависимостями
        let context = UIContext(
            navigation: navigation,
            apiClient: api,
            componentStore: componentStore
        )

        // Массив для записи полученных действий и их параметров
        var received: [(String, [String: String]?)] = []

        // Регистрируем тестовые компоненты, которые будут записывать полученные действия
        componentStore.register(componentID: "title_text", component: AnyComponent { action, params in
            received.append((action, params))
        })
        componentStore.register(componentID: "subtitle_text", component: AnyComponent { action, params in
            received.append((action, params))
        })

        // Создаем событие с цепочкой из двух действий:
        // 1. Действие SET_TEXT для компонента title_text с параметром value="Hello"
        // 2. Действие SET_COLOR для компонентов title_text и subtitle_text с параметром value="#00AAFF"
        let event = makeActionEvent(actions: [
            [
                "target": .string("title_text"),
                "action": .string("SET_TEXT"),
                "value": .string("Hello")
            ],
            [
                "targets": .array([.string("title_text"), .string("subtitle_text")]),
                "action": .string("SET_COLOR"),
                "value": .string("#00AAFF")
            ]
        ])

        // Отправляем событие через контекст
        context.dispatch(event)

        // Проверяем, что всего было получено 3 действия:
        // - SET_TEXT для title_text
        // - SET_COLOR для title_text
        // - SET_COLOR для subtitle_text
        XCTAssertEqual(received.count, 3)

        // Проверяем порядок и типы полученных действий
        XCTAssertEqual(received.map(\.0), ["SET_TEXT", "SET_COLOR", "SET_COLOR"])

        // Проверяем параметры каждого действия
        XCTAssertEqual(received[0].1?["value"], "Hello")        // SET_TEXT с value="Hello"
        XCTAssertEqual(received[1].1?["value"], "#00AAFF")      // SET_COLOR с value="#00AAFF" для title_text
        XCTAssertEqual(received[2].1?["value"], "#00AAFF")      // SET_COLOR с value="#00AAFF" для subtitle_text
    }
}
