import EventKit
import CryptoKit
import SwiftUI

nonisolated enum TipoCuentaCalendario: Sendable, Equatable {
    case microsoft, google, icloud, iphone, suscritos, cumpleanos, otra
}

struct CuentaCalendario: Identifiable, Equatable, Sendable {
    typealias Tipo = TipoCuentaCalendario

    var id: String
    var tipo: Tipo

    var nombre: String
    var correo: String?

    var delColegio: Bool
    var calendarios: [CalendarioDeCuenta]

    var titulo: String {
        if let correo { return correo }
        switch tipo {
        case .iphone: return L("En mi iPhone", "On My iPhone", "Sul mio iPhone")
        case .suscritos: return L("Suscritos", "Subscribed", "Abbonamenti")
        case .cumpleanos: return L("Cumpleaños", "Birthdays", "Compleanni")
        default: return nombre
        }
    }

    var clase: String {
        switch tipo {
        case .microsoft: "Microsoft"
        case .google: "Google"
        case .icloud: "iCloud"
        case .iphone: L("Solo en este iPhone", "Only on this iPhone", "Solo su questo iPhone")
        case .suscritos: L("Calendarios a los que te has suscrito", "Calendars you subscribed to", "Calendari a cui sei abbonato")
        case .cumpleanos: L("De tus contactos", "From your contacts", "Dai tuoi contatti")
        case .otra: nombre
        }
    }

    var simbolo: String {
        switch tipo {
        case .microsoft, .google: delColegio ? "building.columns.fill" : "envelope.fill"
        case .icloud: "icloud.fill"
        case .iphone: "iphone"
        case .suscritos: "dot.radiowaves.left.and.right"
        case .cumpleanos: "gift.fill"
        case .otra: "calendar"
        }
    }

    var colorIcono: ColorHoot {
        switch tipo {
        case .microsoft: .azul
        case .google: .verde
        case .icloud: .cian
        case .iphone: .gris
        case .suscritos: .morado
        case .cumpleanos: .rosa
        case .otra: .naranja
        }
    }
}

struct CalendarioDeCuenta: Identifiable, Equatable, Sendable {
    var id: String
    var titulo: String
    var color: ColorHoot
}

@Observable
final class Calendarios {
    static let compartido = Calendarios()

    enum Permiso: Equatable { case sinPreguntar, concedido, denegado }

    private(set) var permiso: Permiso = .sinPreguntar
    private(set) var cuentas: [CuentaCalendario] = []

    private(set) var leido = false
    private(set) var eventosIPhone: [EventoExterno] = []

    private(set) var actividades: [Actividad] = []

    private(set) var citaDe: [UUID: EventoExterno] = [:]

    @ObservationIgnored private let tienda = EKEventStore()
    @ObservationIgnored private var observador: NSObjectProtocol?
    @ObservationIgnored private var lectura: Task<Void, Never>?
    @ObservationIgnored private var arrancado = false

    private init() {}

    var deEjemplo: Bool { ModoCapturas.calendariosDeEjemplo || Desarrollo.compartido.calendariosDeEjemplo }

    var hayDelColegio: Bool { cuentas.contains(where: \.delColegio) }

    func arrancar() {
        guard !arrancado else { recargar(); return }
        arrancado = true
        observador = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: tienda, queue: .main) { _ in
            Task { @MainActor in Calendarios.compartido.recargar() }
        }
        recargar()
    }

    func pedirPermiso() async {
        _ = try? await tienda.requestFullAccessToEvents()
        recargar()
    }

    func recargar() {
        if deEjemplo {
            permiso = .concedido
            let ejemplo = Self.ejemplo()
            cuentas = ejemplo.cuentas
            eventosIPhone = ejemplo.eventos.filter { e in visible(e.calendarioID, tipo: tipoDe(e.calendarioID)) }
            leido = true
            rehacer()
            return
        }
        permiso = Self.permisoActual
        guard permiso == .concedido else {
            cuentas = []
            eventosIPhone = []
            leido = true
            rehacer()
            return
        }
        let mostrar = Self.preferencias
        let cal = calendarioActual
        let hoy = cal.startOfDay(for: Reloj.ahora)
        let desde = cal.date(byAdding: .day, value: -60, to: hoy) ?? hoy
        let hasta = cal.date(byAdding: .day, value: 240, to: hoy) ?? hoy
        lectura?.cancel()
        lectura = Task {
            let leida = await Task.detached(priority: .userInitiated) {
                Self.leer(mostrar: mostrar, desde: desde, hasta: hasta)
            }.value
            guard !Task.isCancelled else { return }
            aplicar(leida)
        }
    }

    func visible(_ calendarioID: String, tipo: CuentaCalendario.Tipo) -> Bool {
        Self.preferencias[calendarioID] ?? (tipo != .cumpleanos)
    }

    func mostrar(_ calendarioID: String, _ si: Bool) {
        var p = Self.preferencias
        p[calendarioID] = si
        try? UserDefaults.standard.set(JSONEncoder().encode(p), forKey: Self.clavePreferencias)
        recargar()
    }

    func rehacer() {
        let cal = calendarioActual
        let juntas = FusionCalendarios.fusionar([eventosIPhone, ConexionTeams.compartida.eventos], cal: cal)
        var acts: [Actividad] = []
        var de: [UUID: EventoExterno] = [:]
        for e in juntas {
            for d in FusionCalendarios.porDias(e, cal: cal) {
                let id = Self.uuid("\(e.id)|\(DatosEscolares.clave(d.dia))")
                acts.append(Actividad(id: id,
                                      titulo: e.titulo.isEmpty ? L("Sin título", "No title", "Senza titolo") : e.titulo,
                                      simbolo: e.origen == .teams ? "person.3.fill" : "calendar",
                                      color: ColorHoot(rawValue: e.color) ?? .gris,
                                      fecha: d.dia, inicio: d.inicio, fin: d.fin, lugar: e.lugar))
                de[id] = e
            }
        }
        if acts != actividades { actividades = acts }
        citaDe = de
    }

    private nonisolated struct Leida: Sendable {
        var cuentas: [CuentaLeida]
        var eventos: [EventoExterno]
        var colores: [String: [Double]]
    }

    private nonisolated struct CuentaLeida: Sendable {
        var id: String
        var tipo: TipoCuentaCalendario
        var nombre: String
        var correo: String?
        var calendarios: [(id: String, titulo: String)]
    }

    private static var permisoActual: Permiso {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .concedido
        case .notDetermined: .sinPreguntar
        default: .denegado
        }
    }

    private nonisolated static func leer(mostrar: [String: Bool], desde: Date, hasta: Date) -> Leida {
        let tienda = EKEventStore()
        var cuentas: [CuentaLeida] = []
        var colores: [String: [Double]] = [:]
        var visibles: [EKCalendar] = []
        var cuentaDe: [String: String] = [:]
        for fuente in tienda.sources {
            let cals = fuente.calendars(for: .event).sorted { $0.title < $1.title }
            guard !cals.isEmpty else { continue }
            let tipo = tipo(de: fuente, calendarios: cals)

            let correo = fuente.title.contains("@") ? fuente.title : cals.first(where: { $0.title.contains("@") })?.title
            cuentas.append(CuentaLeida(id: fuente.sourceIdentifier, tipo: tipo, nombre: fuente.title, correo: correo,
                                       calendarios: cals.map { ($0.calendarIdentifier, $0.title) }))
            for c in cals {
                colores[c.calendarIdentifier] = componentes(c.cgColor)
                cuentaDe[c.calendarIdentifier] = fuente.sourceIdentifier
                if mostrar[c.calendarIdentifier] ?? (tipo != .cumpleanos) { visibles.append(c) }
            }
        }
        var eventos: [EventoExterno] = []
        var correoDe: [String: String] = [:]

        if !visibles.isEmpty {
            let consulta = tienda.predicateForEvents(withStart: desde, end: hasta, calendars: visibles)
            for ev in tienda.events(matching: consulta) {
                if ev.status == .canceled { continue }
                let yo = ev.attendees?.first(where: \.isCurrentUser)
                if yo?.participantStatus == .declined { continue }
                let calID = ev.calendar.calendarIdentifier

                if let fuente = cuentaDe[calID], correoDe[fuente] == nil,
                   let url = (yo ?? (ev.organizer?.isCurrentUser == true ? ev.organizer : nil))?.url.absoluteString,
                   url.lowercased().hasPrefix("mailto:") {
                    correoDe[fuente] = String(url.dropFirst("mailto:".count))
                }
                let base = ev.eventIdentifier ?? ev.calendarItemIdentifier
                eventos.append(EventoExterno(
                    id: "\(base)@\(Int(ev.startDate.timeIntervalSince1970))",
                    uid: ev.calendarItemExternalIdentifier,
                    titulo: ev.title ?? "",
                    inicio: ev.startDate, fin: ev.endDate, todoElDia: ev.isAllDay,
                    lugar: ev.location ?? "", notas: ev.notes ?? "", origen: .iphone,
                    calendarioID: calID, calendario: ev.calendar.title, cuenta: cuentaDe[calID] ?? ""))
            }
        }
        for i in cuentas.indices where cuentas[i].correo == nil {
            cuentas[i].correo = correoDe[cuentas[i].id]
        }
        return Leida(cuentas: cuentas, eventos: eventos, colores: colores)
    }

    private nonisolated static func tipo(de fuente: EKSource, calendarios: [EKCalendar]) -> TipoCuentaCalendario {
        let nombre = fuente.title.lowercased()
        switch fuente.sourceType {
        case .exchange: return .microsoft
        case .mobileMe: return .icloud
        case .local: return .iphone
        case .subscribed: return .suscritos
        case .birthdays: return .cumpleanos
        case .calDAV:
            if nombre.contains("icloud") { return .icloud }
            let titulos = calendarios.map { $0.title.lowercased() }
            if nombre.contains("gmail") || nombre.contains("google") || titulos.contains(where: { $0.hasSuffix("@gmail.com") || $0.hasSuffix("@googlemail.com") }) {
                return .google
            }
            return .otra
        @unknown default: return .otra
        }
    }

    private nonisolated static func componentes(_ color: CGColor?) -> [Double] {
        guard let color, let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let c = color.converted(to: srgb, intent: .defaultIntent, options: nil)?.components, c.count >= 3 else { return [0.5, 0.5, 0.5] }
        return [Double(c[0]), Double(c[1]), Double(c[2])]
    }

    private func aplicar(_ l: Leida) {
        let colores = l.colores.mapValues { ColorHoot.masParecido(rojo: $0[0], verde: $0[1], azul: $0[2]) }
        cuentas = l.cuentas.map { c in
            CuentaCalendario(id: c.id, tipo: c.tipo, nombre: c.nombre, correo: c.correo,
                             delColegio: Self.delColegio(c.tipo, correo: c.correo),
                             calendarios: c.calendarios.map { CalendarioDeCuenta(id: $0.id, titulo: $0.titulo, color: colores[$0.id] ?? .gris) })
        }
        .sorted { (Self.orden($0), $0.titulo) < (Self.orden($1), $1.titulo) }
        let nombres = Dictionary(cuentas.map { ($0.id, $0.titulo) }, uniquingKeysWith: { a, _ in a })
        eventosIPhone = l.eventos.map { e in
            var e = e
            e.color = (colores[e.calendarioID] ?? .gris).rawValue
            e.cuenta = nombres[e.cuenta] ?? e.cuenta
            return e
        }
        leido = true
        rehacer()
    }

    static func delColegio(_ tipo: CuentaCalendario.Tipo, correo: String?) -> Bool {
        let dominio = correo?.split(separator: "@").last.map { $0.lowercased() }
        let gratuitos = ["outlook.com", "hotmail.com", "live.com", "msn.com", "outlook.es", "hotmail.es", "hotmail.it", "outlook.it",
                         "live.it", "gmail.com", "googlemail.com", "yahoo.com", "yahoo.es", "yahoo.it"]
        switch tipo {
        case .microsoft: return dominio.map { !gratuitos.contains($0) } ?? true
        case .google: return dominio.map { !gratuitos.contains($0) } ?? false
        default: return false
        }
    }

    private static func orden(_ c: CuentaCalendario) -> Int {
        if c.delColegio { return 0 }
        switch c.tipo {
        case .icloud: return 1
        case .google, .microsoft, .otra: return 2
        case .iphone: return 3
        case .suscritos: return 4
        case .cumpleanos: return 5
        }
    }

    private func tipoDe(_ calendarioID: String) -> CuentaCalendario.Tipo {
        cuentas.first { $0.calendarios.contains { $0.id == calendarioID } }?.tipo ?? .otra
    }

    private static let clavePreferencias = "calendariosQueSeEnsenan"

    private static var preferencias: [String: Bool] {
        guard let d = UserDefaults.standard.data(forKey: clavePreferencias),
              let p = try? JSONDecoder().decode([String: Bool].self, from: d) else { return [:] }
        return p
    }

    private static func uuid(_ texto: String) -> UUID {
        let h = Array(SHA256.hash(data: Data(texto.utf8)))
        return UUID(uuid: (h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8], h[9], h[10], h[11], h[12], h[13], h[14], h[15]))
    }
}

extension Calendarios {

    static func ejemplo() -> (cuentas: [CuentaCalendario], eventos: [EventoExterno]) {
        let cuentas = [
            CuentaCalendario(id: "colegio", tipo: .microsoft, nombre: "Exchange", correo: "lucia.garcia@iesejemplo.edu", delColegio: true,
                             calendarios: [CalendarioDeCuenta(id: "colegio-cal", titulo: L("Calendario", "Calendar", "Calendario"), color: .azul)]),
            CuentaCalendario(id: "icloud", tipo: .icloud, nombre: "iCloud", correo: nil, delColegio: false,
                             calendarios: [CalendarioDeCuenta(id: "icloud-casa", titulo: L("Casa", "Home", "Casa"), color: .naranja),
                                           CalendarioDeCuenta(id: "icloud-deporte", titulo: L("Deporte", "Sports", "Sport"), color: .verde)]),
            CuentaCalendario(id: "google", tipo: .google, nombre: "Gmail", correo: "lucia.garcia@gmail.com", delColegio: false,
                             calendarios: [CalendarioDeCuenta(id: "google-principal", titulo: "lucia.garcia@gmail.com", color: .morado),
                                           CalendarioDeCuenta(id: "google-festivos", titulo: L("Festivos en España", "Holidays", "Festività in Italia"), color: .rojo)]),
            CuentaCalendario(id: "cumple", tipo: .cumpleanos, nombre: L("Cumpleaños", "Birthdays", "Compleanni"), correo: nil, delColegio: false,
                             calendarios: [CalendarioDeCuenta(id: "cumple-cal", titulo: L("Cumpleaños", "Birthdays", "Compleanni"), color: .rosa)]),
        ]
        let cal = calendarioActual
        let hoy = cal.startOfDay(for: Reloj.ahora)
        func dia(_ n: Int, _ h: Int, _ m: Int = 0) -> Date {
            let d = cal.date(byAdding: .day, value: n, to: hoy) ?? hoy
            return cal.date(bySettingHour: h, minute: m, second: 0, of: d) ?? d
        }
        func ev(_ id: String, _ titulo: String, _ ini: Date, _ fin: Date, _ calID: String, _ color: ColorHoot, _ cuenta: String,
                todo: Bool = false, lugar: String = "", uid: String? = nil) -> EventoExterno {
            EventoExterno(id: id, uid: uid, titulo: titulo, inicio: ini, fin: fin, todoElDia: todo, lugar: lugar, origen: .iphone,
                          calendarioID: calID, calendario: cuentas.flatMap(\.calendarios).first { $0.id == calID }?.titulo ?? "",
                          cuenta: cuenta, color: color.rawValue)
        }
        let eventos = [
            ev("tutora", L("Reunión con la tutora", "Meeting with the form tutor", "Colloquio con la coordinatrice"), dia(1, 17), dia(1, 17, 30),
               "colegio-cal", .azul, "lucia.garcia@iesejemplo.edu", lugar: "Microsoft Teams", uid: "040000008200E00074C5B7101A82E008TUTORA"),
            ev("museo", L("Excursión al museo", "Museum field trip", "Gita al museo"), dia(3, 0), dia(4, 0),
               "colegio-cal", .azul, "lucia.garcia@iesejemplo.edu", todo: true),
            ev("dentista", L("Dentista", "Dentist", "Dentista"), dia(2, 18, 30), dia(2, 19, 15), "icloud-casa", .naranja, "iCloud",
               lugar: L("Clínica Sonrisa", "Smile Clinic", "Studio Sorriso")),
            ev("partido", L("Partido de baloncesto", "Basketball game", "Partita di basket"), dia(5, 11), dia(5, 12, 30), "icloud-deporte", .verde, "iCloud",
               lugar: L("Polideportivo", "Sports center", "Palazzetto")),
            ev("cumple", L("Cumpleaños de Pablo", "Leo's birthday", "Compleanno di Marco"), dia(4, 0), dia(5, 0), "cumple-cal", .rosa,
               L("Cumpleaños", "Birthdays", "Compleanni"), todo: true),
        ]
        return (cuentas, eventos)
    }
}
