import SwiftUI

// MARK: - Picker Option

private struct PickerOption: Identifiable, Equatable {
    let label: String
    let value: String
    var id: String { value }
}

// MARK: - Picker Component

struct PickerComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext
    private let stateKey: String
    private let optionsEndpoint: String?
    private let optionLabelField: String
    private let optionValueField: String

    @State private var selectedValue: String
    @State private var options: [PickerOption]
    @State private var isLoading = false

    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
        let key = model.resolvedProps.string("stateKey") ?? model.resolvedProps.string("bind") ?? model.id
        stateKey = key
        // к этому моменту @BASE_URL уже подставлен UIService.resolveVariables,
        // поэтому optionsEndpoint - готовый к использованию URL
        optionsEndpoint = model.resolvedProps.string("optionsEndpoint")
        optionLabelField = model.resolvedProps.string("optionLabelField") ?? "label"
        optionValueField = model.resolvedProps.string("optionValueField") ?? "value"

        _selectedValue = State(initialValue: context.stateValue(for: key)?.stringValue ?? "")

        let staticOptions: [PickerOption] = (model.resolvedProps["options"]?.arrayValue ?? []).compactMap { item in
            guard let obj = item.objectValue,
                  let label = obj.string("label"),
                  let value = obj.string("value") else { return nil }
            return PickerOption(label: label, value: value)
        }
        _options = State(initialValue: staticOptions)
    }

    var body: some View {
        let style = Style(props: model.resolvedProps)
        let placeholder = model.resolvedProps.string("placeholder") ?? ""

        let selectionBinding = Binding<String>(
            get: { selectedValue },
            set: { newValue in
                selectedValue = newValue
                context.setState(key: stateKey, value: .string(newValue))

                guard let event = model.event(for: .onChange) else { return }
                var params = event.params
                if params["value"] == nil {
                    params["value"] = .string(newValue)
                }
                context.trigger(EventModel(type: .onChange, targets: event.targets, params: params))
            }
        )

        return Picker(selection: selectionBinding, label: EmptyView()) {
            if selectedValue.isEmpty || !options.contains(where: { $0.value == selectedValue }) {
                Text(placeholder).tag("")
            }
            ForEach(options) { option in
                Text(option.label).tag(option.value)
            }
        }
        .pickerStyle(.navigationLink) //.navigationLink
        .disabled(isLoading)
        .task {
            await loadOptionsIfNeeded()
        }
        .onAppear {
            ComponentStore.shared.register(
                componentID: model.id,
                component: AnyComponent(actionHandler: { [context] action, params in
                    // params - [String: String]?, как и у TextFieldComponent
                    guard action.uppercased() == "SET_VALUE" || action.uppercased() == "SET_TEXT" else { return }
                    guard let value = params?["value"] ?? params?["text"] else { return }
                    selectedValue = value
                    context.setState(key: stateKey, value: .string(value))
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
            if let value = changedValue.stringValue {
                selectedValue = value
            } else if let number = changedValue.numberValue {
                selectedValue = String(number)
            } else {
                selectedValue = ""
            }
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

    // MARK: - Dynamic options loading

    @MainActor
    private func loadOptionsIfNeeded() async {
        guard let endpoint = optionsEndpoint, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await context.callAPI(endpoint: endpoint, method: .get, body: nil)
            guard
                let root = response.objectValue,
                let rows = root["report"]?.arrayValue
            else { return }

            options = rows.compactMap { row in
                guard let obj = row.objectValue,
                      let label = obj.string(optionLabelField),
                      let value = obj.string(optionValueField) else { return nil }
                return PickerOption(label: label, value: value)
            }
        } catch {
            // сетевые ошибки опций не блокируют отображение формы; список
            // останется пустым / со статическими options, если они были
        }
    }
}
