import SwiftUI
import UIKit

enum FormaDeChoque: Equatable, Sendable {
    case caja(radio: CGFloat)
    case capsula
    case circulo

    case texto(arriba: CGFloat, abajo: CGFloat)

    case linea([CGPoint])
}

enum CapaDeChoque: Sendable {
    case app, panel, muestra
}

@MainActor
@Observable
final class Golpe {
    private(set) var veces = 0
    @ObservationIgnored private(set) var fuerza: CGFloat = 0

    func dar(_ f: CGFloat) {
        fuerza = f
        veces &+= 1
    }
}

@MainActor
final class Choques {
    static let compartido = Choques()

    struct Cuerpo {
        var marco: CGRect
        var forma: FormaDeChoque
        var capa: CapaDeChoque
        var golpe: Golpe?
    }

    private(set) var cuerpos: [UUID: Cuerpo] = [:]
    func poner(_ id: UUID, _ c: Cuerpo) { cuerpos[id] = c }
    func quitar(_ id: UUID) { cuerpos[id] = nil }

    private(set) var hojas: [UUID: CGRect] = [:]
    private(set) var altoDeVentana: CGFloat = 900

    func ponerHoja(_ id: UUID, _ marco: CGRect, alto: CGFloat) {
        hojas[id] = marco
        altoDeVentana = alto
    }

    func quitarHoja(_ id: UUID) { hojas[id] = nil }
}

private struct SondaDeHoja: UIViewRepresentable {
    let activa: Bool

    func makeUIView(context: Context) -> Sonda { Sonda() }
    func updateUIView(_ vista: Sonda, context: Context) { vista.activa = activa }

    final class Sonda: UIView {
        private let id = UUID()
        private var enlace: CADisplayLink?
        var activa = false {
            didSet { if activa != oldValue { empezar() } }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            empezar()
        }

        private func empezar() {
            enlace?.invalidate()
            enlace = nil
            if window != nil, activa {
                isUserInteractionEnabled = false
                let e = CADisplayLink(target: self, selector: #selector(medir))
                e.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 60, preferred: 30)
                e.add(to: .main, forMode: .common)
                enlace = e
                medir()
            } else {
                Choques.compartido.quitarHoja(id)
            }
        }

        @objc private func medir() {
            guard let w = window else { return }
            Choques.compartido.ponerHoja(id, convert(bounds, to: w), alto: w.bounds.height)
        }
    }
}

extension View {

    func hojaQueChoca() -> some View {
        background {
            SondaDeHoja(activa: true)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct ClaveCapaDeChoque: EnvironmentKey {
    nonisolated static let defaultValue = CapaDeChoque.app
}

private struct ClavePestanaVisible: EnvironmentKey {
    nonisolated static let defaultValue = true
}

extension EnvironmentValues {
    nonisolated var capaDeChoque: CapaDeChoque {
        get { self[ClaveCapaDeChoque.self] }
        set { self[ClaveCapaDeChoque.self] = newValue }
    }

    nonisolated var pestanaVisible: Bool {
        get { self[ClavePestanaVisible.self] }
        set { self[ClavePestanaVisible.self] = newValue }
    }
}

@MainActor
private final class UltimoMarco {
    var marco: CGRect = .zero
    var aparecido = false
    var pestana = true
    var enPantalla: Bool { aparecido && pestana }
}

private struct Chocable: ViewModifier {
    let forma: FormaDeChoque
    let reacciona: Bool
    @Environment(\.capaDeChoque) private var capa
    @Environment(\.pestanaVisible) private var pestanaVisible
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var id = UUID()
    @State private var golpe = Golpe()
    @State private var ultimo = UltimoMarco()

    func body(content: Content) -> some View {
        let forma = forma, capa = capa, id = id, golpe = reacciona ? golpe : nil, ultimo = ultimo
        let ponerOQuitar: (FormaDeChoque) -> Void = { f in
            if ultimo.enPantalla && ultimo.marco.width >= 1 {
                Choques.compartido.poner(id, .init(marco: ultimo.marco, forma: f, capa: capa, golpe: golpe))
            } else {
                Choques.compartido.quitar(id)
            }
        }
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { r in
                ultimo.marco = r
                ponerOQuitar(forma)
            }
            .modifier(Sacudida(golpe: golpe ?? self.golpe, activa: reacciona && !menosMovimiento))
            .onAppear {
                ultimo.aparecido = true
                ultimo.pestana = pestanaVisible
                ponerOQuitar(forma)
            }
            .onDisappear {
                ultimo.aparecido = false
                Choques.compartido.quitar(id)
            }
            .onChange(of: pestanaVisible) { _, ve in
                ultimo.pestana = ve
                ponerOQuitar(forma)
            }
            .onChange(of: forma) { _, nueva in ponerOQuitar(nueva) }
    }
}

private struct Sacudida: ViewModifier {
    let golpe: Golpe
    let activa: Bool

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat(0), trigger: golpe.veces) { vista, dy in
            vista.offset(y: activa ? dy : 0)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(golpe.fuerza, duration: 0.07, spring: .snappy)
                SpringKeyframe(0, duration: 0.7, spring: Spring(response: 0.42, dampingRatio: 0.42))
            }
        }
    }
}

extension View {

    func chocable(_ forma: FormaDeChoque = .caja(radio: 0), reacciona: Bool = false) -> some View {
        modifier(Chocable(forma: forma, reacciona: reacciona))
    }

    func chocableComoTexto(tamano: CGFloat, reacciona: Bool = true) -> some View {
        modifier(Chocable(forma: formaDeTexto(tamano), reacciona: reacciona))
    }
}

private func formaDeTexto(_ tamano: CGFloat) -> FormaDeChoque {
    let f = UIFont.systemFont(ofSize: tamano, weight: .bold)
    let arriba = max(f.ascender - f.capHeight, 0) + max(f.lineHeight - (f.ascender - f.descender), 0) / 2
    let abajo = max(-f.descender, 0) + max(f.lineHeight - (f.ascender - f.descender), 0) / 2
    return .texto(arriba: arriba, abajo: abajo)
}

struct Solido {
    let id: UUID?
    let minX: Float, minY: Float, maxX: Float, maxY: Float
    let radio: Float
    let linea: [SIMD2<Float>]?
    let golpe: Golpe?
    let hoja: Bool
    var superficie = false

    var ancho: Float { maxX - minX }

    @inline(__always)
    func techo(_ x: Float) -> Float? {
        if let l = linea {
            guard let a = l.first, let b = l.last, x >= a.x, x <= b.x else { return nil }
            var i = 1
            while i < l.count - 1 && l[i].x < x { i += 1 }
            let p = l[i - 1], q = l[i]
            let t = q.x - p.x > 0.001 ? (x - p.x) / (q.x - p.x) : 0
            return p.y + (q.y - p.y) * t
        }
        guard x >= minX, x <= maxX else { return nil }
        let r = min(radio, ancho / 2, (maxY - minY) / 2)
        if r > 0.5 {
            if x < minX + r {
                let d = minX + r - x
                return minY + r - (max(r * r - d * d, 0)).squareRoot()
            }
            if x > maxX - r {
                let d = x - (maxX - r)
                return minY + r - (max(r * r - d * d, 0)).squareRoot()
            }
        }
        return minY
    }

    func pendiente(_ x: Float) -> Float {
        guard let a = techo(x - 1), let b = techo(x + 1) else { return 0 }
        return (b - a) / 2
    }
}

struct Particula {
    enum Tipo: UInt8 {
        case gota, salpicadura, rocio, copo, granizo, chispa, estrella, fugaz, nube, niebla, perla
    }
    enum Estado: UInt8 {
        case libre, posada, resbala, muerta
    }

    var tipo: Tipo
    var x: Float = 0, y: Float = 0
    var vx: Float = 0, vy: Float = 0
    var giro: Float = 0, vgiro: Float = 0
    var fase: Float = 0, vfase: Float = 0
    var tam: Float = 1
    var largo: Float = 0
    var edad: Float = 0
    var vida: Float = .infinity
    var alfa: Float = 1
    var color: UInt8 = 0
    var forma: UInt8 = 0
    var capa: UInt8 = 0
    var estado: Estado = .libre

    var delante = false
    var choca = false
    var rebotes: UInt8 = 0
    var sobre: UUID?
    var dx: Float = 0
    var espera: Float = 0
    var amplitud: Float = 0
}

struct AzarDeVida {
    var s: UInt64

    mutating func siguiente() -> UInt64 {
        s &+= 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func uno() -> Float { Float(siguiente() >> 40) / Float(1 << 24) }
    mutating func entre(_ a: Float, _ b: Float) -> Float { a + (b - a) * uno() }
    mutating func signo() -> Float { uno() < 0.5 ? -1 : 1 }
    mutating func de(_ n: Int) -> Int { Int(siguiente() % UInt64(max(n, 1))) }
}

@MainActor
final class Mundo {
    let vida: Vida

    let oscuro: Bool
    let capa: CapaDeChoque
    let colores: [Color]

    let calidad: Float

    let quieto: Bool

    let tenue: Bool

    var tamano: CGSize = .zero
    var origen: CGPoint = .zero

    private(set) var tapado = false

    private(set) var ps: [Particula] = []
    private(set) var solidos: [Solido] = []
    private var indice: [UUID: Int] = [:]
    var azar: AzarDeVida

    private(set) var t: Double = 0
    private var ultimo: Double?
    private var nacer: [Double] = Array(repeating: 0, count: 8)
    private var preparado = false

    var rayo: Rayo?
    private(set) var destello: Float = 0
    private var proximoRayo: Double = ModoCapturas.rayoQuieto ? 1 : 6
    private var parpadeo: (t: Double, x: Float)?
    private var proximoParpadeo: Double = 3

    struct Rayo {
        var puntos: [SIMD2<Float>]
        var ramas: [[SIMD2<Float>]]
        var nacio: Double
        var destino: UUID?

        func edad(en t: Double) -> Double {
            ModoCapturas.rayoQuieto ? min(t - nacio, 0.3) : t - nacio
        }
    }

    init(vida: Vida, colores: [UInt32], oscuro: Bool, capa: CapaDeChoque, quieto: Bool, tenue: Bool,
         ahorro: Bool, semilla: UInt64 = 0x5EED) {
        self.vida = vida
        self.oscuro = oscuro
        self.capa = capa
        self.colores = colores.map { Color(rgbDeVida: $0) }
        self.calidad = ahorro ? 0.5 : 1

        self.quieto = quieto || vida == .sol
        self.tenue = tenue
        self.azar = AzarDeVida(s: semilla &+ vida.rawValue.unicodeScalars.reduce(UInt64(7)) { $0 &* 31 &+ UInt64($1.value) })
    }

    var fotogramas: Double {
        switch vida {
        case .estrellas, .nubes, .algunasNubes, .niebla: 30
        default: calidad < 1 ? 30 : 60
        }
    }

    var tieneAlgoQuieto: Bool {
        switch vida {
        case .estrellas, .nubes, .algunasNubes, .niebla: true
        default: false
        }
    }

    func color(_ i: UInt8) -> Color {
        colores.isEmpty ? (oscuro ? .white : .black) : colores[Int(i) % colores.count]
    }

    func avanzar(hasta fecha: Date) {
        let ahora = fecha.timeIntervalSinceReferenceDate
        guard tamano.width > 1, tamano.height > 1 else { return }
        if !preparado {
            preparado = true
            empezar()
        }
        guard let antes = ultimo else { ultimo = ahora; return }
        guard ahora > antes else { return }
        ultimo = ahora
        if quieto { return }
        let dt = Float(min(ahora - antes, 1.0 / 20))
        leerSolidos()
        if tapado { return }
        paso(dt)
    }

    func reanudar() { ultimo = nil }

    func calentar(_ segundos: Double) {
        guard tamano.width > 1 else { return }
        if !preparado { preparado = true; empezar() }
        leerSolidos()
        var quedan = Float(segundos)
        while quedan > 0 {
            let dt = min(quedan, 1.0 / 30)
            paso(dt)
            quedan -= dt
        }
    }

    private func leerSolidos() {
        var lista: [Solido] = []
        indice.removeAll(keepingCapacity: true)
        let ox = Float(origen.x), oy = Float(origen.y)
        for (id, c) in Choques.compartido.cuerpos where c.capa == capa {
            let r = c.marco
            var minX = Float(r.minX) - ox, minY = Float(r.minY) - oy
            var maxX = Float(r.maxX) - ox, maxY = Float(r.maxY) - oy
            var radio: Float = 0
            var linea: [SIMD2<Float>]?
            switch c.forma {
            case .caja(let rr): radio = Float(rr)
            case .capsula: radio = Float(min(r.width, r.height) / 2)
            case .circulo: radio = Float(min(r.width, r.height) / 2)
            case .texto(let arriba, let abajo):
                minY += Float(arriba)
                maxY -= Float(abajo)
                if maxY <= minY { continue }
            case .linea(let puntos):
                guard puntos.count >= 2 else { continue }
                let l = puntos.sorted { $0.x < $1.x }
                    .map { SIMD2(Float($0.x + r.minX) - ox, Float($0.y + r.minY) - oy) }
                linea = l
                minX = l.first?.x ?? minX; maxX = l.last?.x ?? maxX

                minY = min(minY, l.map(\.y).min() ?? minY)
            }
            if maxY < -40 || minY > Float(tamano.height) + 40 { continue }
            indice[id] = lista.count
            var s = Solido(id: id, minX: minX, minY: minY, maxX: maxX, maxY: maxY, radio: radio,
                           linea: linea, golpe: c.golpe, hoja: false)
            switch c.forma {
            case .caja, .capsula, .circulo: s.superficie = (maxX - minX) * (maxY - minY) > 500
            default: break
            }
            lista.append(s)
        }
        tapado = false
        if capa == .app {
            let alto = Choques.compartido.altoDeVentana
            for (id, m) in Choques.compartido.hojas {
                if m.minY < alto * 0.14 { tapado = true; continue }
                lista.append(Solido(id: id, minX: Float(m.minX) - ox, minY: Float(m.minY) - oy,
                                    maxX: Float(m.maxX) - ox, maxY: Float(m.maxY) - oy,
                                    radio: 38, linea: nil, golpe: nil, hoja: true))
            }
        }
        lista.sort { ($0.minY, $0.minX) < ($1.minY, $1.minX) }
        indice.removeAll(keepingCapacity: true)
        for (i, s) in lista.enumerated() { if let id = s.id { indice[id] = i } }
        solidos = lista
    }

    private func solido(_ id: UUID?) -> Solido? {
        guard let id, let i = indice[id] else { return nil }
        return solidos[i]
    }

    private func paso(_ dt: Float) {
        t += Double(dt)
        nacimientos(dt)
        tormentaYCielo(dt)
        let W = Float(tamano.width), H = Float(tamano.height)
        var i = 0
        while i < ps.count {
            mover(&ps[i], dt, W, H)
            i += 1
        }
        if !nuevas.isEmpty {
            ps.append(contentsOf: nuevas)
            nuevas.removeAll(keepingCapacity: true)
        }
        ps.removeAll { $0.estado == .muerta }
    }

    private var nuevas: [Particula] = []

    private func empezar() {
        let W = Float(tamano.width), H = Float(tamano.height)
        switch vida {
        case .estrellas:
            sembrarEstrellas(cuantas: 260, arriba: true, W, H)
            nacer[0] = Double(azar.entre(6, 18))
            nacer[1] = Double(azar.entre(40, 90))
        case .nubes, .algunasNubes:

            for k in 0..<(vida == .nubes ? 6 : 3) {
                var p = Particula(tipo: .nube)
                p.x = azar.entre(-0.2 * W, 1.1 * W)
                p.y = azar.entre(0.02, 0.6) * H
                p.tam = azar.entre(0.55, 1.35)
                p.vx = (3 + 6 * p.tam) * (oscuro ? 0.7 : 1)
                p.alfa = oscuro ? azar.entre(0.22, 0.42) : azar.entre(0.55, 0.92)
                p.forma = UInt8(k % 3)
                ps.append(p)
            }
        case .niebla:
            for k in 0..<7 {
                var p = Particula(tipo: .niebla)
                p.x = azar.entre(-0.3 * W, 1.2 * W)
                p.y = azar.entre(0.05, 1.0) * H
                p.tam = azar.entre(0.8, 1.6)
                p.vx = -azar.entre(5, 13)
                p.vgiro = azar.signo() * azar.entre(0.004, 0.012)
                p.vida = azar.entre(45, 80)
                p.edad = azar.entre(0, p.vida)
                p.alfa = oscuro ? azar.entre(0.16, 0.3) : azar.entre(0.3, 0.55)
                p.forma = UInt8(k % 2)
                ps.append(p)
            }

        default:
            break
        }
        switch vida {
        case .lluvia, .lluviaFuerte, .tormenta: calentar(1.5)
        case .nieve: calentar(5)
        case .granizo, .tormentaGranizo: calentar(1)
        default: break
        }
    }

    private func sembrarEstrellas(cuantas: Int, arriba: Bool, _ W: Float, _ H: Float) {
        let n = Int(Float(cuantas) * (W * H) / (440 * 956))
        for _ in 0..<n {
            var p = Particula(tipo: .estrella)
            p.x = azar.entre(0, W)
            p.y = arriba ? pow(azar.uno(), 1.5) * 0.85 * H : azar.entre(0, H)
            let grande = azar.uno() < 0.08
            p.tam = grande ? azar.entre(1.5, 2.3) : azar.entre(0.55, 1.35)
            p.color = UInt8(azar.de(3))
            p.fase = azar.entre(0, 6.3)
            p.vfase = azar.entre(0.8, 2.0)
            p.amplitud = azar.entre(0.78, 0.95)
            p.alfa = arriba ? min(1, max(0, 1.15 - p.y / (0.9 * H))) * azar.entre(0.55, 1) : azar.entre(0.35, 1)
            ps.append(p)
        }
    }

    private func cada(_ k: Int, _ intervalo: () -> Float) -> Bool {
        if t >= nacer[k] {
            nacer[k] = t + Double(intervalo())
            return true
        }
        return false
    }

    private func cuantas(_ tasa: Float, _ dt: Float) -> Int {
        let esperadas = tasa * calidad * dt
        var n = Int(esperadas)
        if azar.uno() < esperadas - Float(n) { n += 1 }
        return n
    }

    private func nacimientos(_ dt: Float) {
        let W = Float(tamano.width), H = Float(tamano.height)
        let k = W / 640
        switch vida {
        case .lluvia:
            lluvia(dt, W, H, k, fuerte: false)
            perlas(dt, tasa: 1.6)
        case .lluviaFuerte, .tormenta:
            lluvia(dt, W, H, k, fuerte: true)
            perlas(dt, tasa: 2.6)
        case .tormentaGranizo:
            lluvia(dt, W, H, k, fuerte: true)
            perlas(dt, tasa: 2.6)
            granizo(dt, W)
        case .nieve:
            for (tasa, capa) in [(52, UInt8(0)), (10, 1), (3, 2), (2, 2)] as [(Float, UInt8)] {
                for _ in 0..<cuantas(tasa, dt) {
                    var p = Particula(tipo: .copo)
                    p.x = azar.entre(-20, W + 20); p.y = -6
                    p.capa = capa
                    p.tam = capa == 0 ? azar.entre(0.5, 1.5) : (capa == 1 ? azar.entre(1.4, 2.6) : azar.entre(2.4, 4.4))
                    p.vy = azar.entre(60, 120) * (0.6 + 0.2 * Float(capa))
                    p.vx = azar.entre(-12, 12)
                    p.amplitud = azar.entre(6, 18)
                    p.vfase = azar.entre(0.6, 1.6); p.fase = azar.entre(0, 6.3)
                    p.alfa = capa == 0 ? azar.entre(0.35, 0.85) : azar.entre(0.6, 0.95)
                    p.choca = capa > 0 || azar.uno() < 0.15
                    ps.append(p)
                }
            }
        case .granizo:
            granizo(dt, W)
        case .estrellas:
            if cada(0, { azar.entre(14, 38) }) && !quieto {
                var p = Particula(tipo: .fugaz)
                p.x = azar.entre(0.15, 0.85) * W; p.y = azar.entre(0.03, 0.28) * H
                let a = azar.entre(0.25, 0.55) * .pi / 2 * (azar.uno() < 0.7 ? 1 : -1)
                let v = 687 * azar.entre(0.8, 1.2)
                p.vx = sin(a) * v * (azar.uno() < 0.5 ? 1 : -1); p.vy = cos(a) * v * 0.55
                p.vida = azar.entre(0.35, 0.6)
                p.largo = azar.entre(60, 100)
                ps.append(p)
            }
            if cada(1, { azar.entre(50, 110) }) && !quieto {

                var p = Particula(tipo: .estrella)
                p.forma = 1
                p.y = azar.entre(0.05, 0.3) * H
                p.x = azar.uno() < 0.5 ? -4 : W + 4
                p.vx = (p.x < 0 ? 1 : -1) * azar.entre(14, 22)
                p.tam = 0.95; p.alfa = 0.8; p.color = 2
                p.vida = (W + 8) / abs(p.vx)
                ps.append(p)
            }
        default:
            break
        }
    }

    private func granizo(_ dt: Float, _ W: Float) {
        for (tasa, v, tam) in [(36, 464, 1.2), (44, 825, 1.8), (9, 1290, 2.6)] as [(Float, Float, Float)] {
            for _ in 0..<cuantas(tasa, dt) {
                var p = Particula(tipo: .granizo)
                p.x = azar.entre(-10, W + 10); p.y = -8
                p.vy = v * azar.entre(0.85, 1.1); p.vx = p.vy * 0.04
                p.tam = tam * azar.entre(0.8, 1.2)
                p.choca = true
                p.alfa = azar.entre(0.55, 0.95)
                ps.append(p)
            }
        }
    }

    private func cuantasDe(_ tipo: Particula.Tipo) -> Int {
        var n = 0
        for p in ps where p.tipo == tipo { n += 1 }
        return n
    }

    private func perlas(_ dt: Float, tasa: Float) {
        let superficies = solidos.indices.filter { solidos[$0].superficie && solidos[$0].id != nil }
        guard !superficies.isEmpty else { return }
        for _ in 0..<cuantas(tasa, dt) where cuantasDe(.perla) < 34 {
            let s = solidos[superficies[azar.de(superficies.count)]]
            let alto = s.maxY - s.minY, ancho = s.maxX - s.minX
            guard alto > 8, ancho > 8 else { continue }
            var p = Particula(tipo: .perla)
            p.sobre = s.id
            p.dx = azar.entre(4, ancho - 4)
            p.espera = azar.entre(3, alto - 3)
            p.x = s.minX + p.dx; p.y = s.minY + p.espera
            p.tam = pow(azar.uno(), 2) * 1.6 + 0.9
            p.vida = azar.entre(6, 14)
            p.alfa = 0
            p.vy = azar.uno() < 0.25 ? azar.entre(10, 26) : 0
            p.fase = azar.entre(0.8, 3)
            p.amplitud = azar.entre(-0.6, 0.6)
            p.delante = true
            ps.append(p)
        }
    }

    private func lluvia(_ dt: Float, _ W: Float, _ H: Float, _ k: Float, fuerte: Bool) {
        let capas: [(tasa: Float, v: Float, rv: Float, escala: Float, re: Float, alfa: Float, ancho: Float)] = fuerte
            ? [(520, 1000, 400, 0.25, 0.5, 0.16, 0.7), (130, 2000, 800, 1.2, 0.4, 0.2, 1.2), (24, 2400, 800, 1.8, 0.3, 0.12, 2)]
            : [(275, 1000, 400, 0.35, 0.4, 0.2184, 0.7), (94, 2000, 1000, 0.9, 0.5, 0.2997, 1.2), (18, 2400, 800, 1.8, 0.3, 0.1463, 2)]
        let inclinacion: Float = fuerte ? 0.2 : 0.02
        for (c, l) in capas.enumerated() {
            for _ in 0..<cuantas(l.tasa, dt) {
                var p = Particula(tipo: .gota)
                p.capa = UInt8(c)
                let v = (l.v + azar.entre(-l.rv, l.rv)) * k
                p.vy = v
                p.vx = v * inclinacion
                let escala = max(l.escala + azar.entre(-l.re, l.re), 0.08)
                p.largo = 50 * escala * k
                p.tam = l.ancho
                p.alfa = min(max(l.alfa + azar.entre(-0.5, 0.5), 0), 0.72)
                if p.alfa < 0.04 { continue }
                p.x = azar.entre(-0.25 * W * inclinacion - 10, W + 10)
                p.y = azar.entre(-30, -5)
                p.choca = c > 0
                ps.append(p)
            }
        }
    }

    private func mover(_ p: inout Particula, _ dt: Float, _ W: Float, _ H: Float) {
        p.edad += dt
        if p.edad >= p.vida { p.estado = .muerta; return }
        switch p.tipo {
        case .gota: moverGota(&p, dt, H)
        case .salpicadura, .chispa:
            p.vy += (p.tipo == .chispa ? 520 : 1375) * dt
            p.vx *= (1 - 1.2 * dt)
            let y0 = p.y
            p.x += p.vx * dt; p.y += p.vy * dt
            if p.tipo == .chispa && p.vy > 0, case let (_, sy)? = choqueArriba(p.x, y0, p.y, 0.5) {
                p.y = sy - 0.5; p.vy = -p.vy * 0.3; p.vx *= 0.6
            }
        case .rocio:
            break
        case .copo: moverCopo(&p, dt, H)
        case .granizo: moverGranizo(&p, dt, H)
        case .estrella:
            if p.forma == 1 { p.x += p.vx * dt }
        case .fugaz:
            p.x += p.vx * dt; p.y += p.vy * dt
        case .nube:
            p.x += p.vx * dt
            if p.x > W + 220 * p.tam { p.x = -260 * p.tam; p.y = azar.entre(0.02, 0.6) * H }
        case .niebla:
            p.x += p.vx * dt; p.giro += p.vgiro * dt
            if p.x < -420 * p.tam { p.x = W + 380 * p.tam; p.y = azar.entre(0.05, 1) * H }
            if p.edad > p.vida - dt * 2 { p.edad = 0 }
        case .perla:
            guard let s = solido(p.sobre) else { p.estado = .muerta; return }
            p.alfa = min(1, p.edad / 0.15) * min(1, (p.vida - p.edad) / 1.5)
            if p.vy > 0 && p.edad > p.fase {
                p.espera += p.vy * dt * (0.6 + 0.4 * p.tam / 2.5)
                p.dx += sin(p.edad * 3 + p.amplitud * 5) * 6 * dt
                if p.espera > s.maxY - s.minY - 2 { p.estado = .muerta; return }
            }
            p.x = s.minX + p.dx; p.y = s.minY + p.espera
        }
    }

    private func moverGota(_ p: inout Particula, _ dt: Float, _ H: Float) {
        let y0 = p.y
        p.x += p.vx * dt; p.y += p.vy * dt
        if p.choca, case let (s, sy)? = choqueArriba(p.x, y0, p.y, 0) {
            salpicar(x: p.x, y: sy, fuerza: p.capa == 2 ? 1 : 0.7, sobre: s)
            p.estado = .muerta
            return
        }
        if p.y - p.largo > H { p.estado = .muerta }
    }

    private func salpicar(x: Float, y: Float, fuerza: Float, sobre s: Int) {
        let n = 2 + azar.de(2)
        for _ in 0..<n {
            var g = Particula(tipo: .salpicadura)
            let a = azar.entre(-1.05, 1.05)
            let v = azar.entre(90, 190) * fuerza
            g.x = x; g.y = y - 0.5
            g.vx = sin(a) * v; g.vy = -cos(a) * v
            g.tam = azar.entre(0.6, 1.3) * (0.7 + 0.3 * fuerza)
            g.vida = azar.entre(0.18, 0.32)
            g.alfa = azar.entre(0.55, 0.9)
            g.delante = true
            nuevas.append(g)
        }
        var r = Particula(tipo: .rocio)
        r.x = x; r.y = y
        r.tam = azar.entre(4, 8) * fuerza
        r.vida = 0.13
        r.alfa = 0.5
        r.delante = true
        nuevas.append(r)
    }

    private func soltar(_ p: inout Particula) {
        p.estado = .libre
        p.sobre = nil
        p.vy = max(p.vy, 12)
    }

    private func empujar(_ s: Solido, _ fuerza: Float) {
        guard let g = s.golpe else { return }
        let f = CGFloat(fuerza)
        DispatchQueue.main.async { g.dar(f) }
    }

    private func moverCopo(_ p: inout Particula, _ dt: Float, _ H: Float) {
        switch p.estado {
        case .libre:
            p.fase += p.vfase * dt
            let terminal: Float = 26 + 14 * Float(p.capa)
            p.vy += (terminal - p.vy) * min(1, 0.35 * dt)
            let vx = p.vx + cos(p.fase) * p.amplitud * p.vfase * 0.5
            let y0 = p.y
            p.x += vx * dt; p.y += p.vy * dt
            if p.choca, case let (s, sy)? = choqueArriba(p.x, y0, p.y, p.tam * 0.5) {
                let solido = solidos[s]
                p.estado = .posada
                p.sobre = solido.id
                p.dx = p.x - solido.minX
                p.y = sy - p.tam * 0.45
                p.delante = true
                p.vida = p.edad + azar.entre(7, 15)
                if solido.id == nil { p.vida = p.edad + azar.entre(1.5, 3) }
            }
            if p.y - p.tam > H { p.estado = .muerta }
        case .posada:
            if let s = solido(p.sobre) {
                p.x = s.minX + p.dx
                if let sy = s.techo(p.x) { p.y = sy - p.tam * 0.45 } else { soltar(&p) }
            } else if p.sobre != nil {
                soltar(&p)
            }
            let queda = p.vida - p.edad
            if queda < 2 { p.alfa = max(0, min(p.alfa, queda / 2)) }
        default:
            break
        }
    }

    private func moverGranizo(_ p: inout Particula, _ dt: Float, _ H: Float) {
        if p.rebotes > 0 { p.vy += 1375 * dt }
        let y0 = p.y
        p.x += p.vx * dt; p.y += p.vy * dt
        if p.vy > 0, case let (s, sy)? = choqueArriba(p.x, y0, p.y, p.tam) {
            if p.rebotes >= 2 { p.estado = .muerta; return }
            p.rebotes += 1
            p.y = sy - p.tam
            p.vy = -min(abs(p.vy) * azar.entre(0.3, 0.42), 275 * azar.entre(0.6, 1)) / Float(p.rebotes)
            p.vx = azar.entre(-90, 90) + solidos[s].pendiente(p.x) * 120
            p.delante = true
            if p.rebotes == 1 { empujar(solidos[s], 0.35) }
        }
        if p.y > H + 10 { p.estado = .muerta }
    }

    private func choqueArriba(_ x: Float, _ y0: Float, _ y1: Float, _ r: Float) -> (Int, Float)? {
        var mejor: (Int, Float)?
        for (i, s) in solidos.enumerated() {
            if x < s.minX || x > s.maxX { continue }
            if y1 + r < s.minY - 1 { continue }
            guard let sy = s.techo(x) else { continue }
            if y0 + r <= sy + 1.5, y1 + r >= sy {
                if mejor == nil || sy < mejor!.1 { mejor = (i, sy) }
            }
        }
        return mejor
    }

    private func tormentaYCielo(_ dt: Float) {
        guard vida == .tormenta || vida == .tormentaGranizo else { return }
        let W = Float(tamano.width), H = Float(tamano.height)

        if Desarrollo.compartido.rayoPedido {
            Desarrollo.compartido.rayoPedido = false
            proximoRayo = t
        }
        if t >= proximoRayo && !(ModoCapturas.rayoQuieto && rayo != nil) {
            proximoRayo = t + Double(azar.entre(7, 16))
            rayo = nuevoRayo(W, H)
        }
        if let r = rayo {
            let edad = Float(r.edad(en: t))
            let d: Float
            switch edad {
            case ..<0.08: d = 0.5
            case ..<0.16: d = 0
            case ..<0.24: d = 1
            default: d = max(0, 1 - (edad - 0.24) / 0.9)
            }
            destello = tenue ? d * 0.15 : d
            if edad > 1.3 { rayo = nil; destello = 0 }
            if edad >= 0.12, edad - dt < 0.12, let id = r.destino, let s = solido(id), let fin = r.puntos.last {
                empujar(s, 2.2)
                for _ in 0..<10 {
                    var c = Particula(tipo: .chispa)
                    let a = azar.entre(-1.3, 1.3)
                    let v = azar.entre(80, 200)
                    c.x = fin.x; c.y = fin.y - 1
                    c.vx = sin(a) * v; c.vy = -cos(a) * v
                    c.vida = azar.entre(0.25, 0.5); c.tam = 1; c.color = 1; c.delante = true
                    nuevas.append(c)
                }
            }
        }
        if t >= proximoParpadeo {
            proximoParpadeo = t + Double(azar.entre(2.5, 6))
            parpadeo = (t, azar.entre(0.1, 0.9) * W)
        }
    }

    var parpadeoAhora: (fuerza: Float, x: Float)? {
        if ModoCapturas.rayoQuieto { return nil }
        guard let p = parpadeo else { return nil }
        let e = Float(t - p.t)
        guard e < 1.2 else { return nil }
        let pasos: [Float] = [0, 0.75, 0, 0.25, 0, 0.25, 0, 1, 0, 0.5, 0, 0.75]
        let i = min(Int(e / 0.1), pasos.count - 1)
        return ((tenue ? 0.2 : 1) * pasos[i], p.x)
    }

    private func nuevoRayo(_ W: Float, _ H: Float) -> Rayo {
        let candidatos = solidos.filter { $0.id != nil && $0.minY > 40 && $0.minY < H * 0.6 && $0.ancho > 20 }
        var destino: UUID?
        var fin: SIMD2<Float>
        if !candidatos.isEmpty, azar.uno() < 0.5 {
            let s = candidatos[azar.de(candidatos.count)]
            let x = azar.entre(s.minX + 6, s.maxX - 6)
            fin = SIMD2(x, s.techo(x) ?? s.minY)
            destino = s.id
        } else {
            fin = SIMD2(azar.entre(0.15, 0.85) * W, azar.entre(0.3, 0.55) * H)
        }
        let inicio = SIMD2(fin.x + azar.entre(-0.25, 0.25) * W, -10)
        var puntos = [inicio, fin]
        var desvio = (fin.y - inicio.y) * 0.22
        for _ in 0..<6 {
            var nuevos: [SIMD2<Float>] = [puntos[0]]
            for i in 1..<puntos.count {
                let a = puntos[i - 1], b = puntos[i]
                var m = (a + b) / 2
                m.x += azar.entre(-desvio, desvio)
                nuevos.append(m)
                nuevos.append(b)
            }
            puntos = nuevos
            desvio *= 0.55
        }
        var ramas: [[SIMD2<Float>]] = []
        for _ in 0..<(2 + azar.de(2)) {
            let i = azar.de(max(puntos.count / 2, 1)) + puntos.count / 6
            guard i < puntos.count else { continue }
            var p = puntos[i]
            var rama = [p]
            let lado = azar.signo()
            for _ in 0..<Int(azar.entre(5, 10)) {
                p += SIMD2(lado * azar.entre(4, 14), azar.entre(6, 16))
                rama.append(p)
            }
            ramas.append(rama)
        }
        return Rayo(puntos: puntos, ramas: ramas, nacio: t, destino: destino)
    }
}

extension Color {
    init(rgbDeVida rgb: UInt32) {
        self.init(.sRGB, red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255,
                  blue: Double(rgb & 0xFF) / 255, opacity: 1)
    }
}

struct ChocaSi: ViewModifier {
    var activo: Bool
    var forma: FormaDeChoque

    func body(content: Content) -> some View {
        if activo { content.chocable(forma) } else { content }
    }
}
