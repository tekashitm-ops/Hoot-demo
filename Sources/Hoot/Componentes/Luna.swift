import SwiftUI

struct FormaLuna: Shape {
    var parte: Double

    var animatableData: Double {
        get { parte }
        set { parte = newValue }
    }

    func path(in r: CGRect) -> Path {
        let radio = min(r.width, r.height) / 2
        let c = CGPoint(x: r.midX, y: r.midY)
        let k = min(max(parte, 0), 1)
        var p = Path()
        if k <= 0.001 { return p }
        if k >= 0.999 {
            p.addEllipse(in: CGRect(x: c.x - radio, y: c.y - radio, width: radio * 2, height: radio * 2))
            return p
        }

        p.addArc(center: c, radius: radio, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)

        let ancho = max(abs(cos(.pi * k)), 0.0001)
        let elipse = CGAffineTransform(translationX: c.x, y: c.y).scaledBy(x: ancho, y: 1).translatedBy(x: -c.x, y: -c.y)
        p.addArc(center: c, radius: radio, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: k < 0.5,
                 transform: elipse)
        p.closeSubpath()
        return p
    }
}

struct Luna: View {

    var parte: Double
    var tamano: CGFloat

    var brillo: Bool? = nil

    private static let crateres: [(x: CGFloat, y: CGFloat, r: CGFloat)] =
        [(0.64, 0.36, 0.11), (0.70, 0.66, 0.08), (0.44, 0.62, 0.07), (0.50, 0.30, 0.05), (0.80, 0.50, 0.05)]

    var body: some View {
        let llena = brillo ?? (parte >= 0.999)
        ZStack {
            Circle().fill(Color.lunaSombra)
            Circle().strokeBorder(Color.lunaAro, lineWidth: max(1, tamano / 34))
            FormaLuna(parte: parte).fill(
                RadialGradient(colors: Color.lunaLuz, center: UnitPoint(x: 0.38, y: 0.34), startRadius: 0,
                               endRadius: tamano * 0.75))
            if tamano >= 28 {
                Canvas { contexto, lado in
                    for c in Self.crateres {
                        let d = lado.width * c.r * 2
                        contexto.fill(Path(ellipseIn: CGRect(x: lado.width * c.x - d / 2, y: lado.height * c.y - d / 2,
                                                            width: d, height: d)),
                                      with: .color(Color.lunaCrater.opacity(0.28)))
                    }
                }
                .mask(FormaLuna(parte: parte))
            }
        }
        .frame(width: tamano, height: tamano)
        .shadow(color: Color.ambar.opacity(llena ? 0.75 : 0), radius: tamano * 0.16)
        .accessibilityElement()
        .accessibilityLabel(Self.nombre(parte))
    }

    static func nombre(_ parte: Double) -> String {
        switch Int((min(max(parte, 0), 1) * 4).rounded()) {
        case 0: L("Luna nueva: aún no te ha preguntado", "New moon: not quizzed yet", "Luna nuova: non ti ha ancora interrogato")
        case 1: L("Luna creciente: algo sabes", "Crescent moon: you know some", "Luna crescente: qualcosa sai")
        case 2: L("Cuarto creciente: bien un día", "First quarter: right on one day", "Primo quarto: bene un giorno")
        case 3: L("Luna gibosa: bien otro día", "Gibbous moon: right on another day", "Luna gibbosa: bene un altro giorno")
        default: L("Luna llena: lo sabes", "Full moon: you know it", "Luna piena: lo sai")
        }
    }
}

struct FilaLunas: View {
    var partes: [Double]
    var tamano: CGFloat
    var hueco: CGFloat = 4

    var body: some View {
        HStack(spacing: hueco) {
            ForEach(Array(partes.enumerated()), id: \.offset) { _, parte in
                Luna(parte: parte, tamano: tamano)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("\(partes.filter { $0 >= 0.999 }.count) de \(partes.count) temas sabidos",
                              "\(partes.filter { $0 >= 0.999 }.count) of \(partes.count) topics known",
                              "\(partes.filter { $0 >= 0.999 }.count) di \(partes.count) argomenti saputi"))
    }
}
