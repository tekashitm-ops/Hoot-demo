import SwiftUI

struct AgendaCielo: View {
    @Environment(Almacen.self) private var almacen
    @State private var nuevo: NuevoElemento?
    @State private var borrando: Tarea?
    @State private var borrandoRecordatorio: Recordatorio?
    @State private var actividad: Actividad?
    @State private var abierto: DiaAbierto?
    @State private var ruta = NavigationPath()
    @State private var repaso: PeticionRepaso?
    @State private var simulacroDe: UUID?
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        NavigationStack(path: $ruta) {
            TimelineView(.everyMinute) { contexto in
                let ahora = Reloj.desde(contexto.date)
                let datos = almacen.datosConCalendario
                let repasoPlan = almacen.datos.planRepaso(ajustes: almacen.ajustes, ahora: ahora)
                let semana = DiaSemana.semana(datos, repaso: repasoPlan, ahora: ahora)

                let deLunes = DiaSemana.semana(datos, repaso: repasoPlan, ahora: ahora, desde: DiaSemana.lunes(de: ahora))
                let total = deLunes.reduce(0) { $0 + $1.carga }
                let examenes = deLunes.reduce(0) { $0 + $1.pruebas.count }
                let hoy = calendarioActual.startOfDay(for: ahora)
                let finSemana = calendarioActual.date(byAdding: .day, value: 7, to: hoy) ?? hoy
                let despues = datos.pruebas.filter { $0.fecha >= finSemana }.sorted { $0.fecha < $1.fecha }
                ScrollViewReader { desplazar in
                    let barra = BarraSemanaAgenda(deLunes: deLunes, enLista: Set(semana.map(\.id)), datos: datos, ahora: ahora,
                                                  total: total, examenes: examenes,
                                                  abrir: { fecha in abierto = DiaAbierto(fecha: fecha) },
                                                  ir: { id in conMuelle { desplazar.scrollTo(id, anchor: .top) } })

                    VStack(spacing: 0) {
                        if !letra.isAccessibilitySize { barra }
                        List {

                            Color.clear.frame(height: 1).id("arriba").fondoCielo()
                            HootDice(frase: FrasesHoot.agenda(pruebas: examenes, minutos: total), gesto: examenes > 0 ? .pensando : .feliz,
                                     tamano: 92, loboALaDerecha: true)
                                .listRowInsets(EdgeInsets(top: 6, leading: Diseno.margenTarjeta, bottom: 0, trailing: Diseno.margenTarjeta))
                                .fondoCielo()
                            if letra.isAccessibilitySize {
                                barra
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 6, trailing: 0))
                                    .fondoCielo()
                            }

                            ForEach(semana) { d in
                                TituloCielo(titulo: d.titulo(ahora: ahora), simbolo: "calendar", enTarjeta: true,
                                            detalle: d.carga > 0 ? Formato.duracion(minutos: d.carga) : nil)
                                    .id(d.id)
                                    .filaEnTarjeta(.arriba, margen: Diseno.margenTarjeta)
                                filasDia(d, datos: datos, ahora: ahora)
                            }

                            if !despues.isEmpty {
                                TituloCielo(titulo: L("Más adelante", "Later", "Più avanti"), simbolo: "calendar.badge.clock", enTarjeta: true)
                                    .filaEnTarjeta(.arriba, margen: Diseno.margenTarjeta)
                                ForEach(Array(despues.enumerated()), id: \.element.id) { i, p in
                                    filaPrueba(p, datos: datos, ahora: ahora, conDia: true)
                                        .filaEnTarjeta(i == despues.count - 1 ? .abajo : .medio, raya: i > 0, margen: Diseno.margenTarjeta,
                                                       abajo: i == despues.count - 1 ? 6 : 0)
                                }
                            }
                            Color.clear.frame(height: 24).fondoCielo()
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

                    .environment(\.cieloSinVelo, true)
                    .background { FondoTiempo(sinVelo: true) }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(L("Prueba", "Test", "Verifica"), systemImage: "moonphase.first.quarter") { nuevo = .examen }
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
            .navigationDestination(for: RutaPruebas.self) { r in
                if case .prueba(let id) = r { PruebaDetalle(id: id) }
            }
            .fullScreenCover(item: $repaso) { r in
                RepasoTemas(peticion: r) { repaso = nil }
            }
            .simulacro(de: $simulacroDe)
            .sheet(item: $nuevo) { tipo in
                switch tipo {
                case .actividad: EditorActividad(actividad: Actividad(titulo: "", fecha: calendarioActual.startOfDay(for: Reloj.ahora), inicio: 17 * 60, fin: 18 * 60))
                case .examen: NuevaPrueba(empezarCon: nil) { id in ruta.append(RutaPruebas.prueba(id)) }
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
    private func filasDia(_ d: DiaSemana, datos: DatosEscolares, ahora: Date) -> some View {
        let recordatorios = datos.recordatorios(en: d.dia)
        let conHora: [(minuto: Int, clave: String, cosa: CosaConHora)] =
            d.pruebas.map { (-2, "p\($0.id)", CosaConHora.prueba($0)) }
            + d.actividades.map { ($0.inicio ?? -1, "a\($0.id)", CosaConHora.actividad($0)) }
            + d.repasos.map { ($0.hora, "s\($0.id)", CosaConHora.repaso($0)) }
            + recordatorios.map { ($0.conHora ? DatosEscolares.minutos($0.fecha) : 24 * 60, "r\($0.id)", CosaConHora.recordatorio($0)) }

        let cosas = conHora.sorted { ($0.minuto, $0.clave) < ($1.minuto, $1.clave) }
        if cosas.isEmpty {
            Text(L("Nada apuntado", "Nothing planned", "Niente in programma"))
                .font(.subheadline)
                .foregroundStyle(EstiloSecundario())
                .padding(.vertical, 10)
                .filaEnTarjeta(.abajo, margen: Diseno.margenTarjeta, abajo: 6)
        }
        ForEach(Array(cosas.enumerated()), id: \.element.clave) { i, c in
            let sitio: SitioEnTarjeta = i == cosas.count - 1 ? .abajo : .medio
            fila(c.cosa, datos: datos, ahora: ahora)
                .filaEnTarjeta(sitio, raya: i > 0, margen: Diseno.margenTarjeta, abajo: sitio == .abajo ? 6 : 0)
        }
    }

    @ViewBuilder
    private func fila(_ cosa: CosaConHora, datos: DatosEscolares, ahora: Date) -> some View {
        switch cosa {
        case .prueba(let p):
            filaPrueba(p, datos: datos, ahora: ahora, conDia: false)
        case .actividad(let a):
            Button { actividad = a } label: {
                FilaActividadInicio(actividad: a).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .repaso(let s):
            Button {
                if s.simulacro, let id = s.pruebaID {
                    simulacroDe = id
                    return
                }
                let conTexto = s.temaIDs.filter { id in datos.tema(id).map { !$0.textoLeido.isEmpty } ?? false }
                if !conTexto.isEmpty { repaso = PeticionRepaso(temaIDs: conTexto, mezclado: s.mezclada) }
            } label: {
                FilaRepasoAgenda(sesion: s, datos: datos).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .recordatorio(let r):
            FilaRecordatorio(recordatorio: r, conDia: false, horaDerecha: true) {
                conMuelle(Diseno.muelleRebote) { almacen.alternarRecordatorio(r.id) }
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { borrandoRecordatorio = r } label: {
                    Label(L("Borrar", "Delete", "Elimina"), systemImage: "trash")
                }
            }
        }
    }

    private func filaPrueba(_ p: Prueba, datos: DatosEscolares, ahora: Date, conDia: Bool) -> some View {
        NavigationLink(value: RutaPruebas.prueba(p.id)) {
            FilaPrueba(prueba: p, asignatura: datos.asignatura(p.asignaturaID), ahora: ahora, cal: calendarioActual)
        }
        .buttonStyle(.plain)
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
    case prueba(Prueba), actividad(Actividad), repaso(SesionRepaso), recordatorio(Recordatorio)
}

struct FilaRepasoAgenda: View {
    var sesion: SesionRepaso
    var datos: DatosEscolares

    var body: some View {
        let cal = calendarioActual
        let temas = sesion.temaIDs.compactMap { datos.tema($0) }
        HStack(spacing: 12) {
            FilaLunas(partes: temas.prefix(3).map { $0.luna(cal: cal).fraccion }, tamano: 15, hueco: 2)
                .frame(minWidth: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(sesion.simulacro ? L("Simulacro · la prueba entera", "Mock test · the whole thing", "Simulazione · la verifica intera")
                     : sesion.ligera ? L("Repaso ligero", "Light review", "Ripasso leggero")
                                   : L("Repaso · \(temas.map(\.nombre).joined(separator: ", "))", "Review · \(temas.map(\.nombre).joined(separator: ", "))",
                                       "Ripasso · \(temas.map(\.nombre).joined(separator: ", "))"))
                    .font(.headline)
                    .lineLimit(2)
                Text("\(Formato.hora(sesion.hora)) · \(sesion.minutos) min\(sesion.mezclada ? L(" · mezclado", " · mixed", " · mescolato") : "")")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(EstiloSecundario())
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
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
            TituloCielo(titulo: L("Esta semana", "This week", "Questa settimana"), simbolo: "chart.bar.fill", enTarjeta: true)
            CabeceraSemanaAgenda(total: total, examenes: examenes)
                .padding(.top, 4)
            GraficoSemanaCielo(semana: deLunes, datos: datos, ahora: ahora,
                               alTocar: { d in abrir(d.dia) },
                               alSoltar: { d in if enLista.contains(d.id) { ir(d.id) } },
                               alElegir: { d in ir(enLista.contains(d.id) ? d.id : "arriba") },
                               compacta: true)
                .padding(.top, 4)
        }
        .padding(.horizontal, Diseno.margenTarjeta)
        .padding(.bottom, 8)
        .fondoModulo()
        .padding(.horizontal, Diseno.margenTarjeta)
    }
}

private struct CabeceraSemanaAgenda: View {
    var total: Int
    var examenes: Int

    var body: some View {
        Text(resumen)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)

            .fixedSize(horizontal: false, vertical: true)
    }

    private var resumen: String {
        if total == 0 && examenes == 0 { return L("Semana despejada", "A clear week", "Settimana libera") }
        let tiempo = Formato.duracion(minutos: total)
        let uno = examenes == 1
        let pruebas = L("\(examenes) \(uno ? "prueba" : "pruebas")", "\(examenes) \(uno ? "test" : "tests")",
                        "\(examenes) \(uno ? "verifica" : "verifiche")")
        if total == 0 { return pruebas }
        return L("\(tiempo) de repaso · \(pruebas)", "\(tiempo) of review · \(pruebas)", "\(tiempo) di ripasso · \(pruebas)")
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
