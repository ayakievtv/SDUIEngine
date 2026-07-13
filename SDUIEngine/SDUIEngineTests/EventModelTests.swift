import XCTest
@testable import SDUIEngine

// MARK: - EventType

/// Тесты перечисления типов локальных UI-событий
final class EventTypeTests: XCTestCase {

    func test_allCases_containsExpectedFiveTypes() {
        // Проверяем полный набор поддерживаемых триггеров
        let expected: Set<EventType> = [.onTap, .onAppear, .onDisappear, .onChange, .onSubmit]
        XCTAssertEqual(Set(EventType.allCases), expected)
        XCTAssertEqual(EventType.allCases.count, 5)
    }

    func test_rawValues_matchJSONContract() {
        // rawValue используется как ключ в JSON ("onTap", "onChange" и т.д.) — не должен случайно измениться
        XCTAssertEqual(EventType.onTap.rawValue, "onTap")
        XCTAssertEqual(EventType.onAppear.rawValue, "onAppear")
        XCTAssertEqual(EventType.onDisappear.rawValue, "onDisappear")
        XCTAssertEqual(EventType.onChange.rawValue, "onChange")
        XCTAssertEqual(EventType.onSubmit.rawValue, "onSubmit")
    }
}

// MARK: - ComponentEventTrigger

/// Тесты перечисления триггеров бэкенд-действий
final class ComponentEventTriggerTests: XCTestCase {

    func test_rawValues_matchBackendContract() {
        // Бэкенд присылает триггеры в верхнем регистре с подчёркиванием — фиксируем контракт
        XCTAssertEqual(ComponentEventTrigger.onInit.rawValue, "ON_INIT")
        XCTAssertEqual(ComponentEventTrigger.onTap.rawValue, "ON_TAP")
        XCTAssertEqual(ComponentEventTrigger.onChange.rawValue, "ON_CHANGE")
    }

    func test_allCases_count() {
        XCTAssertEqual(ComponentEventTrigger.allCases.count, 3)
    }
}

// MARK: - ComponentEvent (Codable)

/// Тесты декодирования динамических действий бэкенда
final class ComponentEventTests: XCTestCase {

    func test_decode_fullPayload() throws {
        let json = """
        {
          "trigger": "ON_INIT",
          "targets": ["dataset1"],
          "action": "REFRESH",
          "params": { "USERID": "@USERID" }
        }
        """
        let event = try JSONDecoder().decode(ComponentEvent.self, from: Data(json.utf8))

        XCTAssertEqual(event.trigger, "ON_INIT")
        XCTAssertEqual(event.targets, ["dataset1"])
        XCTAssertEqual(event.action, "REFRESH")
        XCTAssertEqual(event.params, ["USERID": "@USERID"])
    }

    func test_decode_withoutParams_resultsInNil() throws {
        // params опционален — его отсутствие не должно ломать декодирование
        let json = """
        {
          "trigger": "ON_TAP",
          "targets": ["btn1"],
          "action": "SUBMIT"
        }
        """
        let event = try JSONDecoder().decode(ComponentEvent.self, from: Data(json.utf8))
        XCTAssertNil(event.params)
    }

    func test_equatable() throws {
        let a = ComponentEvent(trigger: "ON_TAP", targets: ["x"], action: "REFRESH", params: nil)
        let b = ComponentEvent(trigger: "ON_TAP", targets: ["x"], action: "REFRESH", params: nil)
        let c = ComponentEvent(trigger: "ON_TAP", targets: ["y"], action: "REFRESH", params: nil)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}

// MARK: - ComponentEventsPayload

/// Тесты обёртки корневого JSON вида { "events": [...] }
final class ComponentEventsPayloadTests: XCTestCase {

    func test_decode_eventsArray() throws {
        let json = """
        {
          "events": [
            { "trigger": "ON_INIT", "targets": ["a"], "action": "REFRESH", "params": null },
            { "trigger": "ON_TAP", "targets": ["b"], "action": "SET_TEXT", "params": { "value": "Hi" } }
          ]
        }
        """
        let payload = try JSONDecoder().decode(ComponentEventsPayload.self, from: Data(json.utf8))
        XCTAssertEqual(payload.events.count, 2)
        XCTAssertEqual(payload.events[0].action, "REFRESH")
        XCTAssertEqual(payload.events[1].params, ["value": "Hi"])
    }
}

// MARK: - AnyComponent

/// Тесты type-erased обёртки компонента, хранимой в ComponentStore
final class AnyComponentTests: XCTestCase {

    func test_handle_forwardsActionAndParamsToClosure() {
        var receivedAction: String?
        var receivedParams: [String: String]?

        let component = AnyComponent { action, params in
            receivedAction = action
            receivedParams = params
        }

        component.handle(action: "SET_TEXT", params: ["value": "Hello"])

        XCTAssertEqual(receivedAction, "SET_TEXT")
        XCTAssertEqual(receivedParams, ["value": "Hello"])
    }

    func test_handle_withNilParams() {
        var wasCalled = false
        let component = AnyComponent { _, params in
            wasCalled = true
            XCTAssertNil(params)
        }
        component.handle(action: "REFRESH", params: nil)
        XCTAssertTrue(wasCalled)
    }
}

// MARK: - ParamResolver

/// Тесты подстановки динамических плейсхолдеров (@USERID и кастомных)
final class ParamResolverTests: XCTestCase {

    func test_defaultUserIDProvider_isUsedWhenNoOverrideGiven() {
        let resolver = ParamResolver()
        let result = resolver.resolve(params: ["greeting": "Hello @USERID!"])
        XCTAssertEqual(result?["greeting"], "Hello demo_user!")
    }

    func test_customUserIDProvider_overridesDefault() {
        let resolver = ParamResolver(currentUserIDProvider: { "aidar" })
        let result = resolver.resolve(params: ["who": "@USERID"])
        XCTAssertEqual(result?["who"], "aidar")
    }

    func test_extraProvider_lowercaseKeyWithoutAt_isNormalized() {
        // Ключ "orgId" должен превратиться в токен "@ORGID"
        let resolver = ParamResolver(extraProviders: ["orgId": { "ORG42" }])
        let result = resolver.resolve(params: ["org": "Org: @ORGID"])
        XCTAssertEqual(result?["org"], "Org: ORG42")
    }

    func test_extraProvider_keyAlreadyPrefixedWithAt() {
        let resolver = ParamResolver(extraProviders: ["@SESSIONID": { "sess-123" }])
        let result = resolver.resolve(params: ["s": "@SESSIONID"])
        XCTAssertEqual(result?["s"], "sess-123")
    }

    func test_multipleOccurrencesOfSameToken_areAllReplaced() {
        let resolver = ParamResolver(currentUserIDProvider: { "u1" })
        let result = resolver.resolve(params: ["pair": "@USERID-@USERID"])
        XCTAssertEqual(result?["pair"], "u1-u1")
    }

    func test_valueWithoutToken_isUnchanged() {
        let resolver = ParamResolver()
        let result = resolver.resolve(params: ["plain": "no placeholders here"])
        XCTAssertEqual(result?["plain"], "no placeholders here")
    }

    func test_unknownToken_isLeftAsIs() {
        // Токен без зарегистрированного провайдера не должен резолвиться
        let resolver = ParamResolver()
        let result = resolver.resolve(params: ["x": "@UNKNOWN_TOKEN"])
        XCTAssertEqual(result?["x"], "@UNKNOWN_TOKEN")
    }

    func test_nilParams_returnsNil() {
        let resolver = ParamResolver()
        XCTAssertNil(resolver.resolve(params: nil))
    }

    func test_multipleKeysResolvedIndependently() {
        let resolver = ParamResolver(
            currentUserIDProvider: { "demo_user" },
            extraProviders: ["orgId": { "ORG1" }]
        )
        let result = resolver.resolve(params: [
            "a": "@USERID",
            "b": "@ORGID",
            "c": "static",
        ])
        XCTAssertEqual(result, [
            "a": "demo_user",
            "b": "ORG1",
            "c": "static",
        ])
    }
}

// MARK: - EventModel

/// Тесты модели события компонента: инициализация, вычисляемое свойство target, Codable-контракт
final class EventModelTests: XCTestCase {

    // MARK: Инициализация

    func test_initWithSingleTarget_wrapsIntoTargetsArray() {
        let model = EventModel(type: .onTap, target: "btn1")
        XCTAssertEqual(model.targets, ["btn1"])
        XCTAssertEqual(model.target, "btn1")
    }

    func test_initWithTargetsArray() {
        let model = EventModel(type: .onChange, targets: ["a", "b"])
        XCTAssertEqual(model.targets, ["a", "b"])
        XCTAssertEqual(model.target, "a") // target возвращает первый элемент targets
    }

    func test_target_returnsEmptyString_whenTargetsIsEmpty() {
        let model = EventModel(type: .onSubmit, targets: [])
        XCTAssertEqual(model.target, "")
    }

    func test_defaultParams_isEmptyDictionary() {
        let model = EventModel(type: .onTap, target: "x")
        XCTAssertTrue(model.params.isEmpty)
    }

    // MARK: Декодирование

    func test_decode_singleTargetKey() throws {
        let json = """
        { "type": "onTap", "target": "btn1", "params": {} }
        """
        let model = try JSONDecoder().decode(EventModel.self, from: Data(json.utf8))
        XCTAssertEqual(model.type, .onTap)
        XCTAssertEqual(model.targets, ["btn1"])
    }

    func test_decode_multipleTargetsKey() throws {
        let json = """
        { "type": "onChange", "targets": ["title_text", "subtitle_text"], "params": {} }
        """
        let model = try JSONDecoder().decode(EventModel.self, from: Data(json.utf8))
        XCTAssertEqual(model.targets, ["title_text", "subtitle_text"])
    }

    func test_decode_bothPresent_targetsTakesPriority() throws {
        // Согласно реализации: если targets непустой — используется он, а не target
        let json = """
        { "type": "onTap", "target": "single", "targets": ["multi1", "multi2"], "params": {} }
        """
        let model = try JSONDecoder().decode(EventModel.self, from: Data(json.utf8))
        XCTAssertEqual(model.targets, ["multi1", "multi2"])
    }

    func test_decode_emptyTargetsArray_fallsBackToTarget() throws {
        // Пустой массив targets не считается валидным — используется одиночный target
        let json = """
        { "type": "onTap", "target": "fallback", "targets": [], "params": {} }
        """
        let model = try JSONDecoder().decode(EventModel.self, from: Data(json.utf8))
        XCTAssertEqual(model.targets, ["fallback"])
    }

    func test_decode_neitherTargetNorTargets_resultsInEmptyArray() throws {
        let json = """
        { "type": "onAppear", "params": {} }
        """
        let model = try JSONDecoder().decode(EventModel.self, from: Data(json.utf8))
        XCTAssertEqual(model.targets, [])
        XCTAssertEqual(model.target, "")
    }

    func test_decode_missingParams_defaultsToEmptyDictionary() throws {
        let json = """
        { "type": "onTap", "target": "x" }
        """
        let model = try JSONDecoder().decode(EventModel.self, from: Data(json.utf8))
        XCTAssertTrue(model.params.isEmpty)
    }

    // MARK: Кодирование

    func test_encode_singleTarget_usesTargetKeyNotTargetsKey() throws {
        let model = EventModel(type: .onTap, target: "btn1")
        let data = try JSONEncoder().encode(model)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["target"] as? String, "btn1")
        XCTAssertNil(object["targets"])
    }

    func test_encode_multipleTargets_usesTargetsKeyNotTargetKey() throws {
        let model = EventModel(type: .onChange, targets: ["a", "b"])
        let data = try JSONEncoder().encode(model)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["targets"] as? [String], ["a", "b"])
        XCTAssertNil(object["target"])
    }

    func test_roundTrip_encodeThenDecode_preservesEquality() throws {
        let original = EventModel(type: .onSubmit, targets: ["form1"], params: ["k": .string("v")])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EventModel.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - ComponentModel.event(for:)

/// Тесты нормализации событий, объявленных в JSON узла компонента.
///
/// ⚠️ Эти тесты собирают `ComponentModel` через декодирование JSON. Если реальные
/// имена ключей (`id`, `type`, `props`, `events`, `children`) или тип `resolvedEvents`
/// в `ComponentModel.swift` отличаются от предполагаемых здесь — поправьте JSON-фикстуры
/// или инициализацию под фактическую схему.
final class ComponentModelEventResolutionTests: XCTestCase {

    private func makeComponent(eventsJSON: String) throws -> ComponentModel {
        let json = """
        {
          "id": "title_text",
          "type": "Text",
          "props": {},
          "events": \(eventsJSON)
        }
        """
        return try JSONDecoder().decode(ComponentModel.self, from: Data(json.utf8))
    }

    func test_stringDefinition_isTreatedAsSingleTarget() throws {
        // {"onTap": "next_button"} — короткая форма, эквивалентна {"target": "next_button"}
        let component = try makeComponent(eventsJSON: #"{ "onTap": "next_button" }"#)
        let event = try XCTUnwrap(component.event(for: .onTap))
        XCTAssertEqual(event.targets, ["next_button"])
    }

    func test_objectDefinition_withTargetsArray() throws {
        let component = try makeComponent(eventsJSON: #"""
        { "onChange": { "targets": ["title_text", "subtitle_text"], "params": {} } }
        """#)
        let event = try XCTUnwrap(component.event(for: .onChange))
        XCTAssertEqual(event.targets, ["title_text", "subtitle_text"])
    }

    func test_objectDefinition_withSingleTargetKey() throws {
        let component = try makeComponent(eventsJSON: #"""
        { "onTap": { "target": "btn1", "params": {} } }
        """#)
        let event = try XCTUnwrap(component.event(for: .onTap))
        XCTAssertEqual(event.targets, ["btn1"])
    }

    func test_objectDefinition_withoutTargetOrTargets_fallsBackToOwnId() throws {
        // Ни target, ни targets не заданы — событие адресуется самому компоненту (self-target)
        let component = try makeComponent(eventsJSON: #"{ "onTap": { "params": {} } }"#)
        let event = try XCTUnwrap(component.event(for: .onTap))
        XCTAssertEqual(event.targets, ["title_text"])
    }

    func test_objectDefinition_carriesParams() throws {
        let component = try makeComponent(eventsJSON: #"""
        { "onTap": { "target": "x", "params": { "value": "Hello" } } }
        """#)
        let event = try XCTUnwrap(component.event(for: .onTap))
        XCTAssertEqual(event.params["value"]?.stringValue, "Hello")
    }

    func test_missingEventType_returnsNil() throws {
        let component = try makeComponent(eventsJSON: #"{ "onTap": "next_button" }"#)
        // onSubmit не объявлен в JSON — метод должен вернуть nil, а не падать
        XCTAssertNil(component.event(for: .onSubmit))
    }
}
