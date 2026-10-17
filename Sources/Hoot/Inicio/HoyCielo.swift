import SwiftUI

struct HoyCielo: View {
    @Environment(Almacen.self) private var almacen

    @ScaledMetric(relativeTo: .largeTitle) private var tamanoNumero: CGFloat = 100

    @ScaledMetric(relativeTo: .title) private var ladoLobo: CGFloat = 64

    @State private var diaVista: String?
    @State private var marcos: [String: CGRect] = [:]
    @State private var anchoSemana: CGFloat = 366
    @State private var abierto: DiaAbierto?
    @State private var claseAbierta: Clase?
    @State private var ruta = NavigationPath()
    @State private var actividad: Actividad?
    @State private var poniendoHorario = false
    @State private var viendoHorario = ModoCapturas.verHorario

    var body: some View {
        NavigationStack(path: $ruta) {
            TimelineView(.everyMinute) { contexto in
                let ahora = Reloj.desde(contexto.date)
                let datos = almacen.datosConCalendario
                let r = ResumenInicio(datos: datos, ahora: ahora)
                let semana = DiaSemana.semana(datos, plan: r.plan, ahora: ahora)
                let vista = semana.first { $0.id == diaVista }
                ScrollViewReader { desplazar in
                ScrollView {
                    VStack(spacing: 0) {

                        cabecera(r, datos: datos, semana: semana, vista: vista)
                            .padding(.top, -4)
                        if datos.horario.isEmpty {
                            Button(L("Poner el horario", "Add timetable", "Aggiungi l'orario"), systemImage: "calendar.badge.plus") {
                                poniendoHorario = true
                            }
                            .buttonStyle(.glass)
                            .chocable(.capsula, reacciona: true)
                            .padding(.top, 16)
                        }
                        modulos(r, datos: datos, semana: semana, vista: vista, ahora: ahora)

                            .padding(.top, max(68, ladoLobo + 4))
                    }
                    .padding(.horizontal, Diseno.margen)
                    .padding(.bottom, 40)
                    .environment(\.colorScheme, .dark)
                    .environment(\.sobreCielo, true)
                    .environment(\.cieloSinVelo, true)
                }
                .scrollIndicators(.hidden)
                .background {

                    FondoTiempo(sinVelo: true)
                }
                .onAppear {
                    if diaVista == nil, let n = ModoCapturas.valor("-vistazo").flatMap(Int.init), semana.indices.contains(n) {
                        diaVista = semana[n].id
                    }

                    if ModoCapturas.activo, let ir = ModoCapturas.valor("-ir") { desplazar.scrollTo(ir, anchor: .top) }
                    if ModoCapturas.activo, let n = ModoCapturas.valor("-clase").flatMap(Int.init) {
                        let clases = datos.clases(en: ahora)
                        if clases.indices.contains(n) { claseAbierta = clases[n] }
                    }
                }
                }
            }
            .conBotonCuenta()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { BotonCalendario() }
            }
            .navigationDestination(for: RutaTarea.self) { ruta in TareaDetalle(id: ruta.id) }
            .sheet(item: $abierto) { d in
                HojaDia(dia: d.fecha, datos: almacen.datosConCalendario, soloLectura: false) { a in actividad = a }
                    .hojaQueChoca()
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $actividad) { a in HojaActividad(actividad: a).hojaQueChoca() }
            .sheet(item: $claseAbierta) { c in
                HojaClase(clase: c, datos: almacen.datos, ahora: Reloj.ahora)
                    .hojaQueChoca()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $poniendoHorario) { HojaHorario().hojaQueChoca() }
            .sheet(isPresented: $viendoHorario) { HojaHorario(editando: false).hojaQueChoca() }
            .sensoryFeedback(.selection, trigger: diaVista)
        }
    }

    struct DatosCabecera {
        var etiqueta: String
        var titulo: String
        var numero: NumeroHoy
        var linea: String
        var dia: Date?
    }

    enum NumeroHoy: Equatable {
        case minutos(Int), duracion(Int), hora(Int), libre, nada
    }

    @ViewBuilder
    private func cabecera(_ r: ResumenInicio, datos: DatosEscolares, semana: [DiaSemana], vista: DiaSemana?) -> some View {
        let c = vista.map { Self.cabecera(dia: $0, datos: datos) } ?? Self.cabecera(r, datos: datos)
        let motivo = vista == nil && r.gestoLobo == .preocupado ? r.motivoPreocupacion : nil
        let franja = c.dia.flatMap { d in Self.diaSemana(d, semana: semana, datos: datos, r: r)?.franja }
        VStack(spacing: 0) {
            Text(c.etiqueta.uppercased(with: localeActual))
                .font(.footnote.weight(.semibold))
            Text(c.titulo)
                .font(.largeTitle)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .contentTransition(.opacity)
            numero(c.numero)

                .padding(.top, -13)
            Group {
                if let motivo {

                    Text("\(Text(Image(systemName: "exclamationmark.circle.fill")).foregroundStyle(Color.avisoCielo)) \(motivo)")
                } else if !c.linea.isEmpty {
                    Text(c.linea)
                }
            }
            .font(.title3.weight(.medium))
            .padding(.top, -6)
            if let franja, let dia = c.dia {
                Text(Self.textoFranja(franja, dia: dia, ahora: r.ahora))
                    .font(.title3.weight(.medium))
                    .monospacedDigit()
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .foregroundStyle(.white)
        .modifier(SombraCabecera())
        .accessibilityElement(children: .combine)
        .animation(Diseno.muelle, value: vista?.id)
    }

    @ViewBuilder
    private func numero(_ n: NumeroHoy) -> some View {
        let grande = Font.system(size: tamanoNumero, weight: .thin)
        Group {
            switch n {
            case .minutos(let m):
                Text("\(m)′").font(grande)
            case .duracion(let total):
                let h = total / 60, m = total % 60
                if h == 0 {
                    Text("\(m)′").font(grande)
                } else {

                    let unidad = Font.system(size: tamanoNumero * 0.36, weight: .light)
                    Text("\(Text("\(h)").font(grande))\(Text("h").font(unidad))\(Text(m > 0 ? "\(m)" : "").font(grande))")
                }
            case .hora(let minutos):
                Text(Formato.hora(minutos)).font(grande)
            case .libre:
                Image(systemName: "checkmark")
                    .font(.system(size: tamanoNumero * 0.62, weight: .thin))
                    .frame(height: tamanoNumero * 1.19)
            case .nada:
                Text("—").font(grande)
            }
        }
        .monospacedDigit()
        .contentTransition(.numericText())
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .chocableComoTexto(tamano: tamanoNumero)

        .accessibilityLabel(Self.leido(n))
    }

    private static func leido(_ n: NumeroHoy) -> String {
        switch n {
        case .minutos(let m): L("\(m) minutos", "\(m) minutes", "\(m) minuti")
        case .duracion(let m): Formato.duracion(minutos: m)
        case .hora(let m): Formato.hora(m)
        case .libre: L("Libre", "Free", "Libero")
        case .nada: ""
        }
    }

    static func cabecera(_ r: ResumenInicio, datos: DatosEscolares) -> DatosCabecera {
        let m = DatosEscolares.minutos(r.ahora)
        let fecha = Formato.diaLargo(r.hoy)
        let mochila = r.totalMochila > 0 && !r.mochilaLista
            ? L("Mochila: \(r.metidas) de \(r.totalMochila)", "Backpack: \(r.metidas) of \(r.totalMochila)", "Zaino: \(r.metidas) di \(r.totalMochila)") : ""

        let estudio = r.ratosHoy.reduce(0) { $0 + $1.minutos }
            + r.entregasHoy.filter { $0.entrega < r.hoy }.reduce(0) { $0 + DiaSemana.minutosPendientes($1) }

        func primeraClase(linea: String) -> DatosCabecera? {
            guard let d = r.diaClases, let p = r.clases.first else { return nil }
            return DatosCabecera(etiqueta: Formato.diaLargo(d), titulo: datos.asignatura(p.asignaturaID)?.nombre ?? "",
                                 numero: .hora(p.inicio), linea: linea, dia: d)
        }
        switch r.momento {
        case .manana:
            let (actual, siguiente) = datos.claseAhora(r.ahora)
            if let c = actual, let a = datos.asignatura(c.asignaturaID) {
                let despues = siguiente.flatMap { datos.asignatura($0.asignaturaID)?.nombre }
                return DatosCabecera(etiqueta: fecha, titulo: a.nombre, numero: .minutos(c.fin - m),
                                     linea: despues.map { L("Después, \($0)", "Then \($0)", "Poi \($0)") }
                                        ?? L("Última clase de hoy", "Last class today", "Ultima lezione di oggi"),
                                     dia: r.hoy)
            }
            let hoyHayClase = !datos.clases(en: r.ahora).isEmpty
            if hoyHayClase, let s = siguiente, let a = datos.asignatura(s.asignaturaID), let p = r.clases.first, m > p.inicio {
                return DatosCabecera(etiqueta: fecha, titulo: L("Recreo", "Break", "Ricreazione"), numero: .minutos(s.inicio - m),
                                     linea: L("Después, \(a.nombre)", "Then \(a.nombre)", "Poi \(a.nombre)"), dia: r.hoy)
            }

            if !hoyHayClase, estudio > 0 {
                return DatosCabecera(etiqueta: fecha, titulo: L("Estudio", "Study", "Studio"), numero: .duracion(estudio),
                                     linea: r.ratosHoy.first.map { L("Empiezas a las \(Formato.hora($0.hora))", "Starting at \(Formato.hora($0.hora))", "Inizi alle \(Formato.hora($0.hora))") } ?? "",
                                     dia: r.hoy)
            }
            if let p = primeraClase(linea: mochila.isEmpty ? L("Primera clase", "First class", "Prima lezione") : mochila) { return p }
            return DatosCabecera(etiqueta: fecha, titulo: L("Hoy no hay clase", "No school today", "Oggi niente scuola"),
                                 numero: .nada, linea: "", dia: nil)
        case .tarde:
            if let primero = r.ratosHoy.first {
                return DatosCabecera(etiqueta: fecha, titulo: L("Estudio", "Study", "Studio"), numero: .duracion(estudio),
                                     linea: L("Empiezas a las \(Formato.hora(primero.hora))", "Starting at \(Formato.hora(primero.hora))", "Inizi alle \(Formato.hora(primero.hora))"),
                                     dia: r.hoy)
            }
            if estudio > 0 {

                return DatosCabecera(etiqueta: fecha, titulo: L("Deberes", "Homework", "Compiti"), numero: .duracion(estudio),
                                     linea: mochila, dia: r.hoy)
            }
            return DatosCabecera(etiqueta: fecha, titulo: L("Tarde libre", "Free afternoon", "Pomeriggio libero"), numero: .libre,
                                 linea: mochila, dia: r.hoy)
        case .noche:
            let linea = !mochila.isEmpty ? mochila
                : (r.mochilaLista ? L("Mochila lista", "Backpack ready", "Zaino pronto") : L("Primera clase", "First class", "Prima lezione"))
            if let p = primeraClase(linea: linea) { return p }
            return DatosCabecera(etiqueta: fecha, titulo: L("A descansar", "Time to rest", "Riposati"), numero: .nada, linea: "", dia: nil)
        }
    }

    static func cabecera(dia d: DiaSemana, datos: DatosEscolares) -> DatosCabecera {
        let cosas = d.cosas(datos)
        let primera = cosas.first?.titulo ?? (d.lectivo ? L("Solo las clases", "Just classes", "Solo le lezioni") : L("Nada", "Nothing", "Niente"))
        let mas = cosas.count > 1 ? L("y \(cosas.count - 1) más", "and \(cosas.count - 1) more", "e altre \(cosas.count - 1)") : ""
        return DatosCabecera(etiqueta: Formato.diaLargo(d.dia), titulo: primera, numero: d.carga > 0 ? .duracion(d.carga) : .libre,
                             linea: mas, dia: d.dia)
    }

    static func textoFranja(_ f: (inicio: Int, fin: Int), dia: Date, ahora: Date) -> String {
        let cuando = Formato.diaRelativo(dia, desde: ahora)
        let (i, a) = (Formato.hora(f.inicio), Formato.hora(f.fin))
        return L("\(cuando), de \(i) a \(a)", "\(cuando), \(i) to \(a)", "\(cuando), dalle \(i) alle \(a)")
    }

    private static func diaSemana(_ fecha: Date, semana: [DiaSemana], datos: DatosEscolares, r: ResumenInicio) -> DiaSemana? {
        semana.first { calendarioActual.isDate($0.dia, inSameDayAs: fecha) }
            ?? DiaSemana.semana(datos, plan: r.plan, ahora: r.ahora, desde: fecha).first
    }

    @ViewBuilder
    private func modulos(_ r: ResumenInicio, datos: DatosEscolares, semana: [DiaSemana], vista: DiaSemana?, ahora: Date) -> some View {
        let momentos = Self.momentos(r, datos: datos, horaMochila: almacen.ajustes.avisos.horaMochila)

        VStack(spacing: Diseno.huecoTarjetas) {
            if !momentos.isEmpty {
                ModuloTiempo(titulo: L("Por horas", "Hourly", "Ora per ora"), subtitulo: Self.resumen(momentos)) {

                    Button { viendoHorario = true } label: {
                        Label(L("Horario", "Timetable", "Orario"), systemImage: "calendar")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(.black)
                } contenido: {
                    TiraHoras(momentos: momentos) { accion in
                        switch accion {
                        case .clase(let c): claseAbierta = c
                        case .tarea(let id): ruta.append(RutaTarea(id: id))
                        case .actividad(let a): actividad = a
                        case .mochila: almacen.pestana = .mochila
                        case .dia(let d): abierto = DiaAbierto(fecha: d)
                        }
                    }
                    .padding(.horizontal, -Diseno.margenTarjeta)
                    .contentMargins(.horizontal, Diseno.margenTarjeta, for: .scrollContent)
                }
                .overlay { lobo(r, vista: vista) }
            }
            ModuloTiempo {
                semanaVista(semana, datos: datos, ahora: ahora)
            }
            .overlay { if momentos.isEmpty { lobo(r, vista: vista) } }
            let filas = Self.filas(r)
            ModuloTiempo(titulo: L("Para hoy", "For today", "Per oggi"), subtitulo: Self.resumen(filas)) {
                paraHoy(r, datos: datos, filas: filas)
                    .padding(.top, -4)
            }
            .id("parahoy")
        }
    }

    private func lobo(_ r: ResumenInicio, vista: DiaSemana?) -> some View {
        SentadoEncima(derecha: 14, hundido: ladoLobo * 0.03) {
            LoboInteractivo(tamano: ladoLobo, gesto: gestoLobo(r, vista: vista), mirada: CGPoint(x: -0.7, y: -0.2),
                            saludo: vista == nil && r.momento == .noche && r.gestoLobo == .normal ? .aullando : nil,
                            paraguasSiLlueve: true)
        }
    }

    private func gestoLobo(_ r: ResumenInicio, vista: DiaSemana?) -> GestoLobo {
        if ModoCapturas.activo, let g = ModoCapturas.valor("-gesto").flatMap(GestoLobo.init(rawValue:)) { return g }
        if let g = Desarrollo.compartido.gestoForzado { return g }
        guard let vista else { return r.gestoLobo }
        return vista.examenes.isEmpty ? .normal : .preocupado
    }

    static func resumen(_ momentos: [MomentoHora]) -> String {
        var clases = 0, actividades = 0, estudio = 0
        for mo in momentos {
            switch mo.accion {
            case .clase: clases += 1
            case .actividad: actividades += 1
            case .tarea: estudio += mo.minutos
            default: break
            }
        }
        return [
            clases > 0 ? L("\(clases) \(clases == 1 ? "clase" : "clases")", "\(clases) \(clases == 1 ? "class" : "classes")", "\(clases) \(clases == 1 ? "lezione" : "lezioni")") : nil,
            estudio > 0 ? L("\(Formato.duracion(minutos: estudio)) de estudio", "\(Formato.duracion(minutos: estudio)) of study", "\(Formato.duracion(minutos: estudio)) di studio") : nil,
            actividades > 0 ? L("\(actividades) \(actividades == 1 ? "actividad" : "actividades")", "\(actividades) \(actividades == 1 ? "activity" : "activities")", "\(actividades) \(actividades == 1 ? "attività" : "attività")") : nil,
        ].compactMap { $0 }.joined(separator: " · ")
    }

    private static func resumen(_ filas: [FilaHoy]) -> String {
        let hechas = filas.filter { if case .hecho = $0 { true } else { false } }.count
        let quedan = filas.count - hechas
        return [
            quedan > 0 ? L("\(quedan) por hacer", "\(quedan) to do", "\(quedan) da fare") : nil,
            hechas > 0 ? L("\(hechas) \(hechas == 1 ? "hecha" : "hechas")", "\(hechas) done", "\(hechas) \(hechas == 1 ? "fatta" : "fatte")") : nil,
        ].compactMap { $0 }.joined(separator: " · ")
    }

    @ViewBuilder
    private func semanaVista(_ semana: [DiaSemana], datos: DatosEscolares, ahora: Date) -> some View {

        let franjas = semana.compactMap(\.franja)
        let eje = franjas.isEmpty ? nil : (franjas.map(\.inicio).min() ?? 0)...max((franjas.map(\.fin).max() ?? 0), (franjas.map(\.inicio).min() ?? 0) + 60)
        let fila = { (y: CGFloat) in marcos.first { $0.value.minY <= y && y < $0.value.maxY }?.key }
        VStack(spacing: 0) {
            ForEach(Array(semana.enumerated()), id: \.element.id) { i, d in
                FilaPronostico(dia: d, datos: datos, ahora: ahora, eje: eje, anchoContenido: anchoSemana, elegida: diaVista == d.id)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("semana")) } action: { marcos[d.id] = $0 }
                    .accessibilityLabel(d.resumen(datos))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { abierto = DiaAbierto(fecha: d.dia) }
                if i < semana.count - 1 {
                    Rectangle().fill(.white.opacity(0.14)).frame(height: 0.5)
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { anchoSemana = $0 }
        .coordinateSpace(.named("semana"))
        .contentShape(Rectangle())

        .gesture(MantenerYDeslizar(
            alEmpezar: { p in if let id = fila(p.y) { conMuelle(Diseno.muelleRapido) { diaVista = id } } },
            alMover: { p in if let id = fila(p.y), id != diaVista { conMuelle(Diseno.muelleRapido) { diaVista = id } } },
            alAcabar: { conMuelle { diaVista = nil } }
        ))

        .onTapGesture(coordinateSpace: .named("semana")) { p in
            if let id = fila(p.y), let d = semana.first(where: { $0.id == id }) { abierto = DiaAbierto(fecha: d.dia) }
        }
    }

    @ViewBuilder
    private func paraHoy(_ r: ResumenInicio, datos: DatosEscolares, filas: [FilaHoy]) -> some View {
        if filas.isEmpty {
            Label(L("Nada pendiente", "Nothing to do", "Niente da fare"), systemImage: "checkmark.circle.fill")
                .font(.body.weight(.medium))
                .foregroundStyle(Color.hecho)
                .padding(.vertical, 12)
        }
        ForEach(Array(filas.enumerated()), id: \.element.id) { i, f in
            Group {
                switch f {
                case .mochila:
                    FilaMochilaInicio(resumen: r) { almacen.pestana = .mochila }
                case .tarea(let t):
                    NavigationLink(value: RutaTarea(id: t.id)) {
                        FilaTarea(tarea: t, asignatura: datos.asignatura(t.asignaturaID), mostrarVence: t.entrega < r.ahora) {
                            conMuelle(Diseno.muelleRebote) { almacen.alternarHecha(t.id) }
                        }
                    }
                    .buttonStyle(.plain)
                case .rato(let s, let t):
                    NavigationLink(value: RutaTarea(id: t.id)) {
                        FilaRato(sesion: s, tarea: t, asignatura: datos.asignatura(t.asignaturaID), hecho: false, ahora: r.ahora) {
                            conMuelle(Diseno.muelleRebote) { almacen.alternarRato(t.id, dia: r.ahora) }
                        }
                    }
                    .buttonStyle(.plain)
                case .hecho(let t):
                    FilaRato(sesion: nil, tarea: t, asignatura: datos.asignatura(t.asignaturaID), hecho: true, ahora: r.ahora) {
                        conMuelle(Diseno.muelleRebote) { almacen.alternarRato(t.id, dia: r.ahora) }
                    }
                case .recordatorio(let rec):
                    FilaRecordatorio(recordatorio: rec, conDia: false, horaDerecha: true) {
                        conMuelle(Diseno.muelleRebote) { almacen.alternarRecordatorio(rec.id) }
                    }
                }
            }
            .padding(.vertical, 4)
            if i < filas.count - 1 { SeparadorInicio() }
        }
    }

    fileprivate enum FilaHoy: Identifiable {
        case mochila, tarea(Tarea), rato(Sesion, Tarea), hecho(Tarea), recordatorio(Recordatorio)

        var id: String {
            switch self {
            case .mochila: "mochila"
            case .tarea(let t): "t\(t.id)"
            case .rato(_, let t): "s\(t.id)"
            case .hecho(let t): "h\(t.id)"
            case .recordatorio(let r): "r\(r.id)"
            }
        }
    }

    private static func filas(_ r: ResumenInicio) -> [FilaHoy] {
        var lista: [FilaHoy] = []
        lista += r.entregasHoy.filter { $0.entrega < r.ahora }.map { .tarea($0) }

        if r.totalMochila > 0, !r.mochilaLista, (r.momento == .manana && r.mochilaDia == r.hoy) || r.momento == .noche {
            lista.append(.mochila)
        }
        lista += r.entregasHoy.filter { $0.entrega >= r.ahora }.map { .tarea($0) }
        var vistas = Set<UUID>()
        for s in r.ratosHoy where !vistas.contains(s.tareaID) {
            vistas.insert(s.tareaID)
            if let t = r.tareasPorID[s.tareaID] { lista.append(.rato(s, t)) }
        }
        lista += r.recordatorios.map { .recordatorio($0) }
        lista += r.hechosHoy.map { .hecho($0) }
        return lista
    }

    static func momentos(_ r: ResumenInicio, datos: DatosEscolares, horaMochila: Int) -> [MomentoHora] {
        let m = DatosEscolares.minutos(r.ahora)
        var lista: [(Int, MomentoHora)] = []
        for c in datos.clases(en: r.ahora) where c.fin > m {
            let a = datos.asignatura(c.asignaturaID)
            let ya = c.inicio <= m
            lista.append((c.inicio, MomentoHora(id: "c\(c.id)", hora: ya ? L("Ahora", "Now", "Ora") : Formato.hora(c.inicio),
                                                simbolo: a?.simbolo ?? "book.closed", color: a?.color ?? .gris,
                                                abajo: "\(c.fin - max(c.inicio, m))′", propuesta: false, ahora: ya,
                                                nombre: a?.nombre ?? "", accion: .clase(c), minutos: c.fin - c.inicio)))
        }
        for s in r.ratosHoy where s.hora + s.minutos > m {
            let t = r.tareasPorID[s.tareaID]
            let a = datos.asignatura(t?.asignaturaID)
            lista.append((s.hora, MomentoHora(id: "s\(s.id)", hora: Formato.hora(s.hora), simbolo: t?.tipo.simbolo ?? "hourglass",
                                              color: a?.color ?? .indigo, abajo: "\(s.minutos)′", propuesta: true, ahora: false,
                                              nombre: t?.titulo ?? "", accion: .tarea(s.tareaID), minutos: s.minutos)))
        }
        for a in datos.actividades(en: r.ahora) {
            guard let i = a.inicio, (a.fin ?? i + 60) > m else { continue }
            let dura = a.fin.map { $0 - max(i, m) }
            lista.append((i, MomentoHora(id: "a\(a.id)", hora: i <= m ? L("Ahora", "Now", "Ora") : Formato.hora(i), simbolo: a.simbolo,
                                         color: a.color, abajo: dura.map { "\($0)′" } ?? "", propuesta: false, ahora: i <= m,
                                         nombre: a.titulo, accion: .actividad(a), minutos: dura ?? 0)))
        }
        if r.totalMochila > 0, !r.mochilaLista, let dia = r.mochilaDia, dia > r.hoy, horaMochila > m {
            lista.append((horaMochila, MomentoHora(id: "mochila", hora: Formato.hora(horaMochila), simbolo: "backpack.fill", color: .indigo,
                                                   abajo: "\(r.metidas)/\(r.totalMochila)", propuesta: false, ahora: false,
                                                   nombre: L("Mochila", "Backpack", "Zaino"), accion: .mochila)))
        }
        if let d = r.diaClases, d > r.hoy, let p = datos.clases(en: d).first {
            let a = datos.asignatura(p.asignaturaID)

            let dia = Formato.nombreDia(iso: DatosEscolares.diaISO(d)).conMayuscula
            lista.append((24 * 60 + p.inicio, MomentoHora(id: "manana", hora: dia, simbolo: a?.simbolo ?? "book.closed",
                                                          color: a?.color ?? .gris, abajo: Formato.hora(p.inicio), propuesta: false, ahora: false,
                                                          nombre: a?.nombre ?? "", accion: .dia(d))))
        }
        return Array(lista.sorted { $0.0 < $1.0 }.map(\.1).prefix(12))
    }
}

struct SentadoEncima: Layout {

    var derecha: CGFloat

    var hundido: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for vista in subviews {
            let t = vista.sizeThatFits(.unspecified)
            vista.place(at: CGPoint(x: bounds.maxX - derecha - t.width, y: bounds.minY + hundido - t.height),
                        anchor: .topLeading, proposal: ProposedViewSize(t))
        }
    }
}

struct FilaPronostico: View {
    var dia: DiaSemana
    var datos: DatosEscolares
    var ahora: Date

    var eje: ClosedRange<Int>?

    var anchoContenido: CGFloat
    var elegida: Bool
    @Environment(\.dynamicTypeSize) private var letra

    @ScaledMetric(relativeTo: .headline) private var anchoHora: CGFloat = 54
    @ScaledMetric(relativeTo: .headline) private var ladoIcono: CGFloat = 26
    @ScaledMetric(relativeTo: .headline) private var altoFila: CGFloat = 52.7

    var body: some View {
        let importante = loImportante(dia, datos)
        Group {
            if letra.isAccessibilitySize {

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        nombre
                        Spacer(minLength: 8)
                        icono(importante)
                    }
                    franja
                }
                .padding(.vertical, 10)
            } else {
                HStack(spacing: 0) {
                    nombre
                        .frame(width: max(60, anchoContenido * 0.257), alignment: .leading)
                    icono(importante)
                        .frame(width: max(ladoIcono, anchoContenido * 0.101))
                    Spacer(minLength: 6)

                    franja
                        .layoutPriority(1)
                }
                .padding(.vertical, 5)
                .frame(minHeight: altoFila)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .background(elegida ? .white.opacity(Diseno.resalteElegido) : .clear, in: RoundedRectangle(cornerRadius: Diseno.radioResalte, style: .continuous))
        .padding(.horizontal, -8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
    }

    private var nombre: some View {
        Text(dia.nombre(ahora: ahora))
            .font(.headline)
            .lineLimit(1)
    }

    private func icono(_ importante: (simbolo: String, color: Color, nombre: String, libre: Bool)) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle().fill(importante.libre ? AnyShapeStyle(.white.opacity(0.18)) : AnyShapeStyle(importante.color.gradient))
                Image(systemName: importante.simbolo)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: ladoIcono, height: ladoIcono)
            .chocable(.circulo)
            if dia.carga > 0 {
                Text(dia.carga < 60 ? "\(dia.carga)′" : Formato.duracionCorta(minutos: dia.carga))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.cianCielo)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var franja: some View {
        let ancho = min(100, max(40, anchoContenido * 0.273))
        if let f = dia.franja, let eje {
            let total = Double(max(1, eje.upperBound - eje.lowerBound))
            let m = DatosEscolares.minutos(ahora)
            let esHoy = calendarioActual.isDate(dia.dia, inSameDayAs: ahora)
            HStack(spacing: 0) {

                Text(Formato.hora(f.inicio))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(EstiloSecundario())
                    .fixedSize()
                    .frame(minWidth: anchoHora, alignment: .trailing)
                BarraFranja(desde: Double(f.inicio - eje.lowerBound) / total, hasta: Double(f.fin - eje.lowerBound) / total,
                            carga: Double(dia.carga) / 150,
                            ahora: esHoy && (f.inicio...f.fin).contains(m) ? Double(m - eje.lowerBound) / total : nil)
                    .frame(maxWidth: ancho)
                    .layoutPriority(1)
                    .padding(.horizontal, 9)
                Text(Formato.hora(f.fin))
                    .font(.headline.monospacedDigit())
                    .fixedSize()
                    .frame(minWidth: anchoHora, alignment: .trailing)
            }
        } else {
            HStack(spacing: 0) {
                Color.clear.frame(width: anchoHora, height: 1)
                Text(L("Libre", "Free", "Libero"))
                    .font(.headline)
                    .foregroundStyle(EstiloSecundario())
                    .frame(maxWidth: ancho)
                    .layoutPriority(1)
                    .padding(.horizontal, 9)
                Color.clear.frame(width: anchoHora, height: 1)
            }
        }
    }
}

struct SombraCabecera: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(0.22), radius: 7)
    }
}
