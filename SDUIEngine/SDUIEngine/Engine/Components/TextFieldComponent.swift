import SwiftUI

struct TextFieldComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext
    private let stateKey: String
    @StateObject private var controller: TextFieldActionController

    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
        let key = model.resolvedProps.string("stateKey") ?? model.resolvedProps.string("bind") ?? model.id
        stateKey = key
        let initialText = context.stateValue(for: key)?.stringValue ?? ""
        _controller = StateObject(wrappedValue: TextFieldActionController(componentID: model.id, initialText: initialText))
    }

    var body: some View {
        let style = Style(props: model.resolvedProps)
        let placeholder = model.resolvedProps.string("placeholder") ?? ""
        let textBinding = Binding<String>(
            get: { controller.text },
            set: { newValue in
                controller.text = newValue
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
                    component: AnyComponent(actionHandler: { [controller] action, params in
                        controller.handle(action: action, params: params)
                    })
                )
            }
            .onDisappear {
                ComponentStore.shared.unregister(componentID: model.id)
            }
            .applyStyle(style)
    }
}

@MainActor
final class TextFieldActionController: ObservableObject, EventActionHandler {
    let componentID: String
    @Published var text: String

    init(componentID: String, initialText: String) {
        self.componentID = componentID
        text = initialText
    }

    func handle(action: String, params: [String: String]?) {
        switch action.uppercased() {
        case "SET_TEXT":
            if let value = params?["value"] ?? params?["text"] {
                text = value
            }
        default:
            break
        }
    }
}
