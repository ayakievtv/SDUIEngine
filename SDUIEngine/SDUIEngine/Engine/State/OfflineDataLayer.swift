import Foundation
import CryptoKit

enum EntitySyncState: String, Codable {
    case clean
    case dirty
    case queued
    case syncing
    case failed
    case conflict
}

struct EntityRecord: Codable, Equatable {
    let id: UUID
    var createdAt: String
    var updatedAt: String
    var clientUpdatedAt: String
    var data: [String: JSONValue]
    var syncState: EntitySyncState
}

enum QueryStatus: String, Codable {
    case idle
    case loading
    case refreshing
    case loadingMore
    case error
    case ready
}

struct QuerySnapshot: Codable, Equatable {
    var queryKey: String
    var ids: [UUID]
    var pageSize: Int
    var nextCursor: String?
    var hasMore: Bool
    var filterText: String
    var sort: String
    var status: QueryStatus
    var error: String?
    var updatedAt: String
}

struct FormDraft: Codable, Equatable {
    let formKey: String
    let entityID: UUID
    var original: [String: JSONValue]
    var draft: [String: JSONValue]
    var dirtyFields: [String]
    var status: String
    var errors: [String: JSONValue]?
    var isSaved: Bool
}

enum PendingOperationStatus: String, Codable {
    case queued
    case syncing
    case failed
    case acked
    case conflict
}

struct PendingOperation: Codable, Equatable {
    let opID: UUID
    let entityType: String
    let entityID: UUID
    let method: HTTPMethod
    let endpoint: String
    let payload: [String: JSONValue]
    let clientUpdatedAt: String
    var attempt: Int
    var status: PendingOperationStatus
    var lastError: String?
    let createdAt: String
    var updatedAt: String
}

actor EntityStore {
    private var records: [UUID: EntityRecord] = [:]
    private let cacheFileURL: URL
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheFileURL = documentsPath.appendingPathComponent("entity_store.json")
        loadFromDisk()
    }
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoded = try JSONDecoder().decode([UUID: EntityRecord].self, from: data)
            records = decoded
        } catch {
            print("Failed to load entity store: \(error)")
        }
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: cacheFileURL)
        } catch {
            print("Failed to save entity store: \(error)")
        }
    }

    func upsert(payload: [String: JSONValue], syncState: EntitySyncState = .clean) -> EntityRecord {
        let now = Timestamp.now()
        let id = resolvedEntityID(payload: payload) ?? UUID()

        if var existing = records[id] {
            existing.data.merge(payload) { _, new in new }
            existing.updatedAt = payload["updatedAt"]?.stringValue ?? existing.updatedAt
            existing.clientUpdatedAt = now
            existing.syncState = syncState
            records[id] = existing
            saveToDisk()
            return existing
        }

        let createdAt = payload["createdAt"]?.stringValue ?? now
        let updatedAt = payload["updatedAt"]?.stringValue ?? now
        var data = payload
        data["id"] = .string(id.uuidString)
        if data["uuid"] == nil {
            data["uuid"] = .string(id.uuidString)
        }
        data["createdAt"] = .string(createdAt)
        data["updatedAt"] = .string(updatedAt)
        data["clientUpdatedAt"] = .string(now)

        let newRecord = EntityRecord(
            id: id,
            createdAt: createdAt,
            updatedAt: updatedAt,
            clientUpdatedAt: now,
            data: data,
            syncState: syncState
        )
        records[id] = newRecord
        saveToDisk()
        return newRecord
    }

    func get(_ id: UUID) -> EntityRecord? {
        records[id]
    }

    func get(ids: [UUID]) -> [EntityRecord] {
        ids.compactMap { records[$0] }
    }

    func all() -> [EntityRecord] {
        Array(records.values)
    }

    func clear() {
        records.removeAll()
        saveToDisk()
    }

    private func resolvedEntityID(payload: [String: JSONValue]) -> UUID? {
        if let raw = identifierString(payload: payload), !raw.isEmpty {
            if let uuid = UUID(uuidString: raw) {
                return uuid
            }
            return deterministicUUID(from: raw)
        }
        return nil
    }

    private func identifierString(payload: [String: JSONValue]) -> String? {
        let candidateKeys = Set(["id", "uuid"])

        for (key, value) in payload where candidateKeys.contains(key.lowercased()) {
            if let string = value.stringValue, !string.isEmpty {
                return string
            }
            if let number = value.numberValue {
                return String(number)
            }
        }

        return nil
    }

    private func deterministicUUID(from source: String) -> UUID {
        let digest = SHA256.hash(data: Data(source.utf8))
        let bytes = Array(digest.prefix(16))
        let value = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: value)
    }
}

actor QueryStore {
    private var snapshots: [String: QuerySnapshot] = [:]

    func set(_ snapshot: QuerySnapshot) {
        snapshots[snapshot.queryKey] = snapshot
    }

    func get(_ queryKey: String) -> QuerySnapshot? {
        snapshots[queryKey]
    }

    func appendPage(
        queryKey: String,
        ids: [UUID],
        pageSize: Int,
        nextCursor: String?,
        hasMore: Bool,
        filterText: String,
        sort: String
    ) {
        let now = Timestamp.now()
        if var existing = snapshots[queryKey] {
            existing.ids.append(contentsOf: ids)
            existing.pageSize = pageSize
            existing.nextCursor = nextCursor
            existing.hasMore = hasMore
            existing.filterText = filterText
            existing.sort = sort
            existing.status = .ready
            existing.error = nil
            existing.updatedAt = now
            snapshots[queryKey] = existing
            return
        }

        snapshots[queryKey] = QuerySnapshot(
            queryKey: queryKey,
            ids: ids,
            pageSize: pageSize,
            nextCursor: nextCursor,
            hasMore: hasMore,
            filterText: filterText,
            sort: sort,
            status: .ready,
            error: nil,
            updatedAt: now
        )
    }

    func replace(
        queryKey: String,
        ids: [UUID],
        pageSize: Int,
        nextCursor: String?,
        hasMore: Bool,
        filterText: String,
        sort: String
    ) {
        let now = Timestamp.now()
        snapshots[queryKey] = QuerySnapshot(
            queryKey: queryKey,
            ids: ids,
            pageSize: pageSize,
            nextCursor: nextCursor,
            hasMore: hasMore,
            filterText: filterText,
            sort: sort,
            status: .ready,
            error: nil,
            updatedAt: now
        )
    }

    func clear() {
        snapshots.removeAll()
    }
}

actor FormDraftStore {
    private var activeDraft: FormDraft?

    func open(formKey: String, entityID: UUID, payload: [String: JSONValue]) {
        activeDraft = FormDraft(
            formKey: formKey,
            entityID: entityID,
            original: payload,
            draft: payload,
            dirtyFields: [],
            status: "ready",
            errors: nil,
            isSaved: false
        )
    }

    func update(field: String, value: JSONValue) {
        guard var draft = activeDraft else { return }
        draft.draft[field] = value
        if !draft.dirtyFields.contains(field) {
            draft.dirtyFields.append(field)
        }
        draft.status = "ready"
        activeDraft = draft
    }

    func active() -> FormDraft? {
        activeDraft
    }

    func markQueued() {
        guard var draft = activeDraft else { return }
        draft.status = "queued"
        activeDraft = draft
    }

    func markSaved() {
        guard var draft = activeDraft else { return }
        draft.isSaved = true
        draft.status = "saved"
        activeDraft = draft
    }

    func clear() {
        activeDraft = nil
    }
}

actor SyncQueueStore {
    private var operations: [PendingOperation] = []
    private let cacheFileURL: URL
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheFileURL = documentsPath.appendingPathComponent("sync_queue.json")
        loadFromDisk()
    }
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoded = try JSONDecoder().decode([PendingOperation].self, from: data)
            operations = decoded
        } catch {
            print("Failed to load sync queue: \(error)")
        }
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(operations)
            try data.write(to: cacheFileURL)
        } catch {
            print("Failed to save sync queue: \(error)")
        }
    }

    func enqueue(_ operation: PendingOperation) {
        operations.append(operation)
        saveToDisk()
    }

    func nextQueued() -> PendingOperation? {
        operations.first(where: { $0.status == .queued || $0.status == .failed })
    }

    func update(_ operation: PendingOperation) {
        guard let index = operations.firstIndex(where: { $0.opID == operation.opID }) else {
            return
        }
        operations[index] = operation
        saveToDisk()
    }

    func remove(opID: UUID) {
        operations.removeAll(where: { $0.opID == opID })
        saveToDisk()
    }

    func all() -> [PendingOperation] {
        operations
    }
}

actor LocalResponseStore {
    private var storage: [String: JSONValue] = [:]
    private let cacheFileURL: URL
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheFileURL = documentsPath.appendingPathComponent("local_response_cache.json")
        loadFromDisk()
    }
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoded = try JSONDecoder().decode([String: JSONValue].self, from: data)
            storage = decoded
        } catch {
            print("Failed to load local response cache: \(error)")
        }
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(storage)
            try data.write(to: cacheFileURL)
        } catch {
            print("Failed to save local response cache: \(error)")
        }
    }

    func set(_ value: JSONValue, for endpoint: String) {
        storage[endpoint] = value
        saveToDisk()
    }

    func get(for endpoint: String) -> JSONValue? {
        storage[endpoint]
    }
}

protocol RemoteRequesting: AnyObject {
    func request(endpoint: String, method: HTTPMethod, body: [String: JSONValue]?) async throws -> JSONValue
}

enum RemoteRequestError: Error {
    case invalidBaseURL
    case invalidResponse
    case badStatusCode(Int)
}

final class URLSessionRemoteClient: RemoteRequesting {
    private let baseURL: URL?
    private let session: URLSession

    init(baseURL: URL? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func request(endpoint: String, method: HTTPMethod, body: [String: JSONValue]?) async throws -> JSONValue {
        guard let url = buildURL(endpoint: endpoint) else {
            throw RemoteRequestError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteRequestError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw RemoteRequestError.badStatusCode(httpResponse.statusCode)
        }

        if data.isEmpty {
            return .object(["ok": .bool(true)])
        }

        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    private func buildURL(endpoint: String) -> URL? {
        if endpoint.hasPrefix("http://") || endpoint.hasPrefix("https://") {
            return URL(string: endpoint)
        }
        guard let baseURL else {
            return nil
        }
        return baseURL.appendingPathComponent(endpoint)
    }
}

actor OfflineDataLayer {
    private let remote: RemoteRequesting
    private let localResponses: LocalResponseStore
    let entityStore: EntityStore
    let queryStore: QueryStore
    let formDraftStore: FormDraftStore
    let syncQueue: SyncQueueStore
    private var isFlushing = false
    private var scheduledRetryTask: Task<Void, Never>?
    private var scheduledRetryAt: Date?

    private let maxOperationsPerFlush = 25
    private let minBackoffSeconds: TimeInterval = 2
    private let maxBackoffSeconds: TimeInterval = 120

    init(
        remote: RemoteRequesting,
        localResponses: LocalResponseStore = LocalResponseStore(),
        entityStore: EntityStore = EntityStore(),
        queryStore: QueryStore = QueryStore(),
        formDraftStore: FormDraftStore = FormDraftStore(),
        syncQueue: SyncQueueStore = SyncQueueStore()
    ) {
        self.remote = remote
        self.localResponses = localResponses
        self.entityStore = entityStore
        self.queryStore = queryStore
        self.formDraftStore = formDraftStore
        self.syncQueue = syncQueue
    }

    func request(endpoint: String, method: HTTPMethod, body: [String: JSONValue]?) async throws -> JSONValue {
        switch method {
        case .get:
            return try await networkFirstGet(endpoint: endpoint)
        case .post, .put:
            return await queueFirstSave(endpoint: endpoint, method: method, body: body)
        case .patch, .delete:
            return try await remote.request(endpoint: endpoint, method: method, body: body)
        }
    }

    func loadQuery(
        queryKey: String,
        endpoint: String,
        filterText: String = "",
        sort: String = "",
        append: Bool = false,
        pageSize: Int = 20,
        itemsPath: String = "items",
        nextCursorPath: String = "nextCursor",
        hasMorePath: String = "hasMore"
    ) async throws -> [EntityRecord] {
        let response = try await networkFirstGet(endpoint: endpoint)
        let parsed = await parseGridResponse(
            response: response,
            itemsPath: itemsPath,
            nextCursorPath: nextCursorPath,
            hasMorePath: hasMorePath,
            pageSize: pageSize
        )

        if append {
            await queryStore.appendPage(
                queryKey: queryKey,
                ids: parsed.ids,
                pageSize: pageSize,
                nextCursor: parsed.nextCursor,
                hasMore: parsed.hasMore,
                filterText: filterText,
                sort: sort
            )
        } else {
            await queryStore.replace(
                queryKey: queryKey,
                ids: parsed.ids,
                pageSize: pageSize,
                nextCursor: parsed.nextCursor,
                hasMore: parsed.hasMore,
                filterText: filterText,
                sort: sort
            )
        }

        return await entityStore.get(ids: parsed.ids)
    }

    func searchInCurrentDataset(queryKey: String, fields: [String], text: String) async -> [EntityRecord] {
        guard let snapshot = await queryStore.get(queryKey) else {
            return []
        }

        if text.isEmpty {
            return await entityStore.get(ids: snapshot.ids)
        }

        let lowercasedText = text.lowercased()
        let rows = await entityStore.get(ids: snapshot.ids)
        return rows.filter { row in
            fields.contains { field in
                (row.data[field]?.stringValue ?? "").lowercased().contains(lowercasedText)
            }
        }
    }

    func openForm(formKey: String, entityID: UUID, endpoint: String) async throws -> FormDraft {
        await formDraftStore.clear()
        let response = try await networkFirstGet(endpoint: endpoint)
        guard let payload = response.objectValue else {
            throw RemoteRequestError.invalidResponse
        }

        _ = await entityStore.upsert(payload: payload, syncState: .clean)
        await formDraftStore.open(formKey: formKey, entityID: entityID, payload: payload)

        guard let draft = await formDraftStore.active() else {
            throw RemoteRequestError.invalidResponse
        }
        return draft
    }

    func saveActiveForm(endpoint: String, method: HTTPMethod) async throws -> JSONValue {
        guard let draft = await formDraftStore.active() else {
            throw RemoteRequestError.invalidResponse
        }

        let body = draft.draft
        let response = await queueFirstSave(endpoint: endpoint, method: method, body: body)
        await formDraftStore.markQueued()
        return response
    }

    func discardActiveForm() async {
        await formDraftStore.clear()
    }

    func flushQueue() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }

        var processed = 0
        var nextRetryDelayNs: UInt64?

        while processed < maxOperationsPerFlush, var operation = await syncQueue.nextQueued() {
            if let remaining = remainingBackoffNanos(for: operation) {
                nextRetryDelayNs = minRetryDelay(current: nextRetryDelayNs, candidate: remaining)
                break
            }

            operation.status = .syncing
            operation.updatedAt = Timestamp.now()
            await syncQueue.update(operation)
            processed += 1

            do {
                let response = try await remote.request(
                    endpoint: operation.endpoint,
                    method: operation.method,
                    body: operation.payload
                )
                await localResponses.set(response, for: operation.endpoint)
                await ingest(response: response)
                await syncQueue.remove(opID: operation.opID)
            } catch {
                operation.attempt += 1
                operation.status = .failed
                operation.lastError = error.localizedDescription
                operation.updatedAt = Timestamp.now()
                await syncQueue.update(operation)
                let delayNs = backoffDelayNanos(forAttempt: operation.attempt)
                nextRetryDelayNs = minRetryDelay(current: nextRetryDelayNs, candidate: delayNs)
                break
            }
        }

        if processed >= maxOperationsPerFlush, await syncQueue.nextQueued() != nil {
            nextRetryDelayNs = minRetryDelay(current: nextRetryDelayNs, candidate: 200_000_000)
        }

        if let delay = nextRetryDelayNs {
            scheduleRetry(after: delay)
        }
    }

    private func networkFirstGet(endpoint: String) async throws -> JSONValue {
        do {
            let response = try await remote.request(endpoint: endpoint, method: .get, body: nil)
            await localResponses.set(response, for: endpoint)
            await ingest(response: response)
            return response
        } catch {
            if let cached = await localResponses.get(for: endpoint) {
                return cached
            }
            throw error
        }
    }

    private func queueFirstSave(endpoint: String, method: HTTPMethod, body: [String: JSONValue]?) async -> JSONValue {
        let payload = body ?? [:]
        let entityRecord = await entityStore.upsert(payload: payload, syncState: .queued)
        let now = Timestamp.now()
        let operation = PendingOperation(
            opID: UUID(),
            entityType: payload["entityType"]?.stringValue ?? "generic",
            entityID: entityRecord.id,
            method: method,
            endpoint: endpoint,
            payload: payload,
            clientUpdatedAt: now,
            attempt: 0,
            status: .queued,
            lastError: nil,
            createdAt: now,
            updatedAt: now
        )

        await syncQueue.enqueue(operation)
        scheduleRetry(after: 0)

        return .object([
            "status": .string("queued"),
            "opId": .string(operation.opID.uuidString),
            "entityId": .string(entityRecord.id.uuidString),
            "clientUpdatedAt": .string(now),
        ])
    }

    private func parseGridResponse(
        response: JSONValue,
        itemsPath: String,
        nextCursorPath: String,
        hasMorePath: String,
        pageSize: Int
    ) async -> (ids: [UUID], nextCursor: String?, hasMore: Bool) {
        let rowsValue = value(at: itemsPath, in: response) ?? value(at: "items", in: response)
        let rows = rowsValue?.arrayValue ?? response.arrayValue
        guard let rows else {
            if let object = response.objectValue,
               let singlePayload = object["id"] ?? object["uuid"],
               let raw = singlePayload.stringValue,
               let id = UUID(uuidString: raw) {
                return ([id], nil, false)
            }
            return ([], nil, false)
        }

        var ids: [UUID] = []
        for row in rows {
            guard let payload = row.objectValue else { continue }
            let record = await entityStore.upsert(payload: payload, syncState: .clean)
            ids.append(record.id)
        }

        let nextCursor = (
            value(at: nextCursorPath, in: response)?.stringValue ??
            value(at: "nextCursor", in: response)?.stringValue ??
            value(at: "offset", in: response)?.stringValue ??
            value(at: "cursor", in: response)?.stringValue
        )
        let hasMore = (
            value(at: hasMorePath, in: response)?.boolValue ??
            value(at: "hasMore", in: response)?.boolValue ??
            ((nextCursor != nil) || ids.count >= max(pageSize, 1))
        )

        return (
            ids,
            nextCursor,
            hasMore
        )
    }

    private func value(at path: String, in root: JSONValue) -> JSONValue? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "$" || trimmed == "." {
            return root
        }

        let normalized = trimmed.hasPrefix("$.") ? String(trimmed.dropFirst(2)) : trimmed
        let segments = normalized.split(separator: ".").map(String.init)
        if segments.isEmpty {
            return root
        }

        var current: JSONValue? = root
        for segment in segments {
            guard let value = current else { return nil }
            if let object = value.objectValue {
                current = object[segment]
                continue
            }
            if let array = value.arrayValue, let index = Int(segment), array.indices.contains(index) {
                current = array[index]
                continue
            }
            return nil
        }
        return current
    }

    private func ingest(response: JSONValue) async {
        guard let object = response.objectValue else {
            return
        }

        if let items = object["items"]?.arrayValue {
            for item in items {
                guard let payload = item.objectValue else { continue }
                _ = await entityStore.upsert(payload: payload, syncState: .clean)
            }
            return
        }

        _ = await entityStore.upsert(payload: object, syncState: .clean)
    }

    private func backoffDelayNanos(forAttempt attempt: Int) -> UInt64 {
        let safeAttempt = max(attempt, 1)
        let exponent = Double(min(safeAttempt - 1, 8))
        let delaySeconds = min(maxBackoffSeconds, minBackoffSeconds * pow(2, exponent))
        return UInt64(delaySeconds * 1_000_000_000)
    }

    private func remainingBackoffNanos(for operation: PendingOperation) -> UInt64? {
        guard operation.status == .failed, operation.attempt > 0 else {
            return nil
        }
        guard let failedAt = Timestamp.date(from: operation.updatedAt) else {
            return nil
        }

        let requiredNs = backoffDelayNanos(forAttempt: operation.attempt)
        let elapsedSeconds = Date().timeIntervalSince(failedAt)
        let elapsedNs = max(0, UInt64(elapsedSeconds * 1_000_000_000))
        if elapsedNs >= requiredNs {
            return nil
        }
        return requiredNs - elapsedNs
    }

    private func minRetryDelay(current: UInt64?, candidate: UInt64) -> UInt64 {
        guard let current else { return candidate }
        return min(current, candidate)
    }

    private func scheduleRetry(after delayNs: UInt64) {
        let targetDate = Date().addingTimeInterval(Double(delayNs) / 1_000_000_000)
        if let scheduledRetryAt, scheduledRetryAt <= targetDate {
            return
        }

        scheduledRetryTask?.cancel()
        scheduledRetryAt = targetDate
        scheduledRetryTask = Task {
            try? await Task.sleep(nanoseconds: delayNs)
            await self.runScheduledRetry()
        }
    }

    private func runScheduledRetry() async {
        scheduledRetryTask = nil
        scheduledRetryAt = nil
        await flushQueue()
    }
}

final class OfflineAPIClient: APIClient {
    private let dataLayer: OfflineDataLayer

    init(dataLayer: OfflineDataLayer) {
        self.dataLayer = dataLayer
    }

    func request(endpoint: String, method: HTTPMethod, body: [String: JSONValue]?) async throws -> JSONValue {
        try await dataLayer.request(endpoint: endpoint, method: method, body: body)
    }
}

enum Timestamp {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static func now() -> String {
        formatter.string(from: Date())
    }

    static func date(from string: String) -> Date? {
        formatter.date(from: string)
    }
}
