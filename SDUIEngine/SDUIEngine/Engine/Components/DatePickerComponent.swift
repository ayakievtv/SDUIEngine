import SwiftUI

// MARK: - DatePicker Component

struct DatePickerComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext
    private let stateKey: String
    @State private var selectedDate: Date

    // ISO8601 с дробными секундами не предполагается (формат "...Z" без миллисекунд,
    // как в примере "2026-09-17T18:40:49Z") - используем withInternetDateTime без
    // fractionalSeconds, иначе парсинг строк без миллисекунд будет падать
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
        let key = model.resolvedProps.string("stateKey") ?? model.resolvedProps.string("bind") ?? model.id
        stateKey = key

        let initialString = context.stateValue(for: key)?.stringValue
        let initialDate = initialString.flatMap { Self.isoFormatter.date(from: $0) } ?? Date()
        _selectedDate = State(initialValue: initialDate)
    }

    var body: some View {
        let style = Style(props: model.resolvedProps)
        let label = model.resolvedProps.string("label") ?? model.resolvedProps.string("placeholder") ?? ""

        // displayMode: "date" | "time" | "dateAndTime" (дефолт - только дата,
        // т.к. большинство форм-примеров используют поле как "Document Date")
        let displayModeRaw = model.resolvedProps.string("displayMode") ?? "date"
        let components: DatePickerComponents = {
            switch displayModeRaw {
            case "time": return .hourAndMinute
            case "dateAndTime": return [.date, .hourAndMinute]
            default: return .date
            }
        }()

        let dateBinding = Binding<Date>(
            get: { selectedDate },
            set: { newValue in
                selectedDate = newValue
                let isoString = Self.isoFormatter.string(from: newValue)
                context.setState(key: stateKey, value: .string(isoString))

                guard let event = model.event(for: .onChange) else { return }
                var params = event.params
                if params["value"] == nil {
                    params["value"] = .string(isoString)
                }
                context.trigger(EventModel(type: .onChange, targets: event.targets, params: params))
            }
        )

        return DatePicker(label, selection: dateBinding, displayedComponents: components)
            .labelsHidden()
            .onAppear {
                ComponentStore.shared.register(
                    componentID: model.id,
                    component: AnyComponent(actionHandler: { [context] action, params in
                        guard action.uppercased() == "SET_DATE" || action.uppercased() == "SET_TEXT" else { return }
                        guard let raw = params?["value"] ?? params?["date"] ?? params?["text"],
                              let parsed = Self.isoFormatter.date(from: raw)
                        else { return }
                        selectedDate = parsed
                        context.setState(key: stateKey, value: .string(raw))
                    })
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .sduiStateDidChange)) { note in
                guard
                    let changedKey = note.userInfo?["key"] as? String,
                    changedKey == stateKey,
                    let changedValue = note.userInfo?["value"] as? JSONValue,
                    let str = changedValue.stringValue,
                    let parsed = Self.isoFormatter.date(from: str)
                else {
                    return
                }
                selectedDate = parsed
            }
            .onDisappear {
                ComponentStore.shared.unregister(componentID: model.id)
            }
            .applyStyle(style)
            .overlay(
                Rectangle()
                    .fill(Color.appgray)
                    .frame(height: 1),
                alignment: .bottom
            )
    }
}
