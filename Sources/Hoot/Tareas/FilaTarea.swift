import SwiftUI

struct FilaTarea: View {
    var tarea: Tarea
    var asignatura: Asignatura?
    var soloLectura = false

    var mostrarVence = true
    var alAlternar: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var tamanoLetra

    var body: some View {

        HStack(alignment: tamanoLetra.isAccessibilitySize ? .top : .center, spacing: 12) {
            if soloLectura {
                Image(systemName: tarea.hecha ? "checkmark.circle.fill" : "hourglass")
                    .font(.title3)
                    .foregroundStyle(tarea.hecha ? AnyShapeStyle(Color.hecho) : AnyShapeStyle(EstiloSecundario()))
                    .frame(width: 44, height: 44)
                    .accessibilityLabel(tarea.hecha ? L("Hecha", "Done", "Fatto") : L("Pendiente", "To do", "Da fare"))
            } else {
                Casilla(marcada: tarea.hecha, color: asignatura?.color ?? .indigo, etiqueta: tarea.titulo, accion: alAlternar)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if tarea.tipo != .deberes {
                        Image(systemName: tarea.tipo.simbolo)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(asignatura?.color.color ?? Color.acento)
                            .accessibilityLabel(tarea.tipo.nombre)
                    }
                    Text(tarea.titulo)
                        .font(.body)
                        .foregroundStyle(tarea.hecha ? AnyShapeStyle(EstiloSecundario()) : AnyShapeStyle(Color.primary))
                        .strikethrough(tarea.hecha)
                        .lineLimit(tamanoLetra.isAccessibilitySize ? nil : 2)
                }
                if let asignatura {
                    Text(asignatura.nombre)
                        .font(.subheadline)
                        .textoSecundario()
                        .lineLimit(tamanoLetra.isAccessibilitySize ? nil : 1)
                }
                if tamanoLetra.isAccessibilitySize && mostrarVence {
                    Vence(fecha: tarea.entrega, hecha: tarea.hecha)
                        .lineLimit(nil)
                }
            }
            Spacer(minLength: 8)
            if !tamanoLetra.isAccessibilitySize && mostrarVence {
                Vence(fecha: tarea.entrega, hecha: tarea.hecha)
            }
        }
        .contentShape(Rectangle())
    }
}
