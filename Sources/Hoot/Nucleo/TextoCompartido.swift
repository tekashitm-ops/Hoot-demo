import Foundation

nonisolated struct IDLetra: Hashable, Sendable, Comparable {
    var a: String
    var n: Int

    static func < (x: IDLetra, y: IDLetra) -> Bool { x.a == y.a ? x.n < y.n : x.a < y.a }
}

nonisolated enum EstiloParrafo: String, Sendable, CaseIterable { case cuerpo, titulo, encabezado, subencabezado, mono }
nonisolated enum TipoLista: String, Sendable, CaseIterable { case vineta, guion, numero, casilla, hecha }
nonisolated enum FuenteApuntes: String, Sendable, CaseIterable { case sistema, redondeada, serif, mono, mano }
nonisolated enum TamanoApuntes: String, Sendable, CaseIterable { case pequeno, normal, grande, enorme }

nonisolated struct EstiloLetra: Hashable, Sendable {
    var negrita = false
    var cursiva = false
    var subrayado = false
    var tachado = false
    var fuente: FuenteApuntes = .sistema
    var tamano: TamanoApuntes = .normal

    var color: String?

    var resalte: String?
    var parrafo: EstiloParrafo = .cuerpo
    var lista: TipoLista?
    var sangria = 0

    static let normal = EstiloLetra()

    var codigo: String {
        var t: [String] = []
        if negrita { t.append("b") }
        if cursiva { t.append("i") }
        if subrayado { t.append("u") }
        if tachado { t.append("s") }
        if fuente != .sistema { t.append("f:\(fuente.rawValue)") }
        if tamano != .normal { t.append("t:\(tamano.rawValue)") }
        if let color { t.append("c:\(color)") }
        if let resalte { t.append("h:\(resalte)") }
        if parrafo != .cuerpo { t.append("p:\(parrafo.rawValue)") }
        if let lista { t.append("l:\(lista.rawValue)") }
        if sangria > 0 { t.append("g:\(sangria)") }
        return t.joined(separator: ",")
    }

    init() {}

    init(codigo: String) {
        for trozo in codigo.split(separator: ",") {
            let partes = trozo.split(separator: ":", maxSplits: 1).map(String.init)
            let v = partes.count > 1 ? partes[1] : ""
            switch partes[0] {
            case "b": negrita = true
            case "i": cursiva = true
            case "u": subrayado = true
            case "s": tachado = true
            case "f": fuente = FuenteApuntes(rawValue: v) ?? .sistema
            case "t": tamano = TamanoApuntes(rawValue: v) ?? .normal
            case "c": color = v
            case "h": resalte = v
            case "p": parrafo = EstiloParrafo(rawValue: v) ?? .cuerpo
            case "l": lista = TipoLista(rawValue: v)
            case "g": sangria = Int(v) ?? 0
            default: break
            }
        }
    }

    mutating func aplicar(_ c: CambioEstilo) {
        switch c {
        case .negrita(let v): negrita = v
        case .cursiva(let v): cursiva = v
        case .subrayado(let v): subrayado = v
        case .tachado(let v): tachado = v
        case .fuente(let v): fuente = v
        case .tamano(let v): tamano = v
        case .color(let v): color = v
        case .resalte(let v): resalte = v
        case .parrafo(let v): parrafo = v
        case .lista(let v): lista = v
        case .sangria(let v): sangria = max(0, min(v, 6))
        }
    }

    func conParrafo(de otro: EstiloLetra) -> EstiloLetra {
        var e = self
        e.parrafo = otro.parrafo; e.lista = otro.lista; e.sangria = otro.sangria
        return e
    }
}

nonisolated enum CambioEstilo: Hashable, Sendable {
    case negrita(Bool), cursiva(Bool), subrayado(Bool), tachado(Bool)
    case fuente(FuenteApuntes), tamano(TamanoApuntes), color(String?), resalte(String?)
    case parrafo(EstiloParrafo), lista(TipoLista?), sangria(Int)

    var esDeParrafo: Bool {
        switch self {
        case .parrafo, .lista, .sangria: true
        default: false
        }
    }

    fileprivate var clave: String {
        switch self {
        case .negrita: "b"
        case .cursiva: "i"
        case .subrayado: "u"
        case .tachado: "s"
        case .fuente: "f"
        case .tamano: "t"
        case .color: "c"
        case .resalte: "h"
        case .parrafo: "p"
        case .lista: "l"
        case .sangria: "g"
        }
    }

    fileprivate var valor: Any {
        switch self {
        case .negrita(let v), .cursiva(let v), .subrayado(let v), .tachado(let v): v
        case .fuente(let v): v.rawValue
        case .tamano(let v): v.rawValue
        case .color(let v), .resalte(let v): v ?? ""
        case .parrafo(let v): v.rawValue
        case .lista(let v): v?.rawValue ?? ""
        case .sangria(let v): v
        }
    }

    fileprivate init?(clave: String, valor v: Any) {
        let s = v as? String ?? ""
        let b = (v as? NSNumber)?.boolValue ?? false
        switch clave {
        case "b": self = .negrita(b)
        case "i": self = .cursiva(b)
        case "u": self = .subrayado(b)
        case "s": self = .tachado(b)
        case "f": self = .fuente(FuenteApuntes(rawValue: s) ?? .sistema)
        case "t": self = .tamano(TamanoApuntes(rawValue: s) ?? .normal)
        case "c": self = .color(s.isEmpty ? nil : s)
        case "h": self = .resalte(s.isEmpty ? nil : s)
        case "p": self = .parrafo(EstiloParrafo(rawValue: s) ?? .cuerpo)
        case "l": self = .lista(TipoLista(rawValue: s))
        case "g": self = .sangria((v as? NSNumber)?.intValue ?? 0)
        default: return nil
        }
    }
}

nonisolated enum OpApuntes: Hashable, Sendable {

    case insertar(tras: IDLetra?, autor: String, desde: Int, texto: String, estilo: EstiloLetra)
    case borrar([IDLetra])
    case estilo([IDLetra], CambioEstilo)
}

nonisolated struct Letra: Hashable, Sendable {
    var id: IDLetra
    var c: Character
    var borrada = false
    var estilo: EstiloLetra
}

nonisolated struct DocumentoApuntes: Sendable, Equatable {
    private(set) var letras: [Letra] = []
    private var posicion: [IDLetra: Int] = [:]

    init() {}

    init(letras: [Letra]) {
        self.letras = letras
        reindexar()
    }

    private mutating func reindexar() {
        posicion = Dictionary(uniqueKeysWithValues: letras.enumerated().map { ($1.id, $0) })
    }

    static func == (x: DocumentoApuntes, y: DocumentoApuntes) -> Bool { x.letras == y.letras }

    var visibles: [Letra] { letras.filter { !$0.borrada } }
    var texto: String { String(visibles.map(\.c)) }

    func contiene(_ id: IDLetra) -> Bool { posicion[id] != nil }

    func ultimoNumero(de autor: String) -> Int {
        letras.reduce(-1) { $1.id.a == autor ? max($0, $1.id.n) : $0 }
    }

    mutating func aplicar(_ op: OpApuntes) {
        switch op {
        case let .insertar(tras, autor, desde, texto, estilo):
            var donde: Int
            if let tras {

                donde = (posicion[tras].map { $0 + 1 }) ?? letras.count
            } else {
                donde = 0
            }
            var nuevas: [Letra] = []
            for (i, ch) in texto.enumerated() {
                let id = IDLetra(a: autor, n: desde + i)
                if posicion[id] != nil { continue }
                nuevas.append(Letra(id: id, c: ch, estilo: estilo))
            }
            guard !nuevas.isEmpty else { return }
            donde = min(donde, letras.count)
            letras.insert(contentsOf: nuevas, at: donde)
            reindexar()
        case .borrar(let ids):
            for id in ids { if let p = posicion[id] { letras[p].borrada = true } }
        case let .estilo(ids, cambio):
            for id in ids { if let p = posicion[id] { letras[p].estilo.aplicar(cambio) } }
        }
    }
}

nonisolated enum CodigoApuntes {

    static func codificar(_ ops: [OpApuntes]) -> String {
        let a: [Any] = ops.map { op -> Any in
            switch op {
            case let .insertar(tras, autor, desde, texto, estilo):
                return ["i", tras?.a ?? "", tras?.n ?? -1, autor, desde, texto, estilo.codigo] as [Any]
            case .borrar(let ids):
                return ["d", rangos(ids)] as [Any]
            case let .estilo(ids, cambio):
                return ["e", rangos(ids), cambio.clave, cambio.valor] as [Any]
            }
        }
        guard let d = try? JSONSerialization.data(withJSONObject: a) else { return "[]" }
        return String(decoding: d, as: UTF8.self)
    }

    static func decodificar(_ s: String) -> [OpApuntes] {
        guard let a = (try? JSONSerialization.jsonObject(with: Data(s.utf8))) as? [[Any]] else { return [] }
        return a.compactMap { e -> OpApuntes? in
            guard let tipo = e.first as? String else { return nil }
            switch tipo {
            case "i":
                guard e.count >= 7, let ta = e[1] as? String, let tn = (e[2] as? NSNumber)?.intValue, let autor = e[3] as? String,
                      let desde = (e[4] as? NSNumber)?.intValue, let texto = e[5] as? String, let est = e[6] as? String else { return nil }
                return .insertar(tras: ta.isEmpty ? nil : IDLetra(a: ta, n: tn), autor: autor, desde: desde, texto: texto,
                                 estilo: EstiloLetra(codigo: est))
            case "d":
                guard e.count >= 2 else { return nil }
                return .borrar(ids(e[1]))
            case "e":
                guard e.count >= 4, let clave = e[2] as? String, let cambio = CambioEstilo(clave: clave, valor: e[3]) else { return nil }
                return .estilo(ids(e[1]), cambio)
            default: return nil
            }
        }
    }

    private static func rangos(_ ids: [IDLetra]) -> [[Any]] {
        var trozos: [[Any]] = []
        var actual: (a: String, d: Int, h: Int)?
        for id in ids {
            if let c = actual, c.a == id.a, c.h + 1 == id.n {
                actual = (c.a, c.d, id.n)
            } else {
                if let c = actual { trozos.append([c.a, c.d, c.h]) }
                actual = (id.a, id.n, id.n)
            }
        }
        if let c = actual { trozos.append([c.a, c.d, c.h]) }
        return trozos
    }

    private static func ids(_ cualquiera: Any) -> [IDLetra] {
        guard let a = cualquiera as? [[Any]] else { return [] }
        var r: [IDLetra] = []
        for t in a where t.count == 3 {
            guard let autor = t[0] as? String, let d = (t[1] as? NSNumber)?.intValue, let h = (t[2] as? NSNumber)?.intValue, h >= d,
                  h - d < 100_000 else { continue }
            for n in d...h { r.append(IDLetra(a: autor, n: n)) }
        }
        return r
    }

    static func foto(_ d: DocumentoApuntes) -> String {
        d.letras.map { l in
            let letra = String(l.c).replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\n", with: "\\n")
            return "\(l.id.a)\t\(l.id.n)\t\(l.borrada ? 1 : 0)\t\(l.estilo.codigo)\t\(letra)"
        }.joined(separator: "\n")
    }

    static func desdeFoto(_ s: String) -> DocumentoApuntes {
        guard !s.isEmpty else { return DocumentoApuntes() }
        var letras: [Letra] = []
        for linea in s.split(separator: "\n", omittingEmptySubsequences: false) {
            let p = linea.split(separator: "\t", maxSplits: 4, omittingEmptySubsequences: false).map(String.init)
            guard p.count == 5, let n = Int(p[1]) else { continue }
            let letra = p[4].replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\\\", with: "\\")
            guard let c = letra.first else { continue }
            letras.append(Letra(id: IDLetra(a: p[0], n: n), c: c, borrada: p[2] == "1", estilo: EstiloLetra(codigo: p[3])))
        }
        return DocumentoApuntes(letras: letras)
    }
}

nonisolated struct EditorApuntes: Sendable {
    nonisolated struct Lote: Hashable, Sendable {
        var id: String
        var ops: [OpApuntes]
    }

    let yo: String
    private(set) var confirmado = DocumentoApuntes()
    private(set) var revision = 0

    private(set) var pendientes: [Lote] = []
    private var abierto: [OpApuntes] = []
    private var siguiente: Int
    private var numeroLote = 0

    private(set) var actual = DocumentoApuntes()

    init(yo: String) {
        self.yo = yo
        siguiente = 0
    }

    mutating func empezar(desde foto: DocumentoApuntes, revision r: Int) {
        confirmado = foto
        revision = r
        siguiente = max(siguiente, foto.ultimoNumero(de: yo) + 1)
        reconstruir()
    }

    var hayPendientes: Bool { !pendientes.isEmpty || !abierto.isEmpty }

    mutating func editar(_ rango: Range<Int>, por texto: String, estilo: EstiloLetra) {
        let vis = actual.visibles
        let r = rango.clamped(to: 0..<vis.count)
        if !r.isEmpty { anotar(.borrar(vis[r].map(\.id))) }
        guard !texto.isEmpty else { return }
        let tras = r.lowerBound > 0 ? vis[r.lowerBound - 1].id : nil
        let op = OpApuntes.insertar(tras: tras, autor: yo, desde: siguiente, texto: texto, estilo: estilo)
        siguiente += texto.count
        anotar(op)
    }

    mutating func cambiar(_ rango: Range<Int>, _ cambio: CambioEstilo) {
        let vis = actual.visibles
        guard !vis.isEmpty else { return }
        var r = rango.clamped(to: 0..<vis.count)
        if cambio.esDeParrafo {
            var ini = min(r.lowerBound, vis.count - 1), fin = max(r.upperBound, ini + 1)
            while ini > 0 && vis[ini - 1].c != "\n" { ini -= 1 }
            while fin < vis.count && vis[fin - 1].c != "\n" { fin += 1 }
            r = ini..<min(fin, vis.count)
        }
        guard !r.isEmpty else { return }
        anotar(.estilo(vis[r].map(\.id), cambio))
    }

    private mutating func anotar(_ op: OpApuntes) {
        abierto.append(op)
        actual.aplicar(op)
    }

    mutating func cerrarLote() {
        guard !abierto.isEmpty else { return }
        numeroLote += 1
        pendientes.append(Lote(id: "\(yo)-\(numeroLote)-\(Int.random(in: 0..<1_000_000))", ops: abierto))
        abierto = []
    }

    var paraMandar: (rev: Int, lote: Lote)? {
        pendientes.first.map { (revision + 1, $0) }
    }

    @discardableResult
    mutating func recibir(rev: Int, idLote: String, ops: [OpApuntes]) -> Bool {
        guard rev == revision + 1 else { return rev <= revision }
        for op in ops { confirmado.aplicar(op) }
        revision = rev
        if let i = pendientes.firstIndex(where: { $0.id == idLote }) {
            pendientes.remove(at: i)
        }
        reconstruir()
        return true
    }

    private mutating func reconstruir() {
        var d = confirmado
        for lote in pendientes { for op in lote.ops { d.aplicar(op) } }
        for op in abierto { d.aplicar(op) }
        actual = d
    }
}
