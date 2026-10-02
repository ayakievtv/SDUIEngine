
import SwiftUI

extension Color {
//----------------- Цвета -----------------
static let nWhite=Color(hex:"#FFFFFF")


//----- монохромная гамма:monohromnaa_gamma -----

static let mon_seryj_80=Color(hex:"#c6cbd2")
static let mon_seryj_20=Color(hex:"#2d3239")
static let mon_seryj_95=Color(hex:"#f1f2f4")
static let mon_seryj_60=Color(hex:"#8d97a5")
static let mon_belyj=Color(hex:"#ffffffff")
static let mon_seryj_40=Color(hex:"#5a6472")
static let mon_seryj_90=Color(hex:"#e2e5e9")
static let mon_cernyj=Color(hex:"#181818")

//----- первичный цвет:pervicnyj_cvet -----

static let per_sinij_30=Color(hex:"#1f3e7a")
static let per_sinij_60=Color(hex:"#5d86d5")
static let per_sinij_50=Color(hex:"#3468cb")
static let per_sinij_40=Color(hex:"#2a53a2")

//----- вторичный цвет:vtoricnyj_cvet -----

static let vto_krasnyj_70=Color(hex:"#f77b6eff")
static let vto_krasnyj_40=Color(hex:"#c11c0bff")
static let vto_krasnyj_50=Color(hex:"#f2230dff")

//----- системные цвета:sistemnye_cveta -----

static let sis_oranzevyj_50=Color(hex:"#ffa100ff")
static let sis_krasnyj_50=Color(hex:"#f2230dff")
static let sis_zelenyj_50=Color(hex:"#34cb55ff")

//----- дополнительные цвета:dopolnitelʹnye_cveta -----

static let dop_goluboj_50=Color(hex:"#00d4ffff")
static let dop_fioletovyj_50=Color(hex:"#7705faff")
}


//----------------- Шрифты -----------------


extension View {

func nabor_nabornyj_20() -> some View {
self.font(Font.custom("MullerRegular.ttf",size:20))
}

func nabor_nabornyj_16() -> some View {
self.font(Font.custom("MullerRegular.ttf",size:16))
}

func nabor_nabornyj_14() -> some View {
self.font(Font.custom("MullerRegular.ttf",size:14))
}

func zagol_zagolovok_3() -> some View {
self.font(Font.custom("MullerRegular.ttf",size:20))
}

func zagol_zagolovok_1() -> some View {
self.font(Font.custom("MullerRegular.ttf",size:32))
}

func zagol_zagolovok_2() -> some View {
self.font(Font.custom("MullerRegular.ttf",size:24))
}

func dokum_zagolovok_2() -> some View {
self.font(Font.custom("MullerRegular.ttf",size:64))
}

func dokum_zagolovok_1() -> some View {
self.font(Font.custom("MullerRegular.ttf",size:96))
}

func dokum_propisnoj() -> some View {
self.font(Font.custom("MullerRegular.ttf",size:32))
}

func dokum_zagolovok_3() -> some View {
self.font(Font.custom("MullerRegular.ttf",size:32))
}

}

extension Color {
    static let appmain = Color(hex:"#2A53A2")//Color(red: 1, green: 0.44, blue: 0.42)
    static let appBack = Color(hex:"#E9E9EE")
    static let buttonMain = Color(hex:"#2A53A2")
    static let buttonBcg = Color(hex:"#B8BEE0")
    static let buttonDis = Color(hex:"#CECECF")//#7A9ECF //DADEF1
    static let buttonDisForg = Color(hex:"#5966A6")
    static let buttonSmall = Color(hex:"#F2F1FE")
    static let buttonSmallForg = Color(hex:"#2A53A2")
    static let appprimary = Color(hex:"#3468CB")
    static let appbluedark = Color(hex:"#12213F")
    static let appGreen = Color(red: 0.49, green: 0.75, blue: 0.56) // #7DBF8F
    static let appGreenDark = Color(red: 0.2, green: 0.5, blue: 0.2) // #7DBF8F
    static let appOrange = Color(red: 0.9, green: 0.56, blue: 0.2) //  #E48F34
    static let brown = Color(hex:"#FFF8DC")
    static let appTitle = Color(red: 0, green: 0, blue: 0)
    static let appFileldHeader = Color(red: 0.6, green: 0.6, blue: 0.6)
    static let appblue = Color(hex:"#2A53A2")  //#c1c6ce
    static let appwhite = Color(hex:"#EEEEEE")
    static let appgray = Color(hex:"#D6D6D6")//Color(red: 0.84, green: 0.84, blue: 0.84)
    static let appgray1 = Color(hex:"#E5E5E5")//Color(red: 0.9, green: 0.9, blue: 0.9)
    static let appgray2 = Color(hex:"#F4F4F4")//Color(red: 0.96, green: 0.96, blue: 0.96)
    static let appgrayRect = Color(hex:"#F0F2F9")
    static let appgrayback = Color(hex:"#E2E5E9")  //#c1c6ce
    static let appgraytext0 = Color(hex:"#242942")
    static let appgraytext = Color(hex:"#323B67")//Color(hex:"#475285")
    static let appgraytext1 = Color(hex:"#475285")//Color(hex:"#475285")
    static let appgraytext2 = Color(hex:"#7581BD")
    static let appbrown = Color(red: 0.898, green: 0.561, blue: 0.205)
    static let appgrayblue = Color(red: 0.475, green: 0.555, blue: 0.698)
    static let appnew = Color(red: 0.49, green: 0.60, blue: 0.75)
    static let dayWork = Color(hex:"#00B007")
    static let dayProgul = Color(hex:"#EB1414")
    static let dayOtgul = Color(hex:"#FFBF00")
    static let dayBolnich = Color(hex:"#FFBF00")
    static let dayOtpusk = Color(hex:"#949ED1")
    static let dayVykhod = Color(hex:"#949ED1")
    static let dayUvoln = Color(hex:"#242942")
    static let appred = Color(hex:"#FA5754")//Color(red: 0.98, green: 0.34, blue: 0.33)
    static let prored = Color(hex:"#c03029")
    static let prored1 = Color(hex:"#D93A32")
    static let progreen1 = Color(hex:"#AEE5C2")
    static let appyellow = Color(hex:"#FFBF00")  //#c1c6ce
}


// MARK: - Color Extension

extension Color {
    /// Initialize color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
