import XCTest
@testable import SDUIEngine

/// Тестовая структура для представления строки таблицы данных
/// Содержит уникальный идентификатор и полезную нагрузку (данные строки)
private struct TestGridRow {
    let id: String
    let payload: [String: JSONValue]
}

/// Тестовый парсер для разбора ответов сервера с данными таблицы (DBGrid)
/// Имитирует логику парсинга, аналогичную DBGridComponent
private enum TestDBGridParser {
    /// Парсит ответ сервера и извлекает строки данных, курсор пагинации и флаг наличия дополнительных данных
    /// - Parameters:
    ///   - response: JSON-ответ от сервера
    ///   - keyField: поле, используемое как уникальный идентификатор строки
    ///   - pageSize: размер страницы для определения наличия дополнительных данных
    /// - Returns: кортеж с массивом строк, курсором пагинации и флагом наличия дополнительных данных
    static func parseRows(
        response: JSONValue,
        keyField: String,
        pageSize: Int
    ) -> (rows: [TestGridRow], nextCursor: String?, hasMore: Bool) {
        // Обработка ответа в формате объекта (стандартный формат с полем "items")
        if let object = response.objectValue {
            // Извлекаем массив элементов из ответа
            let items = object["items"]?.arrayValue ?? []

            // Преобразуем каждый элемент в TestGridRow
            let rows: [TestGridRow] = items.enumerated().compactMap { index, item in
                guard let payload = item.objectValue else { return nil }

                // Пытаемся получить ID из указанного поля, затем из стандартных полей "id" или "uuid"
                // Если ни одно не найдено, используем сгенерированный ID на основе индекса
                let id = payload[keyField]?.stringValue
                    ?? payload["id"]?.stringValue
                    ?? payload["uuid"]?.stringValue
                    ?? "row_\(index)"
                return TestGridRow(id: id, payload: payload)
            }

            // Извлекаем курсор пагинации из различных возможных полей
            let nextCursor = object["nextCursor"]?.stringValue
                ?? object["offset"]?.stringValue
                ?? object["cursor"]?.stringValue

            // Определяем наличие дополнительных данных:
            // - если есть nextCursor
            // - или если количество строк >= размеру страницы
            // - или если явно указано hasMore
            let hasMore = object["hasMore"]?.boolValue ?? ((nextCursor != nil) || rows.count >= pageSize)
            return (rows, nextCursor, hasMore)
        }

        // Обработка ответа в формате массива (упрощенный формат без обертки)
        if let array = response.arrayValue {
            let rows: [TestGridRow] = array.enumerated().compactMap { index, item in
                guard let payload = item.objectValue else { return nil }
                let id = payload[keyField]?.stringValue
                    ?? payload["id"]?.stringValue
                    ?? payload["uuid"]?.stringValue
                    ?? "row_\(index)"
                return TestGridRow(id: id, payload: payload)
            }
            // Для массива hasMore определяется только по размеру страницы
            return (rows, nil, rows.count >= pageSize)
        }

        // Если формат ответа не распознан, возвращаем пустые данные
        return ([], nil, false)
    }
}

/// Тестовая утилита для интерполяции строковых шаблонов с подстановкой значений из payload
/// Имитирует логику интерполяции, используемую в компонентах для отображения динамического текста
private enum TestInterpolation {
    /// Рендерит шаблон, заменяя плейсхолдеры {{key}} на соответствующие значения из payload
    /// - Parameters:
    ///   - template: строка с плейсхолдерами в формате {{key}} или {{nested.key}}
    ///   - payload: словарь с данными для подстановки
    /// - Returns: строка с подставленными значениями
    static func render(_ template: String, payload: [String: JSONValue]) -> String {
        var output = template

        // Ищем все плейсхолдеры в формате {{...}} и заменяем их на значения из payload
        while let open = output.range(of: "{{"),
              let close = output.range(of: "}}", range: open.upperBound..<output.endIndex) {
            // Извлекаем ключ между {{ и }}
            let key = output[open.upperBound..<close.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)

            // Получаем строковое представление значения для этого ключа
            let replacement = payloadString(payload: payload, key: key)

            // Заменяем плейсхолдер на значение
            output.replaceSubrange(open.lowerBound..<close.upperBound, with: replacement)
        }
        return output
    }

    /// Извлекает строковое представление значения из payload по ключу (включая вложенные ключи)
    /// - Parameters:
    ///   - payload: словарь с данными
    ///   - key: ключ, возможно с точечной нотацией для вложенных объектов (например, "meta.status")
    /// - Returns: строковое представление значения или пустая строка, если значение не найдено
    private static func payloadString(payload: [String: JSONValue], key: String) -> String {
        // Разбиваем ключ по точкам для поддержки вложенных объектов
        let segments = key.split(separator: ".").map(String.init)
        guard !segments.isEmpty else { return "" }

        // Начинаем с корневого объекта payload
        var current: JSONValue? = .object(payload)

        // Проходим по всем сегментам ключа
        for segment in segments {
            guard let object = current?.objectValue else { return "" }
            current = object[segment]
        }

        // Преобразуем finale значение в строку
        if let string = current?.stringValue { return string }
        if let number = current?.numberValue { return String(number) }
        if let bool = current?.boolValue { return bool ? "true" : "false" }
        return ""
    }
}

/// Тесты для проверки парсинга данных таблицы (DBGrid) и интерполяции строковых шаблонов
final class DBGridParsingInterpolationTests: XCTestCase {

    /// Тест проверяет парсинг ответа сервера в стандартном формате с полями items, nextCursor, hasMore
    func testDBGridParsingWithItemsNextCursorAndHasMore() {
        // Создаем тестовый ответ сервера с данными таблицы
        let response: JSONValue = .object([
            "items": .array([
                .object([
                    "uuid": .string("u-1"),
                    "doc_number": .string("INV-1"),
                    "customer_name": .string("ACME")
                ]),
                .object([
                    "uuid": .string("u-2"),
                    "doc_number": .string("INV-2"),
                    "customer_name": .string("Beta")
                ])
            ]),
            "nextCursor": .string("offset:2"),
            "hasMore": .bool(true)
        ])

        // Парсим ответ
        let parsed = TestDBGridParser.parseRows(response: response, keyField: "uuid", pageSize: 20)

        // Проверяем результаты парсинга:
        XCTAssertEqual(parsed.rows.count, 2)  // Две строки данных
        XCTAssertEqual(parsed.rows[0].id, "u-1")  // ID первой строки
        XCTAssertEqual(parsed.rows[1].payload["doc_number"]?.stringValue, "INV-2")  // Поле второй строки
        XCTAssertEqual(parsed.nextCursor, "offset:2")  // Курсор пагинации
        XCTAssertTrue(parsed.hasMore)  // Флаг наличия дополнительных данных
    }

    /// Тест проверяет интерполяцию строковых шаблонов с подстановкой значений,
    /// включая вложенные объекты (например, {{meta.status}})
    func testInterpolationResolvesNestedPlaceholders() {
        // Создаем тестовые данные с вложенным объектом
        let payload: [String: JSONValue] = [
            "doc_number": .string("INV-9"),
            "customer_name": .string("Client X"),
            "meta": .object(["status": .string("PAID")])
        ]

        // Рендерим шаблоны с разными типами плейсхолдеров
        let title = TestInterpolation.render("Invoice {{doc_number}}", payload: payload)
        let subtitle = TestInterpolation.render("{{customer_name}}", payload: payload)
        let caption = TestInterpolation.render("{{meta.status}}", payload: payload)

        // Проверяем результаты интерполяции
        XCTAssertEqual(title, "Invoice INV-9")  // Подстановка простого поля
        XCTAssertEqual(subtitle, "Client X")  // Подстановка простого поля
        XCTAssertEqual(caption, "PAID")  // Подстановка вложенного поля
    }
}
