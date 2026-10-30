import Foundation

extension DatosEscolares {

    func tema(_ id: UUID) -> Tema? {
        for p in pruebas { if let t = p.temas.first(where: { $0.id == id }) { return t } }
        return temasDeAhora.first { $0.tema.id == id }?.tema
    }

    mutating func cambiarTema(_ id: UUID, _ cambio: (inout Tema) -> Void) {
        for i in pruebas.indices {
            if let j = pruebas[i].temas.firstIndex(where: { $0.id == id }) { cambio(&pruebas[i].temas[j]); return }
        }
        if let i = temasDeAhora.firstIndex(where: { $0.tema.id == id }) { cambio(&temasDeAhora[i].tema) }
    }

    func prueba(deTema id: UUID) -> Prueba? {
        pruebas.first { $0.temas.contains { $0.id == id } }
    }

    func biblioteca(ahora: Date = Reloj.ahora, conPasadas: Bool = true) -> [Biblioteca.Entrada] {
        Biblioteca.temas(pruebas: pruebas, sueltos: temasDeAhora, ahora: ahora, cal: calendarioActual, conPasadas: conPasadas)
    }

    func asignaturaDeTema(_ id: UUID) -> UUID? {
        prueba(deTema: id)?.asignaturaID ?? temasDeAhora.first { $0.tema.id == id }?.asignaturaID
    }

    @discardableResult
    mutating func apuntarTemaSuelto(id: UUID = UUID(), nombre: String, asignaturaID: UUID?) -> UUID {
        guard tema(id) == nil else { return id }
        var t = Tema(id: id, nombre: nombre.trimmingCharacters(in: .whitespacesAndNewlines))
        t.apuntado = Reloj.ahora
        temasDeAhora.append(TemaDeAhora(asignaturaID: asignaturaID, tema: t))
        return t.id
    }

    mutating func cambiarAsignatura(deTema id: UUID, a asignaturaID: UUID?) {
        if let i = temasDeAhora.firstIndex(where: { $0.tema.id == id }) { temasDeAhora[i].asignaturaID = asignaturaID }
    }

    mutating func borrarTema(_ id: UUID) {
        Biblioteca.borrar(id, pruebas: &pruebas, sueltos: &temasDeAhora)
    }

    mutating func adjuntarTemas(_ ids: [UUID], aPrueba id: UUID) {
        Biblioteca.adjuntar(ids, a: id, pruebas: &pruebas, sueltos: &temasDeAhora)
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

    func porRepasar(ahora: Date = Reloj.ahora) -> [(tema: Tema, asignaturaID: UUID?, costo: Bool)] {
        var r: [(tema: Tema, asignaturaID: UUID?, costo: Bool)] = []
        var vistos = Set<UUID>()
        for p in pruebas.sorted(by: { $0.fecha > $1.fecha }) {
            guard let id = p.sorpresaTemaID, p.fecha < ahora, ahora.timeIntervalSince(p.fecha) < 30 * 86_400,
                  let t = p.temas.first(where: { $0.id == id }), !t.intentos.contains(where: { $0.fecha > p.fecha }) || !t.falladas.isEmpty
            else { continue }
            if vistos.insert(t.id).inserted { r.append((t, p.asignaturaID, true)) }
        }
        for p in pruebas {
            for t in p.temas where !t.falladas.isEmpty && vistos.insert(t.id).inserted { r.append((t, p.asignaturaID, false)) }
        }
        for a in temasDeAhora where !a.tema.falladas.isEmpty && vistos.insert(a.tema.id).inserted { r.append((a.tema, a.asignaturaID, false)) }
        return r
    }

    mutating func apuntarFalladas(_ falladas: [PreguntaFallada], acertadas: Set<String>, enTema id: UUID) {
        func cambiar(_ t: inout Tema) {
            t.falladas.removeAll { acertadas.contains($0.pregunta) }
            for f in falladas where !t.falladas.contains(where: { $0.pregunta == f.pregunta }) { t.falladas.append(f) }
            if t.falladas.count > 30 { t.falladas.removeFirst(t.falladas.count - 30) }
        }
        for i in pruebas.indices {
            if let j = pruebas[i].temas.firstIndex(where: { $0.id == id }) { cambiar(&pruebas[i].temas[j]); return }
        }
        if let i = temasDeAhora.firstIndex(where: { $0.tema.id == id }) { cambiar(&temasDeAhora[i].tema) }
    }

    func planRepaso(ajustes: Ajustes, vacaciones: Set<Date> = [], ahora: Date = Reloj.ahora, dias: Int = 28) -> PlanRepaso {
        let cal = calendarioActual
        let hoy = cal.startOfDay(for: ahora)
        let inicio = cal.startOfDay(for: ajustes.inicioCurso)
        let fin = cal.startOfDay(for: ajustes.finCurso)
        var sinRepaso = Set(vacaciones.map { cal.startOfDay(for: $0) })
        for n in 0..<max(0, dias) {
            if let d = cal.date(byAdding: .day, value: n, to: hoy), d < inicio || d > fin || enVacaciones(d) { sinRepaso.insert(d) }
        }
        var libres: [Date: DiaLibre] = [:]
        for n in 0..<max(0, dias) {
            guard let d = cal.date(byAdding: .day, value: n, to: hoy) else { continue }
            libres[d] = DiaLibre(huecos: huecos(d, ahora: ahora), maximo: Self.maximoDia(lectivo: esLectivo(d)))
        }

        return PlanRepaso.calcular(pruebas: pruebas, temasDeAhora: [], minutosRato: ajustes.minutosRato,
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
        func aligerar(_ t: inout Tema) {
            t.miniaturas = []
            t.charla = []
            t.audio = nil
            for k in t.fuentes.indices { t.fuentes[k].texto = "" }
        }
        for i in d.pruebas.indices {
            for j in d.pruebas[i].temas.indices { aligerar(&d.pruebas[i].temas[j]) }
        }
        for i in d.temasDeAhora.indices { aligerar(&d.temasDeAhora[i].tema) }
        for i in d.pruebasAntiguas.indices { d.pruebasAntiguas[i].miniatura = nil }
        return d
    }

    mutating func recuperarMiniaturas(de local: DatosEscolares) {
        var textos: [UUID: String] = [:]
        var charlas: [UUID: [MensajeCharla]] = [:]
        var audios: [UUID: AudioTema] = [:]
        for t in local.pruebas.flatMap(\.temas) + local.temasDeAhora.map(\.tema) {
            for f in t.fuentes where !f.texto.isEmpty { textos[f.id] = f.texto }
            if !t.charla.isEmpty { charlas[t.id] = t.charla }
            if let a = t.audio { audios[t.id] = a }
        }
        let fotosAntiguas = Dictionary(local.pruebasAntiguas.compactMap { a in a.miniatura.map { (a.id, $0) } }, uniquingKeysWith: { a, _ in a })
        for i in pruebasAntiguas.indices where pruebasAntiguas[i].miniatura == nil { pruebasAntiguas[i].miniatura = fotosAntiguas[pruebasAntiguas[i].id] }
        if !textos.isEmpty || !charlas.isEmpty || !audios.isEmpty {
            func devolver(_ t: inout Tema) {
                for k in t.fuentes.indices where t.fuentes[k].texto.isEmpty { t.fuentes[k].texto = textos[t.fuentes[k].id] ?? "" }
                if t.charla.isEmpty { t.charla = charlas[t.id] ?? [] }
                if t.audio == nil { t.audio = audios[t.id] }
            }
            for i in pruebas.indices { for j in pruebas[i].temas.indices { devolver(&pruebas[i].temas[j]) } }
            for i in temasDeAhora.indices { devolver(&temasDeAhora[i].tema) }
        }
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

extension Tema {

    mutating func prepararFuentes() {
        guard fuentes.isEmpty, !textoLeido.isEmpty || !miniaturas.isEmpty else { return }
        fuentes = [FuenteTema(tipo: miniaturas.isEmpty ? .texto : .fotos, nombre: "", paginas: miniaturas.count, texto: textoLeido)]
    }

    var puedeQuitarFuentes: Bool { fuentes.allSatisfy { !$0.texto.isEmpty } }

    mutating func quitarFuente(_ id: UUID) {
        guard let i = fuentes.firstIndex(where: { $0.id == id }) else { return }
        if fuentes[i].tipo == .fotos {
            let antes = fuentes[..<i].filter { $0.tipo == .fotos }.reduce(0) { $0 + $1.paginas }
            let rango = min(antes, miniaturas.count) ..< min(antes + fuentes[i].paginas, miniaturas.count)
            miniaturas.removeSubrange(rango)
        }
        fuentes.remove(at: i)
    }

    var textoDeFuentes: String { fuentes.map(\.texto).filter { !$0.isEmpty }.joined(separator: "\n\n") }
}
