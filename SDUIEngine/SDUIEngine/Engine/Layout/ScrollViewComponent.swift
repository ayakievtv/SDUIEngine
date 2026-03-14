import SwiftUI

struct ScrollViewComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext

    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
    }

    var body: some View {
        let style = Style(props: model.resolvedProps)

        ScrollView {
            VStack {
                ForEach(model.resolvedChildren) { child in
                    ComponentRenderer(model: child, context: context, registry: context.componentRegistry)
                }
            }
        }
        .applyStyle(style, includeFontSize: false)
    }
}
