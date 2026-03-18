import SwiftUI

// MARK: - Button Component

struct ButtonComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext

    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
    }

    var body: some View {
        let style = Style(props: model.resolvedProps)
        let title = model.resolvedProps.string("title") ?? model.resolvedProps.string("text") ?? "Button"
        let borderColor = model.resolvedProps.string("borderColor").flatMap(Color.sduiColor)
        let borderWidth = CGFloat(model.resolvedProps.double("borderWidth") ?? 1)
        let cornerRadius = CGFloat(model.resolvedProps.double("cornerRadius") ?? 10)
        let backgroundColor = model.resolvedProps.string("backgroundColor").flatMap(Color.sduiColor)

        return Button {
            context.trigger(tapEvent())
        } label: {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(backgroundColor ?? .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor ?? .clear, lineWidth: borderWidth)
                )
        }
        .applyStyle(style)
    }

    /// Create tap event for button interaction
    private func tapEvent() -> EventModel {
        model.event(for: .onTap) ?? EventModel(type: .onTap, target: model.id)
    }
}
