import SwiftUI

/// Dispatches both local UI events and backend dynamic actions
final class EventDispatcher: EventDispatching {
    private var handlers: [EventType: EventHandler] = [:]
    private let componentStore: ComponentStore
    private let paramResolver: ParamResolver

    init(
        componentStore: ComponentStore = .shared,
        paramResolver: ParamResolver = ParamResolver()
    ) {
        self.componentStore = componentStore
        self.paramResolver = paramResolver
    }

    func register(_ type: EventType, handler: @escaping EventHandler) {
        handlers[type] = handler
    }

    func dispatch(_ event: EventModel, context: UIContext) {
        handlers[event.type]?(event, context)
    }

    /// Executes one dynamic action if trigger matches current lifecycle/user trigger
    func dispatch(_ componentEvent: ComponentEvent, for trigger: ComponentEventTrigger? = nil) {
        if let trigger, componentEvent.trigger != trigger.rawValue {
            return
        }

        let resolvedParams = paramResolver.resolve(params: componentEvent.params)
        for targetID in componentEvent.targets {
            componentStore.get(componentID: targetID)?.handle(action: componentEvent.action, params: resolvedParams)
        }
    }

    /// Executes all actions for a given trigger
    func dispatch(events: [ComponentEvent], for trigger: ComponentEventTrigger) {
        events.forEach { dispatch($0, for: trigger) }
    }
}
