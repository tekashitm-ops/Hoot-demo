import SwiftUI

struct UsoVista: View {
    @State private var ia = ClaudeIA.compartida
    @State private var planes = ModoCapturas.activo && ModoCapturas.valor("-planes") != nil

    private var uso: ClaudeIA.Uso { ia.usoDelMes }
    private var conClaude: Bool { ClaudeIA.activa || ModoCapturas.activo }
    private var porcentaje: Int { Int((ia.fraccion * 100).rounded()) }

    var body: some View {
        List {
            if conClaude {
                resumen
            } else {
                Section {
                    LabeledContent(L("Tu plan", "Your plan", "Il tuo piano"), value: L("Gratis", "Free", "Gratis"))
                } footer: {
                    Text(L("Con Apple Intelligence, en tu iPhone y sin límite.", "With Apple Intelligence, on your iPhone, with no limit.",
                           "Con Apple Intelligence, sul tuo iPhone e senza limiti."))
                }
            }
            Section {
                Button(L("Mejorar el plan", "Upgrade Plan", "Migliora il piano")) { planes = true }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(AjusteCuenta.uso.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $planes) { PlanesVista() }
    }

    private var porGrupo: [(grupo: GrupoUso, dolares: Double)] {
        var d: [GrupoUso: Double] = [:]
        for (k, v) in uso.porTarea { if let t = TareaIA(rawValue: k) { d[t.grupo, default: 0] += v } }
        return d.map { ($0.key, $0.value) }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
    }

    private var estimacion: String {
        if let dia = ia.diaEnQueSeAcaba, let fecha = Calendar.current.date(bySetting: .day, value: dia, of: Reloj.ahora) {
            let f = fecha.formatted(.dateTime.day().month(.wide).locale(localeActual))
            return L("A este ritmo, se acaba el \(f)", "At this pace, it runs out on \(f)", "A questo ritmo, finisce il \(f)")
        }
        return L("Te llega para todo el mes", "It lasts the whole month", "Ti basta per tutto il mese")
    }

    private var renueva: String {
        let cal = Calendar.current
        let inicio = cal.date(from: cal.dateComponents([.year, .month], from: Reloj.ahora)) ?? Reloj.ahora
        let siguiente = cal.date(byAdding: .month, value: 1, to: inicio) ?? Reloj.ahora
        return siguiente.formatted(.dateTime.day().month(.wide).locale(localeActual))
    }

    private var nombrePlan: String { L("Prueba con Claude", "Claude trial", "Prova con Claude") }

    private func parte(_ dolares: Double) -> Int { Int((dolares / max(uso.total, 0.0001) * 100).rounded()) }

    @ViewBuilder
    private var resumen: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(nombrePlan).font(.headline)
                        Spacer()
                        Text("\(porcentaje) %").font(.headline).monospacedDigit().contentTransition(.numericText())
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(nombrePlan).font(.headline)
                        Text("\(porcentaje) %").font(.headline).monospacedDigit().contentTransition(.numericText())
                    }
                }
                BarraUso(partes: porGrupo.map { ($0.grupo.color.color, $0.dolares / max(ia.tope, 0.01)) })
                    .frame(height: 22)
                Leyenda(grupos: porGrupo.map(\.grupo))
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L("Usado el \(porcentaje) % de este mes", "\(porcentaje)% used this month", "Usato il \(porcentaje)% di questo mese"))
        }
        Section {
            Label(estimacion, systemImage: "calendar")
            LabeledContent(L("Se renueva", "Renews", "Si rinnova"), value: renueva)
        }
        if !porGrupo.isEmpty {
            Section(L("En qué se usa", "Where it goes", "Dove si usa")) {
                ForEach(porGrupo, id: \.grupo) { g in
                    FilaAjuste(simbolo: g.grupo.simbolo, color: g.grupo.color, titulo: g.grupo.nombre, valor: "\(parte(g.dolares)) %")
                }
            }
        }
        if uso.respuestasApple > 0 {
            Section {
                LabeledContent(L("Con Apple Intelligence", "With Apple Intelligence", "Con Apple Intelligence"),
                               value: L("\(uso.respuestasApple) respuestas", "\(uso.respuestasApple) answers", "\(uso.respuestasApple) risposte"))
            } footer: {
                Text(L("No gastan uso.", "They don't use your plan.", "Non consumano il piano."))
            }
        }
    }

}

private struct BarraUso: View {
    var partes: [(Color, Double)]

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(partes.enumerated()), id: \.offset) { _, p in
                    Rectangle().fill(p.0).frame(width: max(2, geo.size.width * min(p.1, 1)))
                }
                Spacer(minLength: 0)
            }
            .background(Color(.tertiarySystemFill))
            .clipShape(Capsule())
        }
    }
}

private struct Leyenda: View {
    var grupos: [GrupoUso]

    var body: some View {

        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { puntos }
            VStack(alignment: .leading, spacing: 4) { puntos }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var puntos: some View {
        ForEach(grupos) { g in
            HStack(spacing: 5) {
                Circle().fill(g.color.color).frame(width: 8, height: 8)
                Text(g.nombre)
            }
        }
    }
}

struct PlanesVista: View {
    @Environment(\.dismiss) private var cerrar

    private struct Plan: Identifiable {
        var id: String { nombre }
        var nombre: String
        var cosas: [String]
        var actual = false
    }

    private var planes: [Plan] {
        [
            Plan(nombre: L("Gratis", "Free", "Gratis"),
                 cosas: [L("Apple Intelligence en tu iPhone", "Apple Intelligence on your iPhone", "Apple Intelligence sul tuo iPhone"),
                         L("Todo Hoot, sin anuncios", "All of Hoot, no ads", "Tutto Hoot, senza pubblicità")],
                 actual: !ClaudeIA.activa && !ModoCapturas.activo),
            Plan(nombre: "Plus",
                 cosas: [L("Hoot con la IA de Claude", "Hoot with Claude's AI", "Hoot con l'IA di Claude"),
                         L("Te ayuda con las fotos de tus ejercicios", "Helps with photos of your exercises", "Ti aiuta con le foto dei tuoi esercizi"),
                         L("Hablar con Hoot como en una llamada", "Talk to Hoot like on a call", "Parla con Hoot come in una chiamata"),
                         L("Uso para todo el mes", "Usage for the whole month", "Utilizzo per tutto il mese")],
                 actual: ClaudeIA.activa || ModoCapturas.activo),
            Plan(nombre: "Max",
                 cosas: [L("El doble de uso que Plus", "Twice the usage of Plus", "Il doppio dell'utilizzo di Plus"),
                         L("La IA más lista para lo más difícil", "The smartest AI for the hardest things", "L'IA più intelligente per le cose più difficili")]),
            Plan(nombre: L("Familia", "Family", "Famiglia"),
                 cosas: [L("Plus para hasta 4 hijos", "Plus for up to 4 children", "Plus per un massimo di 4 figli")]),
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(planes) { p in
                    Section {
                        ForEach(p.cosas, id: \.self) { c in
                            Label(c, systemImage: "checkmark").foregroundStyle(.primary)
                        }
                    } header: {
                        HStack {
                            Text(p.nombre).font(.title3.weight(.bold)).foregroundStyle(.primary).textCase(nil)
                            if p.actual {
                                Text(L("Ahora", "Current", "Attuale"))
                                    .font(.caption.weight(.semibold))
                                    .textCase(nil)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.acento.opacity(0.15)))
                            }
                        }
                    }
                }

                Section {
                    Button {} label: {
                        Text(L("Muy pronto", "Coming Soon", "Prossimamente")).font(.headline).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(true)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } footer: {
                    Text(L("Llegan con Hoot al App Store.", "Arriving with Hoot on the App Store.", "Arrivano con Hoot sull'App Store."))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L("Planes", "Plans", "Piani"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar() } }
            }
        }
    }
}
