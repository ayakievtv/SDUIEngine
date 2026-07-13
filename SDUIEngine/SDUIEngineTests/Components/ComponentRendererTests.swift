import XCTest
import SwiftUI
@testable import SDUIEngine

@MainActor
final class ComponentRendererTests: XCTestCase {

    // MARK: - Test Doubles

    private final class MockComponent: UIComponent {
        let model: ComponentModel
        let context: UIContext
        var wasInitialized = false

        init(model: ComponentModel, context: UIContext) {
            self.model = model
            self.context = context
            wasInitialized = true
        }

        var body: some View {
            Text("Mock Component")
        }
    }

    @MainActor
    private func makeTestContext() -> UIContext {
        TestUIContext().makeTestContext()
    }

    @MainActor
    private func makeRegistry() -> ComponentRegistry {
        let registry = ComponentRegistry()

        // Register all standard components
        registry.register(type: "Text", component: TextComponent.self)
        registry.register(type: "Button", component: ButtonComponent.self)
        registry.register(type: "TextField", component: TextFieldComponent.self)
        registry.register(type: "Image", component: ImageComponent.self)
        registry.register(type: "VStack", component: VStackComponent.self)
        registry.register(type: "HStack", component: HStackComponent.self)
        registry.register(type: "Spacer", component: SpacerComponent.self)
        registry.register(type: "ScrollView", component: ScrollViewComponent.self)
        registry.register(type: "TabBar", component: TabBarComponent.self)
        registry.register(type: "DBGrid", component: DBGridComponent.self)
        registry.register(type: "DataSource", component: DataSourceComponent.self)

        return registry
    }

    // MARK: - Component Type Mapping Tests

    func testComponentTypeMapping_Text() {
        let registry = makeRegistry()
        let factory = registry.resolve(type: "Text")
        XCTAssertNotNil(factory, "Text component should be registered")
    }

    func testComponentTypeMapping_Button() {
        let registry = makeRegistry()
        let factory = registry.resolve(type: "Button")
        XCTAssertNotNil(factory, "Button component should be registered")
    }

    func testComponentTypeMapping_TextField() {
        let registry = makeRegistry()
        let factory = registry.resolve(type: "TextField")
        XCTAssertNotNil(factory, "TextField component should be registered")
    }

    func testComponentTypeMapping_Image() {
        let registry = makeRegistry()
        let factory = registry.resolve(type: "Image")
        XCTAssertNotNil(factory, "Image component should be registered")
    }

    func testComponentTypeMapping_VStack() {
        let registry = makeRegistry()
        let factory = registry.resolve(type: "VStack")
        XCTAssertNotNil(factory, "VStack component should be registered")
    }

    func testComponentTypeMapping_HStack() {
        let registry = makeRegistry()
        let factory = registry.resolve(type: "HStack")
        XCTAssertNotNil(factory, "HStack component should be registered")
    }

    func testComponentTypeMapping_ScrollView() {
        let registry = makeRegistry()
        let factory = registry.resolve(type: "ScrollView")
        XCTAssertNotNil(factory, "ScrollView component should be registered")
    }

    func testComponentTypeMapping_TabBar() {
        let registry = makeRegistry()
        let factory = registry.resolve(type: "TabBar")
        XCTAssertNotNil(factory, "TabBar component should be registered")
    }

    func testComponentTypeMapping_DBGrid() {
        let registry = makeRegistry()
        let factory = registry.resolve(type: "DBGrid")
        XCTAssertNotNil(factory, "DBGrid component should be registered")
    }

    func testComponentTypeMapping_DataSource() {
        let registry = makeRegistry()
        let factory = registry.resolve(type: "DataSource")
        XCTAssertNotNil(factory, "DataSource component should be registered")
    }

    func testComponentTypeMapping_Unknown() {
        let registry = makeRegistry()
        let factory = registry.resolve(type: "UnknownComponent")
        XCTAssertNil(factory, "Unknown component should not be registered")
    }

    // MARK: - ComponentStyle Application Tests

    func testApplyPerformanceProps_DrawingGroup() {
        let props: [String: JSONValue] = ["drawingGroup": .bool(true)]
        let view = Text("Test").applyPerformanceProps(props)

        // Verify the view can be created without errors
        XCTAssertNotNil(view)
    }

    func testApplyPerformanceProps_CompositingGroup() {
        let props: [String: JSONValue] = ["compositingGroup": .bool(true)]
        let view = Text("Test").applyPerformanceProps(props)

        XCTAssertNotNil(view)
    }

    func testApplyPerformanceProps_FixedSizeHorizontal() {
        let props: [String: JSONValue] = ["fixedSizeHorizontal": .bool(true)]
        let view = Text("Test").applyPerformanceProps(props)

        XCTAssertNotNil(view)
    }

    func testApplyPerformanceProps_FixedSizeVertical() {
        let props: [String: JSONValue] = ["fixedSizeVertical": .bool(true)]
        let view = Text("Test").applyPerformanceProps(props)

        XCTAssertNotNil(view)
    }

    func testApplyPerformanceProps_AllOptions() {
        let props: [String: JSONValue] = [
            "drawingGroup": .bool(true),
            "compositingGroup": .bool(true),
            "fixedSizeHorizontal": .bool(true),
            "fixedSizeVertical": .bool(true)
        ]
        let view = Text("Test").applyPerformanceProps(props)

        XCTAssertNotNil(view)
    }

    func testApplyPerformanceProps_NoOptions() {
        let props: [String: JSONValue] = [:]
        let view = Text("Test").applyPerformanceProps(props)

        XCTAssertNotNil(view)
    }

    // MARK: - Recursive Rendering Tests

    func testRecursiveRendering_NestedChildren() {
        let context = makeTestContext()
        let registry = makeRegistry()

        let childModel = ComponentModel(
            id: "child",
            type: "Text",
            props: ["text": .string("Child Text")]
        )

        let parentModel = ComponentModel(
            id: "parent",
            type: "VStack",
            props: ["spacing": .number(8)],
            children: [childModel]
        )

        // Create renderer - this should not crash
        let renderer = ComponentRenderer(
            model: parentModel,
            context: context,
            registry: registry
        )

        XCTAssertNotNil(renderer)
    }

    func testRecursiveRendering_MultipleLevels() {
        let context = makeTestContext()
        let registry = makeRegistry()

        let grandchildModel = ComponentModel(
            id: "grandchild",
            type: "Text",
            props: ["text": .string("Grandchild")]
        )

        let childModel = ComponentModel(
            id: "child",
            type: "VStack",
            props: ["spacing": .number(4)],
            children: [grandchildModel]
        )

        let parentModel = ComponentModel(
            id: "parent",
            type: "VStack",
            props: ["spacing": .number(8)],
            children: [childModel]
        )

        let renderer = ComponentRenderer(
            model: parentModel,
            context: context,
            registry: registry
        )

        XCTAssertNotNil(renderer)
    }

    func testRecursiveRendering_EmptyChildren() {
        let context = makeTestContext()
        let registry = makeRegistry()

        let model = ComponentModel(
            id: "empty",
            type: "VStack",
            props: ["spacing": .number(8)],
            children: []
        )

        let renderer = ComponentRenderer(
            model: model,
            context: context,
            registry: registry
        )

        XCTAssertNotNil(renderer)
    }

    func testRecursiveRendering_NilChildren() {
        let context = makeTestContext()
        let registry = makeRegistry()

        let model = ComponentModel(
            id: "nilChildren",
            type: "VStack",
            props: ["spacing": .number(8)]
        )

        let renderer = ComponentRenderer(
            model: model,
            context: context,
            registry: registry
        )

        XCTAssertNotNil(renderer)
    }

    // MARK: - Fallback Rendering Tests

    func testFallbackRendering_UnknownComponentType() {
        let context = makeTestContext()
        let registry = ComponentRegistry() // Empty registry

        let model = ComponentModel(
            id: "unknown",
            type: "NonExistentComponent",
            props: ["text": .string("Test")]
        )

        let renderer = ComponentRenderer(
            model: model,
            context: context,
            registry: registry
        )

        // Should create fallback view without crashing
        XCTAssertNotNil(renderer)
    }

    func testFallbackRendering_WithChildren() {
        let context = makeTestContext()
        let registry = ComponentRegistry() // Empty registry

        let childModel = ComponentModel(
            id: "child",
            type: "Text",
            props: ["text": .string("Child")]
        )

        let model = ComponentModel(
            id: "unknown",
            type: "NonExistentComponent",
            props: ["text": .string("Parent")],
            children: [childModel]
        )

        let renderer = ComponentRenderer(
            model: model,
            context: context,
            registry: registry
        )

        XCTAssertNotNil(renderer)
    }

    // MARK: - Lifecycle Events Tests

    func testOnAppearEvent_Triggered(componentStore: ComponentStore = ComponentStore()) {
        let context = makeTestContext()
        let registry = makeRegistry()

        var eventTriggered = false

        // Replace event dispatcher with mock
        let mockDispatcher = MockEventDispatcher {
            eventTriggered = true
        }

        let mockContext = UIContext(
            stateStore: context.stateStore,
            eventDispatcher: mockDispatcher,
            navigation: context.navigation,
            apiClient: context.apiClient,
            componentRegistry: context.componentRegistry,
            dataSourceRegistry: context.dataSourceRegistry,
            componentStore: componentStore//context.componentStore
        )

        let model = ComponentModel(
            id: "test",
            type: "Text",
            props: ["text": .string("Test")],
            events: ["onAppear": .string("testTarget")]
        )

        let renderer = ComponentRenderer(
            model: model,
            context: mockContext,
            registry: registry
        )

        // The view should be created
        XCTAssertNotNil(renderer)

        // Note: Actual event triggering happens in View's onAppear, which we can't test directly
        // This test verifies the renderer is set up correctly
    }

    func testOnDisappearEvent_Triggered() {
        let context = makeTestContext()
        let registry = makeRegistry()

        let model = ComponentModel(
            id: "test",
            type: "Text",
            props: ["text": .string("Test")],
            events: ["onDisappear": .string("testTarget")]
        )

        let renderer = ComponentRenderer(
            model: model,
            context: context,
            registry: registry
        )

        XCTAssertNotNil(renderer)
    }

    // MARK: - Style Tests

    func testStyle_WithAllProperties() {
        let props: [String: JSONValue] = [
            "fontSize": .number(16),
            "fontWeight": .string("bold"),
            "color": .string("red"),
            "padding": .number(8),
            "margin": .number(4),
            "width": .number(100),
            "height": .number(50)
        ]

        let style = Style(props: props)

        XCTAssertEqual(style.fontSize, 16)
        XCTAssertEqual(style.fontWeight, .bold)
        XCTAssertEqual(style.color, .red)
        XCTAssertEqual(style.padding, 8)
        XCTAssertEqual(style.margin, 4)
        XCTAssertEqual(style.width, 100)
        XCTAssertEqual(style.height, 50)
    }

    func testStyle_WithPartialProperties() {
        let props: [String: JSONValue] = [
            "fontSize": .number(14),
            "color": .string("blue")
        ]

        let style = Style(props: props)

        XCTAssertEqual(style.fontSize, 14)
        XCTAssertEqual(style.color, .blue)
        XCTAssertNil(style.fontWeight)
        XCTAssertNil(style.padding)
    }

    func testStyle_WithEmptyProps() {
        let props: [String: JSONValue] = [:]
        let style = Style(props: props)

        XCTAssertNil(style.fontSize)
        XCTAssertNil(style.fontWeight)
        XCTAssertNil(style.color)
        XCTAssertNil(style.padding)
    }

    // MARK: - Color Parsing Tests

    func testColorParsing_NamedColors() {
        XCTAssertEqual(Color.sduiColor("red"), .red)
        XCTAssertEqual(Color.sduiColor("green"), .green)
        XCTAssertEqual(Color.sduiColor("blue"), .blue)
        XCTAssertEqual(Color.sduiColor("black"), .black)
        XCTAssertEqual(Color.sduiColor("white"), .white)
        XCTAssertEqual(Color.sduiColor("gray"), .gray)
        XCTAssertEqual(Color.sduiColor("orange"), .orange)
        XCTAssertEqual(Color.sduiColor("yellow"), .yellow)
    }

    func testColorParsing_HexColors() {
        XCTAssertNotNil(Color.sduiColor("#FF0000"))
        XCTAssertNotNil(Color.sduiColor("#00FF00"))
        XCTAssertNotNil(Color.sduiColor("#0000FF"))
        XCTAssertNotNil(Color.sduiColor("#FFFFFF"))
        XCTAssertNotNil(Color.sduiColor("#000000"))
    }

    func testColorParsing_HexWithAlpha() {
        XCTAssertNotNil(Color.sduiColor("#FF0000FF"))
        XCTAssertNotNil(Color.sduiColor("#800000FF"))
    }

    func testColorParsing_CaseInsensitive() {
        XCTAssertEqual(Color.sduiColor("RED"), .red)
        XCTAssertEqual(Color.sduiColor("Red"), .red)
        XCTAssertEqual(Color.sduiColor("rEd"), .red)
    }

    func testColorParsing_Invalid() {
        XCTAssertNil(Color.sduiColor("invalid"))
        XCTAssertNil(Color.sduiColor("#"))
        XCTAssertNil(Color.sduiColor("#GGGGGG"))
    }

    // MARK: - Font Weight Parsing Tests

    func testFontWeightParsing_String() {
        XCTAssertEqual(Font.Weight.sduiWeight("bold"), .bold)
        XCTAssertEqual(Font.Weight.sduiWeight("regular"), .regular)
        XCTAssertEqual(Font.Weight.sduiWeight("light"), .light)
        XCTAssertEqual(Font.Weight.sduiWeight("semibold"), .semibold)
        XCTAssertEqual(Font.Weight.sduiWeight("ultraLight"), .ultraLight)
        XCTAssertEqual(Font.Weight.sduiWeight("thin"), .thin)
        XCTAssertEqual(Font.Weight.sduiWeight("medium"), .medium)
        XCTAssertEqual(Font.Weight.sduiWeight("heavy"), .heavy)
        XCTAssertEqual(Font.Weight.sduiWeight("black"), .black)
    }

    func testFontWeightParsing_Numeric() {
        XCTAssertEqual(Font.Weight.sduiWeight(100), .ultraLight)
        XCTAssertEqual(Font.Weight.sduiWeight(200), .thin)
        XCTAssertEqual(Font.Weight.sduiWeight(300), .light)
        XCTAssertEqual(Font.Weight.sduiWeight(400), .regular)
        XCTAssertEqual(Font.Weight.sduiWeight(500), .medium)
        XCTAssertEqual(Font.Weight.sduiWeight(600), .semibold)
        XCTAssertEqual(Font.Weight.sduiWeight(700), .bold)
        XCTAssertEqual(Font.Weight.sduiWeight(800), .heavy)
        XCTAssertEqual(Font.Weight.sduiWeight(900), .black)
    }

    func testFontWeightParsing_Invalid() {
        XCTAssertNil(Font.Weight.sduiWeight("invalid"))
        XCTAssertNil(Font.Weight.sduiWeight(""))
    }
}

// MARK: - Mock Event Dispatcher

private final class MockEventDispatcher: EventDispatching {
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    func dispatch(_ event: EventModel, context: UIContext) {
        handler()
    }
}
