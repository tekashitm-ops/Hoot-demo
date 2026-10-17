import SwiftUI

struct HojaClase: View {
    var clase: Clase
    var datos: DatosEscolares
    var ahora: Date
    @Environment(\.dismiss) private var cerrar
    @ScaledMetric(relativeTo: .title2) private var ladoIcono: CGFloat = 52

    var body: some View {
        let a = datos.asignatura(clase.asignaturaID)
        let cal = calendarioActual
        let hoy = cal.startOfDay(for: ahora)
        let deEsta = datos.tareas.filter { !$0.hecha && $0.asignaturaID == clase.asignaturaID }
        let entregas = deEsta.filter { $0.tipo != .examen && cal.isDate($0.entrega, inSameDayAs: ahora) }.sorted { $0.entrega < $1.entrega }
        let examen = deEsta.filter { $0.tipo == .examen && $0.entrega >= hoy }.min { $0.entrega < $1.entrega }
        let materiales = (a?.materiales ?? []).filter { $0.dias.isEmpty || $0.dias.contains(clase.dia) }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 14) {
                        IconoAsignatura(asignatura: a, lado: ladoIcono)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(a?.nombre ?? "")
                                .font(.title2.bold())
                                .fixedSize(horizontal: false, vertical: true)
                            Text(detalle(a))
                                .font(.subheadline)
                                .textoSecundario()
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    if !entregas.isEmpty {
                        parte(L("Para entregar hoy", "Due today", "Da consegnare oggi"))
                        ForEach(entregas) { t in fila(t.titulo, simbolo: t.tipo.simbolo, color: a?.color.color ?? Color.acento) }
                    }
                    if let examen {
                        parte(L("Próximo examen", "Next test", "Prossima verifica"))
                        fila(examen.titulo, simbolo: examen.tipo.simbolo, color: a?.color.color ?? Color.acento,
                             derecha: Formato.diaRelativo(examen.entrega, desde: ahora))
                    }
                    if !materiales.isEmpty {
                        parte(L("Llevar", "Bring", "Portare"))
                        ForEach(materiales) { m in fila(m.nombre, simbolo: m.tipo.simbolo, color: a?.color.color ?? Color.acento) }
                    }
                }
                .padding(.horizontal, Diseno.margen)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { BotonCerrar { cerrar() } }
            }
        }
    }

    private func detalle(_ a: Asignatura?) -> String {
        let aula = clase.aula.isEmpty ? (a?.aula ?? "") : clase.aula
        return ["\(Formato.hora(clase.inicio))–\(Formato.hora(clase.fin))",
                aula.isEmpty ? nil : L("Aula \(aula)", "Room \(aula)", "Aula \(aula)"),
                (a?.profesor).flatMap { $0.isEmpty ? nil : $0 }]
            .compactMap { $0 }.joined(separator: " · ")
    }

    private func parte(_ titulo: String) -> some View {
        Text(titulo)
            .font(.headline)
            .padding(.top, 22)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }

    private func fila(_ texto: String, simbolo: String, color: Color, derecha: String = "") -> some View {
        HStack(spacing: 12) {
            Image(systemName: simbolo)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(texto)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if !derecha.isEmpty {
                Text(derecha)
                    .font(.subheadline.weight(.semibold))
                    .textoSecundario()
            }
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}
