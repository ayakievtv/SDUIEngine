import SwiftUI

// MARK: - Component Renderer

/// Generic renderer that turns any ComponentModel into a concrete SwiftUI view
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
            .applyPerformanceProps(model.resolvedProps)
            // Lifecycle events are dispatched back to the SDUI runtime
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

    /// Render the component using registered factory or fallback view
    private var renderedView: AnyView {
        if let factory = registry.resolve(type: model.type) {
            return factory(model, context)
        }

        // Safe fallback for unknown types so UI does not fully crash
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("Unknown component: \(model.type)")
                    .font(.headline)

                ForEach(model.resolvedChildren) { child in
                    ComponentRenderer(model: child, context: context, registry: registry)
                }
            }
            .padding(12)
        )
    }
}
