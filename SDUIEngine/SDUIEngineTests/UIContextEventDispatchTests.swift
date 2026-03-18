import XCTest
@testable import SDUIEngine

@MainActor
final class UIContextEventDispatchTests: XCTestCase {
    func testActionChainDispatchesToMultipleTargetsOnceEach() async {
        let api = RecordingAPIClient()
        let navigation = NavigationSpy()
        let componentStore = ComponentStore()
        let context = UIContext(
            navigation: navigation,
            apiClient: api,
            componentStore: componentStore
        )

        var received: [(String, [String: String]?)] = []
        componentStore.register(componentID: "title_text", component: AnyComponent { action, params in
            received.append((action, params))
        })
        componentStore.register(componentID: "subtitle_text", component: AnyComponent { action, params in
            received.append((action, params))
        })

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

        context.dispatch(event)

        XCTAssertEqual(received.count, 3)
        XCTAssertEqual(received.map(\.0), ["SET_TEXT", "SET_COLOR", "SET_COLOR"])
        XCTAssertEqual(received[0].1?["value"], "Hello")
        XCTAssertEqual(received[1].1?["value"], "#00AAFF")
        XCTAssertEqual(received[2].1?["value"], "#00AAFF")
    }
}
