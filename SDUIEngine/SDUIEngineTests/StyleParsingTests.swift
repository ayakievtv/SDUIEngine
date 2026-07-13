import XCTest
import SwiftUI
@testable import SDUIEngine

final class StyleParsingTests: XCTestCase {

    // MARK: - Вспомогательная функция извлечения RGBA из Color

    private func rgba(of color: Color) throws -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let ok = uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertTrue(ok, "Не удалось извлечь RGBA-компоненты из Color")
        return (r, g, b, a)
    }

    // MARK: - Dictionary helpers

    func testDictionaryHelpers_extractCorrectTypes() {
        let dict: [String: JSONValue] = [
            "s": .string("hi"),
            "n": .number(42),
            "b": .bool(true),
        ]
        XCTAssertEqual(dict.string("s"), "hi")
        XCTAssertEqual(dict.double("n"), 42)
        XCTAssertEqual(dict.bool("b"), true)
    }

    func testDictionaryHelpers_missingOrWrongType_returnNil() {
        let dict: [String: JSONValue] = ["s": .string("hi")]
        XCTAssertNil(dict.string("missing"))
        XCTAssertNil(dict.double("s")) // строка не является числом
        XCTAssertNil(dict.bool("s"))   // строка не является bool
    }

    // MARK: - Color.sduiColor — именованные цвета

    func testSduiColor_namedColors() {
        XCTAssertEqual(Color.sduiColor("black"), .black)
        XCTAssertEqual(Color.sduiColor("white"), .white)
        XCTAssertEqual(Color.sduiColor("red"), .red)
        XCTAssertEqual(Color.sduiColor("grey"), .gray) // алиас "grey" -> .gray
        XCTAssertEqual(Color.sduiColor("primary"), Color(.label))
    }

    func testSduiColor_namedColors_areCaseInsensitiveAndTrimmed() {
        XCTAssertEqual(Color.sduiColor("  RED  "), .red)
        XCTAssertEqual(Color.sduiColor("Blue"), .blue)
    }

    func testSduiColor_unknownName_returnsNil() {
        XCTAssertNil(Color.sduiColor("not-a-color"))
    }

    // MARK: - Color.sduiColor — hex

    func testSduiColor_hex6_withoutHash() throws {
        let comps = try rgba(of: XCTUnwrap(Color.sduiColor("FF0000")))
        XCTAssertEqual(comps.r, 1.0, accuracy: 0.01)
        XCTAssertEqual(comps.g, 0.0, accuracy: 0.01)
        XCTAssertEqual(comps.b, 0.0, accuracy: 0.01)
        XCTAssertEqual(comps.a, 1.0, accuracy: 0.01)
    }

    func testSduiColor_hex6_withHash() throws {
        let comps = try rgba(of: XCTUnwrap(Color.sduiColor("#00FF00")))
        XCTAssertEqual(comps.r, 0.0, accuracy: 0.01)
        XCTAssertEqual(comps.g, 1.0, accuracy: 0.01)
        XCTAssertEqual(comps.b, 0.0, accuracy: 0.01)
        XCTAssertEqual(comps.a, 1.0, accuracy: 0.01)
    }

    func testSduiColor_hex8_withAlpha() throws {
        // AARRGGBB: 80 (alpha ~0.5) 0000FF (синий)
        let comps = try rgba(of: XCTUnwrap(Color.sduiColor("#800000FF")))
        XCTAssertEqual(comps.r, 0.0, accuracy: 0.01)
        XCTAssertEqual(comps.g, 0.0, accuracy: 0.01)
        XCTAssertEqual(comps.b, 1.0, accuracy: 0.01)
        XCTAssertEqual(comps.a, 128.0 / 255.0, accuracy: 0.01)
    }

    func testSduiColor_invalidHexLength_returnsNil() {
        XCTAssertNil(Color.sduiColor("#ABCDE"))   // 5 символов — не 6 и не 8
        XCTAssertNil(Color.sduiColor("#ABCDEFA")) // 7 символов
    }

    func testSduiColor_nonHexCharacters_returnsNil() {
        XCTAssertNil(Color.sduiColor("#GGGGGG"))
    }

    // MARK: - Font.Weight.sduiWeight(String)

    func testSduiWeight_allNamedWeights() {
        let mapping: [String: Font.Weight] = [
            "ultralight": .ultraLight,
            "thin": .thin,
            "light": .light,
            "regular": .regular,
            "normal": .regular,
            "medium": .medium,
            "semibold": .semibold,
            "bold": .bold,
            "heavy": .heavy,
            "black": .black,
        ]
        for (raw, expected) in mapping {
            XCTAssertEqual(Font.Weight.sduiWeight(raw), expected, "raw=\(raw)")
        }
    }

    func testSduiWeight_string_isTrimmedAndCaseInsensitive() {
        XCTAssertEqual(Font.Weight.sduiWeight("  BOLD  "), .bold)
    }

    func testSduiWeight_string_unknown_returnsNil() {
        XCTAssertNil(Font.Weight.sduiWeight("not-a-weight"))
    }

    // MARK: - Font.Weight.sduiWeight(Double) — пороги диапазонов

    func testSduiWeight_numeric_middleOfEachRange() {
        XCTAssertEqual(Font.Weight.sduiWeight(100), .ultraLight)
        XCTAssertEqual(Font.Weight.sduiWeight(250), .thin)
        XCTAssertEqual(Font.Weight.sduiWeight(350), .light)
        XCTAssertEqual(Font.Weight.sduiWeight(450), .regular)
        XCTAssertEqual(Font.Weight.sduiWeight(550), .medium)
        XCTAssertEqual(Font.Weight.sduiWeight(650), .semibold)
        XCTAssertEqual(Font.Weight.sduiWeight(750), .bold)
        XCTAssertEqual(Font.Weight.sduiWeight(850), .heavy)
        XCTAssertEqual(Font.Weight.sduiWeight(950), .black)
    }

    func testSduiWeight_numeric_boundaryValues() {
        // Диапазоны полуоткрытые (..<200, ..<300, ...), поэтому ровно 200
        // попадает уже в следующий диапазон (.thin), а не в .ultraLight
        XCTAssertEqual(Font.Weight.sduiWeight(199.999), .ultraLight)
        XCTAssertEqual(Font.Weight.sduiWeight(200), .thin)
        XCTAssertEqual(Font.Weight.sduiWeight(299.999), .thin)
        XCTAssertEqual(Font.Weight.sduiWeight(300), .light)
        XCTAssertEqual(Font.Weight.sduiWeight(900), .black)
        XCTAssertEqual(Font.Weight.sduiWeight(10000), .black) // всё, что >= 900 — .black
    }

    // MARK: - Style(props:)

    func testStyle_parsesAllNumericAndColorProps() {
        let props: [String: JSONValue] = [
            "fontSize": .number(18),
            "padding": .number(8),
            "margin": .number(4),
            "width": .number(100),
            "height": .number(50),
            "color": .string("red"),
        ]
        let style = Style(props: props)

        XCTAssertEqual(style.fontSize, 18)
        XCTAssertEqual(style.padding, 8)
        XCTAssertEqual(style.margin, 4)
        XCTAssertEqual(style.width, 100)
        XCTAssertEqual(style.height, 50)
        XCTAssertEqual(style.color, .red)
        XCTAssertNil(style.fontWeight)
    }

    func testStyle_missingProps_resultInNilFields() {
        let style = Style(props: [:])

        XCTAssertNil(style.fontSize)
        XCTAssertNil(style.fontWeight)
        XCTAssertNil(style.padding)
        XCTAssertNil(style.margin)
        XCTAssertNil(style.color)
        XCTAssertNil(style.width)
        XCTAssertNil(style.height)
    }

    func testStyle_fontWeight_stringTakesPriorityOverNumber() {
        // Реализация сначала пробует props.string("fontWeight"), затем — double.
        // Если строка присутствует (даже если бы оба ключа существовали), число не используется.
        let style = Style(props: ["fontWeight": .string("bold")])
        XCTAssertEqual(style.fontWeight, .bold)
    }

    func testStyle_fontWeight_numericFallback_whenNoString() {
        let style = Style(props: ["fontWeight": .number(700)])
        XCTAssertEqual(style.fontWeight, .bold)
    }

    func testStyle_fontWeight_invalidStringName_doesNotFallBackToNil() {
        // Невалидное имя веса в виде строки -> nil, а не попытка интерпретировать как число
        let style = Style(props: ["fontWeight": .string("not-a-real-weight")])
        XCTAssertNil(style.fontWeight)
    }

    func testStyle_invalidColorName_resultsInNilColor() {
        let style = Style(props: ["color": .string("not-a-color")])
        XCTAssertNil(style.color)
    }
}
