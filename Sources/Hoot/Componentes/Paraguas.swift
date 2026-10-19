import SwiftUI

nonisolated enum Paraguas {
    static let inclinacion: CGFloat = -10

    static let centro = CGPoint(x: 0.48, y: -0.05)
    static let radio: CGFloat = 0.62
    static let alto: CGFloat = 0.34
    static let ondas = 4
    static let onda: CGFloat = 0.12
    static let grosor: CGFloat = 0.024
    static let colorPalo = Color(red: 0.31, green: 0.32, blue: 0.38)

    static let colorTela = Color(red: 1.0, green: 0.36, blue: 0.36)
    static let colorGajo = Color(red: 0.87, green: 0.24, blue: 0.28)

    private static let angulo = inclinacion * .pi / 180

    static let eje = CGPoint(x: -sin(angulo), y: cos(angulo))
    static let punta = CGPoint(x: centro.x - eje.x * alto, y: centro.y - eje.y * alto)

    static let agarre: CGPoint = {
        let largo = (0.79 - centro.y) / eje.y
        return CGPoint(x: centro.x + eje.x * largo, y: 0.79)
    }()

    static let brazo = CGPoint(x: agarre.x - 0.03, y: agarre.y + 0.075)

    static func colocar(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: centro.x + x * cos(angulo) - y * sin(angulo), y: centro.y + x * sin(angulo) + y * cos(angulo))
    }

    static let silueta: [CGPoint] = {
        let R = radio, h = alto
        func cubica(_ a: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
            let u = 1 - t
            return CGPoint(x: u * u * u * a.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * b.x,
                           y: u * u * u * a.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * b.y)
        }
        var puntos: [CGPoint] = []
        for i in 0...8 {
            puntos.append(cubica(colocar(-R, 0), colocar(-R, -0.62 * h), colocar(-0.58 * R, -h), colocar(0, -h), CGFloat(i) / 8))
        }
        for i in 1...8 {
            puntos.append(cubica(colocar(0, -h), colocar(0.58 * R, -h), colocar(R, -0.62 * h), colocar(R, 0), CGFloat(i) / 8))
        }
        return puntos.sorted { $0.x < $1.x }
    }()

    enum Parte {
        case tela, gajos, brillo, contera, paloDetras, paloDelante
    }

    struct Forma: Shape {
        var parte: Parte

        func path(in r: CGRect) -> Path {
            let p = { (q: CGPoint) in CGPoint(x: r.minX + q.x * r.width, y: r.minY + q.y * r.height) }
            let c = { (x: CGFloat, y: CGFloat) in p(colocar(x, y)) }
            let R = radio, h = alto
            var camino = Path()
            switch parte {
            case .tela:
                camino.move(to: c(-R, 0))
                camino.addCurve(to: c(0, -h), control1: c(-R, -0.62 * h), control2: c(-0.58 * R, -h))
                camino.addCurve(to: c(R, 0), control1: c(0.58 * R, -h), control2: c(R, -0.62 * h))
                for i in 0..<ondas {
                    let x0 = R - 2 * R * CGFloat(i) / CGFloat(ondas), x1 = R - 2 * R * CGFloat(i + 1) / CGFloat(ondas)
                    camino.addQuadCurve(to: c(x1, 0), control: c((x0 + x1) / 2, -onda * h))
                }
                camino.closeSubpath()
            case .gajos:
                for k in stride(from: 1, to: ondas, by: 2) {
                    let xa = -R + 2 * R * CGFloat(k) / CGFloat(ondas), xb = -R + 2 * R * CGFloat(k + 1) / CGFloat(ondas)
                    camino.move(to: c(0, -h))
                    camino.addQuadCurve(to: c(xa, 0), control: c(xa * 0.92, -0.72 * h))
                    camino.addQuadCurve(to: c(xb, 0), control: c((xa + xb) / 2, -onda * h))
                    camino.addQuadCurve(to: c(0, -h), control: c(xb * 0.92, -0.72 * h))
                    camino.closeSubpath()
                }
            case .brillo:
                let centro = c(-0.22 * R, -0.62 * h)
                let w = 0.30 * R * r.width, alto = 0.16 * h * r.height
                camino = Path(ellipseIn: CGRect(x: -w / 2, y: -alto / 2, width: w, height: alto))
                    .applying(CGAffineTransform(rotationAngle: (-28 + inclinacion) * .pi / 180))
                    .applying(CGAffineTransform(translationX: centro.x, y: centro.y))
            case .contera:
                camino.move(to: c(0, -h))
                camino.addLine(to: c(0, -h - 0.06))
            case .paloDetras:
                camino.move(to: p(punta))
                camino.addLine(to: p(CGPoint(x: agarre.x + eje.x * 0.10, y: agarre.y + eje.y * 0.10)))
            case .paloDelante:
                let bajo = CGPoint(x: agarre.x + eje.x * 0.10, y: agarre.y + eje.y * 0.10)
                camino.move(to: p(CGPoint(x: agarre.x - eje.x * 0.06, y: agarre.y - eje.y * 0.06)))
                camino.addLine(to: p(bajo))
                camino.addQuadCurve(to: p(CGPoint(x: bajo.x + 0.01, y: bajo.y + 0.07)),
                                    control: p(CGPoint(x: bajo.x + 0.075, y: bajo.y + 0.004)))
            }
            return camino
        }
    }
}
