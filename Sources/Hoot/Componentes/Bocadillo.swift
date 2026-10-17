import SwiftUI

struct Bocadillo: View {
    enum Pico { case izquierda, derecha, arribaIzquierda, arribaDerecha }

    var texto: String
    var pico: Pico = .izquierda

    var body: some View {
        Text(texto)
            .font(.body.weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(Color.tintaBocadillo)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background {
                FormaBocadillo(pico: pico)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.18), radius: 13, y: 8)
            }
            .accessibilityElement()
            .accessibilityLabel(L("Hoot dice: \(texto)", "Hoot says: \(texto)", "Hoot dice: \(texto)"))
    }
}

struct FormaBocadillo: Shape {
    var pico: Bocadillo.Pico
    var radio: CGFloat = 22

    func path(in r: CGRect) -> Path {
        var p = Path(roundedRect: r, cornerRadius: radio, style: .continuous)
        let lado: CGFloat = 18
        let centro: CGPoint = switch pico {
        case .izquierda: CGPoint(x: r.minX + 3, y: r.minY + min(35, r.height / 2))
        case .derecha: CGPoint(x: r.maxX - 3, y: r.minY + min(35, r.height / 2))
        case .arribaIzquierda: CGPoint(x: r.minX + 49, y: r.minY + 3)
        case .arribaDerecha: CGPoint(x: r.maxX - 49, y: r.minY + 3)
        }
        let giro = CGAffineTransform(translationX: centro.x, y: centro.y).rotated(by: .pi / 4)
        p.addPath(Path(roundedRect: CGRect(x: -lado / 2, y: -lado / 2, width: lado, height: lado), cornerRadius: 3),
                  transform: giro)
        return p
    }
}
