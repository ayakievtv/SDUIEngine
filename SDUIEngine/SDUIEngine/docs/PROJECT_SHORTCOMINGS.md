# SDUIEngine — список недостатков (полный аудит)

Дата аудита: 2026-03-18  
Покрытие: все `.md`, Swift-код (`Engine`, `Network`, `Screens`, `ContentView`) и JSON-экраны в `Resources`.
Принятый контракт событий: действия описываются в `params.actions` (одиночный `params.action` не считается обязательным форматом).

## 1. Критичные функциональные проблемы

1. `onTap` не прогоняет `dispatchComponentAction`, поэтому цепочки действий на тап могут не выполняться, если это не чистая навигация.  
   Файл: `Engine/Core/UIContext.swift:293-302`

2. Логика `dispatchComponentAction`/`dispatchToComponent` ошибочна: для каждого action выбирается `targetID`, но дальше `dispatchToComponent` снова итерирует весь массив `actions`, что приводит к повторным/неверным вызовам действий.  
   Файлы: `Engine/Core/UIContext.swift:333-345`, `Engine/Core/UIContext.swift:631-641`

3. Для `backend_data` используется только ветка `handleDataAction(action:params:[String:String])`; в ней отсутствует `DISCARD_FORM`, поэтому кнопка закрытия без сохранения фактически не работает.  
   Файл: `Engine/Core/UIContext.swift:378-395`

4. `performSaveForm(_ params: [String:String])` требует `formStatePrefix`, а JSON часто передает только `endpoint/method/idStateKey`; сохранение тихо не выполняется.  
   Файл: `Engine/Core/UIContext.swift:581-584`

5. В `DBGrid` plain-template ветка не рендерит данные: вычисленный `cached` не используется, вместо карточки всегда текст `"No row template"`.  
   Файл: `Engine/Components/DBGridComponent.swift:349-377`

6. Идентификация сущностей в offline-слое завязана только на `payload["id"]`; при реальных данных с `uuid` создаются новые случайные UUID и теряется стабильная связь записи между запросами.  
   Файл: `Engine/State/OfflineDataLayer.swift:112-114`

7. `invoice_edit_form.json` фактически содержит другой экран (`demo_screen2_root`) и сильный шум/случайные id, что ломает ожидаемый контракт маршрута формы.  
   Файл: `Resources/invoice_edit_form.json:2`

## 2. Высокие риски/архитектурные недостатки

1. `UIContext.swift` перегружен (state, event-dispatch, backend data actions, navigation, API) и содержит дублирующую/устаревшую логику (`performOpenFormOLD`, два `performSaveForm`, неиспользуемый `handleNavigationAction`).  
   Файл: `Engine/Core/UIContext.swift:499-579`, `581-704`

2. Сильная зашумленность `print`-логами debug-уровня в runtime-навигации и контексте, включая путь production-кода.  
   Файлы: `Engine/Core/UIContext.swift:295-300`, `Engine/State/NavigationEngine.swift:166-337`

3. Дефолт `UIService.useLocalScreens = true` полностью отключает backend-загрузку экранов в текущем состоянии (даже при готовом base URL).  
   Файл: `Network/UIService.swift:25`, ветка `if Self.useLocalScreens || Self.isDebugBuild` на `51`

4. `ScrollViewComponent` читает `showsIndicators`, но не применяет его к `ScrollView`; также одновременно рендерит собственный header и ставит `navigationTitle`, создавая дубль заголовков.  
   Файл: `Engine/Layout/ScrollViewComponent.swift:15`, `19-33`, `43`

5. `TextComponent` насильно красит текст в черный (`foregroundColor(.black)`), ломая color-props и dark mode.  
   Файл: `Engine/Components/TextComponent.swift:47`, `61`

6. `HStackComponent` игнорирует `spacing` prop (в отличие от `VStack`), поведение несогласованно.  
   Файлы: `Engine/Layout/HStackComponent.swift:15`, `Engine/Layout/VStackComponent.swift:14`

7. В `TabBarComponent` регистрация в `ComponentStore` есть, а `unregister` на `onDisappear` отсутствует (риск утечек/висячих обработчиков).  
   Файл: `Engine/Components/TabBarComponent.swift:42-50`

8. Комментарий в `ContentView` противоречит коду: стоит `TODO: Add TabBarComponent.swift to Xcode project`, но компонент уже регистрируется.  
   Файл: `ContentView.swift:161-162`

9. `DBGrid` prefetch-логика не использует `threshold` по назначению (переменная вычисляется, но в условии не участвует).  
    Файл: `Engine/Components/DBGridComponent.swift:283-285`

10. В `DBGrid` удалено кэширование resolved row component (раньше декларировалось), теперь каждый ряд пересобирается.  
    Файл: `Engine/Components/DBGridComponent.swift:468-470`

## 3. Проблемы offline/data-слоя

1. `EntityStore.clear()` очищает только память, но не сохраняет очистку на диск; при рестарте возможен возврат старых данных.  
   Файл: `Engine/State/OfflineDataLayer.swift:158-160`

2. `loadFromDisk()` вызывается в `init` через `Task { ... }` у нескольких сторов; есть race между первым использованием и завершением загрузки кеша.  
   Файлы: `EntityStore` `84-86`, `SyncQueueStore` `296-298`, `LocalResponseStore` `356-358`

3. `flushQueue()` останавливается на первой ошибке без backoff/лимита/next-scheduling механизма; при долгом офлайне очередь может «залипать».  
   Файл: `Engine/State/OfflineDataLayer.swift:570-592`

4. `parseGridResponse` в offline-слое поддерживает только `items` + ограниченный fallback; контракт с произвольными path (`itemsPath/nextCursorPath`) отсутствует.  
   Файл: `Engine/State/OfflineDataLayer.swift:640-664`

5. `saveActiveForm` помечает draft queued и сразу очищает его, не оставляя возможности локального повторного редактирования при ошибках синка.  
   Файл: `Engine/State/OfflineDataLayer.swift:560-563`

## 4. Недостатки JSON-ресурсов

1. В `main.json` есть мусорный id `_root_scwqwqroll`; ухудшает поддерживаемость и трассировку.  
   Файл: `Resources/main.json:10`

2. В `main.json` у нескольких кнопок присутствует пустой `children: []` (шум в контракте).  
   Файл: `Resources/main.json:48-50`, `73-75`, `98-100`

3. `invoice_edit_form.json` содержит дубли props (`multilineTextAlignment` задан дважды) и трудно читаемые случайные id (`invgsdsp`, `demfser1` и т.п.).  
   Файл: `Resources/invoice_edit_form.json:169-170` и по файлу

4. `tabbar_demo.json` использует несовместимый формат события кнопки (`action/target` вне `params.actions`), и `target:"invoices_grid"` трактуется как target-компонент, а не route-навигация.  
   Файл: `Resources/tabbar_demo.json:75-78`

5. `invoices_grid.json` кладет `DataSource` ниже `DBGrid`; это компенсируется retry-костылем в коде, но архитектурно это порядок-зависимый анти-паттерн.  
   Файл: `Resources/invoices_grid.json:21-181` (grid раньше datasource)

## 5. Разрыв документации и реализации

1. `COMPONENT_PROPS.md` описывает props, которых нет в коде (`rowMode`, `rowTemplate`, `refreshable`, `loadMoreEnabled`, `showFilter`, `filterPlaceholder`).  
   Файл: `docs/COMPONENT_PROPS.md:121-126`

2. README заявляет «adaptive colors / dark mode support», но `TextComponent` принудительно красит текст в black.  
   Файлы: `README.md:18`, `Engine/Components/TextComponent.swift:47,61`

3. README и `WORK_CONTEXT.md` содержат устаревшие архитектурные утверждения (например, «все исправлено/полностью функционально»), не подтверждаемые текущим состоянием кода/JSON.  
   Файлы: `README.md`, `docs/WORK_CONTEXT.md`

## 6. Качество кода и поддерживаемость

1. Смешение языков комментариев (русский/английский) в критичных модулях повышает когнитивную нагрузку команды.  
   Пример: `Engine/Core/UIContext.swift`

2. `UIContext` содержит несколько слоев ответственности без модульных границ (нет отдельных файлов для backend actions/event chain/nav bridge).  
   Файл: `Engine/Core/UIContext.swift`

3. Нет единого механизма логирования (вместо этого прямые `print`), нет уровней логов/фич-флагов.  
   Файлы: `Engine/Core/UIContext.swift`, `Engine/State/NavigationEngine.swift`, `Network/UIService.swift`

4. Часть комментариев и `TODO` уже недостоверны, что снижает доверие к коду как к источнику истины.  
   Файл: `ContentView.swift:161`

## 7. Тестовое покрытие и проверяемость

1. В проекте нет unit/integration тестов для критичных путей:
   - event-dispatch и action-chain,
   - OPEN_FORM/SAVE_FORM/DISCARD_FORM,
   - DBGrid parsing/interpolation,
   - Offline queue retries/conflict behavior.

2. Нет контрактных тестов для JSON-схем экранов (`Resources/*.json`), поэтому неконсистентные структуры попадают в mainline.

---

## Краткий вывод

Система функционально богата, но сейчас основной долг — в консистентности runtime-логики (`UIContext`/`DBGrid`), целостности offline identity (`id` vs `uuid`), качестве JSON-контрактов и синхронизации документации с фактическим кодом. Без закрытия этих пунктов риск регрессий и «ложноположительной стабильности» остается высоким.
