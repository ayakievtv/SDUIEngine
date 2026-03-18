import SwiftUI

// MARK: - TextField Component

struct TextFieldComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext
    private let stateKey: String
    @State private var localText: String

    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
        let key = model.resolvedProps.string("stateKey") ?? model.resolvedProps.string("bind") ?? model.id
        stateKey = key
        _localText = State(initialValue: context.stateValue(for: key)?.stringValue ?? "")
    }

    var body: some View {
        let style = Style(props: model.resolvedProps)
        let placeholder = model.resolvedProps.string("placeholder") ?? ""
        let borderWidth = model.resolvedProps["borderWidth"]?.numberValue ?? 0
        let borderColor = model.resolvedProps.string("borderColor") ?? Color.gray.description
        let cornerRadius = model.resolvedProps["cornerRadius"]?.numberValue ?? 0
        let maxLength = model.resolvedProps["maxLength"]?.numberValue ?? 100
        let textAlignment = model.resolvedProps.string("multilineTextAlignment") ?? "leading"
        let textBinding = Binding<String>(
            get: { localText },
            set: { newValue in
                // Limit text to maxLength characters
                let truncatedValue = String(newValue.prefix(Int(maxLength)))
                localText = truncatedValue
                context.setState(key: stateKey, value: .string(truncatedValue))
            }
        )

        return TextField(placeholder, text: textBinding)
            .multilineTextAlignment(parseTextAlignment(textAlignment))
            .onChange(of: textBinding.wrappedValue) { value in
                guard let event = model.event(for: .onChange) else { return }
                var params = event.params
                // Keep JSON-defined value if provided; otherwise pass current field value
                if params["value"] == nil {
                    params["value"] = .string(value)
                }
                context.trigger(EventModel(type: .onChange, targets: event.targets, params: params))
            }
            .onSubmit {
                if let event = model.event(for: .onSubmit) {
                    context.trigger(event)
                }
            }
            .onAppear {
                ComponentStore.shared.register(
                    componentID: model.id,
                    component: AnyComponent(actionHandler: { [context] action, params in
                        guard action.uppercased() == "SET_TEXT" else { return }
                        if let value = params?["value"] ?? params?["text"] {
                            context.setState(key: stateKey, value: .string(value))
                        }
                    })
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .sduiStateDidChange)) { note in
                guard
                    let changedKey = note.userInfo?["key"] as? String,
                    changedKey == stateKey,
                    let changedValue = note.userInfo?["value"] as? JSONValue
                else {
                    return
                }
                if let value = changedValue.stringValue {
                    localText = value
                } else if let number = changedValue.numberValue {
                    localText = String(number)
                } else if let bool = changedValue.boolValue {
                    localText = bool ? "true" : "false"
                } else {
                    localText = ""
                }
            }
            .onDisappear {
                ComponentStore.shared.unregister(componentID: model.id)
            }
            .applyStyle(style)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color(hex: borderColor), lineWidth: borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Color Extension

extension Color {
    /// Initialize color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Text Alignment Helper

/// Parse text alignment from string
private func parseTextAlignment(_ alignment: String) -> TextAlignment {
    switch alignment.lowercased() {
    case "center":
        return .center
    case "trailing", "right":
        return .trailing
    default:
        return .leading
    }
}
