import SwiftUI

// MARK: - Popup Option (строка списка, как DBGridRow, но с явными label/value)

struct PopupOption: Identifiable {
    let id: String        // = value
    let label: String
    let value: String
    let payload: [String: JSONValue]
}

// MARK: - Popup Component

struct PopupComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext

    private let stateKey: String
    private let optionLabelField: String
    private let optionValueField: String

    @State private var selectedValue: String
    @State private var selectedLabel: String = ""

    @State private var isPresented = false
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var allOptions: [PopupOption] = []
    @State private var visibleOptions: [PopupOption] = []
    @State private var searchText = ""
    @State private var nextCursor: String?
    @State private var hasMore = false
    @State private var remoteSearchTask: Task<Void, Never>?
    @State private var activeConfig: DataSourceConfig?

    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
        let key = model.resolvedProps.string("stateKey") ?? model.resolvedProps.string("bind") ?? model.id
        stateKey = key
        optionLabelField = model.resolvedProps.string("optionLabelField") ?? "label"
        optionValueField = model.resolvedProps.string("optionValueField") ?? "value"

        _selectedValue = State(initialValue: context.stateValue(for: key)?.stringValue ?? "")

        // статические options[] (как у Picker) - фолбэк, если нет endpoint/dataSourceId
        let staticOptions: [PopupOption] = (model.resolvedProps["options"]?.arrayValue ?? []).compactMap { item in
            guard let obj = item.objectValue,
                  let label = obj.string("label"),
                  let value = obj.string("value") else { return nil }
            return PopupOption(id: value, label: label, value: value, payload: obj)
        }
        _allOptions = State(initialValue: staticOptions)
        _visibleOptions = State(initialValue: staticOptions)
    }

    var body: some View {
        let props = model.resolvedProps
        let style = Style(props: props)
        let placeholder = props.string("placeholder") ?? ""

        Button {
            isPresented = true
        } label: {
            HStack {
                Spacer()
                
                Text(selectedLabel.isEmpty ? placeholder : selectedLabel)
                    .foregroundColor(selectedLabel.isEmpty ? .secondary : .primary)
               
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .applyStyle(style)
        .overlay(
            Rectangle()
                .fill(Color.appgray)
                .frame(height: 1),
            alignment: .bottom
        )
        .task {
            // если значение уже выбрано (форма открыта на редактирование),
            // но label ещё не известен - резолвим его отдельно
            if !selectedValue.isEmpty && selectedLabel.isEmpty {
                await resolveInitialLabel()
            }
        }
        .onAppear {
            ComponentStore.shared.register(
                componentID: model.id,
                component: AnyComponent(actionHandler: { [context] action, params in
                    guard action.uppercased() == "SET_VALUE" || action.uppercased() == "SET_TEXT" else { return }
                    guard let value = params?["value"] ?? params?["text"] else { return }
                    selectedValue = value
                    context.setState(key: stateKey, value: .string(value))
                    selectedLabel = params?["label"] ?? value
                    Task { if params?["label"] == nil { await resolveInitialLabel() } }
                })
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .sduiStateDidChange)) { note in
            guard
                let changedKey = note.userInfo?["key"] as? String,
                changedKey == stateKey,
                let changedValue = note.userInfo?["value"] as? JSONValue
            else {
                return
            }
//            let newValue = changedValue.stringValue ?? (changedValue.numberValue.map(String.init) ?? "")
            let newValue = changedValue.stringValue ?? changedValue.numberValue.map { String($0) } ?? ""
            
            if newValue != selectedValue {
                selectedValue = newValue
                selectedLabel = ""
                Task { await resolveInitialLabel() }
            }
        }
        .onDisappear {
            ComponentStore.shared.unregister(componentID: model.id)
        }
        .sheet(isPresented: $isPresented) {
            popupContent(props: props)
        }
    }

    // MARK: - Popup sheet content

    @ViewBuilder
    private func popupContent(props: [String: JSONValue]) -> some View {
        let title = props.string("popupTitle") ?? props.string("placeholder") ?? "Select value"

        NavigationView {
            VStack(spacing: 0) {
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(8)
                    .onChange(of: searchText) { value in
                        let cfg = activeConfig ?? resolvedDataSourceConfig(props: props)
                        applyLocalFilter(config: cfg)
                        triggerRemoteSearchIfNeeded(value: value, config: cfg)
                    }

                if isLoading && visibleOptions.isEmpty {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if visibleOptions.isEmpty {
                    Text("No results")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(visibleOptions) { option in
                            Button {
                                select(option)
                            } label: {
                                HStack {
                                    Text(option.label)
                                        .foregroundColor(.primary)
                                    if option.value == selectedValue {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .onAppear {
                                let cfg = activeConfig ?? resolvedDataSourceConfig(props: props)
                                let threshold = max(cfg.prefetchThreshold, 1)
                                let startIndex = max(visibleOptions.count - threshold, 0)
                                if let idx = visibleOptions.firstIndex(where: { $0.id == option.id }),
                                   idx >= startIndex, hasMore, !isLoadingMore {
                                    Task { await loadMore(config: cfg) }
                                }
                            }
                        }
                        if isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                if !selectedValue.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Clear") {
                            clearSelection()
                        }
                    }
                }
            }
        }
        .task {
            let resolved = resolvedDataSourceConfig(props: props)
            activeConfig = resolved
            if allOptions.isEmpty || !resolved.endpoint.isEmpty {
                await loadInitial(config: resolved, remoteQuery: nil)
            } else {
                visibleOptions = allOptions
            }
        }
    }

    // MARK: - Selection

    private func select(_ option: PopupOption) {
        selectedValue = option.value
        selectedLabel = option.label
        context.setState(key: stateKey, value: .string(option.value))
        isPresented = false

        guard let event = model.event(for: .onChange) else { return }
        var params = event.params
        if params["value"] == nil {
            params["value"] = .string(option.value)
        }
        params["label"] = .string(option.label)
        context.trigger(EventModel(type: .onChange, targets: event.targets, params: params))
    }

    private func clearSelection() {
        selectedValue = ""
        selectedLabel = ""
        context.setState(key: stateKey, value: .string(""))
        isPresented = false
    }

    // MARK: - Data loading (аналогично DBGridComponent)

    private func resolvedDataSourceConfig(props: [String: JSONValue]) -> DataSourceConfig {
        let dataSourceID = props.string("dataSourceId") ?? props.string("dataSource") ?? ""
        if !dataSourceID.isEmpty, let registered = context.dataSourceRegistry.get(dataSourceID) {
            return registered
        }

        let fallbackID = dataSourceID.isEmpty ? model.id : dataSourceID
        // optionsEndpoint - тот же проп, что у Picker (уже с подставленным @BASE_URL)
        let endpoint = props.string("optionsEndpoint") ?? props.string("endpoint") ?? ""
        var config = DataSourceConfig.makeDefault(id: fallbackID, endpoint: endpoint)

        config = DataSourceConfig(
            id: config.id,
            endpoint: endpoint.isEmpty ? config.endpoint : endpoint,
            fetchPolicy: props.string("fetchPolicy") ?? config.fetchPolicy,
            pageSize: Int(props.double("pageSize") ?? Double(config.pageSize)),
            queryParam: props.string("queryParam") ?? config.queryParam,
            cursorParam: props.string("cursorParam") ?? config.cursorParam,
            localFiltering: props.bool("localFiltering") ?? config.localFiltering,
            remoteFiltering: props.bool("remoteFiltering") ?? config.remoteFiltering,
            debounceMs: Int(props.double("debounceMs") ?? Double(config.debounceMs)),
            sorting: false,
            defaultSortField: nil,
            defaultSortAscending: true,
            prefetchThreshold: Int(props.double("prefetchThreshold") ?? Double(config.prefetchThreshold)),
            keyField: optionValueField
        )

        return config
    }

    @MainActor
    private func loadInitial(config: DataSourceConfig, remoteQuery: String?) async {
        guard !config.endpoint.isEmpty else {
            // только статические options - уже заполнены в init
            visibleOptions = allOptions
            return
        }

        isLoading = true
        errorMessage = nil
        nextCursor = nil
        hasMore = false

        do {
            let endpoint = buildEndpoint(base: config.endpoint, query: remoteQuery, cursor: nil, config: config)
            let response = try await context.callAPI(endpoint: endpoint, method: .get, body: nil)
            let parsed = parseOptions(response: response, pageSize: config.pageSize)
            allOptions = parsed.options
            nextCursor = parsed.nextCursor
            hasMore = parsed.hasMore
            applyLocalFilter(config: config)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    private func loadMore(config: DataSourceConfig) async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let endpoint = buildEndpoint(base: config.endpoint, query: searchText, cursor: nextCursor, config: config)
            let response = try await context.callAPI(endpoint: endpoint, method: .get, body: nil)
            let parsed = parseOptions(response: response, pageSize: config.pageSize)
            allOptions.append(contentsOf: parsed.options)
            nextCursor = parsed.nextCursor
            hasMore = parsed.hasMore
            applyLocalFilter(config: config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func triggerRemoteSearchIfNeeded(value: String, config: DataSourceConfig) {
        remoteSearchTask?.cancel()
        guard config.remoteFiltering else { return }
        remoteSearchTask = Task {
            let delay = UInt64(max(config.debounceMs, 50)) * 1_000_000
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await loadInitial(config: config, remoteQuery: value)
        }
    }

    private func applyLocalFilter(config: DataSourceConfig) {
        guard config.localFiltering, !searchText.isEmpty else {
            visibleOptions = allOptions
            return
        }
        let query = searchText.lowercased()
        visibleOptions = allOptions.filter { $0.label.lowercased().contains(query) }
    }

    private func parseOptions(response: JSONValue, pageSize: Int) -> (options: [PopupOption], nextCursor: String?, hasMore: Bool) {
        guard let obj = response.objectValue, let rows = obj["report"]?.arrayValue else {
            return ([], nil, false)
        }
        let options: [PopupOption] = rows.compactMap { row in
            guard let rowObj = row.objectValue else { return nil }
            let normalized = Dictionary(rowObj.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { a, _ in a })
            guard let label = normalized.string(optionLabelField.lowercased()) ?? normalized.string(optionLabelField),
                  let value = normalized.string(optionValueField.lowercased()) ?? normalized.string(optionValueField)
            else { return nil }
            return PopupOption(id: value, label: label, value: value, payload: normalized)
        }
        let nextCursor = obj["nextCursor"]?.stringValue ?? obj["offset"]?.stringValue
        let hasMore = obj["hasMore"]?.boolValue ?? ((nextCursor != nil) || options.count >= pageSize)
        return (options, nextCursor, hasMore)
    }

    private func buildEndpoint(base: String, query: String?, cursor: String?, config: DataSourceConfig) -> String {
        guard var components = URLComponents(string: base) else { return base }
        var queryItems = components.queryItems ?? []

        if let query, !query.isEmpty {
            queryItems.removeAll { $0.name == config.queryParam }
            queryItems.append(URLQueryItem(name: config.queryParam, value: query))
        }
        if let cursor, !cursor.isEmpty {
            queryItems.removeAll { $0.name == config.cursorParam }
            queryItems.append(URLQueryItem(name: config.cursorParam, value: cursor))
        }
        queryItems.removeAll { $0.name == "limit" }
        queryItems.append(URLQueryItem(name: "limit", value: String(max(config.pageSize, 1))))

        components.queryItems = queryItems
        return components.string ?? base
    }

    // MARK: - Резолв label для уже выбранного value (форма открыта на редактирование)

    @MainActor
    private func resolveInitialLabel() async {
        guard !selectedValue.isEmpty else { return }

        // 1) ищем среди уже загруженных/статических опций
        if let found = allOptions.first(where: { $0.value == selectedValue }) {
            selectedLabel = found.label
            return
        }

        // 2) если есть отдельный сервис резолва по значению - дернуть его
        //    (опциональный проп "resolveLabelEndpoint" с плейсхолдером {value})
        let props = model.resolvedProps
        guard let template = props.string("resolveLabelEndpoint") else {
            selectedLabel = selectedValue   // fallback: показываем сырое значение
            return
        }
        let endpoint = template.replacingOccurrences(of: "{value}", with: selectedValue)

        do {
            let response = try await context.callAPI(endpoint: endpoint, method: .get, body: nil)
            guard let obj = response.objectValue,
                  let rows = obj["report"]?.arrayValue,
                  let first = rows.first?.objectValue
            else {
                selectedLabel = selectedValue
                return
            }
            let normalized = Dictionary(first.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { a, _ in a })
            selectedLabel = normalized.string(optionLabelField.lowercased()) ?? selectedValue
        } catch {
            selectedLabel = selectedValue
        }
    }
}
