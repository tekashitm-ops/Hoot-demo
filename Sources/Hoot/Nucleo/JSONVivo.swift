import Foundation

nonisolated enum JSONVivo: Sendable, Equatable {
    case nulo
    case bool(Bool)
    case numero(Double)
    case texto(String)
    case objeto([String: JSONVivo])

    init(_ cualquiera: Any?) {
        switch cualquiera {
        case nil, is NSNull: self = .nulo
        case let s as String: self = .texto(s)
        case let n as NSNumber:
            if JSONVivo.esBool(n) { self = .bool(n.boolValue) } else { self = .numero(n.doubleValue) }
        case let d as [String: Any]:
            var o: [String: JSONVivo] = [:]
            for (k, v) in d { let j = JSONVivo(v); if j != .nulo { o[k] = j } }
            self = o.isEmpty ? .nulo : .objeto(o)
        case let a as [Any]:

            var o: [String: JSONVivo] = [:]
            for (i, v) in a.enumerated() { let j = JSONVivo(v); if j != .nulo { o[String(i)] = j } }
            self = o.isEmpty ? .nulo : .objeto(o)
        default: self = .nulo
        }
    }

    private static func esBool(_ n: NSNumber) -> Bool {
        #if canImport(Darwin)
        return CFGetTypeID(n) == CFBooleanGetTypeID()
        #else
        return String(cString: n.objCType) == "c"
        #endif
    }

    var cualquiera: Any {
        switch self {
        case .nulo: NSNull()
        case .bool(let b): b
        case .numero(let n): n
        case .texto(let s): s
        case .objeto(let o): o.mapValues(\.cualquiera)
        }
    }

    static func leer(_ datos: Data) -> JSONVivo {
        JSONVivo(try? JSONSerialization.jsonObject(with: datos, options: [.fragmentsAllowed]))
    }

    func datos() -> Data {
        (try? JSONSerialization.data(withJSONObject: cualquiera, options: [.fragmentsAllowed])) ?? Data("null".utf8)
    }

    subscript(clave: String) -> JSONVivo {
        if case .objeto(let o) = self { return o[clave] ?? .nulo }
        return .nulo
    }

    func en(_ ruta: [String]) -> JSONVivo {
        var v = self
        for k in ruta { v = v[k]; if v == .nulo { return .nulo } }
        return v
    }

    var texto: String? { if case .texto(let s) = self { return s }; return nil }
    var numero: Double? { if case .numero(let n) = self { return n }; return nil }
    var bool: Bool? { if case .bool(let b) = self { return b }; return nil }
    var objeto: [String: JSONVivo] { if case .objeto(let o) = self { return o }; return [:] }
    var existe: Bool { self != .nulo }

    mutating func poner(_ valor: JSONVivo, en ruta: [String]) {
        guard let primera = ruta.first else { self = valor; return }
        var o = objeto
        var hijo = o[primera] ?? .nulo
        hijo.poner(valor, en: Array(ruta.dropFirst()))
        if hijo == .nulo { o.removeValue(forKey: primera) } else { o[primera] = hijo }
        self = o.isEmpty ? .nulo : .objeto(o)
    }

    mutating func parchear(_ hijos: [String: JSONVivo], en ruta: [String]) {
        for (k, v) in hijos { poner(v, en: ruta + JSONVivo.trozos(k)) }
    }

    static func trozos(_ ruta: String) -> [String] {
        ruta.split(separator: "/").map(String.init)
    }
}

extension JSONVivo: ExpressibleByStringLiteral, ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral,
                    ExpressibleByBooleanLiteral, ExpressibleByDictionaryLiteral {
    nonisolated init(stringLiteral v: String) { self = .texto(v) }
    nonisolated init(floatLiteral v: Double) { self = .numero(v) }
    nonisolated init(integerLiteral v: Int) { self = .numero(Double(v)) }
    nonisolated init(booleanLiteral v: Bool) { self = .bool(v) }
    nonisolated init(dictionaryLiteral pares: (String, JSONVivo)...) {
        var o: [String: JSONVivo] = [:]
        for (k, v) in pares where v != .nulo { o[k] = v }
        self = o.isEmpty ? .nulo : .objeto(o)
    }

    nonisolated static let horaServidor: JSONVivo = [".sv": "timestamp"]
}

nonisolated struct ParserSSE: Sendable {
    nonisolated struct Evento: Equatable, Sendable {
        var tipo: String
        var datos: String
    }

    private var linea: [UInt8] = []
    private var tipo = ""
    private var datos: [String] = []

    init() {}

    mutating func anadir(_ byte: UInt8) -> Evento? {
        guard byte == 10 else { linea.append(byte); return nil }
        var l = linea
        linea.removeAll(keepingCapacity: true)
        if l.last == 13 { l.removeLast() }
        if l.isEmpty {
            defer { tipo = ""; datos = [] }
            if tipo.isEmpty && datos.isEmpty { return nil }
            return Evento(tipo: tipo.isEmpty ? "message" : tipo, datos: datos.joined(separator: "\n"))
        }
        let s = String(decoding: l, as: UTF8.self)
        if s.hasPrefix(":") { return nil }
        let campo: Substring, valor: Substring
        if let dos = s.firstIndex(of: ":") {
            campo = s[..<dos]
            var v = s[s.index(after: dos)...]
            if v.first == " " { v = v.dropFirst() }
            valor = v
        } else {
            campo = Substring(s); valor = ""
        }
        switch campo {
        case "event": tipo = String(valor)
        case "data": datos.append(String(valor))
        default: break
        }
        return nil
    }

    mutating func anadir<S: Sequence>(contentsOf bytes: S) -> [Evento] where S.Element == UInt8 {
        var eventos: [Evento] = []
        for b in bytes { if let e = anadir(b) { eventos.append(e) } }
        return eventos
    }
}

nonisolated enum CambioVivo: Sendable, Equatable {
    case poner(ruta: [String], valor: JSONVivo)
    case parchear(ruta: [String], hijos: [String: JSONVivo])

    case sinPermiso

    case paseCaducado

    init?(_ e: ParserSSE.Evento) {
        switch e.tipo {
        case "put", "patch":
            let j = JSONVivo.leer(Data(e.datos.utf8))
            guard let ruta = j["path"].texto else { return nil }
            if e.tipo == "put" {
                self = .poner(ruta: JSONVivo.trozos(ruta), valor: j["data"])
            } else {
                self = .parchear(ruta: JSONVivo.trozos(ruta), hijos: j["data"].objeto)
            }
        case "cancel": self = .sinPermiso
        case "auth_revoked": self = .paseCaducado
        default: return nil
        }
    }
}

nonisolated struct IDEmpuje: Sendable {
    private static let letras = Array("-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz")
    private var ultimaHora: Int64 = 0
    private var ultimos: [Int] = Array(repeating: 0, count: 12)

    init() {}

    mutating func nuevo(ahora: Date = Date()) -> String {
        var hora = Int64(ahora.timeIntervalSince1970 * 1000)
        let repetida = hora == ultimaHora
        ultimaHora = hora
        var cabeza = [Character](repeating: "-", count: 8)
        for i in stride(from: 7, through: 0, by: -1) {
            cabeza[i] = Self.letras[Int(hora % 64)]
            hora /= 64
        }
        if repetida {
            var i = 11
            while i >= 0 && ultimos[i] == 63 { ultimos[i] = 0; i -= 1 }
            if i >= 0 { ultimos[i] += 1 }
        } else {
            for i in 0..<12 { ultimos[i] = Int.random(in: 0..<64) }
        }
        return String(cabeza) + String(ultimos.map { Self.letras[$0] })
    }
}

nonisolated enum CodigoSala {
    static let letras = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func nuevo() -> String {
        String((0..<6).map { _ in letras.randomElement()! })
    }

    static func limpio(_ s: String) -> String {
        String(s.uppercased().filter { letras.contains($0) }.prefix(6))
    }

    static func bonito(_ c: String) -> String {
        guard c.count == 6 else { return c }
        return "\(c.prefix(3))–\(c.suffix(3))"
    }
}
