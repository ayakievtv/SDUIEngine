import SwiftUI

// Root container for backend-driven navigation and initial screen bootstrap.
struct ContentView: View {
    @StateObject private var router: NavigationRouter
    private let context: UIContext
    private let service: UIService

    @State private var rootComponent: ComponentModel?
    @State private var isLoading = true
    @State private var errorMessage: String?

    init() {
        // A single router instance is shared by the whole app tree.
        let router = NavigationRouter()
        _router = StateObject(wrappedValue: router)

        // UIContext is the runtime "engine" used by components.
        let context = UIContext(navigation: router)
        registerDefaultComponents(in: context.componentRegistry)
        self.context = context
        self.service = UIService()
    }

    var body: some View {
        // Centralized NavigationStack for all server routes.
        NavigationStack(path: $router.path) {
            Group {
                if isLoading {
                    ProgressView("Loading main screen...")
                } else if let rootComponent {
                    ComponentRenderer(model: rootComponent, context: context, registry: context.componentRegistry)
                } else {
                    Text(errorMessage ?? "Failed to load screen")
                        .padding(16)
                }
            }
            // A single destination resolver for every AppRoute.
            .navigationDestination(for: AppRoute.self) { route in
                ScreenView(name: route.screenName, service: service, context: context)
            }
        }
        .task {
            await loadMainScreen()
        }
    }

    @MainActor
    private func loadMainScreen() async {
        isLoading = true
        errorMessage = nil

        do {
            // Backend-driven entry point.
            rootComponent = try await service.loadScreen("main")
        } catch {
            rootComponent = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private func registerDefaultComponents(in registry: ComponentRegistry) {
    // Default mapping between JSON "type" and SwiftUI implementation.
    registry.register(type: "VStack", component: VStackComponent.self)
    registry.register(type: "HStack", component: HStackComponent.self)
    registry.register(type: "ScrollView", component: ScrollViewComponent.self)
    registry.register(type: "Text", component: TextComponent.self)
    registry.register(type: "Button", component: ButtonComponent.self)
    registry.register(type: "Image", component: ImageComponent.self)
    registry.register(type: "Spacer", component: SpacerComponent.self)
    registry.register(type: "TextField", component: TextFieldComponent.self)
    registry.register(type: "DataSource", component: DataSourceComponent.self)
    registry.register(type: "DBGrid", component: DBGridComponent.self)
    // TODO: Add TabBarComponent.swift to Xcode project
     registry.register(type: "TabBar", component: TabBarComponent.self)
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
