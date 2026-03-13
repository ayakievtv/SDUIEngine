import SwiftUI

struct ScrollViewComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext

    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
    }

    var body: some View {
        let style = Style(props: model.props)

        ScrollView {
            VStack {
                ForEach(model.children) { child in
                    ComponentRenderer(model: child, context: context, registry: context.componentRegistry)
                }
            }
        }
        .applyStyle(style, includeFontSize: false)
    }
}
