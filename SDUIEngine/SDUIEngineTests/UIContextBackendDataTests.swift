import XCTest
@testable import SDUIEngine

/// Тесты для проверки работы UIContext с бэкенд-данными (OPEN_FORM, SAVE_FORM, DISCARD_FORM)
/// Проверяет интеграцию с API и управление состоянием формы
@MainActor
final class UIContextBackendDataTests: XCTestCase {

    /// Тест проверяет загрузку данных формы через OPEN_FORM action
    /// Проверяет:
    /// - Подстановку ID в endpoint URL
    /// - Загрузку данных с сервера
    /// - Сохранение загруженных данных в state с правильным префиксом
    func testOpenFormLoadsPayloadIntoStateWithIDReplacement() async {
        // Создаем мок-объекты для тестирования
        let api = RecordingAPIClient()
        let navigation = NavigationSpy()
        let context = UIContext(navigation: navigation, apiClient: api)

        // Устанавливаем ID накладной в state (будет подставлен в URL)
        context.setState(key: "invoiceForm.id", value: .string("abc-123"))

        // Настраиваем мок API: при запросе возвращаем тестовые данные накладной
        api.onRequest = { endpoint, method, _ in
            XCTAssertEqual(method, .get)
            XCTAssertTrue(endpoint.hasSuffix("/abc-123"))
            return .object([
                "items": .array([
                    .object([
                        "uuid": .string("abc-123"),
                        "doc_number": .string("INV-42"),
                        "customer_name": .string("ACME")
                    ])
                ])
            ])
        }

        // Создаем событие OPEN_FORM с параметрами:
        // - target: backend_data (системная цель для работы с данными)
        // - action: OPEN_FORM
        // - endpoint: URL с плейсхолдером {id}
        // - idStateKey: ключ state, откуда брать ID для подстановки
        // - formStatePrefix: префикс для сохранения данных формы в state
        // - clearPreviousDraft: флаг очистки старых данных перед загрузкой
        let event = makeActionEvent(actions: [[
            "target": .string("backend_data"),
            "action": .string("OPEN_FORM"),
            "endpoint": .string("https://example.com/invoices/{id}"),
            "idStateKey": .string("invoiceForm.id"),
            "formStatePrefix": .string("invoiceForm"),
            "clearPreviousDraft": .string("true")
        ]])

        // Отправляем событие
        context.dispatch(event)

        // Ждем, пока данные будут загружены и сохранены в state
        await waitUntil {
            context.stateValue(for: "invoiceForm.doc_number")?.stringValue == "INV-42"
        }

        // Проверяем, что все поля формы сохранены в state с правильным префиксом
        XCTAssertEqual(context.stateValue(for: "invoiceForm.customer_name")?.stringValue, "ACME")
        XCTAssertEqual(context.stateValue(for: "invoiceForm.uuid")?.stringValue, "abc-123")
    }

    /// Тест проверяет сохранение данных формы через SAVE_FORM action
    /// Проверяет:
    /// - Автоматическое определение префикса формы из idStateKey
    /// - Подстановку ID в endpoint URL
    /// - Отправку данных формы на сервер
    func testSaveFormWorksWithoutFormStatePrefixUsingIdStateKeyInference() async {
        // Создаем мок-объекты
        let api = RecordingAPIClient()
        let navigation = NavigationSpy()
        let context = UIContext(navigation: navigation, apiClient: api)

        // Устанавливаем начальные данные формы в state
        context.setState(key: "invoiceForm.id", value: .string("id-77"))
        context.setState(key: "invoiceForm.doc_number", value: .string("INV-77"))
        context.setState(key: "invoiceForm.status", value: .string("NEW"))

        // Создаем событие SAVE_FORM:
        // - target: backend_data
        // - action: SAVE_FORM
        // - endpoint: URL с плейсхолдером {id}
        // - idStateKey: ключ для получения ID
        // - method: HTTP метод (PUT)
        // Примечание: formStatePrefix не указан, будет выведен из idStateKey ("invoiceForm")
        let event = makeActionEvent(actions: [[
            "target": .string("backend_data"),
            "action": .string("SAVE_FORM"),
            "endpoint": .string("https://example.com/invoices/{id}"),
            "idStateKey": .string("invoiceForm.id"),
            "method": .string("PUT")
        ]])

        // Отправляем событие
        context.dispatch(event)

        // Ждем выполнения запроса
        await waitUntil {
            api.requests.count == 1
        }

        // Получаем первый (и единственный) запрос
        guard let first = api.requests.first else {
            return XCTFail("Expected one save request")
        }

        // Проверяем параметры запроса:
        // - HTTP метод должен быть PUT
        // - URL должен содержать ID
        // - Тело запроса должно содержать данные формы
        XCTAssertEqual(first.method, .put)
        XCTAssertTrue(first.endpoint.hasSuffix("/id-77"))
        XCTAssertEqual(first.body?["doc_number"]?.stringValue, "INV-77")
        XCTAssertEqual(first.body?["status"]?.stringValue, "NEW")
    }

    /// Тест проверяет отмену формы через DISCARD_FORM action
    /// Проверяет:
    /// - Очистку всех полей формы с указанным префиксом
    /// - Возврат назад (goBack) при наличии флага
    func testDiscardFormClearsPrefixAndCanGoBack() async {
        // Создаем мок-объекты
        let api = RecordingAPIClient()
        let navigation = NavigationSpy()
        navigation.push(.screen(name: "invoice_edit_form"))

        let context = UIContext(navigation: navigation, apiClient: api)

        // Устанавливаем данные формы в state
        context.setState(key: "invoiceForm.doc_number", value: .string("INV-100"))
        context.setState(key: "invoiceForm.customer_name", value: .string("Old customer"))

        // Создаем событие DISCARD_FORM:
        // - target: backend_data
        // - action: DISCARD_FORM
        // - formStatePrefix: префикс полей формы для очистки
        // - goBack: флаг возврата назад
        let event = makeActionEvent(actions: [[
            "target": .string("backend_data"),
            "action": .string("DISCARD_FORM"),
            "formStatePrefix": .string("invoiceForm"),
            "goBack": .string("true")
        ]])

        // Отправляем событие
        context.dispatch(event)

        // Ждем, пока поля формы будут очищены
        await waitUntil {
            context.stateValue(for: "invoiceForm.doc_number")?.stringValue == ""
        }

        // Проверяем:
        // - Все поля формы очищены
        // - Выполнен возврат назад (pop)
        XCTAssertEqual(context.stateValue(for: "invoiceForm.customer_name")?.stringValue, "")
        XCTAssertEqual(navigation.popCount, 1)
    }
}
