import SwiftUI

struct CalendarioVista: View {
    var enHoja = false
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var nueva: NuevoCalendario?

    var body: some View {
        NavigationStack {
            CalendarioContenido(datos: almacen.datosConCalendario, soloLectura: false) { act in
                nueva = .editar(act)
            }
            .task {

                guard ModoCapturas.activo, let n = ModoCapturas.valor("-cita").flatMap(Int.init) else { return }
                try? await Task.sleep(for: .seconds(1.5))
                let cal = calendarioActual
                if let d = cal.date(byAdding: .day, value: n, to: cal.startOfDay(for: Reloj.ahora)),
                   let a = almacen.datosConCalendario.actividades(en: d).first(where: { Calendarios.compartido.citaDe[$0.id] != nil }) {
                    nueva = .editar(a)
                }
            }
            .toolbar {
                if enHoja {
                    ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar() } }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(L("Prueba", "Test", "Verifica"), systemImage: "moonphase.first.quarter") { nueva = .examen }
                        Button(L("Actividad", "Activity", "Attività"), systemImage: "figure.run") { nueva = .actividad }
                        Button(L("Recordatorio", "Reminder", "Promemoria"), systemImage: "bell") { nueva = .recordatorio }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(L("Añadir", "Add", "Aggiungi"))
                }
                if !enHoja {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    ToolbarItem(placement: .topBarTrailing) {
                        BotonCuenta()
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
            }
            .navigationDestination(for: RutaTarea.self) { ruta in
                TareaDetalle(id: ruta.id)
            }
            .sheet(item: $nueva) { n in
                switch n {
                case .actividad:
                    EditorActividad(actividad: Actividad(titulo: "", fecha: calendarioActual.startOfDay(for: Reloj.ahora), inicio: 17 * 60, fin: 18 * 60))
                case .editar(let a):
                    HojaActividad(actividad: a)
                case .deberes:
                    EditorTarea(tarea: Tarea(titulo: "", tipo: .deberes, entrega: TareasVista.entregaPorDefecto()))
                case .examen:
                    NuevaPrueba(empezarCon: nil) { _ in }
                case .recordatorio:
                    EditorRecordatorio(recordatorio: Recordatorio(titulo: "", fecha: TareasVista.entregaPorDefecto()))
                }
            }
        }
    }
}

enum NuevoCalendario: Identifiable {
    case deberes, actividad, examen, recordatorio
    case editar(Actividad)

    var id: String {
        switch self {
        case .deberes: "deberes"
        case .actividad: "actividad"
        case .examen: "examen"
        case .recordatorio: "recordatorio"
        case .editar(let a): "editar-\(a.id)"
        }
    }
}

struct DiaAbierto: Identifiable, Hashable {
    var fecha: Date
    var id: String { DatosEscolares.clave(fecha) }
}

struct CalendarioContenido: View {
    var datos: DatosEscolares
    var soloLectura: Bool
    var alTocarActividad: (Actividad) -> Void = { _ in }

    @State private var abierto: DiaAbierto?
    @State private var eligiendoFecha = false
    @State private var fecha = Reloj.ahora
    @State private var irA: Date?

    @State private var semanaArriba: Date?

    var body: some View {
        TimelineView(.everyMinute) { contexto in
            let ahora = Reloj.desde(contexto.date)
            let plan = datos.plan(ahora: ahora)
            let estaSemana = Self.inicioSemana(de: ahora)
            let semanas = (-8...30).compactMap { calendarioActual.date(byAdding: .day, value: 7 * $0, to: estaSemana) }
            ScrollViewReader { desplazar in

                VStack(spacing: 0) {
                    cabecera(ahora: ahora)
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Diseno.huecoTarjetas) {
                            ForEach(Array(semanas.enumerated()), id: \.element) { i, inicio in

                                if i > 0, let mes = Self.mesQueEmpieza(inicio, primera: false) {
                                    Text(Self.titulo(mes, ahora: ahora))
                                        .font(.title2.bold())
                                        .padding(.top, 16)
                                        .accessibilityAddTraits(.isHeader)
                                }
                                SemanaCalendario(dias: DiaSemana.semana(datos, plan: plan, ahora: ahora, desde: inicio), datos: datos,
                                                 ahora: ahora) { d in abierto = DiaAbierto(fecha: d) }
                                    .id(inicio)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, Diseno.margen)
                        .padding(.bottom, 40)
                    }
                    .scrollIndicators(.hidden)

                    .contentMargins(.top, Diseno.desvanecer, for: .scrollContent)
                    .scrollPosition(id: $semanaArriba, anchor: .top)
                    .mask { DesvanecerArriba() }

                    .onAppear {
                        semanaArriba = estaSemana
                        desplazar.scrollTo(estaSemana, anchor: .top)
                    }
                    .onChange(of: irA) { _, inicio in
                        guard let inicio else { return }
                        conMuelle { desplazar.scrollTo(inicio, anchor: .top) }
                        irA = nil
                    }
                }
            }
        }
        .sobreElCielo()

        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(L("Hoy", "Today", "Oggi")) { irA = Self.inicioSemana(de: Reloj.ahora) }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    fecha = Reloj.ahora
                    eligiendoFecha = true
                } label: {
                    Image(systemName: "calendar")
                }
                .accessibilityLabel(L("Ir a un día", "Go to a day", "Vai a un giorno"))
            }
        }
        .sheet(item: $abierto) { d in
            HojaDia(dia: d.fecha, datos: datos, soloLectura: soloLectura, alTocarActividad: alTocarActividad)
                .hojaQueChoca()
                .presentationDetents([.medium, .large])
        }

        .sheet(isPresented: $eligiendoFecha) {
            NavigationStack {
                DatePicker(L("Día", "Day", "Giorno"), selection: $fecha, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.horizontal)
                    .navigationTitle(L("Ir a un día", "Go to a day", "Vai a un giorno"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button(role: .cancel) { eligiendoFecha = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(role: .confirm) {
                                eligiendoFecha = false
                                irA = Self.inicioSemana(de: fecha)
                                let elegido = fecha
                                Task {
                                    try? await Task.sleep(for: .milliseconds(500))
                                    abierto = DiaAbierto(fecha: calendarioActual.startOfDay(for: elegido))
                                }
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .sensoryFeedback(.selection, trigger: abierto)
        .onAppear {

            if let n = ModoCapturas.valor("-abrir").flatMap(Int.init), ModoCapturas.activo, abierto == nil,
               let d = calendarioActual.date(byAdding: .day, value: n, to: calendarioActual.startOfDay(for: Reloj.ahora)) {
                abierto = DiaAbierto(fecha: d)
            }
        }
    }

    private func cabecera(ahora: Date) -> some View {
        let mes = Self.mesQueEmpieza(semanaArriba ?? Self.inicioSemana(de: ahora), primera: true) ?? ahora
        let titulo = Self.titulo(mes, ahora: ahora)
        return VStack(alignment: .leading, spacing: 6) {
            Text(titulo)
                .font(.title2.bold())
                .contentTransition(.opacity)
                .animation(Diseno.muelleRapido, value: titulo)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, Diseno.margen)
            HStack(spacing: 0) {
                ForEach(DatosEscolares.ordenSemana, id: \.self) { iso in
                    Text(Formato.nombreDia(iso: iso, estilo: .narrow))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(EstiloSecundario())
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Diseno.margen + Diseno.margenTarjeta)
            .accessibilityHidden(true)
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func inicioSemana(de fecha: Date) -> Date {
        let cal = calendarioActual
        let primero = DatosEscolares.ordenSemana.first ?? 1
        var d = cal.startOfDay(for: fecha)
        for _ in 0..<7 where DatosEscolares.diaISO(d) != primero {
            d = cal.date(byAdding: .day, value: -1, to: d) ?? d
        }
        return d
    }

    static func mesQueEmpieza(_ inicio: Date, primera: Bool) -> Date? {
        let cal = calendarioActual
        for i in 0..<7 {
            if let d = cal.date(byAdding: .day, value: i, to: inicio), cal.component(.day, from: d) == 1 { return d }
        }
        return primera ? inicio : nil
    }

    static func titulo(_ mes: Date, ahora: Date) -> String {
        let cal = calendarioActual
        return (cal.component(.year, from: mes) == cal.component(.year, from: ahora) ? Formato.mesSolo(mes) : Formato.mes(mes)).conMayuscula
    }
}

private struct SemanaCalendario: View {
    var dias: [DiaSemana]
    var datos: DatosEscolares
    var ahora: Date
    var alAbrir: (Date) -> Void

    @ScaledMetric(relativeTo: .body) private var altoBarra: CGFloat = 34
    private let lleno = 150

    var body: some View {
        let total = dias.reduce(0) { $0 + $1.carga }
        let examenes = dias.reduce(0) { $0 + $1.examenes.count }
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(rango)
                Spacer(minLength: 8)
                if total > 0 || examenes > 0 {
                    Text([total > 0 ? Formato.duracion(minutos: total) : nil,
                          examenes > 0 ? L("\(examenes) \(examenes == 1 ? "examen" : "exámenes")", "\(examenes) \(examenes == 1 ? "test" : "tests")", "\(examenes) \(examenes == 1 ? "verifica" : "verifiche")") : nil]
                        .compactMap { $0 }.joined(separator: " · "))
                        .monospacedDigit()
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(EstiloSecundario())
            .padding(.top, 12)
            .padding(.bottom, 6)
            HStack(alignment: .top, spacing: 0) {
                ForEach(dias) { d in celda(d) }
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, Diseno.margenTarjeta - 6)
        .fondoModulo()
    }

    private var rango: String {
        guard let a = dias.first?.dia, let b = dias.last?.dia else { return "" }
        let cal = calendarioActual
        if cal.component(.month, from: a) == cal.component(.month, from: b) {
            return "\(cal.component(.day, from: a))–\(Formato.diaCorto(b))"
        }
        return "\(Formato.diaCorto(a)) – \(Formato.diaCorto(b))"
    }

    private func celda(_ d: DiaSemana) -> some View {
        let cal = calendarioActual
        let esHoy = cal.isDate(d.dia, inSameDayAs: ahora)
        let pasado = d.dia < cal.startOfDay(for: ahora)
        let segmentos = GraficoSemanaCielo.segmentos(d, datos)
        let carga = segmentos.reduce(0) { $0 + $1.1 }

        var puntos = Puntos.colores(dia: d.dia, datos: datos)
        if !d.examenes.isEmpty, !puntos.isEmpty { puntos.removeFirst() }
        return Button { alAbrir(d.dia) } label: {
            VStack(spacing: 5) {

                Text("\(cal.component(.day, from: d.dia))")
                    .font(.body.weight(esHoy ? .bold : .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(esHoy || (!pasado && d.lectivo) ? 1 : 0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 2)
                    .frame(minWidth: 34, minHeight: 34)
                    .background { if esHoy { Circle().fill(Color.acentoRelleno) } }

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.white.opacity(0.12))
                    VStack(spacing: 1.5) {
                        ForEach(segmentos, id: \.0) { color, minutos in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(color.color.gradient)
                                .frame(height: max(4, altoBarra * CGFloat(min(minutos, lleno)) / CGFloat(max(lleno, carga))))
                        }
                    }
                }
                .frame(width: 12, height: altoBarra)
                .opacity(pasado ? 0.45 : 1)
                HStack(spacing: 3) {
                    if !d.examenes.isEmpty {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 12, height: 12)
                            .background(Color.rayoExamen, in: Circle())
                    }
                    ForEach(Array(puntos.prefix(d.examenes.isEmpty ? 3 : 2).enumerated()), id: \.offset) { _, c in
                        Circle().fill(c).frame(width: 6, height: 6)
                    }
                }
                .frame(height: 12)
                .opacity(pasado ? 0.6 : 1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(EstiloPulsar())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(d.resumen(datos))
        .accessibilityAddTraits(esHoy ? [.isButton, .isSelected] : .isButton)
    }
}

struct HojaDia: View {
    var dia: Date
    var datos: DatosEscolares
    var soloLectura: Bool
    var alTocarActividad: (Actividad) -> Void
    @Environment(\.dismiss) private var cerrar
    @State private var nueva: NuevoCalendario?

    var body: some View {
        NavigationStack {
            ScrollView {

                let plan = soloLectura ? nil : datos.plan()
                let ratos = plan?.sesiones(en: dia) ?? []
                let tramos = datos.tramos(dia, ratos: ratos)
                VStack(alignment: .leading, spacing: 0) {
                    if !tramos.isEmpty {
                        if let texto = resumenClases {
                            Text(texto)
                                .font(.subheadline)
                                .textoSecundario()
                        }
                        let primero = tramos.map(\.inicio).min() ?? 8 * 60
                        let ultimo = tramos.map(\.fin).max() ?? 20 * 60

                        CintaDia(tramos: tramos, desde: min(8 * 60, primero / 60 * 60), hasta: max(20 * 60, (ultimo + 59) / 60 * 60),
                                 dia: dia, ahora: Reloj.ahora, conHoras: true)
                            .padding(.top, 10)
                    }
                    ListaDia(dia: dia, datos: datos, plan: plan, ratos: ratos, soloLectura: soloLectura) { a in
                        cerrar()
                        alTocarActividad(a)
                    }
                    .padding(.top, tramos.isEmpty ? 0 : 16)
                }
                .padding(.horizontal, Diseno.margen)

                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .navigationTitle(Formato.diaLargo(dia).conMayuscula)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !soloLectura {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button(L("Deberes", "Homework", "Compiti"), systemImage: "pencil.line") { nueva = .deberes }
                            Button(L("Examen", "Test", "Verifica"), systemImage: "doc.text.magnifyingglass") { nueva = .examen }
                            Button(L("Actividad", "Activity", "Attività"), systemImage: "figure.run") { nueva = .actividad }
                            Button(L("Recordatorio", "Reminder", "Promemoria"), systemImage: "bell") { nueva = .recordatorio }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(L("Añadir a este día", "Add to this day", "Aggiungi a questo giorno"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    BotonCerrar { cerrar() }
                }
            }
            .navigationDestination(for: RutaTarea.self) { ruta in
                TareaDetalle(id: ruta.id)
            }
            .sheet(item: $nueva) { n in
                switch n {
                case .actividad:
                    EditorActividad(actividad: Actividad(titulo: "", fecha: calendarioActual.startOfDay(for: dia), inicio: 17 * 60, fin: 18 * 60))
                case .editar(let a):
                    HojaActividad(actividad: a)
                case .deberes:
                    EditorTarea(tarea: Tarea(titulo: "", tipo: .deberes, entrega: DatosEscolares.fecha(dia, minutos: 23 * 60 + 59)))
                case .examen:
                    EditorTarea(tarea: Tarea(titulo: "", tipo: .examen, entrega: DatosEscolares.fecha(dia, minutos: 9 * 60)))
                case .recordatorio:
                    EditorRecordatorio(recordatorio: Recordatorio(titulo: "", fecha: DatosEscolares.fecha(dia, minutos: 17 * 60)))
                }
            }
        }
    }

    private var resumenClases: String? {
        let clases = datos.clases(en: dia)
        if let p = clases.first, let u = clases.last {
            return L("Clases de \(Formato.hora(p.inicio)) a \(Formato.hora(u.fin))",
                     "Classes \(Formato.hora(p.inicio))–\(Formato.hora(u.fin))",
                     "Lezioni dalle \(Formato.hora(p.inicio)) alle \(Formato.hora(u.fin))")
        }
        return datos.esLectivo(dia) ? nil : L("Sin clase", "No school", "Niente scuola")
    }
}

enum Puntos {
    static func colores(dia: Date, datos: DatosEscolares) -> [Color] {
        var r: [Color] = []
        let tareas = datos.tareas(en: dia)
        if tareas.contains(where: { $0.tipo == .examen }) { r.append(Color.urgente) }
        for t in tareas where t.tipo != .examen {
            r.append(datos.asignatura(t.asignaturaID)?.color.color ?? Color.acento)
        }
        for a in datos.actividades(en: dia) { r.append(a.color.color) }
        if !datos.recordatorios(en: dia).isEmpty { r.append(ColorHoot.naranja.color) }
        return Array(r.prefix(3))
    }
}

struct ListaDia: View {
    var dia: Date
    var datos: DatosEscolares
    var plan: PlanEstudio?

    var ratos: [Sesion]
    var soloLectura: Bool
    var alTocarActividad: (Actividad) -> Void

    @Environment(Almacen.self) private var almacen

    private enum Fila: Identifiable {
        case examen(Tarea), entrega(Tarea), actividad(Actividad), estudio(Tarea, [Sesion]), recordatorio(Recordatorio)

        var id: String {
            switch self {
            case .examen(let t), .entrega(let t): "t-\(t.id)"
            case .actividad(let a): "a-\(a.id)"
            case .estudio(let t, _): "e-\(t.id)"
            case .recordatorio(let r): "r-\(r.id)"
            }
        }
    }

    private var filas: [Fila] {
        let tareas = datos.tareas(en: dia)
        var r: [Fila] = tareas.filter { $0.tipo == .examen }.map { .examen($0) }
        r += tareas.filter { $0.tipo != .examen }.map { .entrega($0) }

        let entregas = Set(tareas.map(\.id))
        var conHora: [(minuto: Int, clave: String, fila: Fila)] = []
        for a in datos.actividades(en: dia) {
            conHora.append((a.inicio ?? -1, "a\(a.id)", .actividad(a)))
        }
        for (id, sesiones) in Dictionary(grouping: ratos.filter { !entregas.contains($0.tareaID) }, by: \.tareaID) {
            guard let t = datos.tareas.first(where: { $0.id == id }) else { continue }
            let orden = sesiones.sorted { $0.hora < $1.hora }
            conHora.append((orden.first?.hora ?? 0, "e\(id)", .estudio(t, orden)))
        }
        let recordatorios = datos.recordatorios(en: dia)
        for rec in recordatorios where rec.conHora {
            conHora.append((DatosEscolares.minutos(rec.fecha), "r\(rec.id)", .recordatorio(rec)))
        }
        r += conHora.sorted { ($0.minuto, $0.clave) < ($1.minuto, $1.clave) }.map(\.fila)
        r += recordatorios.filter { !$0.conHora }.map { .recordatorio($0) }
        return r
    }

    var body: some View {
        let lista = filas
        VStack(alignment: .leading, spacing: 0) {
            if lista.isEmpty {
                HStack(spacing: 12) {
                    Lobo(tamano: 40, gesto: .dormido)
                    Text(L("Nada este día", "Nothing this day", "Niente in questo giorno"))
                        .textoSecundario()
                }
                .padding(.vertical, 8)
            }
            ForEach(Array(lista.enumerated()), id: \.element.id) { i, f in
                fila(f)
                    .padding(.vertical, 6)
                if i < lista.count - 1 { SeparadorInicio() }
            }
        }
        .animando(Diseno.muelle, valor: DatosEscolares.clave(dia))
    }

    @ViewBuilder
    private func fila(_ f: Fila) -> some View {
        switch f {
        case .examen(let t):
            enlace(t) {
                FilaExamenDia(examen: t, asignatura: datos.asignatura(t.asignaturaID))
            }
        case .entrega(let t):
            if soloLectura {
                FilaTarea(tarea: t, asignatura: datos.asignatura(t.asignaturaID), soloLectura: true, mostrarVence: false)
            } else {
                NavigationLink(value: RutaTarea(id: t.id)) {
                    FilaTarea(tarea: t, asignatura: datos.asignatura(t.asignaturaID), mostrarVence: false) {
                        conMuelle(Diseno.muelleRebote) { almacen.alternarHecha(t.id) }
                    }
                }
                .buttonStyle(.plain)
            }
        case .actividad(let a):
            if soloLectura {
                FilaActividadInicio(actividad: a)
            } else {
                Button { alTocarActividad(a) } label: {
                    FilaActividadInicio(actividad: a).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        case .estudio(let t, let sesiones):
            enlace(t) {
                FilaEstudioDia(tarea: t, asignatura: datos.asignatura(t.asignaturaID), sesiones: sesiones,
                               justa: plan?.empezar(t.id)?.justa ?? false)
            }
        case .recordatorio(let r):
            FilaRecordatorio(recordatorio: r, soloLectura: soloLectura, conDia: false, horaDerecha: true) {
                conMuelle(Diseno.muelleRebote) { almacen.alternarRecordatorio(r.id) }
            }
        }
    }

    @ViewBuilder
    private func enlace<Contenido: View>(_ t: Tarea, @ViewBuilder contenido: () -> Contenido) -> some View {
        if soloLectura {
            contenido()
        } else {
            NavigationLink(value: RutaTarea(id: t.id)) { contenido() }
                .buttonStyle(.plain)
        }
    }
}

struct FilaEstudioDia: View {
    var tarea: Tarea
    var asignatura: Asignatura?
    var sesiones: [Sesion]

    var justa: Bool
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        let varios = sesiones.count > 1
        let total = sesiones.reduce(0) { $0 + $1.minutos }
        HStack(alignment: letra.isAccessibilitySize ? .top : .center, spacing: 12) {
            IconoRato(simbolo: tarea.tipo.simbolo, color: asignatura?.color ?? .indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text(tarea.tituloRato(asignatura))
                    .lineLimit(letra.isAccessibilitySize ? nil : 2)
                Text(detalle)
                    .font(.subheadline)
                    .foregroundStyle(justa ? AnyShapeStyle(EstiloAviso(color: Color.pronto)) : AnyShapeStyle(EstiloSecundario()))
                    .lineLimit(letra.isAccessibilitySize ? nil : 2)
                if varios || letra.isAccessibilitySize {
                    Text(varios
                         ? sesiones.map { Formato.hora($0.hora) }.joined(separator: " · ")
                         : "\(Formato.hora(sesiones[0].hora)) · \(sesiones[0].minutos) min")
                        .font(.subheadline.monospacedDigit())
                        .textoSecundario()
                }
            }
            Spacer(minLength: 8)
            if !letra.isAccessibilitySize, let primera = sesiones.first {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(varios ? L("\(sesiones.count) ratos", "\(sesiones.count) sessions", "\(sesiones.count) sessioni") : Formato.hora(primera.hora))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    Text(varios ? Formato.duracion(minutos: total) : "\(primera.minutos) min")
                        .font(.caption.monospacedDigit())
                        .textoSecundario()
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var detalle: String {
        let dia = Formato.diaSemana(tarea.entrega)
        let para: String
        switch tarea.tipo {
        case .examen: para = L("Para el examen del \(dia)", "For \(dia)'s test", "Per la verifica di \(dia)")
        case .trabajo, .deberes: para = L("Se entrega el \(dia)", "Due \(dia)", "Si consegna \(dia)")
        }
        return justa ? para + L(" · va justo", " · it's tight", " · è stretto") : para
    }
}

struct IconoRato: View {
    var simbolo: String
    var color: ColorHoot

    var body: some View {
        Image(systemName: simbolo)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color.color)
            .frame(width: 32, height: 32)
            .background(Circle().fill(color.color.opacity(0.12)))
            .overlay(Circle().strokeBorder(color.color, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5])))
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)
    }
}

struct FilaExamenDia: View {
    var examen: Tarea
    var asignatura: Asignatura?
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        let total = DatosEscolares.esfuerzo(examen).ratos
        let hechos = min(examen.ratosHechos.count, total)
        let nombre = asignatura?.nombre ?? examen.titulo
        HStack(alignment: letra.isAccessibilitySize ? .top : .center, spacing: 12) {
            RatosExamen(hechos: hechos, total: total, color: asignatura?.color.color ?? Color.acento)
                .frame(width: 40, height: 40)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Examen de \(nombre)", "\(nombre) test", "Verifica di \(nombre)"))
                    .foregroundStyle(examen.hecha ? AnyShapeStyle(EstiloSecundario()) : AnyShapeStyle(Color.primary))
                    .lineLimit(letra.isAccessibilitySize ? nil : 2)
                if !examen.temas.isEmpty {
                    Text(examen.temas)
                        .font(.subheadline)
                        .textoSecundario()
                        .lineLimit(letra.isAccessibilitySize ? nil : 1)
                }
                if letra.isAccessibilitySize {
                    Text(Formato.hora(examen.entrega))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
            }
            Spacer(minLength: 8)
            if !letra.isAccessibilitySize {
                Text(Formato.hora(examen.entrega))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(L("Preparado: \(hechos) de \(total) ratos", "Prepared: \(hechos) of \(total) sessions", "Preparato: \(hechos) di \(total) sessioni"))
    }
}
