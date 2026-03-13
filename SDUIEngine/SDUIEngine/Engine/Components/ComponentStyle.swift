import SwiftUI
import UIKit

struct Style {
    let fontSize: CGFloat?
    let fontWeight: Font.Weight?
    let padding: CGFloat?
    let margin: CGFloat?
    let color: Color?
    let width: CGFloat?
    let height: CGFloat?

    init(props: [String: JSONValue]) {
        fontSize = props.double("fontSize").map { CGFloat($0) }
        if let weightName = props.string("fontWeight") {
            fontWeight = Font.Weight.sduiWeight(weightName)
        } else if let numericWeight = props.double("fontWeight") {
            fontWeight = Font.Weight.sduiWeight(numericWeight)
        } else {
            fontWeight = nil
        }
        padding = props.double("padding").map { CGFloat($0) }
        margin = props.double("margin").map { CGFloat($0) }
        color = props.string("color").flatMap(Color.sduiColor)
        width = props.double("width").map { CGFloat($0) }
        height = props.double("height").map { CGFloat($0) }
    }
}

extension JSONValue {
    var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    var numberValue: Double? {
        if case let .number(value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case let .object(value) = self { return value }
        return nil
    }
}

extension Dictionary where Key == String, Value == JSONValue {
    func string(_ key: String) -> String? {
        self[key]?.stringValue
    }

    func double(_ key: String) -> Double? {
        self[key]?.numberValue
    }

    func bool(_ key: String) -> Bool? {
        self[key]?.boolValue
    }
}

extension Color {
    static func sduiColor(_ raw: String) -> Color? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch value {
        case "black": return .black
        case "white": return .white
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "gray", "grey": return .gray
        case "orange": return .orange
        case "yellow": return .yellow
        case "pink": return .pink
        case "purple": return .purple
        default:
            break
        }

        let hex = value.hasPrefix("#") ? String(value.dropFirst()) : value
        guard hex.count == 6 || hex.count == 8, let number = UInt64(hex, radix: 16) else {
            return nil
        }

        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        let a: CGFloat

        if hex.count == 8 {
            a = CGFloat((number & 0xFF000000) >> 24) / 255.0
            r = CGFloat((number & 0x00FF0000) >> 16) / 255.0
            g = CGFloat((number & 0x0000FF00) >> 8) / 255.0
            b = CGFloat(number & 0x000000FF) / 255.0
        } else {
            a = 1.0
            r = CGFloat((number & 0xFF0000) >> 16) / 255.0
            g = CGFloat((number & 0x00FF00) >> 8) / 255.0
            b = CGFloat(number & 0x0000FF) / 255.0
        }

        return Color(uiColor: UIColor(red: r, green: g, blue: b, alpha: a))
    }
}

extension Font.Weight {
    static func sduiWeight(_ raw: String) -> Font.Weight? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular", "normal": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return nil
        }
    }

    static func sduiWeight(_ value: Double) -> Font.Weight {
        switch value {
        case ..<200: return .ultraLight
        case ..<300: return .thin
        case ..<400: return .light
        case ..<500: return .regular
        case ..<600: return .medium
        case ..<700: return .semibold
        case ..<800: return .bold
        case ..<900: return .heavy
        default: return .black
        }
    }
}

extension View {
    func applyStyle(_ style: Style, includeFontSize: Bool = true) -> AnyView {
        var result = AnyView(self)

        if includeFontSize {
            if let fontSize = style.fontSize, let fontWeight = style.fontWeight {
                result = AnyView(result.font(.system(size: fontSize, weight: fontWeight)))
            } else if let fontSize = style.fontSize {
                result = AnyView(result.font(.system(size: fontSize)))
            } else if let fontWeight = style.fontWeight {
                result = AnyView(result.font(.system(size: 17, weight: fontWeight)))
            }
        }

        if let color = style.color {
            result = AnyView(result.foregroundColor(color))
        }

        result = AnyView(result.frame(width: style.width, height: style.height))

        if let padding = style.padding {
            result = AnyView(result.padding(padding))
        }

        if let margin = style.margin {
            result = AnyView(result.padding(margin))
        }

        return result
    }
}
