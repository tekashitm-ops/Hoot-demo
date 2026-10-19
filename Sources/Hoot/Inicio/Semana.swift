import SwiftUI

struct DiaSemana: Identifiable {
    var dia: Date
    var clases: [Clase]
    var actividades: [Actividad]
    var ratos: [Sesion]
    var entregas: [Tarea]
    var examenes: [Tarea]
    var recordatorios: Int
    var lectivo: Bool

    var atrasadas: [Tarea] = []

    var repasos: [SesionRepaso] = []
    var pruebas: [Prueba] = []

    var id: String { DatosEscolares.clave(dia) }

    var carga: Int {
        ratos.reduce(0) { $0 + $1.minutos } + atrasadas.reduce(0) { $0 + Self.minutosPendientes($1) } + repasos.reduce(0) { $0 + $1.minutos }
    }

    static func minutosPendientes(_ t: Tarea) -> Int {
        let e = DatosEscolares.esfuerzo(t)
        return max(1, e.ratos - t.ratosHechos.count) * e.minutos
    }
    var vacio: Bool {
        clases.isEmpty && actividades.isEmpty && ratos.isEmpty && entregas.isEmpty && examenes.isEmpty && recordatorios == 0 && atrasadas.isEmpty
            && repasos.isEmpty && pruebas.isEmpty
    }

    var franja: (inicio: Int, fin: Int)? {
        var tramos = clases.map { ($0.inicio, $0.fin) }
        tramos += actividades.compactMap { a in a.inicio.map { ($0, max(a.fin ?? $0 + 60, $0)) } }
        tramos += ratos.map { ($0.hora, $0.hora + $0.minutos) }
        tramos += repasos.map { ($0.hora, $0.hora + $0.minutos) }
        guard let inicio = tramos.map(\.0).min(), let fin = tramos.map(\.1).max() else { return nil }
        return (inicio, fin)
    }

    static func semana(_ datos: DatosEscolares, repaso: PlanRepaso, ahora: Date, desde: Date? = nil) -> [DiaSemana] {
        let cal = calendarioActual
        let hoy = cal.startOfDay(for: ahora)
        let inicio = cal.startOfDay(for: desde ?? hoy)
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: inicio) }.map { d in
            DiaSemana(
                dia: d,
                clases: datos.clases(en: d),
                actividades: datos.actividades(en: d),
                ratos: [],
                entregas: [],
                examenes: [],
                recordatorios: datos.recordatorios(en: d).filter { !$0.hecho }.count,
                lectivo: datos.esLectivo(d),
                repasos: repaso.sesiones(en: d, cal: cal),
                pruebas: datos.pruebas.filter { cal.isDate($0.fecha, inSameDayAs: d) }.sorted { $0.fecha < $1.fecha }
            )
        }
    }

    static func lunes(de ahora: Date) -> Date {
        let hoy = calendarioActual.startOfDay(for: ahora)
        return calendarioActual.date(byAdding: .day, value: 1 - DatosEscolares.diaISO(hoy), to: hoy) ?? hoy
    }

    func nombre(ahora: Date) -> String {
        let cal = calendarioActual
        if cal.isDate(dia, inSameDayAs: ahora) { return L("Hoy", "Today", "Oggi") }
        return Formato.nombreDia(iso: DatosEscolares.diaISO(dia)).conMayuscula
    }

    func resumen(_ datos: DatosEscolares) -> String {
        var partes: [String] = [Formato.diaLargo(dia)]
        for p in pruebas {
            let nombre = datos.asignatura(p.asignaturaID)?.nombre ?? p.tipo.nombre
            partes.append(L("prueba de \(nombre)", "\(nombre) test", "verifica di \(nombre)"))
        }
        if let p = clases.first, let u = clases.last { partes.append(L("clases de \(Formato.hora(p.inicio)) a \(Formato.hora(u.fin))", "classes \(Formato.hora(p.inicio))–\(Formato.hora(u.fin))", "lezioni dalle \(Formato.hora(p.inicio)) alle \(Formato.hora(u.fin))")) }
        for a in actividades { partes.append(a.titulo) }
        if carga > 0 { partes.append(L("\(Formato.duracion(minutos: carga)) de repaso", "\(Formato.duracion(minutos: carga)) of review", "\(Formato.duracion(minutos: carga)) di ripasso")) }
        if !entregas.isEmpty { partes.append(L("\(entregas.count) entregas", "\(entregas.count) due", "\(entregas.count) consegne")) }
        return partes.joined(separator: ", ")
    }
}

struct CosaSemana: Identifiable {
    enum Peso: Int, Comparable {
        case rato, actividad, deberes, trabajo, examen

        static func < (a: Peso, b: Peso) -> Bool { a.rawValue < b.rawValue }
    }

    var id: String
    var peso: Peso
    var titulo: String
    var detalle: String

    var hora: Int?
    var color: ColorHoot
    var simbolo: String
    var tareaID: UUID?
}

extension DiaSemana {

    func cosas(_ datos: DatosEscolares) -> [CosaSemana] {
        var r: [CosaSemana] = []
        for p in pruebas {
            let a = datos.asignatura(p.asignaturaID)
            let nombre = a?.nombre ?? p.tipo.nombre
            r.append(CosaSemana(id: "p\(p.id)", peso: .examen, titulo: "\(nombre) · \(p.tipo.nombre)",
                                detalle: p.temas.map(\.nombre).joined(separator: ", "), hora: DatosEscolares.minutos(p.fecha),
                                color: a?.color ?? .indigo, simbolo: "moonphase.first.quarter", tareaID: nil))
        }
        for s in repasos {
            let temas = s.temaIDs.compactMap { datos.tema($0) }
            let a = datos.prueba(deTema: s.temaIDs.first ?? UUID()).flatMap { datos.asignatura($0.asignaturaID) }
            r.append(CosaSemana(id: "r\(s.id)", peso: .rato,
                                titulo: L("Repaso: \(temas.map(\.nombre).joined(separator: ", "))", "Review: \(temas.map(\.nombre).joined(separator: ", "))",
                                          "Ripasso: \(temas.map(\.nombre).joined(separator: ", "))"),
                                detalle: Formato.duracion(minutos: s.minutos), hora: s.hora, color: a?.color ?? .indigo,
                                simbolo: "book.fill", tareaID: nil))
        }
        for t in examenes {
            let a = datos.asignatura(t.asignaturaID)
            let nombre = a?.nombre ?? t.titulo
            r.append(CosaSemana(id: "e\(t.id)", peso: .examen,
                                titulo: L("Examen de \(nombre)", "\(nombre) test", "Verifica di \(nombre)"),
                                detalle: t.temas, hora: DatosEscolares.minutos(t.entrega), color: a?.color ?? .rojo,
                                simbolo: TipoTarea.examen.simbolo, tareaID: t.id))
        }
        for t in entregas {
            let a = datos.asignatura(t.asignaturaID)
            r.append(CosaSemana(id: "t\(t.id)", peso: t.tipo == .trabajo ? .trabajo : .deberes, titulo: t.titulo,
                                detalle: a?.nombre ?? "", hora: nil, color: a?.color ?? .indigo, simbolo: t.tipo.simbolo, tareaID: t.id))
        }
        for a in actividades {
            r.append(CosaSemana(id: "a\(a.id)", peso: .actividad, titulo: a.titulo, detalle: a.lugar, hora: a.inicio,
                                color: a.color, simbolo: a.simbolo, tareaID: nil))
        }

        let yaEstan = Set((examenes + entregas).map(\.id))
        for (id, sesiones) in Dictionary(grouping: ratos.filter { !yaEstan.contains($0.tareaID) }, by: \.tareaID) {
            guard let t = datos.tareas.first(where: { $0.id == id }) else { continue }
            let a = datos.asignatura(t.asignaturaID)
            let minutos = sesiones.reduce(0) { $0 + $1.minutos }
            r.append(CosaSemana(id: "s\(id)", peso: .rato, titulo: t.tituloRato(a), detalle: Formato.duracion(minutos: minutos),
                                hora: sesiones.map(\.hora).min(), color: a?.color ?? .indigo, simbolo: t.tipo.simbolo, tareaID: t.id))
        }
        return r.sorted { a, b in a.peso != b.peso ? a.peso > b.peso : ((a.hora ?? 0), a.id) < ((b.hora ?? 0), b.id) }
    }

    func titulo(ahora: Date) -> String {
        let cal = calendarioActual
        if cal.isDate(dia, inSameDayAs: ahora) { return L("Hoy", "Today", "Oggi") }
        if let m = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: ahora)), cal.isDate(dia, inSameDayAs: m) {
            return L("Mañana", "Tomorrow", "Domani")
        }
        return Formato.diaSemana(dia).conMayuscula + " " + String(cal.component(.day, from: dia))
    }
}
