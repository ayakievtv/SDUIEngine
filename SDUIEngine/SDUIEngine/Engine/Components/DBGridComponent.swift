import SwiftUI

private struct DBGridColumn: Hashable {
    let field: String
    let title: String
    let sortable: Bool
}

private struct DBGridRow: Identifiable {
    let id: String
    let payload: [String: JSONValue]
}

private struct DBGridRowTemplateSpec {
    let title: String
    let subtitle: String?
    let caption: String?
    let badge: String?

    static func from(props: [String: JSONValue], columns: [DBGridColumn]) -> DBGridRowTemplateSpec {
        if let row = props["row"]?.objectValue {
            return DBGridRowTemplateSpec(
                title: row["title"]?.stringValue ?? "{{id}}",
                subtitle: row["subtitle"]?.stringValue,
                caption: row["caption"]?.stringValue,
                badge: row["badge"]?.stringValue
            )
        }

        let primary = columns.first?.field ?? "id"
        let secondary = columns.dropFirst().first?.field
        let tertiary = columns.dropFirst(2).first?.field

        return DBGridRowTemplateSpec(
            title: "{{\(primary)}}",
            subtitle: secondary.map { "{{\($0)}}" },
            caption: tertiary.map { "{{\($0)}}" },
            badge: nil
        )
    }

    var signature: String {
        "\(title)|\(subtitle ?? "")|\(caption ?? "")|\(badge ?? "")"
    }

    static let fallback = DBGridRowTemplateSpec(
        title: "{{id}}",
        subtitle: nil,
        caption: nil,
        badge: nil
    )
}

private final class DBGridCachedRow: NSObject {
    let title: String
    let subtitle: String?
    let caption: String?
    let badge: String?

    init(title: String, subtitle: String?, caption: String?, badge: String?) {
        self.title = title
        self.subtitle = subtitle
        self.caption = caption
        self.badge = badge
    }
}

private final class DBGridRowTemplateCache {
    static let shared = DBGridRowTemplateCache()
    private let cache = NSCache<NSString, DBGridCachedRow>()

    private init() {
        cache.countLimit = 600
    }

    func resolve(id: String, updatedAt: String, template: DBGridRowTemplateSpec, payload: [String: JSONValue]) -> DBGridCachedRow {
        let key = "\(id)|\(updatedAt)|\(template.signature)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let rendered = DBGridCachedRow(
            title: Self.interpolate(template.title, payload: payload),
            subtitle: template.subtitle.map { Self.interpolate($0, payload: payload) },
            caption: template.caption.map { Self.interpolate($0, payload: payload) },
            badge: template.badge.map { Self.interpolate($0, payload: payload) }
        )
        cache.setObject(rendered, forKey: key)
        return rendered
    }

    private static func interpolate(_ input: String, payload: [String: JSONValue]) -> String {
        var output = input
        while let open = output.range(of: "{{"),
              let close = output.range(of: "}}", range: open.upperBound..<output.endIndex) {
            let key = output[open.upperBound..<close.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let replacement = payloadStringValue(payload: payload, key: key)
            output.replaceSubrange(open.lowerBound..<close.upperBound, with: replacement)
        }

        return output
    }

    private static func payloadValue(payload: [String: JSONValue], key: String) -> JSONValue? {
        let segments = key.split(separator: ".").map(String.init)
        if segments.isEmpty {
            return nil
        }

        var current: JSONValue? = .object(payload)
        for segment in segments {
            guard let object = current?.objectValue else {
                return nil
            }
            current = lookupValue(in: object, key: segment)
            if current == nil {
                return nil
            }
        }
        return current
    }

    private static func payloadStringValue(payload: [String: JSONValue], key: String) -> String {
        guard let value = payloadValue(payload: payload, key: key) else {
            return ""
        }
        if let string = value.stringValue { return string }
        if let number = value.numberValue { return String(number) }
        if let bool = value.boolValue { return bool ? "true" : "false" }
        return ""
    }

    private static func normalizeKey(_ key: String) -> String {
        key.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func lookupValue(in object: [String: JSONValue], key: String) -> JSONValue? {
        if let direct = object[key] { return direct }
        if let upper = object[key.uppercased()] { return upper }
        if let lower = object[key.lowercased()] { return lower }

        let normalizedKey = normalizeKey(key)
        if normalizedKey.isEmpty {
            return nil
        }

        for (candidate, value) in object where normalizeKey(candidate) == normalizedKey {
            _ = candidate
            return value
        }
        for value in object.values {
            if let nested = findValueRecursively(in: value, normalizedKey: normalizedKey) {
                return nested
            }
        }
        return nil
    }

    private static func findValueRecursively(in value: JSONValue, normalizedKey: String, depth: Int = 0) -> JSONValue? {
        if depth > 4 {
            return nil
        }

        if let object = value.objectValue {
            for (candidate, candidateValue) in object where normalizeKey(candidate) == normalizedKey {
                _ = candidate
                return candidateValue
            }
            for child in object.values {
                if let nested = findValueRecursively(in: child, normalizedKey: normalizedKey, depth: depth + 1) {
                    return nested
                }
            }
        } else if let array = value.arrayValue {
            for child in array {
                if let nested = findValueRecursively(in: child, normalizedKey: normalizedKey, depth: depth + 1) {
                    return nested
                }
            }
        }
        return nil
    }
}


struct DBGridComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext

    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var allRows: [DBGridRow] = []
    @State private var visibleRows: [DBGridRow] = []
    @State private var nextCursor: String?
    @State private var hasMore = false
    @State private var filterText = ""
    @State private var sortField = ""
    @State private var sortAscending = true
    @State private var remoteSearchTask: Task<Void, Never>?
    @State private var activeConfig: DataSourceConfig?
    @State private var parsedRowTemplate: DBGridRowTemplateSpec = .fallback
    @State private var parsedRowComponentTemplate: ComponentModel?

    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
    }

    var body: some View {
        let props = model.resolvedProps
        let style = Style(props: props)
        let columns = resolvedColumns(props: props)
        let rowTemplate = parsedRowTemplate
        let rowComponentTemplate = parsedRowComponentTemplate
        let cfg = activeConfig ?? resolvedDataSourceConfig(props: props)
        let showControls = props.bool("showControls") ?? true

        return VStack(alignment: .leading, spacing: 10) {
            if showControls {
                HStack(spacing: 8) {
                    TextField("Filter...", text: $filterText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: filterText) { value in
                            applyLocalFilterAndSort(columns: columns, config: cfg)
                            triggerRemoteSearchIfNeeded(value: value, config: cfg)
                        }

                    Button("Reload") {
                        Task {
                            let resolved = await resolveDataSourceConfigWithRetry(props: props)
                            activeConfig = resolved
                            await loadInitial(config: resolved, resetCursor: true, remoteQuery: filterText)
                        }
                    }
                    .buttonStyle(.bordered)
                }

                if cfg.sorting {
                    HStack(spacing: 8) {
                        Text("Sort:")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        Picker("Sort", selection: $sortField) {
                            Text("Default").tag("")
                            ForEach(columns.filter(\.sortable), id: \.field) { column in
                                Text(column.title).tag(column.field)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: sortField) { _ in
                            applyLocalFilterAndSort(columns: columns, config: cfg)
                        }

                        Button(sortAscending ? "Asc" : "Desc") {
                            sortAscending.toggle()
                            applyLocalFilterAndSort(columns: columns, config: cfg)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if isLoading && visibleRows.isEmpty {
                ProgressView("Loading grid...")
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            } else if visibleRows.isEmpty {
                Text("No rows")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(visibleRows, id: \.id) { row in
                        rowCard(row: row, template: rowTemplate, rowComponentTemplate: rowComponentTemplate)
                            .onAppear {
                                // Проверяем только последнюю строку для дозагрузки
                                if let lastId = visibleRows.last?.id, row.id == lastId {
                                    let threshold = max(cfg.prefetchThreshold, 1)
                                    let shouldPrefetch = hasMore && !isLoadingMore
                                    if shouldPrefetch {
                                        Task { await loadMore(config: cfg) }
                                    }
                                }
                            }
                    }

                    if isLoadingMore {
                        ProgressView("Loading more...")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                    } else if hasMore {
                        Button("Load More") {
                            Task { await loadMore(config: cfg) }
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .applyStyle(style, includeFontSize: false)
        .task {
            let resolved = await resolveDataSourceConfigWithRetry(props: props)
            activeConfig = resolved
            parsedRowTemplate = DBGridRowTemplateSpec.from(props: props, columns: columns)
            if parsedRowComponentTemplate == nil {
                parsedRowComponentTemplate = buildRowComponentTemplate(from: props)
            }
            if sortField.isEmpty {
                sortField = resolved.defaultSortField ?? ""
            }
            sortAscending = resolved.defaultSortAscending
            await loadInitial(config: resolved, resetCursor: true, remoteQuery: nil)
        }
    }

    
    private func rowCard(
        row: DBGridRow,
        template: DBGridRowTemplateSpec,
        rowComponentTemplate: ComponentModel?
    ) -> AnyView {
        if let rowComponentTemplate {
            let resolvedComponent = resolvedRowComponentModel(template: rowComponentTemplate, row: row)
            return AnyView(
                Button {
                    handleRowTap(row: row)
                } label: {
                    ComponentRenderer(model: resolvedComponent, context: context, registry: context.componentRegistry)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            )
        }

        let updatedAt = row.payload["updatedAt"]?.stringValue ?? row.payload["clientUpdatedAt"]?.stringValue ?? ""
        let cached = DBGridRowTemplateCache.shared.resolve(
            id: row.id,
            updatedAt: updatedAt,
            template: template,
            payload: row.payload
        )

        return AnyView(
            Button {
                handleRowTap(row: row)
            } label: {
                Text("No row template")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        )
    }

    private func handleRowTap(row: DBGridRow) {
        let selectedIDStateKey = model.resolvedProps.string("selectedIdStateKey")
            ?? model.resolvedProps.string("selectionStateKey")
            ?? "selectedRowId"
        context.setState(key: selectedIDStateKey, value: .string(row.id))
        if selectedIDStateKey.hasSuffix(".id") {
            let uuidKey = String(selectedIDStateKey.dropLast(3)) + ".uuid"
            context.setState(key: uuidKey, value: .string(row.id))
        } else if selectedIDStateKey.hasSuffix(".uuid") {
            let idKey = String(selectedIDStateKey.dropLast(5)) + ".id"
            context.setState(key: idKey, value: .string(row.id))
        }

        guard let event = model.event(for: .onTap) else {
            return
        }

        var params = event.params
        if params["value"] == nil {
            params["value"] = .string(row.id)
        }
        params["rowId"] = .string(row.id)

        context.trigger(EventModel(type: .onTap, targets: event.targets, params: params))
    }

    private func resolvedColumns(props: [String: JSONValue]) -> [DBGridColumn] {
        guard let array = props["columns"]?.arrayValue else {
            return [
                DBGridColumn(field: "id", title: "ID", sortable: true),
                DBGridColumn(field: "name", title: "Name", sortable: true),
                DBGridColumn(field: "status", title: "Status", sortable: true),
            ]
        }

        let columns = array.compactMap { value -> DBGridColumn? in
            guard let object = value.objectValue else { return nil }
            let field = object["field"]?.stringValue ?? ""
            guard !field.isEmpty else { return nil }
            let title = object["title"]?.stringValue ?? field
            let sortable = object["sortable"]?.boolValue ?? true
            return DBGridColumn(field: field, title: title, sortable: sortable)
        }

        return columns.isEmpty ? [DBGridColumn(field: "id", title: "ID", sortable: true)] : columns
    }

    private func resolvedDataSourceConfig(props: [String: JSONValue]) -> DataSourceConfig {
        let dataSourceID = props.string("dataSourceId") ?? props.string("dataSource") ?? ""
        if !dataSourceID.isEmpty, let registered = context.dataSourceRegistry.get(dataSourceID) {
            return registered
        }

        let fallbackID = dataSourceID.isEmpty ? model.id : dataSourceID
        let endpoint = props.string("endpoint") ?? ""
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
            sorting: props.bool("sorting") ?? config.sorting,
            defaultSortField: props.string("defaultSortField") ?? config.defaultSortField,
            defaultSortAscending: props.bool("defaultSortAscending") ?? config.defaultSortAscending,
            prefetchThreshold: Int(props.double("prefetchThreshold") ?? Double(config.prefetchThreshold)),
            keyField: props.string("keyField") ?? config.keyField
        )

        return config
    }

    private func buildRowComponentTemplate(from props: [String: JSONValue]) -> ComponentModel? {
        guard let object = props["rowComponent"]?.objectValue else {
            return nil
        }

        guard let data = try? JSONEncoder().encode(JSONValue.object(object)) else {
            return nil
        }

        return try? JSONDecoder().decode(ComponentModel.self, from: data)
    }

    private func resolvedRowComponentModel(template: ComponentModel, row: DBGridRow) -> ComponentModel {
        return resolveComponentModel(template: template, row: row)
    }

    private func resolveComponentModel(template: ComponentModel, row: DBGridRow) -> ComponentModel {
        let props = template.props?.mapValues { resolveValue($0, payload: row.payload) }
        let events = template.events?.mapValues { resolveValue($0, payload: row.payload) }
        let children = template.children?.map { resolveComponentModel(template: $0, row: row) }
        let componentID = "\(template.id)__row_\(row.id)"

        return ComponentModel(
            id: componentID,
            type: template.type,
            props: props,
            events: events,
            children: children
        )
    }

    private func resolveValue(_ value: JSONValue, payload: [String: JSONValue]) -> JSONValue {
        switch value {
        case let .string(string):
            return .string(interpolate(string, payload: payload))
        case let .array(array):
            return .array(array.map { resolveValue($0, payload: payload) })
        case let .object(object):
            let mapped = object.reduce(into: [String: JSONValue]()) { partialResult, pair in
                partialResult[pair.key] = resolveValue(pair.value, payload: payload)
            }
            return .object(mapped)
        default:
            return value
        }
    }

    private func interpolate(_ input: String, payload: [String: JSONValue]) -> String {
        var output = input
        while let open = output.range(of: "{{"),
              let close = output.range(of: "}}", range: open.upperBound..<output.endIndex) {
            let key = output[open.upperBound..<close.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let replacement = valueAsString(payloadValue(payload: payload, key: key))
            output.replaceSubrange(open.lowerBound..<close.upperBound, with: replacement)
        }

        return output
    }

    private func resolveDataSourceConfigWithRetry(
        props: [String: JSONValue],
        retries: Int = 20,
        delayMs: UInt64 = 100
    ) async -> DataSourceConfig {
        var config = resolvedDataSourceConfig(props: props)
        let dataSourceID = props.string("dataSourceId") ?? props.string("dataSource") ?? ""

        guard !dataSourceID.isEmpty, config.endpoint.isEmpty else {
            return config
        }

        for _ in 0..<retries {
            try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
            config = resolvedDataSourceConfig(props: props)
            if !config.endpoint.isEmpty {
                return config
            }
        }

        return config
    }

    private func triggerRemoteSearchIfNeeded(value: String, config: DataSourceConfig) {
        remoteSearchTask?.cancel()
        guard config.remoteFiltering else { return }

        remoteSearchTask = Task {
            let delay = UInt64(max(config.debounceMs, 50)) * 1_000_000
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await loadInitial(config: config, resetCursor: true, remoteQuery: value)
        }
    }

    @MainActor
    private func loadInitial(config: DataSourceConfig, resetCursor: Bool, remoteQuery: String?) async {
        guard !config.endpoint.isEmpty else {
            errorMessage = "DBGrid DataSource endpoint is empty"
            return
        }

        isLoading = true
        errorMessage = nil

        if resetCursor {
            nextCursor = nil
            hasMore = false
        }

        do {
            let endpoint = buildEndpoint(base: config.endpoint, query: remoteQuery, cursor: nil, config: config)
            let response = try await context.callAPI(endpoint: endpoint, method: .get, body: nil)
            let parsed = parseRows(response: response, keyField: config.keyField, pageSize: config.pageSize)
            allRows = parsed.rows
            nextCursor = parsed.nextCursor
            hasMore = parsed.hasMore
            applyLocalFilterAndSort(columns: resolvedColumns(props: model.resolvedProps), config: config)
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
            let endpoint = buildEndpoint(base: config.endpoint, query: filterText, cursor: nextCursor, config: config)
            let response = try await context.callAPI(endpoint: endpoint, method: .get, body: nil)
            let parsed = parseRows(response: response, keyField: config.keyField, pageSize: config.pageSize)
            allRows.append(contentsOf: parsed.rows)
            visibleRows = allRows // Добавлено обновление visibleRows
            nextCursor = parsed.nextCursor
            hasMore = parsed.hasMore
            applyLocalFilterAndSort(columns: resolvedColumns(props: model.resolvedProps), config: config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyLocalFilterAndSort(columns: [DBGridColumn], config: DataSourceConfig) {
        var rows = allRows

        if config.localFiltering, !filterText.isEmpty {
            let query = filterText.lowercased()
            let fields = columns.map(\.field)
            rows = rows.filter { row in
                fields.contains { field in
                    valueAsString(payloadValue(payload: row.payload, key: field)).lowercased().contains(query)
                }
            }
        }

        if config.sorting {
            let field = sortField.isEmpty ? (config.defaultSortField ?? columns.first?.field ?? config.keyField) : sortField
            rows.sort { lhs, rhs in
                let left = valueAsString(payloadValue(payload: lhs.payload, key: field))
                let right = valueAsString(payloadValue(payload: rhs.payload, key: field))
                if sortAscending {
                    return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
                }
                return left.localizedCaseInsensitiveCompare(right) == .orderedDescending
            }
        }

        visibleRows = rows
    }

    private func parseRows(response: JSONValue, keyField: String, pageSize: Int) -> (rows: [DBGridRow], nextCursor: String?, hasMore: Bool) {
        if let object = response.objectValue {
            let items = object["items"]?.arrayValue
            let rows = (items ?? []).enumerated().compactMap { index, item in
                toGridRow(item: item, keyField: keyField, index: index)
            }
            let nextCursor = object["nextCursor"]?.stringValue
                ?? object["offset"]?.stringValue
                ?? object["cursor"]?.stringValue
            let hasMore = object["hasMore"]?.boolValue ?? ((nextCursor != nil) || rows.count >= pageSize)
            if !rows.isEmpty {
                return (rows, nextCursor, hasMore)
            }

            if let single = toGridRow(item: .object(object), keyField: keyField, index: 0) {
                return ([single], nil, false)
            }
        }

        if let array = response.arrayValue {
            let rows = array.enumerated().compactMap { index, item in
                toGridRow(item: item, keyField: keyField, index: index)
            }
            return (rows, nil, rows.count >= pageSize)
        }

        return ([], nil, false)
    }

    private func toGridRow(item: JSONValue, keyField: String, index: Int) -> DBGridRow? {
        guard let sourcePayload = item.objectValue else {
            return nil
        }
        let payload = unwrapRowPayload(sourcePayload)

        let keyUpper = keyField.uppercased()
        let keyLower = keyField.lowercased()
        let candidates: [String] = [
            keyField,
            keyUpper,
            keyLower,
            "id",
            "ID",
            "invoice_id",
            "INVOICE_ID",
            "invoice_no",
            "INVOICE_NO",
            "row.id",
            "data.id",
            "row.invoice_id",
            "data.invoice_id",
            "row.invoice_no",
            "data.invoice_no",
        ]

        var resolvedID: String?
        for key in candidates {
            if let value = payloadStringValue(payload: payload, key: key), !value.isEmpty {
                resolvedID = value
                break
            }
        }

        let rawID = resolvedID ?? "row_\(index)_\(UUID().uuidString)"

        return DBGridRow(id: rawID, payload: payload)
    }

    private func buildEndpoint(base: String, query: String?, cursor: String?, config: DataSourceConfig) -> String {
        var endpoint = base

        if endpoint.contains("{query}") {
            endpoint = endpoint.replacingOccurrences(of: "{query}", with: (query ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        }

        if endpoint.contains("{cursor}") {
            endpoint = endpoint.replacingOccurrences(of: "{cursor}", with: (cursor ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        }

        guard var components = URLComponents(string: endpoint) else {
            return endpoint
        }

        var queryItems = components.queryItems ?? []

        if let query, !query.isEmpty, !endpoint.contains("{query}") {
            queryItems.removeAll(where: { $0.name == config.queryParam })
            queryItems.append(URLQueryItem(name: config.queryParam, value: query))
        }

        if let cursor, !cursor.isEmpty, !endpoint.contains("{cursor}") {
            queryItems.removeAll(where: { $0.name == config.cursorParam })
            queryItems.append(URLQueryItem(name: config.cursorParam, value: cursor))
        }

        queryItems.removeAll(where: { $0.name == "limit" })
        queryItems.append(URLQueryItem(name: "limit", value: String(max(config.pageSize, 1))))

        components.queryItems = queryItems
        return components.string ?? endpoint
    }

    private func valueAsString(_ value: JSONValue?) -> String {
        guard let value else { return "" }
        if let string = value.stringValue { return string }
        if let number = value.numberValue { return String(number) }
        if let bool = value.boolValue { return bool ? "true" : "false" }
        return ""
    }

    private func payloadValue(payload: [String: JSONValue], key: String) -> JSONValue? {
        let segments = key.split(separator: ".").map(String.init)
        if segments.isEmpty {
            return nil
        }

        var current: JSONValue? = .object(payload)
        for segment in segments {
            guard let object = current?.objectValue else {
                return nil
            }
            current = lookupValue(in: object, key: segment)
            if current == nil {
                return nil
            }
        }
        return current
    }

    private func payloadStringValue(payload: [String: JSONValue], key: String) -> String? {
        let value = payloadValue(payload: payload, key: key)
        let string = valueAsString(value)
        return string.isEmpty ? nil : string
    }

    private func normalizeKey(_ key: String) -> String {
        key.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func lookupValue(in object: [String: JSONValue], key: String) -> JSONValue? {
        if let direct = object[key] { return direct }
        if let upper = object[key.uppercased()] { return upper }
        if let lower = object[key.lowercased()] { return lower }

        let normalizedKey = normalizeKey(key)
        if normalizedKey.isEmpty {
            return nil
        }

        for (candidate, value) in object where normalizeKey(candidate) == normalizedKey {
            _ = candidate
            return value
        }
        for value in object.values {
            if let nested = findValueRecursively(in: value, normalizedKey: normalizedKey) {
                return nested
            }
        }
        return nil
    }

    private func unwrapRowPayload(_ payload: [String: JSONValue]) -> [String: JSONValue] {
        let wrappers = ["row", "data", "value", "record", "item"]
        var merged = payload
        for wrapper in wrappers {
            if let nested = lookupValue(in: payload, key: wrapper)?.objectValue, !nested.isEmpty {
                nested.forEach { key, value in
                    merged[key] = value
                }
            }
        }
        return merged
    }

    private func findValueRecursively(in value: JSONValue, normalizedKey: String, depth: Int = 0) -> JSONValue? {
        if depth > 4 {
            return nil
        }

        if let object = value.objectValue {
            for (candidate, candidateValue) in object where normalizeKey(candidate) == normalizedKey {
                _ = candidate
                return candidateValue
            }
            for child in object.values {
                if let nested = findValueRecursively(in: child, normalizedKey: normalizedKey, depth: depth + 1) {
                    return nested
                }
            }
        } else if let array = value.arrayValue {
            for child in array {
                if let nested = findValueRecursively(in: child, normalizedKey: normalizedKey, depth: depth + 1) {
                    return nested
                }
            }
        }
        return nil
    }
}
