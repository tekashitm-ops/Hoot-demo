import SwiftUI

struct HootDice: View {
    var frase: String
    var gesto: GestoLobo = .normal
    var tamano: CGFloat = 150
    var loboALaDerecha = false

    var paraguasSiLlueve = true

    var saludo: GestoLobo? = nil

    @Environment(\.dynamicTypeSize) private var letra
    @Environment(Almacen.self) private var almacen: Almacen?

    private var conParaguas: Bool {
        guard paraguasSiLlueve, let almacen else { return false }
        return TiempoReal.compartido.escena(fijado: TiempoFijo(rawValue: almacen.ajustes.tiempoFondo) ?? .real).caeAlgo
    }

    var body: some View {
        let lobo = LoboInteractivo(tamano: tamano, gesto: gesto, mirada: CGPoint(x: loboALaDerecha ? -0.35 : 0.35, y: 0),
                                   saludo: saludo, paraguasSiLlueve: paraguasSiLlueve)
        Group {
            if letra.isAccessibilitySize {
                VStack(alignment: loboALaDerecha ? .trailing : .leading, spacing: 2) {
                    lobo
                    Bocadillo(texto: frase, pico: loboALaDerecha ? .arribaDerecha : .arribaIzquierda)
                }
                .frame(maxWidth: .infinity, alignment: loboALaDerecha ? .trailing : .leading)
            } else {
                HStack(alignment: .center, spacing: 4) {
                    if !loboALaDerecha { lobo }
                    Bocadillo(texto: frase, pico: loboALaDerecha ? .derecha : .izquierda)
                        .frame(maxWidth: .infinity, alignment: loboALaDerecha ? .trailing : .leading)
                    if loboALaDerecha { lobo }
                }
            }
        }
        .padding(.top, conParaguas ? tamano * 0.34 : 0)
        .animation(Diseno.muelle, value: frase)
    }
}

extension View {

    func botonAmbar() -> some View {
        buttonStyle(.glassProminent)
            .tint(Color.ambar)
            .foregroundStyle(Color.sobreAmbar)
    }
}
