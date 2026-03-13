import SwiftUI

typealias ComponentFactory = (ComponentModel, UIContext) -> AnyView

final class ComponentRegistry {
    private var factories: [String: ComponentFactory] = [:]

    func register(type: String, factory: @escaping ComponentFactory) {
        factories[type] = factory
    }

    func register<Component: UIComponent>(type: String, component: Component.Type) {
        register(type: type) { model, context in
            AnyView(component.init(model: model, context: context))
        }
    }

    func resolve(type: String) -> ComponentFactory? {
        factories[type]
    }
}
