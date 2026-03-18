import XCTest
@testable import SDUIEngine

private struct TestGridRow {
    let id: String
    let payload: [String: JSONValue]
}

private enum TestDBGridParser {
    static func parseRows(
        response: JSONValue,
        keyField: String,
        pageSize: Int
    ) -> (rows: [TestGridRow], nextCursor: String?, hasMore: Bool) {
        if let object = response.objectValue {
            let items = object["items"]?.arrayValue ?? []
            let rows: [TestGridRow] = items.enumerated().compactMap { index, item in
                guard let payload = item.objectValue else { return nil }
                let id = payload[keyField]?.stringValue
                    ?? payload["id"]?.stringValue
                    ?? payload["uuid"]?.stringValue
                    ?? "row_\(index)"
                return TestGridRow(id: id, payload: payload)
            }
            let nextCursor = object["nextCursor"]?.stringValue
                ?? object["offset"]?.stringValue
                ?? object["cursor"]?.stringValue
            let hasMore = object["hasMore"]?.boolValue ?? ((nextCursor != nil) || rows.count >= pageSize)
            return (rows, nextCursor, hasMore)
        }

        if let array = response.arrayValue {
            let rows: [TestGridRow] = array.enumerated().compactMap { index, item in
                guard let payload = item.objectValue else { return nil }
                let id = payload[keyField]?.stringValue
                    ?? payload["id"]?.stringValue
                    ?? payload["uuid"]?.stringValue
                    ?? "row_\(index)"
                return TestGridRow(id: id, payload: payload)
            }
            return (rows, nil, rows.count >= pageSize)
        }

        return ([], nil, false)
    }
}

private enum TestInterpolation {
    static func render(_ template: String, payload: [String: JSONValue]) -> String {
        var output = template
        while let open = output.range(of: "{{"),
              let close = output.range(of: "}}", range: open.upperBound..<output.endIndex) {
            let key = output[open.upperBound..<close.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let replacement = payloadString(payload: payload, key: key)
            output.replaceSubrange(open.lowerBound..<close.upperBound, with: replacement)
        }
        return output
    }

    private static func payloadString(payload: [String: JSONValue], key: String) -> String {
        let segments = key.split(separator: ".").map(String.init)
        guard !segments.isEmpty else { return "" }

        var current: JSONValue? = .object(payload)
        for segment in segments {
            guard let object = current?.objectValue else { return "" }
            current = object[segment]
        }

        if let string = current?.stringValue { return string }
        if let number = current?.numberValue { return String(number) }
        if let bool = current?.boolValue { return bool ? "true" : "false" }
        return ""
    }
}

final class DBGridParsingInterpolationTests: XCTestCase {
    func testDBGridParsingWithItemsNextCursorAndHasMore() {
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

        let parsed = TestDBGridParser.parseRows(response: response, keyField: "uuid", pageSize: 20)

        XCTAssertEqual(parsed.rows.count, 2)
        XCTAssertEqual(parsed.rows[0].id, "u-1")
        XCTAssertEqual(parsed.rows[1].payload["doc_number"]?.stringValue, "INV-2")
        XCTAssertEqual(parsed.nextCursor, "offset:2")
        XCTAssertTrue(parsed.hasMore)
    }

    func testInterpolationResolvesNestedPlaceholders() {
        let payload: [String: JSONValue] = [
            "doc_number": .string("INV-9"),
            "customer_name": .string("Client X"),
            "meta": .object(["status": .string("PAID")])
        ]

        let title = TestInterpolation.render("Invoice {{doc_number}}", payload: payload)
        let subtitle = TestInterpolation.render("{{customer_name}}", payload: payload)
        let caption = TestInterpolation.render("{{meta.status}}", payload: payload)

        XCTAssertEqual(title, "Invoice INV-9")
        XCTAssertEqual(subtitle, "Client X")
        XCTAssertEqual(caption, "PAID")
    }
}
