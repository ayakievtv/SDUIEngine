import SwiftUI

struct TextFieldComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext

    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
    }

    var body: some View {
        let style = Style(props: model.props)
        let placeholder = model.props.string("placeholder") ?? ""
        let stateKey = model.props.string("stateKey") ?? model.props.string("bind") ?? model.id
        let textBinding = context.bindingString(for: stateKey)

        return TextField(placeholder, text: textBinding)
            .onChange(of: textBinding.wrappedValue) { value in
                guard let event = model.event(for: .onChange) else { return }
                var params = event.params
                params["value"] = .string(value)
                context.trigger(EventModel(type: .onChange, target: event.target, params: params))
            }
            .onSubmit {
                if let event = model.event(for: .onSubmit) {
                    context.trigger(event)
                }
            }
            .applyStyle(style)
    }
}
