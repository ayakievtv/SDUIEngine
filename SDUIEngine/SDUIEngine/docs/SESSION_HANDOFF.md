# Session Handoff (For Next Day)

## Latest update (2026-03-18)

1. Test infrastructure finalized:
- Xcode unit-test target `SDUIEngineTests` added and wired to `SDUIEngine`.
2. Critical runtime tests added/updated:
- event chain dispatch,
- backend form actions (`OPEN_FORM`, `SAVE_FORM`, `DISCARD_FORM`),
- DBGrid parsing + interpolation,
- offline queue retry/backoff behavior.
3. Flaky behavior in offline queue tests fixed:
- replaced strict timing assumptions with async polling,
- added queue cleanup at test start to isolate persisted state between runs.
4. Validation completed:
- full `xcodebuild test` green (8 tests passed),
- app builds and launches in iOS Simulator from CLI.
5. Last pushed commit:
- `f2c0c0e` on `main`.

## What was built

1. Event system improvements
- Added support for event `targets` (array), with backward compatibility for single `target`.
- Added support for multi-action events via `params.actions`.

2. New demo screen
- Added `demo_screen2.json` and navigation from `main.json`.
- Demo chain implemented:
  - button -> updates first text field
  - first text field `onChange` -> updates second field
- Fixed `TextField` behavior so JSON-defined `params.value` is not overwritten by default onChange value.

3. Offline-first data layer
- Implemented `OfflineDataLayer.swift` with:
  - `EntityStore`, `QueryStore`, `FormDraftStore`, `SyncQueueStore`, `LocalResponseStore`
  - GET: network-first with local fallback
  - POST/PUT: queue-first with optimistic local update and background flush
- Integrated into runtime via default API client in `UIContext`.

4. New SDUI components
- Added `DataSourceComponent`:
  - registers datasource config in runtime registry
  - default values for filter/sort/paging behavior
- Added `DBGridComponent`:
  - datasource binding (`dataSourceId`)
  - local + remote filtering (debounced)
  - sorting
  - load more + prefetch threshold
  - row tap event forwarding
  - row rendering modes:
    - simple row template (`row`)
    - full `rowComponent` tree (`Text/HStack/VStack/...`)

5. Invoices demos
- Added `invoices_grid.json` (DBGrid + DataSource) for:
  - `https://oracleapex.com/ords/yakiev/sdui_example/invoices`
- Added `invoice_edit_form.json` for edit form flows
- Added navigation from `main.json` to invoices grid

6. Performance improvements
- `LazyVStack` rendering
- row template caching
- row component model caching
- equatable card content
- reduced repeated template parsing via state caching

7. Data binding robustness fixes
- key matching now tolerates:
  - case differences (`field` vs `FIELD`)
  - naming style differences (`invoice_no`, `invoiceNo`, `INVOICENO`)
- supports dot-paths (`a.b.c`)
- recursive nested value search
- row wrapper merge (`row`, `data`, `value`, `record`, `item`)

## Critical bugfixes done during session

1. MainActor init error
- `DataSourceRegistry` was `@MainActor` and used as default argument in `UIContext.init`.
- Removed `@MainActor` from registry to avoid nonisolated default-init call error.

2. Swift type-check timeout
- Broke large `??` chain for row id into incremental candidate resolution loop.

3. DataSource registration race
- `EmptyView` could skip `onAppear` in practice.
- switched DataSource render to `Color.clear.frame(height: 0)` for reliable appear registration.

4. Placeholder interpolation bug (root cause of empty cards)
- old regex interpolation failed; replaced with reliable manual parser for `{{...}}`.
- this enabled actual data substitution in row templates and rowComponent trees.

## Known environment issue during validation

- External endpoint sometimes returned Oracle error HTML instead of JSON.
- In such moments grid fetch succeeds at transport level but payload is not usable as list data.
- When endpoint returns proper JSON (`items` array), mapping should work.

## Expected server row shape used for mapping

Example row fields:
- `uuid`
- `doc_number`
- `doc_date`
- `customer_name`
- `amount`
- `currency`
- `status`
- `description`
- `updated_at`

Grid JSON was updated to this schema (`keyField = uuid`, card and columns use `doc_number/doc_date/...`).

## Suggested next steps

1. Add explicit payload-shape diagnostics in DBGrid
- if payload is HTML / malformed JSON, show user-friendly error text in grid state.

2. Add API response mapping config in DataSource
- props like `itemsPath`, `nextCursorPath`, `hasMorePath` to avoid hardcoded assumptions.

3. Add unit tests for
- placeholder interpolation
- key normalization lookup
- nested path resolution
- row wrapper merge
- datasource registration timing

4. Add offline queue policy controls
- retry limit/backoff strategy
- conflict strategy (`last-write-wins` vs merge)
