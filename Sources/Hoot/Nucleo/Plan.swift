import Foundation

struct Sesion: Identifiable, Hashable {
    var id: String
    var tareaID: UUID

    var dia: Date

    var hora: Int
    var minutos: Int

    var numero: Int
    var total: Int
}

struct PlanTarea: Hashable {

    var empezar: Date
    var sesiones: [Sesion]

    var justa: Bool
}

struct PlanEstudio {
    var sesiones: [Sesion] = []
    var porTarea: [UUID: PlanTarea] = [:]

    func sesiones(en dia: Date) -> [Sesion] {
        let cal = calendarioActual
        return sesiones.filter { cal.isDate($0.dia, inSameDayAs: dia) }.sorted { $0.hora < $1.hora }
    }

    func empezar(_ tareaID: UUID) -> PlanTarea? { porTarea[tareaID] }
}

extension DatosEscolares {

    static func esfuerzo(_ t: Tarea) -> (ratos: Int, minutos: Int) {
        switch t.tipo {
        case .deberes: (1, 30)
        case .trabajo: (3, 45)
        case .examen: (4, 45)
        }
    }

    static func maximoDia(lectivo: Bool) -> Int { lectivo ? 120 : 150 }

    static let finTarde = 20 * 60 + 30

    func huecos(_ dia: Date, ahora: Date = Reloj.ahora) -> [Hueco] {
        let cal = calendarioActual
        var inicio: Int
        if let ultima = clases(en: dia).last {
            inicio = ultima.fin + 60
        } else {
            inicio = esLectivo(dia) ? 16 * 60 : 10 * 60
        }
        if cal.isDate(dia, inSameDayAs: ahora) {

            let desde = Self.minutos(ahora) + 10
            inicio = max(inicio, ((desde + 14) / 15) * 15)
        }
        let fin = Self.finTarde
        guard fin - inicio >= 15 else { return [] }
        var ocupado: [(Int, Int)] = []
        for a in actividades where ocurre(a, en: dia) {
            guard let i = a.inicio else { return [] }
            ocupado.append((i - 20, (a.fin ?? i + 60) + 20))
        }

        for c in delCalendario where c.inicio != nil && ocurre(c, en: dia) {
            let i = c.inicio ?? 0
            ocupado.append((i - 20, (c.fin ?? i + 60) + 20))
        }
        ocupado.sort { $0.0 < $1.0 }
        var huecos: [Hueco] = []
        var cursor = inicio
        for (a, b) in ocupado {
            if a > cursor { huecos.append(Hueco(inicio: cursor, fin: min(a, fin))) }
            cursor = max(cursor, b)
            if cursor >= fin { break }
        }
        if cursor < fin { huecos.append(Hueco(inicio: cursor, fin: fin)) }
        return huecos.filter { $0.duracion >= 15 }
    }

    func minutosLibres(_ dia: Date, ahora: Date = Reloj.ahora) -> Int {
        min(huecos(dia, ahora: ahora).reduce(0) { $0 + $1.duracion }, Self.maximoDia(lectivo: esLectivo(dia)))
    }

    private func ultimoDia(_ t: Tarea) -> Date {
        let cal = calendarioActual
        let diaEntrega = cal.startOfDay(for: t.entrega)
        var ultimo = Self.minutos(t.entrega) >= 18 * 60 && t.tipo == .deberes
            ? diaEntrega
            : (cal.date(byAdding: .day, value: -1, to: diaEntrega) ?? diaEntrega)
        if t.tipo == .trabajo {
            ultimo = cal.date(byAdding: .day, value: -1, to: ultimo) ?? ultimo
        }
        return ultimo
    }

    func plan(ahora: Date = Reloj.ahora, dias: Int = 28) -> PlanEstudio {
        let cal = calendarioActual
        let hoy = cal.startOfDay(for: ahora)
        let lista = (0..<dias).compactMap { cal.date(byAdding: .day, value: $0, to: hoy) }
        var libre: [String: Int] = [:]
        for d in lista { libre[Self.clave(d)] = minutosLibres(d, ahora: ahora) }

        let pendientes = tareas
            .filter { !$0.hecha && $0.entrega > ahora }
            .sorted { $0.entrega > $1.entrega }

        var plan = PlanEstudio()
        var porDia: [String: [(UUID, Int, Int, Int)]] = [:]

        for t in pendientes {
            let (todos, minutos) = Self.esfuerzo(t)

            let ratos = max(0, todos - t.ratosHechos.count)
            guard ratos > 0 else { continue }
            let hechoHoy = t.ratosHechos.contains { cal.isDate($0, inSameDayAs: hoy) }
            let primero = hechoHoy ? (cal.date(byAdding: .day, value: 1, to: hoy) ?? hoy) : hoy
            let ultimo = max(primero, ultimoDia(t))

            var candidatos = lista.filter { $0 >= primero && $0 <= ultimo }.reversed().map { $0 }
            if candidatos.isEmpty { candidatos = [primero] }
            var elegidos: [Date] = []

            for d in candidatos where elegidos.count < ratos {
                let k = Self.clave(d)
                if (libre[k] ?? 0) >= minutos {
                    elegidos.append(d)
                    libre[k, default: 0] -= minutos
                }
            }

            for d in candidatos where elegidos.count < ratos {
                let k = Self.clave(d)
                while elegidos.count < ratos && (libre[k] ?? 0) >= minutos {
                    elegidos.append(d)
                    libre[k, default: 0] -= minutos
                }
            }

            let justa = elegidos.count < ratos
            var faltan = ratos - elegidos.count
            let conTarde = candidatos.reversed().filter { !huecos($0, ahora: ahora).isEmpty }
            var i = 0
            while faltan > 0 {
                let d = conTarde.isEmpty ? primero : conTarde[i % conTarde.count]
                elegidos.append(d)
                libre[Self.clave(d), default: 0] -= minutos
                faltan -= 1
                i += 1
            }
            elegidos.sort()
            for (n, d) in elegidos.enumerated() {
                porDia[Self.clave(d), default: []].append((t.id, minutos, t.ratosHechos.count + n + 1, todos))
            }
            plan.porTarea[t.id] = PlanTarea(empezar: elegidos.first ?? primero, sesiones: [], justa: justa)
        }

        let entrega = Dictionary(uniqueKeysWithValues: tareas.map { ($0.id, $0.entrega) })
        for d in lista {
            let k = Self.clave(d)
            guard var ratos = porDia[k], !ratos.isEmpty else { continue }
            ratos.sort { (entrega[$0.0] ?? .distantFuture) < (entrega[$1.0] ?? .distantFuture) }
            var huecosDia = huecos(d, ahora: ahora)
            var siguiente = huecosDia.first?.inicio ?? 17 * 60
            for (id, minutos, numero, total) in ratos {
                var hora = siguiente
                if let i = huecosDia.firstIndex(where: { $0.duracion >= minutos }) {
                    hora = huecosDia[i].inicio
                    huecosDia[i].inicio += minutos + 15
                    if huecosDia[i].duracion < 15 { huecosDia.remove(at: i) }
                }
                siguiente = hora + minutos + 15
                let s = Sesion(id: "\(id)-\(numero)", tareaID: id, dia: d, hora: hora, minutos: minutos, numero: numero, total: total)
                plan.sesiones.append(s)
                plan.porTarea[id]?.sesiones.append(s)
            }
        }
        for (id, p) in plan.porTarea {
            plan.porTarea[id]?.sesiones = p.sesiones.sorted { ($0.dia, $0.hora) < ($1.dia, $1.hora) }
        }
        return plan
    }
}
