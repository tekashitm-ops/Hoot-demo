import SwiftUI

struct TextoMarkdown: View {
    var texto: String
    var color: Color
    var esquema = false

    enum Bloque: Hashable {
        case titulo(String, Int)
        case vineta(String, Int)
        case numerada(String, String, Int)
        case parrafo(String)
    }

    static func bloques(_ texto: String) -> [Bloque] {
        var r: [Bloque] = []
        for linea in texto.components(separatedBy: .newlines) {
            let sinFinal = linea.replacingOccurrences(of: "\t", with: "  ")
            let espacios = sinFinal.prefix { $0 == " " }.count
            let t = sinFinal.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { continue }
            let nivel = min(3, espacios / 2)
            if t.hasPrefix("#") {
                let hashes = t.prefix { $0 == "#" }.count
                let contenido = t.dropFirst(hashes).trimmingCharacters(in: .whitespaces)
                if !contenido.isEmpty { r.append(.titulo(contenido, hashes)) }
            } else if t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("• ") {
                r.append(.vineta(String(t.dropFirst(2)), nivel))
            } else if let rango = t.range(of: #"^\d+[\.\)]\s"#, options: .regularExpression) {
                let numero = String(t[rango]).trimmingCharacters(in: .whitespaces)
                r.append(.numerada(String(t[rango.upperBound...]), numero, nivel))
            } else {
                r.append(.parrafo(t))
            }
        }
        return r
    }

    var body: some View {
        let lista = Self.bloques(texto)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lista.enumerated()), id: \.offset) { i, bloque in
                vista(bloque, primero: i == 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func vista(_ b: Bloque, primero: Bool) -> some View {
        switch b {
        case .titulo(let t, let nivel):
            Text(t.conMarkdown)
                .font(nivel <= 1 ? .title2.bold() : (nivel == 2 ? .title3.bold() : .headline))
                .foregroundStyle(Color.primary)
                .padding(.top, primero ? 0 : 18)
                .padding(.bottom, 2)
                .accessibilityAddTraits(.isHeader)
        case .vineta(let t, let nivel):
            fila(nivel: nivel) {
                if esquema && nivel == 0 {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color)
                        .frame(width: 10, height: 10)
                } else {
                    Circle()
                        .fill(nivel == 0 ? color : color.opacity(0.55))
                        .frame(width: nivel == 0 ? 7 : 6, height: nivel == 0 ? 7 : 6)
                }
            } texto: {
                Text(t.conMarkdown)
                    .font(esquema && nivel == 0 ? .body.weight(.semibold) : .body)
            }
        case .numerada(let t, let n, let nivel):
            fila(nivel: nivel) {

                Text(n)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.primary)
            } texto: {
                Text(t.conMarkdown)
            }
        case .parrafo(let t):
            Text(t.conMarkdown)
                .font(.body)
        }
    }

    private func fila<Marca: View, Contenido: View>(nivel: Int, @ViewBuilder marca: () -> Marca, @ViewBuilder texto: () -> Contenido) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if esquema {
                ForEach(0..<nivel, id: \.self) { _ in
                    Rectangle()
                        .fill(color.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.leading, 4)
                        .alignmentGuide(.firstTextBaseline) { d in d[.top] + 14 }
                }
            } else if nivel > 0 {
                Color.clear.frame(width: CGFloat(nivel) * 18, height: 1)
            }
            marca()
                .frame(minWidth: 12)
            texto()
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
