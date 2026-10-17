import SwiftUI

struct NocheDeLunaLlena: View {
    var asignatura: String
    var temas: [String]

    var dia: String
    var alSeguir: () -> Void

    @State private var encendidas = 0
    @State private var lunaVisible = false
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        GeometryReader { geo in
            let ancho = geo.size.width
            ZStack {
                CieloDeNoche()
                ConstelacionTemas(cuantas: temas.count, encendidas: encendidas)
                    .frame(width: ancho * 0.6, height: ancho * 0.36)
                    .position(x: ancho * 0.3, y: geo.size.height * 0.14)
                Luna(parte: 1, tamano: min(232, ancho * 0.56), brillo: true)
                    .scaleEffect(lunaVisible ? 1 : 0.6)
                    .opacity(lunaVisible ? 1 : 0)
                    .position(x: ancho / 2, y: geo.size.height * 0.31)
                Ellipse()
                    .fill(Color(red: 0.043, green: 0.078, blue: 0.2))
                    .frame(width: ancho * 1.6, height: 520)
                    .position(x: ancho / 2, y: geo.size.height + 70)
                VStack(spacing: 6) {
                    Spacer(minLength: geo.size.height * 0.45)
                    Text(asignatura.uppercased(with: localeActual))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.86))
                    Text(L("Luna llena", "Full moon", "Luna piena"))
                        .font(.largeTitle.weight(.heavy))
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                        .shadow(color: Color.ambar.opacity(0.35), radius: 18)
                        .accessibilityAddTraits(.isHeader)
                    HStack(alignment: .bottom, spacing: 0) {
                        Lobo(tamano: min(200, ancho * 0.46), gesto: .aullando)
                        Bocadillo(texto: FrasesHoot.pruebaEntera(temas: temas.count, dia: dia), pico: .izquierda)
                            .padding(.bottom, 70)
                    }
                    .padding(.top, 8)
                    Button(action: alSeguir) {
                        Text(L("Seguir", "Continue", "Continua")).frame(maxWidth: .infinity)
                    }
                    .botonAmbar()
                    .controlSize(.large)
                }
                .padding(.horizontal, Diseno.margen)
                .padding(.bottom, 12)
            }
        }
        .ignoresSafeArea(edges: .top)
        .task { await celebrar() }
    }

    private func celebrar() async {
        if reducirMovimiento || ModoCapturas.activo {
            lunaVisible = true
            encendidas = temas.count
            if !ModoCapturas.activo { Sonidos.compartido.tocar(.aullido) }
            return
        }
        withAnimation(Diseno.muelleLento) { lunaVisible = true }
        Sonidos.compartido.tocar(.aullido)
        for i in 1...max(temas.count, 1) {
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(Diseno.muelleRebote) { encendidas = i }
        }
    }
}

struct CieloDeNoche: View {
    var semilla: UInt64 = 5
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reducirMovimiento || ModoCapturas.activo)) { contexto in
            let t = contexto.date.timeIntervalSinceReferenceDate
            Canvas { c, lado in
                c.fill(Path(CGRect(origin: .zero, size: lado)), with: .linearGradient(
                    Gradient(colors: [Color(red: 0.027, green: 0.059, blue: 0.157), Color(red: 0.051, green: 0.102, blue: 0.251),
                                      Color(red: 0.086, green: 0.153, blue: 0.353), Color(red: 0.11, green: 0.188, blue: 0.4)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: lado.height)))
                var g = Aleatorio(semilla: semilla)
                for _ in 0..<130 {
                    let x = g.siguiente() * lado.width
                    let y = pow(g.siguiente(), 1.6) * lado.height
                    let r = [0.6, 0.8, 0.9, 1.1, 1.4][Int(g.siguiente() * 5) % 5]
                    let fase = g.siguiente() * 6.28
                    let base = (0.35 + g.siguiente() * 0.6) * (1 - y / lado.height * 0.6)
                    let titila = reducirMovimiento ? 1 : 0.75 + 0.25 * sin(t * 0.9 + fase)
                    c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                           with: .color(.white.opacity(base * titila)))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct ConstelacionTemas: View {
    var cuantas: Int
    var encendidas: Int

    var body: some View {
        Canvas { c, lado in
            let puntos = Self.puntos(cuantas, en: lado)
            var linea = Path()
            for (i, p) in puntos.enumerated() where i < encendidas {
                if i == 0 { linea.move(to: p) } else { linea.addLine(to: p) }
            }
            c.stroke(linea, with: .color(Color(red: 1, green: 0.886, blue: 0.627).opacity(0.45)), lineWidth: 1)
            for (i, p) in puntos.enumerated() {
                if i < encendidas {
                    c.fill(Path(ellipseIn: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16)), with: .color(Color.ambar.opacity(0.22)))
                    c.fill(Estrella.camino(centro: p, radio: 6), with: .color(Color(red: 1, green: 0.824, blue: 0.478)))
                } else {
                    c.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(.white.opacity(0.45)))
                }
            }
        }
        .accessibilityHidden(true)
    }

    static func puntos(_ n: Int, en lado: CGSize) -> [CGPoint] {
        guard n > 0 else { return [] }
        var g = Aleatorio(semilla: UInt64(40 + n))
        return (0..<n).map { i in
            let x = n == 1 ? 0.5 : 0.06 + 0.88 * Double(i) / Double(n - 1)
            let y = 0.2 + 0.6 * g.siguiente()
            return CGPoint(x: x * lado.width, y: y * lado.height)
        }
    }
}

enum Estrella {
    static func camino(centro c: CGPoint, radio r: CGFloat) -> Path {
        var p = Path()
        for i in 0..<10 {
            let angulo = -Double.pi / 2 + Double(i) * .pi / 5
            let radio = i.isMultiple(of: 2) ? r : r * 0.45
            let punto = CGPoint(x: c.x + cos(angulo) * radio, y: c.y + sin(angulo) * radio)
            if i == 0 { p.move(to: punto) } else { p.addLine(to: punto) }
        }
        p.closeSubpath()
        return p
    }
}

struct Aleatorio {
    private var estado: UInt64
    init(semilla: UInt64) { estado = semilla &* 0x9E3779B97F4A7C15 | 1 }

    mutating func siguiente() -> Double {
        estado ^= estado << 13
        estado ^= estado >> 7
        estado ^= estado << 17
        return Double(estado % 1_000_000) / 1_000_000
    }
}
