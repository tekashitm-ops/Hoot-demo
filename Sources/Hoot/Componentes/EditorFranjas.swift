import SwiftUI

struct EditorFranjas: View {
    @Binding var datos: DatosEscolares
    @Environment(\.dismiss) private var cerrar
    @Environment(\.dynamicTypeSize) private var tamanoLetra
    @State private var quitando: IndexSet?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($datos.franjas) { $f in
                        let nombre = f.esRecreo ? L("Recreo", "Break", "Ricreazione") : L("Clase", "Class", "Lezione")
                        let disposicion = tamanoLetra.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout())
                        disposicion {
                            Label(nombre, systemImage: f.esRecreo ? "figure.play" : "book.closed")
                                .labelStyle(.titleAndIcon)
                            if !tamanoLetra.isAccessibilitySize { Spacer() }
                            HStack {
                                SelectorHora(titulo: L("\(nombre), empieza", "\(nombre), starts", "\(nombre), inizia"), minutos: $f.inicio, conEtiqueta: false)
                                Text("–").textoSecundario().accessibilityHidden(true)
                                SelectorHora(titulo: L("\(nombre), termina", "\(nombre), ends", "\(nombre), finisce"), minutos: $f.fin, conEtiqueta: false)
                            }
                        }
                    }
                    .onDelete { indices in quitando = indices }
                }
                Section {
                    Button(L("Añadir una hora de clase", "Add a class period", "Aggiungi un'ora di lezione"), systemImage: "plus") { anadir(recreo: false) }
                    Button(L("Añadir un recreo", "Add a break", "Aggiungi una ricreazione"), systemImage: "plus") { anadir(recreo: true) }
                }
            }
            .navigationTitle(L("Horas", "Periods", "Orari"))
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(L("¿Quitar esta franja?", "Remove this period?", "Togliere questa fascia?"),
                                isPresented: Binding(get: { quitando != nil }, set: { if !$0 { quitando = nil } }),
                                titleVisibility: .visible) {
                Button(L("Quitar", "Remove", "Togli"), role: .destructive) {
                    guard let indices = quitando else { return }
                    let quitadas = indices.map { datos.franjas[$0] }
                    conMuelle {
                        datos.franjas.remove(atOffsets: indices)
                        datos.horario.removeAll { c in quitadas.contains { $0.inicio == c.inicio } }
                    }
                    quitando = nil
                }
            } message: {
                Text(L("También se quitan las clases de esa hora de toda la semana.", "The classes at that time are removed from the whole week too.", "Si tolgono anche le lezioni di quell'ora per tutta la settimana."))
            }
            .onChange(of: datos.franjas) { viejas, nuevas in

                for n in nuevas {
                    guard let v = viejas.first(where: { $0.id == n.id }), v.inicio != n.inicio || v.fin != n.fin else { continue }
                    for i in datos.horario.indices where datos.horario[i].inicio == v.inicio {
                        datos.horario[i].inicio = n.inicio
                        datos.horario[i].fin = n.fin
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { ordenar(); cerrar() }
                }
            }
        }
    }

    private func anadir(recreo: Bool) {
        let ultimo = datos.franjas.map(\.fin).max() ?? 8 * 60 + 30
        datos.franjas.append(Franja(inicio: ultimo, fin: ultimo + (recreo ? 30 : 55), esRecreo: recreo))
    }

    private func ordenar() {
        datos.franjas.sort { $0.inicio < $1.inicio }
    }
}

struct SelectorHora: View {
    var titulo: String
    @Binding var minutos: Int
    var conEtiqueta = true

    var body: some View {
        let selector = DatePicker(titulo, selection: Binding(
            get: { DatosEscolares.fecha(Reloj.ahora, minutos: minutos) },
            set: { minutos = DatosEscolares.minutos($0) }
        ), displayedComponents: .hourAndMinute)
        .environment(\.locale, localeActual)
        if conEtiqueta {
            selector
        } else {
            selector.labelsHidden()
        }
    }
}
