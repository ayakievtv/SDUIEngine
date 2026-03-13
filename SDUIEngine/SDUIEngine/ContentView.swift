import SwiftUI

struct ContentView: View {
    private let context: UIContext
    private let service: UIService

    @State private var rootComponent: ComponentModel?
    @State private var isLoading = true
    @State private var errorMessage: String?

    init() {
        let context = UIContext()
        registerDefaultComponents(in: context.componentRegistry)
        self.context = context
        self.service = UIService()
    }

    var body: some View {
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
        .task {
            await loadMainScreen()
        }
    }

    @MainActor
    private func loadMainScreen() async {
        isLoading = true
        errorMessage = nil

        do {
            rootComponent = try await service.loadScreen("main")
        } catch {
            rootComponent = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private func registerDefaultComponents(in registry: ComponentRegistry) {
    registry.register(type: "VStack", component: VStackComponent.self)
    registry.register(type: "HStack", component: HStackComponent.self)
    registry.register(type: "ScrollView", component: ScrollViewComponent.self)
    registry.register(type: "Text", component: TextComponent.self)
    registry.register(type: "Button", component: ButtonComponent.self)
    registry.register(type: "Image", component: ImageComponent.self)
    registry.register(type: "Spacer", component: SpacerComponent.self)
    registry.register(type: "TextField", component: TextFieldComponent.self)
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
