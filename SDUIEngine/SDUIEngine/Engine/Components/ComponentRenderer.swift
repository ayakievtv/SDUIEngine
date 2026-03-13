import SwiftUI

struct ComponentRenderer: View {
    let model: ComponentModel
    let context: UIContext
    let registry: ComponentRegistry

    init(model: ComponentModel, context: UIContext, registry: ComponentRegistry) {
        self.model = model
        self.context = context
        self.registry = registry
    }

    var body: some View {
        renderedView
            .onAppear {
                if let event = model.event(for: .onAppear) {
                    context.trigger(event)
                }
            }
            .onDisappear {
                if let event = model.event(for: .onDisappear) {
                    context.trigger(event)
                }
            }
    }

    private var renderedView: AnyView {
        if let factory = registry.resolve(type: model.type) {
            return factory(model, context)
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("Unknown component: \(model.type)")
                    .font(.headline)

                ForEach(model.children) { child in
                    ComponentRenderer(model: child, context: context, registry: registry)
                }
            }
            .padding(12)
        )
    }
}
