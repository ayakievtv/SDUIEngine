import SwiftUI

// MARK: - Notification Extensions

extension Notification.Name {
    static let sduiStateDidChange = Notification.Name("sdui.state.didChange")
}

// MARK: - State Management Protocols

/// Protocol for managing component state storage
protocol StateStoreManaging: AnyObject {
    var state: [String: JSONValue] { get }
    func getValue(for key: String) -> JSONValue?
    func set(_ value: JSONValue, for key: String)
    func merge(_ json: JSONValue, withPrefix: String)
    func getValues(forPrefix prefix: String) -> [String: JSONValue]
}


// MARK: - Event Dispatching

/// Type alias for event handler closure
typealias EventHandler = (EventModel, UIContext) -> Void

/// Protocol for dispatching component events
protocol EventDispatching: AnyObject {
    func dispatch(_ event: EventModel, context: UIContext)
}

// MARK: - HTTP Client

/// HTTP methods for API requests
enum HTTPMethod: String, Codable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Protocol for making API requests
protocol APIClient: AnyObject {
    func request(endpoint: String, method: HTTPMethod, body: [String: JSONValue]?) async throws -> JSONValue
}

///// Mock API client for testing
//final class MockAPIClient: APIClient {
//    func request(endpoint: String, method: HTTPMethod, body: [String: JSONValue]?) async throws -> JSONValue {
//        .object([
//            "endpoint": .string(endpoint),
//            "method": .string(method.rawValue),
//            "body": .object(body ?? [:]),
//        ])
//    }
//}

/// Creates default API client with offline data layer
func makeDefaultAPIClient() -> APIClient {
    let remote = URLSessionRemoteClient()
    let dataLayer = OfflineDataLayer(remote: remote)
    return OfflineAPIClient(dataLayer: dataLayer)
}

// MARK: - UI Context

/// Runtime context shared by every component: state, events, navigation and API
@MainActor
final class UIContext {
    let stateStore: StateStoreManaging
    let eventDispatcher: EventDispatching
    let navigation: NavigationRouting
    let apiClient: APIClient
    let componentRegistry: ComponentRegistry
    let dataSourceRegistry: DataSourceRegistry
    private let componentStore: ComponentStore
    private var openFormRequestSerial = 0
    private var activeOpenFormTokenByPrefix: [String: Int] = [:]

    let globalVariables: GlobalVariablesStore      // init: = .shared
    let variableResolver: ParamResolver            // init: ParamResolver(store: globalVariables)

    
    var activeRow: [String: JSONValue] = [:]
    
    
    func resolveGlobalVariables(in model: ComponentModel) -> ComponentModel {
        model.resolvingVariables(using: variableResolver)
    }

    init(
        stateStore: StateStoreManaging = InMemoryStateStore(),
        eventDispatcher: EventDispatching = EventDispatcher(),
        navigation: NavigationRouting? = nil,
        apiClient: APIClient = makeDefaultAPIClient(),
        componentRegistry: ComponentRegistry = ComponentRegistry(),
        dataSourceRegistry: DataSourceRegistry = DataSourceRegistry(),
        componentStore: ComponentStore = .shared
    ) {
        self.stateStore = stateStore
        self.eventDispatcher = eventDispatcher
        self.navigation = navigation ?? NavigationRouter()
        self.apiClient = apiClient
        self.componentRegistry = componentRegistry
        self.dataSourceRegistry = dataSourceRegistry
        self.componentStore = componentStore

        self.globalVariables = .shared
        self.variableResolver = ParamResolver(store: globalVariables)
        
        // Bridge common component events to backend-driven navigation actions
        registerDefaultEventHandlers()
    }

    
    
    
    /// params вида {"id":{"source":"row","field":"id"}} / {"source":"state","stateKey":".."} -> [String:String]
    private func resolveNestedParams(_ nested: [String: JSONValue]?) -> [String: String] {
        guard let nested else { return [:] }
        let row = Dictionary(activeRow.map { ($0.key.lowercased(), $0.value) },
                             uniquingKeysWith: { a, _ in a })

        func scalar(_ v: JSONValue) -> String? {
            if let s = v.stringValue { return s }
            if let n = v.numberValue { return n.rounded() == n ? String(Int(n)) : String(n) }
            if let b = v.boolValue { return b ? "true" : "false" }
            return nil
        }

        var out: [String: String] = [:]
        for (k, v) in nested {
            if let o = v.objectValue {
                switch o["source"]?.stringValue {
                case "row":
                    if let f = o["field"]?.stringValue, let rv = row[f.lowercased()] { out[k] = scalar(rv) }
                case "state":
                    if let key = o["stateKey"]?.stringValue, let sv = stateValue(for: key) { out[k] = scalar(sv) }
                default: break
                }
            } else if let s = scalar(v) {
                out[k] = s
            }
        }
        return out
    }
    
    
    
    
    
    
    
    
    
    // MARK: - State Management

    /// Set state value and post notification
    func setState(_ value: JSONValue, for key: String) {
        stateStore.set(value, for: key)
        NotificationCenter.default.post(
            name: .sduiStateDidChange,
            object: self,
            userInfo: ["key": key, "value": value]
        )
    }

    /// Set state value with string key
    func setState(key: String, value: JSONValue) {
        setState(value, for: key)
    }

    /// Get state value
    func stateValue(for key: String) -> JSONValue? {
        stateStore.getValue(for: key)
    }

    /// Create two-way binding for string state values
    func bindingString(for key: String, default defaultValue: String = "") -> Binding<String> {
        // Two-way binding between UI controls and state store string values
        Binding(
            get: {
                guard let value = self.stateValue(for: key) else { return defaultValue }
                if let string = value.stringValue { return string }
                if let number = value.numberValue { return String(number) }
                if let bool = value.boolValue { return bool ? "true" : "false" }
                return defaultValue
            },
            set: { self.setState(key: key, value: .string($0)) }
        )
    }

    /// Create two-way binding for boolean state values
    func bindingBool(for key: String, default defaultValue: Bool = false) -> Binding<Bool> {
        // Two-way binding between UI controls and state store bool values
        Binding(
            get: { self.stateValue(for: key)?.boolValue ?? defaultValue },
            set: { self.setState(key: key, value: .bool($0)) }
        )
    }

    // MARK: - Event Handling

    /// Dispatch event through event dispatcher
    func dispatch(_ event: EventModel) {
        eventDispatcher.dispatch(event, context: self)
    }

    /// Trigger event (alias for dispatch)
    func trigger(_ event: EventModel) {
        dispatch(event)
    }

    // MARK: - Navigation

   

    /// Handle server navigation action
    func handle(action: ServerAction) {
        navigation.handle(action: action)
    }

    /// Dismiss current modal
    func dismissModal() {
        navigation.dismissModal()
    }

    /// Go back in navigation
    func goBack() {
        navigation.pop()
    }

    // MARK: - API Calls

    /// Make API call with GET method
    func callAPI(endpoint: String, method: HTTPMethod = .get, body: [String: JSONValue]? = nil) async throws -> JSONValue {
        try await apiClient.request(endpoint: endpoint, method: method, body: body)
    }

    /// Make API call with any method
    func callAPI(_ endpoint: String, method: HTTPMethod = .get, body: [String: JSONValue]? = nil) async throws -> JSONValue {
        try await callAPI(endpoint: endpoint, method: method, body: body)
    }

    // MARK: - Default Event Handlers

    /// Register default event handlers for common component events
    private func registerDefaultEventHandlers() {
        guard let dispatcher = eventDispatcher as? EventDispatcher else {
            return
        }

        // Standard tap action path: component event -> ServerAction -> router
        dispatcher.register(.onTap) { event, context in
            context.dispatchComponentAction(event)
          
            if event.params["actions"]?.arrayValue != nil {
                return
            }
            let currentAppId = context.navigation.currentRoute?.appId ?? "1"
              if let action = ServerAction.from(event: event, currentAppId: currentAppId) {
                  context.handle(action: action)
              }
        }

        // Submit actions can navigate as well (for forms/search flows)
        dispatcher.register(.onSubmit) { event, context in
            context.dispatchComponentAction(event)
            if event.params["actions"]?.arrayValue != nil {
                return
            }
            let currentAppId = context.navigation.currentRoute?.appId ?? "1"
              if let action = ServerAction.from(event: event, currentAppId: currentAppId) {
                  context.handle(action: action)
              }
        }
        
        // Change actions support "event chains", e.g. TextField value update -> target component update.
        dispatcher.register(.onChange) { event, context in
            context.dispatchComponentAction(event)
            if event.params["actions"]?.arrayValue != nil {
                return
            }
            let currentAppId = context.navigation.currentRoute?.appId ?? "1"
              if let action = ServerAction.from(event: event, currentAppId: currentAppId) {
                  context.handle(action: action)
              }
        }

        // Lifecycle events should also be able to trigger component/backend data actions.
        dispatcher.register(.onAppear) { event, context in
            context.dispatchComponentAction(event)
        }

        dispatcher.register(.onDisappear) { event, context in
            context.dispatchComponentAction(event)
        }
    }


    
    func dispatchComponentAction(_ event: EventModel) {
        guard let actions = event.params["actions"]?.arrayValue else { return }
        
        for actionValue in actions {
            guard let actionData = actionValue.objectValue,
                  let actionName = actionData["action"]?.stringValue else { continue }
//            let params = flattenJSONParams(actionData)

            var params = flattenJSONParams(actionData)

            // вложенные params (навигация): кладём значения в state целевой формы <route>Form.<key>,
            // откуда их читает OPEN_FORM
            let nav = resolveNestedParams(actionData["params"]?.objectValue)
            if !nav.isEmpty {
                if let route = params["route"], !route.isEmpty {
                    for (k, v) in nav {
                        setState(.string(v), for: "\(route)Form.\(k)")   // именно .string
                        
//                        print("🧭 nav \(route)Form.\(k) = '\(v)'")
                    }
                }
                params.merge(nav) { current, _ in current }
            }
            
            let explicitTargets = actionData["targets"]?.arrayValue?
                .compactMap(\.stringValue)
                .filter { !$0.isEmpty } ?? []

            let resolvedTargets: [String]
            if !explicitTargets.isEmpty {
                resolvedTargets = explicitTargets
            } else if let singleTarget = actionData["target"]?.stringValue, !singleTarget.isEmpty {
                resolvedTargets = [singleTarget]
            } else {
                resolvedTargets = event.targets
            }

            for targetID in resolvedTargets where !targetID.isEmpty {
                if isSystemTarget(targetID) {
                    handleSystemAction(targetID, action: actionName, params: params)
                } else {
                    dispatchToComponent(targetID, action: actionName, params: params)
                }
            }
        }
    }
    
    
    /// Check if target is a system keyword
    private func isSystemTarget(_ id: String) -> Bool {
        let systemTargets = ["navigation", "backend_data", "backend_logger"]
        return systemTargets.contains(id)
    }

    /// Router for system actions
    private func handleSystemAction(_ targetID: String, action: String, params: [String: String]) {
        switch targetID {
        case "navigation":
            let appId = params["appId"] ?? navigation.currentRoute?.appId ?? "1"
            switch action.lowercased() {
            case "push", "navigate": self.push(params["route"] ?? "", appId: appId)
            case "modal":   self.modal(params["route"] ?? "", appId: appId)
            case "pop":     self.goBack()
            case "replace": self.replace(with: params["route"] ?? "", appId: appId)
            default: break
            }
        case "backend_data":
            handleDataAction(action: action, params: params)
        default: break
        }
    }
    
    /// Handle data actions (OPEN_FORM, SAVE_FORM, etc.)
     func handleDataAction(action: String, params: [String: String]) {
        Task { @MainActor in
            switch action.uppercased() {
            case "OPEN_FORM":
                await performOpenForm(params)
                
            case "SAVE_FORM":
                await performSaveForm(params)

            case "DISCARD_FORM":
                performDiscardForm(params)
                if params["goBack"]?.lowercased() == "true" || params["close"]?.lowercased() == "true" {
                    goBack()
                }
                
            case "REFRESH_DATA":
                // For manual DataSource refresh
                if let dsId = params["dataSourceId"] {
                    // Logic to notify DataSource about refresh need
                }
                
            default:
                print("⚠️ SDUI: Unknown data action: \(action)")
            }
        }
    }

    private func performDiscardForm(_ params: [String: String]) {
        let prefix = params["formStatePrefix"] ?? params["formKey"] ?? "main"
        let keyPrefix = prefix.hasSuffix(".") ? prefix : "\(prefix)."

        let keysToClear = stateStore.state.keys.filter { $0.hasPrefix(keyPrefix) }
        for key in keysToClear {
            setState(.string(""), for: key)
        }
    }
    
    /// Perform open form action
    private func performOpenForm(_ params: [String: String]) async {
        // 1. Extract basic parameters from flat dictionary
        guard let rawEndpoint = params["endpoint"] else { return }

        let idStateKey = params["idStateKey"] ?? "dummyForm.id"
        let formPrefix = params["formStatePrefix"] ?? String(idStateKey.split(separator: ".").first ?? "main")
        
        // Generate keys for ID and UUID synchronization
        let uuidStateKey = idStateKey.hasSuffix(".id")
            ? String(idStateKey.dropLast(3)) + ".uuid"
            : (idStateKey.hasSuffix(".uuid") ? idStateKey : "\(formPrefix).uuid")

        // Get current ID value from state for URL substitution
        let idValue = stateValue(for: idStateKey)?.stringValue
            ?? stateValue(for: uuidStateKey)?.stringValue
            ?? ""

        let endpoint = rawEndpoint.replacingOccurrences(of: "{id}", with: idValue)

        // Validation: if URL needs ID and it's empty - stop
        if rawEndpoint.contains("{id}") && idValue.isEmpty {
            setState(.string("OPEN_FORM: id is empty for endpoint with {id}"), for: "\(formPrefix)._openFormError")
            return
        }

        let clearPreviousDraft = params["clearPreviousDraft"] == "true"
        let keyPrefix = formPrefix.hasSuffix(".") ? formPrefix : "\(formPrefix)."

        // 2. Request session management (Anti-race condition)
        openFormRequestSerial += 1
        let requestToken = openFormRequestSerial
        activeOpenFormTokenByPrefix[formPrefix] = requestToken

        // Clear old data if required
        if clearPreviousDraft {
            let keysToClear = stateStore.state.keys.filter { $0.hasPrefix(keyPrefix) }
            for key in keysToClear {
                setState(.string(""), for: key)
            }
        }

        // Pre-set ID in state (so UI knows we're loading)
        if !idValue.isEmpty {
            setState(.string(idValue), for: idStateKey)
            setState(.string(idValue), for: uuidStateKey)
        }
        
        setState(.string(""), for: "\(formPrefix)._openFormError")
        setState(.string(endpoint), for: "\(formPrefix)._lastOpenFormEndpoint")

        // 3. Network request
        do {
            let response = try await callAPI(endpoint: endpoint, method: .get, body: nil)
            
            // Check: is this response still relevant?
            guard activeOpenFormTokenByPrefix[formPrefix] == requestToken else { return }
            
            
            
            
            
            
            guard let payload = response.objectValue else {
                setState(.string("OPEN_FORM: response is not an object"), for: "\(formPrefix)._openFormError")
                return
            }

            // Обёртки ответа: DS_API кладёт строки в "report", ORDS в "items"
            let rows = payload["report"]?.arrayValue
                ?? payload["items"]?.arrayValue
                ?? payload["data"]?.arrayValue
                ?? payload["rows"]?.arrayValue

            guard let firstRecord = rows?.first?.objectValue else {
                setState(.string("OPEN_FORM: no record in response"), for: "\(formPrefix)._openFormError")
                return
            }

            // Ключи в нижний регистр: поля формы читают <prefix>.<lower(column)>;
            // служебную колонку RN (номер строки) не переносим
            let record = Dictionary(firstRecord.map { ($0.key.lowercased(), $0.value) },
                                    uniquingKeysWith: { a, _ in a })
            for (key, value) in record where key != "rn" {
                setState(value, for: "\(formPrefix).\(key)")
            }

            // Синхронизация id/uuid
            if let uuid = record["uuid"]?.stringValue, !uuid.isEmpty {
                setState(.string(uuid), for: "\(formPrefix).uuid")
                setState(.string(uuid), for: "\(formPrefix).id")
            } else if let id = record["id"]?.stringValue, !id.isEmpty {
                setState(.string(id), for: "\(formPrefix).id")
                setState(.string(id), for: "\(formPrefix).uuid")
            }

            // Маппинг дат (если одной из них нет)
            if let docDate = record["doc_date"] {
                setState(docDate, for: "\(formPrefix).due_date")
            } else if let dueDate = record["due_date"] {
                setState(dueDate, for: "\(formPrefix).doc_date")
            }

            // Финальная проверка ID
            if !idValue.isEmpty {
                setState(.string(idValue), for: idStateKey)
                setState(.string(idValue), for: uuidStateKey)
            }
            
            
            
            
            
//            guard let payload = response.objectValue else {
//                setState(.string("OPEN_FORM: response is not an object"), for: "\(formPrefix)._openFormError")
//                return
//            }
//
//            // Unpack data (Oracle ORDS "items" or flat object)
//            let items = payload["items"]?.arrayValue
//            let firstRecord = items?.first?.objectValue ?? payload
//            
//            // Bulk state update
//            for (key, value) in firstRecord {
//                setState(value, for: "\(formPrefix).\(key)")
//            }
//
//            // Synchronize system ID/UUID fields
//            if let uuid = firstRecord["uuid"]?.stringValue, !uuid.isEmpty {
//                setState(.string(uuid), for: "\(formPrefix).uuid")
//                setState(.string(uuid), for: "\(formPrefix).id")
//            } else if let id = firstRecord["id"]?.stringValue, !id.isEmpty {
//                setState(.string(id), for: "\(formPrefix).id")
//                setState(.string(id), for: "\(formPrefix).uuid")
//            }
//
//            // Date mapping (if one of them is missing)
//            if let docDate = firstRecord["doc_date"] {
//                setState(docDate, for: "\(formPrefix).due_date")
//            } else if let dueDate = firstRecord["due_date"] {
//                setState(dueDate, for: "\(formPrefix).doc_date")
//            }
//
//            // Final ID check
//            if !idValue.isEmpty {
//                setState(.string(idValue), for: idStateKey)
//                setState(.string(idValue), for: uuidStateKey)
//            }
            
        } catch {
            guard activeOpenFormTokenByPrefix[formPrefix] == requestToken else { return }
            setState(.string(error.localizedDescription), for: "\(formPrefix)._openFormError")
        }
    }
    
    
    private func performSaveForm(_ params: [String: String]) async {
        guard let rawEndpoint = params["endpoint"] else { return }
        let idStateKey = params["idStateKey"] ?? "dummyForm.id"
        let inferredPrefix = String(idStateKey.split(separator: ".").first ?? "main")
        let prefix = params["formStatePrefix"] ?? params["formKey"] ?? inferredPrefix
        
        // Collect data. If getValues is not yet in protocol,
        // it needs to be added there (implementation below)
        let formData = stateStore.getValues(forPrefix: prefix)
        
        let idValue = stateStore.getValue(for: idStateKey)?.stringValue
            ?? stateStore.getValue(for: "\(prefix).id")?.stringValue
            ?? ""
        let endpoint = rawEndpoint.replacingOccurrences(of: "{id}", with: idValue)
        
        let method: HTTPMethod = (params["method"]?.uppercased() == "POST") ? .post : .put
        
        do {
            _ = try await callAPI(endpoint: endpoint, method: method, body: formData)
         
        } catch {
            print("❌ SDUI: Save error: \(error)")
        }
    }
    


    /// Send resolved action command to specific UI component by ID.
    private func dispatchToComponent(_ targetID: String, action: String, params: [String: String]) {
        componentStore.get(componentID: targetID)?.handle(action: action, params: params)
    }

    /// Helper function to convert JSONValue to [String: String]
    /// (this is the format expected by component handle method)
    private func flattenJSONParams(_ dict: [String: JSONValue]) -> [String: String] {
        dict.reduce(into: [String: String]()) { result, pair in
            switch pair.value {
            case .string(let v): result[pair.key] = v
            case .number(let v): result[pair.key] = String(v)
            case .bool(let v):   result[pair.key] = v ? "true" : "false"
            default: break
            }
        }
    }
    
  

    private func performDiscardForm(_ params: [String: JSONValue]) {
        let prefix = params["formStatePrefix"]?.stringValue
            ?? params["formKey"]?.stringValue
            ?? "dummyForm"
        let keyPrefix = prefix.hasSuffix(".") ? prefix : "\(prefix)."

        let keysToClear = stateStore.state.keys.filter { $0.hasPrefix(keyPrefix) }
        for key in keysToClear {
            setState(.string(""), for: key)
        }
    }



    private func performSaveForm(_ params: [String: JSONValue]) async {
        guard let rawEndpoint = params["endpoint"]?.stringValue else {
            return
        }

        let methodRaw = params["method"]?.stringValue?.uppercased() ?? "POST"
        let method = HTTPMethod(rawValue: methodRaw) ?? .post
        let idStateKey = params["idStateKey"]?.stringValue ?? "dummyForm.id"
        let formPrefix = params["formStatePrefix"]?.stringValue ?? String(idStateKey.split(separator: ".").first ?? "main")
        let idValue = stateValue(for: idStateKey)?.stringValue ?? ""
        let endpoint = rawEndpoint.replacingOccurrences(of: "{id}", with: idValue)
        let keyPrefix = formPrefix.hasSuffix(".") ? formPrefix : "\(formPrefix)."

        let payload = stateStore.state.reduce(into: [String: JSONValue]()) { result, pair in
            guard pair.key.hasPrefix(keyPrefix) else { return }
            let field = String(pair.key.dropFirst(keyPrefix.count))
            guard !field.isEmpty else { return }
            result[field] = pair.value
        }

        do {
            _ = try await callAPI(endpoint: endpoint, method: method, body: payload)
        } catch {
            // Save queue/offline layer can fail silently here; state is preserved for retry.
        }
    }
}



extension UIContext {
    func navigate(to route: String, appId: String) {
        navigation.navigate(to: AppRoute(appId: appId, screenName: route), mode: .push)
    }

    func navigate(_ route: String, appId: String) {
        navigate(to: route, appId: appId)
    }

    func push(_ route: String, appId: String) {
        navigation.push(AppRoute(appId: appId, screenName: route))
    }

    func modal(_ route: String, appId: String) {
        navigation.modal(AppRoute(appId: appId, screenName: route))
    }

    func replace(with route: String, appId: String) {
        navigation.replace(with: AppRoute(appId: appId, screenName: route))
    }
}
