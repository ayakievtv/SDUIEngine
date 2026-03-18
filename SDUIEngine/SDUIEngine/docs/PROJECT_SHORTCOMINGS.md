# SDUIEngine — список недостатков (полный аудит)

Дата аудита: 2026-03-18  
Покрытие: все `.md`, Swift-код (`Engine`, `Network`, `Screens`, `ContentView`) и JSON-экраны в `Resources`.
Принятый контракт событий: действия описываются в `params.actions` (одиночный `params.action` не считается обязательным форматом).

## 1. Критичные функциональные проблемы

1. В `DBGrid` plain-template ветка не рендерит данные: вычисленный `cached` не используется, вместо карточки всегда текст `"No row template"`.  
   Файл: `Engine/Components/DBGridComponent.swift:349-377`

2. `invoice_edit_form.json` содержит сильный шум/случайные id, что ломает читаемость и поддерживаемость формы.  
   Файл: `Resources/invoice_edit_form.json`

## 2. Высокие риски/архитектурные недостатки

1. `UIContext.swift` перегружен (state, event-dispatch, backend data actions, navigation, API) и содержит дублирующую/устаревшую логику (`performOpenFormOLD`, два `performSaveForm`, неиспользуемый `handleNavigationAction`).  
   Файл: `Engine/Core/UIContext.swift:499-579`, `581-704`

2. Сильная зашумленность `print`-логами debug-уровня в runtime-навигации и контексте, включая путь production-кода.  
   Файлы: `Engine/Core/UIContext.swift:295-300`, `Engine/State/NavigationEngine.swift:166-337`

3. Дефолт `UIService.useLocalScreens = true` полностью отключает backend-загрузку экранов в текущем состоянии (даже при готовом base URL).  
   Файл: `Network/UIService.swift:25`, ветка `if Self.useLocalScreens || Self.isDebugBuild` на `51`

## 3. Проблемы offline/data-слоя

Открытых пунктов нет.

## 4. Недостатки JSON-ресурсов

Открытых пунктов нет.

## 5. Разрыв документации и реализации

1. `COMPONENT_PROPS.md` описывает props, которых нет в коде (`rowMode`, `rowTemplate`, `refreshable`, `loadMoreEnabled`, `showFilter`, `filterPlaceholder`).  
   Файл: `docs/COMPONENT_PROPS.md:121-126`

2. README и `WORK_CONTEXT.md` содержат устаревшие архитектурные утверждения (например, «все исправлено/полностью функционально»), не подтверждаемые текущим состоянием кода/JSON.  
   Файлы: `README.md`, `docs/WORK_CONTEXT.md`

## 6. Качество кода и поддерживаемость

1. Смешение языков комментариев (русский/английский) в критичных модулях повышает когнитивную нагрузку команды.  
   Пример: `Engine/Core/UIContext.swift`

2. `UIContext` содержит несколько слоев ответственности без модульных границ (нет отдельных файлов для backend actions/event chain/nav bridge).  
   Файл: `Engine/Core/UIContext.swift`

3. Нет единого механизма логирования (вместо этого прямые `print`), нет уровней логов/фич-флагов.  
   Файлы: `Engine/Core/UIContext.swift`, `Engine/State/NavigationEngine.swift`, `Network/UIService.swift`

## 7. Тестовое покрытие и проверяемость

1. В проекте нет unit/integration тестов для критичных путей:
   - event-dispatch и action-chain,
   - OPEN_FORM/SAVE_FORM/DISCARD_FORM,
   - DBGrid parsing/interpolation,
   - Offline queue retries/conflict behavior.

2. Нет контрактных тестов для JSON-схем экранов (`Resources/*.json`), поэтому неконсистентные структуры попадают в mainline.

---

## Краткий вывод

Система функционально богата, но сейчас основной долг — в консистентности runtime-логики (`UIContext`/`DBGrid`), качестве JSON-контрактов и синхронизации документации с фактическим кодом. Без закрытия этих пунктов риск регрессий и «ложноположительной стабильности» остается высоким.
