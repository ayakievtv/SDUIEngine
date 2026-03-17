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
        
        ScrollView {
            VStack(spacing: 0) {
                // Если есть navigationTitle, добавляем заголовок
                if let title = navigationTitle, !title.isEmpty {
                    VStack(spacing: 0) {
                        HStack {
                            Text(title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color("#1F2937"))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color("#F8FAFC"))
                        .frame(height: 56)
                    }
                }
                
                VStack(spacing: 0) {
                    ForEach(model.resolvedChildren) { child in
                        ComponentRenderer(model: child, context: context, registry: context.componentRegistry)
                    }
                }
            }
        }
        .applyStyle(style, includeFontSize: false)
        .navigationTitle(navigationTitle ?? "")
        // Чтобы заголовок уменьшался при скролле (Collapse effect):
        .navigationBarTitleDisplayMode(.large)
    }
}
