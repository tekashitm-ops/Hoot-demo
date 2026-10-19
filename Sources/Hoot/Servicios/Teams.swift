import AuthenticationServices
import CryptoKit
import SwiftUI

enum Teams {

    static let idCliente = ""
    static let esquema = "hoot-teams"
    static let redireccion = "hoot-teams://auth"
    static let permisos = "openid profile offline_access User.Read Team.ReadBasic.All Channel.ReadBasic.All ChannelMessage.Read.All Calendars.Read"
    static let autoridad = "https://login.microsoftonline.com/organizations/oauth2/v2.0"

    static var disponible: Bool { !idCliente.isEmpty }
}

nonisolated struct Comunicado: Identifiable, Hashable, Sendable {
    var id: String
    var equipo: String
    var canal: String
    var autor: String
    var asunto: String
    var texto: String
    var fecha: Date
    var enlace: String?
}

nonisolated struct SesionTeams: Codable, Sendable {
    var acceso: String
    var renovar: String
    var caduca: Date
}

@Observable
final class ConexionTeams {
    static let compartida = ConexionTeams()

    enum Paso: Equatable {
        case comprobando
        case vinculado(String)
        case bloqueado
        case sinConexion
        case fallo(String)
    }

    var paso: Paso?
    private(set) var comunicados: [Comunicado] = []

    private(set) var eventos: [EventoExterno] = [] {
        didSet { Calendarios.compartido.rehacer() }
    }
    private(set) var actualizando = false

    private(set) var hayQueEntrar = false

    @ObservationIgnored private var verificador = ""
    private static let claveSesion = "teams.sesion"

    private init() {}

    func vincular(_ almacen: Almacen, abrir: (URL) async throws -> URL) async {
        if let simulado = Desarrollo.compartido.teamsSimulado {
            await vincularDePrueba(almacen, permitido: simulado == .permitido)
            return
        }
        guard Teams.disponible, let url = urlEntrada() else {
            paso = .fallo(L("Falta registrar Hoot en Microsoft.", "Hoot isn't registered with Microsoft yet.", "Manca la registrazione di Hoot su Microsoft."))
            return
        }
        let vuelta: URL
        do {
            vuelta = try await abrir(url)
        } catch {

            return
        }
        paso = .comprobando
        let empezo = Date.now
        let resultado = await comprobar(vuelta, almacen)

        let falta = 1.6 - Date.now.timeIntervalSince(empezo)
        if falta > 0 { try? await Task.sleep(for: .seconds(falta)) }
        if case .vinculado = resultado { await actualizar(almacen) }
        conMuelle { paso = resultado }
    }

    private func urlEntrada() -> URL? {
        verificador = Self.aleatorio(48)
        let reto = Data(SHA256.hash(data: Data(verificador.utf8))).base64URL
        var c = URLComponents(string: "\(Teams.autoridad)/authorize")
        c?.queryItems = [
            URLQueryItem(name: "client_id", value: Teams.idCliente),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Teams.redireccion),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "scope", value: Teams.permisos),
            URLQueryItem(name: "code_challenge", value: reto),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        return c?.url
    }

    private func comprobar(_ vuelta: URL, _ almacen: Almacen) async -> Paso {
        let datos = URLComponents(url: vuelta, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func valor(_ n: String) -> String? { datos.first { $0.name == n }?.value }
        if let error = valor("error") {
            return Self.clasificar(error: error, descripcion: valor("error_description") ?? "")
        }
        guard let codigo = valor("code") else { return .fallo(L("Microsoft no ha devuelto nada.", "Microsoft returned nothing.", "Microsoft non ha restituito nulla.")) }
        do {
            let sesion = try await pedirSesion([
                "grant_type": "authorization_code", "code": codigo, "redirect_uri": Teams.redireccion,
                "code_verifier": verificador,
            ])
            Llavero.guardar(sesion, como: Self.claveSesion)

            let yo = try await graph("me?$select=mail,userPrincipalName", sesion: sesion)
            let correo = (yo["mail"] as? String) ?? (yo["userPrincipalName"] as? String) ?? ""
            let equipos = try await graph("me/joinedTeams?$select=id,displayName", sesion: sesion)["value"] as? [[String: Any]] ?? []
            if let equipo = equipos.first?["id"] as? String {
                let canales = try await graph("teams/\(equipo)/channels?$select=id,displayName", sesion: sesion)["value"] as? [[String: Any]] ?? []
                if let canal = canales.first?["id"] as? String {
                    _ = try await graph("teams/\(equipo)/channels/\(canal)/messages?$top=1", sesion: sesion)
                }
            }
            almacen.teams.estado = .vinculado
            almacen.teams.cuentaColegio = correo
            hayQueEntrar = false
            return .vinculado(correo)
        } catch let e as ErrorTeams {
            Llavero.borrar(Self.claveSesion)
            return e.paso
        } catch {
            Llavero.borrar(Self.claveSesion)
            return .sinConexion
        }
    }

    static func clasificar(error: String, descripcion: String) -> Paso {
        let bloqueos = ["AADSTS90093", "AADSTS90094", "AADSTS90095", "AADSTS65004", "AADSTS900941", "AADSTS900981", "AADSTS65001",
                        "AADSTS50105", "AADSTS53000", "AADSTS53003", "AADSTS530003"]
        if bloqueos.contains(where: descripcion.contains) || ["access_denied", "consent_required", "interaction_required"].contains(error) {
            return .bloqueado
        }
        if descripcion.contains("AADSTS50020") {
            return .fallo(L("Esa cuenta no es de un colegio. Entra con la de Teams.", "That isn't a school account. Use your Teams one.", "Quell'account non è della scuola. Usa quello di Teams."))
        }
        let primera = descripcion.split(separator: "\n").first.map(String.init) ?? error
        return .fallo(primera.isEmpty ? error : primera)
    }

    func actualizar(_ almacen: Almacen) async {
        switch almacen.teams.estado {
        case .sinVincular:
            comunicados = []
            eventos = []
            return
        case .prueba:
            let ejemplo = Self.ejemplo()
            comunicados = ejemplo.comunicados
            eventos = ejemplo.eventos
            almacen.teams.ultimaSincronizacion = Reloj.ahora
            return
        case .vinculado:
            break
        }
        guard !actualizando, var sesion = Llavero.leer(SesionTeams.self, de: Self.claveSesion) else {
            hayQueEntrar = almacen.teams.estado == .vinculado && Llavero.leer(SesionTeams.self, de: Self.claveSesion) == nil
            return
        }
        actualizando = true
        defer { actualizando = false }
        do {
            if sesion.caduca < Date.now.addingTimeInterval(120) {
                sesion = try await pedirSesion(["grant_type": "refresh_token", "refresh_token": sesion.renovar])
                Llavero.guardar(sesion, como: Self.claveSesion)
            }
            comunicados = try await leerComunicados(sesion)
            eventos = try await leerCitas(sesion)
            almacen.teams.ultimaSincronizacion = Reloj.ahora
            hayQueEntrar = false
        } catch let e as ErrorTeams where e.caducada {
            hayQueEntrar = true
        } catch {

        }
    }

    func desvincular(_ almacen: Almacen) {
        Llavero.borrar(Self.claveSesion)
        almacen.teams.estado = .sinVincular
        almacen.teams.cuentaColegio = ""
        almacen.teams.ultimaSincronizacion = nil
        comunicados = []
        eventos = []
        hayQueEntrar = false
    }

    private func leerComunicados(_ s: SesionTeams) async throws -> [Comunicado] {
        var lista: [Comunicado] = []
        let equipos = try await graph("me/joinedTeams?$select=id,displayName", sesion: s)["value"] as? [[String: Any]] ?? []
        for equipo in equipos.prefix(10) {
            guard let eid = equipo["id"] as? String else { continue }
            let nombreEquipo = equipo["displayName"] as? String ?? ""
            let canales = try await graph("teams/\(eid)/channels?$select=id,displayName", sesion: s)["value"] as? [[String: Any]] ?? []
            for canal in canales.prefix(4) {
                guard let cid = canal["id"] as? String else { continue }
                let mensajes = try await graph("teams/\(eid)/channels/\(cid)/messages?$top=15", sesion: s)["value"] as? [[String: Any]] ?? []
                for m in mensajes {

                    guard m["messageType"] as? String == "message", m["deletedDateTime"] is NSNull || m["deletedDateTime"] == nil,
                          let id = m["id"] as? String, let fecha = Self.fecha(m["createdDateTime"] as? String) else { continue }
                    let cuerpo = (m["body"] as? [String: Any])?["content"] as? String ?? ""
                    let texto = Self.sinHTML(cuerpo)
                    let asunto = (m["subject"] as? String) ?? ""
                    guard !texto.isEmpty || !asunto.isEmpty else { continue }
                    let autor = ((m["from"] as? [String: Any])?["user"] as? [String: Any])?["displayName"] as? String ?? ""
                    lista.append(Comunicado(id: id, equipo: nombreEquipo, canal: canal["displayName"] as? String ?? "", autor: autor,
                                            asunto: asunto, texto: texto, fecha: fecha, enlace: m["webUrl"] as? String))
                }
            }
        }
        return Array(lista.sorted { $0.fecha > $1.fecha }.prefix(40))
    }

    private func leerCitas(_ s: SesionTeams) async throws -> [EventoExterno] {
        let cal = calendarioActual
        let hoy = cal.startOfDay(for: Reloj.ahora)
        let desde = cal.date(byAdding: .day, value: -60, to: hoy) ?? hoy
        let hasta = cal.date(byAdding: .day, value: 240, to: hoy) ?? hoy
        let iso = ISO8601DateFormatter()
        var ruta: String? = "me/calendarView?startDateTime=\(iso.string(from: desde))&endDateTime=\(iso.string(from: hasta))&$top=200"
            + "&$select=id,subject,start,end,isAllDay,location,iCalUId,isCancelled,webLink,responseStatus,bodyPreview"
        var lista: [EventoExterno] = []
        var paginas = 0
        while let r = ruta, paginas < 5 {
            let datos = try await graph(r, sesion: s, cabeceras: ["Prefer": "outlook.timezone=\"UTC\""])
            for e in datos["value"] as? [[String: Any]] ?? [] {
                if e["isCancelled"] as? Bool == true { continue }
                if ((e["responseStatus"] as? [String: Any])?["response"] as? String) == "declined" { continue }
                let todo = e["isAllDay"] as? Bool ?? false
                guard let id = e["id"] as? String,
                      let ini = Self.fechaCita((e["start"] as? [String: Any])?["dateTime"] as? String, todoElDia: todo),
                      let fin = Self.fechaCita((e["end"] as? [String: Any])?["dateTime"] as? String, todoElDia: todo) else { continue }
                lista.append(EventoExterno(
                    id: "teams-\(id)", uid: e["iCalUId"] as? String, titulo: e["subject"] as? String ?? "",
                    inicio: ini, fin: fin, todoElDia: todo,
                    lugar: (e["location"] as? [String: Any])?["displayName"] as? String ?? "",
                    notas: e["bodyPreview"] as? String ?? "", origen: .teams,
                    calendario: "Microsoft Teams", cuenta: "Microsoft Teams", color: ColorHoot.indigo.rawValue,
                    enlace: e["webLink"] as? String))
            }

            ruta = (datos["@odata.nextLink"] as? String).map { $0.replacingOccurrences(of: "https://graph.microsoft.com/v1.0/", with: "") }
            paginas += 1
        }
        return lista
    }

    private struct ErrorTeams: Error {
        var paso: Paso
        var caducada = false
    }

    private func pedirSesion(_ campos: [String: String]) async throws -> SesionTeams {
        guard let url = URL(string: "\(Teams.autoridad)/token") else { throw ErrorTeams(paso: .sinConexion) }
        var p = URLRequest(url: url)
        p.httpMethod = "POST"
        p.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var todos = campos
        todos["client_id"] = Teams.idCliente
        todos["scope"] = Teams.permisos
        p.httpBody = todos.map { "\($0.key)=\(Self.codificar($0.value))" }.joined(separator: "&").data(using: .utf8)
        let (datos, _) = try await URLSession.shared.data(for: p)
        let json = (try? JSONSerialization.jsonObject(with: datos)) as? [String: Any] ?? [:]
        if let acceso = json["access_token"] as? String {
            return SesionTeams(acceso: acceso, renovar: json["refresh_token"] as? String ?? "",
                               caduca: Date.now.addingTimeInterval(json["expires_in"] as? Double ?? 3600))
        }
        let error = json["error"] as? String ?? ""
        let paso = Self.clasificar(error: error, descripcion: json["error_description"] as? String ?? "")
        throw ErrorTeams(paso: paso, caducada: error == "invalid_grant")
    }

    private func graph(_ ruta: String, sesion: SesionTeams, cabeceras: [String: String] = [:]) async throws -> [String: Any] {
        guard let url = URL(string: "https://graph.microsoft.com/v1.0/\(ruta)") else { throw ErrorTeams(paso: .sinConexion) }
        var p = URLRequest(url: url)
        p.setValue("Bearer \(sesion.acceso)", forHTTPHeaderField: "Authorization")
        for (k, v) in cabeceras { p.setValue(v, forHTTPHeaderField: k) }
        let (datos, respuesta) = try await URLSession.shared.data(for: p)
        let estado = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        switch estado {
        case 200..<300:
            return (try? JSONSerialization.jsonObject(with: datos)) as? [String: Any] ?? [:]
        case 401:
            throw ErrorTeams(paso: .bloqueado, caducada: true)
        case 403:

            throw ErrorTeams(paso: .bloqueado)
        default:
            throw ErrorTeams(paso: .fallo("Microsoft Graph \(estado)"))
        }
    }

    private func vincularDePrueba(_ almacen: Almacen, permitido: Bool) async {
        paso = .comprobando
        try? await Task.sleep(for: .seconds(2))
        if permitido {
            almacen.teams.estado = .prueba
            almacen.teams.cuentaColegio = "lucia.garcia@iesejemplo.edu"
            await actualizar(almacen)
            conMuelle { paso = .vinculado("lucia.garcia@iesejemplo.edu") }
        } else {
            conMuelle { paso = .bloqueado }
        }
    }

    static func ejemplo() -> (comunicados: [Comunicado], eventos: [EventoExterno]) {
        let ahora = Reloj.ahora
        let cal = calendarioActual
        let hoy = cal.startOfDay(for: ahora)
        func dia(_ n: Int, _ h: Int, _ m: Int = 0) -> Date {
            let d = cal.date(byAdding: .day, value: n, to: hoy) ?? hoy
            return cal.date(bySettingHour: h, minute: m, second: 0, of: d) ?? d
        }
        let comunicados = [
            Comunicado(id: "c1", equipo: L("2.º ESO B", "Grade 8B", "2ª B"), canal: "General", autor: L("Ana Martín", "Ann Martin", "Anna Martini"),
                       asunto: L("Excursión al museo", "Museum field trip", "Gita al museo"),
                       texto: L("El jueves vamos al museo de ciencias. Traed la autorización firmada antes del miércoles.",
                                "On Thursday we're going to the science museum. Bring the signed form by Wednesday.",
                                "Giovedì andiamo al museo della scienza. Portate l'autorizzazione firmata entro mercoledì."),
                       fecha: ahora.addingTimeInterval(-3 * 3600)),
            Comunicado(id: "c2", equipo: L("Familias 2.º ESO", "Grade 8 Families", "Famiglie 2ª media"), canal: "General",
                       autor: L("Dirección", "Head office", "Presidenza"), asunto: L("Colloqui con las familias", "Parent-teacher meetings", "Colloqui con le famiglie"),
                       texto: L("Ya se pueden reservar las reuniones con los profesores en el calendario.",
                                "Meetings with teachers can now be booked in the calendar.",
                                "Si possono già prenotare i colloqui con i professori nel calendario."),
                       fecha: ahora.addingTimeInterval(-26 * 3600)),
            Comunicado(id: "c3", equipo: L("Matemáticas 2.º B", "Math 8B", "Matematica 2ª B"), canal: "General", autor: "Luis Pérez",
                       asunto: "", texto: L("Mañana no hay clase de 5.ª hora: el profesor está de guardia.",
                                            "No class in 5th period tomorrow.", "Domani niente lezione alla 5ª ora."),
                       fecha: ahora.addingTimeInterval(-50 * 3600)),
        ]
        let eventos = [
            EventoExterno(id: "teams-tutora", uid: "OTRO-ID-DE-TEAMS", titulo: L("Reunión con la tutora", "Meeting with the form tutor", "Colloquio con la coordinatrice"),
                          inicio: dia(1, 17), fin: dia(1, 17, 30), todoElDia: false, lugar: "Microsoft Teams", origen: .teams,
                          calendario: "Microsoft Teams", cuenta: "Microsoft Teams", color: ColorHoot.indigo.rawValue),
            EventoExterno(id: "teams-consejo", uid: "CONSEJO", titulo: L("Charla de orientación", "Guidance talk", "Incontro di orientamento"),
                          inicio: dia(6, 10), fin: dia(6, 11), todoElDia: false, lugar: L("Salón de actos", "Auditorium", "Aula magna"), origen: .teams,
                          calendario: "Microsoft Teams", cuenta: "Microsoft Teams", color: ColorHoot.indigo.rawValue),
        ]
        return (comunicados, eventos)
    }

    private static func aleatorio(_ n: Int) -> String {
        let letras = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return String((0..<n).map { _ in letras.randomElement()! })
    }

    private static func codificar(_ s: String) -> String {
        var permitidos = CharacterSet.alphanumerics
        permitidos.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: permitidos) ?? s
    }

    static func fecha(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    static func fechaCita(_ s: String?, todoElDia: Bool) -> Date? {
        guard let s, s.count >= 19 else { return nil }
        let base = String(s.prefix(19))
        if todoElDia {
            let p = base.prefix(10).split(separator: "-").compactMap { Int($0) }
            guard p.count == 3 else { return nil }
            return calendarioActual.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f.date(from: base)
    }

    static func sinHTML(_ html: String) -> String {
        var t = html.replacingOccurrences(of: "<br>", with: "\n").replacingOccurrences(of: "</p>", with: "\n")
        t = t.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (a, b) in [("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'")] {
            t = t.replacingOccurrences(of: a, with: b)
        }
        return t.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

enum Conexiones {
    static func actualizar(_ almacen: Almacen) async {
        Calendarios.compartido.arrancar()
        await ConexionTeams.compartida.actualizar(almacen)
    }
}

private extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
