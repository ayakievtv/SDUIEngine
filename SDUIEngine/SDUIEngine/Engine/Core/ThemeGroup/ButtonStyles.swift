

import SwiftUI



struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}


//MARK кнопка без привязки к ширине экрана
struct BtnBigFill: ButtonStyle {//big_fill
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .nabor_nabornyj_16()
//            .frame(width: UIScreen.main.bounds.width - 120)
            .frame(minWidth: 0, maxWidth: .infinity)
            .padding(.vertical, 16)
                  .padding(.horizontal, 32)
            .foregroundColor(configuration.isPressed ? .mon_seryj_80 : Color.nWhite)
            .padding(1)
          
            .overlay( RoundedRectangle(cornerRadius: 30)
                                    .stroke( isEnabled ? Color.per_sinij_40: .mon_seryj_80, lineWidth: 2)
                                    .shadow(color: .gray.opacity(0.5), radius: 10, x: 7, y: 7)
                            )
          
            .background(isEnabled ? Color.per_sinij_40 : .mon_seryj_80)
//            .shadow(color: .gray, radius: 2, x: 0, y: 2)
//            .shadow(color: .black.opacity(1), radius: 4, x: 0, y: 2)
            .cornerRadius(30)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct BtnBigStroke: ButtonStyle {//big_stroke
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .nabor_nabornyj_16()
//            .frame(width: UIScreen.main.bounds.width - 120)
            .frame(minWidth: 0, maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .foregroundColor(configuration.isPressed ? .mon_seryj_80 : isEnabled ? Color.per_sinij_40: .mon_seryj_80)
            .padding(1)
            .overlay( RoundedRectangle(cornerRadius: 30)
                                    .stroke( isEnabled ? Color.per_sinij_40: .mon_seryj_80, lineWidth: 2)
                            )
            .background(Color.nWhite )
            .cornerRadius(30)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}











struct BtnMidFill: ButtonStyle {//mid_fill
    @Environment(\.isEnabled) private var isEnabled

   
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .nabor_nabornyj_16()
//            .frame(width: UIScreen.main.bounds.width - 180)
            .frame(minWidth: 0, maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .foregroundColor(configuration.isPressed ? .mon_seryj_80 : Color.nWhite)
            .padding(1)
            .overlay( RoundedRectangle(cornerRadius: 25)
                                    .stroke( isEnabled ? Color.per_sinij_40: .mon_seryj_80, lineWidth: 2)
                                    .shadow(color: .gray, radius: 2, x: 0, y: 2)
                            )
            .background(isEnabled ? Color.per_sinij_40 : .mon_seryj_80)
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
    
}

struct BtnMidStroke: ButtonStyle {//mid_stroke
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .nabor_nabornyj_16()
//            .frame(width: UIScreen.main.bounds.width - 180)
            .frame(minWidth: 0, maxWidth: .infinity)
            .padding(.vertical, 10)
//            .padding(.horizontal, 32)
            .foregroundColor(configuration.isPressed ? .mon_seryj_80 : isEnabled ? Color.per_sinij_40: .mon_seryj_80)
            .padding(1)
            .overlay( RoundedRectangle(cornerRadius: 25)
                                    .stroke( isEnabled ? Color.per_sinij_40: .mon_seryj_80, lineWidth: 2)
                            )
            .background(Color.nWhite )
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}











struct BtnSmallFill: ButtonStyle {//small_fill
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .nabor_nabornyj_16()
            .padding(.vertical, 4)
            .padding(.horizontal, 24)
            .foregroundColor(configuration.isPressed ? .mon_seryj_80 : Color.nWhite)
            .padding(1)
//            .overlay( RoundedRectangle(cornerRadius: 20)
//                                    .stroke( isEnabled ? Color.per_sinij_40: .mon_seryj_80, lineWidth: 2)
//                                    .shadow(color: .gray, radius: 2, x: 0, y: 2)
//                            )
            .overlay( RoundedRectangle(cornerRadius: 20)
                                    .stroke( isEnabled ? Color.per_sinij_40: .mon_seryj_80, lineWidth: 2)
//                                    .shadow(color: .gray, radius: 2, x: 0, y: 2)
                            )

            .background(isEnabled ? Color.per_sinij_40 : .mon_seryj_80)
            .cornerRadius(15)
//            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}


struct BtnSmallStroke: ButtonStyle {//small_stroke
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .nabor_nabornyj_16()
            .padding(.vertical, 4)
            .padding(.horizontal, 24)
            .foregroundColor(configuration.isPressed ? .mon_seryj_40 : isEnabled ? Color.per_sinij_40: .mon_seryj_80)
            .padding(1)
            .overlay( RoundedRectangle(cornerRadius: 20)
                                    .stroke( isEnabled ? Color.per_sinij_40: .mon_seryj_80, lineWidth: 2)
                            )
            .background(Color.nWhite )
            .cornerRadius(15)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }

}


struct CircleButton: View {
    @State private var tapped = Bool()
    @State var img:String
    @Environment(\.isEnabled) private var isEnabled
    
    var action: () -> ()
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(isEnabled ? Color.per_sinij_40 : .mon_seryj_80)
                    .frame(width: 54, height: 54)
                    .shadow(color: .gray.opacity(0.5), radius: 10, x: 7, y: 7)
                Image(systemName: img)
                    .foregroundColor(Color.nWhite)
                    .font(.system(size: 16, weight: .semibold))
            }
            .scaleEffect(tapped ? 0.95 : 1)
            .onTapGesture {
              
                UIApplication.shared.endEditing()
                    tapped.toggle()
                    action()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        tapped = false
                                    }
             
            }
            
        }
    }
}
