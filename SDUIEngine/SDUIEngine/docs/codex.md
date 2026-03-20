# SDUIEngine Architecture (Detailed)

## 1) Purpose and Design Goals

SDUIEngine is a SwiftUI-based Server-Driven UI runtime. The backend controls screen structure and behavior via JSON, while the app renders components dynamically and executes event contracts.

Primary goals:
1. Render UI from JSON without shipping new app builds for each UI change.
2. Keep interactions declarative (events/actions in JSON).
3. Support data-heavy screens (grid + forms) with offline-first behavior.
4. Make navigation backend-driven.
5. Keep runtime resilient to partial failures (network unavailability, payload variance).

---

## 2) High-Level Architecture

Runtime layers:
1. Screen loading layer (`UIService`): loads screen JSON by route name.
2. Rendering layer (`ComponentRenderer` + component registry): maps JSON `type` to SwiftUI view.
3. Interaction layer (`EventModel` + `UIContext` dispatcher): executes actions/events.
4. Data layer (`OfflineDataLayer`): GET fallback cache + queued writes.
5. Navigation layer (`NavigationEngine`): resolves backend navigation actions.

Data flow (simplified):
1. Route opened -> `UIService` loads JSON.
2. `ComponentRenderer` recursively renders the component tree.
3. User input triggers component event (`onTap`, `onChange`, `onSubmit`).
4. `UIContext` dispatches component-to-component actions and navigation.
5. API calls go through offline data layer.

---

## 3) Project Structure and Responsibilities

### Root app
- `ContentView.swift`
  - Creates shared `UIContext` and `NavigationRouter`.
  - Registers built-in and custom component types.
  - Hosts `NavigationStack` and destination resolver.
- `ScreenView.swift`
  - Loads JSON screen by route name and renders root component.
- `UIService.swift`
  - Loads screen JSON from local resource fallback (current mode) and supports backend path.

### Core runtime
- `Engine/Core/ComponentModel.swift`
  - Canonical node for SDUI tree (`id`, `type`, `props`, `events`, `children`).
- `Engine/Core/JSONValue.swift`
  - Dynamic value enum used across props/events payloads.
- `Engine/Core/UIContext.swift`
  - Runtime context: state store, event dispatcher, navigation, API client.
  - Contains component-to-component action dispatch logic.

### Events
- `Engine/Events/EventModel.swift`
  - Event type system and parsing from JSON.
  - Supports both single `target` and multi `targets`.

### Navigation
- `Engine/State/NavigationEngine.swift`
  - Interprets backend action payloads into push/replace/pop behavior.

### Offline data system
- `Engine/State/OfflineDataLayer.swift`
  - Implements hybrid store model and offline policies.
- `Engine/State/DataSourceRegistry.swift`
  - Runtime registry for `DataSource` component configurations used by `DBGrid`.

### Components
- **UI Primitives**: `Text`, `Button`, `TextField`, `Image`, `Spacer`
- **Layout Containers**: `VStack`, `HStack`, `ScrollView` with spacing and alignment
- **Data Components**:
  - `DataSourceComponent.swift` - API integration with offline policies
  - `DBGridComponent.swift` - Data grids with caching, pagination, filtering
- **Navigation**: `TabBarComponent.swift` - SDUI tab navigation

### Layout Components
- `Engine/Layout/VStackComponent.swift` - Vertical container with spacing
- `Engine/Layout/HStackComponent.swift` - Horizontal container with spacing  
- `Engine/Layout/ScrollViewComponent.swift` - Scrollable container with navigation title

---

## 4) Event Contract and Behavior

Supported triggers:
- `onTap`
- `onChange`
- `onSubmit`
- lifecycle (`onAppear`, `onDisappear`)

### 4.1 Targeting
1. Single target:
```json
{"target":"title_text"}
```
2. Multiple targets:
```json
{"targets":["title_text","subtitle_text"]}
```

### 4.2 Multi-action event
A single event can execute several actions sequentially:
```json
{
  "params": {
    "actions": [
      {"action":"SET_TEXT","value":"Hello"},
      {"action":"SET_COLOR","value":"#2563EB"}
    ]
  }
}
```

### 4.3 Implemented compatibility decisions
1. `target` and `targets` are both accepted.
2. If `targets` present and non-empty, they are used.
3. If only `target` is present, runtime wraps it into a single-item `targets` list.
4. Existing JSON contracts remain valid (backward compatible).

---

## 5) Hybrid Data Architecture (Implemented)

Model: `Query + Entity Store + Form Draft` with a sync queue.

### 5.1 EntityStore
Purpose:
- Normalized record storage by UUID.

Core fields per entity record:
- `id`
- `createdAt`
- `updatedAt`
- `clientUpdatedAt`
- `syncState`
- `data` (full payload)

### 5.2 QueryStore
Purpose:
- Read-only datasets for list/grid queries.

Stores:
- `ids`
- `nextCursor`
- `hasMore`
- `filterText`
- `sort`
- `status`
- `updatedAt`

### 5.3 FormDraftStore
Purpose:
- Ephemeral active form only.

Rules (implemented decision):
1. Opening new form clears previous draft.
2. Unsaved close clears draft.
3. Historical forms are not retained in memory.

### 5.4 SyncQueueStore
Purpose:
- Queue pending writes (`POST`/`PUT`) for offline-safe save behavior.

Operation statuses:
- `queued`
- `syncing`
- `failed`
- `acked`
- `conflict`

### 5.5 LocalResponseStore
Purpose:
- Endpoint-local GET fallback cache.

---

## 6) Offline Policies (Implemented)

### 6.1 GET: NetworkFirst + LocalFallback
1. Try remote request first.
2. On success:
- cache response locally,
- ingest entities.
3. On failure:
- return cached response if exists.
4. If no cache:
- propagate error.

### 6.2 POST/PUT: QueueFirst
1. Save is queued first.
2. Optimistic local entity update is applied.
3. Background flush attempts server sync.
4. Success removes operation from queue.
5. Failure marks operation `failed` for retry.

---

## 7) DataSource + DBGrid Architecture

## 7.1 DataSource component
`DataSource` is a non-visual config node. It registers config in `DataSourceRegistry` on appear.

Important implementation detail:
- It uses `Color.clear.frame(height: 0)` instead of `EmptyView` to ensure `onAppear` is reliably triggered.

Key props:
- `id`
- `endpoint`
- `pageSize`
- `queryParam`
- `cursorParam`
- `keyField`

Defaults (if omitted):
- `fetchPolicy = NETWORK_FIRST_LOCAL_FALLBACK`
- `pageSize = 25`
- `queryParam = q`
- `cursorParam = offset`
- `localFiltering = true`
- `remoteFiltering = true`
- `debounceMs = 450`
- `sorting = false`
- `prefetchThreshold = 3`
- `keyField = id`

## 7.2 DBGrid component
`DBGrid` binds to `DataSource` by `dataSourceId`.

Capabilities implemented:
1. Initial load.
2. Manual reload.
3. Load more + prefetch threshold.
4. Local filtering.
5. Debounced remote filtering.
6. Local sorting.
7. Row tap -> event forwarding.

### 7.3 Row rendering modes
1. Simple template mode (`row` object):
- `title/subtitle/caption/badge` with `{{field}}` placeholders.

2. Full component mode (`rowComponent`):
- full nested UI tree using SDUI components (`VStack`, `HStack`, `Text`, etc.)
- placeholders are resolved in props/events recursively.

---

## 8) Performance Decisions (Implemented)

1. `LazyVStack` for row rendering.
2. Row text template cache (`NSCache`) to avoid repeated placeholder materialization.
3. Row component cache (resolved `ComponentModel` per row/version).
4. `Equatable` plain card content to reduce unnecessary body recomputation.
5. Row template parsing moved out of repeated path into state-backed initialization flow.
6. DataSource resolution retry in grid init to avoid startup race (DataSource may appear after DBGrid).
7. Global JSON-driven performance modifiers are supported on all components:
- `drawingGroup`
- `compositingGroup`
- `fixedSizeHorizontal`
- `fixedSizeVertical`
8. Performance modifiers are applied in `ComponentRenderer` via `applyPerformanceProps`, so the same JSON contract works for primitive components and nested `rowComponent` trees.

---

## 9) Data Binding Robustness (Implemented)

To handle inconsistent backend key naming:
1. Case-insensitive lookup.
2. Normalized-key lookup (`snake_case`, `camelCase`, uppercase variants).
3. Dot-path lookup (`a.b.c`).
4. Recursive lookup through nested objects/arrays.
5. Row wrapper merge for common envelopes (`row`, `data`, `value`, `record`, `item`).
6. Placeholder interpolation for `{{...}}` is implemented with deterministic manual parsing (not regex), for both simple row templates and `rowComponent` props/events resolution.

This was added because list payloads may vary between environments and wrappers.

---

## 10) Invoices Demo Contract

Endpoint:
- `https://oracleapex.com/ords/yakiev/sdui_example/invoices`

Observed row fields:
- `uuid`
- `doc_number`
- `doc_date`
- `customer_name`
- `amount`
- `currency`
- `status`
- `description`
- `updated_at`

Current mapping in demo grid:
- key field: `uuid`
- row card fields: `doc_number`, `customer_name`, `amount`, `currency`, `doc_date`, `description`, `status`

Screens:
- `Resources/invoices_grid.json`
- `Resources/invoice_edit_form.json`

---

## 11) Known Operational Risks / Constraints

1. Remote endpoint may intermittently return HTML error page instead of JSON.
- In this case grid transport succeeds but data mapping has no valid items.

2. Current grid parser expects list data in either:
- root `items` array,
- or direct object/array fallback.

3. Full offline queue conflict strategy is basic currently.
- Next phase can add explicit conflict-resolution policy and stronger retry/backoff controls.

---

## 12) Why These Decisions Were Chosen

1. Backward compatibility for events (`target` + `targets`) avoids breaking existing JSON.
2. Queue-first saves match offline-first requirement and future sync layer.
3. Ephemeral form draft matches requirement to drop unsaved forms on close.
4. DataSource+DBGrid split separates data acquisition config from rendering logic.
5. RowComponent mode provides visual flexibility while preserving SDUI composition.
6. Extra key/path robustness reduces fragility against backend shape drift.

---

## 13) Current Demo Coverage

1. Core SDUI behavior: `main.json`, `demo_screen.json`, `demo_screen2.json`.
2. Data source + grid + cards: `invoices_grid.json`.
3. Edit form contract: `invoice_edit_form.json`.
4. Offline data runtime present in code and wired as default API path.

---

## 14) Latest Completed Work (2026-03-18)

1. Added automated test target `SDUIEngineTests` in Xcode project and connected it to host app target.
2. Added/updated critical tests:
- `UIContextEventDispatchTests`
- `UIContextBackendDataTests`
- `DBGridParsingInterpolationTests`
- `OfflineQueueBehaviorTests`
3. Stabilized offline queue tests:
- removed race assumptions around scheduled flush behavior,
- added polling-based waits for async state transitions,
- ensured test isolation by clearing persisted sync queue state at test start.
4. Verified full test run is green (8/8).
5. Verified app build and simulator launch from CLI:
- build: `xcodebuild build ... -scheme SDUIEngine`,
- launch: `xcrun simctl launch ... com.example.SDUIEngine`.
6. Changes were committed and pushed to `origin/main`:
- commit: `f2c0c0e`
- message: `Stabilize test suite and finalize offline queue behavior`.
