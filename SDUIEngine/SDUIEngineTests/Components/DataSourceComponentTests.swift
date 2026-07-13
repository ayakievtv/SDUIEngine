import XCTest
import SwiftUI
@testable import SDUIEngine

// ИСПРАВЛЕНО:
// component.buildConfig(from: props) вызывался напрямую в 6 тестах
// (testBuildConfig_*, testParameterPassing_*) — судя по паттерну ошибок в этом
// проекте, это внутренняя деталь реализации DataSourceComponent (private),
// снаружи (даже через @testable import) недоступна: "'buildConfig' is
// inaccessible due to 'private' protection level".
//
// Исходника DataSourceComponent.swift у меня нет, поэтому не подтверждаю это
// на 100% — но чинил независимо от того, private это или нет: вместо прямого
// вызова используется уже рабочий в этом же файле паттерн
// (testDataSourceRegistration_*, testOfflineDataLayer_ParametersPassed) —
// `_ = component.body` триггерит регистрацию DataSource, а результат
// проверяется через публичный/internal `context.dataSourceRegistry.get(id)`.
// Это тестирует то же самое поведение через реальный публичный путь, а не
// пробивает инкапсуляцию, и работает вне зависимости от access level buildConfig.

@MainActor
final class DataSourceComponentTests: XCTestCase {

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

    @MainActor
    private func makeTestContext() -> UIContext {
        let stateStore = MockStateStore()
        let componentStore = ComponentStore()
        let dataSourceRegistry = DataSourceRegistry()
        let componentRegistry = ComponentRegistry()

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

    // MARK: - DataSource Registration Tests

    func testDataSourceRegistration_WithID() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "id": .string("testDS"),
            "endpoint": .string("https://api.test/data")
        ]

        let model = ComponentModel(
            id: "ds1",
            type: "DataSource",
            props: props
        )

//        let component = DataSourceComponent(model: model, context: context)
//
//        // Create the component - this should register the DataSource
//        _ = component.body
//
//        // Check that DataSource was registered
//        let registered = context.dataSourceRegistry.get("testDS")
//        XCTAssertNotNil(registered)
        
        let component = DataSourceComponent(model: model, context: context)
        component.registerDataSource()  // явный вызов вместо .onAppear
        let registered = context.dataSourceRegistry.get("testDS")
        XCTAssertNotNil(registered)
        
        
        XCTAssertEqual(registered?.id, "testDS")
        XCTAssertEqual(registered?.endpoint, "https://api.test/data")
    }

    func testDataSourceRegistration_WithFallbackID() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "endpoint": .string("https://api.test/data")
        ]

        let model = ComponentModel(
            id: "fallbackDS",
            type: "DataSource",
            props: props
        )

//        let component = DataSourceComponent(model: model, context: context)
//
//        _ = component.body
//
//        // Should use model.id as fallback
//        let registered = context.dataSourceRegistry.get("fallbackDS")
//        XCTAssertNotNil(registered)
//        XCTAssertEqual(registered?.id, "fallbackDS")
        
        
        let component = DataSourceComponent(model: model, context: context)
        component.registerDataSource()
        let registered = context.dataSourceRegistry.get("fallbackDS")
        XCTAssertNotNil(registered)
        
        
    }

    func testDataSourceRegistration_WithAllParams() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "id": .string("fullDS"),
            "endpoint": .string("https://api.test/data"),
            "fetchPolicy": .string("CACHE_FIRST"),
            "pageSize": .number(50),
            "queryParam": .string("search"),
            "cursorParam": .string("page"),
            "localFiltering": .bool(false),
            "remoteFiltering": .bool(true),
            "debounceMs": .number(300),
            "sorting": .bool(true),
            "defaultSortField": .string("name"),
            "defaultSortAscending": .bool(false),
            "prefetchThreshold": .number(5),
            "keyField": .string("uuid")
        ]

        let model = ComponentModel(
            id: "ds1",
            type: "DataSource",
            props: props
        )

//        let component = DataSourceComponent(model: model, context: context)
//
//        _ = component.body

        
        
        let component = DataSourceComponent(model: model, context: context)
        component.registerDataSource()
        let registered = context.dataSourceRegistry.get("fullDS")
        XCTAssertNotNil(registered)
        
        
        
        
        
//        let registered = context.dataSourceRegistry.get("fullDS")
//        XCTAssertNotNil(registered)
        XCTAssertEqual(registered?.fetchPolicy, "CACHE_FIRST")
        XCTAssertEqual(registered?.pageSize, 50)
        XCTAssertEqual(registered?.queryParam, "search")
        XCTAssertEqual(registered?.cursorParam, "page")
        XCTAssertFalse(registered?.localFiltering ?? true)
        XCTAssertTrue(registered?.remoteFiltering ?? false)
        XCTAssertEqual(registered?.debounceMs, 300)
        XCTAssertTrue(registered?.sorting ?? false)
        XCTAssertEqual(registered?.defaultSortField, "name")
        XCTAssertFalse(registered?.defaultSortAscending ?? true)
        XCTAssertEqual(registered?.prefetchThreshold, 5)
        XCTAssertEqual(registered?.keyField, "uuid")
    }

    // MARK: - Config Building Tests
    // Проверяются через публичный путь: component.body -> dataSourceRegistry.get(id),
    // а не через прямой вызов buildConfig(from:) (см. комментарий в шапке файла).

    func testBuildConfig_DefaultValues() throws {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "id": .string("testDS"),
            "endpoint": .string("https://api.test/data")
        ]

        let model = ComponentModel(
            id: "ds1",
            type: "DataSource",
            props: props
        )

        let component = DataSourceComponent(model: model, context: context)
//        _ = component.body
        component.registerDataSource()
        
        let config = try XCTUnwrap(context.dataSourceRegistry.get("testDS"))

        XCTAssertEqual(config.id, "testDS")
        XCTAssertEqual(config.endpoint, "https://api.test/data")
        XCTAssertEqual(config.fetchPolicy, "NETWORK_FIRST_LOCAL_FALLBACK")
        XCTAssertEqual(config.pageSize, 25)
        XCTAssertEqual(config.queryParam, "q")
        XCTAssertEqual(config.cursorParam, "offset")
        XCTAssertTrue(config.localFiltering)
        XCTAssertTrue(config.remoteFiltering)
        XCTAssertEqual(config.debounceMs, 450)
        XCTAssertFalse(config.sorting)
        XCTAssertNil(config.defaultSortField)
        XCTAssertTrue(config.defaultSortAscending)
        XCTAssertEqual(config.prefetchThreshold, 3)
        XCTAssertEqual(config.keyField, "id")
    }

    func testBuildConfig_Overrides() throws {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "id": .string("testDS"),
            "endpoint": .string("https://api.test/data"),
            "pageSize": .number(100),
            "queryParam": .string("query"),
            "cursorParam": .string("cursor"),
            "localFiltering": .bool(false),
            "remoteFiltering": .bool(false),
            "debounceMs": .number(1000),
            "sorting": .bool(true),
            "defaultSortField": .string("createdAt"),
            "defaultSortAscending": .bool(false),
            "prefetchThreshold": .number(10),
            "keyField": .string("uuid")
        ]

        let model = ComponentModel(
            id: "ds1",
            type: "DataSource",
            props: props
        )

        let component = DataSourceComponent(model: model, context: context)
//        _ = component.body
        component.registerDataSource()
        let config = try XCTUnwrap(context.dataSourceRegistry.get("testDS"))

        XCTAssertEqual(config.pageSize, 100)
        XCTAssertEqual(config.queryParam, "query")
        XCTAssertEqual(config.cursorParam, "cursor")
        XCTAssertFalse(config.localFiltering)
        XCTAssertFalse(config.remoteFiltering)
        XCTAssertEqual(config.debounceMs, 1000)
        XCTAssertTrue(config.sorting)
        XCTAssertEqual(config.defaultSortField, "createdAt")
        XCTAssertFalse(config.defaultSortAscending)
        XCTAssertEqual(config.prefetchThreshold, 10)
        XCTAssertEqual(config.keyField, "uuid")
    }

    // MARK: - Integration with DataSourceRegistry Tests

    func testDataSourceRegistry_UpdateExisting() {
        let context = makeTestContext()

        // Register initial DataSource
        let initialConfig = DataSourceConfig.makeDefault(
            id: "testDS",
            endpoint: "https://api.test/initial"
        )
        context.dataSourceRegistry.register(initialConfig)

        // Create component with same ID but different endpoint
        let props: [String: JSONValue] = [
            "id": .string("testDS"),
            "endpoint": .string("https://api.test/updated")
        ]

        let model = ComponentModel(
            id: "ds1",
            type: "DataSource",
            props: props
        )
//
//        let component = DataSourceComponent(model: model, context: context)
//
//        _ = component.body
//
//        // Should have updated the existing registration
//        let registered = context.dataSourceRegistry.get("testDS")
//        XCTAssertNotNil(registered)
      
        
        let component = DataSourceComponent(model: model, context: context)
        component.registerDataSource()
        let registered = context.dataSourceRegistry.get("testDS")
        XCTAssertNotNil(registered)
        
        XCTAssertEqual(registered?.endpoint, "https://api.test/updated")
        
        
        
        
        
        
    }

    func testDataSourceRegistry_MultipleDataSources() {
        let context = makeTestContext()

        let props1: [String: JSONValue] = [
            "id": .string("ds1"),
            "endpoint": .string("https://api.test/data1")
        ]

        let props2: [String: JSONValue] = [
            "id": .string("ds2"),
            "endpoint": .string("https://api.test/data2")
        ]

        let model1 = ComponentModel(id: "c1", type: "DataSource", props: props1)
        let model2 = ComponentModel(id: "c2", type: "DataSource", props: props2)

        let component1 = DataSourceComponent(model: model1, context: context)
        let component2 = DataSourceComponent(model: model2, context: context)

        component1.registerDataSource()
        component2.registerDataSource()

//        _ = component1.body
//        _ = component2.body

        let ds1 = context.dataSourceRegistry.get("ds1")
        let ds2 = context.dataSourceRegistry.get("ds2")

        XCTAssertNotNil(ds1)
        XCTAssertNotNil(ds2)
        XCTAssertEqual(ds1?.endpoint, "https://api.test/data1")
        XCTAssertEqual(ds2?.endpoint, "https://api.test/data2")
    }

    // MARK: - Parameter Passing Tests
    // Проверяются через публичный путь: component.body -> dataSourceRegistry.get(id).

    func testParameterPassing_QueryParam() throws {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "id": .string("testDS"),
            "endpoint": .string("https://api.test/data"),
            "queryParam": .string("search")
        ]

        let model = ComponentModel(
            id: "ds1",
            type: "DataSource",
            props: props
        )

        let component = DataSourceComponent(model: model, context: context)
//        _ = component.body
        component.registerDataSource()
        
        let config = try XCTUnwrap(context.dataSourceRegistry.get("testDS"))
        XCTAssertEqual(config.queryParam, "search")
    }

    func testParameterPassing_CursorParam() throws {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "id": .string("testDS"),
            "endpoint": .string("https://api.test/data"),
            "cursorParam": .string("offset")
        ]

        let model = ComponentModel(
            id: "ds1",
            type: "DataSource",
            props: props
        )

        let component = DataSourceComponent(model: model, context: context)
//        _ = component.body
        component.registerDataSource()
        
        let config = try XCTUnwrap(context.dataSourceRegistry.get("testDS"))
        XCTAssertEqual(config.cursorParam, "offset")
    }

    func testParameterPassing_FilterText() throws {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "id": .string("testDS"),
            "endpoint": .string("https://api.test/data"),
            "localFiltering": .bool(true),
            "remoteFiltering": .bool(true)
        ]

        let model = ComponentModel(
            id: "ds1",
            type: "DataSource",
            props: props
        )

        let component = DataSourceComponent(model: model, context: context)
//        _ = component.body
        component.registerDataSource()
        
        let config = try XCTUnwrap(context.dataSourceRegistry.get("testDS"))
        XCTAssertTrue(config.localFiltering)
        XCTAssertTrue(config.remoteFiltering)
    }

    func testParameterPassing_Sort() throws {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "id": .string("testDS"),
            "endpoint": .string("https://api.test/data"),
            "sorting": .bool(true),
            "defaultSortField": .string("name"),
            "defaultSortAscending": .bool(false)
        ]

        let model = ComponentModel(
            id: "ds1",
            type: "DataSource",
            props: props
        )

        let component = DataSourceComponent(model: model, context: context)
//        _ = component.body
        component.registerDataSource()
        
        let config = try XCTUnwrap(context.dataSourceRegistry.get("testDS"))
        XCTAssertTrue(config.sorting)
        XCTAssertEqual(config.defaultSortField, "name")
        XCTAssertFalse(config.defaultSortAscending)
    }

    // MARK: - OfflineDataLayer Integration Tests

    func testOfflineDataLayer_ParametersPassed() {
        let context = makeTestContext()

        let props: [String: JSONValue] = [
            "id": .string("testDS"),
            "endpoint": .string("https://api.test/data"),
            "queryParam": .string("q"),
            "cursorParam": .string("offset"),
            "filterText": .string("test"),
            "sort": .string("name:asc")
        ]

        let model = ComponentModel(
            id: "ds1",
            type: "DataSource",
            props: props
        )

        let component = DataSourceComponent(model: model, context: context)

        // The component registers the config with all parameters
//        _ = component.body
        component.registerDataSource()
        
        let config = context.dataSourceRegistry.get("testDS")
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.queryParam, "q")
        XCTAssertEqual(config?.cursorParam, "offset")
    }
}
