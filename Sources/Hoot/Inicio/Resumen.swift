import SwiftUI

enum Momento: Hashable {
    case manana, tarde, noche

    static func de(_ ahora: Date, datos: DatosEscolares) -> Momento {
        let m = DatosEscolares.minutos(ahora)
        if m >= 19 * 60 + 30 || m < 5 * 60 { return .noche }
        if let ultima = datos.clases(en: ahora).last { return m < ultima.fin ? .manana : .tarde }
        return m < 13 * 60 ? .manana : .tarde
    }
}

struct FilaActividadInicio: View {
    var actividad: Actividad
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        if letra.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                Label(actividad.titulo, systemImage: actividad.simbolo)
                    .foregroundStyle(Color.primary)
                Text(actividad.inicio.map { i in actividad.fin.map { "\(Formato.hora(i))–\(Formato.hora($0))" } ?? Formato.hora(i) } ?? L("Todo el día", "All day", "Tutto il giorno"))
                    .font(.subheadline.monospacedDigit())
                    .textoSecundario()
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
        } else {
            fila
        }
    }

    private var fila: some View {
        HStack(spacing: 12) {
            Image(systemName: actividad.simbolo)
                .font(.body.weight(.semibold))
                .foregroundStyle(actividad.color.sobre)
                .frame(width: 32, height: 32)
                .background(actividad.color.color.gradient, in: Circle())
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(actividad.titulo)
                    .lineLimit(1)
                let detalle = [actividad.lugar, actividad.llevar.isEmpty ? "" : L("Llevar: ", "Bring: ", "Portare: ") + actividad.llevar.joined(separator: ", ")]
                    .filter { !$0.isEmpty }.joined(separator: " · ")
                if !detalle.isEmpty {
                    Text(detalle)
                        .font(.subheadline)
                        .textoSecundario()
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let inicio = actividad.inicio {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Formato.hora(inicio))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    if let fin = actividad.fin {
                        Text(Formato.hora(fin))
                            .font(.caption.monospacedDigit())
                            .textoSecundario()
                    }
                }
            } else {
                Text(L("Todo el día", "All day", "Tutto il giorno"))
                    .font(.subheadline)
                    .textoSecundario()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct SeparadorInicio: View {
    var body: some View {
        Divider().padding(.leading, 56)
    }
}
