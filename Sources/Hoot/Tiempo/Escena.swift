import SwiftUI

enum Vida: String, Sendable {
    case lluvia, lluviaFuerte, tormenta, tormentaGranizo, nieve, granizo, sol, estrellas, nubes, algunasNubes, niebla
}

enum Tiempo: String, CaseIterable, Codable, Sendable {
    case despejado, algunasNubes, nubes, niebla, lluvia, lluviaFuerte, tormenta, tormentaGranizo, nieve, granizo

    init(wmo c: Int) {
        switch c {
        case 0, 1: self = .despejado
        case 2: self = .algunasNubes
        case 3: self = .nubes
        case 45, 48: self = .niebla
        case 51...57, 61, 80: self = .lluvia
        case 63...67, 81, 82: self = .lluviaFuerte
        case 71...77, 85, 86: self = .nieve
        case 95: self = .tormenta
        case 96, 99: self = .tormentaGranizo
        default: self = .nubes
        }
    }
}

enum TiempoFijo: String, CaseIterable, Sendable {
    case real, lluvia, tormenta, nieve, granizo, sol, noche, nubes, niebla

    var nombre: String {
        switch self {
        case .real: L("El de verdad", "The real one", "Quello vero")
        case .lluvia: L("Lluvia", "Rain", "Pioggia")
        case .tormenta: L("Tormenta", "Thunderstorm", "Temporale")
        case .nieve: L("Nieve", "Snow", "Neve")
        case .granizo: L("Granizo", "Hail", "Grandine")
        case .sol: L("Sol", "Sunny", "Sole")
        case .noche: L("Noche estrellada", "Starry night", "Notte stellata")
        case .nubes: L("Nubes", "Clouds", "Nuvole")
        case .niebla: L("Niebla", "Fog", "Nebbia")
        }
    }

    var simbolo: String {
        switch self {
        case .real: "location.fill"
        case .lluvia: "cloud.rain.fill"
        case .tormenta: "cloud.bolt.rain.fill"
        case .nieve: "cloud.snow.fill"
        case .granizo: "cloud.hail.fill"
        case .sol: "sun.max.fill"
        case .noche: "moon.stars.fill"
        case .nubes: "cloud.fill"
        case .niebla: "cloud.fog.fill"
        }
    }
}

struct Escena: Equatable, Sendable {
    var vida: Vida
    var noche: Bool

    var cielo: [UInt32]

    var malla: [UInt32]?
    var particulas: [UInt32]

    var tinteVelo: UInt32

    var bajoVelo: (color: UInt32, alfa: Double)? = nil

    static func == (a: Escena, b: Escena) -> Bool {
        a.vida == b.vida && a.noche == b.noche && a.cielo == b.cielo && a.malla == b.malla && a.particulas == b.particulas
            && a.tinteVelo == b.tinteVelo && a.bajoVelo?.color == b.bajoVelo?.color && a.bajoVelo?.alfa == b.bajoVelo?.alfa
    }

    static func de(_ t: Tiempo, noche: Bool) -> Escena {

        switch t {
        case .despejado where noche:
            return Escena(vida: .estrellas, noche: true, cielo: [0x030A1C, 0x030A1C], malla: [0x002356, 0x003659, 0x0A154B, 0x030A1C],
                          particulas: [0xFFFBF4, 0xD5EBFF, 0xE5F5FD, 0xFDFDFD], tinteVelo: 0x030A1C)
        case .despejado:

            return Escena(vida: .sol, noche: false, cielo: [0x215C96, 0x2F669F, 0x376FA9, 0x3B74B2, 0x4480BD, 0x558CC6, 0x6499D1, 0x74A6DC, 0x82B1E4],
                          malla: nil, particulas: [0xFFFCF0, 0xFFF4DE], tinteVelo: 0x0E2B4D, bajoVelo: (0xFFFCF0, 0.35))
        case .algunasNubes where noche, .nubes where noche:
            return Escena(vida: t == .nubes ? .nubes : .algunasNubes, noche: true, cielo: [0x182544, 0x050C1E], malla: nil,
                          particulas: [0x949FB2, 0x697284], tinteVelo: 0x182544, bajoVelo: (0x949FB2, 1))
        case .algunasNubes:

            return Escena(vida: .algunasNubes, noche: false, cielo: [0x215C96, 0x2F669F, 0x376FA9, 0x3B74B2, 0x4480BD, 0x558CC6, 0x6499D1, 0x74A6DC, 0x82B1E4],
                          malla: nil, particulas: [0xFDFDFD, 0xE2E9EE], tinteVelo: 0x0E2B4D, bajoVelo: (0xFDFDFD, 1))
        case .nubes:
            return Escena(vida: .nubes, noche: false, cielo: [0x4B5B6F, 0x556578, 0x5D6E81, 0x617387, 0x6C7E94, 0x798A9F, 0x8697AB, 0x93A4B7, 0x9FAFC1],
                          malla: nil, particulas: [0xFDFDFD, 0xE2E9EE], tinteVelo: 0x182544, bajoVelo: (0xFDFDFD, 1))
        case .niebla:
            let niebla: UInt32 = noche ? 0xA7B0B2 : 0xFDFDFD
            return Escena(vida: .niebla, noche: noche,
                          cielo: noche ? [0x232A2D, 0x0B1012] : [0x545B5D, 0x5E6566, 0x666E6F, 0x6B7374, 0x767E80, 0x828A8B, 0x8F9798, 0x9CA4A5, 0xA7AEB0],
                          malla: nil, particulas: [niebla], tinteVelo: 0x232A2D, bajoVelo: (niebla, 1))
        case .lluvia, .lluviaFuerte:
            return Escena(vida: t == .lluvia ? .lluvia : .lluviaFuerte, noche: noche,
                          cielo: noche ? [0x263746, 0x0B1722] : [0x475563, 0x515E6C, 0x586675, 0x5D6B7A, 0x677685, 0x728190, 0x7E8D9C, 0x8B99A7, 0x96A3B1],
                          malla: nil, particulas: [0xF2F6F8], tinteVelo: 0x263746)
        case .tormenta, .tormentaGranizo:
            return Escena(vida: t == .tormenta ? .tormenta : .tormentaGranizo, noche: noche,
                          cielo: noche ? [0x273042, 0x0E1321] : [0x2F3A53, 0x374159, 0x3C4760, 0x404B64, 0x47526D, 0x505B74, 0x59647D, 0x626D85, 0x6A748B],
                          malla: nil, particulas: [0xF3F5F8, 0xF5F9FF, 0xDAE4FF], tinteVelo: 0x273042)
        case .nieve:
            return Escena(vida: .nieve, noche: noche,
                          cielo: noche ? [0x1C2F44, 0x06101C] : [0x465C6F, 0x506679, 0x586F82, 0x5C7488, 0x678094, 0x738B9F, 0x8198AB, 0x8EA5B8, 0x9AB0C2],
                          malla: nil, particulas: noche ? [0xFDFDFD, 0xD9E7F1] : [0xFDFDFD, 0xEFF6FB], tinteVelo: 0x1C2F44)
        case .granizo:
            return Escena(vida: .granizo, noche: noche,
                          cielo: noche ? [0x252C35, 0x0B1016] : [0x4C5663, 0x55606C, 0x5D6875, 0x626D7B, 0x6C7886, 0x788391, 0x848F9D, 0x919CA9, 0x9CA6B3],
                          malla: nil, particulas: noche ? [0xFDFDFD, 0xB9BEC4] : [0xFDFDFD, 0xCCD2D7], tinteVelo: 0x252C35)
        }
    }

    var tieneSol: Bool { !noche && (vida == .sol || vida == .algunasNubes) }

    var caeAlgo: Bool { [.lluvia, .lluviaFuerte, .tormenta, .tormentaGranizo, .nieve, .granizo].contains(vida) }

    func cielo(en y: Double) -> RGBVida {
        guard cielo.count > 1 else { return RGBVida(cielo.first ?? 0) }
        let x = min(max(y, 0), 1) * Double(cielo.count - 1)
        let i = min(Int(x), cielo.count - 2)
        return RGBVida(cielo[i]).mezcla(RGBVida(cielo[i + 1]), x - Double(i))
    }

    var velo: [(y: Double, alfa: Double)] { paradas(filas: 0.112) }

    static let sinVelo: [(y: Double, alfa: Double)] = [(0, 0), (1, 0)]

    func bajoVelo(en y: Double) -> Double {
        guard let b = bajoVelo else { return 0 }
        switch vida {
        case .sol: return min(b.alfa, Self.luzDelSol(en: y))
        case .nubes, .algunasNubes: return y <= 0.70 ? b.alfa : 0
        default: return b.alfa
        }
    }

    private static func luzDelSol(en y: Double) -> Double {
        if let hecha = luzDelSolHecha[y] { return hecha }
        var l = 0.0
        for d in [-0.06, -0.03, 0, 0.03, 0.06, 0.09] where y + d >= 0.10 {
            l = max(l, Double(SolDeTiempo.luzMaxima(enAltura: Float((y + d) * 2.16))))
        }
        luzDelSolHecha[y] = l
        return l
    }

    private static var luzDelSolHecha: [Double: Double] = [:]

    private func paradas(filas: Double) -> [(y: Double, alfa: Double)] {
        let tinte = RGBVida(tinteVelo)
        func alfa(en y: Double, luminancia objetivo: Double) -> Double {
            var c = cielo(en: y)
            if let b = bajoVelo { c = c.mezcla(RGBVida(b.color), bajoVelo(en: y)) }
            guard c.luminancia > objetivo else { return 0 }
            var bajo = 0.0, alto = 1.0
            for _ in 0..<20 {
                let a = (bajo + alto) / 2
                if c.mezcla(tinte, a).luminancia > objetivo { bajo = a } else { alto = a }
            }
            return alto
        }

        return [(0.10, 0), (0.16, alfa(en: 0.16, luminancia: 0.169)), (0.23, alfa(en: 0.23, luminancia: 0.169)),
                (0.30, alfa(en: 0.30, luminancia: filas)), (0.40, alfa(en: 0.40, luminancia: filas)),
                (0.50, alfa(en: 0.50, luminancia: filas)), (0.70, alfa(en: 0.70, luminancia: filas)),
                (0.85, alfa(en: 0.85, luminancia: filas)), (1.0, alfa(en: 1.0, luminancia: filas))]
    }
}

struct RGBVida: Equatable, Sendable {
    var r, g, b: Double

    init(_ hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

    func mezcla(_ o: RGBVida, _ t: Double) -> RGBVida {
        RGBVida(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t)
    }

    var luminancia: Double {
        func lin(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }

    var hsb: (h: Double, s: Double, b: Double) {
        let mayor = max(r, g, b), menor = min(r, g, b), d = mayor - menor
        var h = 0.0
        if d > 0 {
            if mayor == r { h = (g - b) / d } else if mayor == g { h = (b - r) / d + 2 } else { h = (r - g) / d + 4 }
            h /= 6
            if h < 0 { h += 1 }
        }
        return (h, mayor == 0 ? 0 : d / mayor, mayor)
    }

    init(h: Double, s: Double, b: Double) {
        let i = Int(h * 6) % 6, f = h * 6 - Double(Int(h * 6))
        let p = b * (1 - s), q = b * (1 - f * s), t = b * (1 - (1 - f) * s)
        switch i {
        case 0: (r, g, self.b) = (b, t, p)
        case 1: (r, g, self.b) = (q, b, p)
        case 2: (r, g, self.b) = (p, b, t)
        case 3: (r, g, self.b) = (p, q, b)
        case 4: (r, g, self.b) = (t, p, b)
        default: (r, g, self.b) = (b, p, q)
        }
    }

    static func tono(_ h: Double, _ s: Double, luminancia objetivo: Double) -> RGBVida {
        var bajo = 0.0, alto = 1.0
        for _ in 0..<30 {
            let m = (bajo + alto) / 2
            if RGBVida(h: h, s: s, b: m).luminancia < objetivo { bajo = m } else { alto = m }
        }
        return RGBVida(h: h, s: s, b: bajo)
    }
}

struct TonoCielo: Equatable, Sendable {
    var fondo: RGBVida
    var fila: RGBVida
    var boton: RGBVida

    var modulo: RGBVida

    static let dia = Escena.de(.despejado, noche: false).tono
}

extension Escena {
    var tono: TonoCielo {

        let base = RGBVida(malla?.first ?? cielo.first ?? 0x82C3EE)
        let (h, s, _) = base.hsb

        let saturado = min(0.85, s * 1.45 + 0.04)
        let fondo, fila, modulo: RGBVida

        if noche || base.luminancia < 0.075 {
            fondo = base.luminancia < 0.05 ? base : RGBVida.tono(h, saturado, luminancia: 0.05)
            fila = RGBVida.tono(h, min(0.62, s * 1.1 + 0.04), luminancia: max(0.045, fondo.luminancia * 2.6))
            modulo = fila
        } else {
            fondo = RGBVida.tono(h, saturado, luminancia: 0.075)
            fila = RGBVida.tono(h, saturado, luminancia: 0.125)
            modulo = RGBVida.tono(h, saturado, luminancia: 0.085)
        }
        return TonoCielo(fondo: fondo, fila: fila, boton: base.mezcla(RGBVida(0xFFFFFF), 0.72), modulo: modulo)
    }
}

private struct ClaveTonoCielo: EnvironmentKey {
    nonisolated static let defaultValue: TonoCielo? = nil
}

private struct ClaveCieloSinVelo: EnvironmentKey {
    nonisolated static let defaultValue = false
}

extension EnvironmentValues {

    nonisolated var cieloSinVelo: Bool {
        get { self[ClaveCieloSinVelo.self] }
        set { self[ClaveCieloSinVelo.self] = newValue }
    }

    nonisolated var tonoCielo: TonoCielo? {
        get { self[ClaveTonoCielo.self] }
        set { self[ClaveTonoCielo.self] = newValue }
    }
}

struct FondoTenido: ViewModifier {
    var hoja = false
    @Environment(Almacen.self) private var almacen

    func body(content: Content) -> some View {
        let tono = TonoCielo.actual(almacen)
        content
            .environment(\.colorScheme, .dark)
            .environment(\.sobreCielo, true)
            .environment(\.tonoCielo, tono)
            .tint(.white)
            .scrollContentBackground(.hidden)
            .background { if !hoja { tono.fondo.color.ignoresSafeArea() } }
            .animation(Diseno.muelleLento, value: tono)
    }
}

struct FondoHojaTenida: View {
    @Environment(Almacen.self) private var almacen

    var body: some View {
        let tono = TonoCielo.actual(almacen)
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            tono.fondo.color.opacity(FondoModulo.opacidad)
        }
        .environment(\.colorScheme, .dark)
        .animation(Diseno.muelleLento, value: tono)
    }
}

extension TonoCielo {

    @MainActor static func actual(_ almacen: Almacen) -> TonoCielo {
        TiempoReal.compartido.escena(fijado: TiempoFijo(rawValue: almacen.ajustes.tiempoFondo) ?? .real).tono
    }
}

extension View {

    func tenidaDelCielo(hoja: Bool = false) -> some View {
        modifier(FondoTenido(hoja: hoja))
    }

    func filaTenida() -> some View {
        modifier(FilaTenida())
    }
}

enum Indicacion {
    static func texto(_ s: String) -> Text {
        Text(s).foregroundStyle(EstiloSecundario())
    }
}

struct FilaTenida: ViewModifier {
    @Environment(\.tonoCielo) private var tono

    func body(content: Content) -> some View {
        content.listRowBackground((tono ?? TonoCielo.dia).fila.color)
    }
}
