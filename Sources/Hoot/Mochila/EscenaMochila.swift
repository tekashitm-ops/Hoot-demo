import SwiftUI

struct Ficha: Identifiable {
    let id = UUID()
    let simbolo: String
    let color: ColorHoot?
    let inicio: Date
    let puntos: [CGPoint]
    let golpes: [Double]

    let indiceDentro: Int

    static let paso: Double = 1 / 120

    var duracion: Double { Double(puntos.count) * Self.paso }

    func indice(en fecha: Date) -> Int {
        min(puntos.count - 1, max(0, Int(fecha.timeIntervalSince(inicio) / Self.paso)))
    }

    func entrada(en fecha: Date) -> Double {
        let quedan = duracion - fecha.timeIntervalSince(inicio)
        return max(0, min(1, quedan / 0.16))
    }

    static func lanzar(desde origen: CGPoint, boca: CGPoint, montonY: CGFloat, izquierda: CGFloat, derecha: CGFloat, alto: CGFloat) -> Ficha.Trayectoria {
        let g: CGFloat = 2600, restitucion: CGFloat = 0.34, roce: CGFloat = 0.86
        let cumbre = min(origen.y, boca.y) - alto * 0.32
        var vy = -sqrt(2 * g * max(1, origen.y - cumbre))
        let t1 = -vy / g
        let t2 = sqrt(2 * max(1, boca.y - cumbre) / g)
        var vx = (boca.x - origen.x) / (t1 + t2)
        var x = origen.x, y = origen.y
        var puntos: [CGPoint] = [origen]
        var golpes: [Double] = []
        var indiceDentro = Int.max
        var t = 0.0
        let dt = CGFloat(paso)
        while t < 3 {
            vy += g * dt
            x += vx * dt
            y += vy * dt
            t += paso
            if indiceDentro == .max && vy > 0 && y >= boca.y {
                indiceDentro = puntos.count
            }
            if indiceDentro != .max {
                if x < izquierda { x = izquierda; vx = abs(vx) * 0.6 }
                if x > derecha { x = derecha; vx = -abs(vx) * 0.6 }
                if y >= montonY && vy > 0 {
                    y = montonY
                    golpes.append(t)
                    vy = -vy * restitucion
                    vx = vx * roce + CGFloat.random(in: -45...45)
                    if abs(vy) < 90 {
                        puntos.append(CGPoint(x: x, y: y))

                        for _ in 0..<20 { puntos.append(CGPoint(x: x, y: y + 2)) }
                        break
                    }
                }
            }
            puntos.append(CGPoint(x: x, y: y))
        }
        return Trayectoria(puntos: puntos, golpes: golpes, indiceDentro: min(indiceDentro, puntos.count - 1))
    }

    struct Trayectoria {
        let puntos: [CGPoint]
        let golpes: [Double]
        let indiceDentro: Int
    }
}

struct Lanzamiento: Equatable {
    var id: Int
    var simbolo: String
    var color: ColorHoot?
    var desde: CGPoint?
}

struct EscenaMochila: View {

    var dentro: Int
    var total: Int

    var colores: [ColorHoot]
    var ultima: Lanzamiento?

    var ancho: CGFloat = 176

    @State private var fichas: [Ficha] = []
    @State private var mostradas: Int = 0
    @State private var golpes = 0
    @State private var aplastada = false
    @State private var completa = false
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    private var alto: CGFloat { ancho * 1.12 }
    private var progreso: CGFloat { total == 0 ? 0 : CGFloat(mostradas) / CGFloat(total) }

    private var montonY: CGFloat { alto * (0.40 - 0.24 * progreso) }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: fichas.isEmpty)) { contexto in
            ZStack(alignment: .topLeading) {

                Asa()
                    .stroke(ColoresMochila.oscuro, style: StrokeStyle(lineWidth: ancho * 0.045, lineCap: .round))
                    .frame(width: ancho * 0.30, height: alto * 0.12)
                    .position(x: ancho / 2, y: alto * 0.07)
                Capsule().fill(ColoresMochila.oscuro)
                    .frame(width: ancho * 0.09, height: alto * 0.62)
                    .position(x: ancho * 0.07, y: alto * 0.6)
                Capsule().fill(ColoresMochila.oscuro)
                    .frame(width: ancho * 0.09, height: alto * 0.62)
                    .position(x: ancho * 0.93, y: alto * 0.6)

                let atras = RoundedRectangle(cornerRadius: ancho * 0.28, style: .continuous)
                ZStack(alignment: .top) {
                    atras.fill(ColoresMochila.interior)
                    Monton(colores: colores, ancho: ancho * 0.76)
                        .offset(y: montonY - alto * 0.08)
                }
                .frame(width: ancho * 0.76, height: alto * 0.88)
                .clipShape(atras)
                .position(x: ancho / 2, y: alto * 0.08 + alto * 0.44)

                fichasVista(contexto.date, dentro: true)

                FrenteMochila(progreso: progreso, completa: completa, ancho: ancho, alto: alto)

                fichasVista(contexto.date, dentro: false)
            }
            .frame(width: ancho, height: alto)
            .scaleEffect(x: aplastada ? 1.035 : 1, y: aplastada ? 0.955 : 1, anchor: .bottom)
            .offset(y: completa && !reducirMovimiento ? -6 : 0)
        }
        .frame(width: ancho, height: alto)
        .padding(.top, alto * 0.3)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.75), trigger: golpes)
        .sensoryFeedback(.success, trigger: completa) { _, nueva in nueva }
        .onAppear {
            mostradas = dentro
            completa = total > 0 && dentro == total
        }
        .onChange(of: dentro) { antes, ahora in
            if ahora < antes || reducirMovimiento {
                withAnimation(Diseno.muelle) { mostradas = ahora }
                actualizarCompleta()
            }
        }
        .onChange(of: total) { _, _ in
            mostradas = min(mostradas, dentro)
            actualizarCompleta()
        }
        .onChange(of: ultima) { _, nueva in
            guard let nueva, !reducirMovimiento else { return }
            soltar(nueva)
        }
        .accessibilityElement()
        .accessibilityLabel(L("Mochila", "Backpack", "Zaino"))
        .accessibilityValue(L("\(dentro) de \(total) cosas dentro", "\(dentro) of \(total) things in", "\(dentro) di \(total) cose dentro"))
    }

    private func fichasVista(_ fecha: Date, dentro: Bool) -> some View {
        ForEach(fichas) { f in
            let i = f.indice(en: fecha)
            if (i >= f.indiceDentro) == dentro {
                let p = f.puntos[i]
                let e = f.entrada(en: fecha)
                FichaVista(simbolo: f.simbolo, color: f.color, lado: ancho * 0.22)
                    .scaleEffect(0.55 + 0.45 * e)
                    .opacity(e)
                    .position(x: p.x, y: p.y)
            }
        }
    }

    private func soltar(_ l: Lanzamiento) {
        let r = ancho * 0.11
        let izquierda = ancho * 0.12 + r, derecha = ancho * 0.88 - r
        let boca = CGPoint(x: ancho / 2 + CGFloat.random(in: -ancho * 0.08...ancho * 0.08), y: alto * 0.30)

        let origen = l.desde ?? CGPoint(x: ancho * 0.5, y: alto * 1.3)
        let tray = Ficha.lanzar(desde: origen, boca: boca, montonY: montonY - r * 0.6, izquierda: izquierda, derecha: derecha, alto: alto)
        let ficha = Ficha(simbolo: l.simbolo, color: l.color, inicio: .now, puntos: tray.puntos, golpes: tray.golpes, indiceDentro: tray.indiceDentro)
        fichas.append(ficha)

        if let t = tray.golpes.first {
            Task {
                try? await Task.sleep(for: .seconds(t))
                golpes += 1
                withAnimation(Diseno.muelleGolpe) { aplastada = true }
                try? await Task.sleep(for: .milliseconds(90))
                withAnimation(Diseno.muelleVuelta) { aplastada = false }
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(ficha.duracion))
            fichas.removeAll { $0.id == ficha.id }
            withAnimation(Diseno.muelleGesto) { mostradas = min(dentro, mostradas + 1) }
            actualizarCompleta()
        }
    }

    private func actualizarCompleta() {
        let nueva = total > 0 && mostradas >= total && dentro >= total
        if nueva != completa {
            withAnimation(nueva ? Diseno.muelleRebote : Diseno.muelle) { completa = nueva }
        }
    }
}

enum ColoresMochila {
    static let arriba = Color(red: 0.43, green: 0.42, blue: 0.95)
    static let abajo = Color(red: 0.30, green: 0.28, blue: 0.78)
    static let oscuro = Color(red: 0.22, green: 0.20, blue: 0.58)
    static let interior = Color(red: 0.16, green: 0.15, blue: 0.40)
    static let bolsillo = Color(red: 0.55, green: 0.54, blue: 0.98)
}

struct Asa: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.maxY),
                   control1: CGPoint(x: r.minX, y: r.minY - r.height * 0.3),
                   control2: CGPoint(x: r.maxX, y: r.minY - r.height * 0.3))
        return p
    }
}

struct Monton: View {
    var colores: [ColorHoot]
    var ancho: CGFloat

    var body: some View {
        let lista = colores.isEmpty ? [ColorHoot.gris] : Array(colores.suffix(6))
        ZStack(alignment: .topLeading) {
            Rectangle().fill(ColoresMochila.oscuro).offset(y: ancho * 0.06)
            ForEach(Array(lista.enumerated()), id: \.offset) { i, c in
                let w = ancho * [0.34, 0.26, 0.3, 0.22, 0.28, 0.24][i % 6]
                let x = ancho * [0.06, 0.36, 0.58, 0.18, 0.46, 0.7][i % 6]
                let y = ancho * [0.02, 0.0, 0.03, 0.06, 0.05, 0.02][i % 6]
                RoundedRectangle(cornerRadius: ancho * 0.03, style: .continuous)
                    .fill(c.color)
                    .frame(width: w, height: ancho * 0.5)
                    .rotationEffect(.degrees([-6, 4, -3, 7, -5, 3][i % 6]))
                    .offset(x: x, y: y)
            }
        }
        .frame(width: ancho, alignment: .topLeading)
    }
}

struct FichaVista: View {
    var simbolo: String
    var color: ColorHoot?
    var lado: CGFloat

    var body: some View {
        let c = color ?? .indigo
        Image(systemName: simbolo)
            .font(.system(size: lado * 0.46, weight: .semibold))
            .foregroundStyle(c.sobre)
            .frame(width: lado, height: lado)
            .background(c.color.gradient, in: Circle())
            .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
    }
}

struct FrenteMochila: View {
    var progreso: CGFloat
    var completa: Bool
    var ancho: CGFloat
    var alto: CGFloat

    var body: some View {
        let frente = RoundedRectangle(cornerRadius: ancho * 0.22, style: .continuous)
        let anchoPista = ancho * 0.46
        ZStack {
            frente
                .fill(LinearGradient(colors: [ColoresMochila.arriba, ColoresMochila.abajo], startPoint: .top, endPoint: .bottom))
                .frame(width: ancho * 0.84, height: alto * 0.62)
                .overlay(alignment: .top) {

                    Capsule().fill(.white.opacity(0.22))
                        .frame(width: ancho * 0.6, height: 2)
                        .padding(.top, 5)
                }
                .position(x: ancho / 2, y: alto * 0.36 + alto * 0.31)

            RoundedRectangle(cornerRadius: ancho * 0.12, style: .continuous)
                .fill(ColoresMochila.bolsillo.opacity(0.55))
                .frame(width: ancho * 0.6, height: alto * 0.27)
                .position(x: ancho / 2, y: alto * 0.62 + alto * 0.135)

            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.3))
                    .frame(width: anchoPista, height: 3)
                Capsule().fill(.white)
                    .frame(width: max(3, anchoPista * progreso), height: 3)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(.white)
                    .frame(width: ancho * 0.05, height: ancho * 0.09)
                    .offset(x: anchoPista * progreso - ancho * 0.025, y: ancho * 0.04)
            }
            .frame(width: anchoPista, alignment: .leading)
            .position(x: ancho / 2, y: alto * 0.62 + alto * 0.05)

            if completa {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: ancho * 0.16, weight: .semibold))
                    .foregroundStyle(.white)
                    .position(x: ancho / 2, y: alto * 0.62 + alto * 0.16)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .frame(width: ancho, height: alto)
        .allowsHitTesting(false)
    }
}
