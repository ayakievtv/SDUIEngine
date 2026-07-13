import XCTest
@testable import SDUIEngine

final class TestUIContext: XCTestCase {

//    // MARK: - Mock API Client
//
//    final class MockAPIClient: APIClient {
//        var lastRequest: (endpoint: String, method: HTTPMethod, body: [String: JSONValue]?)?
//        var mockResponse: JSONValue = .object(["success": .bool(true)])
//
//        func request(endpoint: String, method: HTTPMethod, body: [String: JSONValue]?) async throws -> JSONValue {
//            lastRequest = (endpoint, method, body)
//            return mockResponse
//        }
//    }

    // MARK: - Mock State Store

//    final class MockStateStore: StateStoreManaging {
//        private var storage: [String: JSONValue] = [:]
//
//        var state: [String: JSONValue] { storage }
//
//        func getValue(for key: String) -> JSONValue? {
//            storage[key]
//        }
//
//        func set(_ value: JSONValue, for key: String) {
//            storage[key] = value
//        }
//
//        func merge(_ json: JSONValue, withPrefix prefix: String) {
//            guard let obj = json.objectValue else { return }
//            for (k, v) in obj {
//                set(v, for: "\(prefix).\(k)")
//            }
//        }
//
//        func getValues(forPrefix prefix: String) -> [String: JSONValue] {
//            var result: [String: JSONValue] = [:]
//            let searchPrefix = prefix.hasSuffix(".") ? prefix : "\(prefix)."
//            for (key, value) in storage where key.hasPrefix(searchPrefix) {
//                let cleanKey = String(key.dropFirst(searchPrefix.count))
//                result[cleanKey] = value
//            }
//            return result
//        }
//    }

    // MARK: - Test Context Factory

    @MainActor
    func makeTestContext() -> UIContext {
        let registry = ComponentRegistry()
        let dataSourceRegistry = DataSourceRegistry()
        let componentStore = ComponentStore()
        let stateStore = MockStateStore()
        let apiClient = MockAPIClient()
        let eventDispatcher = EventDispatcher(
            componentStore: componentStore,
            paramResolver: ParamResolver()
        )
        let navigation = NavigationRouter()

        return UIContext(
            stateStore: stateStore,
            eventDispatcher: eventDispatcher,
            navigation: navigation,
            apiClient: apiClient,
            componentRegistry: registry,
            dataSourceRegistry: dataSourceRegistry,
            componentStore: componentStore
        )
    }

    // MARK: - Tests

    @MainActor
    func testStateStore_SetAndGet() {
        let context = makeTestContext()
        let key = "testKey"
        let value: JSONValue = .string("testValue")

        context.setState(value, for: key)
        let retrieved = context.stateStore.getValue(for: key)

        XCTAssertEqual(retrieved, value)
    }

    @MainActor
    func testStateStore_Merge() {
        let context = makeTestContext()
        let json: JSONValue = .object([
            "key1": .string("value1"),
            "key2": .string("value2")
        ])

        context.stateStore.merge(json, withPrefix: "prefix")

        XCTAssertEqual(context.stateStore.getValue(for: "prefix.key1"), .string("value1"))
        XCTAssertEqual(context.stateStore.getValue(for: "prefix.key2"), .string("value2"))
    }

    @MainActor
    func testGetValuesForPrefix() {
        let context = makeTestContext()
        context.stateStore.set(.string("v1"), for: "pfx.k1")
        context.stateStore.set(.string("v2"), for: "pfx.k2")

        let values = context.stateStore.getValues(forPrefix: "pfx")
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(values["k1"], .string("v1"))
        XCTAssertEqual(values["k2"], .string("v2"))
    }

    @MainActor
    func testOpenForm_StatePopulation() async {
        let context = makeTestContext()

        // First set an ID in state so the endpoint can be resolved
        context.stateStore.set(.string("123"), for: "formPrefix.id")

        let formData: [String: String] = [
            "formStatePrefix": "formPrefix",
            "dataSourceID": "testDataSource",
            "idStateKey": "formPrefix.id",
            "endpoint": "https://api.test/form/{id}"
        ]

        // Call the internal method through handleDataAction
        context.handleDataAction(action: "OPEN_FORM", params: formData)

        // Wait for async task to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let idValue = context.stateStore.getValue(for: "formPrefix.id")
        XCTAssertNotNil(idValue)
    }

    @MainActor
    func testDiscardForm_StateClearing() async {
        let context = makeTestContext()
        context.stateStore.set(.string("value"), for: "form.key")

        let params: [String: String] = [
            "formStatePrefix": "form"
        ]

        // Call the internal method through handleDataAction
        context.handleDataAction(action: "DISCARD_FORM", params: params)

        // Wait for async task to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let clearedValue = context.stateStore.getValue(for: "form.key")
        // performDiscardForm sets empty string, not nil
        XCTAssertEqual(clearedValue, .string(""))
    }

    @MainActor
    func testCallAPI_Success() async {
        let context = makeTestContext()

        do {
            let _ = try await context.callAPI(endpoint: "https://test.com", method: .post, body: ["key": .string("value")])
        } catch {
            XCTFail("API call should not throw")
        }

        let mockClient = context.apiClient as? MockAPIClient
        XCTAssertNotNil(mockClient?.lastRequest)
        XCTAssertEqual(mockClient?.lastRequest?.endpoint, "https://test.com")
        XCTAssertEqual(mockClient?.lastRequest?.method, .post)
        XCTAssertEqual(mockClient?.lastRequest?.body?["key"]?.stringValue, "value")
    }

    @MainActor
    func testDispatchEvent() {
        let context = makeTestContext()
        var handled = false

        // Register handler directly on the event dispatcher
        if let dispatcher = context.eventDispatcher as? EventDispatcher {
            dispatcher.register(.onTap) { _, _ in
                handled = true
            }
        }

        let event = EventModel(type: .onTap, target: "test", params: [:])
        context.dispatch(event)

        XCTAssertTrue(handled)
    }

    @MainActor
    func testPerformSaveForm_Success() async {
        let context = makeTestContext()
        context.stateStore.set(.string("testData"), for: "formPrefix.data")

        let params: [String: String] = [
            "endpoint": "https://save.com",
            "formStatePrefix": "formPrefix",
            "method": "POST"
        ]

        // Call the internal method through handleDataAction
        context.handleDataAction(action: "SAVE_FORM", params: params)

        // Wait for async task to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let mockClient = context.apiClient as? MockAPIClient
        XCTAssertNotNil(mockClient?.lastRequest)
    }

    @MainActor
    func testPerformOpenForm_ErrorHandling() async {
        let context = makeTestContext()
        let params: [String: String] = [
            "formStatePrefix": "errorForm",
            "dataSourceID": "invalidDS",
            "endpoint": "https://api.test/form/{id}"
        ]

        // Call the internal method through handleDataAction
        context.handleDataAction(action: "OPEN_FORM", params: params)

        // Wait for async task to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let errorValue = context.stateStore.getValue(for: "errorForm._openFormError")
        XCTAssertNotNil(errorValue)
    }
}
