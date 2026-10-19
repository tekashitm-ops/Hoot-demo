import SwiftUI

struct EditorActividad: View {
    @State var actividad: Actividad
    var esNueva = true
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var nuevaCosa = ""
    @State private var borrando = false
    @FocusState private var foco: Bool

    private enum TipoRepeticion: String, CaseIterable, Identifiable {
        case nunca, diaria, semanal, quincenal, mensual
        var id: String { rawValue }
        var nombre: String {
            switch self {
            case .nunca: Repeticion.nunca.nombre
            case .diaria: Repeticion.diaria.nombre
            case .semanal: Repeticion.semanal([]).nombre
            case .quincenal: Repeticion.quincenal([]).nombre
            case .mensual: Repeticion.mensual.nombre
            }
        }
    }

    private var tipoRepeticion: Binding<TipoRepeticion> {
        Binding {
            switch actividad.repeticion {
            case .nunca: .nunca
            case .diaria: .diaria
            case .semanal: .semanal
            case .quincenal: .quincenal
            case .mensual: .mensual
            }
        } set: { nuevo in
            let dias = diasElegidos.isEmpty ? [DatosEscolares.diaISO(actividad.fecha)] : diasElegidos
            conMuelle {
                switch nuevo {
                case .nunca: actividad.repeticion = .nunca
                case .diaria: actividad.repeticion = .diaria
                case .semanal: actividad.repeticion = .semanal(dias)
                case .quincenal: actividad.repeticion = .quincenal(dias)
                case .mensual: actividad.repeticion = .mensual
                }
            }
        }
    }

    private var diasElegidos: Set<Int> {
        switch actividad.repeticion {
        case .semanal(let d), .quincenal(let d): d
        default: []
        }
    }

    private func alternarDia(_ d: Int) {
        var dias = diasElegidos
        if dias.contains(d) { if dias.count > 1 { dias.remove(d) } } else { dias.insert(d) }
        switch actividad.repeticion {
        case .semanal: actividad.repeticion = .semanal(dias)
        case .quincenal: actividad.repeticion = .quincenal(dias)
        default: break
        }
    }

    private var avisos: [(String, Int?)] {
        [(L("Sin aviso", "None", "Nessun avviso"), nil),
         (L("A la hora", "At start", "All'inizio"), 0),
         (L("15 minutos antes", "15 minutes before", "15 minuti prima"), 15),
         (L("30 minutos antes", "30 minutes before", "30 minuti prima"), 30),
         (L("1 hora antes", "1 hour before", "1 ora prima"), 60),
         (L("1 día antes", "1 day before", "1 giorno prima"), 1440)]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: actividad.simbolo)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(actividad.color.sobre)
                            .frame(width: 40, height: 40)
                            .background(actividad.color.color.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        TextField(text: $actividad.titulo, prompt: Indicacion.texto(L("Fútbol, piano, academia…", "Soccer, piano, tutoring…", "Calcio, pianoforte, ripetizioni…"))) {
                            Text(L("Actividad", "Activity", "Attività"))
                        }
                        .font(.title3)
                        .focused($foco)
                    }
                    DisclosureGroup(L("Símbolo y color", "Symbol and color", "Simbolo e colore")) {
                        SelectorSimbolo(simbolo: $actividad.simbolo, opciones: SimbolosHoot.actividades, color: actividad.color)
                        SelectorColor(color: $actividad.color)
                    }
                }
                .filaTenida()

                Section {
                    DatePicker(L("Día", "Date", "Giorno"), selection: $actividad.fecha, displayedComponents: .date)
                        .tint(Color.acento)
                    Toggle(L("Todo el día", "All day", "Tutto il giorno"), isOn: Binding(
                        get: { actividad.inicio == nil },
                        set: { todo in
                            conMuelle {
                                actividad.inicio = todo ? nil : 17 * 60
                                actividad.fin = todo ? nil : 18 * 60
                            }
                        }
                    ))
                    .interruptorApple()
                    if actividad.inicio != nil {
                        SelectorHora(titulo: L("Empieza", "Starts", "Inizia"), minutos: Binding(get: { actividad.inicio ?? 0 }, set: { actividad.inicio = $0 }))
                            .tint(Color.acento)
                        SelectorHora(titulo: L("Termina", "Ends", "Finisce"), minutos: Binding(get: { actividad.fin ?? 0 }, set: { actividad.fin = $0 }))
                            .tint(Color.acento)
                    }
                }
                .filaTenida()

                Section {
                    Picker(L("Repetir", "Repeat", "Ripeti"), selection: tipoRepeticion) {
                        ForEach(TipoRepeticion.allCases) { Text($0.nombre).tag($0) }
                    }
                    if case .semanal = actividad.repeticion { selectorDias }
                    if case .quincenal = actividad.repeticion { selectorDias }
                    if actividad.repeticion != .nunca {
                        Toggle(L("Hasta una fecha", "Until a date", "Fino a una data"), isOn: Binding(
                            get: { actividad.hasta != nil },
                            set: { on in conMuelle { actividad.hasta = on ? Ajustes.finCursoPorDefecto : nil } }
                        ))
                        .interruptorApple()
                        if let hasta = actividad.hasta {
                            DatePicker(L("Termina el", "Ends on", "Finisce il"), selection: Binding(get: { hasta }, set: { actividad.hasta = $0 }), displayedComponents: .date)
                                .tint(Color.acento)
                        }
                    }
                }
                .filaTenida()

                Section {
                    TextField(text: $actividad.lugar, prompt: Indicacion.texto(L("Lugar", "Location", "Luogo"))) {
                        Text(L("Lugar", "Location", "Luogo"))
                    }
                    Picker(L("Aviso", "Alert", "Avviso"), selection: $actividad.aviso) {
                        ForEach(avisos, id: \.0) { Text($0.0).tag($0.1) }
                    }
                }
                .filaTenida()

                Section {
                    ForEach(actividad.llevar, id: \.self) { cosa in
                        Label(cosa, systemImage: "backpack.fill")
                    }
                    .onDelete { actividad.llevar.remove(atOffsets: $0) }
                    HStack {
                        TextField(text: $nuevaCosa, prompt: Indicacion.texto(L("Botas, raqueta, partituras…", "Cleats, racket, sheet music…", "Scarpe, racchetta, spartiti…"))) {
                            Text(L("Qué llevar", "What to bring", "Cosa portare"))
                        }
                        .onSubmit(anadirCosa)
                        Button(L("Añadir", "Add", "Aggiungi"), action: anadirCosa)
                            .buttonStyle(.borderless)
                            .disabled(nuevaCosa.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text(L("Qué llevar", "What to bring", "Cosa portare")).foregroundStyle(EstiloSecundario())
                } footer: {
                    Text(L("Se añade a la mochila de ese día.", "It's added to that day's backpack.", "Si aggiunge allo zaino di quel giorno."))
                        .foregroundStyle(EstiloSecundario())
                }
                .filaTenida()

                Section {
                    TextField(text: $actividad.notas, prompt: Indicacion.texto(L("Detalles", "Details", "Dettagli")), axis: .vertical) {
                        Text(L("Detalles", "Details", "Dettagli"))
                    }
                    .lineLimit(2...5)
                }
                .filaTenida()

                if !esNueva {
                    Section {

                        Button(role: .destructive) { borrando = true } label: {
                            FilaAjuste(simbolo: "trash.fill", color: .rojo, titulo: L("Borrar actividad", "Delete activity", "Elimina attività"))
                        }
                    }
                    .filaTenida()
                }
            }
            .tenidaDelCielo(hoja: true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle(esNueva ? L("Nueva actividad", "New activity", "Nuova attività") : actividad.titulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BotonCerrar { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { guardar() }
                        .disabled(actividad.titulo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog(L("¿Borrar esta actividad?", "Delete this activity?", "Eliminare questa attività?"), isPresented: $borrando, titleVisibility: .visible) {
                Button(L("Borrar", "Delete", "Elimina"), role: .destructive) {
                    conMuelle { almacen.datos.actividades.removeAll { $0.id == actividad.id } }
                    cerrar()
                }
            } message: {
                Text(L("Desaparece de todos los días en que se repite.", "It's removed from every day it repeats.", "Sparisce da tutti i giorni in cui si ripete."))
            }
            .onAppear { if esNueva { foco = true } }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground { FondoHojaTenida() }
    }

    private var selectorDias: some View {
        SelectorDias(seleccion: Binding(get: { diasElegidos }, set: { nuevos in
            for d in 1...7 where nuevos.contains(d) != diasElegidos.contains(d) { alternarDia(d) }
        }), color: actividad.color, minimo: 1)
    }

    private func anadirCosa() {
        let t = nuevaCosa.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        conMuelle { actividad.llevar.append(t) }
        nuevaCosa = ""
    }

    private func guardar() {
        actividad.titulo = actividad.titulo.trimmingCharacters(in: .whitespaces)
        actividad.fecha = calendarioActual.startOfDay(for: actividad.fecha)
        conMuelle {
            if let i = almacen.datos.actividades.firstIndex(where: { $0.id == actividad.id }) {
                almacen.datos.actividades[i] = actividad
            } else {
                almacen.datos.actividades.append(actividad)
            }
        }
        cerrar()
    }
}
