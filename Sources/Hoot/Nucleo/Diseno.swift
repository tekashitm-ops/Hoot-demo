import SwiftUI
import UIKit

enum Diseno {

    static let margen: CGFloat = 20

    static let hueco: CGFloat = 12

    static let huecoPequeno: CGFloat = 6

    static let huecoSeccion: CGFloat = 34

    static let huecoTitulo: CGFloat = 10

    static let radioIconoAjustes: CGFloat = 7

    static let radioBloque: CGFloat = 10

    static let radioGrande: CGFloat = 22

    static let radioTramo: CGFloat = 8

    static let radioTarjeta: CGFloat = 26

    static let radioModulo: CGFloat = 19

    static let margenTarjeta: CGFloat = 16
    static let huecoTarjetas: CGFloat = 10

    static let desvanecer: CGFloat = 18

    static let radioResalte: CGFloat = 14

    static let resalteHoy: Double = 0.10
    static let resalteElegido: Double = 0.14

    static let radioMomento: CGFloat = 18
    static let radioLente: CGFloat = 16

    static let radioBarra: CGFloat = 5

    static let radioHoja: CGFloat = 30

    static let iconoAjustes: CGFloat = 29
    static let avatarBarra: CGFloat = 38
    static let avatarCuenta: CGFloat = 96
    static let iconoCabecera: CGFloat = 64
    static let filaCuenta: CGFloat = 64
    static let casilla: CGFloat = 26

    static let muelle = Animation.spring(response: 0.4, dampingFraction: 1)
    static let muelleRapido = Animation.spring(response: 0.3, dampingFraction: 1)
    static let muelleLento = Animation.spring(response: 0.7, dampingFraction: 1)
    static let muelleGesto = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let muelleRebote = Animation.spring(response: 0.45, dampingFraction: 0.62)

    static let muelleAnillo = Animation.spring(response: 1.1, dampingFraction: 1)

    static let muelleEscritura = Animation.spring(response: 1.7, dampingFraction: 1)

    static let muelleParpadeo = Animation.spring(response: 0.1, dampingFraction: 1)
    static let muelleParpadeoAbrir = Animation.spring(response: 0.16, dampingFraction: 1)

    static let muelleGolpe = Animation.spring(response: 0.12, dampingFraction: 1)
    static let muelleVuelta = Animation.spring(response: 0.35, dampingFraction: 0.55)

    static let muelleSacudida = Animation.spring(response: 0.08, dampingFraction: 1)
}

extension UIColor {

    nonisolated static func hoot(claro: UInt32, oscuro: UInt32, claroAlto: UInt32? = nil, oscuroAlto: UInt32? = nil) -> UIColor {
        UIColor { rasgos in
            let alto = rasgos.accessibilityContrast == .high
            if rasgos.userInterfaceStyle == .dark {
                return UIColor(hex: alto ? (oscuroAlto ?? oscuro) : oscuro)
            }
            return UIColor(hex: alto ? (claroAlto ?? claro) : claro)
        }
    }

    nonisolated convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {

    static let acento = Color(uiColor: .hoot(claro: 0x5452CF, oscuro: 0x9D9BFF, claroAlto: 0x3F3DB8, oscuroAlto: 0xB8B6FF))

    static let acentoRelleno = Color(uiColor: .hoot(claro: 0x5452CF, oscuro: 0x5E5CE6, claroAlto: 0x3F3DB8, oscuroAlto: 0x4F4CD6))

    static let azulConfig = Color(uiColor: .hoot(claro: 0x0062C4, oscuro: 0x5AAEFF, claroAlto: 0x0050A8, oscuroAlto: 0x7DBEFF))

    static let azulConfigRelleno = Color(uiColor: .hoot(claro: 0x0071E3, oscuro: 0x0071E3, claroAlto: 0x0058B8, oscuroAlto: 0x0058B8))

    static let interruptor = Color(uiColor: .systemGreen)

    nonisolated static let texto2 = Color(uiColor: .hoot(claro: 0x636366, oscuro: 0xAEAEB2, claroAlto: 0x48484A, oscuroAlto: 0xC7C7CC))

    nonisolated static let urgente = Color(uiColor: .hoot(claro: 0xC00012, oscuro: 0xFF8078, claroAlto: 0x9E000F, oscuroAlto: 0xFFA19B))

    static let pronto = Color(uiColor: .hoot(claro: 0xAD4500, oscuro: 0xFF9F0A, claroAlto: 0x8F3900, oscuroAlto: 0xFFB340))

    static let hecho = Color(uiColor: .hoot(claro: 0x1A7431, oscuro: 0x30D158, claroAlto: 0x125C26, oscuroAlto: 0x5BE07A))

    nonisolated static let ambar = Color(red: 1, green: 0.722, blue: 0.2)

    nonisolated static let sobreAmbar = Color(red: 0.165, green: 0.09, blue: 0)

    nonisolated static let lunaLuz: [Color] = [Color(red: 1, green: 0.902, blue: 0.651),
                                               Color(red: 1, green: 0.761, blue: 0.29),
                                               Color(red: 0.949, green: 0.62, blue: 0.11)]

    nonisolated static let lunaSombra = Color(red: 0.03, green: 0.055, blue: 0.157).opacity(0.42)
    nonisolated static let lunaAro = Color(red: 1, green: 0.886, blue: 0.667).opacity(0.55)
    nonisolated static let lunaCrater = Color(red: 0.851, green: 0.541, blue: 0.07)

    nonisolated static let tintaBocadillo = Color(red: 0.086, green: 0.129, blue: 0.247)

    static let fondo = Color(uiColor: .systemBackground)

    static let fondoAgrupado = Color(uiColor: .systemGroupedBackground)

    static let tarjeta = Color(uiColor: .secondarySystemGroupedBackground)

    static let relleno = Color(uiColor: .tertiarySystemFill)
    static let separador = Color(uiColor: .separator)
}

enum ColorHoot: String, Codable, CaseIterable, Identifiable, Sendable {
    case rojo, naranja, amarillo, verde, menta, turquesa, cian, azul, indigo, morado, rosa, marron, gris

    var id: String { rawValue }

    nonisolated private var valores: (claro: UInt32, oscuro: UInt32) {
        switch self {
        case .rojo: (0xFF3B30, 0xFF453A)
        case .naranja: (0xD65A00, 0xFF9F0A)
        case .amarillo: (0xA67C00, 0xFFD60A)
        case .verde: (0x248A3D, 0x30D158)
        case .menta: (0x0C817B, 0x63E6E2)
        case .turquesa: (0x008299, 0x40CBE0)
        case .cian: (0x0071A4, 0x64D2FF)
        case .azul: (0x007AFF, 0x0A84FF)
        case .indigo: (0x5856D6, 0x7D7AFF)
        case .morado: (0xAF52DE, 0xBF5AF2)
        case .rosa: (0xFF2D55, 0xFF375F)
        case .marron: (0x946F45, 0xAC8E68)
        case .gris: (0x6C6C70, 0x98989D)
        }
    }

    var color: Color {
        Color(uiColor: .hoot(claro: valores.claro, oscuro: valores.oscuro))
    }

    var sobre: Color {
        Color(uiColor: ColorHoot.colorSobre(claro: valores.claro, oscuro: valores.oscuro))
    }

    nonisolated private static func colorSobre(claro: UInt32, oscuro: UInt32) -> UIColor {
        UIColor { rasgos in
            let hex = rasgos.userInterfaceStyle == .dark ? oscuro : claro
            return luminancia(hex) > 0.30 ? UIColor(hex: 0x1C1C1E) : .white
        }
    }

    var textoEncima: Color {
        Color(uiColor: ColorHoot.colorTexto(claro: valores.claro, oscuro: valores.oscuro))
    }

    nonisolated private static func colorTexto(claro: UInt32, oscuro: UInt32) -> UIColor {
        UIColor { rasgos in
            let l = luminancia(rasgos.userInterfaceStyle == .dark ? oscuro : claro)

            return 1.05 / (l + 0.05) >= (l + 0.05) / 0.05 ? .white : .black
        }
    }

    var hondo: Color {
        Color(uiColor: UIColor(hex: ColorHoot.hondo(valores.claro)))
    }

    nonisolated static func hondo(_ hex: UInt32) -> UInt32 {
        var t = 0.0
        while t < 0.7 {
            let r = UInt32(Double((hex >> 16) & 0xFF) * (1 - t)), g = UInt32(Double((hex >> 8) & 0xFF) * (1 - t)), b = UInt32(Double(hex & 0xFF) * (1 - t))
            let mezcla = (r << 16) | (g << 8) | b
            if 1.05 / (luminancia(mezcla) + 0.05) >= 4.6 { return mezcla }
            t += 0.02
        }
        return 0x333333
    }

    static func masParecido(rojo: Double, verde: Double, azul: Double) -> ColorHoot {
        let o = hsb(rojo, verde, azul)

        if o.s < 0.18 { return .gris }
        var mejor = ColorHoot.gris
        var menor = Double.infinity
        for c in [ColorHoot.rojo, .naranja, .amarillo, .verde, .menta, .turquesa, .cian, .azul, .indigo, .morado, .rosa, .marron] {
            let hex = c.valores.oscuro
            let p = hsb(Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
            let dh = min(abs(p.h - o.h), 1 - abs(p.h - o.h))
            let d = dh * dh * 4 + (p.s - o.s) * (p.s - o.s) * 0.5 + (p.v - o.v) * (p.v - o.v) * 0.5
            if d < menor { menor = d; mejor = c }
        }
        return mejor
    }

    nonisolated private static func hsb(_ r: Double, _ g: Double, _ b: Double) -> (h: Double, s: Double, v: Double) {
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        var h = 0.0
        if d > 0 {
            if mx == r { h = (g - b) / d } else if mx == g { h = 2 + (b - r) / d } else { h = 4 + (r - g) / d }
            h = (h / 6).truncatingRemainder(dividingBy: 1)
            if h < 0 { h += 1 }
        }
        return (h, mx == 0 ? 0 : d / mx, mx)
    }

    var suave: Color { color.opacity(0.16) }

    var nombre: String {
        switch self {
        case .rojo: L("Rojo", "Red", "Rosso")
        case .naranja: L("Naranja", "Orange", "Arancione")
        case .amarillo: L("Amarillo", "Yellow", "Giallo")
        case .verde: L("Verde", "Green", "Verde")
        case .menta: L("Menta", "Mint", "Menta")
        case .turquesa: L("Turquesa", "Teal", "Turchese")
        case .cian: L("Cian", "Cyan", "Ciano")
        case .azul: L("Azul", "Blue", "Blu")
        case .indigo: L("Índigo", "Indigo", "Indaco")
        case .morado: L("Morado", "Purple", "Viola")
        case .rosa: L("Rosa", "Pink", "Rosa")
        case .marron: L("Marrón", "Brown", "Marrone")
        case .gris: L("Gris", "Gray", "Grigio")
        }
    }

    nonisolated static func luminancia(_ hex: UInt32) -> Double {
        func lin(_ v: UInt32) -> Double {
            let c = Double(v) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin((hex >> 16) & 0xFF) + 0.7152 * lin((hex >> 8) & 0xFF) + 0.0722 * lin(hex & 0xFF)
    }
}

extension View {

    func textoSecundario() -> some View {
        foregroundStyle(EstiloSecundario())
    }

    func zonaTactil() -> some View {
        frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }

    func animacion<V: Equatable>(_ animacion: Animation?, valor: V, reducir: Bool) -> some View {
        self.animation(reducir ? nil : animacion, value: valor)
    }

    func interruptorApple() -> some View {
        tint(Color.interruptor)
    }

    func filaConfig() -> some View {
        listRowBackground(Color(uiColor: .secondarySystemBackground))
    }
}

struct AnimacionAccesible<V: Equatable>: ViewModifier {
    var animacion: Animation
    var valor: V
    @Environment(\.accessibilityReduceMotion) private var reducir

    func body(content: Content) -> some View {
        content.animation(reducir ? nil : animacion, value: valor)
    }
}

extension View {
    func animando<V: Equatable>(_ animacion: Animation, valor: V) -> some View {
        modifier(AnimacionAccesible(animacion: animacion, valor: valor))
    }
}

@discardableResult
func conMuelle<R>(_ animacion: Animation = Diseno.muelle, _ cambios: () throws -> R) rethrows -> R {
    if UIAccessibility.isReduceMotionEnabled {
        return try cambios()
    }
    return try withAnimation(animacion, cambios)
}

private struct ClaveSobreCielo: EnvironmentKey {
    nonisolated static let defaultValue = false
}

extension EnvironmentValues {

    nonisolated var sobreCielo: Bool {
        get { self[ClaveSobreCielo.self] }
        set { self[ClaveSobreCielo.self] = newValue }
    }
}

extension Color {

    nonisolated static let avisoCielo = Color(red: 1, green: 0.84, blue: 0.4)

    nonisolated static let rayoExamen = Color(red: 1, green: 0.33, blue: 0.33)

    nonisolated static let cianCielo = Color(red: 0.72, green: 0.92, blue: 1)
}

struct EstiloSecundario: ShapeStyle {
    func resolve(in entorno: EnvironmentValues) -> Color {
        entorno.sobreCielo ? Color.white.opacity(0.86) : Color.texto2
    }
}

struct EstiloUrgente: ShapeStyle {
    func resolve(in entorno: EnvironmentValues) -> Color {
        entorno.sobreCielo ? Color.avisoCielo : Color.urgente
    }
}
