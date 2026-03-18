import SwiftUI

// MARK: - Main Content View

/// Root container for backend-driven navigation and initial screen bootstrap
struct ContentView: View {
    @StateObject private var router: NavigationRouter
    private let context: UIContext
    private let service: UIService

    @State private var rootComponent: ComponentModel?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTab = 0

    init() {
        // A single router instance is shared by the whole app tree
        let router = NavigationRouter()
        _router = StateObject(wrappedValue: router)

        // UIContext is the runtime "engine" used by components
        let context = UIContext(navigation: router)
        registerDefaultComponents(in: context.componentRegistry)
        self.context = context
        self.service = UIService()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // SDUI Tab
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
                // A single destination resolver for every AppRoute
                .navigationDestination(for: AppRoute.self) { route in
                    ScreenView(name: route.screenName, service: service, context: context)
                }
            }
            .tabItem {
                Label("Main", systemImage: "house.fill")
            }
            .tag(0)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)
        }
        .task {
            await loadMainScreen()
        }
    }

    /// Load main screen from backend
    @MainActor
    private func loadMainScreen() async {
        isLoading = true
        errorMessage = nil

        do {
            // Backend-driven entry point
            rootComponent = try await service.loadScreen("main")
        } catch {
            rootComponent = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Settings View

/// Native Settings View
struct SettingsView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                VStack(alignment: .leading, spacing: 15) {
                    SettingsRow(title: "Profile", subtitle: "User profile management", icon: "person.circle")
                    SettingsRow(title: "Notifications", subtitle: "Push notification settings", icon: "bell")
                    SettingsRow(title: "Security", subtitle: "Password and authentication", icon: "lock.shield")
                    SettingsRow(title: "Language", subtitle: "English", icon: "globe")
                    SettingsRow(title: "About", subtitle: "Version 1.0.0", icon: "info.circle")
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Settings Row

/// Settings row component
struct SettingsRow: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Component Registration

/// Register default components in registry
private func registerDefaultComponents(in registry: ComponentRegistry) {
    // Default mapping between JSON "type" and SwiftUI implementation
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

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
