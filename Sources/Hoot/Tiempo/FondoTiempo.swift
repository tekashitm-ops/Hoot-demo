import SwiftUI
import UIKit

struct FondoTiempo: View {

    var vidaEnHoja = false

    var sinVelo = false
    @Environment(Almacen.self) private var almacen
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento
    @State private var enHoja: Bool?

    var body: some View {
        let escena = TiempoReal.compartido.escena(fijado: TiempoFijo(rawValue: almacen.ajustes.tiempoFondo) ?? .real)
        let tinte = RGBVida(escena.tinteVelo).color
        let velo = sinVelo ? Escena.sinVelo : escena.velo
        let conVida = enHoja == false || (enHoja == true && vidaEnHoja)
        ZStack {
            lienzo(escena)
            if escena.tieneSol && conVida {
                LuzDelSol()
                    .transition(.opacity)
            }
            if conVida {

                CapaDeVida(vida: escena.vida, colores: escena.particulas, oscuro: escena.noche,
                           capa: enHoja == true ? .muestra : .app, velo: velo, tinteVelo: tinte)

                    .id("\(escena.vida.rawValue)-\(escena.noche)-\(Desarrollo.compartido.claveVida)")
                    .transition(.opacity)
            } else {
                LinearGradient(stops: velo.map { Gradient.Stop(color: tinte.opacity($0.alfa), location: $0.y) },
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .background { DetectorDeHoja { enHoja = $0 } }
        .animation(Diseno.muelleLento, value: escena)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func lienzo(_ e: Escena) -> some View {
        if let m = e.malla, m.count == 4 {

            TimelineView(.animation(minimumInterval: 1 / 30, paused: menosMovimiento)) { t in
                MallaEstadio.malla(colores: m.prefix(3).map { Color(rgbDeVida: $0) }, base: Color(rgbDeVida: m[3]),
                                   t: Float(menosMovimiento ? 0 : t.date.timeIntervalSinceReferenceDate))
            }
        } else {
            LinearGradient(colors: e.cielo.map { Color(rgbDeVida: $0) }, startPoint: .top, endPoint: .bottom)
        }
    }
}

enum MallaEstadio {
    static func malla(colores: [Color], base: Color, t s: Float) -> MeshGradient {
        let a = colores.count == 3 ? colores : [base, base, base]
        let m = a.map { $0.mix(with: base, by: 0.55) }
        return MeshGradient(
            width: 3, height: 4,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.24 + 0.03 * sin(s * 0.5)],
                [0.5 + 0.10 * sin(s * 0.33), 0.28 + 0.05 * cos(s * 0.41)],
                [1, 0.22 + 0.03 * cos(s * 0.47)],
                [0, 0.50], [0.5 + 0.06 * cos(s * 0.29), 0.54], [1, 0.48],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [a[0], a[1], a[2], a[2], a[0], a[1], m[1], m[2], m[0], base, base, base])
    }
}

struct DetectorDeHoja: UIViewRepresentable {
    let dice: (Bool) -> Void

    func makeUIView(context: Context) -> Sonda {
        let s = Sonda()
        s.dice = dice
        return s
    }

    func updateUIView(_ vista: Sonda, context: Context) {
        vista.dice = dice
    }

    final class Sonda: UIView {
        var dice: ((Bool) -> Void)?
        private var dicho: Bool?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in self?.mirar() }
        }

        private func mirar() {
            var r: UIResponder? = self
            var enHoja = false
            while let siguiente = r?.next {
                if let vc = siguiente as? UIViewController {
                    enHoja = vc.presentingViewController != nil
                    break
                }
                r = siguiente
            }
            if dicho != enHoja {
                dicho = enHoja
                dice?(enHoja)
            }
        }
    }
}

extension View {

    func sobreElCielo(sinVelo: Bool = false) -> some View {
        environment(\.colorScheme, .dark)
            .environment(\.sobreCielo, true)
            .environment(\.cieloSinVelo, sinVelo)
            .background { FondoTiempo(sinVelo: sinVelo) }
    }
}
