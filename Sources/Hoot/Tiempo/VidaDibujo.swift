import SwiftUI
import CoreImage
import UIKit

@MainActor
@Observable
final class VidaActiva {
    static let compartida = VidaActiva()
    private(set) var app: Mundo?
    private(set) var panel: Mundo?

    func poner(_ m: Mundo) {
        switch m.capa {
        case .app: if app !== m { app = m }
        case .panel: if panel !== m { panel = m }
        case .muestra: break
        }
    }

    func quitar(_ m: Mundo) {
        if app === m { app = nil }
        if panel === m { panel = nil }
    }
}

struct CapaDeVida: View {
    let vida: Vida
    let colores: [UInt32]
    let oscuro: Bool
    var capa: CapaDeChoque = .app

    var calentar: Double = 0

    var velo: [(y: Double, alfa: Double)] = []
    var tinteVelo: Color = .black

    @Environment(\.scenePhase) private var fase
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @Environment(\.accessibilityDimFlashingLights) private var menosDestellos
    @Environment(\.pestanaVisible) private var pestanaVisible
    @State private var mundo: Mundo?
    @State private var visible = false
    @State private var marco = MarcoGuardado()

    var body: some View {
        let m = mundo
        let marco = marco
        let velo = Gradient(stops: velo.map { Gradient.Stop(color: tinteVelo.opacity($0.alfa), location: $0.y) })
        TimelineView(.animation(minimumInterval: 1 / (m?.fotogramas ?? 30), paused: pausada)) { tl in
            Canvas { ctx, tamano in
                guard let m else { return }
                if m.tamano != tamano { m.tamano = tamano }
                m.avanzar(hasta: tl.date)
                m.dibujar(&ctx, parte: .cielo)
                ctx.fill(Path(CGRect(origin: .zero, size: tamano)),
                         with: .linearGradient(velo, startPoint: .zero, endPoint: CGPoint(x: 0, y: tamano.height)))
                m.dibujar(&ctx, parte: .caida)
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { r in
            marco.rect = r
            mundo?.origen = r.origin
            if let m = mundo, m.tamano != r.size { m.tamano = r.size }
        }
        .onAppear {
            if mundo == nil {
                let d = Desarrollo.compartido
                let nuevo = Mundo(vida: vida, colores: colores, oscuro: oscuro, capa: capa,
                                  quieto: menosMovimiento || d.vidaQuieta, tenue: menosDestellos || d.vidaTenue,
                                  ahorro: ProcessInfo.processInfo.isLowPowerModeEnabled || d.vidaAhorro)
                nuevo.origen = marco.rect.origin
                if marco.rect.width > 1 { nuevo.tamano = marco.rect.size }
                mundo = nuevo
            }
            visible = true
            if let m = mundo, pestanaVisible {
                m.reanudar()
                VidaActiva.compartida.poner(m)
                let s = ModoCapturas.calentarVida ?? calentar
                if s > 0 {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(600))
                        m.calentar(s)
                    }
                }
            }
        }
        .onDisappear {
            visible = false
            if let m = mundo { VidaActiva.compartida.quitar(m) }
        }
        .onChange(of: pestanaVisible) { _, ve in
            guard let m = mundo else { return }
            if ve && visible {
                m.reanudar()
                VidaActiva.compartida.poner(m)
            } else if !ve {
                VidaActiva.compartida.quitar(m)
            }
        }
        .onChange(of: fase) { _, nueva in
            if nueva == .active { mundo?.reanudar() }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var pausada: Bool {
        !visible || !pestanaVisible || fase != .active || mundo == nil || (mundo?.quieto ?? true)
    }
}

struct CapaDelanteDeLaVida: View {
    var capa: CapaDeChoque = .app
    @Environment(\.scenePhase) private var fase
    @State private var origen = OrigenGuardado()

    var body: some View {
        let activa = capa == .app ? VidaActiva.compartida.app : VidaActiva.compartida.panel
        let pausada = activa == nil || fase != .active || (activa?.quieto ?? true)
        let origen = origen
        TimelineView(.animation(minimumInterval: 1 / (activa?.fotogramas ?? 30), paused: pausada)) { tl in
            Canvas { ctx, _ in
                guard let m = activa else { return }
                m.avanzar(hasta: tl.date)
                let d = CGPoint(x: m.origen.x - origen.punto.x, y: m.origen.y - origen.punto.y)
                m.dibujar(&ctx, parte: .delante, desplazamiento: d)
            }
        }
        .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: { origen.punto = $0 }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@MainActor
private final class OrigenGuardado {
    var punto: CGPoint = .zero
}

@MainActor
private final class MarcoGuardado {
    var rect: CGRect = .zero
}

enum ParteDelMundo {
    case cielo, caida, delante
}

extension Mundo {

    func dibujar(_ ctx: inout GraphicsContext, parte: ParteDelMundo, desplazamiento d: CGPoint = .zero) {
        guard !tapado, tamano.width > 1, tamano.height > 1 else { return }
        var c = ctx
        if d != .zero { c.translateBy(x: d.x, y: d.y) }
        if parte == .cielo { cielo(&c) }
        if quieto && !tieneAlgoQuieto { return }
        let delante = parte == .delante
        if parte != .cielo {
            gotas(&c, delante: delante)
            puntos(&c, delante: delante)
        }
        for p in ps where p.delante == delante {
            switch p.tipo {
            case .fugaz: if parte != .cielo { fugaz(&c, p) }
            case .nube, .niebla: if parte == .cielo { nube(&c, p) }
            case .perla: if parte != .cielo { perla(&c, p) }
            default: break
            }
        }
        if parte == .cielo, let r = rayo { relampago(&c, r) }
    }

    private func cielo(_ c: inout GraphicsContext) {
        let W = tamano.width, H = tamano.height
        switch vida {
        case .tormenta, .tormentaGranizo:
            if destello > 0.001 {
                c.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
                       with: .color(color(2).opacity(Double(destello) * 0.26)))
            }
            if let f = parpadeoAhora, f.fuerza > 0 {
                let centro = CGPoint(x: CGFloat(f.x), y: -20)
                c.fill(Path(ellipseIn: CGRect(x: centro.x - W * 0.6, y: centro.y - H * 0.25, width: W * 1.2, height: H * 0.5)),
                       with: .radialGradient(Gradient(colors: [color(2).opacity(0.22 * Double(f.fuerza)), .clear]),
                                             center: centro, startRadius: 0, endRadius: W * 0.6))
            }
        case .nubes where oscuro, .algunasNubes where oscuro:

            let centro = CGPoint(x: W * 0.8, y: H * 0.1)
            c.fill(Path(ellipseIn: CGRect(x: centro.x - 160, y: centro.y - 160, width: 320, height: 320)),
                   with: .radialGradient(Gradient(colors: [Color.white.opacity(0.16), .clear]),
                                         center: centro, startRadius: 0, endRadius: 160))
            c.fill(Path(ellipseIn: CGRect(x: centro.x - 15, y: centro.y - 15, width: 30, height: 30)),
                   with: .color(Color.white.opacity(0.85)))
        default:
            break
        }
    }

    private func relampago(_ c: inout GraphicsContext, _ r: Rayo) {
        let edad = r.edad(en: t)
        guard edad < 0.9 else { return }
        let visible = min(1, edad / 0.12)
        let apagar = edad < 0.3 ? 1 : max(0, 1 - (edad - 0.3) / 0.6)
        let parpadeo = edad > 0.12 && edad < 0.2 ? 0.35 : 1
        let a = apagar * parpadeo * (tenue ? 0.5 : 1)
        func camino(_ pts: [SIMD2<Float>], _ hasta: Double) -> Path {
            var p = Path()
            let n = max(2, Int(Double(pts.count) * hasta))
            for i in 0..<min(n, pts.count) {
                let q = CGPoint(x: CGFloat(pts[i].x), y: CGFloat(pts[i].y))
                if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
            }
            return p
        }
        let principal = camino(r.puntos, visible)
        let luz = color(1)
        c.stroke(principal, with: .color(luz.opacity(0.16 * a)), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
        c.stroke(principal, with: .color(luz.opacity(0.45 * a)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
        c.stroke(principal, with: .color(Color.white.opacity(a)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
        if visible >= 1 {
            for rama in r.ramas {
                let p = camino(rama, 1)
                c.stroke(p, with: .color(luz.opacity(0.25 * a)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                c.stroke(p, with: .color(Color.white.opacity(0.7 * a)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
            }
        }
    }

    private func gotas(_ c: inout GraphicsContext, delante: Bool) {
        guard !delante, vida == .lluvia || vida == .lluviaFuerte || vida == .tormenta || vida == .tormentaGranizo else { return }
        let H = Float(tamano.height)
        var colas = [[Path]](repeating: [Path](repeating: Path(), count: 4), count: 3)
        var cabezas = colas
        var hay = false
        for p in ps where p.tipo == .gota {
            let mitad = H / 2
            let f: Float = p.y < mitad ? 0.65 + 0.35 * max(p.y, 0) / mitad : max(0, 1 - (p.y - mitad) / mitad)
            let a = p.alfa * f
            guard a.isFinite, a >= 0.02 else { continue }
            let b = min(Int(a * 4 / 0.72), 3)
            let k = Int(p.capa)
            let vn = max((p.vx * p.vx + p.vy * p.vy).squareRoot(), 1)
            let ux = p.vx / vn, uy = p.vy / vn
            let cola = CGPoint(x: CGFloat(p.x - ux * p.largo), y: CGFloat(p.y - uy * p.largo))
            let medio = CGPoint(x: CGFloat(p.x - ux * p.largo * 0.45), y: CGFloat(p.y - uy * p.largo * 0.45))
            let cabeza = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
            colas[k][b].move(to: cola); colas[k][b].addLine(to: medio)
            cabezas[k][b].move(to: medio); cabezas[k][b].addLine(to: cabeza)
            hay = true
        }
        guard hay else { return }
        let col = color(0)
        let anchos: [CGFloat] = [0.6, 1.1, 1.8]
        for k in 0..<3 {
            for b in 0..<4 {
                let a = Double(b + 1) / 4 * 0.72
                if !colas[k][b].isEmpty {
                    c.stroke(colas[k][b], with: .color(col.opacity(a * 0.4)), style: StrokeStyle(lineWidth: anchos[k], lineCap: .round))
                    c.stroke(cabezas[k][b], with: .color(col.opacity(a)), style: StrokeStyle(lineWidth: anchos[k], lineCap: .round))
                }
            }
        }
    }

    private func puntos(_ c: inout GraphicsContext, delante: Bool) {
        var rellenos: [Int: Path] = [:]
        var trazos: [Int: Path] = [:]
        var luces: [(x: CGFloat, y: CGFloat, halo: Double, radio: CGFloat, cruz: Double, lado: CGFloat)] = []
        let tiempo = Float(t)
        let niveles = Mundo.niveles
        func clave(_ color: Int, _ b: Int) -> Int { color * 128 + b }
        func cubeta(_ a: Float) -> Int { a.isFinite ? min(max(Int((a * Float(niveles)).rounded()), 0), niveles) : 0 }
        func opacidad(_ k: Int) -> Double { Double(k % 128) / Double(niveles) }
        func tono(_ k: Int) -> UInt8 { UInt8(k / 128) }
        for p in ps where p.delante == delante {
            switch p.tipo {
            case .salpicadura:
                let a = p.alfa * (1 - p.edad / p.vida)
                let r = CGFloat(p.tam)
                rellenos[clave(Int(p.color), cubeta(a)), default: Path()]
                    .addEllipse(in: CGRect(x: CGFloat(p.x) - r, y: CGFloat(p.y) - r, width: r * 2, height: r * 2))
            case .rocio:
                let a = p.alfa * (1 - p.edad / p.vida)
                let w = CGFloat(p.tam) * CGFloat(0.6 + 0.4 * p.edad / p.vida)
                rellenos[clave(0, cubeta(a)), default: Path()]
                    .addEllipse(in: CGRect(x: CGFloat(p.x) - w, y: CGFloat(p.y) - 0.7, width: w * 2, height: 1.4))
            case .copo:
                let r = CGFloat(p.tam) * 0.5
                rellenos[clave(0, cubeta(p.alfa)), default: Path()]
                    .addEllipse(in: CGRect(x: CGFloat(p.x) - r, y: CGFloat(p.y) - r, width: r * 2, height: r * 2))
            case .granizo:
                let r = CGFloat(p.tam) * 0.5
                let alto = r * (p.rebotes == 0 ? 2.6 : 1.2)
                rellenos[clave(0, cubeta(p.alfa)), default: Path()]
                    .addEllipse(in: CGRect(x: CGFloat(p.x) - r, y: CGFloat(p.y) - alto, width: r * 2, height: alto * 2))
            case .estrella:

                let brillo: Float = p.forma == 1 ? 1 : centelleo(p, tiempo)
                let a = min(1, p.alfa * brillo)
                if a < 0.02 { continue }
                let r = CGFloat(p.tam), x = CGFloat(p.x), y = CGFloat(p.y)
                rellenos[clave(Int(p.color), cubeta(a)), default: Path()]
                    .addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                guard p.forma == 0, p.tam > 0.8 else { continue }
                let b = CGFloat(brillo)
                let cruz = p.tam > 1.25 ? Double(a * brillo * brillo) : 0
                luces.append((x, y, Double(0.85 * a * brillo), r * (4 + 4.5 * b), cruz, r * (5 + 10 * b * b)))
            case .chispa:
                let vida = p.edad / p.vida
                let a = (1 - vida) * (1 - vida) * (vida > 0.75 ? 0.6 + 0.4 * sin(tiempo * 40 + p.x) : 1)
                let largo: Float = p.largo > 0 ? 0.04 : 0.025
                var raya = trazos[clave(Int(p.color), cubeta(a)), default: Path()]
                raya.move(to: CGPoint(x: CGFloat(p.x - p.vx * largo), y: CGFloat(p.y - p.vy * largo)))
                raya.addLine(to: CGPoint(x: CGFloat(p.x), y: CGFloat(p.y)))
                trazos[clave(Int(p.color), cubeta(a))] = raya
            default:
                break
            }
        }
        if oscuro && vida == .estrellas { c.blendMode = .plusLighter }

        if !luces.isEmpty, let halo = FormasDeVida.halo, let destello = FormasDeVida.destello {
            var l = c
            if oscuro { l.blendMode = .plusLighter }
            let imagenHalo = l.resolve(Image(uiImage: halo)), imagenDestello = l.resolve(Image(uiImage: destello))
            for e in luces {
                var g = l
                if e.halo > 0.02 {
                    g.opacity = e.halo
                    g.draw(imagenHalo, in: CGRect(x: e.x - e.radio, y: e.y - e.radio, width: e.radio * 2, height: e.radio * 2))
                }
                if e.cruz > 0.02 {
                    g.opacity = e.cruz
                    g.draw(imagenDestello, in: CGRect(x: e.x - e.lado, y: e.y - e.lado, width: e.lado * 2, height: e.lado * 2))
                }
            }
        }
        for (k, camino) in trazos {
            c.stroke(camino, with: .color(color(tono(k)).opacity(opacidad(k))),
                     style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
        if !oscuro && (vida == .nieve || vida == .granizo || vida == .tormentaGranizo) {
            for (k, camino) in rellenos {
                c.stroke(camino, with: .color(Color.black.opacity(0.06 * opacidad(k))), lineWidth: 0.8)
            }
        }
        for (k, camino) in rellenos {
            c.fill(camino, with: .color(color(tono(k)).opacity(opacidad(k))))
        }
        c.blendMode = .normal
    }

    static let niveles = 64

    func centelleo(_ p: Particula, _ t: Float) -> Float {
        let onda = 0.5 + 0.5 * sin(t * p.vfase + p.fase)
        return (1 - p.amplitud) + p.amplitud * pow(onda, 1.6)
    }

    private func perla(_ c: inout GraphicsContext, _ p: Particula) {
        let a = Double(p.alfa)
        guard a > 0.02 else { return }
        let r = CGFloat(p.tam)
        let x = CGFloat(p.x), y = CGFloat(p.y)
        if p.vy > 0 && p.edad > p.fase {
            var rastro = Path()
            rastro.move(to: CGPoint(x: x, y: y - r))
            rastro.addLine(to: CGPoint(x: x - CGFloat(sin(p.edad * 3)) * 1.5, y: y - r - CGFloat(min(p.edad - p.fase, 2)) * 14))
            c.stroke(rastro, with: .color((oscuro ? Color.white : Color.black).opacity(0.07 * a)),
                     style: StrokeStyle(lineWidth: r * 0.9, lineCap: .round))
        }
        let cuerpo = CGRect(x: x - r, y: y - r * 1.05, width: r * 2, height: r * 2.1)
        c.fill(Path(ellipseIn: cuerpo), with: .color(Color.white.opacity((oscuro ? 0.14 : 0.3) * a)))
        var sombra = Path()
        sombra.addArc(center: CGPoint(x: x, y: y), radius: r * 0.92, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
        c.stroke(sombra, with: .color(Color.black.opacity((oscuro ? 0.32 : 0.26) * a)), lineWidth: max(0.5, r * 0.32))
        c.fill(Path(ellipseIn: CGRect(x: x - r * 0.45, y: y - r * 0.62, width: r * 0.5, height: r * 0.42)),
               with: .color(Color.white.opacity(0.85 * a)))
    }

    private func fugaz(_ c: inout GraphicsContext, _ p: Particula) {
        let vida = p.edad / p.vida
        let a = Double(vida < 0.2 ? vida / 0.2 : 1 - (vida - 0.2) / 0.8)
        let vn = max((p.vx * p.vx + p.vy * p.vy).squareRoot(), 1)
        let cola = CGPoint(x: CGFloat(p.x - p.vx / vn * p.largo), y: CGFloat(p.y - p.vy / vn * p.largo))
        let cabeza = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
        var raya = Path()
        raya.move(to: cola); raya.addLine(to: cabeza)
        c.stroke(raya, with: .linearGradient(Gradient(colors: [.clear, Color.white.opacity(0.9 * a)]),
                                             startPoint: cola, endPoint: cabeza),
                 style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        c.fill(Path(ellipseIn: CGRect(x: cabeza.x - 1.3, y: cabeza.y - 1.3, width: 2.6, height: 2.6)),
               with: .color(Color.white.opacity(a)))
    }

    private func nube(_ c: inout GraphicsContext, _ p: Particula) {
        let niebla = p.tipo == .niebla
        let cual: FormasDeVida.Imagen = niebla ? .niebla : .nube(Int(p.forma))
        guard let img = FormasDeVida.imagen(cual) else { return }
        let escala = CGFloat(p.tam) * FormasDeVida.puntosPorPixel(cual)
        let ancho = img.size.width * escala, alto = img.size.height * escala
        var l = c
        l.translateBy(x: CGFloat(p.x), y: CGFloat(p.y))
        if niebla { l.rotate(by: .radians(Double(p.giro))) }
        var a = Double(p.alfa)
        if niebla { a *= Double(sin(min(max(p.edad / p.vida, 0), 1) * .pi)) }
        l.opacity = a
        if oscuro || niebla { l.addFilter(.colorMultiply(color(0))) }
        l.draw(Image(uiImage: img), in: CGRect(x: -ancho / 2, y: -alto / 2, width: ancho, height: alto))
    }
}

@MainActor
enum FormasDeVida {
    static let halo: UIImage? = {
        let lado: CGFloat = 64
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: lado, height: lado), format: formato).image { ctx in
            let colores = [UIColor(white: 1, alpha: 0.62), UIColor(white: 1, alpha: 0.26),
                           UIColor(white: 1, alpha: 0.08), UIColor(white: 1, alpha: 0)].map(\.cgColor) as CFArray
            guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colores,
                                     locations: [0, 0.2, 0.5, 1]) else { return }
            let centro = CGPoint(x: lado / 2, y: lado / 2)
            ctx.cgContext.drawRadialGradient(g, startCenter: centro, startRadius: 0, endCenter: centro,
                                             endRadius: lado / 2, options: [])
        }
    }()

    static let destello: UIImage? = {
        let lado: CGFloat = 128, m = lado / 2, grueso: CGFloat = 1.5
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: lado, height: lado), format: formato).image { ctx in
            let c = ctx.cgContext
            let colores = [UIColor(white: 1, alpha: 0), UIColor(white: 1, alpha: 1), UIColor(white: 1, alpha: 0)]
                .map(\.cgColor) as CFArray
            guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colores,
                                     locations: [0, 0.5, 1]) else { return }
            for vertical in [false, true] {
                let rombo = CGMutablePath()
                if vertical {
                    rombo.move(to: CGPoint(x: m, y: 0)); rombo.addLine(to: CGPoint(x: m + grueso, y: m))
                    rombo.addLine(to: CGPoint(x: m, y: lado)); rombo.addLine(to: CGPoint(x: m - grueso, y: m))
                } else {
                    rombo.move(to: CGPoint(x: 0, y: m)); rombo.addLine(to: CGPoint(x: m, y: m - grueso))
                    rombo.addLine(to: CGPoint(x: lado, y: m)); rombo.addLine(to: CGPoint(x: m, y: m + grueso))
                }
                rombo.closeSubpath()
                c.saveGState()
                c.addPath(rombo)
                c.clip()
                c.drawLinearGradient(g, start: vertical ? CGPoint(x: m, y: 0) : CGPoint(x: 0, y: m),
                                     end: vertical ? CGPoint(x: m, y: lado) : CGPoint(x: lado, y: m), options: [])
                c.restoreGState()
            }
        }
    }()

    enum Imagen: Hashable { case nube(Int), niebla }
    private static var imagenes: [Imagen: UIImage] = [:]

    static func puntosPorPixel(_ cual: Imagen) -> CGFloat {
        if case .nube = cual { return 250.0 / 260 }
        return 1
    }

    static func imagen(_ cual: Imagen) -> UIImage? {
        if let i = imagenes[cual] { return i }
        var circulos: [(x: CGFloat, y: CGFloat, r: CGFloat)] = []
        let sigma: CGFloat
        var base: CGFloat?
        switch cual {
        case .nube(let k):
            var azar = AzarDeVida(s: UInt64(k) &* 7919 &+ 17)
            sigma = 8
            base = 0
            let largo: CGFloat = 200
            for i in 0..<7 {
                let x = CGFloat(i) * largo / 6 + CGFloat(azar.entre(-6, 6))
                let r = CGFloat(azar.entre(17, 26))
                circulos.append((x, -r * 0.55, r))
            }
            let m = 3 + Int(azar.uno() * 2)
            for j in 0..<m {
                let t = (CGFloat(j) + 0.5) / CGFloat(m)
                let x = largo * (0.18 + 0.64 * t) + CGFloat(azar.entre(-10, 10))
                let alto = sin(t * .pi)
                let r = CGFloat(azar.entre(26, 36)) + 14 * alto
                circulos.append((x, -r * 0.55 - 16 - 22 * alto + CGFloat(azar.entre(-4, 4)), r))
            }
        case .niebla:
            var azar = AzarDeVida(s: 4242)
            sigma = 18
            for i in 0..<12 {
                let afina = 0.62 + 0.38 * sin((CGFloat(i) + 0.5) / 12 * .pi)
                circulos.append((CGFloat(i) * 33 + CGFloat(azar.entre(-10, 10)), CGFloat(azar.entre(-14, 14)),
                                 CGFloat(azar.entre(32, 52)) * afina))
            }
        }
        let margen = 3 * sigma + 3
        let minX = circulos.map { $0.x - $0.r }.min() ?? 0, maxX = circulos.map { $0.x + $0.r }.max() ?? 1
        let minY = circulos.map { $0.y - $0.r }.min() ?? 0
        let maxY = base.map { $0 + 8 } ?? (circulos.map { $0.y + $0.r }.max() ?? 1)
        let tam = CGSize(width: (maxX - minX + 2 * margen).rounded(.up), height: (maxY - minY + 2 * margen).rounded(.up))
        let ox = margen - minX, oy = margen - minY
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        let pintada = UIGraphicsImageRenderer(size: tam, format: formato).image { ctx in
            let c = ctx.cgContext
            UIColor.white.setFill()
            for (x, y, r) in circulos {
                c.fillEllipse(in: CGRect(x: x + ox - r, y: y + oy - r, width: r * 2, height: r * 2))
            }
            guard let base, let espacio = CGColorSpace(name: CGColorSpace.sRGB) else { return }
            let yb = base + oy, arriba = minY + oy
            if let g = CGGradient(colorsSpace: espacio, colors: [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray,
                                  locations: [0, 1]) {
                c.setBlendMode(.destinationIn)
                c.drawLinearGradient(g, start: CGPoint(x: 0, y: yb - 12), end: CGPoint(x: 0, y: yb + 4),
                                     options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            if let g = CGGradient(colorsSpace: espacio,
                                  colors: [UIColor.black.withAlphaComponent(0).cgColor,
                                           UIColor.black.withAlphaComponent(0.035).cgColor,
                                           UIColor.black.withAlphaComponent(0.105).cgColor] as CFArray,
                                  locations: [0, 0.5, 1]) {
                c.setBlendMode(.sourceAtop)
                c.drawLinearGradient(g, start: CGPoint(x: 0, y: arriba), end: CGPoint(x: 0, y: yb),
                                     options: [.drawsAfterEndLocation])
            }
        }
        guard let cg = pintada.cgImage else { return nil }
        let marco = CGRect(origin: .zero, size: tam)
        let ci = CIImage(cgImage: cg).applyingGaussianBlur(sigma: sigma).cropped(to: marco)
        guard let hecha = CIContext(options: [.cacheIntermediates: false]).createCGImage(ci, from: marco) else { return nil }
        let img = UIImage(cgImage: hecha)
        imagenes[cual] = img
        return img
    }
}
