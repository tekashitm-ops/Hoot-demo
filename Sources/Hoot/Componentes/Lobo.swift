import SwiftUI

struct PaletaLobo: Equatable {
    var pelajeArriba: Color
    var pelajeAbajo: Color

    var sombra: Color

    var claro: Color
    var orejaDentro: Color
    var iris: Color
    var pupila: Color
    var nariz: Color
    var rubor: Color

    private static func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }

    static let gris = PaletaLobo(pelajeArriba: c(0.60, 0.66, 0.78), pelajeAbajo: c(0.44, 0.50, 0.63), sombra: c(0.33, 0.38, 0.51),
                                 claro: c(0.98, 0.96, 0.92), orejaDentro: c(0.97, 0.80, 0.80), iris: c(1.0, 0.72, 0.20),
                                 pupila: c(0.10, 0.10, 0.14), nariz: c(0.17, 0.17, 0.22), rubor: c(1.0, 0.60, 0.66))

    static let actual = gris
}

enum GestoLobo: String, Equatable, CaseIterable {
    case normal, feliz, pensando, dormido, sorprendido

    case preocupado

    case enfadado

    case escribiendo

    case saltando

    case aullando

    case hablando

    case atascado
}

nonisolated private func punto(_ r: CGRect, _ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height)
}

struct CabezaLobo: Shape {
    func path(in r: CGRect) -> Path {
        let p = { (x: CGFloat, y: CGFloat) in punto(r, x, y) }
        var c = Path()
        c.move(to: p(0.50, 0.17))
        c.addQuadCurve(to: p(0.76, 0.22), control: p(0.66, 0.15))
        c.addCurve(to: p(0.87, 0.44), control1: p(0.84, 0.27), control2: p(0.87, 0.35))
        c.addQuadCurve(to: p(0.97, 0.55), control: p(0.92, 0.52))
        c.addQuadCurve(to: p(0.88, 0.57), control: p(0.92, 0.57))
        c.addQuadCurve(to: p(0.93, 0.66), control: p(0.91, 0.62))
        c.addQuadCurve(to: p(0.82, 0.66), control: p(0.87, 0.67))
        c.addQuadCurve(to: p(0.50, 0.75), control: p(0.70, 0.76))
        c.addQuadCurve(to: p(0.18, 0.66), control: p(0.30, 0.76))
        c.addQuadCurve(to: p(0.07, 0.66), control: p(0.13, 0.67))
        c.addQuadCurve(to: p(0.12, 0.57), control: p(0.09, 0.62))
        c.addQuadCurve(to: p(0.03, 0.55), control: p(0.08, 0.57))
        c.addQuadCurve(to: p(0.13, 0.44), control: p(0.08, 0.52))
        c.addCurve(to: p(0.24, 0.22), control1: p(0.13, 0.35), control2: p(0.16, 0.27))
        c.addQuadCurve(to: p(0.50, 0.17), control: p(0.34, 0.15))
        c.closeSubpath()
        return c
    }
}

struct MechonLobo: Shape {
    func path(in r: CGRect) -> Path {
        let p = { (x: CGFloat, y: CGFloat) in punto(r, x, y) }
        var c = Path()
        c.move(to: p(0.41, 0.19))
        c.addQuadCurve(to: p(0.47, 0.125), control: p(0.45, 0.15))
        c.addQuadCurve(to: p(0.51, 0.17), control: p(0.49, 0.15))
        c.addQuadCurve(to: p(0.565, 0.135), control: p(0.545, 0.145))
        c.addQuadCurve(to: p(0.60, 0.20), control: p(0.59, 0.16))
        c.closeSubpath()
        return c
    }
}

struct OrejaLobo: Shape {
    var dentro = false

    func path(in r: CGRect) -> Path {
        let p = { (x: CGFloat, y: CGFloat) in punto(r, x, y) }
        var c = Path()
        if dentro {
            c.move(to: p(0.23, 0.27))
            c.addQuadCurve(to: p(0.195, 0.075), control: p(0.18, 0.15))
            c.addQuadCurve(to: p(0.37, 0.20), control: p(0.27, 0.11))
        } else {
            c.move(to: p(0.14, 0.34))
            c.addQuadCurve(to: p(0.15, 0.025), control: p(0.10, 0.12))
            c.addQuadCurve(to: p(0.21, 0.01), control: p(0.17, -0.01))
            c.addQuadCurve(to: p(0.45, 0.19), control: p(0.34, 0.06))
        }
        c.closeSubpath()
        return c
    }
}

struct AntifazLobo: Shape {
    func path(in r: CGRect) -> Path {
        let p = { (x: CGFloat, y: CGFloat) in punto(r, x, y) }
        var c = Path()
        c.move(to: p(0.0, 0.60))
        c.addQuadCurve(to: p(0.27, 0.50), control: p(0.14, 0.50))
        c.addQuadCurve(to: p(0.43, 0.47), control: p(0.36, 0.53))
        c.addQuadCurve(to: p(0.50, 0.53), control: p(0.47, 0.46))
        c.addQuadCurve(to: p(0.57, 0.47), control: p(0.53, 0.46))
        c.addQuadCurve(to: p(0.73, 0.50), control: p(0.64, 0.53))
        c.addQuadCurve(to: p(1.0, 0.60), control: p(0.86, 0.50))
        c.addLine(to: p(1.0, 1.0))
        c.addLine(to: p(0.0, 1.0))
        c.closeSubpath()
        return c
    }
}

struct CuerpoLobo: Shape {
    func path(in r: CGRect) -> Path {
        let p = { (x: CGFloat, y: CGFloat) in punto(r, x, y) }
        var c = Path()
        c.move(to: p(0.34, 0.62))
        c.addCurve(to: p(0.17, 0.95), control1: p(0.24, 0.72), control2: p(0.15, 0.82))
        c.addQuadCurve(to: p(0.83, 0.95), control: p(0.50, 1.0))
        c.addCurve(to: p(0.66, 0.62), control1: p(0.85, 0.82), control2: p(0.76, 0.72))
        c.closeSubpath()
        return c
    }
}

struct ColaLobo: Shape {
    static let raiz = UnitPoint(x: 0.70, y: 0.93)

    func path(in r: CGRect) -> Path {
        let p = { (x: CGFloat, y: CGFloat) in punto(r, Self.raiz.x + x, Self.raiz.y + y) }
        var c = Path()
        c.move(to: p(-0.045, 0))
        c.addCurve(to: p(-0.13, -0.38), control1: p(-0.13, -0.08), control2: p(-0.20, -0.28))
        c.addCurve(to: p(0.045, 0), control1: p(-0.02, -0.37), control2: p(0.10, -0.14))
        c.closeSubpath()
        return c
    }
}

struct NarizLobo: Shape {
    func path(in r: CGRect) -> Path {
        var c = Path()
        c.move(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.2))
        c.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.2), control: CGPoint(x: r.midX, y: r.minY - r.height * 0.2))
        c.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.maxX, y: r.minY + r.height * 0.9))
        c.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.2), control: CGPoint(x: r.minX, y: r.minY + r.height * 0.9))
        c.closeSubpath()
        return c
    }
}

struct BocaLobo: Shape {
    func path(in r: CGRect) -> Path {
        let p = { (x: CGFloat, y: CGFloat) in punto(r, x, y) }
        var c = Path()
        c.move(to: p(0.5, 0.57))
        c.addLine(to: p(0.5, 0.588))
        c.move(to: p(0.44, 0.585))
        c.addQuadCurve(to: p(0.50, 0.585), control: p(0.47, 0.62))
        c.addQuadCurve(to: p(0.56, 0.585), control: p(0.53, 0.62))
        return c
    }
}

struct ArcoOjo: Shape {
    var haciaArriba: Bool

    func path(in r: CGRect) -> Path {
        var c = Path()
        c.move(to: CGPoint(x: r.minX, y: r.midY))
        c.addQuadCurve(
            to: CGPoint(x: r.maxX, y: r.midY),
            control: CGPoint(x: r.midX, y: haciaArriba ? r.minY - r.height * 0.6 : r.maxY + r.height * 0.6)
        )
        return c
    }
}

private struct Zeta: Shape {
    func path(in r: CGRect) -> Path {
        var c = Path()
        c.move(to: CGPoint(x: r.minX, y: r.minY))
        c.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        c.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        c.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        return c
    }
}

struct Lobo: View {
    var tamano: CGFloat
    var gesto: GestoLobo = .normal

    var mirada: CGPoint = .zero
    var paleta: PaletaLobo = .actual
    var anima = true

    var paraguas = false

    @State private var cerrado = false
    @State private var tic: Double = 0
    @State private var desde = Date.now
    @State private var visible = true
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    private var vivo: Bool { anima && !reducirMovimiento }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !vivo || !visible)) { contexto in
            let t = vivo ? contexto.date.timeIntervalSinceReferenceDate : 0
            let tg = vivo ? max(0, contexto.date.timeIntervalSince(desde)) : 0
            figura(t: t, tg: tg)
        }
        .frame(width: tamano, height: tamano)
        .accessibilityHidden(true)
        .onScrollVisibilityChange(threshold: 0.01) { visible = $0 }
        .onChange(of: gesto) { desde = .now }
        .task(id: vivo && ojosAbiertos) {
            guard vivo, ojosAbiertos else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.4...5)))
                withAnimation(Diseno.muelleParpadeo) { cerrado = true }
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(Diseno.muelleParpadeoAbrir) { cerrado = false }

                if Int.random(in: 0..<3) == 0 {
                    try? await Task.sleep(for: .milliseconds(300))
                    withAnimation(Diseno.muelleRapido) { tic = 12 }
                    try? await Task.sleep(for: .milliseconds(180))
                    withAnimation(Diseno.muelleVuelta) { tic = 0 }
                }
            }
        }
    }

    private var ojosAbiertos: Bool { ![.feliz, .saltando, .dormido, .aullando].contains(gesto) }

    private func figura(t: Double, tg: Double) -> some View {
        let s = tamano
        let respira = 1 + 0.012 * sin(t * 2.1)
        let salto = gesto == .saltando ? -abs(sin(tg * 5.2)) * s * 0.12 : 0
        let aplasta = gesto == .saltando ? 1 - 0.05 * max(0, cos(tg * 10.4)) : 1

        let mece = Angle.degrees(1.3 * sin(t * 1.1))
        let agarre = UnitPoint(x: Paraguas.agarre.x, y: Paraguas.agarre.y)
        return ZStack {
            cola(t)
            if paraguas {

                Paraguas.Forma(parte: .paloDetras)
                    .stroke(Paraguas.colorPalo, style: StrokeStyle(lineWidth: s * Paraguas.grosor, lineCap: .round))
                    .rotationEffect(mece, anchor: agarre)
            }
            cuerpo
            cabeza(t)
                .rotationEffect(.degrees(inclinacion), anchor: UnitPoint(x: 0.5, y: 0.72))
            extras(t)
            if paraguas { paraguasDelante(mece: mece) }
        }
        .frame(width: s, height: s)
        .scaleEffect(x: 1, y: respira * aplasta, anchor: .bottom)
        .offset(y: salto)
    }

    private func paraguasDelante(mece: Angle) -> some View {
        let s = tamano
        let agarre = UnitPoint(x: Paraguas.agarre.x, y: Paraguas.agarre.y)
        let brazo = Paraguas.brazo
        return ZStack {
            ZStack {
                Paraguas.Forma(parte: .paloDelante)
                    .stroke(Paraguas.colorPalo, style: StrokeStyle(lineWidth: s * Paraguas.grosor, lineCap: .round, lineJoin: .round))
            }
            .rotationEffect(mece, anchor: agarre)

            ZStack(alignment: .top) {
                Capsule().fill(paleta.sombra.opacity(0.5)).padding(-s * 0.008)
                Capsule().fill(paleta.claro)
                HStack(spacing: s * 0.014) {
                    Capsule().fill(paleta.orejaDentro).frame(width: s * 0.01)
                    Capsule().fill(paleta.orejaDentro).frame(width: s * 0.01)
                }
                .frame(height: s * 0.016)
                .padding(.top, s * 0.017)
            }
            .frame(width: s * 0.096, height: s * 0.175)
            .rotationEffect(.degrees(16))
            .position(x: s * brazo.x, y: s * brazo.y)
            ZStack {
                Paraguas.Forma(parte: .tela).fill(Paraguas.colorTela)
                Paraguas.Forma(parte: .gajos).fill(Paraguas.colorGajo)
                Paraguas.Forma(parte: .brillo).fill(.white.opacity(0.22))
                Paraguas.Forma(parte: .contera)
                    .stroke(Paraguas.colorPalo, style: StrokeStyle(lineWidth: s * 0.026, lineCap: .round))
            }
            .rotationEffect(mece, anchor: agarre)
        }
        .frame(width: s, height: s)
    }

    private var inclinacion: Double {
        switch gesto {
        case .aullando: -24
        case .escribiendo, .atascado: 7
        case .pensando: -5
        default: 0
        }
    }

    private func cola(_ t: Double) -> some View {
        let s = tamano
        let meneo: Double = switch gesto {
        case .feliz, .saltando: 14 * sin(t * 12)
        case .preocupado, .dormido: -18
        default: 4 * sin(t * 1.6)
        }
        return ZStack {
            ColaLobo().fill(paleta.pelajeAbajo)
            Ellipse().fill(paleta.sombra)
                .frame(width: s * 0.20, height: s * 0.17)
                .position(x: s * (ColaLobo.raiz.x - 0.12), y: s * (ColaLobo.raiz.y - 0.36))
        }
        .frame(width: s, height: s)
        .clipShape(ColaLobo())
        .rotationEffect(.degrees(62 + meneo), anchor: ColaLobo.raiz)
    }

    private var cuerpo: some View {
        let s = tamano
        return ZStack {
            ZStack {
                CuerpoLobo()
                    .fill(LinearGradient(colors: [paleta.pelajeAbajo, paleta.sombra], startPoint: UnitPoint(x: 0.5, y: 0.6), endPoint: .bottom))
                Ellipse().fill(paleta.sombra).frame(width: s * 0.20, height: s * 0.15).position(x: s * 0.25, y: s * 0.90)
                Ellipse().fill(paleta.sombra).frame(width: s * 0.20, height: s * 0.15).position(x: s * 0.75, y: s * 0.90)
            }
            .frame(width: s, height: s)
            .clipShape(CuerpoLobo())
            Ellipse().fill(paleta.claro).frame(width: s * 0.28, height: s * 0.26).position(x: s * 0.5, y: s * 0.78)
            pata(x: 0.425)
            if gesto != .pensando && !paraguas { pata(x: 0.575) }
        }
        .frame(width: s, height: s)
    }

    private func pata(x: CGFloat) -> some View {
        let s = tamano
        return ZStack(alignment: .bottom) {
            Capsule().fill(paleta.claro)
            dedos.padding(.bottom, s * 0.0)
        }
        .frame(width: s * 0.10, height: s * 0.17)
        .position(x: s * x, y: s * 0.895)
    }

    private var dedos: some View {
        let s = tamano
        return HStack(spacing: s * 0.014) {
            Capsule().fill(paleta.orejaDentro).frame(width: s * 0.01)
            Capsule().fill(paleta.orejaDentro).frame(width: s * 0.01)
        }
        .frame(height: s * 0.03)
    }

    private func cabeza(_ t: Double) -> some View {
        let s = tamano
        let degradado = LinearGradient(colors: [paleta.pelajeArriba, paleta.pelajeAbajo],
                                       startPoint: UnitPoint(x: 0.5, y: 0.15), endPoint: UnitPoint(x: 0.5, y: 0.75))
        return ZStack {
            orejas
            MechonLobo().fill(degradado)
            CabezaLobo().fill(degradado)
            AntifazLobo().fill(paleta.claro).clipShape(CabezaLobo())
            cejasClaras
            ojo(x: 0.345)
            ojo(x: 0.655)
            cejas
            rubor
            NarizLobo().fill(paleta.nariz).frame(width: s * 0.12, height: s * 0.08).position(x: s * 0.5, y: s * 0.535)
            Ellipse().fill(.white.opacity(0.6)).frame(width: s * 0.03, height: s * 0.016).position(x: s * 0.48, y: s * 0.512)
            boca(t)
            if gesto == .pensando { pataBarbilla }
        }
        .frame(width: s, height: s)
    }

    private var anguloOrejas: Double {
        switch gesto {
        case .enfadado, .atascado: 16
        case .aullando: 20
        case .preocupado: 9
        case .dormido: 10
        case .sorprendido: -6
        default: 0
        }
    }

    private var orejas: some View {
        let s = tamano
        let a = anguloOrejas
        return ZStack {
            oreja.rotationEffect(.degrees(-a), anchor: UnitPoint(x: 0.30, y: 0.26))
            oreja
                .scaleEffect(x: -1, y: 1)
                .rotationEffect(.degrees(a + tic), anchor: UnitPoint(x: 0.70, y: 0.26))
        }
        .frame(width: s, height: s)
    }

    private var oreja: some View {
        ZStack {
            OrejaLobo().fill(paleta.sombra)
            OrejaLobo(dentro: true).fill(paleta.orejaDentro)
        }
    }

    private var cejasClaras: some View {
        let s = tamano
        let y = gesto == .sorprendido ? 0.30 : 0.315
        return ZStack {
            Ellipse().fill(paleta.claro).frame(width: s * 0.075, height: s * 0.042)
                .rotationEffect(.degrees(-12)).position(x: s * 0.335, y: s * y)
            Ellipse().fill(paleta.claro).frame(width: s * 0.075, height: s * 0.042)
                .rotationEffect(.degrees(12)).position(x: s * 0.665, y: s * y)
        }
    }

    @ViewBuilder
    private func ojo(x: CGFloat) -> some View {
        let s = tamano
        let centro = CGPoint(x: s * x, y: s * 0.43)
        switch gesto {
        case .feliz, .saltando:
            ArcoOjo(haciaArriba: true)
                .stroke(paleta.pupila, style: StrokeStyle(lineWidth: s * 0.032, lineCap: .round))
                .frame(width: s * 0.13, height: s * 0.045)
                .position(x: centro.x, y: centro.y + s * 0.01)
        case .dormido, .aullando:
            ArcoOjo(haciaArriba: false)
                .stroke(paleta.pupila, style: StrokeStyle(lineWidth: s * 0.028, lineCap: .round))
                .frame(width: s * 0.13, height: s * 0.04)
                .position(centro)
        default:
            ojoAbierto.position(centro)
        }
    }

    private var ojoAbierto: some View {
        let s = tamano
        let blanco = gesto == .sorprendido ? 0.19 : 0.175
        let pupila = gesto == .sorprendido ? 0.05 : 0.07
        let mira: CGPoint = switch gesto {
        case .pensando: CGPoint(x: 0.6, y: -0.75)
        case .escribiendo, .atascado: CGPoint(x: 0.2, y: 0.85)
        default: mirada
        }

        return ZStack {
            Circle().fill(.white)
            ZStack {
                Circle().fill(paleta.iris).frame(width: s * 0.12)
                    .offset(x: mira.x * s * 0.042, y: mira.y * s * 0.042)
                Circle().fill(paleta.pupila).frame(width: s * pupila)
                    .offset(x: mira.x * s * 0.05, y: mira.y * s * 0.05)
                Circle().fill(.white).frame(width: s * 0.028)
                    .offset(x: mira.x * s * 0.05 - s * 0.018, y: mira.y * s * 0.05 - s * 0.022)
            }
            .clipShape(Circle())
        }
        .frame(width: s * blanco, height: s * blanco)
        .scaleEffect(x: 1, y: cerrado ? 0.08 : 1)
    }

    @ViewBuilder
    private var cejas: some View {
        let s = tamano
        if gesto == .preocupado || gesto == .enfadado || gesto == .atascado {
            let giro: Double = gesto == .preocupado ? -16 : 22
            Capsule().fill(paleta.pupila)
                .frame(width: s * 0.13, height: s * 0.032)
                .rotationEffect(.degrees(giro))
                .position(x: s * 0.345, y: s * 0.30)
            Capsule().fill(paleta.pupila)
                .frame(width: s * 0.13, height: s * 0.032)
                .rotationEffect(.degrees(-giro))
                .position(x: s * 0.655, y: s * 0.30)
        }
    }

    @ViewBuilder
    private var rubor: some View {
        let s = tamano
        if gesto == .feliz || gesto == .enfadado || gesto == .atascado || gesto == .saltando {
            let color = paleta.rubor.opacity(gesto == .enfadado || gesto == .atascado ? 0.75 : 0.5)
            Ellipse().fill(color).frame(width: s * 0.10, height: s * 0.05).position(x: s * 0.25, y: s * 0.555)
            Ellipse().fill(color).frame(width: s * 0.10, height: s * 0.05).position(x: s * 0.75, y: s * 0.555)
        }
    }

    @ViewBuilder
    private func boca(_ t: Double) -> some View {
        let s = tamano
        switch gesto {
        case .feliz, .saltando:

            Ellipse().fill(paleta.nariz)
                .frame(width: s * 0.13, height: s * 0.10)
                .mask(alignment: .bottom) { Rectangle().frame(height: s * 0.05) }
                .position(x: s * 0.5, y: s * 0.585)
            Ellipse().fill(Color(red: 1, green: 0.45, blue: 0.55))
                .frame(width: s * 0.07, height: s * 0.04)
                .position(x: s * 0.5, y: s * 0.618)
        case .hablando:
            Ellipse().fill(paleta.nariz)
                .frame(width: s * 0.07, height: s * (0.02 + 0.05 * abs(sin(t * 9))))
                .position(x: s * 0.5, y: s * 0.605)
        case .aullando, .sorprendido:
            Ellipse().fill(paleta.nariz)
                .frame(width: s * (gesto == .aullando ? 0.075 : 0.05), height: s * (gesto == .aullando ? 0.085 : 0.05))
                .position(x: s * 0.5, y: s * 0.625)
        case .enfadado, .preocupado, .atascado:
            ArcoOjo(haciaArriba: true)
                .stroke(paleta.nariz, style: StrokeStyle(lineWidth: s * 0.022, lineCap: .round))
                .frame(width: s * 0.09, height: s * 0.03)
                .position(x: s * 0.5, y: s * 0.635)
        default:
            BocaLobo()
                .stroke(paleta.nariz, style: StrokeStyle(lineWidth: s * 0.018, lineCap: .round, lineJoin: .round))
        }
    }

    private var pataBarbilla: some View {
        let s = tamano
        return ZStack(alignment: .top) {
            Capsule().fill(paleta.sombra.opacity(0.5)).padding(-s * 0.008)
            Capsule().fill(paleta.claro)
            HStack(spacing: s * 0.014) {
                Capsule().fill(paleta.orejaDentro).frame(width: s * 0.01)
                Capsule().fill(paleta.orejaDentro).frame(width: s * 0.01)
            }
            .frame(height: s * 0.016)
            .padding(.top, s * 0.017)
        }
        .frame(width: s * 0.10, height: s * 0.21)
        .rotationEffect(.degrees(-14))
        .position(x: s * 0.585, y: s * 0.775)
    }

    @ViewBuilder
    private func extras(_ t: Double) -> some View {
        switch gesto {
        case .pensando: puntitos(t)
        case .escribiendo: escritura(t)
        case .atascado:
            escritura(0.55)
            rayitas(t)
        case .dormido: zetas(t)
        case .aullando: aullido(t)
        case .enfadado: rayitas(t)
        default: EmptyView()
        }
    }

    private func puntitos(_ t: Double) -> some View {
        let s = tamano
        return ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(.white)
                    .frame(width: s * 0.045)
                    .opacity(0.35 + 0.65 * max(0, sin(t * 3.2 - Double(i) * 0.7)))
                    .position(x: s * (0.79 + 0.07 * Double(i)), y: s * 0.10)
            }
        }
        .frame(width: s, height: s)
    }

    private func escritura(_ t: Double) -> some View {
        let s = tamano
        let avance = (t * 0.6).truncatingRemainder(dividingBy: 1)
        return ZStack {
            RoundedRectangle(cornerRadius: s * 0.02, style: .continuous)
                .fill(.white)
                .stroke(paleta.sombra.opacity(0.35), lineWidth: s * 0.008)
                .frame(width: s * 0.34, height: s * 0.20)
                .rotationEffect(.degrees(-4))
                .position(x: s * 0.40, y: s * 0.90)
            Capsule().fill(paleta.sombra.opacity(0.6))
                .frame(width: s * 0.26 * avance, height: s * 0.014)
                .position(x: s * (0.27 + 0.13 * avance), y: s * 0.88)
            ZStack(alignment: .bottom) {
                Capsule().fill(Color(red: 1, green: 0.78, blue: 0.27))
                Capsule().fill(paleta.nariz).frame(width: s * 0.022, height: s * 0.04)
            }
            .frame(width: s * 0.045, height: s * 0.22)
            .rotationEffect(.degrees(28))
            .position(x: s * (0.32 + 0.24 * avance), y: s * (0.80 + 0.012 * sin(t * 18)))
            Capsule().fill(paleta.claro)
                .frame(width: s * 0.12, height: s * 0.08)
                .position(x: s * (0.36 + 0.24 * avance), y: s * 0.88)
        }
        .frame(width: s, height: s)
    }

    private func zetas(_ t: Double) -> some View {
        let s = tamano
        return ZStack {
            ForEach(0..<3, id: \.self) { i in
                let fase = (t * 0.35 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                let lado = s * (0.08 + 0.04 * fase) * 2 / 3
                Zeta()
                    .stroke(.white.opacity(1 - fase), style: StrokeStyle(lineWidth: s * 0.018, lineCap: .round, lineJoin: .round))
                    .frame(width: lado, height: lado)
                    .position(x: s * (0.78 + 0.1 * fase), y: s * (0.22 - 0.16 * fase))
            }
        }
        .frame(width: s, height: s)
    }

    private func aullido(_ t: Double) -> some View {
        let s = tamano
        return ZStack {
            ForEach(0..<3, id: \.self) { i in
                let fase = (t * 0.4 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                ArcoOjo(haciaArriba: true)
                    .stroke(.white.opacity(0.8 * (1 - fase)), style: StrokeStyle(lineWidth: s * 0.02, lineCap: .round))
                    .frame(width: s * (0.10 + 0.14 * fase), height: s * 0.05)
                    .rotationEffect(.degrees(-20))
                    .position(x: s * (0.30 - 0.06 * fase), y: s * (0.13 - 0.15 * fase))
            }
        }
        .frame(width: s, height: s)
    }

    private func rayitas(_ t: Double) -> some View {
        let s = tamano
        return ZStack {
            ForEach(0..<2, id: \.self) { i in
                Capsule().fill(Color(red: 1, green: 0.4, blue: 0.4))
                    .frame(width: s * 0.025, height: s * 0.09)
                    .rotationEffect(.degrees(i == 0 ? -25 : 25))
                    .position(x: s * (i == 0 ? 0.12 : 0.88), y: s * 0.20 + s * 0.008 * sin(t * 30))
            }
        }
        .frame(width: s, height: s)
    }
}

extension Lobo {

    static func silueta(_ tamano: CGFloat, paraguas: Bool = false) -> [CGPoint] {
        if paraguas { return Paraguas.silueta.map { CGPoint(x: $0.x * tamano, y: $0.y * tamano) } }
        return silueta(tamano)
    }

    static func silueta(_ tamano: CGFloat) -> [CGPoint] {
        [(0.03, 0.55), (0.13, 0.44), (0.14, 0.34), (0.15, 0.025), (0.21, 0.01), (0.33, 0.10), (0.41, 0.17),
         (0.47, 0.13), (0.50, 0.16), (0.565, 0.135), (0.60, 0.17), (0.67, 0.10), (0.79, 0.01), (0.85, 0.025),
         (0.86, 0.34), (0.87, 0.44), (0.97, 0.55)]
            .map { CGPoint(x: $0.0 * tamano, y: $0.1 * tamano) }
    }
}

struct LoboInteractivo: View {
    var tamano: CGFloat
    var gesto: GestoLobo = .normal
    var mirada: CGPoint = .zero
    var saludo: GestoLobo? = nil
    var paleta: PaletaLobo = .actual

    var paraguasSiLlueve = false

    @State private var toques = 0
    @State private var momento: GestoLobo?
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @Environment(Almacen.self) private var almacen: Almacen?

    private var paraguas: Bool {
        guard paraguasSiLlueve, let almacen else { return false }
        return TiempoReal.compartido.escena(fijado: TiempoFijo(rawValue: almacen.ajustes.tiempoFondo) ?? .real).caeAlgo
    }

    var body: some View {
        let paraguas = paraguas
        Lobo(tamano: tamano, gesto: momento ?? gesto, mirada: mirada, paleta: paleta, paraguas: paraguas)

            .chocable(.linea(Lobo.silueta(tamano, paraguas: paraguas)), reacciona: true)
            .contentShape(Rectangle())
            .onTapGesture {
                toques += 1
                hacer(reducirMovimiento ? .feliz : .saltando, durante: 1.2)
            }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.8), trigger: toques)
            .task(id: saludo) {
                if let saludo { hacer(saludo, durante: saludo == .saltando ? 1.25 : 3.2) }
            }
            .accessibilityElement()
            .accessibilityLabel(L("Lobo de Hoot", "Hoot's wolf", "Il lupo di Hoot"))
            .accessibilityAddTraits(.isButton)
    }

    private func hacer(_ g: GestoLobo, durante segundos: Double) {
        momento = g
        Task {
            try? await Task.sleep(for: .seconds(segundos))
            if momento == g { momento = nil }
        }
    }
}

struct LoboTrabajando: View {
    var tamano: CGFloat

    var gesto: GestoLobo = .pensando
    @State private var paso = 0
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    private var secuencia: [(GestoLobo, Double)] {
        let otro: GestoLobo = gesto == .escribiendo ? .pensando : .escribiendo
        return [(gesto, 3.2), (otro, 2.6), (gesto, 3.2), (.atascado, 1.6), (gesto, 2.6), (otro, 2.6)]
    }

    private var quieto: Bool { reducirMovimiento || ModoCapturas.activo }

    var body: some View {
        Lobo(tamano: tamano, gesto: quieto ? gesto : secuencia[paso % secuencia.count].0)
            .task {
                guard !quieto else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(secuencia[paso % secuencia.count].1))
                    paso += 1
                }
            }
    }
}

struct Roca: Shape {
    func path(in r: CGRect) -> Path {
        var c = Path()
        c.move(to: CGPoint(x: r.minX, y: r.maxY))
        c.addCurve(to: CGPoint(x: r.midX + r.width * 0.06, y: r.minY),
                   control1: CGPoint(x: r.minX + r.width * 0.06, y: r.minY + r.height * 0.35),
                   control2: CGPoint(x: r.minX + r.width * 0.24, y: r.minY))
        c.addCurve(to: CGPoint(x: r.maxX, y: r.maxY),
                   control1: CGPoint(x: r.maxX - r.width * 0.16, y: r.minY),
                   control2: CGPoint(x: r.maxX - r.width * 0.03, y: r.minY + r.height * 0.4))
        c.closeSubpath()
        return c
    }
}

struct CatalogoLobos: View {
    private let gestos: [(GestoLobo, String)] = [
        (.normal, "Normal"), (.feliz, "Contento"), (.saltando, "Saltando"),
        (.pensando, "Pensando"), (.escribiendo, "Escribiendo"), (.atascado, "Atascado"),
        (.enfadado, "Enfadado"), (.preocupado, "Preocupado"), (.sorprendido, "Sorprendido"),
        (.dormido, "Dormido"), (.aullando, "Aullando"), (.hablando, "Hablando"),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 18) {
                ForEach(gestos, id: \.1) { g, nombre in
                    VStack(spacing: 6) {
                        Lobo(tamano: 112, gesto: g, mirada: CGPoint(x: -0.3, y: 0.2))
                        Text(nombre).font(.footnote.weight(.semibold)).foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.top, 70)
        }
        .background { FondoTiempo() }
    }
}
