import SwiftUI

// Reusable screen container: loads JSON by (appId, name) and renders dynamic component tree.
struct ScreenView: View {
    let route: AppRoute          // CHANGED: раньше был `name: String`
    let service: UIService
    let context: UIContext

    @State private var rootComponent: ComponentModel?
    @State private var errorMessage: String?
    @State private var isLoading = false

    init(route: AppRoute, service: UIService, context: UIContext) {
        self.route = route
        self.service = service
        self.context = context
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading \(route.screenName)...")
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text("Failed to load screen")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await load()
                        }
                    }
                }
                .padding(16)
            } else if let rootComponent {
                ComponentRenderer(model: rootComponent, context: context, registry: context.componentRegistry)
            } else {
                EmptyView()
            }
        }
        // CHANGED: id теперь учитывает appId+screenName - перезагрузка
        // при смене либо экрана, либо приложения
        .task(id: "\(route.appId)::\(route.screenName)") {
            await load()
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            rootComponent = try await service.loadScreen(screenName: route.screenName, appId: route.appId)
        } catch {
            rootComponent = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
