import SwiftUI

// Reusable screen container: loads JSON by name and renders dynamic component tree.
struct ScreenView: View {
    let name: String
    let service: UIService
    let context: UIContext

    @State private var rootComponent: ComponentModel?
    @State private var errorMessage: String?
    @State private var isLoading = false

    init(name: String, service: UIService, context: UIContext) {
        self.name = name
        self.service = service
        self.context = context
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading \(name)...")
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
        .task(id: name) {
            // Reload when route/screen name changes.
            await load()
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            // Delegates to UIService (backend first, local fallback).
            rootComponent = try await service.loadScreen(screenName: name)
        } catch {
            rootComponent = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
