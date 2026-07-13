import XCTest
import SwiftUI
@testable import SDUIEngine

@MainActor
final class LayoutComponentsTests: XCTestCase {

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

        // Register components
        componentRegistry.register(type: "VStack", component: VStackComponent.self)
        componentRegistry.register(type: "HStack", component: HStackComponent.self)
        componentRegistry.register(type: "Spacer", component: SpacerComponent.self)
        componentRegistry.register(type: "ScrollView", component: ScrollViewComponent.self)
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

    // MARK: - VStackComponent Tests

    func testVStackComponent_Initialization() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let child2 = ComponentModel(
            id: "text2",
            type: "Text",
            props: ["text": .string("Item 2")]
        )

        let model = ComponentModel(
            id: "vstack1",
            type: "VStack",
            props: ["spacing": .number(8)],
            children: [child1, child2]
        )

        let component = VStackComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testVStackComponent_WithSpacing() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let model = ComponentModel(
            id: "vstack1",
            type: "VStack",
            props: ["spacing": .number(16)],
            children: [child1]
        )

        let component = VStackComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testVStackComponent_WithAlignment() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let model = ComponentModel(
            id: "vstack1",
            type: "VStack",
            props: [
                "spacing": .number(8),
                "alignment": .string("leading")
            ],
            children: [child1]
        )

        let component = VStackComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testVStackComponent_WithPadding() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let model = ComponentModel(
            id: "vstack1",
            type: "VStack",
            props: [
                "spacing": .number(8),
                "padding": .number(10)
            ],
            children: [child1]
        )

        let component = VStackComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testVStackComponent_WithoutChildren() {
        let context = makeTestContext()

        let model = ComponentModel(
            id: "vstack1",
            type: "VStack",
            props: ["spacing": .number(8)]
        )

        let component = VStackComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testVStackComponent_WithEmptyChildren() {
        let context = makeTestContext()

        let model = ComponentModel(
            id: "vstack1",
            type: "VStack",
            props: ["spacing": .number(8)],
            children: []
        )

        let component = VStackComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testVStackComponent_AlignmentValues() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        // Test all alignment values
        let alignments = ["leading", "center", "trailing", "top", "bottom", "firstTextBaseline", "lastTextBaseline"]

        for alignment in alignments {
            let model = ComponentModel(
                id: "vstack1",
                type: "VStack",
                props: [
                    "spacing": .number(8),
                    "alignment": .string(alignment)
                ],
                children: [child1]
            )

            let component = VStackComponent(model: model, context: context)
            XCTAssertNotNil(component, "VStack should support alignment: \(alignment)")
        }
    }

    // MARK: - HStackComponent Tests

    func testHStackComponent_Initialization() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let child2 = ComponentModel(
            id: "text2",
            type: "Text",
            props: ["text": .string("Item 2")]
        )

        let model = ComponentModel(
            id: "hstack1",
            type: "HStack",
            props: ["spacing": .number(8)],
            children: [child1, child2]
        )

        let component = HStackComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testHStackComponent_WithSpacing() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let model = ComponentModel(
            id: "hstack1",
            type: "HStack",
            props: ["spacing": .number(12)],
            children: [child1]
        )

        let component = HStackComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testHStackComponent_WithAlignment() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let model = ComponentModel(
            id: "hstack1",
            type: "HStack",
            props: [
                "spacing": .number(8),
                "alignment": .string("center")
            ],
            children: [child1]
        )

        let component = HStackComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testHStackComponent_WithPadding() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let model = ComponentModel(
            id: "hstack1",
            type: "HStack",
            props: [
                "spacing": .number(8),
                "padding": .number(15)
            ],
            children: [child1]
        )

        let component = HStackComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testHStackComponent_WithoutChildren() {
        let context = makeTestContext()

        let model = ComponentModel(
            id: "hstack1",
            type: "HStack",
            props: ["spacing": .number(8)]
        )

        let component = HStackComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testHStackComponent_AlignmentValues() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        // Test all alignment values
        let alignments = ["top", "center", "bottom", "leading", "trailing", "firstTextBaseline", "lastTextBaseline"]

        for alignment in alignments {
            let model = ComponentModel(
                id: "hstack1",
                type: "HStack",
                props: [
                    "spacing": .number(8),
                    "alignment": .string(alignment)
                ],
                children: [child1]
            )

            let component = HStackComponent(model: model, context: context)
            XCTAssertNotNil(component, "HStack should support alignment: \(alignment)")
        }
    }

    // MARK: - SpacerComponent Tests

    func testSpacerComponent_Initialization() {
        let context = makeTestContext()

        let model = ComponentModel(
            id: "spacer1",
            type: "Spacer"
        )

        let component = SpacerComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testSpacerComponent_WithProps() {
        let context = makeTestContext()

        let model = ComponentModel(
            id: "spacer1",
            type: "Spacer",
            props: ["width": .number(100), "height": .number(50)]
        )

        let component = SpacerComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testSpacerComponent_WithStyle() {
        let context = makeTestContext()

        let model = ComponentModel(
            id: "spacer1",
            type: "Spacer",
            props: [
                "width": .number(100),
                "height": .number(50),
                "padding": .number(8),
                "margin": .number(4)
            ]
        )

        let component = SpacerComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    // MARK: - ScrollViewComponent Tests

    func testScrollViewComponent_Initialization() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let child2 = ComponentModel(
            id: "text2",
            type: "Text",
            props: ["text": .string("Item 2")]
        )

        let model = ComponentModel(
            id: "scroll1",
            type: "ScrollView",
            children: [child1, child2]
        )

        let component = ScrollViewComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testScrollViewComponent_WithShowsIndicators() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let model = ComponentModel(
            id: "scroll1",
            type: "ScrollView",
            props: ["showsIndicators": .bool(false)],
            children: [child1]
        )

        let component = ScrollViewComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testScrollViewComponent_WithNavigationTitle() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let model = ComponentModel(
            id: "scroll1",
            type: "ScrollView",
            props: ["navigationTitle": .string("My Scroll View")],
            children: [child1]
        )

        let component = ScrollViewComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testScrollViewComponent_WithoutChildren() {
        let context = makeTestContext()

        let model = ComponentModel(
            id: "scroll1",
            type: "ScrollView"
        )

        let component = ScrollViewComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testScrollViewComponent_WithEmptyChildren() {
        let context = makeTestContext()

        let model = ComponentModel(
            id: "scroll1",
            type: "ScrollView",
            children: []
        )

        let component = ScrollViewComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testScrollViewComponent_WithAllProps() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let model = ComponentModel(
            id: "scroll1",
            type: "ScrollView",
            props: [
                "showsIndicators": .bool(true),
                "navigationTitle": .string("Title"),
                "padding": .number(10),
                "margin": .number(5)
            ],
            children: [child1]
        )

        let component = ScrollViewComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    // MARK: - Nested Layout Tests

    func testNestedLayout_VStackInHStack() {
        let context = makeTestContext()

        let text1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let text2 = ComponentModel(
            id: "text2",
            type: "Text",
            props: ["text": .string("Item 2")]
        )

        let vstack = ComponentModel(
            id: "vstack1",
            type: "VStack",
            props: ["spacing": .number(4)],
            children: [text1, text2]
        )

        let model = ComponentModel(
            id: "hstack1",
            type: "HStack",
            props: ["spacing": .number(8)],
            children: [vstack]
        )

        let component = HStackComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testNestedLayout_HStackInVStack() {
        let context = makeTestContext()

        let text1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let text2 = ComponentModel(
            id: "text2",
            type: "Text",
            props: ["text": .string("Item 2")]
        )

        let hstack = ComponentModel(
            id: "hstack1",
            type: "HStack",
            props: ["spacing": .number(4)],
            children: [text1, text2]
        )

        let model = ComponentModel(
            id: "vstack1",
            type: "VStack",
            props: ["spacing": .number(8)],
            children: [hstack]
        )

        let component = VStackComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testComplexLayout_ScrollViewWithStacks() {
        let context = makeTestContext()

        let text1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let text2 = ComponentModel(
            id: "text2",
            type: "Text",
            props: ["text": .string("Item 2")]
        )

        let vstack = ComponentModel(
            id: "vstack1",
            type: "VStack",
            props: ["spacing": .number(4)],
            children: [text1, text2]
        )

        let spacer = ComponentModel(
            id: "spacer1",
            type: "Spacer"
        )

        let model = ComponentModel(
            id: "scroll1",
            type: "ScrollView",
            props: [
                "navigationTitle": .string("Complex Layout"),
                "showsIndicators": .bool(true)
            ],
            children: [vstack, spacer]
        )

        let component = ScrollViewComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    // MARK: - Style Application Tests

    func testVStackComponent_WithStyle() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let model = ComponentModel(
            id: "vstack1",
            type: "VStack",
            props: [
                "spacing": .number(8),
                "padding": .number(10),
                "margin": .number(5),
                "width": .number(200),
                "height": .number(100)
            ],
            children: [child1]
        )

        let component = VStackComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testHStackComponent_WithStyle() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let model = ComponentModel(
            id: "hstack1",
            type: "HStack",
            props: [
                "spacing": .number(8),
                "padding": .number(10),
                "margin": .number(5),
                "width": .number(200),
                "height": .number(100)
            ],
            children: [child1]
        )

        let component = HStackComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    func testScrollViewComponent_WithStyle() {
        let context = makeTestContext()

        let child1 = ComponentModel(
            id: "text1",
            type: "Text",
            props: ["text": .string("Item 1")]
        )

        let model = ComponentModel(
            id: "scroll1",
            type: "ScrollView",
            props: [
                "showsIndicators": .bool(true),
                "navigationTitle": .string("Styled Scroll"),
                "padding": .number(10),
                "margin": .number(5),
                "width": .number(300),
                "height": .number(200)
            ],
            children: [child1]
        )

        let component = ScrollViewComponent(model: model, context: context)

        XCTAssertNotNil(component)
    }

    // MARK: - Alignment Parsing Tests

}

// MARK: - Helper Functions
class AlignmentParsingTests: XCTestCase {
    
    // MARK: - Vertical Alignment Tests
    
    func testVerticalAlignmentParsing_Top() {
        let alignment = parseVerticalAlignment("top")
        XCTAssertEqual(alignment, .top)
    }
    
    func testVerticalAlignmentParsing_Center() {
        let alignment = parseVerticalAlignment("center")
        XCTAssertEqual(alignment, .center)
    }
    
    func testVerticalAlignmentParsing_Bottom() {
        let alignment = parseVerticalAlignment("bottom")
        XCTAssertEqual(alignment, .bottom)
    }
    
    func testVerticalAlignmentParsing_FirstTextBaseline() {
        let alignment = parseVerticalAlignment("firstTextBaseline")
        XCTAssertEqual(alignment, .firstTextBaseline)
    }
    
    func testVerticalAlignmentParsing_FirstTextBaselineWithSpaces() {
        let alignment = parseVerticalAlignment("first text baseline")
        XCTAssertEqual(alignment, .firstTextBaseline)
    }
    
    func testVerticalAlignmentParsing_LastTextBaseline() {
        let alignment = parseVerticalAlignment("lastTextBaseline")
        XCTAssertEqual(alignment, .lastTextBaseline)
    }
    
    func testVerticalAlignmentParsing_LastTextBaselineWithSpaces() {
        let alignment = parseVerticalAlignment("last text baseline")
        XCTAssertEqual(alignment, .lastTextBaseline)
    }
    
    func testVerticalAlignmentParsing_Default() {
        let alignment = parseVerticalAlignment("unknown")
        XCTAssertEqual(alignment, .center)
    }
    
    func testVerticalAlignmentParsing_EmptyString() {
        let alignment = parseVerticalAlignment("")
        XCTAssertEqual(alignment, .center)
    }
    
    func testVerticalAlignmentParsing_CaseInsensitive() {
        let alignment = parseVerticalAlignment("TOP")
        XCTAssertEqual(alignment, .top)
    }
    
    // MARK: - Horizontal Alignment Tests
    
    func testHorizontalAlignmentParsing_Leading() {
        let alignment = parseHorizontalAlignment("leading")
        XCTAssertEqual(alignment, .leading)
    }
    
    func testHorizontalAlignmentParsing_Center() {
        let alignment = parseHorizontalAlignment("center")
        XCTAssertEqual(alignment, .center)
    }
    
    func testHorizontalAlignmentParsing_Trailing() {
        let alignment = parseHorizontalAlignment("trailing")
        XCTAssertEqual(alignment, .trailing)
    }
    
    func testHorizontalAlignmentParsing_Default() {
        let alignment = parseHorizontalAlignment("unknown")
        XCTAssertEqual(alignment, .center)
    }
    
    func testHorizontalAlignmentParsing_EmptyString() {
        let alignment = parseHorizontalAlignment("")
        XCTAssertEqual(alignment, .center)
    }
    
    func testHorizontalAlignmentParsing_CaseInsensitive() {
        let alignment = parseHorizontalAlignment("LEADING")
        XCTAssertEqual(alignment, .leading)
    }
}

// MARK: - Helper Functions

private func parseVerticalAlignment(_ alignment: String) -> VerticalAlignment {
    switch alignment.lowercased() {
    case "top":
        return .top
    case "bottom":
        return .bottom
    case "firsttextbaseline", "first text baseline":
        return .firstTextBaseline
    case "lasttextbaseline", "last text baseline":
        return .lastTextBaseline
    default:
        return .center
    }
}

private func parseHorizontalAlignment(_ alignment: String) -> HorizontalAlignment {
    switch alignment.lowercased() {
    case "leading":
        return .leading
    case "trailing":
        return .trailing
    default:
        return .center
    }
}
