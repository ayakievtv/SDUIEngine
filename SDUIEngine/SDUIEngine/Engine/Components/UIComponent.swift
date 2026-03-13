import SwiftUI

protocol UIComponent: View {
    init(model: ComponentModel, context: UIContext)
}
