import SwiftUI

struct SpacerComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext

    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
    }

    var body: some View {
        let style = Style(props: model.resolvedProps)
        let background = style.color ?? .clear

        if style.width != nil || style.height != nil {
            return AnyView(
                background
                    .frame(width: style.width, height: style.height)
                    .padding(style.padding ?? 0)
                    .padding(style.margin ?? 0)
            )
        }

        return AnyView(
            Spacer()
                .background(background)
                .padding(style.padding ?? 0)
                .padding(style.margin ?? 0)
        )
    }
}
