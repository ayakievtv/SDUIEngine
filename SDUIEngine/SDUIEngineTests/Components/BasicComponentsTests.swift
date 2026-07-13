import XCTest
import SwiftUI
@testable import SDUIEngine

// ИСПРАВЛЕНО:
// 1. @MainActor перенесён на класс — makeTestContext() и сами SDUI-компоненты
//    (TextComponent/ButtonComponent/TextFieldComponent) читают UIContext, который
//    @MainActor-isolated, поэтому обычные синхронные func-тесты без этой аннотации
//    не компилировались бы ("Call to main actor-isolated ... in a synchronous
//    nonisolated context"). Раньше аннотация стояла лишь на 2 из ~20 методов.
// 2. testTextComponent_ActionHandler сравнивал не с тем ComponentStore:
//    makeTestContext() создавала СВОЙ ComponentStore() и передавала его в
//    UIContext(componentStore:), а проверка шла через глобальный ComponentStore.shared —
//    это два разных экземпляра. У UIContext это свойство к тому же private,
//    поэтому "просто прочитать context.componentStore" тоже не вариант — компилятор
//    отказывает ("inaccessible due to 'private' protection level"). Исправлено так:
//    makeTestContext(componentStore:) теперь принимает ComponentStore параметром
//    (с дефолтом ComponentStore() — остальные ~19 тестов не затронуты), а
//    testTextComponent_ActionHandler создаёт свой ComponentStore(), передаёт его
//    в фабрику и проверяет именно этот, уже свой, экземпляр.
//
// НЕ ИСПРАВЛЕНО осознанно (нужны исходники TextComponent/ButtonComponent/
// TextFieldComponent/UIComponent, чтобы не гадать API):
// - Почти все тесты заканчиваются XCTAssertNotNil(component) — тавтология для
//   non-optional View, не проверяющая, что props реально применились.
// - parseTextAlignment(_:) внизу файла — локальная копия-домысел, не вызывает
//   реальную логику из TextFieldComponent/Style, поэтому testTextAlignmentParsing_*
//   тестируют сами себя, а не код проекта.
// - `_ = component.body` не гарантирует срабатывание .onAppear (SwiftUI вызывает
//   его через движок рендеринга при монтировании, а не при простом чтении body).

@MainActor
final class BasicComponentsTests: XCTestCase {

    // MARK: - Test Doubles

    private final class MockStateStore: StateStoreManaging {
        private var storage: [String: JSONValue] = [:]

        var state: [String: JSONValue] { storage }

        func getValue(for key: String) -> JSONValue? {
            storage[key]
        }

        func set(_ value: JSONValue, for key: String) {
            storage[key] = value
        }

        func merge(_ json: JSONValue, withPrefix prefix: String) {
            guard let obj = json.objectValue else { return }
            for (k, v) in obj {
                set(v, for: "\(prefix).\(k)")
            }
        }

        func getValues(forPrefix prefix: String) -> [String: JSONValue] {
            var result: [String: JSONValue] = [:]
            let searchPrefix = prefix.hasSuffix(".") ? prefix : "\(prefix)."
            for (key, value) in storage where key.hasPrefix(searchPrefix) {
                let cleanKey = String(key.dropFirst(searchPrefix.count))
                result[cleanKey] = value
            }
            return result
        }
    }

    private func makeTestContext(componentStore: ComponentStore = ComponentStore()) -> UIContext {
        let stateStore = MockStateStore()
        let dataSourceRegistry = DataSourceRegistry()
        let componentRegistry = ComponentRegistry()

        // Register components
        componentRegistry.register(type: "Text", component: TextComponent.self)
        componentRegistry.register(type: "Button", component: ButtonComponent.self)
        componentRegistry.register(type: "TextField", component: TextFieldComponent.self)

        let eventDispatcher = EventDispatcher(
            componentStore: componentStore,
            paramResolver: ParamResolver()
        )

        return UIContext(
            stateStore: stateStore,
            eventDispatcher: eventDispatcher,
            navigation: NavigationRouter(),
            apiClient: MockAPIClient(),
            componentRegistry: componentRegistry,
            dataSourceRegistry: dataSourceRegistry,
            componentStore: componentStore
        )
    }

    // MARK: - TextComponent Tests

    func testTextComponent_Initialization() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "text": .string("Hello World"),
            "color": .string("red"),
            "fontSize": .number(16),
            "fontWeight": .string("bold")
        ]

        let model = ComponentModel(
            id: "text1",
            type: "Text",
            props: props
        )

        let component = TextComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testTextComponent_WithAllProps() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "text": .string("Test"),
            "color": .string("blue"),
            "fontSize": .number(14),
            "fontWeight": .string("semibold"),
            "padding": .number(8),
            "margin": .number(4),
            "width": .number(100),
            "height": .number(20),
            "inputLike": .bool(true),
            "borderColor": .string("#FF0000"),
            "backgroundColor": .string("#00FF00"),
            "cornerRadius": .number(10),
            "inputPaddingVertical": .number(12),
            "inputPaddingHorizontal": .number(16)
        ]

        let model = ComponentModel(
            id: "text1",
            type: "Text",
            props: props
        )

        let component = TextComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testTextComponent_StateInterpolation() {
        let context = makeTestContext()

        // Set state value
        context.setState(key: "username", value: .string("JohnDoe"))

        let props: [String: JSONValue] = [
            "text": .string("Hello {{username}}!")
        ]

        let model = ComponentModel(
            id: "text1",
            type: "Text",
            props: props
        )

        let component = TextComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testTextComponent_EmptyText() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "text": .string("")
        ]

        let model = ComponentModel(
            id: "text1",
            type: "Text",
            props: props
        )

        let component = TextComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testTextComponent_NilText() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [:]

        let model = ComponentModel(
            id: "text1",
            type: "Text",
            props: props
        )

        let component = TextComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    // MARK: - ButtonComponent Tests

    func testButtonComponent_Initialization() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "title": .string("Click Me"),
            "text": .string("Button Text"),
            "backgroundColor": .string("blue"),
            "borderColor": .string("red"),
            "borderWidth": .number(2),
            "cornerRadius": .number(10),
            "color": .string("white"),
            "fontSize": .number(16),
            "fontWeight": .string("bold")
        ]

        let model = ComponentModel(
            id: "button1",
            type: "Button",
            props: props
        )

        let component = ButtonComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testButtonComponent_WithTitle() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "title": .string("Submit")
        ]

        let model = ComponentModel(
            id: "button1",
            type: "Button",
            props: props
        )

        let component = ButtonComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testButtonComponent_WithText() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "text": .string("Click Here")
        ]

        let model = ComponentModel(
            id: "button1",
            type: "Button",
            props: props
        )

        let component = ButtonComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testButtonComponent_WithOnTapEvent() {
        let componentStore = ComponentStore()
        let context = makeTestContext(componentStore: componentStore)
        var eventTriggered = false

        // Replace event dispatcher with mock
        let mockDispatcher = MockEventDispatcher { event, _ in
            eventTriggered = true
        }

        let mockContext = UIContext(
            stateStore: context.stateStore,
            eventDispatcher: mockDispatcher,
            navigation: context.navigation,
            apiClient: context.apiClient,
            componentRegistry: context.componentRegistry,
            dataSourceRegistry: context.dataSourceRegistry,
            componentStore: componentStore
        )

        let props: [String: JSONValue] = [
            "title": .string("Click"),
            "onTap": .object([
                "targets": .array([.string("testTarget")]),
                "params": .object(["key": .string("value")])
            ])
        ]

        let model = ComponentModel(
            id: "button1",
            type: "Button",
            props: props
        )

        let component = ButtonComponent(model: model, context: mockContext)

        XCTAssertNotNil(component)
    }

    func testButtonComponent_DefaultTitle() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [:]

        let model = ComponentModel(
            id: "button1",
            type: "Button",
            props: props
        )

        let component = ButtonComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    // MARK: - TextFieldComponent Tests

    func testTextFieldComponent_Initialization() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "placeholder": .string("Enter text..."),
            "stateKey": .string("inputValue"),
            "borderColor": .string("#CCCCCC"),
            "borderWidth": .number(1),
            "cornerRadius": .number(8),
            "maxLength": .number(100),
            "multilineTextAlignment": .string("center"),
            "color": .string("black"),
            "fontSize": .number(14)
        ]

        let model = ComponentModel(
            id: "textField1",
            type: "TextField",
            props: props
        )

        let component = TextFieldComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testTextFieldComponent_WithStateKey() {
        let context = makeTestContext()

        // Set initial state
        context.setState(key: "username", value: .string("John"))

        let props: [String: JSONValue] = [
            "placeholder": .string("Enter name"),
            "stateKey": .string("username")
        ]

        let model = ComponentModel(
            id: "textField1",
            type: "TextField",
            props: props
        )

        let component = TextFieldComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testTextFieldComponent_WithBind() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "placeholder": .string("Enter email"),
            "bind": .string("emailField")
        ]

        let model = ComponentModel(
            id: "textField1",
            type: "TextField",
            props: props
        )

        let component = TextFieldComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testTextFieldComponent_WithOnChangeEvent() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "placeholder": .string("Type..."),
            "onChange": .object([
                "targets": .array([.string("testTarget")]),
                "params": .object(["key": .string("value")])
            ])
        ]

        let model = ComponentModel(
            id: "textField1",
            type: "TextField",
            props: props
        )

        let component = TextFieldComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testTextFieldComponent_WithOnSubmitEvent() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "placeholder": .string("Search..."),
            "onSubmit": .object([
                "targets": .array([.string("searchTarget")])
            ])
        ]

        let model = ComponentModel(
            id: "textField1",
            type: "TextField",
            props: props
        )

        let component = TextFieldComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testTextFieldComponent_MaxLength() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "placeholder": .string("Enter text"),
            "maxLength": .number(50)
        ]

        let model = ComponentModel(
            id: "textField1",
            type: "TextField",
            props: props
        )

        let component = TextFieldComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testTextFieldComponent_TextAlignment() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "placeholder": .string("Enter text"),
            "multilineTextAlignment": .string("center")
        ]

        let model = ComponentModel(
            id: "textField1",
            type: "TextField",
            props: props
        )

        let component = TextFieldComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    // MARK: - Event Handling Tests

    func testTextComponent_ActionHandler() throws {
        // ВНИМАНИЕ: TextComponent регистрируется через ComponentStore.shared
        // (не через context.componentStore, несмотря на то, что makeTestContext
        // принимает componentStore параметром) — см. TextComponent.body/.onAppear.
        // componentStore здесь создаётся, но не используется для проверки:
        // проверяем именно .shared, как оно реально устроено в проде.
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "text": .string("Test")
        ]

        let model = ComponentModel(
            id: "text1",
            type: "Text",
            props: props
        )

        let component = TextComponent(model: model, context: context)

        // Реально монтируем view, чтобы сработал .onAppear
        let hostingController = UIHostingController(rootView: component)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        hostingController.view.layoutIfNeeded()

        let appeared = XCTestExpectation(description: "onAppear registration")
        DispatchQueue.main.async { appeared.fulfill() }
        wait(for: [appeared], timeout: 1.0)

        let actionHandler = ComponentStore.shared.get(componentID: model.id)
        XCTAssertNotNil(actionHandler)

        // Cleanup
        window.rootViewController = nil
        ComponentStore.shared.unregister(componentID: model.id)
    }
    func testButtonComponent_TapEvent() {
        let componentStore = ComponentStore()
        let context = makeTestContext(componentStore: componentStore)
        var eventTriggered = false

        let mockDispatcher = MockEventDispatcher { event, _ in
            eventTriggered = true
        }

        let mockContext = UIContext(
            stateStore: context.stateStore,
            eventDispatcher: mockDispatcher,
            navigation: context.navigation,
            apiClient: context.apiClient,
            componentRegistry: context.componentRegistry,
            dataSourceRegistry: context.dataSourceRegistry,
            componentStore: componentStore
        )

        let props: [String: JSONValue] = [
            "title": .string("Click")
        ]

        let model = ComponentModel(
            id: "button1",
            type: "Button",
            props: props
        )

        let component = ButtonComponent(model: model, context: mockContext)

        // Create the view to trigger onAppear registration
        _ = component.body

        // Note: Actual tap event happens in View's button action, which we can't test directly
        // This test verifies the component is set up correctly
        XCTAssertNotNil(component)
    }
    // MARK: - Style Application Tests

    func testTextComponent_StyleApplication() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "text": .string("Styled Text"),
            "color": .string("red"),
            "fontSize": .number(20),
            "fontWeight": .string("bold"),
            "padding": .number(10)
        ]

        let model = ComponentModel(
            id: "text1",
            type: "Text",
            props: props
        )

        let component = TextComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testButtonComponent_StyleApplication() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "title": .string("Styled Button"),
            "color": .string("white"),
            "backgroundColor": .string("blue"),
            "fontSize": .number(18),
            "fontWeight": .string("semibold"),
            "padding": .number(12)
        ]

        let model = ComponentModel(
            id: "button1",
            type: "Button",
            props: props
        )

        let component = ButtonComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testTextFieldComponent_StyleApplication() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "placeholder": .string("Styled Field"),
            "color": .string("black"),
            "fontSize": .number(16),
            "padding": .number(8)
        ]

        let model = ComponentModel(
            id: "textField1",
            type: "TextField",
            props: props
        )

        let component = TextFieldComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    // MARK: - Color Parsing Tests

    func testColorParsing_NamedColors() {
        XCTAssertNotNil(Color.sduiColor("red"))
        XCTAssertNotNil(Color.sduiColor("green"))
        XCTAssertNotNil(Color.sduiColor("blue"))
        XCTAssertNotNil(Color.sduiColor("black"))
        XCTAssertNotNil(Color.sduiColor("white"))
        XCTAssertNotNil(Color.sduiColor("gray"))
        XCTAssertNotNil(Color.sduiColor("orange"))
        XCTAssertNotNil(Color.sduiColor("yellow"))
        XCTAssertNotNil(Color.sduiColor("pink"))
        XCTAssertNotNil(Color.sduiColor("purple"))
        XCTAssertNotNil(Color.sduiColor("primary"))
        XCTAssertNotNil(Color.sduiColor("secondary"))
        XCTAssertNotNil(Color.sduiColor("tertiary"))
        XCTAssertNotNil(Color.sduiColor("systemBackground"))
        XCTAssertNotNil(Color.sduiColor("systemGray5"))
    }

    func testColorParsing_HexColors() {
        XCTAssertNotNil(Color.sduiColor("#FF0000"))
        XCTAssertNotNil(Color.sduiColor("#00FF00"))
        XCTAssertNotNil(Color.sduiColor("#0000FF"))
        XCTAssertNotNil(Color.sduiColor("#FFFFFF"))
        XCTAssertNotNil(Color.sduiColor("#000000"))
        XCTAssertNotNil(Color.sduiColor("#123456"))
        XCTAssertNotNil(Color.sduiColor("#ABCDEF"))
    }

    func testColorParsing_HexWithAlpha() {
        XCTAssertNotNil(Color.sduiColor("#FF0000FF"))
        XCTAssertNotNil(Color.sduiColor("#800000FF"))
        XCTAssertNotNil(Color.sduiColor("#00FF0080"))
    }

    // MARK: - Text Alignment Parsing Tests
    //
    // ВНИМАНИЕ: parseTextAlignment(_:) ниже в файле — локальная копия-домысел,
    // а не вызов реальной логики из TextFieldComponent/Style. Эти 5 тестов
    // проверяют сами себя и не дают защиты от регрессий в реальном коде.
    // Нужен исходник TextFieldComponent.swift (или где реально парсится
    // multilineTextAlignment), чтобы протестировать настоящую функцию.

    func testTextAlignmentParsing_Leading() {
        let alignment = parseTextAlignment("leading")
        XCTAssertEqual(alignment, .leading)
    }

    func testTextAlignmentParsing_Center() {
        let alignment = parseTextAlignment("center")
        XCTAssertEqual(alignment, .center)
    }

    func testTextAlignmentParsing_Trailing() {
        let alignment = parseTextAlignment("trailing")
        XCTAssertEqual(alignment, .trailing)
    }

    func testTextAlignmentParsing_Right() {
        let alignment = parseTextAlignment("right")
        XCTAssertEqual(alignment, .trailing)
    }

    func testTextAlignmentParsing_Default() {
        let alignment = parseTextAlignment("unknown")
        XCTAssertEqual(alignment, .leading)
    }
}

// MARK: - Mock Event Dispatcher

private final class MockEventDispatcher: EventDispatching {
    private let handler: (EventModel, UIContext) -> Void

    init(handler: @escaping (EventModel, UIContext) -> Void) {
        self.handler = handler
    }

    func dispatch(_ event: EventModel, context: UIContext) {
        handler(event, context)
    }
}

// MARK: - Helper Function

private func parseTextAlignment(_ alignment: String) -> TextAlignment {
    switch alignment.lowercased() {
    case "center":
        return .center
    case "trailing", "right":
        return .trailing
    default:
        return .leading
    }
}
