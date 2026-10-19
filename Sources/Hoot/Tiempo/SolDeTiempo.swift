import Foundation

nonisolated enum SolDeTiempo {

    static let centro = SIMD2<Float>(1 - 273.0 / 1186, 225.0 / 1186)

    static let alcance: Float = 1.06

    static func luz(_ dx: Float, _ dy: Float) -> SIMD3<Float> {
        let r = (dx * dx + dy * dy).squareRoot()
        var total = Tabla.resplandor.en(r)

        if r < Tabla.destellos.hasta {
            var suma: Float = 0
            for (ux, uy) in direccionesDestellos {
                let largo = dx * ux + dy * uy
                guard largo > 0 else { continue }
                let lado = (dy * ux - dx * uy) / destellosSigma
                suma += exp(-0.5 * lado * lado)
            }
            total += Tabla.destellos.en(r) * suma
        }

        let ax = dx - anilloCentro.x, ay = dy - anilloCentro.y
        let da = (ax * ax + ay * ay).squareRoot()
        if da > 0.25 && da < 0.62 {
            let c = ax / da, s = ay / da
            for k in 0..<3 {
                let f = anilloFuerza[k], rr = anilloRadio[k]
                let fuerza = max(0, f.x + f.y * c + f.z * s)
                let d = (da - (rr.x + rr.y * c + rr.z * s)) / anilloSigma[k]
                total[k] += fuerza * exp(-0.5 * d * d)
            }
        }

        for p in manchaPartes {
            let u = (dx - manchaCentro.x) / p.sx, v = (dy - manchaCentro.y) / p.sy
            let q = u * u + v * v
            if q < 30 { total += p.luz * exp(-0.5 * q) }
        }

        total += Tabla.disco.en(distancia(dx, dy, discoCentro))
        total += Tabla.burbuja.en(distancia(dx, dy, burbujaCentro))
        let b = distancia(dx, dy, brilloCentro) / brilloSigma
        if b < 6 { total += brilloLuz * exp(-0.5 * b * b) }
        let aro = min(max((aroRadio - distancia(dx, dy, aroCentro)) / aroBorde + 0.5, 0), 1)
        total += aroLuz * aro

        let peso = suave(lejanoDesde.0, lejanoDesde.1, r) * (1 - suave(lejanoHasta.0, lejanoHasta.1, dy))
        if peso > 0 {
            let t: [Float] = [1, dx, dy, dx * dx, dx * dy, dy * dy]
            for k in 0..<3 {
                var v: Float = 0
                for i in 0..<6 { v += lejano[k][i] * t[i] }
                total[k] += v * peso
            }
        }
        return total.clamped(lowerBound: .zero, upperBound: .one)
    }

    static func luz(enPantalla x: Float, _ y: Float) -> SIMD3<Float> {
        luz(centro.x - x, y - centro.y)
    }

    static func luzMaxima(enAltura y: Float) -> Float {
        var mayor: Float = 0
        for i in 0...40 {
            let l = luz(enPantalla: Float(i) / 40, y)
            mayor = max(mayor, (l.x + l.y + l.z) / 3)
        }
        return mayor
    }

    static func pixeles(ancho: Int) -> (alto: Int, datos: [UInt8]) {
        let alto = Int((Float(ancho) * alcance).rounded(.up))
        var datos = [UInt8](repeating: 255, count: ancho * alto * 4)
        let w = Float(ancho)
        for j in 0..<alto {
            let y = (Float(j) + 0.5) / w
            for i in 0..<ancho {
                let l = luz(enPantalla: (Float(i) + 0.5) / w, y)
                let k = (j * ancho + i) * 4
                datos[k] = UInt8(l.x * 255 + 0.5)
                datos[k + 1] = UInt8(l.y * 255 + 0.5)
                datos[k + 2] = UInt8(l.z * 255 + 0.5)
            }
        }
        return (alto, datos)
    }

    private static let direccionesDestellos: [(Float, Float)] = (0..<6).map { k in
        let a = (destellosAngulo + 60 * Float(k)) * .pi / 180
        return (cos(a), sin(a))
    }

    private static func distancia(_ dx: Float, _ dy: Float, _ c: SIMD2<Float>) -> Float {
        let x = dx - c.x, y = dy - c.y
        return (x * x + y * y).squareRoot()
    }

    private static func suave(_ a: Float, _ b: Float, _ v: Float) -> Float {
        let t = min(max((v - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }

    nonisolated struct Tabla: Sendable {
        let paso: Float
        let valores: [SIMD3<Float>]
        let hasta: Float

        init(_ puntos: [(Float, SIMD3<Float>)], pasos: Int = 1024) {
            hasta = puntos.last?.0 ?? 0
            paso = hasta / Float(pasos)
            var v: [SIMD3<Float>] = []
            var j = 0
            for i in 0...pasos {
                let r = Float(i) * paso
                while j + 1 < puntos.count - 1 && puntos[j + 1].0 < r { j += 1 }
                let (r0, a) = puntos[j], (r1, b) = puntos[min(j + 1, puntos.count - 1)]
                let t = r1 > r0 ? min(max((r - r0) / (r1 - r0), 0), 1) : 0
                v.append(a + (b - a) * t)
            }
            valores = v
        }

        func en(_ r: Float) -> SIMD3<Float> {
            guard r < hasta, paso > 0 else { return .zero }
            let x = r / paso
            let i = Int(x), t = x - Float(i)
            guard i + 1 < valores.count else { return valores[valores.count - 1] }
            return valores[i] + (valores[i + 1] - valores[i]) * t
        }

        static let resplandor = Tabla(SolDeTiempo.resplandor, pasos: 2048)
        static let destellos = Tabla(SolDeTiempo.destellos)
        static let disco = Tabla(SolDeTiempo.disco, pasos: 256)
        static let burbuja = Tabla(SolDeTiempo.burbuja, pasos: 256)
    }
}
