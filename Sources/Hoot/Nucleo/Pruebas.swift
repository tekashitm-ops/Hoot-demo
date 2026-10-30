import Foundation

nonisolated enum TipoPrueba: String, Codable, CaseIterable, Identifiable, Sendable {
    case escrita, oral

    var id: String { rawValue }
}

nonisolated enum Seguridad: String, Codable, CaseIterable, Identifiable, Sendable {
    case niIdea, creoQueSi, seguro

    var id: String { rawValue }
}

nonisolated struct Respuesta: Codable, Hashable, Sendable {
    var acierto: Bool
    var seguridad: Seguridad?
}

nonisolated struct Intento: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var fecha: Date
    var respuestas: [Respuesta] = []

    var mezclado = false

    var aciertos: Int { respuestas.filter(\.acierto).count }

    var proporcion: Double? {
        respuestas.isEmpty ? nil : Double(aciertos) / Double(respuestas.count)
    }

    var aprueba: Bool {
        respuestas.count >= FaseLuna.minimoRespuestas && (proporcion ?? 0) >= FaseLuna.aprobado
    }
}

nonisolated struct PreguntaFallada: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var pregunta: String
    var esperada: String
    var fecha: Date
}

nonisolated struct FuenteTema: Identifiable, Codable, Hashable, Sendable {
    enum Tipo: String, Codable, Sendable {
        case fotos, pdf, diapositivas, documento, texto
    }

    var id = UUID()
    var tipo: Tipo
    var nombre: String

    var paginas = 0
    var fecha = Date()

    var texto = ""
}

nonisolated struct MensajeCharla: Identifiable, Codable, Hashable, Sendable {
    enum Quien: String, Codable, Sendable {
        case yo, hoot
    }

    var id = UUID()
    var quien: Quien
    var texto: String

    var fuente = ""

    var foto: Data?
    var fecha = Date()

    var masFotos: [Data] = []

    var fotos: [Data] { (foto.map { [$0] } ?? []) + masFotos }
}

nonisolated struct PruebaAntigua: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var asignaturaID: UUID?
    var texto: String

    var miniatura: Data?
    var fecha = Date()
}

nonisolated struct AudioTema: Codable, Hashable, Sendable {

    var huella: UInt64
    var resumen: String
    var preguntas: [PreguntaAudio]
}

nonisolated struct PreguntaAudio: Codable, Hashable, Sendable {
    var pregunta: String
    var respuesta: String
}

extension String {

    nonisolated var huellaEstable: UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in utf8 {
            h ^= UInt64(b)
            h = h &* 0x0000_0100_0000_01b3
        }
        return h
    }
}

nonisolated struct Tema: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var nombre: String

    var miniaturas: [Data] = []

    var textoLeido = ""
    var intentos: [Intento] = []

    var falladas: [PreguntaFallada] = []

    var fuentes: [FuenteTema] = []

    var charla: [MensajeCharla] = []

    var audio: AudioTema?

    var apuntado: Date?

    func luna(cal: Calendar) -> FaseLuna { FaseLuna.de(intentos, cal: cal) }

    func practicado(_ dia: Date, cal: Calendar) -> Bool {
        intentos.contains { cal.isDate($0.fecha, inSameDayAs: dia) }
    }
}

nonisolated struct Prueba: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var asignaturaID: UUID?
    var tipo: TipoPrueba = .escrita

    var fecha: Date
    var temas: [Tema] = []

    var deFamilia = false

    var privada = false

    var sorpresaTemaID: UUID?

    var ultimoSimulacro: Date?
    var notas = ""

    func llenos(cal: Calendar) -> Int { temas.filter { $0.luna(cal: cal) == .llena }.count }

    func progreso(cal: Calendar) -> Double {
        temas.isEmpty ? 0 : Double(llenos(cal: cal)) / Double(temas.count)
    }

    func diasQueFaltan(desde ahora: Date, cal: Calendar) -> Int {
        cal.dateComponents([.day], from: cal.startOfDay(for: ahora), to: cal.startOfDay(for: fecha)).day ?? 0
    }

    static func nombresDeTemas(_ texto: String) -> [String] {
        var limpio = texto

        if let dos = limpio.firstIndex(of: ":") {
            let antes = limpio[..<dos].trimmingCharacters(in: .whitespaces)
            if !antes.isEmpty, antes.count <= 12, antes.allSatisfy(\.isLetter) {
                limpio = String(limpio[limpio.index(after: dos)...])
            }
        }
        let separadores = CharacterSet(charactersIn: "\n\r;,•·")
        var partes = limpio.components(separatedBy: separadores)
            .map(limpiarNombre)
            .filter { !$0.isEmpty }
        if partes.count >= 2, let ultima = partes.last {
            for conjuncion in [" y ", " e ", " and ", " i "] {
                guard let r = ultima.range(of: conjuncion, options: .backwards) else { continue }
                let a = limpiarNombre(String(ultima[..<r.lowerBound]))
                let b = limpiarNombre(String(ultima[r.upperBound...]))
                if a.filter(\.isLetter).count >= 3 && b.filter(\.isLetter).count >= 3 {
                    partes.removeLast()
                    partes += [a, b]
                }
                break
            }
        }
        var vistos = Set<String>()
        var r: [String] = []
        for p in partes {
            let clave = p.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            guard vistos.insert(clave).inserted else { continue }
            r.append(String(p.prefix(80)))
            if r.count == 12 { break }
        }
        return r
    }

    private static func limpiarNombre(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".-–—\"«»“”")))
    }
}

nonisolated struct TemaDeAhora: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var asignaturaID: UUID?
    var tema: Tema

    var activo = true
}

nonisolated extension UUID {

    static func derivado(de base: UUID, _ n: Int) -> UUID {
        var b = base.uuid
        b.15 ^= UInt8(truncatingIfNeeded: n + 1)
        b.14 ^= UInt8(truncatingIfNeeded: (n + 1) >> 8) ^ 0x5A
        return UUID(uuid: b)
    }
}

nonisolated enum Biblioteca {

    struct Entrada: Identifiable, Hashable, Sendable {
        var tema: Tema
        var asignaturaID: UUID?
        var pruebaID: UUID?
        var id: UUID { tema.id }
    }

    static func temas(pruebas: [Prueba], sueltos: [TemaDeAhora], ahora: Date, cal: Calendar, conPasadas: Bool = true) -> [Entrada] {
        var vistos = Set<UUID>()
        var r: [Entrada] = []
        func poner(_ e: Entrada) { if vistos.insert(e.id).inserted { r.append(e) } }
        for s in sueltos.reversed() where conPasadas || s.activo { poner(Entrada(tema: s.tema, asignaturaID: s.asignaturaID, pruebaID: nil)) }
        let vienen = pruebas.filter { $0.diasQueFaltan(desde: ahora, cal: cal) >= 0 }.sorted { $0.fecha < $1.fecha }
        let pasadas = pruebas.filter { $0.diasQueFaltan(desde: ahora, cal: cal) < 0 }.sorted { $0.fecha > $1.fecha }
        for p in vienen + (conPasadas ? pasadas : []) {
            for t in p.temas { poner(Entrada(tema: t, asignaturaID: p.asignaturaID, pruebaID: p.id)) }
        }
        return r
    }

    static func porAsignatura(_ temas: [Entrada]) -> [(asignaturaID: UUID?, temas: [Entrada])] {
        var orden: [UUID?] = []
        var grupos: [UUID?: [Entrada]] = [:]
        for t in temas {
            if grupos[t.asignaturaID] == nil { orden.append(t.asignaturaID) }
            grupos[t.asignaturaID, default: []].append(t)
        }
        return orden.map { ($0, grupos[$0] ?? []) }
    }

    static func plano(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func buscar(_ texto: String, en temas: [Entrada], asignatura: (UUID?) -> String) -> [Entrada] {
        let q = plano(texto)
        guard !q.isEmpty else { return [] }
        let encontrados = temas.filter { plano($0.tema.nombre).contains(q) || plano(asignatura($0.asignaturaID)).contains(q) }
        return encontrados.filter { plano($0.tema.nombre).hasPrefix(q) } + encontrados.filter { !plano($0.tema.nombre).hasPrefix(q) }
    }

    static func adjuntar(_ ids: [UUID], a pruebaID: UUID, pruebas: inout [Prueba], sueltos: inout [TemaDeAhora]) {
        guard let i = pruebas.firstIndex(where: { $0.id == pruebaID }) else { return }
        for id in ids where !pruebas[i].temas.contains(where: { $0.id == id }) {
            guard let j = sueltos.firstIndex(where: { $0.tema.id == id }) else { continue }
            pruebas[i].temas.append(sueltos[j].tema)
            sueltos.remove(at: j)
        }
    }

    static func borrar(_ id: UUID, pruebas: inout [Prueba], sueltos: inout [TemaDeAhora]) {
        sueltos.removeAll { $0.tema.id == id }
        for i in pruebas.indices { pruebas[i].temas.removeAll { $0.id == id } }
    }

    static func paraSeguir(_ temas: [Entrada], cal: Calendar) -> Entrada? {
        let conMaterial = temas.filter { !$0.tema.textoLeido.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let sinLlenar = conMaterial.filter { $0.tema.luna(cal: cal) != .llena }
        if let ultimo = sinLlenar.filter({ !$0.tema.intentos.isEmpty }).max(by: {
            ($0.tema.intentos.map(\.fecha).max() ?? .distantPast) < ($1.tema.intentos.map(\.fecha).max() ?? .distantPast)
        }) {
            return ultimo
        }
        return sinLlenar.min { $0.tema.luna(cal: cal).rawValue < $1.tema.luna(cal: cal).rawValue }
    }

    static let preguntasRepasito = 8
    static func porTemaRepasito(_ temas: Int) -> Int {
        max(1, Int((Double(preguntasRepasito) / Double(max(1, temas))).rounded()))
    }
}

nonisolated enum FaseLuna: Int, Codable, CaseIterable, Comparable, Sendable {

    case nueva = 0

    case creciente

    case cuarto

    case gibosa

    case llena

    var fraccion: Double { Double(rawValue) / 4 }

    static func < (a: FaseLuna, b: FaseLuna) -> Bool { a.rawValue < b.rawValue }

    static let minimoRespuestas = 3

    static let aprobado = 0.8

    static let algo = 0.5

    static func de(_ intentos: [Intento], cal: Calendar) -> FaseLuna {
        var dias = Set<Date>()
        var mezclado = false
        var algoBien = false
        var menguada = false
        var sueltas: [Respuesta] = []
        for original in intentos.sorted(by: { $0.fecha < $1.fecha }) {
            var i = original
            if i.mezclado && i.respuestas.count < minimoRespuestas {
                sueltas += i.respuestas
                guard sueltas.count >= minimoRespuestas else { continue }
                i = Intento(fecha: i.fecha, respuestas: sueltas, mezclado: true)
                sueltas = []
            }
            if i.aprueba {
                dias.insert(cal.startOfDay(for: i.fecha))
                if i.mezclado { mezclado = true }
                menguada = false
            } else if let p = i.proporcion {
                if p >= algo { algoBien = true }
                if p < algo && fase(dias: dias.count, mezclado: mezclado, algoBien: algoBien) == .llena { menguada = true }
            }
        }
        let f = fase(dias: dias.count, mezclado: mezclado, algoBien: algoBien)
        return menguada && f == .llena ? .gibosa : f
    }

    private static func fase(dias: Int, mezclado: Bool, algoBien: Bool) -> FaseLuna {
        switch dias {
        case 2...: mezclado ? .llena : .gibosa
        case 1: mezclado ? .gibosa : .cuarto
        default: algoBien ? .creciente : .nueva
        }
    }
}

nonisolated struct Calibracion: Hashable, Sendable {
    enum Lectura: Sendable { case sinDatos, ajustada, demasiadoSeguro, pocoSeguro }

    var segurasBien = 0
    var segurasMal = 0

    var dudasBien = 0
    var dudasMal = 0

    static let minimo = 5

    init(_ respuestas: [Respuesta]) {
        for r in respuestas {
            switch (r.seguridad, r.acierto) {
            case (.seguro?, true): segurasBien += 1
            case (.seguro?, false): segurasMal += 1
            case (.some, true): dudasBien += 1
            case (.some, false): dudasMal += 1
            case (nil, _): break
            }
        }
    }

    init(intentos: [Intento]) { self.init(intentos.flatMap(\.respuestas)) }

    var aciertoSiSeguro: Double? {
        let n = segurasBien + segurasMal
        return n == 0 ? nil : Double(segurasBien) / Double(n)
    }

    var aciertoSiDuda: Double? {
        let n = dudasBien + dudasMal
        return n == 0 ? nil : Double(dudasBien) / Double(n)
    }

    var lectura: Lectura {
        let seguras = segurasBien + segurasMal
        let dudas = dudasBien + dudasMal
        if seguras >= Self.minimo, let a = aciertoSiSeguro, a < 0.7 { return .demasiadoSeguro }
        if dudas >= Self.minimo, let a = aciertoSiDuda, a >= 0.8 { return .pocoSeguro }
        return seguras + dudas >= Self.minimo ? .ajustada : .sinDatos
    }
}

nonisolated struct SesionRepaso: Identifiable, Hashable, Sendable {
    var id: String

    var dia: Date

    var hora: Int
    var minutos: Int
    var temaIDs: [UUID]

    var mezclada: Bool

    var ligera: Bool

    var pruebaID: UUID?

    var simulacro = false
}

nonisolated struct DiaLibre: Hashable, Sendable {
    var huecos: [Hueco]
    var maximo: Int
}

nonisolated struct PlanRepaso: Hashable, Sendable {
    var sesiones: [SesionRepaso] = []

    var justas: Set<UUID> = []

    static let diasAntes = 7
    static let minutosLigero = 10

    static func minutosSimulacro(_ temas: Int) -> Int { min(30, max(15, temas * 5)) }
    static let minutosDeAhora = 10

    static let cadaDeAhora = 2

    static let descanso = 15

    func sesiones(en dia: Date, cal: Calendar) -> [SesionRepaso] {
        sesiones.filter { cal.isDate($0.dia, inSameDayAs: dia) }.sorted { $0.hora < $1.hora }
    }

    func sesiones(de prueba: Prueba) -> [SesionRepaso] {
        let ids = Set(prueba.temas.map(\.id))
        return sesiones.filter { $0.pruebaID == prueba.id || !ids.isDisjoint(with: $0.temaIDs) }
    }

    func empieza(_ prueba: Prueba) -> Date? { sesiones(de: prueba).first?.dia }

    static func clave(_ dia: Date, cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: dia)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func calcular(pruebas: [Prueba], temasDeAhora: [TemaDeAhora], minutosRato: Int, sinRepaso: Set<Date>,
                         ahora: Date, cal: Calendar, dias: Int = 28, libre: (Date) -> DiaLibre) -> PlanRepaso {
        let hoy = cal.startOfDay(for: ahora)
        let descansos = Set(sinRepaso.map { cal.startOfDay(for: $0) })
        let rato = max(5, minutosRato)
        let futuras = pruebas
            .filter { !$0.temas.isEmpty && cal.startOfDay(for: $0.fecha) > hoy }
            .sorted { $0.fecha < $1.fecha }
        let deAhora = temasDeAhora.filter(\.activo)
        func diaDe(_ p: Prueba) -> Date { cal.startOfDay(for: p.fecha) }
        func sumar(_ n: Int, _ d: Date) -> Date { cal.date(byAdding: .day, value: n, to: d) ?? d }
        func entre(_ a: Date, _ b: Date) -> Int { cal.dateComponents([.day], from: a, to: b).day ?? 0 }

        var proyeccion: [UUID: Tema] = [:]
        var deQuePrueba: [UUID: UUID] = [:]
        for p in futuras {
            for t in p.temas {
                proyeccion[t.id] = t
                deQuePrueba[t.id] = p.id
            }
        }
        for a in deAhora { proyeccion[a.tema.id] = a.tema }
        var veces: [UUID: Int] = [:]
        var ultimoDeAhora: Date?
        var plan = PlanRepaso()

        func aprobar(_ ids: [UUID], _ dia: Date, mezclado: Bool) {
            for id in ids {
                if let t = proyeccion[id] { proyeccion[id] = conAprobado(t, dia, mezclado: mezclado, cal) }
                veces[id, default: 0] += 1
            }
        }

        for n in 0..<max(0, dias) {
            let d = sumar(n, hoy)
            guard !descansos.contains(d) else { continue }
            let hoyLibre = libre(d)
            var huecos = hoyLibre.huecos.sorted { $0.inicio < $1.inicio }
            var queda = hoyLibre.maximo
            var usados = Set<UUID>()
            var ratosHoy = 0

            func anadir(_ tipo: String, _ ids: [UUID], minutos: Int, mezclada: Bool, ligera: Bool, prueba: UUID?, simulacro: Bool = false) -> Bool {
                guard !ids.isEmpty, queda >= minutos, let i = huecos.firstIndex(where: { $0.duracion >= minutos }) else { return false }
                let hora = huecos[i].inicio
                huecos[i].inicio += minutos + descanso
                if huecos[i].duracion < 15 { huecos.remove(at: i) }
                queda -= minutos
                ratosHoy += 1
                usados.formUnion(ids)
                plan.sesiones.append(SesionRepaso(id: "\(clave(d, cal: cal))-\(tipo)", dia: d, hora: hora, minutos: minutos,
                                                  temaIDs: ids, mezclada: mezclada, ligera: ligera, pruebaID: prueba, simulacro: simulacro))
                return true
            }

            func libreHoy(_ id: UUID) -> Bool {
                guard !usados.contains(id), let t = proyeccion[id] else { return false }
                return !t.practicado(d, cal: cal)
            }

            for p in futuras where sumar(-1, diaDe(p)) == d {
                _ = anadir("ligero-\(p.id)", p.temas.map(\.id), minutos: minutosLigero, mezclada: false, ligera: true, prueba: p.id)
            }

            for p in futuras where sumar(-2, diaDe(p)) == d && p.temas.contains(where: { $0.luna(cal: cal) < .llena })
                && !(p.ultimoSimulacro.map { cal.startOfDay(for: $0) >= sumar(-3, diaDe(p)) } ?? false) {
                let ids = p.temas.map(\.id)
                if anadir("simulacro-\(p.id)", ids, minutos: minutosSimulacro(ids.count), mezclada: true, ligera: false, prueba: p.id, simulacro: true) {
                    aprobar(ids, d, mezclado: true)
                }
            }

            let enMarcha = futuras.filter { d >= max(hoy, sumar(-diasAntes, diaDe($0))) && d <= sumar(-2, diaDe($0)) }

            if !enMarcha.isEmpty {
                let grupos = enMarcha.map { $0.temas.map(\.id) } + [deAhora.map(\.tema.id)]
                var aprobados: [(id: UUID, grupo: Int, fase: FaseLuna, necesita: Bool)] = []
                for (g, ids) in grupos.enumerated() {
                    for id in ids where libreHoy(id) {
                        guard let t = proyeccion[id] else { continue }
                        let f = t.luna(cal: cal)
                        if f >= .cuarto { aprobados.append((id, g, f, f < .llena && mejora(t, d, mezclado: true, cal))) }
                    }
                }
                let necesitan = aprobados.filter(\.necesita).sorted { ($1.fase.rawValue, $0.grupo) < ($0.fase.rawValue, $1.grupo) }
                if aprobados.count >= 2 && !necesitan.isEmpty {
                    let compania = aprobados.filter { !$0.necesita }
                    var elegidos: [UUID] = []
                    var gruposUsados = Set<Int>()
                    for (lista, distintos) in [(necesitan, true), (necesitan, false), (compania, true), (compania, false)] {
                        for c in lista where elegidos.count < 3 && !elegidos.contains(c.id) && !(distintos && gruposUsados.contains(c.grupo)) {
                            elegidos.append(c.id)
                            gruposUsados.insert(c.grupo)
                        }
                    }
                    let suyas = Set(elegidos.map { deQuePrueba[$0] })
                    let prueba = suyas.count == 1 ? suyas.first ?? nil : nil
                    if anadir("mezclado", elegidos, minutos: rato, mezclada: true, ligera: false, prueba: prueba) {
                        aprobar(elegidos, d, mezclado: true)
                    }
                }
            }

            for p in enMarcha {
                let elegibles = p.temas.enumerated().compactMap { (i, t0) -> (id: UUID, fase: Int, veces: Int, orden: Int)? in
                    guard libreHoy(t0.id), let t = proyeccion[t0.id] else { return nil }
                    let f = t.luna(cal: cal)
                    guard f < .llena, mejora(t, d, mezclado: false, cal) else { return nil }
                    return (t0.id, f.rawValue, veces[t0.id] ?? 0, i)
                }.sorted { ($0.fase, $0.veces, $0.orden) < ($1.fase, $1.veces, $1.orden) }
                guard !elegibles.isEmpty else { continue }
                let quedan = (0...max(0, entre(d, sumar(-2, diaDe(p))))).filter { !descansos.contains(sumar($0, d)) }.count
                let porDia = min(3, max(1, Int((Double(elegibles.count) / Double(2 * max(1, quedan))).rounded(.up))))
                var resto = elegibles.map(\.id)
                for k in 0..<porDia where !resto.isEmpty {
                    let ids = Array(resto.prefix(2))
                    resto.removeFirst(ids.count)
                    if anadir("rato-\(p.id)-\(k + 1)", ids, minutos: rato, mezclada: false, ligera: false, prueba: p.id) {
                        aprobar(ids, d, mezclado: false)
                    } else {
                        break
                    }
                }
            }

            if !deAhora.isEmpty {
                let pasados = ultimoDeAhora.map { entre($0, d) } ?? (n + cadaDeAhora)
                if pasados >= cadaDeAhora && (ratosHoy < 2 || pasados > cadaDeAhora) {
                    let orden = deAhora.enumerated().filter { libreHoy($0.element.tema.id) }.sorted { a, b in
                        let ta = proyeccion[a.element.tema.id] ?? a.element.tema
                        let tb = proyeccion[b.element.tema.id] ?? b.element.tema
                        let fa = ta.luna(cal: cal), fb = tb.luna(cal: cal)
                        if fa != fb { return fa < fb }
                        let ua = ta.intentos.map(\.fecha).max() ?? .distantPast
                        let ub = tb.intentos.map(\.fecha).max() ?? .distantPast
                        return ua != ub ? ua < ub : a.offset < b.offset
                    }
                    let ids = orden.prefix(3).map(\.element.tema.id)
                    if anadir("ahora", ids, minutos: minutosDeAhora, mezclada: ids.count >= 2, ligera: false, prueba: nil) {
                        ultimoDeAhora = d
                        aprobar(ids, d, mezclado: ids.count >= 2)
                    }
                }
            }
        }

        for p in futuras where diaDe(p) <= sumar(dias, hoy) {
            if p.temas.contains(where: { (proyeccion[$0.id] ?? $0).luna(cal: cal) < .llena }) { plan.justas.insert(p.id) }
        }
        plan.sesiones.sort { ($0.dia, $0.hora) < ($1.dia, $1.hora) }
        return plan
    }

    private static func conAprobado(_ t: Tema, _ dia: Date, mezclado: Bool, _ cal: Calendar) -> Tema {
        var t = t
        let cuando = cal.date(byAdding: .hour, value: 20, to: dia) ?? dia
        t.intentos.append(Intento(fecha: cuando, respuestas: Array(repeating: Respuesta(acierto: true, seguridad: nil),
                                                                   count: FaseLuna.minimoRespuestas), mezclado: mezclado))
        return t
    }

    private static func mejora(_ t: Tema, _ dia: Date, mezclado: Bool, _ cal: Calendar) -> Bool {
        conAprobado(t, dia, mezclado: mezclado, cal).luna(cal: cal) > t.luna(cal: cal)
    }
}
