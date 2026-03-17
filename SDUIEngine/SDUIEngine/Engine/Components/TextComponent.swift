import SwiftUI

struct TextComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext
    @StateObject private var controller: TextActionController
    @State private var stateRefreshToken = 0

    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
        _controller = StateObject(
            wrappedValue: TextActionController(
                componentID: model.id,
                initialText: model.resolvedProps.string("text"),
                initialColor: model.resolvedProps.string("color")
            )
        )
    }

    var body: some View {
        var props = model.resolvedProps
        if let textOverride = controller.textOverride {
            props["text"] = .string(textOverride)
        }
        if let colorOverride = controller.colorOverride {
            props["color"] = .string(colorOverride)
        }

        let style = Style(props: props)
        let rawText = props.string("text") ?? ""
        let value = interpolateStateTokens(in: rawText)
        let isInputLike = props.bool("inputLike") ?? false
        let borderColor = Color.sduiColor(props.string("borderColor") ?? "#D1D5DB") ?? Color.gray.opacity(0.5)
        let backgroundColor = Color.sduiColor(props.string("backgroundColor") ?? "#F9FAFB") ?? Color(.systemBackground)
        let cornerRadius = CGFloat(props.double("cornerRadius") ?? 8)
        let verticalPadding = CGFloat(props.double("inputPaddingVertical") ?? 10)
        let horizontalPadding = CGFloat(props.double("inputPaddingHorizontal") ?? 12)

        let baseText = Text(value).applyStyle(style)
        let renderedText: AnyView
        if isInputLike {
            renderedText = AnyView(
                baseText
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, verticalPadding)
                    .padding(.horizontal, horizontalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(backgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
        } else {
            renderedText = AnyView(baseText.foregroundColor(.black))
        }

        return renderedText
            .onAppear {
                ComponentStore.shared.register(
                    componentID: model.id,
                    component: AnyComponent(actionHandler: { [controller] action, params in
                        controller.handle(action: action, params: params)
                    })
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .sduiStateDidChange)) { _ in
                stateRefreshToken += 1
            }
            .onDisappear {
                ComponentStore.shared.unregister(componentID: model.id)
            }
    }

    private func interpolateStateTokens(in text: String) -> String {
        var output = text
        while let open = output.range(of: "{{"),
              let close = output.range(of: "}}", range: open.upperBound..<output.endIndex) {
            let key = output[open.upperBound..<close.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let replacement: String
            if let value = context.stateValue(for: key) {
                if let string = value.stringValue {
                    replacement = string
                } else if let number = value.numberValue {
                    replacement = String(number)
                } else if let bool = value.boolValue {
                    replacement = bool ? "true" : "false"
                } else {
                    replacement = ""
                }
            } else {
                replacement = ""
            }
            output.replaceSubrange(open.lowerBound..<close.upperBound, with: replacement)
        }
        return output
    }
}

@MainActor
final class TextActionController: ObservableObject, EventActionHandler {
    let componentID: String
    @Published var textOverride: String?
    @Published var colorOverride: String?

    init(componentID: String, initialText: String?, initialColor: String?) {
        self.componentID = componentID
        textOverride = initialText
        colorOverride = initialColor
    }

    func handle(action: String, params: [String: String]?) {
        switch action.uppercased() {
        case "SET_TEXT":
            if let newText = params?["value"] ?? params?["text"] {
                textOverride = newText
            }
        case "SET_COLOR":
            if let newColor = params?["value"] ?? params?["color"] {
                colorOverride = newColor
            }
        default:
            break
        }
    }
}
