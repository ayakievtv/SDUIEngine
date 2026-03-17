import SwiftUI

struct TabBarComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext
    
    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
    }
    
    var body: some View {
        TabBarView(model: model, context: context)
    }
}

struct TabBarView: View {
    let model: ComponentModel
    let context: UIContext
    @State private var selectedTab: Int = 0
    
    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
        self._selectedTab = State(initialValue: Int(model.props?.double("selectedIndex") ?? 0))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Array(model.children?.enumerated() ?? [].enumerated()), id: \.element.id) { index, child in
                renderChild(child, index: index)
                    .tabItem {
                        tabItemForChild(child, index: index)
                    }
                    .tag(index)
            }
        }
        .onAppear {
            // Регистрация компонента для событий
            ComponentStore.shared.register(
                componentID: model.id,
                component: AnyComponent(actionHandler: { action, params in
                    handle(action: action, params: params)
                })
            )
        }
    }
    
    @ViewBuilder
    private func renderChild(_ child: ComponentModel, index: Int) -> some View {
        ComponentRenderer(model: child, context: context, registry: context.componentRegistry)
    }
    
    @ViewBuilder
    private func tabItemForChild(_ child: ComponentModel, index: Int) -> some View {
        let props = child.props
        let title = props?.string("title") ?? "Tab \(index + 1)"
        let iconName = props?.string("iconName")
        let systemImage = props?.string("systemImage")
        
        if let systemImage = systemImage {
            Label(title, systemImage: systemImage)
        } else if let iconName = iconName {
            // Для кастомных иконок можно использовать Image
            Label(title, image: iconName)
        } else {
            Text(title)
        }
    }
    
    private func handle(action: String, params: [String: String]?) {
        // Обработка событий для TabBar
        if action == "selectTab", let index = params?["index"], let tabIndex = Int(index) {
            selectedTab = tabIndex
        }
    }
}
