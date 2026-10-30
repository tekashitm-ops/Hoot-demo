import Foundation
import FoundationModels

struct BorradorPrueba: Equatable {
    var asignaturaID: UUID?
    var tipo: TipoPrueba = .escrita
    var fecha: Date?
    var temas: [String] = []

    var texto = ""
}

enum LectorDiario {
    static func leer(_ texto: String, asignaturas: [Asignatura], ahora: Date = Reloj.ahora) async -> BorradorPrueba {
        var b = interpretar(texto, asignaturas: asignaturas, ahora: ahora)
        guard DisponibilidadIA.actual == .lista, texto.count > 6 else { return b }
        if let ia = try? await conIA(texto, asignaturas: asignaturas, ahora: ahora) {
            b.asignaturaID = ia.asignaturaID ?? b.asignaturaID
            if ia.tipo == .oral { b.tipo = .oral }
            b.fecha = ia.fecha ?? b.fecha
            if !ia.temas.isEmpty { b.temas = ia.temas }
        }
        return b
    }

    static func interpretar(_ texto: String, asignaturas: [Asignatura], ahora: Date) -> BorradorPrueba {
        var b = BorradorPrueba(texto: texto)
        let plano = plegar(texto)

        var mejor: (id: UUID, largo: Int)?
        for a in asignaturas {
            let nombre = plegar(a.nombre)
            let primera = nombre.split(separator: " ").first.map(String.init) ?? nombre
            for candidato in Set([nombre, primera]) where candidato.count >= 4 && plano.contains(candidato) {
                if candidato.count > (mejor?.largo ?? 0) { mejor = (a.id, candidato.count) }
            }
        }
        b.asignaturaID = mejor?.id
        if ["oral", "interrogazion", "interroga", "exposicion", "orale"].contains(where: { plano.contains($0) }) { b.tipo = .oral }

        let cabecera = plano.split(separator: ":", maxSplits: 1).first.map(String.init) ?? plano
        b.fecha = fecha(en: cabecera, ahora: ahora)
        b.temas = temas(en: texto)
        return b
    }

    static func temas(en texto: String) -> [String] {
        let lineas = texto.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        for (i, linea) in lineas.enumerated() {
            guard let r = linea.range(of: ":") else { continue }
            let resto = linea[r.upperBound...].trimmingCharacters(in: .whitespaces)
            let fuente = resto.isEmpty ? (lineas.indices.contains(i + 1) ? lineas[i + 1] : "") : resto
            let nombres = Prueba.nombresDeTemas(fuente).map(FrasesHoot.mayusculaInicial)
            if !nombres.isEmpty { return nombres }
        }
        return []
    }

    static func fecha(en plano: String, ahora: Date) -> Date? {
        let cal = calendarioActual
        let hoy = cal.startOfDay(for: ahora)
        let palabras = plano.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "/" && $0 != "-" }).map(String.init)

        for p in palabras {
            let partes = p.split(whereSeparator: { $0 == "/" || $0 == "-" }).compactMap { Int($0) }
            if partes.count >= 2, (1...31).contains(partes[0]), (1...12).contains(partes[1]) {
                var c = cal.dateComponents([.year], from: hoy)
                c.month = partes[1]
                c.day = partes[0]
                if let d = cal.date(from: c) {
                    return d < hoy ? cal.date(byAdding: .year, value: 1, to: d) : d
                }
            }
        }

        if let n = palabras.compactMap({ Int($0) }).first(where: { (1...31).contains($0) }) {
            for k in 0..<62 {
                guard let d = cal.date(byAdding: .day, value: k, to: hoy) else { continue }
                if cal.component(.day, from: d) == n { return d }
            }
        }

        let dias: [(String, Int)] = [("lun", 2), ("mar", 3), ("mie", 4), ("mer", 4), ("jue", 5), ("gio", 5), ("vie", 6), ("ven", 6),
                                     ("sab", 7), ("dom", 1), ("mon", 2), ("tue", 3), ("wed", 4), ("thu", 5), ("fri", 6)]
        for p in palabras {
            guard let (_, dia) = dias.first(where: { p.hasPrefix($0.0) && p.count <= 9 }) else { continue }
            for k in 1...7 {
                if let d = cal.date(byAdding: .day, value: k, to: hoy), cal.component(.weekday, from: d) == dia { return d }
            }
        }
        return nil
    }

    private static func plegar(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func conIA(_ texto: String, asignaturas: [Asignatura], ahora: Date) async throws -> BorradorPrueba {
        let nombres = asignaturas.map(\.nombre)
        let ninguna = L("ninguna", "none", "nessuna")
        let raiz = DynamicGenerationSchema(name: "Nota", properties: [
            .init(name: "asignatura", description: L("La asignatura de la prueba", "The test's subject", "La materia della verifica"),
                  schema: .init(name: "Asignatura", anyOf: nombres + [ninguna])),
            .init(name: "tipo", description: L("oral si es una exposición o la preguntan en voz alta; si no, escrita",
                                                "oral if it's a presentation or asked out loud; otherwise written",
                                                "orale se è un'interrogazione; altrimenti scritta"),
                  schema: .init(name: "Tipo", anyOf: ["escrita", "oral"])),
            .init(name: "dia", description: L("El número del día del mes de la prueba, o 0 si no lo dice",
                                               "The day of the month of the test, or 0 if not given",
                                               "Il giorno del mese della verifica, o 0 se non c'è"),
                  schema: .init(type: Int.self)),
            .init(name: "temas", description: L("Los temas que entran, tal como están escritos. Sin inventar.",
                                                 "The topics covered, as written. Don't invent any.",
                                                 "Gli argomenti che entrano, come sono scritti. Senza inventare."),
                  schema: .init(arrayOf: .init(type: String.self), minimumElements: 0, maximumElements: 12)),
        ])
        let esquema = try GenerationSchema(root: raiz, dependencies: [])
        let r = try await MotorIA.conForma(.diario,
                                           instrucciones: L("Lees lo que un alumno apuntó en su diario del colegio sobre una prueba.",
                                                            "You read what a student wrote in their school planner about a test.",
                                                            "Leggi quello che uno studente ha scritto sul diario a proposito di una verifica."),
                                           prompt: String(texto.prefix(1500)), esquema: esquema, maximo: 300, temperatura: 0)
        var b = BorradorPrueba(texto: texto)
        if let a = try? r.value(String.self, forProperty: "asignatura") {
            b.asignaturaID = asignaturas.first { $0.nombre == a }?.id
        }
        if (try? r.value(String.self, forProperty: "tipo")) == "oral" { b.tipo = .oral }
        if let n = try? r.value(Int.self, forProperty: "dia"), (1...31).contains(n) {
            b.fecha = fecha(en: String(n), ahora: ahora)
        }
        if let t = try? r.value([String].self, forProperty: "temas") {
            b.temas = Prueba.nombresDeTemas(t.joined(separator: "\n")).map(FrasesHoot.mayusculaInicial)
        }
        return b
    }
}
