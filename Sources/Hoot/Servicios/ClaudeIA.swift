import Foundation

@Observable
final class ClaudeIA {
    static let compartida = ClaudeIA()

    enum Modelo: String, CaseIterable, Codable {
        case haiku = "claude-haiku-5-5"
        case sonnet = "claude-sonnet-5-5"

        var nombre: String {
            switch self {
            case .haiku: "Haiku"
            case .sonnet: "Sonnet"
            }
        }

        var precio: (entrada: Double, salida: Double) {
            switch self {
            case .haiku: (0.10, 0.50)
            case .sonnet: (2, 10)
            }
        }
    }

    enum Esfuerzo: String { case low, medium, high }

    struct Uso: Codable, Equatable {
        var mes = ""
        var respuestas: [String: Int] = [:]
        var entrada: [String: Int] = [:]
        var salida: [String: Int] = [:]
        var porTarea: [String: Double] = [:]
        var apple: [String: Int] = [:]

        var porDia: [Int: Double] = [:]

        init(mes: String = "") { self.mes = mes }

        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            mes = try c.decodeIfPresent(String.self, forKey: .mes) ?? ""
            respuestas = try c.decodeIfPresent([String: Int].self, forKey: .respuestas) ?? [:]
            entrada = try c.decodeIfPresent([String: Int].self, forKey: .entrada) ?? [:]
            salida = try c.decodeIfPresent([String: Int].self, forKey: .salida) ?? [:]
            porTarea = try c.decodeIfPresent([String: Double].self, forKey: .porTarea) ?? [:]
            apple = try c.decodeIfPresent([String: Int].self, forKey: .apple) ?? [:]
            porDia = try c.decodeIfPresent([Int: Double].self, forKey: .porDia) ?? [:]
        }

        func dolares(_ m: Modelo) -> Double {
            Double(entrada[m.rawValue, default: 0]) * m.precio.entrada / 1_000_000
                + Double(salida[m.rawValue, default: 0]) * m.precio.salida / 1_000_000
        }

        var total: Double { Modelo.allCases.reduce(0) { $0 + dolares($1) } }
        var respuestasClaude: Int { respuestas.values.reduce(0, +) }
        var respuestasApple: Int { apple.values.reduce(0, +) }
    }

    private static let cuentaLlavero = "claude.clave"
    private static let claveUso = "claude.uso"
    private static let claveActiva = "claude.activa"
    private static let claveTope = "claude.tope"

    private(set) var hayClave = Llavero.leer(String.self, de: cuentaLlavero) != nil
    var activa = UserDefaults.standard.bool(forKey: claveActiva) {
        didSet { UserDefaults.standard.set(activa, forKey: Self.claveActiva) }
    }

    var tope = UserDefaults.standard.object(forKey: claveTope) as? Double ?? 5 {
        didSet { UserDefaults.standard.set(tope, forKey: Self.claveTope) }
    }
    private(set) var uso = ClaudeIA.leerUso()

    var verModelo = UserDefaults.standard.object(forKey: "claude.verModelo") as? Bool ?? true {
        didSet { UserDefaults.standard.set(verModelo, forKey: "claude.verModelo") }
    }

    static var activa: Bool { compartida.activa && compartida.hayClave && !ModoCapturas.activo }

    var finClave: String { String((Llavero.leer(String.self, de: Self.cuentaLlavero) ?? "").suffix(4)) }

    func guardarClave(_ clave: String) {
        let limpia = clave.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpia.isEmpty else { return }
        Llavero.guardar(limpia, como: Self.cuentaLlavero)
        hayClave = true
        activa = true
    }

    func borrarClave() {
        Llavero.borrar(Self.cuentaLlavero)
        hayClave = false
        activa = false
    }

    func ponerUsoACero() {
        uso = Uso(mes: Self.mesDeAhora())
        guardarUso()
    }

    var usoDelMes: Uso { uso.mes == Self.mesDeAhora() ? uso : Uso(mes: Self.mesDeAhora()) }

    var fraccion: Double { min(1, usoDelMes.total / max(tope, 0.01)) }

    var llegoAlTope: Bool { usoDelMes.total >= tope }

    static func partePasadaDelMes(_ ahora: Date = Reloj.ahora) -> Double {
        let cal = Calendar.current
        let dias = Double(cal.range(of: .day, in: .month, for: ahora)?.count ?? 30)
        let pasado = Double(cal.component(.day, from: ahora)) - 1 + Double(cal.component(.hour, from: ahora)) / 24
        return max(pasado, 0.5) / dias
    }

    var ritmo: Double { usoDelMes.total / max(tope * Self.partePasadaDelMes(), 0.0001) }

    var ahorro: Int {
        switch ritmo {
        case ..<1.1: 0
        case ..<1.5: 1
        default: 2
        }
    }

    var deprisa: Bool { ahorro >= 1 }

    var diaEnQueSeAcaba: Int? {
        let cal = Calendar.current
        let ahora = Reloj.ahora
        let dias = cal.range(of: .day, in: .month, for: ahora)?.count ?? 30
        let pasado = Self.partePasadaDelMes(ahora) * Double(dias)
        let porDia = usoDelMes.total / max(pasado, 0.5)
        guard porDia > 0 else { return nil }
        let dia = Int((tope / porDia).rounded(.down)) + 1
        return dia <= dias ? max(dia, cal.component(.day, from: ahora)) : nil
    }

    static func trivial(_ t: String) -> Bool {
        let x = sinTildes(t).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !x.isEmpty, !t.contains("?"), x.split(separator: " ").count <= 3 else { return false }
        return ["vale", "ok", "okay", "gracias", "muchas gracias", "genial", "perfecto", "entendido", "ya esta", "hola", "adios",
                "grazie", "grazie mille", "ciao", "perfetto", "capito", "thanks", "thank you", "got it", "hi", "bye", "ah vale",
                "vale gracias", "ok gracias", "de acuerdo", "va bene"].contains(x)
    }

    static func noEntiende(_ t: String) -> Bool {
        ["no entiendo", "no lo entiendo", "no lo pillo", "sigo sin", "no se hacer", "no se como", "no me sale", "no capisco",
         "non ho capito", "non mi viene", "don't understand", "dont understand", "i don't get"].contains { t.contains($0) }
    }

    static func sinTildes(_ t: String) -> String {
        t.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    struct Mensaje {
        var deHoot: Bool
        var texto: String

        var fotos: [Data] = []
    }

    enum Fallo: Error {
        case sinClave, claveMala, saturado, tope, sinRed, red(String)

        @MainActor var mensaje: String {
            switch self {
            case .sinClave: L("Falta la clave de Claude (Cuenta › Modo desarrollador).", "The Claude key is missing (Account › Developer Mode).", "Manca la chiave di Claude (Account › Modalità sviluppatore).")
            case .claveMala: L("La clave de Claude no vale. Revísala en el modo desarrollador.", "The Claude key isn't valid. Check it in Developer Mode.", "La chiave di Claude non è valida. Controllala nella modalità sviluppatore.")
            case .saturado: L("Claude está saturado. Pregúntaselo otra vez en un momento.", "Claude is busy. Ask again in a moment.", "Claude è occupato. Richiedi tra un attimo.")
            case .tope: L("Se ha acabado la IA de este mes. Puedes ver tu plan en Cuenta › Uso.", "This month's AI has run out. See your plan in Account › Usage.", "L'IA di questo mese è finita. Vedi il tuo piano in Account › Utilizzo.")
            case .sinRed: L("Sin conexión. Comprueba internet y pregúntaselo otra vez.", "No connection. Check the internet and ask again.", "Nessuna connessione. Controlla internet e richiedi.")
            case let .red(t): t
            }
        }

        var codigo: String {
            switch self {
            case .sinClave: "sinClave"
            case .claveMala: "claveMala"
            case .saturado: "saturado"
            case .tope: "tope"
            case .sinRed: "sinRed"
            case let .red(t): "red: \(t.prefix(160))"
            }
        }
    }

    private func peticion(modelo: Modelo, sistema: String, mensajes: [Mensaje], maximo: Int, esfuerzo: Esfuerzo,
                          formato: Any?, flujo: Bool) throws -> URLRequest {
        guard let clave = Llavero.leer(String.self, de: Self.cuentaLlavero) else { throw Fallo.sinClave }
        guard !llegoAlTope else { throw Fallo.tope }
        var p = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        p.httpMethod = "POST"
        p.timeoutInterval = 120
        p.setValue(clave, forHTTPHeaderField: "x-api-key")
        p.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        p.setValue("application/json", forHTTPHeaderField: "content-type")
        var config: [String: Any] = ["effort": esfuerzo.rawValue]
        if let formato { config["format"] = ["type": "json_schema", "schema": formato] }
        var cuerpo: [String: Any] = [
            "model": modelo.rawValue,
            "max_tokens": maximo,
            "system": sistema,
            "messages": Self.turnos(mensajes),
            "output_config": config,
        ]
        if flujo { cuerpo["stream"] = true }
        p.httpBody = try JSONSerialization.data(withJSONObject: cuerpo)
        return p
    }

    private static func fallo(_ codigo: Int, detalle: String) -> Fallo {
        switch codigo {
        case 401, 403: return .claveMala
        case 429, 529, 500...599: return .saturado
        default:
            let mensaje = (try? JSONSerialization.jsonObject(with: Data(detalle.utf8)) as? [String: Any])
                .flatMap { ($0["error"] as? [String: Any])?["message"] as? String } ?? "\(codigo)"
            return .red("\(codigo): \(mensaje)")
        }
    }

    private static func deRed(_ e: Error) -> Error {
        if let u = e as? URLError, [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost,
                                    .dataNotAllowed, .internationalRoamingOff].contains(u.code) {
            return Fallo.sinRed
        }
        return e
    }

    func responder(modelo: Modelo, tarea: TareaIA, sistema: String, mensajes: [Mensaje], maximo: Int = 4000,
                   esfuerzo: Esfuerzo = .medium, alEscribir: @escaping (String) -> Void,
                   parar: ((String) -> Bool)? = nil) async throws -> String {
        let peticion = try peticion(modelo: modelo, sistema: sistema, mensajes: mensajes, maximo: maximo, esfuerzo: esfuerzo,
                                    formato: nil, flujo: true)
        let bytes: URLSession.AsyncBytes
        let respuesta: URLResponse
        do { (bytes, respuesta) = try await URLSession.shared.bytes(for: peticion) } catch { throw Self.deRed(error) }
        let codigo = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        guard codigo == 200 else {
            var detalle = ""
            for try await linea in bytes.lines { detalle += linea; if detalle.count > 600 { break } }
            throw Self.fallo(codigo, detalle: detalle)
        }
        var texto = ""
        var entrada = 0
        var salida = 0
        do {
            for try await linea in bytes.lines {
                try Task.checkCancellation()
                guard linea.hasPrefix("data:"),
                      let json = try? JSONSerialization.jsonObject(with: Data(linea.dropFirst(5).utf8)) as? [String: Any] else { continue }
                switch json["type"] as? String {
                case "message_start":
                    let u = (json["message"] as? [String: Any])?["usage"] as? [String: Any]
                    entrada = (u?["input_tokens"] as? Int ?? 0) + (u?["cache_read_input_tokens"] as? Int ?? 0)
                        + (u?["cache_creation_input_tokens"] as? Int ?? 0)
                case "content_block_delta":
                    if let d = json["delta"] as? [String: Any], d["type"] as? String == "text_delta", let t = d["text"] as? String {
                        texto += t
                        if parar?(texto) == true {
                            apuntar(modelo, tarea: tarea, entrada: entrada, salida: 8)
                            return texto
                        }
                        alEscribir(texto)
                    }
                case "message_delta":
                    salida = ((json["usage"] as? [String: Any])?["output_tokens"] as? Int) ?? salida
                case "error":
                    let m = (json["error"] as? [String: Any])?["type"] as? String
                    throw m == "overloaded_error" ? Fallo.saturado : Fallo.red(L("Claude se ha cortado. Pregúntaselo otra vez.", "Claude cut off. Ask again.", "Claude si è interrotto. Richiedi."))
                default:
                    break
                }
            }
        } catch is CancellationError {

            apuntar(modelo, tarea: tarea, entrada: entrada, salida: max(salida, texto.count / 4))
            throw CancellationError()
        } catch let f as Fallo {
            throw f
        } catch {
            throw Self.deRed(error)
        }
        apuntar(modelo, tarea: tarea, entrada: entrada, salida: salida)
        return texto
    }

    func responderJSON(modelo: Modelo, tarea: TareaIA, sistema: String, mensajes: [Mensaje], esquema: Any, maximo: Int = 6000,
                       esfuerzo: Esfuerzo = .medium) async throws -> String {
        do {
            return try await pedirJSON(modelo: modelo, tarea: tarea, sistema: sistema, mensajes: mensajes, formato: esquema,
                                       maximo: maximo, esfuerzo: esfuerzo)
        } catch let Fallo.red(detalle) where detalle.hasPrefix("400") {
            let forma = (try? JSONSerialization.data(withJSONObject: esquema)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            let texto = try await pedirJSON(modelo: modelo, tarea: tarea,
                                            sistema: sistema + "\n\nContesta SOLO con un objeto JSON válido que cumpla este JSON Schema, sin nada antes ni después:\n" + forma,
                                            mensajes: mensajes, formato: nil, maximo: maximo, esfuerzo: esfuerzo)
            guard let a = texto.firstIndex(of: "{"), let b = texto.lastIndex(of: "}") else { return texto }
            return String(texto[a...b])
        }
    }

    private func pedirJSON(modelo: Modelo, tarea: TareaIA, sistema: String, mensajes: [Mensaje], formato: Any?, maximo: Int,
                           esfuerzo: Esfuerzo) async throws -> String {
        let peticion = try peticion(modelo: modelo, sistema: sistema, mensajes: mensajes, maximo: maximo, esfuerzo: esfuerzo,
                                    formato: formato, flujo: false)
        let datos: Data
        let respuesta: URLResponse
        do { (datos, respuesta) = try await URLSession.shared.data(for: peticion) } catch { throw Self.deRed(error) }
        let codigo = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
        guard codigo == 200 else { throw Self.fallo(codigo, detalle: String(data: datos.prefix(800), encoding: .utf8) ?? "") }
        guard let json = try JSONSerialization.jsonObject(with: datos) as? [String: Any] else { throw Fallo.red("JSON") }
        let u = json["usage"] as? [String: Any]
        apuntar(modelo, tarea: tarea, entrada: (u?["input_tokens"] as? Int ?? 0) + (u?["cache_read_input_tokens"] as? Int ?? 0),
                salida: u?["output_tokens"] as? Int ?? 0)
        let bloques = json["content"] as? [[String: Any]] ?? []
        return bloques.filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }.joined()
    }

    static let marcaDificil = "<sonnet/>"

    @MainActor static var reglaSubir: String {
        L("Si no puedes resolverlo, explicarlo o corregirlo con total seguridad (por ejemplo, un ejercicio largo o difícil de matemáticas, física o química), escribe solo <sonnet/> y nada más.",
          "If you can't solve, explain or correct it with complete certainty (for example, a long or hard maths, physics or chemistry exercise), write only <sonnet/> and nothing else.",
          "Se non puoi risolverlo, spiegarlo o correggerlo con totale sicurezza (per esempio, un esercizio lungo o difficile di matematica, fisica o chimica), scrivi solo <sonnet/> e nient'altro.")
    }

    func responderBien(tarea: TareaIA, sistema: String, mensajes: [Mensaje], maximo: Int = 4000, esfuerzo: Esfuerzo = .medium,
                       sonnetYa: Bool = false, puedeSubir: Bool = true,
                       alEscribir: @escaping (String) -> Void) async throws -> (texto: String, modelo: Modelo) {

        let esfuerzoSonnet: Esfuerzo = esfuerzo == .low ? .low : .medium
        if sonnetYa && puedeSubir {
            let t = try await responder(modelo: .sonnet, tarea: tarea, sistema: sistema, mensajes: mensajes, maximo: maximo,
                                        esfuerzo: esfuerzoSonnet, alEscribir: alEscribir)
            return (t, .sonnet)
        }
        let marca = Self.marcaDificil
        func esMarca(_ t: String) -> Bool {
            let x = t.trimmingCharacters(in: .whitespacesAndNewlines)
            return !x.isEmpty && (marca.hasPrefix(x) || x.hasPrefix(marca))
        }
        let t = try await responder(modelo: .haiku, tarea: tarea, sistema: puedeSubir ? sistema + "\n\n" + Self.reglaSubir : sistema,
                                    mensajes: mensajes, maximo: maximo, esfuerzo: esfuerzo,
                                    alEscribir: { if !esMarca($0) { alEscribir($0) } },
                                    parar: { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(marca) })
        guard puedeSubir, t.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(marca) else { return (t, .haiku) }
        alEscribir("")
        let s = try await responder(modelo: .sonnet, tarea: tarea, sistema: sistema, mensajes: mensajes, maximo: maximo,
                                    esfuerzo: esfuerzoSonnet, alEscribir: alEscribir)
        return (s, .sonnet)
    }

    func probar() async -> String {
        do {
            let t = try await responder(modelo: .haiku, tarea: .charla, sistema: "Contesta en una palabra.",
                                        mensajes: [Mensaje(deHoot: false, texto: "Di «hola».")], maximo: 200, esfuerzo: .low,
                                        alEscribir: { _ in })
            return L("Funciona: «\(t.trimmingCharacters(in: .whitespacesAndNewlines))»", "It works: “\(t)”", "Funziona: «\(t)»")
        } catch let f as Fallo {
            return f.mensaje
        } catch {
            return error.localizedDescription
        }
    }

    static func turnos(_ mensajes: [Mensaje]) -> [[String: Any]] {
        var turnos: [(deHoot: Bool, partes: [[String: Any]])] = []
        for m in mensajes {
            var partes: [[String: Any]] = m.fotos.map { f in
                ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": f.base64EncodedString()]]
            }
            let t = m.texto.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { partes.append(["type": "text", "text": t]) }
            guard !partes.isEmpty else { continue }
            if let ultimo = turnos.last, ultimo.deHoot == m.deHoot {
                turnos[turnos.count - 1].partes += partes
            } else {
                turnos.append((m.deHoot, partes))
            }
        }
        while let primero = turnos.first, primero.deHoot { turnos.removeFirst() }

        while let ultimo = turnos.last, ultimo.deHoot { turnos.removeLast() }
        return turnos.map { ["role": $0.deHoot ? "assistant" : "user", "content": $0.partes] }
    }

    private func apuntar(_ m: Modelo, tarea: TareaIA, entrada: Int, salida: Int) {
        var u = usoDelMes
        u.respuestas[m.rawValue, default: 0] += 1
        u.entrada[m.rawValue, default: 0] += entrada
        u.salida[m.rawValue, default: 0] += salida
        let dolares = Double(entrada) * m.precio.entrada / 1_000_000 + Double(salida) * m.precio.salida / 1_000_000
        u.porTarea[tarea.rawValue, default: 0] += dolares
        u.porDia[Calendar.current.component(.day, from: Reloj.ahora), default: 0] += dolares
        uso = u
        guardarUso()
    }

    func apuntarApple(_ tarea: TareaIA) {
        var u = usoDelMes
        u.apple[tarea.rawValue, default: 0] += 1
        uso = u
        guardarUso()
    }

    private func guardarUso() {
        if let d = try? JSONEncoder().encode(uso) { UserDefaults.standard.set(d, forKey: Self.claveUso) }
    }

    private static func leerUso() -> Uso {
        guard let d = UserDefaults.standard.data(forKey: claveUso), let u = try? JSONDecoder().decode(Uso.self, from: d) else {
            return Uso(mes: mesDeAhora())
        }
        return u
    }

    static func mesDeAhora() -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: Reloj.ahora)
        return "\(c.year ?? 0)-\(c.month ?? 0)"
    }

    static func usoDeEjemplo(dia: Int, gastado: Double) -> Uso {
        var u = Uso(mes: mesDeAhora())
        u.respuestas = [Modelo.haiku.rawValue: 412, Modelo.sonnet.rawValue: 9]
        u.porTarea = [TareaIA.charla.rawValue: gastado * 0.46, TareaIA.voz.rawValue: gastado * 0.18, TareaIA.revisar.rawValue: gastado * 0.14,
                      TareaIA.simulacro.rawValue: gastado * 0.1, TareaIA.esquema.rawValue: gastado * 0.07, TareaIA.resumen.rawValue: gastado * 0.05]
        u.apple = [TareaIA.charla.rawValue: 37]
        let pesos = (1...dia).map { d in 0.6 + 0.8 * abs(sin(Double(d) * 1.7)) }
        let suma = pesos.reduce(0, +)
        for (i, p) in pesos.enumerated() { u.porDia[i + 1] = gastado * p / suma }

        u.entrada = [Modelo.haiku.rawValue: Int(gastado * 0.62 / 0.10 * 1_000_000 * 0.5), Modelo.sonnet.rawValue: 0]
        u.salida = [Modelo.haiku.rawValue: Int(gastado * 0.62 / 0.50 * 1_000_000 * 0.5), Modelo.sonnet.rawValue: Int(gastado * 0.38 / 10 * 1_000_000)]
        return u
    }

    func usarEjemplo(_ u: Uso, tope: Double) {
        uso = u
        self.tope = tope
    }
}
