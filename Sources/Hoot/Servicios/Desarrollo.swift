import SwiftUI
import UserNotifications

@Observable
final class Desarrollo {
    static let compartido = Desarrollo()

    private(set) var parada: Date?

    private(set) var desfase: TimeInterval = 0
    var horaSimulada: Bool { parada != nil || desfase != 0 }

    var iaForzada: DisponibilidadIA? { didSet { guardarAjustes() } }
    var gestoForzado: GestoLobo? { didSet { guardarAjustes() } }

    var tiempoForzado: Tiempo? { didSet { guardarAjustes() } }

    var nocheForzada: Bool? { didSet { guardarAjustes() } }

    var vidaQuieta = false { didSet { guardarAjustes() } }
    var vidaAhorro = false { didSet { guardarAjustes() } }
    var vidaTenue = false { didSet { guardarAjustes() } }
    var claveVida: String { "\(vidaQuieta)\(vidaAhorro)\(vidaTenue)" }

    var letraForzada: DynamicTypeSize? { didSet { guardarAjustes() } }
    var aparienciaForzada: ColorScheme? { didSet { guardarAjustes() } }
    var negrita = false { didSet { guardarAjustes() } }

    static let letras: [(clave: String, tamano: DynamicTypeSize)] = [
        ("xSmall", .xSmall), ("large", .large), ("xxxLarge", .xxxLarge), ("accessibility3", .accessibility3), ("accessibility5", .accessibility5),
    ]

    var calendariosDeEjemplo = false { didSet { Calendarios.compartido.recargar() } }

    enum SimulacionTeams: String, CaseIterable, Identifiable {
        case permitido, bloqueado
        var id: String { rawValue }
    }

    var teamsSimulado: SimulacionTeams?

    @ObservationIgnored var rayoPedido = false

    @ObservationIgnored var rehacerAlCerrar = false

    private(set) var configurando = false

    private init() {
        if ModoCapturas.activo {

            configurando = ModoCapturas.salidaConfiguracion
            teamsSimulado = ModoCapturas.valor("-teams").flatMap(SimulacionTeams.init(rawValue:))
            letraForzada = ModoCapturas.valor("-letra").flatMap { c in Self.letras.first { $0.clave == c }?.tamano }
            switch ModoCapturas.valor("-apariencia") {
            case "claro": aparienciaForzada = .light
            case "oscuro": aparienciaForzada = .dark
            default: break
            }
            return
        }
        leerAjustes()
    }

    private enum Clave {
        static let desfase = "hoot.desarrollo.desfase"
        static let parada = "hoot.desarrollo.parada"
        static let ia = "hoot.desarrollo.ia"
        static let gesto = "hoot.desarrollo.gesto"
        static let tiempo = "hoot.desarrollo.tiempo"
        static let noche = "hoot.desarrollo.noche"
        static let vida = "hoot.desarrollo.vida"
        static let letra = "hoot.desarrollo.letra"
        static let apariencia = "hoot.desarrollo.apariencia"
        static let negrita = "hoot.desarrollo.negrita"
        static let configurando = "hoot.desarrollo.configurando"
    }

    static let casosIA: [(clave: String, caso: DisponibilidadIA)] = [
        ("lista", .lista), ("noCompatible", .noCompatible), ("desactivada", .desactivada),
        ("preparando", .preparando), ("idiomaNoDisponible", .idiomaNoDisponible),
    ]

    private var cargandoAjustes = false

    private func leerAjustes() {
        cargandoAjustes = true
        defer { cargandoAjustes = false }
        let d = UserDefaults.standard
        iaForzada = d.string(forKey: Clave.ia).flatMap { c in Self.casosIA.first { $0.clave == c }?.caso }
        gestoForzado = d.string(forKey: Clave.gesto).flatMap(GestoLobo.init(rawValue:))
        tiempoForzado = d.string(forKey: Clave.tiempo).flatMap(Tiempo.init(rawValue:))
        switch d.integer(forKey: Clave.noche) {
        case 1: nocheForzada = false
        case 2: nocheForzada = true
        default: nocheForzada = nil
        }
        let vida = d.array(forKey: Clave.vida) as? [Bool] ?? []
        vidaQuieta = vida.count == 3 && vida[0]
        vidaAhorro = vida.count == 3 && vida[1]
        vidaTenue = vida.count == 3 && vida[2]
        letraForzada = d.string(forKey: Clave.letra).flatMap { c in Self.letras.first { $0.clave == c }?.tamano }
        switch d.string(forKey: Clave.apariencia) {
        case "claro": aparienciaForzada = .light
        case "oscuro": aparienciaForzada = .dark
        default: aparienciaForzada = nil
        }
        negrita = d.bool(forKey: Clave.negrita)
        configurando = d.bool(forKey: Clave.configurando)
    }

    private func guardarAjustes() {
        guard !cargandoAjustes, !ModoCapturas.activo else { return }
        let d = UserDefaults.standard
        d.set(iaForzada.flatMap { c in Self.casosIA.first { $0.caso == c }?.clave }, forKey: Clave.ia)
        d.set(gestoForzado?.rawValue, forKey: Clave.gesto)
        d.set(tiempoForzado?.rawValue, forKey: Clave.tiempo)
        d.set(nocheForzada.map { $0 ? 2 : 1 } ?? 0, forKey: Clave.noche)
        d.set([vidaQuieta, vidaAhorro, vidaTenue], forKey: Clave.vida)
        d.set(letraForzada.flatMap { t in Self.letras.first { $0.tamano == t }?.clave }, forKey: Clave.letra)
        d.set(aparienciaForzada.map { $0 == .dark ? "oscuro" : "claro" }, forKey: Clave.apariencia)
        d.set(negrita, forKey: Clave.negrita)
        d.set(configurando, forKey: Clave.configurando)
    }

    func cargarHora() {
        guard !ModoCapturas.activo else { return }
        let d = UserDefaults.standard
        desfase = d.double(forKey: Clave.desfase)
        let p = d.double(forKey: Clave.parada)
        parada = p > 0 ? Date(timeIntervalSince1970: p) : nil
        Reloj.desfase = desfase
        Reloj.parado = parada
    }

    func ponerHora(_ fecha: Date, parada parar: Bool) {
        if parar {
            parada = fecha
            desfase = 0
        } else {
            parada = nil
            desfase = fecha.timeIntervalSince(Date())
        }
        aplicarHora()
    }

    func parar(_ parar: Bool) {
        ponerHora(Reloj.ahora, parada: parar)
    }

    func horaDeVerdad() {
        parada = nil
        desfase = 0
        aplicarHora()
    }

    func mover(_ segundos: TimeInterval) {
        ponerHora(Reloj.ahora.addingTimeInterval(segundos), parada: parada != nil)
    }

    private func aplicarHora() {
        Reloj.desfase = desfase
        Reloj.parado = parada
        rehacerAlCerrar = true
        let d = UserDefaults.standard
        d.set(desfase, forKey: Clave.desfase)
        d.set(parada?.timeIntervalSince1970 ?? 0, forKey: Clave.parada)
    }

    static func momento(_ datos: DatosEscolares, hora: Int, minuto: Int, conClase: Bool) -> Date {
        let cal = calendarioActual
        var dia = cal.startOfDay(for: Reloj.ahora)
        if conClase {
            for _ in 0..<8 where !datos.esLectivo(dia) {
                dia = cal.date(byAdding: .day, value: 1, to: dia) ?? dia
            }
        }
        return DatosEscolares.fecha(dia, minutos: hora * 60 + minuto)
    }

    static func proximo(diaISO: Int, hora: Int, minuto: Int) -> Date {
        let cal = calendarioActual
        var dia = cal.startOfDay(for: Reloj.ahora)
        for _ in 0..<7 where DatosEscolares.diaISO(dia) != diaISO {
            dia = cal.date(byAdding: .day, value: 1, to: dia) ?? dia
        }
        return DatosEscolares.fecha(dia, minutos: hora * 60 + minuto)
    }

    func alCerrarCuenta(_ almacen: Almacen) {
        guard rehacerAlCerrar else { return }
        rehacerAlCerrar = false
        almacen.versionIdioma += 1
    }

    enum Copia: String {

        case datos = "prueba-copia"

        case antesDeConfigurar = "prueba-antes-de-configurar"

        var json: URL { Almacen.carpeta.appendingPathComponent(rawValue + ".json") }
        var foto: URL { Almacen.carpeta.appendingPathComponent(rawValue + ".jpg") }
    }

    private(set) var fechas: [String: Date] = [:]

    func fecha(_ c: Copia) -> Date? {
        _ = fechas
        guard let atributos = try? FileManager.default.attributesOfItem(atPath: c.json.path) else { return nil }
        return atributos[.modificationDate] as? Date
    }

    func guardarCopia(_ c: Copia, de almacen: Almacen) {
        almacen.guardarYa()
        guard let data = try? JSONEncoder().encode(almacen.copiaDeTodo) else { return }
        try? data.write(to: c.json, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try? FileManager.default.removeItem(at: c.foto)
        if let foto = almacen.fotoAvatar?.jpegData(compressionQuality: 0.9) {
            try? foto.write(to: c.foto, options: .atomic)
        }
        fechas[c.rawValue] = Date()
    }

    @discardableResult
    func recuperar(_ c: Copia, en almacen: Almacen) -> Bool {
        guard let data = try? Data(contentsOf: c.json), let e = try? CompatibilidadDatos.decodificar(data) else { return false }
        let foto = (try? Data(contentsOf: c.foto)).flatMap(UIImage.init(data:))
        FlujoConfig.olvidar()
        conMuelle(Diseno.muelleLento) {
            almacen.aplicarPrueba(e, foto: foto)
            almacen.pestana = .hoy
        }
        Task { await Avisos.reprogramar(almacen) }
        return true
    }

    func borrar(_ c: Copia) {
        try? FileManager.default.removeItem(at: c.json)
        try? FileManager.default.removeItem(at: c.foto)
        fechas[c.rawValue] = nil
    }

    private func protegerDatos(_ almacen: Almacen) {
        if fecha(.datos) == nil { guardarCopia(.datos, de: almacen) }
    }

    func volverAConfiguracion(_ almacen: Almacen) {
        guardarCopia(.antesDeConfigurar, de: almacen)
        configurando = true
        guardarAjustes()
        cerrarCuentaY(almacen) {
            FlujoConfig.olvidar()
            var nuevo = EstadoGuardado()
            nuevo.ajustes.idioma = almacen.ajustes.idioma
            nuevo.ajustes.region = almacen.ajustes.region
            nuevo.ajustes.escala = .para(region: almacen.ajustes.region)
            conMuelle(Diseno.muelleLento) {
                almacen.aplicarPrueba(nuevo, foto: nil)
                almacen.pestana = .hoy
            }
        }
    }

    func salirDeConfiguracion(_ almacen: Almacen) {
        configurando = false
        guardarAjustes()
        if !recuperar(.antesDeConfigurar, en: almacen) {
            conMuelle(Diseno.muelleLento) { almacen.configurado = true }
        }
        borrar(.antesDeConfigurar)
    }

    func configuracionTerminada() {
        guard configurando else { return }
        configurando = false
        guardarAjustes()
    }

    func cambiarCuenta(_ almacen: Almacen) {
        let aFamilia = !almacen.esFamilia
        cerrarCuentaY(almacen) {
            conMuelle(Diseno.muelleLento) {
                if aFamilia && almacen.hijos.isEmpty {
                    let hijo = Demo.hijo(escala: almacen.ajustes.escala)
                    almacen.hijos = [hijo]
                    almacen.hijoActivoID = hijo.id
                }
                almacen.perfil.rol = aFamilia ? .familia : .estudiante
                almacen.pestana = .hoy
            }
        }
    }

    func cerrarCuentaY(_ almacen: Almacen, _ cambio: @escaping () -> Void) {
        almacen.mostrandoCuenta = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            cambio()
        }
    }

    func aplicar(_ s: Situacion, en almacen: Almacen) {
        protegerDatos(almacen)
        s.aplicar(almacen)
        rehacerAlCerrar = true
    }

    struct Programado: Identifiable, Sendable {
        let id: String
        let titulo: String
        let cuerpo: String
        let fecha: Date?
    }

    static func programados() async -> [Programado] {
        let pendientes = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pendientes
            .filter { !$0.identifier.hasPrefix("prueba-") }
            .map { r in
                Programado(id: r.identifier, titulo: r.content.title, cuerpo: r.content.body,
                           fecha: (r.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate())
            }
            .sorted { ($0.fecha ?? .distantFuture) < ($1.fecha ?? .distantFuture) }
    }

    static func lanzar(titulo: String, cuerpo: String, en segundos: TimeInterval) async {
        let contenido = UNMutableNotificationContent()
        contenido.title = titulo
        contenido.body = cuerpo
        contenido.sound = .default
        let disparador = UNTimeIntervalNotificationTrigger(timeInterval: max(1, segundos), repeats: false)
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "prueba-\(UUID().uuidString)", content: contenido, trigger: disparador))
    }

    static func borrarProgramados() async {
        let centro = UNUserNotificationCenter.current()
        let pendientes = await centro.pendingNotificationRequests()
        centro.removePendingNotificationRequests(withIdentifiers: pendientes.map(\.identifier))
    }
}

enum Situacion: String, CaseIterable, Identifiable {
    case ejemplo, examenManana, examenHoy, atrasadas, todoHecho, semanaCargada, semanaLibre, sinHorario, vacio
    case actividadHoy, recordatorioFamilia, mochilaSinHacer, mochilaHecha, textosLargos
    case unHijo, dosHijos, sinHijos, avisosNuevos, hijoAtrasado, hijoExamen, mochilaHijo

    var id: String { rawValue }

    var deFamilia: Bool {
        switch self {
        case .unHijo, .dosHijos, .sinHijos, .avisosNuevos, .hijoAtrasado, .hijoExamen, .mochilaHijo: true
        default: false
        }
    }

    var nombre: String {
        switch self {
        case .ejemplo: L("Datos de ejemplo", "Sample data", "Dati di esempio")
        case .examenManana: L("Examen mañana sin preparar", "Test tomorrow, not studied", "Verifica domani, non preparata")
        case .examenHoy: L("Examen hoy", "Test today", "Verifica oggi")
        case .atrasadas: L("Tres tareas atrasadas", "Three late assignments", "Tre compiti in ritardo")
        case .todoHecho: L("Todo hecho", "All done", "Tutto fatto")
        case .semanaCargada: L("Semana cargada", "Busy week", "Settimana piena")
        case .semanaLibre: L("Semana sin nada", "Empty week", "Settimana vuota")
        case .sinHorario: L("Sin horario", "No timetable", "Senza orario")
        case .vacio: L("Recién empezada (sin nada)", "Brand new (nothing)", "Appena iniziata (niente)")
        case .actividadHoy: L("Actividad esta tarde", "Activity this afternoon", "Attività oggi pomeriggio")
        case .recordatorioFamilia: L("Recordatorio de tu familia", "Reminder from your family", "Promemoria dalla famiglia")
        case .mochilaSinHacer: L("Mochila sin preparar", "Backpack not packed", "Zaino non preparato")
        case .mochilaHecha: L("Mochila preparada", "Backpack packed", "Zaino pronto")
        case .textosLargos: L("Textos muy largos", "Very long texts", "Testi molto lunghi")
        case .unHijo: L("Un hijo de ejemplo", "One sample child", "Un figlio di esempio")
        case .dosHijos: L("Dos hijos", "Two children", "Due figli")
        case .sinHijos: L("Sin hijos vinculados", "No linked children", "Nessun figlio collegato")
        case .avisosNuevos: L("Avisos sin leer", "Unread updates", "Avvisi non letti")
        case .hijoAtrasado: L("Tarea atrasada del hijo", "Child's late assignment", "Compito in ritardo del figlio")
        case .hijoExamen: L("Examen mañana del hijo", "Child's test tomorrow", "Verifica domani del figlio")
        case .mochilaHijo: L("Mochila del hijo sin preparar", "Child's backpack not packed", "Zaino del figlio non preparato")
        }
    }

    var simbolo: String {
        switch self {
        case .ejemplo: "tray.full.fill"
        case .examenManana, .hijoExamen: "doc.text.magnifyingglass"
        case .examenHoy: "alarm.fill"
        case .atrasadas, .hijoAtrasado: "exclamationmark.circle.fill"
        case .todoHecho: "checkmark.circle.fill"
        case .semanaCargada: "calendar.badge.exclamationmark"
        case .semanaLibre: "sun.max.fill"
        case .sinHorario: "calendar.badge.minus"
        case .vacio: "sparkles"
        case .actividadHoy: "figure.run"
        case .recordatorioFamilia: "bell.fill"
        case .mochilaSinHacer, .mochilaHijo: "backpack.fill"
        case .mochilaHecha: "checkmark.seal.fill"
        case .textosLargos: "text.alignleft"
        case .unHijo: "person.fill"
        case .dosHijos: "person.2.fill"
        case .sinHijos: "person.crop.circle.badge.xmark"
        case .avisosNuevos: "bell.badge.fill"
        }
    }

    var color: ColorHoot {
        switch self {
        case .ejemplo: .azul
        case .examenManana, .examenHoy, .hijoExamen, .atrasadas, .hijoAtrasado: .rojo
        case .todoHecho: .verde
        case .semanaCargada: .naranja
        case .semanaLibre: .amarillo
        case .sinHorario, .vacio, .textosLargos, .sinHijos: .gris
        case .actividadHoy: .naranja
        case .recordatorioFamilia, .avisosNuevos: .naranja
        case .mochilaSinHacer, .mochilaHijo: .marron
        case .mochilaHecha: .verde
        case .unHijo, .dosHijos: .verde
        }
    }

    func aplicar(_ a: Almacen) {
        let cal = calendarioActual
        let ahora = Reloj.ahora
        let hoy = cal.startOfDay(for: ahora)
        func dia(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: hoy) ?? hoy }
        func base() { Demo.cargarEjemplo(a) }
        switch self {
        case .ejemplo:
            base()
        case .examenManana:
            base()
            let manana = a.datos.siguienteDiaConClase(despuesDe: ahora) ?? dia(1)
            a.datos.tareas = Self.conExamen(a.datos, en: DatosEscolares.fecha(manana, minutos: 9 * 60 + 25))
        case .examenHoy:
            base()
            a.datos.tareas = Self.conExamen(a.datos, en: DatosEscolares.fecha(hoy, minutos: 12 * 60 + 40))
        case .atrasadas:
            base()
            let titulos = [
                L("Ejercicios 4 a 8 de la página 52", "Exercises 4 to 8 on page 52", "Esercizi da 4 a 8 a pagina 52"),
                L("Resumen del tema 2", "Unit 2 summary", "Riassunto dell'unità 2"),
                L("Redacción: mi lugar favorito", "Essay: my favorite place", "Tema: il mio posto preferito"),
            ]
            for (i, (t, atras)) in zip(titulos, [1, 2, 4]).enumerated() {
                let asig = a.datos.asignaturas.isEmpty ? nil : a.datos.asignaturas[[0, 3, 1][i] % a.datos.asignaturas.count].id
                a.datos.tareas.append(Tarea(titulo: t, asignaturaID: asig, entrega: DatosEscolares.fecha(dia(-atras), minutos: 23 * 60 + 59)))
            }
        case .todoHecho:
            base()
            let limite = dia(8)
            for i in a.datos.tareas.indices where a.datos.tareas[i].entrega < limite {
                if a.datos.tareas[i].tipo == .examen {
                    a.datos.tareas[i].ratosHechos = (1...4).map { dia(-$0) }
                } else {
                    a.datos.tareas[i].hecha = true
                    a.datos.tareas[i].hechaEl = ahora
                }
            }
            for i in a.datos.recordatorios.indices { a.datos.recordatorios[i].hecho = true }
            if let d = a.datos.diaMochila(ahora: ahora) {
                a.datos.mochilaMarcada[DatosEscolares.clave(d)] = Set(a.datos.itemsMochila(para: d).map(\.id))
            }
        case .semanaCargada:
            base()
            let deberes = [
                L("Problemas de fracciones", "Fraction problems", "Problemi sulle frazioni"),
                L("Lectura del capítulo 3", "Read chapter 3", "Leggere il capitolo 3"),
                L("Vocabulario de la unidad 4", "Unit 4 vocabulary", "Vocabolario dell'unità 4"),
                L("Esquema del tema 5", "Unit 5 outline", "Schema dell'unità 5"),
                L("Comentario de un mapa", "Map commentary", "Commento di una cartina"),
            ]
            var d = ahora
            for n in 0..<5 {
                d = a.datos.siguienteDiaConClase(despuesDe: d) ?? cal.date(byAdding: .day, value: 1, to: d) ?? d
                for k in 0..<2 {
                    let asig = a.datos.asignaturas.isEmpty ? nil : a.datos.asignaturas[(n * 2 + k) % a.datos.asignaturas.count].id
                    a.datos.tareas.append(Tarea(titulo: deberes[(n + k) % deberes.count], asignaturaID: asig,
                                                entrega: DatosEscolares.fecha(d, minutos: 8 * 60 + 30)))
                }
            }
            if let fq = a.datos.asignaturas.first(where: { $0.simbolo == "atom" }) ?? a.datos.asignaturas.first {
                a.datos.tareas.append(Tarea(titulo: L("Examen de Física y Química", "Physics & Chemistry test", "Verifica di fisica e chimica"),
                                            tipo: .examen, asignaturaID: fq.id, entrega: DatosEscolares.fecha(dia(3), minutos: 10 * 60 + 20),
                                            temas: L("Tema 2: la materia", "Unit 2: matter", "Unità 2: la materia")))
                a.datos.tareas.append(Tarea(titulo: L("Trabajo sobre la energía", "Energy project", "Ricerca sull'energia"),
                                            tipo: .trabajo, asignaturaID: fq.id, entrega: DatosEscolares.fecha(dia(4), minutos: 23 * 60 + 59)))
            }
        case .semanaLibre:
            base()
            a.datos.tareas = []
            a.datos.recordatorios = []
            a.datos.actividades = []
        case .sinHorario:
            base()
            a.datos.horario = []
        case .vacio:
            a.datos = DatosEscolares()
            ConexionTeams.compartida.desvincular(a)
        case .actividadHoy:
            if a.datos.asignaturas.isEmpty { base() }
            let inicio = min(DatosEscolares.minutos(ahora) + 90, 22 * 60)
            a.datos.actividades.append(Actividad(titulo: L("Entrenamiento de baloncesto", "Basketball practice", "Allenamento di basket"),
                                                 simbolo: "basketball.fill", color: .naranja, fecha: hoy,
                                                 inicio: inicio, fin: min(inicio + 90, 23 * 60 + 59),
                                                 lugar: L("Polideportivo", "Sports center", "Palazzetto"),
                                                 llevar: [L("Zapatillas", "Sneakers", "Scarpe da ginnastica"), L("Botella de agua", "Water bottle", "Borraccia")],
                                                 aviso: 30))
        case .recordatorioFamilia:
            if a.datos.asignaturas.isEmpty { base() }
            a.datos.recordatorios.append(Recordatorio(titulo: L("Llevar la autorización de la excursión firmada", "Bring the signed field trip form", "Portare l'autorizzazione della gita firmata"),
                                                      fecha: ahora.addingTimeInterval(3600), origen: .familia))
        case .mochilaSinHacer:
            if a.datos.asignaturas.isEmpty { base() }
            if let d = a.datos.diaMochila(ahora: ahora) { a.datos.mochilaMarcada[DatosEscolares.clave(d)] = [] }
        case .mochilaHecha:
            if a.datos.asignaturas.isEmpty { base() }
            if let d = a.datos.diaMochila(ahora: ahora) {
                a.datos.mochilaMarcada[DatosEscolares.clave(d)] = Set(a.datos.itemsMochila(para: d).map(\.id))
            }
        case .textosLargos:
            if a.datos.asignaturas.isEmpty { base() }
            let asig = a.datos.asignaturas.first?.id
            a.datos.tareas.append(Tarea(titulo: L("Comentario de texto del poema «Volverán las oscuras golondrinas» de Gustavo Adolfo Bécquer, con el análisis métrico y las figuras literarias",
                                                  "Commentary on the poem “The Road Not Taken” by Robert Frost, with the meter analysis and the literary devices",
                                                  "Commento del testo della poesia «San Martino» di Giosuè Carducci, con l'analisi metrica e le figure retoriche"),
                                        asignaturaID: asig, entrega: DatosEscolares.fecha(dia(1), minutos: 8 * 60 + 30)))
            a.datos.recordatorios.append(Recordatorio(titulo: L("Pedir en secretaría el certificado de notas del curso pasado para la beca del ayuntamiento",
                                                                "Ask the school office for last year's grade certificate for the town scholarship",
                                                                "Chiedere in segreteria il certificato dei voti dell'anno scorso per la borsa di studio del comune"),
                                                      fecha: DatosEscolares.fecha(hoy, minutos: 18 * 60)))
        case .unHijo:
            let h = Demo.hijo(escala: a.ajustes.escala)
            a.hijos = [h]
            a.hijoActivoID = h.id
        case .dosHijos:
            let h1 = Demo.hijo(escala: a.ajustes.escala)
            var h2 = Demo.hijo(nombre: L("Pablo", "Leo", "Marco"), escala: a.ajustes.escala)
            h2.curso = L("6.º de Primaria", "6th grade", "5ª elementare")
            h2.colorAvatar = .azul
            a.hijos = [h1, h2]
            a.hijoActivoID = h1.id
        case .sinHijos:
            a.hijos = []
            a.hijoActivoID = nil
        case .avisosNuevos:
            Self.conHijo(a) { h in
                h.avisos.insert(contentsOf: [
                    Aviso(tipo: .tareaHecha, fecha: ahora.addingTimeInterval(-600), texto: L("Ha terminado «Ejercicios de la página 52»", "Finished “Exercises on page 52”", "Ha finito «Esercizi a pagina 52»")),
                    Aviso(tipo: .tareaNueva, fecha: ahora.addingTimeInterval(-7200), texto: L("Ha apuntado 2 tareas nuevas", "Added 2 new assignments", "Ha segnato 2 nuovi compiti")),
                ], at: 0)
            }
        case .hijoAtrasado:
            Self.conHijo(a) { h in
                let t = Tarea(titulo: L("Ficha de repaso del tema 3", "Unit 3 review sheet", "Scheda di ripasso dell'unità 3"),
                              asignaturaID: h.datos.asignaturas.first?.id, entrega: DatosEscolares.fecha(dia(-1), minutos: 23 * 60 + 59))
                h.datos.tareas.append(t)
                h.avisos.insert(Aviso(tipo: .atrasada, fecha: ahora.addingTimeInterval(-1800),
                                      texto: L("«\(t.titulo)» no se entregó a tiempo", "“\(t.titulo)” wasn't handed in on time", "«\(t.titulo)» non è stato consegnato in tempo")), at: 0)
            }
        case .hijoExamen:
            Self.conHijo(a) { h in
                let manana = h.datos.siguienteDiaConClase(despuesDe: ahora) ?? dia(1)
                h.datos.tareas = Self.conExamen(h.datos, en: DatosEscolares.fecha(manana, minutos: 9 * 60 + 25))
                if let ex = h.datos.proximoExamen(desde: ahora) {
                    let materia = h.datos.asignatura(ex.asignaturaID)?.nombre ?? ex.titulo
                    h.avisos.insert(Aviso(tipo: .examen, fecha: ahora.addingTimeInterval(-900),
                                          texto: L("Examen de \(materia) mañana", "\(materia) test tomorrow", "Verifica di \(materia) domani")), at: 0)
                }
            }
        case .mochilaHijo:
            Self.conHijo(a) { h in
                if let d = h.datos.diaMochila(ahora: ahora) { h.datos.mochilaMarcada[DatosEscolares.clave(d)] = [] }
            }
        }
    }

    private static func conExamen(_ d: DatosEscolares, en fecha: Date) -> [Tarea] {
        var tareas = d.tareas
        if let i = tareas.firstIndex(where: { $0.tipo == .examen && !$0.hecha }) {
            tareas[i].entrega = fecha
            tareas[i].ratosHechos = []
        } else {
            let bio = d.asignaturas.first { $0.simbolo == "leaf.fill" } ?? d.asignaturas.first
            tareas.append(Tarea(titulo: L("Examen de Biología", "Biology test", "Verifica di scienze"), tipo: .examen,
                                asignaturaID: bio?.id, entrega: fecha, temas: L("Tema 3: la célula", "Unit 3: the cell", "Unità 3: la cellula")))
        }
        return tareas
    }

    private static func conHijo(_ a: Almacen, _ cambio: (inout Hijo) -> Void) {
        if a.hijos.isEmpty {
            let h = Demo.hijo(escala: a.ajustes.escala)
            a.hijos = [h]
            a.hijoActivoID = h.id
        }
        let id = a.hijoActivo?.id ?? a.hijos[0].id
        guard let i = a.hijos.firstIndex(where: { $0.id == id }) else { return }
        cambio(&a.hijos[i])
    }
}
