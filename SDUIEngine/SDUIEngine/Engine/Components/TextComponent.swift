import SwiftUI

struct TextComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext
    @StateObject private var controller: TextActionController

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
        let value = props.string("text") ?? ""
        let isInputLike = props.bool("inputLike") ?? false
        let borderColor = Color.sduiColor(props.string("borderColor") ?? "#D1D5DB") ?? Color.gray.opacity(0.5)
        let backgroundColor = Color.sduiColor(props.string("backgroundColor") ?? "#FFFFFF") ?? Color.white
        let cornerRadius = CGFloat(props.double("cornerRadius") ?? 8)
        let verticalPadding = CGFloat(props.double("inputPaddingVertical") ?? 10)
        let horizontalPadding = CGFloat(props.double("inputPaddingHorizontal") ?? 12)

        let baseText = Text(value).applyStyle(style)
        let renderedText: AnyView
        if isInputLike {
            renderedText = AnyView(
                baseText
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
            renderedText = baseText
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
            .onDisappear {
                ComponentStore.shared.unregister(componentID: model.id)
            }
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
