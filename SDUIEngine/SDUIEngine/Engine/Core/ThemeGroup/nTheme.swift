
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
