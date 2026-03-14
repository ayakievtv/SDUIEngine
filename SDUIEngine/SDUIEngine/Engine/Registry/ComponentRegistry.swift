import SwiftUI

typealias ComponentFactory = (ComponentModel, UIContext) -> AnyView

// Maps server component "type" values to concrete SwiftUI factories.
final class ComponentRegistry {
    private var factories: [String: ComponentFactory] = [:]

    func register(type: String, factory: @escaping ComponentFactory) {
        factories[type] = factory
    }

    // Convenience API to register any UIComponent type directly.
    func register<Component: UIComponent>(type: String, component: Component.Type) {
        register(type: type) { model, context in
            AnyView(component.init(model: model, context: context))
        }
    }

    func resolve(type: String) -> ComponentFactory? {
        factories[type]
    }
}

// Central runtime storage for active components that can receive actions by ID.
final class ComponentStore {
    static let shared = ComponentStore()

    private var components: [String: AnyComponent] = [:]

    func register(componentID: String, component: AnyComponent) {
        components[componentID] = component
    }

    func get(componentID: String) -> AnyComponent? {
        components[componentID]
    }

    func unregister(componentID: String) {
        components.removeValue(forKey: componentID)
    }
}
