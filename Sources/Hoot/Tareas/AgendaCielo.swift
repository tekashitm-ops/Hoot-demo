import SwiftUI

struct AgendaCielo: View {
    @Environment(Almacen.self) private var almacen
    @State private var nuevo: NuevoElemento?
    @State private var borrando: Tarea?
    @State private var borrandoRecordatorio: Recordatorio?
    @State private var actividad: Actividad?
    @State private var abierto: DiaAbierto?
    @State private var ruta = NavigationPath()
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        NavigationStack(path: $ruta) {
            TimelineView(.everyMinute) { contexto in
                let ahora = Reloj.desde(contexto.date)
                let datos = almacen.datosConCalendario
                let plan = datos.plan(ahora: ahora)
                let semana = DiaSemana.semana(datos, plan: plan, ahora: ahora)

                let deLunes = DiaSemana.semana(datos, plan: plan, ahora: ahora, desde: DiaSemana.lunes(de: ahora))
                let total = deLunes.reduce(0) { $0 + $1.carga }
                let examenes = deLunes.reduce(0) { $0 + $1.examenes.count }
                let hoy = calendarioActual.startOfDay(for: ahora)
                let atrasadas = datos.tareas.filter { !$0.hecha && $0.entrega < ahora && $0.tipo != .examen }.sorted { $0.entrega < $1.entrega }
                let finSemana = calendarioActual.date(byAdding: .day, value: 7, to: hoy) ?? hoy
                let despues = datos.tareas.filter { !$0.hecha && $0.entrega >= finSemana }.sorted { $0.entrega < $1.entrega }
                ScrollViewReader { desplazar in
                    let barra = BarraSemanaAgenda(deLunes: deLunes, enLista: Set(semana.map(\.id)), datos: datos, ahora: ahora,
                                                  total: total, examenes: examenes,
                                                  abrir: { fecha in abierto = DiaAbierto(fecha: fecha) },
                                                  ir: { id in conMuelle { desplazar.scrollTo(id, anchor: .top) } })

                    VStack(spacing: 0) {
                        if !letra.isAccessibilitySize { barra }
                        List {

                            Color.clear.frame(height: 1).id("arriba").fondoCielo()
                            if letra.isAccessibilitySize {
                                barra
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 6, trailing: 0))
                                    .fondoCielo()
                            }

                            if !atrasadas.isEmpty {
                                TituloDiaAgenda(titulo: L("Atrasadas", "Late", "In ritardo"), detalle: "", urgente: true)
                                    .fondoCielo()
                                ForEach(atrasadas) { t in filaTarea(t, datos: datos, ahora: ahora, conVence: true) }
                            }

                            ForEach(semana) { d in
                                TituloDiaAgenda(titulo: d.titulo(ahora: ahora), detalle: d.carga > 0 ? Formato.duracion(minutos: d.carga) : "")
                                    .id(d.id)
                                    .fondoCielo()
                                filasDia(d, datos: datos, ahora: ahora, plan: plan)
                            }

                            if !despues.isEmpty {
                                TituloDiaAgenda(titulo: L("Más adelante", "Later", "Più avanti"), detalle: "")
                                    .fondoCielo()
                                ForEach(despues) { t in
                                    if t.tipo == .examen {
                                        enlace(t) { FilaExamenDia(examen: t, asignatura: datos.asignatura(t.asignaturaID)) }
                                            .fila()
                                    } else {
                                        filaTarea(t, datos: datos, ahora: ahora, conVence: true)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)

                        .contentMargins(.top, letra.isAccessibilitySize ? Diseno.desvanecer : 0, for: .scrollContent)
                        .mask { DesvanecerArriba() }
                        .refreshable { await Conexiones.actualizar(almacen) }
                        .onAppear {

                            if ModoCapturas.activo, let n = ModoCapturas.valor("-ir").flatMap(Int.init), semana.indices.contains(n) {
                                desplazar.scrollTo(semana[n].id, anchor: .top)
                            }
                            if ModoCapturas.activo, let n = ModoCapturas.valor("-tocar").flatMap(Int.init), deLunes.indices.contains(n) {
                                abierto = DiaAbierto(fecha: deLunes[n].dia)
                            }
                        }
                    }
                    .environment(\.colorScheme, .dark)
                    .environment(\.sobreCielo, true)
                    .background { FondoTiempo() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(L("Deberes", "Homework", "Compiti"), systemImage: "pencil.line") { nuevo = .deberes }
                        Button(L("Examen", "Test", "Verifica"), systemImage: "doc.text.magnifyingglass") { nuevo = .examen }
                        Button(L("Actividad", "Activity", "Attività"), systemImage: "figure.run") { nuevo = .actividad }
                        Button(L("Recordatorio", "Reminder", "Promemoria"), systemImage: "bell") { nuevo = .recordatorio }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .chocable(.circulo, reacciona: true)
                    .accessibilityLabel(L("Añadir", "Add", "Aggiungi"))
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    BotonCuenta()
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .navigationDestination(for: RutaTarea.self) { ruta in TareaDetalle(id: ruta.id) }
            .sheet(item: $nuevo) { tipo in
                switch tipo {
                case .deberes: EditorTarea(tarea: Tarea(titulo: "", tipo: .deberes, entrega: TareasVista.entregaPorDefecto()))
                case .actividad: EditorActividad(actividad: Actividad(titulo: "", fecha: calendarioActual.startOfDay(for: Reloj.ahora), inicio: 17 * 60, fin: 18 * 60))
                case .examen: EditorTarea(tarea: Tarea(titulo: "", tipo: .examen, entrega: TareasVista.entregaPorDefecto(examen: true)))
                case .recordatorio: EditorRecordatorio(recordatorio: Recordatorio(titulo: "", fecha: TareasVista.entregaPorDefecto()))
                }
            }
            .sheet(item: $actividad) { a in HojaActividad(actividad: a).hojaQueChoca() }
            .sheet(item: $abierto) { d in
                HojaDia(dia: d.fecha, datos: almacen.datosConCalendario, soloLectura: false) { a in actividad = a }
                    .hojaQueChoca()
                    .presentationDetents([.medium, .large])
            }
            .confirmationDialog(
                L("¿Borrar esta tarea?", "Delete this task?", "Eliminare questo compito?"),
                isPresented: Binding(get: { borrando != nil }, set: { if !$0 { borrando = nil } }),
                titleVisibility: .visible,
                presenting: borrando
            ) { t in
                Button(L("Borrar", "Delete", "Elimina"), role: .destructive) {
                    conMuelle { almacen.datos.tareas.removeAll { $0.id == t.id } }
                }
            } message: { t in
                Text(t.origen == .teams
                     ? L("Desaparece de Hoot, no de Teams.", "It's removed from Hoot, not from Teams.", "Sparisce da Hoot, non da Teams.")
                     : L("No se puede deshacer.", "This can't be undone.", "Non si può annullare."))
            }
            .confirmationDialog(
                L("¿Borrar este recordatorio?", "Delete this reminder?", "Eliminare questo promemoria?"),
                isPresented: Binding(get: { borrandoRecordatorio != nil }, set: { if !$0 { borrandoRecordatorio = nil } }),
                titleVisibility: .visible,
                presenting: borrandoRecordatorio
            ) { r in
                Button(L("Borrar", "Delete", "Elimina"), role: .destructive) {
                    conMuelle { almacen.datos.recordatorios.removeAll { $0.id == r.id } }
                }
            } message: { _ in
                Text(L("No se puede deshacer.", "This can't be undone.", "Non si può annullare."))
            }
            .onAppear {

                if ModoCapturas.activo, ModoCapturas.pantalla == "tarea-examen", ruta.isEmpty, let ex = almacen.datos.proximoExamen() {
                    ruta.append(RutaTarea(id: ex.id))
                }
                if ModoCapturas.activo, nuevo == nil, let n = ModoCapturas.valor("-nuevo").flatMap(NuevoElemento.init(rawValue:)) {
                    nuevo = n
                }
            }
        }
    }

    @ViewBuilder
    private func filasDia(_ d: DiaSemana, datos: DatosEscolares, ahora: Date, plan: PlanEstudio) -> some View {
        let entregadas = Set((d.entregas + d.examenes).map(\.id))
        let ratos = Dictionary(grouping: d.ratos.filter { !entregadas.contains($0.tareaID) }, by: \.tareaID)
            .compactMap { id, ss -> (Tarea, [Sesion])? in datos.tareas.first { $0.id == id }.map { ($0, ss.sorted { $0.hora < $1.hora }) } }
            .sorted { ($0.1.first?.hora ?? 0) < ($1.1.first?.hora ?? 0) }
        let hechas = datos.tareas(en: d.dia).filter(\.hecha)
        let recordatorios = datos.recordatorios(en: d.dia)
        if d.examenes.isEmpty && d.entregas.isEmpty && d.actividades.isEmpty && ratos.isEmpty && recordatorios.isEmpty && hechas.isEmpty {
            Text(L("Libre", "Free", "Libero"))
                .font(.subheadline)
                .foregroundStyle(EstiloSecundario())
                .fila()
        }
        ForEach(d.examenes) { t in
            enlace(t) { FilaExamenDia(examen: t, asignatura: datos.asignatura(t.asignaturaID)) }
                .fila()
        }
        ForEach(d.entregas) { t in filaTarea(t, datos: datos, ahora: ahora, conVence: false) }

        let conHora: [(minuto: Int, clave: String, cosa: CosaConHora)] =
            d.actividades.map { ($0.inicio ?? -1, "a\($0.id)", CosaConHora.actividad($0)) }
            + ratos.map { ($0.1.first?.hora ?? 0, "s\($0.0.id)", CosaConHora.estudio($0.0, $0.1)) }
            + recordatorios.map { ($0.conHora ? DatosEscolares.minutos($0.fecha) : 24 * 60, "r\($0.id)", CosaConHora.recordatorio($0)) }
        ForEach(conHora.sorted { ($0.minuto, $0.clave) < ($1.minuto, $1.clave) }, id: \.clave) { _, _, cosa in
            switch cosa {
            case .actividad(let a):
                Button { actividad = a } label: {
                    FilaActividadInicio(actividad: a).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .fila()
            case .estudio(let t, let sesiones):
                enlace(t) {
                    FilaEstudioDia(tarea: t, asignatura: datos.asignatura(t.asignaturaID), sesiones: sesiones,
                                   justa: plan.empezar(t.id)?.justa ?? false)
                }
                .fila()
            case .recordatorio(let r):
                FilaRecordatorio(recordatorio: r, conDia: false, horaDerecha: true) {
                    conMuelle(Diseno.muelleRebote) { almacen.alternarRecordatorio(r.id) }
                }
                .fila()
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { borrandoRecordatorio = r } label: {
                        Label(L("Borrar", "Delete", "Elimina"), systemImage: "trash")
                    }
                }
            }
        }
        ForEach(hechas) { t in filaTarea(t, datos: datos, ahora: ahora, conVence: false) }
    }

    private func filaTarea(_ t: Tarea, datos: DatosEscolares, ahora: Date, conVence: Bool) -> some View {
        enlace(t) {
            FilaTarea(tarea: t, asignatura: datos.asignatura(t.asignaturaID), mostrarVence: conVence) {
                conMuelle(Diseno.muelleRebote) { almacen.alternarHecha(t.id) }
            }
        }
        .fila()
        .swipeActions(edge: .leading) {
            Button {
                conMuelle(Diseno.muelleRebote) { almacen.alternarHecha(t.id) }
            } label: {
                Label(t.hecha ? L("Pendiente", "To do", "Da fare") : L("Hecha", "Done", "Fatto"),
                      systemImage: t.hecha ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(Color.interruptor)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { borrando = t } label: {
                Label(L("Borrar", "Delete", "Elimina"), systemImage: "trash")
            }
        }
    }

    private func enlace<Contenido: View>(_ t: Tarea, @ViewBuilder contenido: () -> Contenido) -> some View {
        NavigationLink(value: RutaTarea(id: t.id)) { contenido() }
            .buttonStyle(.plain)
    }
}

private enum CosaConHora {
    case actividad(Actividad), estudio(Tarea, [Sesion]), recordatorio(Recordatorio)
}

struct TituloDiaAgenda: View {
    var titulo: String
    var detalle: String
    var urgente = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titulo)
                .font(.title3.weight(.semibold))
                .foregroundStyle(urgente ? AnyShapeStyle(EstiloUrgente()) : AnyShapeStyle(Color.primary))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if !detalle.isEmpty {
                Text(detalle)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(EstiloSecundario())
            }
        }
        .padding(.top, 18)
    }
}

private extension View {

    func fila() -> some View {
        listRowBackground(Color.clear)
    }

    func fondoCielo() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

private struct BarraSemanaAgenda: View {
    var deLunes: [DiaSemana]
    var enLista: Set<String>
    var datos: DatosEscolares
    var ahora: Date
    var total: Int
    var examenes: Int
    var abrir: (Date) -> Void
    var ir: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            CabeceraSemanaAgenda(total: total, examenes: examenes)
            GraficoSemanaCielo(semana: deLunes, datos: datos, ahora: ahora,
                               alTocar: { d in abrir(d.dia) },
                               alSoltar: { d in if enLista.contains(d.id) { ir(d.id) } },
                               alElegir: { d in ir(enLista.contains(d.id) ? d.id : "arriba") },
                               compacta: true)
                .padding(.top, 4)
        }
        .padding(.horizontal, Diseno.margen)
    }
}

private struct CabeceraSemanaAgenda: View {
    var total: Int
    var examenes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L("Esta semana", "This week", "Questa settimana"))
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)
            Text(resumen)
                .font(.headline)

                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var resumen: String {
        if total == 0 && examenes == 0 { return L("Semana despejada", "A clear week", "Settimana libera") }
        let tiempo = Formato.duracion(minutos: total)
        let uno = examenes == 1
        return L("\(tiempo) de trabajo · \(examenes) \(uno ? "examen" : "exámenes")",
                 "\(tiempo) of work · \(examenes) \(uno ? "test" : "tests")",
                 "\(tiempo) di lavoro · \(examenes) \(uno ? "verifica" : "verifiche")")
    }
}

struct DesvanecerArriba: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: Diseno.desvanecer)
            Rectangle().fill(.black)
        }
    }
}
