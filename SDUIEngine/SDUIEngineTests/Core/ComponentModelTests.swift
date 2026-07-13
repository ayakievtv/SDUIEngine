import XCTest
@testable import SDUIEngine

final class ComponentModelTests: XCTestCase {

    // MARK: - Тесты на декодирование и кодирование

    func testDecodeEncode_NullValues() throws {
        let json = """
        {
            "id": "test1",
            "type": "Text",
            "props": null,
            "events": null,
            "children": null
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ComponentModel.self, from: data)
        
        XCTAssertEqual(decoded.id, "test1")
        XCTAssertEqual(decoded.type, "Text")
        XCTAssertNil(decoded.props)
        XCTAssertNil(decoded.events)
        XCTAssertNil(decoded.children)
        
        let encoded = try JSONEncoder().encode(decoded)
        let decodedAgain = try JSONDecoder().decode(ComponentModel.self, from: encoded)
        
        XCTAssertEqual(decoded, decodedAgain)
    }

    func testDecodeEncode_EmptyPropsEventsChildren() throws {
        let json = """
        {
            "id": "test2",
            "type": "Button",
            "props": {},
            "events": {},
            "children": []
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ComponentModel.self, from: data)
        
        XCTAssertEqual(decoded.id, "test2")
        XCTAssertEqual(decoded.type, "Button")
        XCTAssertNotNil(decoded.props)
        XCTAssertTrue(decoded.props!.isEmpty)
        XCTAssertNotNil(decoded.events)
        XCTAssertTrue(decoded.events!.isEmpty)
        XCTAssertNotNil(decoded.children)
        XCTAssertTrue(decoded.children!.isEmpty)
        
        let encoded = try JSONEncoder().encode(decoded)
        let decodedAgain = try JSONDecoder().decode(ComponentModel.self, from: encoded)
        
        XCTAssertEqual(decoded, decodedAgain)
    }

    func testDecodeEncode_FullComponent() throws {
        let json = """
        {
            "id": "test3",
            "type": "VStack",
            "props": {"spacing": 10},
            "events": {"onTap": {"target": "button1"}},
            "children": [
                {"id": "child1", "type": "Text", "props": {"text": "Hello"}}
            ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ComponentModel.self, from: data)
        
        XCTAssertEqual(decoded.id, "test3")
        XCTAssertEqual(decoded.type, "VStack")
        XCTAssertNotNil(decoded.props)
        XCTAssertEqual(decoded.props?["spacing"]?.numberValue, 10)
        XCTAssertNotNil(decoded.events)
        XCTAssertEqual(decoded.events?["onTap"]?.objectValue?["target"]?.stringValue, "button1")
        XCTAssertNotNil(decoded.children)
        XCTAssertEqual(decoded.children?.count, 1)
        XCTAssertEqual(decoded.children?.first?.id, "child1")
        
        let encoded = try JSONEncoder().encode(decoded)
        let decodedAgain = try JSONDecoder().decode(ComponentModel.self, from: encoded)
        
        XCTAssertEqual(decoded, decodedAgain)
    }

    // MARK: - Тесты на поведение при отсутствии опциональных полей

    func testDecode_MissingOptionalFields() throws {
        let json = """
        {
            "id": "test4",
            "type": "Image"
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ComponentModel.self, from: data)
        
        XCTAssertEqual(decoded.id, "test4")
        XCTAssertEqual(decoded.type, "Image")
        XCTAssertNil(decoded.props)
        XCTAssertNil(decoded.events)
        XCTAssertNil(decoded.children)
    }

    func testResolvedProperties_ReturnEmptyDictWhenNil() {
        let model = ComponentModel(
            id: "test5",
            type: "Text",
            props: nil,
            events: nil,
            children: nil
        )
        
        XCTAssertTrue(model.resolvedProps.isEmpty)
        XCTAssertTrue(model.resolvedEvents.isEmpty)
        XCTAssertTrue(model.resolvedChildren.isEmpty)
    }

    // MARK: - Тесты на Equatable для вложенных структур

    func testEquatable_SimpleComponents() {
        let model1 = ComponentModel(id: "1", type: "Text", props: nil, events: nil, children: nil)
        let model2 = ComponentModel(id: "1", type: "Text", props: nil, events: nil, children: nil)
        let model3 = ComponentModel(id: "2", type: "Text", props: nil, events: nil, children: nil)
        
        XCTAssertEqual(model1, model2)
        XCTAssertNotEqual(model1, model3)
    }

    func testEquatable_WithProps() {
        let props1: [String: JSONValue] = ["text": .string("Hello"), "color": .string("#000")]
        let props2: [String: JSONValue] = ["text": .string("Hello"), "color": .string("#000")]
        let props3: [String: JSONValue] = ["text": .string("World"), "color": .string("#000")]
        
        let model1 = ComponentModel(id: "1", type: "Text", props: props1, events: nil, children: nil)
        let model2 = ComponentModel(id: "1", type: "Text", props: props2, events: nil, children: nil)
        let model3 = ComponentModel(id: "1", type: "Text", props: props3, events: nil, children: nil)
        
        XCTAssertEqual(model1, model2)
        XCTAssertNotEqual(model1, model3)
    }

    func testEquatable_NestedChildren() {
        let child1 = ComponentModel(id: "child1", type: "Text", props: ["text": .string("Child")], events: nil, children: nil)
        let child2 = ComponentModel(id: "child1", type: "Text", props: ["text": .string("Child")], events: nil, children: nil)
        let child3 = ComponentModel(id: "child2", type: "Text", props: ["text": .string("Child")], events: nil, children: nil)
        
        let model1 = ComponentModel(id: "parent", type: "VStack", props: nil, events: nil, children: [child1])
        let model2 = ComponentModel(id: "parent", type: "VStack", props: nil, events: nil, children: [child2])
        let model3 = ComponentModel(id: "parent", type: "VStack", props: nil, events: nil, children: [child3])
        
        XCTAssertEqual(model1, model2)
        XCTAssertNotEqual(model1, model3)
    }

    func testEquatable_WithEvents() {
        let events1: [String: JSONValue] = ["onTap": .object(["target": .string("button1")])]
        let events2: [String: JSONValue] = ["onTap": .object(["target": .string("button1")])]
        let events3: [String: JSONValue] = ["onTap": .object(["target": .string("button2")])]
        
        let model1 = ComponentModel(id: "1", type: "Button", props: nil, events: events1, children: nil)
        let model2 = ComponentModel(id: "1", type: "Button", props: nil, events: events2, children: nil)
        let model3 = ComponentModel(id: "1", type: "Button", props: nil, events: events3, children: nil)
        
        XCTAssertEqual(model1, model2)
        XCTAssertNotEqual(model1, model3)
    }
}
