import Foundation

nonisolated struct EventoExterno: Identifiable, Hashable, Sendable {
    enum Origen: String, Sendable { case iphone, teams }

    var id: String

    var uid: String?
    var titulo: String
    var inicio: Date
    var fin: Date
    var todoElDia: Bool
    var lugar = ""
    var notas = ""
    var origen: Origen

    var calendarioID = ""
    var calendario = ""
    var cuenta = ""

    var color = "gris"

    var enlace: String?
}

nonisolated enum FusionCalendarios {

    static func normalizar(_ s: String) -> String {
        let plano = s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "es"))
        var r = ""
        var espacio = false
        for c in plano.unicodeScalars {
            if CharacterSet.alphanumerics.contains(c) {
                if espacio && !r.isEmpty { r.append(" ") }
                r.unicodeScalars.append(c)
                espacio = false
            } else {
                espacio = true
            }
        }
        return r
    }

    static func mismaCita(_ a: EventoExterno, _ b: EventoExterno, cal: Calendar) -> Bool {
        if let ua = a.uid, let ub = b.uid, !ua.isEmpty, ua == ub,
           abs(a.inicio.timeIntervalSince(b.inicio)) < 12 * 3600 {
            return true
        }
        let t = normalizar(a.titulo)
        guard !t.isEmpty, t == normalizar(b.titulo) else { return false }
        if a.todoElDia || b.todoElDia {
            return a.todoElDia == b.todoElDia && cal.isDate(a.inicio, inSameDayAs: b.inicio)
        }
        return abs(a.inicio.timeIntervalSince(b.inicio)) <= 60
    }

    static func fusionar(_ listas: [[EventoExterno]], cal: Calendar) -> [EventoExterno] {
        var r: [EventoExterno] = []
        var porDia: [Int: [Int]] = [:]
        for lista in listas {
            for e in lista {

                let d = clave(e.inicio, cal)
                let cerca = (d - 1...d + 1).flatMap { porDia[$0] ?? [] }
                if cerca.contains(where: { mismaCita(r[$0], e, cal: cal) }) { continue }
                porDia[d, default: []].append(r.count)
                r.append(e)
            }
        }
        return r.sorted { ($0.inicio, $0.titulo) < ($1.inicio, $1.titulo) }
    }

    static func coincide(titulo: String, inicio: Int?, conTitulo otro: String, inicio otroInicio: Int?) -> Bool {
        let t = normalizar(titulo)
        guard !t.isEmpty, t == normalizar(otro) else { return false }
        switch (inicio, otroInicio) {
        case (nil, nil): return true
        case let (a?, b?): return abs(a - b) <= 5
        default: return false
        }
    }

    static func porDias(_ e: EventoExterno, cal: Calendar) -> [(dia: Date, inicio: Int?, fin: Int?)] {
        let primero = cal.startOfDay(for: e.inicio)
        if e.todoElDia {

            let ultimo = cal.startOfDay(for: e.fin.addingTimeInterval(-1))
            return dias(desde: primero, hasta: max(ultimo, primero), cal: cal).map { ($0, nil, nil) }
        }
        let fin = max(e.fin, e.inicio)

        let ultimo = cal.startOfDay(for: fin == e.inicio ? fin : fin.addingTimeInterval(-1))
        let lista = dias(desde: primero, hasta: max(ultimo, primero), cal: cal)
        if lista.count == 1 {
            return [(primero, minutos(e.inicio, cal), max(minutos(fin, cal, finDeDia: true), minutos(e.inicio, cal)))]
        }
        return lista.enumerated().map { i, d in
            if i == 0 { return (d, minutos(e.inicio, cal), 24 * 60 - 1) }
            if i == lista.count - 1 { return (d, 0, minutos(fin, cal, finDeDia: true)) }
            return (d, nil, nil)
        }
    }

    private static func clave(_ f: Date, _ cal: Calendar) -> Int {
        let c = cal.dateComponents([.year, .month, .day], from: f)
        return ((c.year ?? 0) * 12 + (c.month ?? 0)) * 31 + (c.day ?? 0)
    }

    private static func dias(desde a: Date, hasta b: Date, cal: Calendar) -> [Date] {
        var r: [Date] = []
        var d = a

        while d <= b && r.count < 60 {
            r.append(d)
            guard let s = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = s
        }
        return r
    }

    private static func minutos(_ f: Date, _ cal: Calendar, finDeDia: Bool = false) -> Int {
        let c = cal.dateComponents([.hour, .minute], from: f)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)

        return finDeDia && m == 0 ? 24 * 60 - 1 : m
    }
}
