import Foundation

struct GrupoMochila: Hashable {
    var id: String
    var titulo: String
    var simbolo: String
    var color: ColorHoot?
}

struct ItemMochila: Identifiable, Hashable {

    var id: String
    var nombre: String
    var simbolo: String
    var colores: [ColorHoot]
    var deDonde: [String]

    var grupo: GrupoMochila
}

enum ElementoDia: Identifiable, Hashable {
    case clase(Clase)
    case actividad(Actividad)
    case tarea(Tarea)
    case recordatorio(Recordatorio)

    var id: String {
        switch self {
        case .clase(let c): "c-\(c.id)"
        case .actividad(let a): "a-\(a.id)"
        case .tarea(let t): "t-\(t.id)"
        case .recordatorio(let r): "r-\(r.id)"
        }
    }
}

extension DatosEscolares {
    static func clave(_ dia: Date) -> String {
        let c = calendarioActual.dateComponents([.year, .month, .day], from: dia)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func diaISO(_ fecha: Date) -> Int {
        let w = Calendar(identifier: .gregorian).component(.weekday, from: fecha)
        return w == 1 ? 7 : w - 1
    }

    static func minutos(_ fecha: Date) -> Int {
        let c = calendarioActual.dateComponents([.hour, .minute], from: fecha)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func fecha(_ dia: Date, minutos: Int) -> Date {
        calendarioActual.date(bySettingHour: minutos / 60, minute: minutos % 60, second: 0, of: dia) ?? dia
    }

    func asignatura(_ id: UUID?) -> Asignatura? {
        guard let id else { return nil }
        return asignaturas.first { $0.id == id }
    }

    static var ordenSemana: [Int] {
        let primero = calendarioActual.firstWeekday == 1 ? 7 : calendarioActual.firstWeekday - 1
        return (0..<7).map { (primero - 1 + $0) % 7 + 1 }
    }

    var diasLectivosOrdenados: [Int] {
        Self.ordenSemana.filter { diasLectivos.contains($0) }
    }

    func esLectivo(_ dia: Date) -> Bool {
        diasLectivos.contains(Self.diaISO(dia))
    }

    func clases(en dia: Date) -> [Clase] {
        let iso = Self.diaISO(dia)
        guard diasLectivos.contains(iso) else { return [] }
        return horario.filter { $0.dia == iso }.sorted { $0.inicio < $1.inicio }
    }

    func hayClase(_ dia: Date) -> Bool {
        let iso = Self.diaISO(dia)
        return diasLectivos.contains(iso) && horario.contains { $0.dia == iso }
    }

    var diasConClase: [Int] {
        let con = Set(horario.map(\.dia))
        return diasLectivosOrdenados.filter { con.contains($0) }
    }

    func claseAhora(_ ahora: Date = Reloj.ahora) -> (actual: Clase?, siguiente: Clase?) {
        let m = Self.minutos(ahora)
        let hoy = clases(en: ahora)
        let actual = hoy.first { $0.inicio <= m && m < $0.fin }
        let siguiente = hoy.first { $0.inicio >= (actual?.fin ?? m) && $0.id != actual?.id }
        return (actual, siguiente)
    }

    func siguienteDiaConClase(despuesDe dia: Date) -> Date? {
        guard !horario.isEmpty else { return nil }
        let cal = calendarioActual
        var d = cal.startOfDay(for: dia)
        for _ in 0..<14 {
            d = cal.date(byAdding: .day, value: 1, to: d) ?? d
            if hayClase(d) { return d }
        }
        return nil
    }

    func ocurre(_ a: Actividad, en dia: Date) -> Bool {
        let cal = calendarioActual
        let d = cal.startOfDay(for: dia)
        let primero = cal.startOfDay(for: a.fecha)
        if d < primero { return false }
        if let hasta = a.hasta, d > cal.startOfDay(for: hasta) { return false }
        switch a.repeticion {
        case .nunca:
            return d == primero
        case .diaria:
            return true
        case .semanal(let dias):
            let set = dias.isEmpty ? [Self.diaISO(a.fecha)] : dias
            return set.contains(Self.diaISO(d))
        case .quincenal(let dias):
            let set = dias.isEmpty ? [Self.diaISO(a.fecha)] : dias
            guard set.contains(Self.diaISO(d)) else { return false }
            let semanas = cal.dateComponents([.weekOfYear], from: inicioSemana(primero), to: inicioSemana(d)).weekOfYear ?? 0
            return semanas % 2 == 0
        case .mensual:
            return cal.component(.day, from: d) == cal.component(.day, from: primero)
        }
    }

    private func inicioSemana(_ d: Date) -> Date {
        let cal = calendarioActual
        return cal.dateInterval(of: .weekOfYear, for: d)?.start ?? d
    }

    func actividades(en dia: Date) -> [Actividad] {
        let propias = actividades.filter { ocurre($0, en: dia) }
        let citas = delCalendario.filter { c in
            ocurre(c, en: dia) && !propias.contains { FusionCalendarios.coincide(titulo: $0.titulo, inicio: $0.inicio, conTitulo: c.titulo, inicio: c.inicio) }
        }
        return (propias + citas).sorted { ($0.inicio ?? -1) < ($1.inicio ?? -1) }
    }

    func tareas(en dia: Date) -> [Tarea] {
        let cal = calendarioActual
        return tareas.filter { cal.isDate($0.entrega, inSameDayAs: dia) }.sorted { $0.entrega < $1.entrega }
    }

    func recordatorios(en dia: Date) -> [Recordatorio] {
        let cal = calendarioActual
        return recordatorios.filter { cal.isDate($0.fecha, inSameDayAs: dia) }.sorted { $0.fecha < $1.fecha }
    }

    var pendientes: [Tarea] {
        tareas.filter { !$0.hecha }.sorted { $0.entrega < $1.entrega }
    }

    func proximoExamen(desde ahora: Date = Reloj.ahora) -> Tarea? {
        let hoy = calendarioActual.startOfDay(for: ahora)
        return tareas.filter { $0.tipo == .examen && !$0.hecha && $0.entrega >= hoy }.min { $0.entrega < $1.entrega }
    }

    func elementos(en dia: Date) -> [ElementoDia] {
        var r: [(Int, ElementoDia)] = []
        r += clases(en: dia).map { ($0.inicio, .clase($0)) }
        r += actividades(en: dia).map { ($0.inicio ?? -1, .actividad($0)) }
        r += tareas(en: dia).map { (Self.minutos($0.entrega), .tarea($0)) }
        r += recordatorios(en: dia).map { ($0.conHora ? Self.minutos($0.fecha) : -1, .recordatorio($0)) }
        return r.sorted { $0.0 < $1.0 }.map(\.1)
    }

    func diaMochila(ahora: Date = Reloj.ahora) -> Date? {
        let cal = calendarioActual
        if let primera = clases(en: ahora).first, Self.minutos(ahora) < primera.inicio {
            return cal.startOfDay(for: ahora)
        }
        return siguienteDiaConClase(despuesDe: ahora)
    }

    static func normalizar(_ texto: String) -> String {
        texto.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func itemsMochila(para dia: Date) -> [ItemMochila] {
        var orden: [String] = []
        var items: [String: ItemMochila] = [:]

        func anadir(_ nombre: String, simbolo: String, color: ColorHoot?, de origen: String, grupo: GrupoMochila) {
            let limpio = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !limpio.isEmpty else { return }
            let k = Self.normalizar(limpio)
            if var it = items[k] {
                if let color, !it.colores.contains(color) { it.colores.append(color) }
                if !it.deDonde.contains(origen) { it.deDonde.append(origen) }
                items[k] = it
            } else {
                items[k] = ItemMochila(id: k, nombre: limpio, simbolo: simbolo, colores: color.map { [$0] } ?? [], deDonde: [origen], grupo: grupo)
                orden.append(k)
            }
        }

        let iso = Self.diaISO(dia)
        var vistas = Set<UUID>()
        for clase in clases(en: dia) {
            guard !vistas.contains(clase.asignaturaID), let a = asignatura(clase.asignaturaID) else { continue }
            vistas.insert(clase.asignaturaID)
            let grupo = GrupoMochila(id: "a-\(a.id)", titulo: a.nombre, simbolo: a.simbolo, color: a.color)
            for m in a.materiales where m.dias.isEmpty || m.dias.contains(iso) {
                anadir(m.nombre, simbolo: m.tipo.simbolo, color: a.color, de: a.nombre, grupo: grupo)
            }
        }
        for act in actividades(en: dia) {
            let grupo = GrupoMochila(id: "act-\(act.id)", titulo: act.titulo, simbolo: act.simbolo, color: act.color)
            for cosa in act.llevar {
                anadir(cosa, simbolo: "bag.fill", color: act.color, de: act.titulo, grupo: grupo)
            }
        }
        let soloHoy = L("Solo este día", "Just this day", "Solo questo giorno")
        for extra in mochilaExtra[Self.clave(dia)] ?? [] {
            anadir(extra, simbolo: "pin.fill", color: nil, de: soloHoy,
                   grupo: GrupoMochila(id: "extra", titulo: soloHoy, simbolo: "pin.fill", color: nil))
        }
        if hayClase(dia) {
            let titulo = L("Todos los días", "Every day", "Tutti i giorni")
            for cosa in siempre {
                anadir(cosa, simbolo: "star.fill", color: nil, de: titulo,
                       grupo: GrupoMochila(id: "siempre", titulo: titulo, simbolo: "star.fill", color: nil))
            }
        }
        return orden.compactMap { items[$0] }
    }

    func marcadas(_ dia: Date) -> Set<String> {
        mochilaMarcada[Self.clave(dia)] ?? []
    }

    func notas(de asignaturaID: UUID) -> [Nota] {
        notas.filter { $0.asignaturaID == asignaturaID }.sorted { $0.fecha < $1.fecha }
    }

    func media(de asignaturaID: UUID) -> Double? {
        let n = notas(de: asignaturaID)
        let pesos = n.reduce(0) { $0 + $1.peso }
        guard pesos > 0 else { return nil }
        return n.reduce(0) { $0 + $1.valor * $1.peso } / pesos
    }

    var mediaGeneral: Double? {
        let medias = asignaturas.compactMap { media(de: $0.id) }
        guard !medias.isEmpty else { return nil }
        return medias.reduce(0, +) / Double(medias.count)
    }
}
