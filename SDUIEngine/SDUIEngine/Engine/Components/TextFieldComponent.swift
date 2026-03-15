import SwiftUI

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
        let textBinding = Binding<String>(
            get: { localText },
            set: { newValue in
                localText = newValue
                context.setState(key: stateKey, value: .string(newValue))
            }
        )

        return TextField(placeholder, text: textBinding)
            .onChange(of: textBinding.wrappedValue) { value in
                guard let event = model.event(for: .onChange) else { return }
                var params = event.params
                // Keep JSON-defined value if provided; otherwise pass current field value.
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
    }
}
