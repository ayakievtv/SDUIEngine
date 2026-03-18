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
        let navigationTitle = model.resolvedProps["navigationTitle"]?.stringValue
        let showsIndicators = model.resolvedProps["showsIndicators"]?.boolValue ?? true

        let scrollContent = ScrollView(showsIndicators: showsIndicators) {
            VStack(spacing: 0) {
                ForEach(model.resolvedChildren) { child in
                    ComponentRenderer(model: child, context: context, registry: context.componentRegistry)
                }
            }
        }
        .applyStyle(style, includeFontSize: false)

        if let navigationTitle, !navigationTitle.isEmpty {
            scrollContent
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.large)
        } else {
            scrollContent
        }
    }
}
