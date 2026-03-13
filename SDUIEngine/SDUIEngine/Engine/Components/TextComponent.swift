import SwiftUI

struct TextComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext

    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
    }

    var body: some View {
        let style = Style(props: model.props)
        let value = model.props.string("text") ?? ""
        return Text(value).applyStyle(style)
    }
}
