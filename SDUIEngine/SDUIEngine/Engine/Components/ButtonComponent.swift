import SwiftUI

struct ButtonComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext

    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
    }

    var body: some View {
        let style = Style(props: model.props)
        let title = model.props.string("title") ?? model.props.string("text") ?? "Button"

        return Button {
            context.trigger(tapEvent())
        } label: {
            Text(title)
        }
        .applyStyle(style)
    }

    private func tapEvent() -> EventModel {
        model.event(for: .onTap) ?? EventModel(type: .onTap, target: model.id)
    }
}
