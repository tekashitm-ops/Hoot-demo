import Foundation

extension DatosEscolares {

    func tema(_ id: UUID) -> Tema? {
        for p in pruebas { if let t = p.temas.first(where: { $0.id == id }) { return t } }
        return temasDeAhora.first { $0.tema.id == id }?.tema
    }

    func prueba(deTema id: UUID) -> Prueba? {
        pruebas.first { $0.temas.contains { $0.id == id } }
    }

    mutating func apuntar(_ intento: Intento, enTema id: UUID) {
        for i in pruebas.indices {
            if let j = pruebas[i].temas.firstIndex(where: { $0.id == id }) {
                pruebas[i].temas[j].intentos.append(intento)
                return
            }
        }
        if let i = temasDeAhora.firstIndex(where: { $0.tema.id == id }) {
            temasDeAhora[i].tema.intentos.append(intento)
        }
    }

    func planRepaso(ajustes: Ajustes, vacaciones: Set<Date> = [], ahora: Date = Reloj.ahora, dias: Int = 28) -> PlanRepaso {
        let cal = calendarioActual
        let hoy = cal.startOfDay(for: ahora)
        let inicio = cal.startOfDay(for: ajustes.inicioCurso)
        let fin = cal.startOfDay(for: ajustes.finCurso)
        var sinRepaso = Set(vacaciones.map { cal.startOfDay(for: $0) })
        for n in 0..<max(0, dias) {
            if let d = cal.date(byAdding: .day, value: n, to: hoy), d < inicio || d > fin { sinRepaso.insert(d) }
        }
        var libres: [Date: DiaLibre] = [:]
        for n in 0..<max(0, dias) {
            guard let d = cal.date(byAdding: .day, value: n, to: hoy) else { continue }
            libres[d] = DiaLibre(huecos: huecos(d, ahora: ahora), maximo: Self.maximoDia(lectivo: esLectivo(d)))
        }
        return PlanRepaso.calcular(pruebas: pruebas, temasDeAhora: temasDeAhora, minutosRato: ajustes.minutosRato,
                                   sinRepaso: sinRepaso, ahora: ahora, cal: cal, dias: dias) { d in
            libres[cal.startOfDay(for: d)] ?? DiaLibre(huecos: [], maximo: 0)
        }
    }

    @discardableResult
    mutating func pasarExamenesAPruebas() -> Bool {
        guard !examenesEnPruebas else { return false }
        examenesEnPruebas = true
        let ya = Set(pruebas.map(\.id))
        for t in tareas where t.tipo == .examen && !ya.contains(t.id) {
            var nombres = Prueba.nombresDeTemas(t.temas)
            if nombres.isEmpty {
                let titulo = t.titulo.trimmingCharacters(in: .whitespacesAndNewlines)
                nombres = [titulo.isEmpty ? (asignatura(t.asignaturaID)?.nombre ?? L("Tema", "Topic", "Argomento")) : titulo]
            }
            let temas = nombres.enumerated().map { n, nombre in Tema(id: .derivado(de: t.id, n), nombre: nombre) }
            pruebas.append(Prueba(id: t.id, asignaturaID: t.asignaturaID, tipo: .escrita, fecha: t.entrega, temas: temas,
                                  deFamilia: t.origen == .familia, notas: t.notas))
        }
        return true
    }

    var sinMiniaturas: DatosEscolares {
        var d = self
        for i in d.pruebas.indices {
            for j in d.pruebas[i].temas.indices { d.pruebas[i].temas[j].miniaturas = [] }
        }
        for i in d.temasDeAhora.indices { d.temasDeAhora[i].tema.miniaturas = [] }
        return d
    }

    mutating func recuperarMiniaturas(de local: DatosEscolares) {
        var guardadas: [UUID: [Data]] = [:]
        for p in local.pruebas { for t in p.temas where !t.miniaturas.isEmpty { guardadas[t.id] = t.miniaturas } }
        for a in local.temasDeAhora where !a.tema.miniaturas.isEmpty { guardadas[a.tema.id] = a.tema.miniaturas }
        guard !guardadas.isEmpty else { return }
        for i in pruebas.indices {
            for j in pruebas[i].temas.indices where pruebas[i].temas[j].miniaturas.isEmpty {
                if let m = guardadas[pruebas[i].temas[j].id] { pruebas[i].temas[j].miniaturas = m }
            }
        }
        for i in temasDeAhora.indices where temasDeAhora[i].tema.miniaturas.isEmpty {
            if let m = guardadas[temasDeAhora[i].tema.id] { temasDeAhora[i].tema.miniaturas = m }
        }
    }
}
