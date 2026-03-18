import XCTest
@testable import SDUIEngine

@MainActor
final class UIContextBackendDataTests: XCTestCase {
    func testOpenFormLoadsPayloadIntoStateWithIDReplacement() async {
        let api = RecordingAPIClient()
        let navigation = NavigationSpy()
        let context = UIContext(navigation: navigation, apiClient: api)

        context.setState(key: "invoiceForm.id", value: .string("abc-123"))

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

        let event = makeActionEvent(actions: [[
            "target": .string("backend_data"),
            "action": .string("OPEN_FORM"),
            "endpoint": .string("https://example.com/invoices/{id}"),
            "idStateKey": .string("invoiceForm.id"),
            "formStatePrefix": .string("invoiceForm"),
            "clearPreviousDraft": .string("true")
        ]])

        context.dispatch(event)

        await waitUntil {
            context.stateValue(for: "invoiceForm.doc_number")?.stringValue == "INV-42"
        }

        XCTAssertEqual(context.stateValue(for: "invoiceForm.customer_name")?.stringValue, "ACME")
        XCTAssertEqual(context.stateValue(for: "invoiceForm.uuid")?.stringValue, "abc-123")
    }

    func testSaveFormWorksWithoutFormStatePrefixUsingIdStateKeyInference() async {
        let api = RecordingAPIClient()
        let navigation = NavigationSpy()
        let context = UIContext(navigation: navigation, apiClient: api)

        context.setState(key: "invoiceForm.id", value: .string("id-77"))
        context.setState(key: "invoiceForm.doc_number", value: .string("INV-77"))
        context.setState(key: "invoiceForm.status", value: .string("NEW"))

        let event = makeActionEvent(actions: [[
            "target": .string("backend_data"),
            "action": .string("SAVE_FORM"),
            "endpoint": .string("https://example.com/invoices/{id}"),
            "idStateKey": .string("invoiceForm.id"),
            "method": .string("PUT")
        ]])

        context.dispatch(event)

        await waitUntil {
            api.requests.count == 1
        }

        guard let first = api.requests.first else {
            return XCTFail("Expected one save request")
        }

        XCTAssertEqual(first.method, .put)
        XCTAssertTrue(first.endpoint.hasSuffix("/id-77"))
        XCTAssertEqual(first.body?["doc_number"]?.stringValue, "INV-77")
        XCTAssertEqual(first.body?["status"]?.stringValue, "NEW")
    }

    func testDiscardFormClearsPrefixAndCanGoBack() async {
        let api = RecordingAPIClient()
        let navigation = NavigationSpy()
        navigation.push(.screen(name: "invoice_edit_form"))

        let context = UIContext(navigation: navigation, apiClient: api)
        context.setState(key: "invoiceForm.doc_number", value: .string("INV-100"))
        context.setState(key: "invoiceForm.customer_name", value: .string("Old customer"))

        let event = makeActionEvent(actions: [[
            "target": .string("backend_data"),
            "action": .string("DISCARD_FORM"),
            "formStatePrefix": .string("invoiceForm"),
            "goBack": .string("true")
        ]])

        context.dispatch(event)

        await waitUntil {
            context.stateValue(for: "invoiceForm.doc_number")?.stringValue == ""
        }

        XCTAssertEqual(context.stateValue(for: "invoiceForm.customer_name")?.stringValue, "")
        XCTAssertEqual(navigation.popCount, 1)
    }
}
