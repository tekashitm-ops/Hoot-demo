import Foundation

nonisolated enum ConfigNube {
    static let proyecto = ""
    static let clave = ""
    static var lista: Bool { !proyecto.isEmpty && !clave.isEmpty }
}

nonisolated struct SesionNube: Codable, Equatable, Sendable {
    var uid: String
    var correo: String
    var idToken: String
    var refresco: String
    var caduca: Date
    var verificada: Bool
}

nonisolated enum FalloNube: Error, Equatable, Sendable {
    case correoEnUso, credenciales, contrasenaDebil, correoNoValido, demasiadosIntentos, sinRed, sinSesion
    case sinVerificar, desactivada, conflicto, otro(String)
}

nonisolated struct GuardadoNube: Sendable {
    var estado: Data
    var foto: Data?
    var modificado: Date

    var version: String
}

actor Nube {
    static let compartida = Nube()

    private var sesion: SesionNube? = Llavero.leer(SesionNube.self, de: "sesion")
    private let red: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 20
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    var sesionActual: SesionNube? { sesion }

    func crearCuenta(correo: String, contrasena: String, idioma: String) async throws -> SesionNube {
        let r = try await identidad("accounts:signUp", ["email": correo, "password": contrasena, "returnSecureToken": true])
        let s = try nuevaSesion(r, correo: correo, verificada: false)
        try await mandarConfirmacion(idioma: idioma)
        return s
    }

    func iniciarSesion(correo: String, contrasena: String) async throws -> SesionNube {
        let r = try await identidad("accounts:signInWithPassword", ["email": correo, "password": contrasena, "returnSecureToken": true])
        var s = try nuevaSesion(r, correo: correo, verificada: false)
        s.verificada = (try? await correoConfirmado()) ?? false
        sesion = s
        Llavero.guardar(s, como: "sesion")
        return s
    }

    func mandarConfirmacion(idioma: String) async throws {
        let token = try await tokenValido()
        _ = try await identidad("accounts:sendOobCode", ["requestType": "VERIFY_EMAIL", "idToken": token], idioma: idioma)
    }

    func comprobarConfirmacion() async throws -> Bool {
        let ok = try await correoConfirmado()
        if ok, var s = sesion {
            s.verificada = true
            sesion = s
            try await renovar()
        }
        return ok
    }

    func restablecerContrasena(correo: String, idioma: String) async throws {
        _ = try await identidad("accounts:sendOobCode", ["requestType": "PASSWORD_RESET", "email": correo], idioma: idioma)
    }

    func cerrarSesion() {
        sesion = nil
        Llavero.borrar("sesion")
    }

    func borrarCuenta() async throws {
        guard let s = sesion else { throw FalloNube.sinSesion }
        let token = try await tokenValido()
        var p = URLRequest(url: documento(s.uid))
        p.httpMethod = "DELETE"
        p.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        _ = try? await pedir(p, aceptar404: true)
        _ = try await identidad("accounts:delete", ["idToken": token])
        cerrarSesion()
    }

    func bajar() async throws -> GuardadoNube? {
        guard let s = sesion else { throw FalloNube.sinSesion }
        return try await bajar(uid: s.uid)
    }

    private func bajar(uid: String) async throws -> GuardadoNube? {
        guard sesion != nil else { throw FalloNube.sinSesion }
        let token = try await tokenValido()
        var p = URLRequest(url: documento(uid))
        p.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let datos = try await pedir(p, aceptar404: true),
              let doc = try JSONSerialization.jsonObject(with: datos) as? [String: Any],
              let campos = doc["fields"] as? [String: Any] else { return nil }
        func bytes(_ k: String) -> Data? {
            ((campos[k] as? [String: Any])?["bytesValue"] as? String).flatMap { Data(base64Encoded: $0) }
        }
        guard let comprimido = bytes("estado"),
              let estado = try? (comprimido as NSData).decompressed(using: .zlib) as Data else { return nil }
        let modificado = ((campos["modificado"] as? [String: Any])?["timestampValue"] as? String).flatMap(Self.fecha) ?? .distantPast
        return GuardadoNube(estado: estado, foto: bytes("foto"), modificado: modificado, version: doc["updateTime"] as? String ?? "")
    }

    func subir(_ estado: Data, foto: Data?, modificado: Date, aparato: String, encimaDe version: String?) async throws -> String {
        guard let s = sesion else { throw FalloNube.sinSesion }
        guard s.verificada else { throw FalloNube.sinVerificar }
        let token = try await tokenValido()
        let comprimido = try (estado as NSData).compressed(using: .zlib) as Data
        var campos: [String: Any] = [
            "estado": ["bytesValue": comprimido.base64EncodedString()],
            "modificado": ["timestampValue": Self.texto(modificado)],
            "aparato": ["stringValue": aparato],
            "formato": ["integerValue": "1"],
        ]

        if let foto, comprimido.count + foto.count < 700_000 {
            campos["foto"] = ["bytesValue": foto.base64EncodedString()]
        }
        var url = URLComponents(url: documento(s.uid), resolvingAgainstBaseURL: false)!
        if let version, !version.isEmpty {
            url.queryItems = [URLQueryItem(name: "currentDocument.updateTime", value: version)]
        }
        var p = URLRequest(url: url.url!)
        p.httpMethod = "PATCH"
        p.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        p.setValue("application/json", forHTTPHeaderField: "Content-Type")
        p.httpBody = try JSONSerialization.data(withJSONObject: ["fields": campos])
        guard let datos = try await pedir(p),
              let doc = try JSONSerialization.jsonObject(with: datos) as? [String: Any] else { throw FalloNube.otro("sin respuesta") }
        return doc["updateTime"] as? String ?? ""
    }

    var uidPropio: String? { sesion?.uid }

    func publicarVinculo(codigo: String, nombre: String) async throws {
        guard let s = sesion else { throw FalloNube.sinSesion }
        _ = try await peticion(ruta("vinculos/\(codigo)"), metodo: "PATCH",
                               campos: ["uid": ["stringValue": s.uid], "nombre": ["stringValue": nombre]])
    }

    func borrarVinculo(codigo: String) async throws {
        _ = try await peticion(ruta("vinculos/\(codigo)"), metodo: "DELETE", aceptar404: true)
    }

    func buscarVinculo(codigo: String) async throws -> (uid: String, nombre: String)? {
        guard let doc = try await peticion(ruta("vinculos/\(codigo)"), aceptar404: true), let c = doc["fields"] as? [String: Any],
              let uid = Self.cadena(c, "uid") else { return nil }
        return (uid, Self.cadena(c, "nombre") ?? "")
    }

    func pedirSeguir(uidHijo: String, nombre: String) async throws {
        guard let s = sesion else { throw FalloNube.sinSesion }
        _ = try await peticion(ruta("usuarios/\(uidHijo)/familia", consulta: [URLQueryItem(name: "documentId", value: s.uid)]),
                               metodo: "POST", campos: ["nombre": ["stringValue": nombre], "aceptado": ["booleanValue": false],
                                                        "creado": ["timestampValue": Self.texto(Date())]])
    }

    func dejarDeSeguir(uidHijo: String) async throws {
        guard let s = sesion else { throw FalloNube.sinSesion }
        _ = try await peticion(ruta("usuarios/\(uidHijo)/familia/\(s.uid)"), metodo: "DELETE", aceptar404: true)
    }

    func familiares() async throws -> [(uid: String, nombre: String, aceptado: Bool, creado: Date)] {
        guard let s = sesion else { throw FalloNube.sinSesion }
        guard let r = try await peticion(ruta("usuarios/\(s.uid)/familia"), aceptar404: true) else { return [] }
        return ((r["documents"] as? [[String: Any]]) ?? []).compactMap { d in
            guard let nombreDoc = d["name"] as? String, let c = d["fields"] as? [String: Any] else { return nil }
            let creado = ((c["creado"] as? [String: Any])?["timestampValue"] as? String).flatMap(Self.fecha) ?? Date()
            return (String(nombreDoc.split(separator: "/").last ?? ""), Self.cadena(c, "nombre") ?? "",
                    ((c["aceptado"] as? [String: Any])?["booleanValue"] as? Bool) ?? false, creado)
        }
    }

    func aceptar(_ uidFamiliar: String) async throws {
        guard let s = sesion else { throw FalloNube.sinSesion }
        _ = try await peticion(ruta("usuarios/\(s.uid)/familia/\(uidFamiliar)", consulta: [URLQueryItem(name: "updateMask.fieldPaths", value: "aceptado")]),
                               metodo: "PATCH", campos: ["aceptado": ["booleanValue": true]])
    }

    func quitarFamiliar(_ uidFamiliar: String) async throws {
        guard let s = sesion else { throw FalloNube.sinSesion }
        _ = try await peticion(ruta("usuarios/\(s.uid)/familia/\(uidFamiliar)"), metodo: "DELETE", aceptar404: true)
    }

    func bajarHijo(_ uid: String) async throws -> GuardadoNube? {
        try await bajar(uid: uid)
    }

    func mandarAlBuzon(uidHijo: String, tipo: String, json: String, de: String) async throws {
        _ = try await peticion(ruta("usuarios/\(uidHijo)/buzon"), metodo: "POST",
                               campos: ["tipo": ["stringValue": tipo], "json": ["stringValue": json], "de": ["stringValue": de],
                                        "creado": ["timestampValue": Self.texto(Date())]])
    }

    func buzon() async throws -> [(id: String, tipo: String, json: String, de: String)] {
        guard let s = sesion else { throw FalloNube.sinSesion }
        guard let r = try await peticion(ruta("usuarios/\(s.uid)/buzon"), aceptar404: true) else { return [] }
        return ((r["documents"] as? [[String: Any]]) ?? []).compactMap { d in
            guard let nombreDoc = d["name"] as? String, let c = d["fields"] as? [String: Any],
                  let tipo = Self.cadena(c, "tipo"), let json = Self.cadena(c, "json") else { return nil }
            return (String(nombreDoc.split(separator: "/").last ?? ""), tipo, json, Self.cadena(c, "de") ?? "")
        }
    }

    func borrarDelBuzon(_ id: String) async throws {
        guard let s = sesion else { throw FalloNube.sinSesion }
        _ = try await peticion(ruta("usuarios/\(s.uid)/buzon/\(id)"), metodo: "DELETE", aceptar404: true)
    }

    private func ruta(_ camino: String, consulta: [URLQueryItem] = []) -> URL {
        var c = URLComponents(string: "https://firestore.googleapis.com/v1/projects/\(ConfigNube.proyecto)/databases/(default)/documents/\(camino)")!
        if !consulta.isEmpty { c.queryItems = consulta }
        return c.url!
    }

    private func peticion(_ url: URL, metodo: String = "GET", campos: [String: Any]? = nil, aceptar404: Bool = false) async throws -> [String: Any]? {
        guard sesion != nil else { throw FalloNube.sinSesion }
        let token = try await tokenValido()
        var p = URLRequest(url: url)
        p.httpMethod = metodo
        p.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let campos {
            p.setValue("application/json", forHTTPHeaderField: "Content-Type")
            p.httpBody = try JSONSerialization.data(withJSONObject: ["fields": campos])
        }
        guard let datos = try await pedir(p, aceptar404: aceptar404) else { return nil }
        return (try? JSONSerialization.jsonObject(with: datos) as? [String: Any]) ?? [:]
    }

    private static func cadena(_ campos: [String: Any], _ k: String) -> String? {
        (campos[k] as? [String: Any])?["stringValue"] as? String
    }

    private func documento(_ uid: String) -> URL {
        URL(string: "https://firestore.googleapis.com/v1/projects/\(ConfigNube.proyecto)/databases/(default)/documents/usuarios/\(uid)")!
    }

    private func nuevaSesion(_ r: [String: Any], correo: String, verificada: Bool) throws -> SesionNube {
        guard let uid = r["localId"] as? String, let id = r["idToken"] as? String, let refresco = r["refreshToken"] as? String
        else { throw FalloNube.otro("respuesta incompleta") }
        let dura = Double(r["expiresIn"] as? String ?? "3600") ?? 3600
        let s = SesionNube(uid: uid, correo: correo, idToken: id, refresco: refresco, caduca: Date().addingTimeInterval(dura - 120),
                           verificada: verificada)
        sesion = s
        Llavero.guardar(s, como: "sesion")
        return s
    }

    private func correoConfirmado() async throws -> Bool {
        let token = try await tokenValido()
        let r = try await identidad("accounts:lookup", ["idToken": token])
        return ((r["users"] as? [[String: Any]])?.first?["emailVerified"] as? Bool) ?? false
    }

    func pase() async throws -> String { try await tokenValido() }

    private func tokenValido() async throws -> String {
        guard let s = sesion else { throw FalloNube.sinSesion }
        if s.caduca > Date() { return s.idToken }
        try await renovar()
        return sesion?.idToken ?? s.idToken
    }

    private func renovar() async throws {
        guard var s = sesion else { throw FalloNube.sinSesion }
        var p = URLRequest(url: URL(string: "https://securetoken.googleapis.com/v1/token?key=\(ConfigNube.clave)")!)
        p.httpMethod = "POST"
        p.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let refresco = s.refresco.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s.refresco
        p.httpBody = Data("grant_type=refresh_token&refresh_token=\(refresco)".utf8)
        guard let datos = try await pedir(p), let r = try JSONSerialization.jsonObject(with: datos) as? [String: Any],
              let id = r["id_token"] as? String else { throw FalloNube.otro("no se pudo renovar") }
        s.idToken = id
        if let nuevo = r["refresh_token"] as? String { s.refresco = nuevo }
        let dura = Double(r["expires_in"] as? String ?? "3600") ?? 3600
        s.caduca = Date().addingTimeInterval(dura - 120)
        sesion = s
        Llavero.guardar(s, como: "sesion")
    }

    private func identidad(_ metodo: String, _ cuerpo: [String: Any], idioma: String? = nil) async throws -> [String: Any] {
        var p = URLRequest(url: URL(string: "https://identitytoolkit.googleapis.com/v1/\(metodo)?key=\(ConfigNube.clave)")!)
        p.httpMethod = "POST"
        p.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let idioma { p.setValue(idioma, forHTTPHeaderField: "X-Firebase-Locale") }
        p.httpBody = try JSONSerialization.data(withJSONObject: cuerpo)
        guard let datos = try await pedir(p) else { return [:] }
        return (try JSONSerialization.jsonObject(with: datos) as? [String: Any]) ?? [:]
    }

    private func pedir(_ p: URLRequest, aceptar404: Bool = false) async throws -> Data? {
        let datos: Data, respuesta: URLResponse
        do {
            (datos, respuesta) = try await red.data(for: p)
        } catch {
            throw FalloNube.sinRed
        }
        let estado = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        if (200..<300).contains(estado) { return datos }
        if estado == 404 && aceptar404 { return nil }
        let error = (try? JSONSerialization.jsonObject(with: datos) as? [String: Any])?["error"] as? [String: Any]
        let mensaje = (error?["message"] as? String) ?? ""
        let estadoGoogle = (error?["status"] as? String) ?? ""
        if estadoGoogle == "FAILED_PRECONDITION" || estado == 409 { throw FalloNube.conflicto }
        if estadoGoogle == "PERMISSION_DENIED" { throw FalloNube.sinVerificar }
        switch mensaje.split(separator: " ").first.map(String.init) ?? mensaje {
        case "EMAIL_EXISTS": throw FalloNube.correoEnUso
        case "INVALID_LOGIN_CREDENTIALS", "INVALID_PASSWORD", "EMAIL_NOT_FOUND": throw FalloNube.credenciales
        case "WEAK_PASSWORD": throw FalloNube.contrasenaDebil
        case "INVALID_EMAIL", "MISSING_EMAIL": throw FalloNube.correoNoValido
        case "TOO_MANY_ATTEMPTS_TRY_LATER": throw FalloNube.demasiadosIntentos
        case "USER_DISABLED": throw FalloNube.desactivada
        case "INVALID_ID_TOKEN", "TOKEN_EXPIRED", "USER_NOT_FOUND", "INVALID_REFRESH_TOKEN", "CREDENTIAL_TOO_OLD_LOGIN_AGAIN":
            throw FalloNube.sinSesion
        default: throw FalloNube.otro(mensaje.isEmpty ? "HTTP \(estado)" : mensaje)
        }
    }

    private static func texto(_ f: Date) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.string(from: f)
    }

    private static func fecha(_ t: String) -> Date? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let f = fmt.date(from: t) { return f }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: t)
    }
}
