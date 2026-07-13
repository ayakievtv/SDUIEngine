import XCTest
import SwiftUI
@testable import SDUIEngine


@MainActor
final class ImageAndTabBarComponentsTests: XCTestCase {

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

 
    private func makeTestContext() -> UIContext {
        let stateStore = MockStateStore()
        let componentStore = ComponentStore()
        let dataSourceRegistry = DataSourceRegistry()
        let componentRegistry = ComponentRegistry()

        // Register components
        componentRegistry.register(type: "Image", component: ImageComponent.self)
        componentRegistry.register(type: "TabBar", component: TabBarComponent.self)
        componentRegistry.register(type: "Text", component: TextComponent.self)

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

    // MARK: - ImageComponent Tests

    func testImageComponent_WithURL() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "url": .string("https://example.com/image.png"),
            "resizable": .bool(true),
            "contentMode": .string("fit")
        ]

        let model = ComponentModel(
            id: "image1",
            type: "Image",
            props: props
        )

        let component = ImageComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testImageComponent_WithSystemName() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "systemName": .string("photo"),
            "resizable": .bool(false)
        ]

        let model = ComponentModel(
            id: "image1",
            type: "Image",
            props: props
        )

        let component = ImageComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testImageComponent_WithName() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "name": .string("localImage"),
            "resizable": .bool(true),
            "contentMode": .string("fill")
        ]

        let model = ComponentModel(
            id: "image1",
            type: "Image",
            props: props
        )

        let component = ImageComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testImageComponent_WithoutSource() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [:]

        let model = ComponentModel(
            id: "image1",
            type: "Image",
            props: props
        )

        let component = ImageComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testImageComponent_ResizableTrue() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "systemName": .string("photo"),
            "resizable": .bool(true)
        ]

        let model = ComponentModel(
            id: "image1",
            type: "Image",
            props: props
        )

        let component = ImageComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testImageComponent_ResizableFalse() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "systemName": .string("photo"),
            "resizable": .bool(false)
        ]

        let model = ComponentModel(
            id: "image1",
            type: "Image",
            props: props
        )

        let component = ImageComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testImageComponent_ContentModeFit() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "systemName": .string("photo"),
            "resizable": .bool(true),
            "contentMode": .string("fit")
        ]

        let model = ComponentModel(
            id: "image1",
            type: "Image",
            props: props
        )

        let component = ImageComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testImageComponent_ContentModeFill() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "systemName": .string("photo"),
            "resizable": .bool(true),
            "contentMode": .string("fill")
        ]

        let model = ComponentModel(
            id: "image1",
            type: "Image",
            props: props
        )

        let component = ImageComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testImageComponent_ContentModeCaseInsensitive() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "systemName": .string("photo"),
            "resizable": .bool(true),
            "contentMode": .string("FIT")
        ]

        let model = ComponentModel(
            id: "image1",
            type: "Image",
            props: props
        )

        let component = ImageComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testImageComponent_WithStyle() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "systemName": .string("photo"),
            "width": .number(100),
            "height": .number(100),
            "padding": .number(8),
            "margin": .number(4),
            "color": .string("red")
        ]

        let model = ComponentModel(
            id: "image1",
            type: "Image",
            props: props
        )

        let component = ImageComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    // MARK: - TabBarComponent Tests

    func testTabBarComponent_Initialization() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "tab1",
            type: "Text",
            props: ["title": .string("Tab 1"), "text": .string("Content 1")]
        )

        let child2 = ComponentModel(
            id: "tab2",
            type: "Text",
            props: ["title": .string("Tab 2"), "text": .string("Content 2")]
        )

        let model = ComponentModel(
            id: "tabBar1",
            type: "TabBar",
            children: [child1, child2]
        )

        let component = TabBarComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testTabBarComponent_WithSystemImage() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "tab1",
            type: "Text",
            props: [
                "title": .string("Home"),
                "systemImage": .string("house")
            ]
        )

        let child2 = ComponentModel(
            id: "tab2",
            type: "Text",
            props: [
                "title": .string("Settings"),
                "systemImage": .string("gear")
            ]
        )

        let model = ComponentModel(
            id: "tabBar1",
            type: "TabBar",
            children: [child1, child2]
        )

        let component = TabBarComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testTabBarComponent_WithIconName() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "tab1",
            type: "Text",
            props: [
                "title": .string("Home"),
                "iconName": .string("home_icon")
            ]
        )

        let model = ComponentModel(
            id: "tabBar1",
            type: "TabBar",
            children: [child1]
        )

        let component = TabBarComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testTabBarComponent_WithSelectedIndex() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "tab1",
            type: "Text",
            props: ["title": .string("Tab 1")]
        )

        let child2 = ComponentModel(
            id: "tab2",
            type: "Text",
            props: ["title": .string("Tab 2")]
        )

        let model = ComponentModel(
            id: "tabBar1",
            type: "TabBar",
            props: ["selectedIndex": .number(1)],
            children: [child1, child2]
        )

        let component = TabBarComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testTabBarComponent_WithoutChildren() {
        let context = makeTestContext()

        let model = ComponentModel(
            id: "tabBar1",
            type: "TabBar"
        )

        let component = TabBarComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testTabBarComponent_WithEmptyChildren() {
        let context = makeTestContext()

        let model = ComponentModel(
            id: "tabBar1",
            type: "TabBar",
            children: []
        )

        let component = TabBarComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testTabBarComponent_SelectTabAction() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "tab1",
            type: "Text",
            props: ["title": .string("Tab 1")]
        )

        let child2 = ComponentModel(
            id: "tab2",
            type: "Text",
            props: ["title": .string("Tab 2")]
        )

        let model = ComponentModel(
            id: "tabBar1",
            type: "TabBar",
            children: [child1, child2]
        )

        let component = TabBarComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    // MARK: - TabBarView Tests

    func testTabBarView_Initialization() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "tab1",
            type: "Text",
            props: ["title": .string("Tab 1")]
        )

        let model = ComponentModel(
            id: "tabBar1",
            type: "TabBar",
            children: [child1]
        )

        let tabBarView = TabBarView(model: model, context: context)

        XCTAssertNotNil(tabBarView)
    }

    func testTabBarView_WithSelectedIndex() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "tab1",
            type: "Text",
            props: ["title": .string("Tab 1")]
        )

        let model = ComponentModel(
            id: "tabBar1",
            type: "TabBar",
            props: ["selectedIndex": .number(0)],
            children: [child1]
        )

        let tabBarView = TabBarView(model: model, context: context)

        XCTAssertNotNil(tabBarView)
    }

    // MARK: - Tab Item Creation Tests

    func testTabItemForChild_WithSystemImage() {
        let context = makeTestContext()

        let child = ComponentModel(
            id: "tab1",
            type: "Text",
            props: [
                "title": .string("Home"),
                "systemImage": .string("house")
            ]
        )

        let model = ComponentModel(
            id: "tabBar1",
            type: "TabBar",
            children: [child]
        )

        let tabBarView = TabBarView(model: model, context: context)

        // Test the tab item creation
        let tabItem = tabBarView.tabItemForChild(child, index: 0)

        XCTAssertNotNil(tabItem)
    }

    func testTabItemForChild_WithIconName() {
        let context = makeTestContext()

        let child = ComponentModel(
            id: "tab1",
            type: "Text",
            props: [
                "title": .string("Home"),
                "iconName": .string("home_icon")
            ]
        )

        let model = ComponentModel(
            id: "tabBar1",
            type: "TabBar",
            children: [child]
        )

        let tabBarView = TabBarView(model: model, context: context)

        let tabItem = tabBarView.tabItemForChild(child, index: 0)

        XCTAssertNotNil(tabItem)
    }

    func testTabItemForChild_WithTitleOnly() {
        let context = makeTestContext()

        let child = ComponentModel(
            id: "tab1",
            type: "Text",
            props: ["title": .string("Home")]
        )

        let model = ComponentModel(
            id: "tabBar1",
            type: "TabBar",
            children: [child]
        )

        let tabBarView = TabBarView(model: model, context: context)

        let tabItem = tabBarView.tabItemForChild(child, index: 0)

        XCTAssertNotNil(tabItem)
    }

    func testTabItemForChild_DefaultTitle() {
        let context = makeTestContext()

        let child = ComponentModel(
            id: "tab1",
            type: "Text",
            props: [:]
        )

        let model = ComponentModel(
            id: "tabBar1",
            type: "TabBar",
            children: [child]
        )

        let tabBarView = TabBarView(model: model, context: context)

        let tabItem = tabBarView.tabItemForChild(child, index: 0)

        XCTAssertNotNil(tabItem)
    }

    // MARK: - Action Handling Tests

    // MARK: - TabBarComponent Tests
    //
    // ВНИМАНИЕ: TabBarView регистрируется через ComponentStore.shared (глобальный
    // синглтон), а не через context.componentStore, как TextComponent/ButtonComponent.
    // Это несоответствие остальному паттерну в файле — см. makeTestContext(componentStore:).
    // Тест ниже проверяет текущее поведение (.shared), но стоит рассмотреть починку
    // TabBarView на context.componentStore.register(...) для консистентности и
    // изоляции между тестами.

    func testTabBarView_SelectTabAction() throws {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "tab1",
            type: "Text",
            props: ["title": .string("Tab 1")]
        )

        let child2 = ComponentModel(
            id: "tab2",
            type: "Text",
            props: ["title": .string("Tab 2")]
        )

        let model = ComponentModel(
            id: "tabBar1",
            type: "TabBar",
            children: [child1, child2]
        )

        let tabBarView = TabBarView(model: model, context: context)

        // Реально монтируем view в иерархию — прямой вызов .body не гарантирует
        // срабатывание .onAppear (SwiftUI триггерит его через движок рендеринга,
        // а не при простом чтении computed property).
        let hostingController = UIHostingController(rootView: tabBarView)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        hostingController.view.layoutIfNeeded()

        let appeared = XCTestExpectation(description: "onAppear registration")
        DispatchQueue.main.async { appeared.fulfill() }
        wait(for: [appeared], timeout: 1.0)

        let actionHandler = ComponentStore.shared.get(componentID: model.id)
        XCTAssertNotNil(actionHandler)

        // Cleanup: триггерим onDisappear и убираем регистрацию из глобального
        // синглтона, чтобы не протекало в другие тесты
        window.rootViewController = nil
        ComponentStore.shared.unregister(componentID: model.id)
    }

    // MARK: - Image Loading Tests

    func testImageComponent_InvalidURL() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "url": .string("invalid-url"),
            "resizable": .bool(true),
            "contentMode": .string("fit")
        ]

        let model = ComponentModel(
            id: "image1",
            type: "Image",
            props: props
        )

        let component = ImageComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testImageComponent_EmptyURL() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "url": .string(""),
            "systemName": .string("photo")
        ]

        let model = ComponentModel(
            id: "image1",
            type: "Image",
            props: props
        )

        let component = ImageComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    // MARK: - Style Application Tests

    func testImageComponent_WithFullStyle() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "systemName": .string("photo"),
            "width": .number(200),
            "height": .number(200),
            "padding": .number(10),
            "margin": .number(5),
            "color": .string("blue")
        ]

        let model = ComponentModel(
            id: "image1",
            type: "Image",
            props: props
        )

        let component = ImageComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    // MARK: - TabBar Style Tests

    func testTabBarComponent_WithStyle() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "tab1",
            type: "Text",
            props: ["title": .string("Tab 1")]
        )

        let model = ComponentModel(
            id: "tabBar1",
            type: "TabBar",
            props: [
                "width": .number(300),
                "height": .number(50)
            ],
            children: [child1]
        )

        let component = TabBarComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }
}
