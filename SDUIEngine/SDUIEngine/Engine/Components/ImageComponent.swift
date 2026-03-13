import SwiftUI

struct ImageComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext

    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
    }

    var body: some View {
        let style = Style(props: model.props)
        return renderedImage().applyStyle(style, includeFontSize: false)
    }

    private func renderedImage() -> AnyView {
        let isResizable = model.props.bool("resizable") ?? true
        let contentMode: ContentMode = (model.props.string("contentMode")?.lowercased() == "fill") ? .fill : .fit

        if let urlString = model.props.string("url"), let url = URL(string: urlString) {
            return AnyView(
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        if isResizable {
                            image.resizable().aspectRatio(contentMode: contentMode)
                        } else {
                            image
                        }
                    case .failure:
                        Image(systemName: "photo").foregroundColor(.gray)
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
            )
        }

        if let systemName = model.props.string("systemName") {
            let image = Image(systemName: systemName)
            if isResizable {
                return AnyView(image.resizable().aspectRatio(contentMode: contentMode))
            }
            return AnyView(image)
        }

        if let name = model.props.string("name") {
            let image = Image(name)
            if isResizable {
                return AnyView(image.resizable().aspectRatio(contentMode: contentMode))
            }
            return AnyView(image)
        }

        return AnyView(Image(systemName: "photo").foregroundColor(.gray))
    }
}
