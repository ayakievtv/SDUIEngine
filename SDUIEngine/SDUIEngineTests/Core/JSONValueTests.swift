import XCTest
@testable import SDUIEngine

final class JSONValueTests: XCTestCase {

    // MARK: - Тесты на декодирование из нестандартного JSON

    func testDecode_NestedArrays() throws {
        let json = """
        {
            "nested": [1, "two", true, [3, 4], {"key": "value"}]
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: data)
        
        XCTAssertNotNil(decoded["nested"]?.arrayValue)
        XCTAssertEqual(decoded["nested"]?.arrayValue?.count, 5)
        
        if let nested = decoded["nested"]?.arrayValue {
            XCTAssertEqual(nested[0].numberValue, 1)
            XCTAssertEqual(nested[1].stringValue, "two")
            XCTAssertEqual(nested[2].boolValue, true)
            XCTAssertNotNil(nested[3].arrayValue)
            XCTAssertNotNil(nested[4].objectValue)
            XCTAssertEqual(nested[4].objectValue?["key"]?.stringValue, "value")
        }
    }

    func testDecode_MixedTypesArray() throws {
        let json = """
        [null, "string", 42, true, {"a": 1}, [1, 2, 3]]
        """
        
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([JSONValue].self, from: data)
        
        XCTAssertEqual(decoded.count, 6)
        XCTAssertEqual(decoded[0], .null)
        XCTAssertEqual(decoded[1], .string("string"))
        XCTAssertEqual(decoded[2], .number(42))
        XCTAssertEqual(decoded[3], .bool(true))
        XCTAssertNotNil(decoded[4].objectValue)
        XCTAssertNotNil(decoded[5].arrayValue)
    }

    func testDecode_ComplexNestedObject() throws {
        let json = """
        {
            "level1": {
                "level2": {
                    "level3": ["a", "b", {"deep": true}]
                }
            }
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: data)
        
        XCTAssertNotNil(decoded["level1"]?.objectValue)
        
        if let level1 = decoded["level1"]?.objectValue,
           let level2 = level1["level2"]?.objectValue,
           let level3 = level2["level3"]?.arrayValue {
            
            XCTAssertEqual(level3.count, 3)
            XCTAssertEqual(level3[0].stringValue, "a")
            XCTAssertEqual(level3[1].stringValue, "b")
            XCTAssertNotNil(level3[2].objectValue)
            XCTAssertEqual(level3[2].objectValue?["deep"]?.boolValue, true)
        }
    }

    // MARK: - Тесты на обработку ошибочных payloads
    //
    // ИСПРАВЛЕНО и СВЕРЕНО с реальным JSONValue.init(from:): порядок проб в
    // декодере — String → Double → Bool → Array → Object, но это не влияет
    // на корректность тестов ниже, так как типы JSON синтаксически однозначны
    // (строка всегда в кавычках, число/bool — нет), а singleValueContainer
    // строго типизирован (decode(String.self) от числа или decode(Bool.self)
    // от строки "true" всегда бросает typeMismatch внутри try?, а не коэрсит
    // значение). Поэтому decode(...) НЕ бросает ошибку из-за "несовпадения
    // типа" — любое валидное JSON-значение успешно ложится в свой case.
    // Несовпадение типа проверяется через типизированные accessor'ы
    // (stringValue/numberValue/boolValue), которые в этом случае возвращают
    // nil. Ниже — исправленные версии трёх тестов (testDecode_InvalidTypeInsteadOf...),
    // которые ошибочно ожидали throw, плюс тесты на реально невалидный JSON,
    // где throw действительно необходим (синтаксическая ошибка, top-level
    // скаляр вместо объекта, пустые данные).

    func testDecode_NumberValue_doesNotExposeStringAccessor() throws {
        // {"key": 123} успешно декодируется как .number(123);
        // stringValue для числа должен вернуть nil, а не бросать ошибку
        let json = """
        {"key": 123}
        """
        let data = json.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: data)

        XCTAssertEqual(decoded["key"], .number(123))
        XCTAssertEqual(decoded["key"]?.numberValue, 123)
        XCTAssertNil(decoded["key"]?.stringValue)
        XCTAssertNil(decoded["key"]?.boolValue)
    }

    func testDecode_StringValue_doesNotExposeNumberAccessor() throws {
        // {"key": "not a number"} успешно декодируется как .string(...);
        // numberValue должен вернуть nil, а не бросать ошибку
        let json = """
        {"key": "not a number"}
        """
        let data = json.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: data)

        XCTAssertEqual(decoded["key"], .string("not a number"))
        XCTAssertNil(decoded["key"]?.numberValue)
    }

    func testDecode_StringValue_doesNotExposeBoolAccessor() throws {
        // {"key": "true"} — это строка "true", а не булево значение;
        // boolValue должен вернуть nil, а не бросать ошибку и не коэрсить строку в Bool
        let json = """
        {"key": "true"}
        """
        let data = json.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: data)

        XCTAssertEqual(decoded["key"], .string("true"))
        XCTAssertNil(decoded["key"]?.boolValue)
    }

    func testDecode_MalformedJSONSyntax_throws() {
        // Синтаксически невалидный JSON — вот здесь decode обязан бросить ошибку
        let json = "{ this is not valid json }"
        let data = json.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode([String: JSONValue].self, from: data)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testDecode_TopLevelScalar_whenKeyedContainerExpected_throws() {
        // Верхнеуровневый JSON — просто число 42, а не объект;
        // decode как [String: JSONValue] обязан бросить ошибку несоответствия контейнера
        let json = "42"
        let data = json.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode([String: JSONValue].self, from: data)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testDecode_EmptyData_throws() {
        // Пустые данные не являются валидным JSON ни при каких условиях
        let data = Data()

        XCTAssertThrowsError(try JSONDecoder().decode([String: JSONValue].self, from: data)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    // MARK: - Тесты на Equatable

    func testEquatable_Null() {
        let value1: JSONValue = .null
        let value2: JSONValue = .null
        
        XCTAssertEqual(value1, value2)
    }

    func testEquatable_String() {
        let value1: JSONValue = .string("hello")
        let value2: JSONValue = .string("hello")
        let value3: JSONValue = .string("world")
        
        XCTAssertEqual(value1, value2)
        XCTAssertNotEqual(value1, value3)
    }

    func testEquatable_Number() {
        let value1: JSONValue = .number(42.0)
        let value2: JSONValue = .number(42.0)
        let value3: JSONValue = .number(43.0)
        
        XCTAssertEqual(value1, value2)
        XCTAssertNotEqual(value1, value3)
    }

    func testEquatable_Bool() {
        let value1: JSONValue = .bool(true)
        let value2: JSONValue = .bool(true)
        let value3: JSONValue = .bool(false)
        
        XCTAssertEqual(value1, value2)
        XCTAssertNotEqual(value1, value3)
    }

    func testEquatable_Array() {
        let array1: [JSONValue] = [.string("a"), .number(1), .bool(true)]
        let array2: [JSONValue] = [.string("a"), .number(1), .bool(true)]
        let array3: [JSONValue] = [.string("b"), .number(1), .bool(true)]
        
        XCTAssertEqual(JSONValue.array(array1), JSONValue.array(array2))
        XCTAssertNotEqual(JSONValue.array(array1), JSONValue.array(array3))
    }

    func testEquatable_Object() {
        let object1: [String: JSONValue] = ["a": .string("value"), "b": .number(1)]
        let object2: [String: JSONValue] = ["a": .string("value"), "b": .number(1)]
        let object3: [String: JSONValue] = ["a": .string("other"), "b": .number(1)]
        
        XCTAssertEqual(JSONValue.object(object1), JSONValue.object(object2))
        XCTAssertNotEqual(JSONValue.object(object1), JSONValue.object(object3))
    }

    func testEquatable_ComplexNested() {
        let nested1: [String: JSONValue] = [
            "array": .array([.string("x"), .number(1)]),
            "object": .object(["key": .string("value")])
        ]
        let nested2: [String: JSONValue] = [
            "array": .array([.string("x"), .number(1)]),
            "object": .object(["key": .string("value")])
        ]
        
        XCTAssertEqual(JSONValue.object(nested1), JSONValue.object(nested2))
    }

    // MARK: - Тесты на кодирование

    func testEncodeDecode_RoundTrip() throws {
        let original: [String: JSONValue] = [
            "null": .null,
            "string": .string("test"),
            "number": .number(3.14),
            "bool": .bool(false),
            "array": .array([.string("a"), .number(2)]),
            "object": .object(["nested": .string("value")])
        ]
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: encoded)
        
        XCTAssertEqual(original, decoded)
    }
}
