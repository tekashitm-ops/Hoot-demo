import SwiftUI
import FoundationModels

enum Veredicto: String, Codable, CaseIterable, Sendable {

    case correcta

    case ampliable

    case consejo

    case incompleta

    case incorrecta

    var fallada: Bool { self == .incompleta || self == .incorrecta }

    var titulo: String {
        switch self {
        case .correcta: L("Correcta", "Correct", "Corretta")
        case .ampliable: L("Bien, y puedes añadir más", "Good, and you can add more", "Bene, e puoi aggiungere altro")
        case .consejo: L("Bien. Un consejo para explicarlo", "Good. A tip to explain it", "Bene. Un consiglio per spiegarla")
        case .incompleta: L("Le falta información", "Something's missing", "Manca qualcosa")
        case .incorrecta: L("No es correcta", "Not correct", "Non è corretta")
        }
    }

    var simbolo: String {
        switch self {
        case .correcta: "checkmark.circle.fill"
        case .ampliable: "plus.circle.fill"
        case .consejo: "lightbulb.fill"
        case .incompleta: "circle.lefthalf.filled"
        case .incorrecta: "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .correcta, .ampliable, .consejo: .hecho
        case .incompleta: .pronto
        case .incorrecta: .urgente
        }
    }
}

struct PreguntaPrueba: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var pregunta: String

    var esperada: String
    var respuesta = ""
    var veredicto: Veredicto?

    var nota: Double?
    var comentario = ""

    var consejo = ""

    var temaID: UUID?

    var seguridad: Seguridad?
}

struct PruebaGuardada: Codable, Hashable, Sendable {
    var preguntas: [PreguntaPrueba]

    var nota: Double? {
        let notas = preguntas.compactMap(\.nota)
        return notas.isEmpty ? nil : notas.reduce(0, +) / Double(notas.count)
    }
}

extension EscalaNotas {

    func desdeDiez(_ n: Double) -> Double {
        let p = max(0, min(1, n / 10))
        let v = mayorEsMejor ? minimo + p * (maximo - minimo) : maximo - p * (maximo - minimo)
        return (v / paso).rounded() * paso
    }
}

@Observable
final class PruebaIA: Hashable {
    nonisolated static func == (a: PruebaIA, b: PruebaIA) -> Bool { a === b }
    nonisolated func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }

    enum Fase: Equatable {
        case leyendo(Int, Int)
        case preparando
        case preguntando
        case corrigiendo
        case terminada
        case error(String)
    }

    var fase: Fase = .preparando
    var preguntas: [PreguntaPrueba] = []
    var actual = 0

    var material = ""

    var anteriores: [String] = []
    var asignatura: String?
    var curso = ""
    var tema = ""

    var cuantas = 5

    var borrador = ""

    var modo: ModoPrueba = .oral

    var materiales: [UUID: String] = [:]
    var nombresTemas: [UUID: String] = [:]

    var faseInicial: [UUID: FaseLuna] = [:]
    var mezclado = false
    var conSeguridad = false
    var porTema = FaseLuna.minimoRespuestas

    var esRepaso: Bool { !materiales.isEmpty }

    @ObservationIgnored private var tarea: Task<Void, Never>?
    @ObservationIgnored private var vigilante: Task<Void, Never>?

    private func vigilar(_ segundos: Double) {
        vigilante?.cancel()
        vigilante = Task { [weak self] in
            try? await Task.sleep(for: .seconds(segundos))
            guard let self, !Task.isCancelled else { return }
            self.fase = .error(L("Está tardando demasiado. Inténtalo otra vez, con menos fotos si son muchas.",
                                 "It's taking too long. Try again, with fewer photos if there are many.",
                                 "Ci sta mettendo troppo. Riprova, con meno foto se sono tante."))
            self.tarea?.cancel()
        }
    }

    var pregunta: PreguntaPrueba? { preguntas.indices.contains(actual) ? preguntas[actual] : nil }
    var corregida: Bool { pregunta?.veredicto != nil }
    var guardada: PruebaGuardada { PruebaGuardada(preguntas: preguntas) }
    var falladas: [PreguntaPrueba] { preguntas.filter { $0.veredicto?.fallada == true } }

    var fallida: Bool {
        if case .error = fase { return true }
        return false
    }

    func cancelar() {
        tarea?.cancel()
        vigilante?.cancel()
    }

    func empezar(imagenes: [UIImage], escrito: String) {
        tarea?.cancel()
        tarea = Task { [weak self] in
            guard let self else { return }
            do {
                let texto = try await TrabajoIA.leer(imagenes, escrito: escrito) { i, n in self.fase = .leyendo(i, n) }
                guard texto.count > 20 else {
                    self.fase = .error(L("No se lee texto en las fotos. Prueba con más luz y la hoja entera.", "No text found in the photos. Try with more light and the whole page.", "Nessun testo nelle foto. Riprova con più luce e la pagina intera."))
                    return
                }
                self.material = texto
                try await self.preparar()
            } catch is CancellationError {
                return
            } catch let e as LanguageModelSession.GenerationError {
                self.fase = .error(TrabajoIA.mensaje(e))
            } catch {
                self.fase = .error(L("No se ha podido preparar la prueba. Inténtalo otra vez.", "Couldn't prepare the test. Please try again.", "Non è stato possibile preparare la verifica. Riprova."))
            }
        }
    }

    func empezar(temas: [Tema], fases: [UUID: FaseLuna], mezclar: Bool) {
        materiales = Dictionary(uniqueKeysWithValues: temas.map { ($0.id, $0.textoLeido) })
        nombresTemas = Dictionary(uniqueKeysWithValues: temas.map { ($0.id, $0.nombre) })
        faseInicial = fases
        mezclado = mezclar
        conSeguridad = true
        tema = temas.map(\.nombre).joined(separator: ", ")
        material = temas.map(\.textoLeido).joined(separator: "\n\n")
        prepararRepaso()
    }

    private func prepararRepaso() {
        tarea?.cancel()
        tarea = Task { [weak self] in
            guard let self else { return }
            guard DisponibilidadIA.actual == .lista else {
                self.fase = .error(DisponibilidadIA.actual.mensaje)
                return
            }
            self.fase = .preparando
            do {
                var porTema: [[PreguntaPrueba]] = []
                for (id, texto) in self.materiales.sorted(by: { (self.nombresTemas[$0.key] ?? "") < (self.nombresTemas[$1.key] ?? "") }) {
                    let ajustado = try await TrabajoIA.ajustar(texto, maximo: TrabajoIA.caracteresMaximos - 2500)
                    var nuevas = try await self.generar(ajustado, cuantas: self.porTema, sobre: self.nombresTemas[id] ?? "")
                    for i in nuevas.indices { nuevas[i].temaID = id }
                    porTema.append(nuevas)
                }
                try Task.checkCancellation()

                var lista: [PreguntaPrueba] = []
                if self.mezclado {
                    for n in 0..<(porTema.map(\.count).max() ?? 0) {
                        for grupo in porTema where grupo.indices.contains(n) { lista.append(grupo[n]) }
                    }
                } else {
                    lista = porTema.flatMap { $0 }
                }
                guard !lista.isEmpty else {
                    self.fase = .error(L("No se han podido sacar preguntas de estas fotos.", "Couldn't make questions from these photos.",
                                         "Non è stato possibile fare domande da queste foto."))
                    return
                }
                conMuelle {
                    self.preguntas = lista
                    self.actual = 0
                    self.fase = .preguntando
                }
            } catch is CancellationError {
                return
            } catch let e as LanguageModelSession.GenerationError {
                self.fase = .error(TrabajoIA.mensaje(e))
            } catch {
                self.fase = .error(L("No se ha podido preparar el repaso. Inténtalo otra vez.", "Couldn't prepare the review. Please try again.",
                                     "Non è stato possibile preparare il ripasso. Riprova."))
            }
        }
    }

    func intentos(fecha: Date = Reloj.ahora) -> [UUID: Intento] {
        var r: [UUID: Intento] = [:]
        for q in preguntas {
            guard let id = q.temaID, let v = q.veredicto else { continue }
            r[id, default: Intento(fecha: fecha, mezclado: mezclado)].respuestas.append(Respuesta(acierto: !v.fallada, seguridad: q.seguridad))
        }
        return r
    }

    func parteEnVivo(_ id: UUID) -> Double {
        let base = faseInicial[id]?.fraccion ?? 0
        guard base < 1 else { return 1 }
        let aciertos = preguntas.filter { $0.temaID == id && $0.veredicto.map { !$0.fallada } == true }.count
        return min(1, base + 0.25 * min(Double(aciertos) / Double(max(porTema, 1)), 1))
    }

    func nuevaPrueba() {
        anteriores += preguntas.map(\.pregunta)
        preguntas = []
        actual = 0
        if esRepaso {
            prepararRepaso()
            return
        }
        tarea?.cancel()
        tarea = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.preparar()
            } catch is CancellationError {
                return
            } catch let e as LanguageModelSession.GenerationError {
                self.fase = .error(TrabajoIA.mensaje(e))
            } catch {
                self.fase = .error(L("No se ha podido preparar la prueba. Inténtalo otra vez.", "Couldn't prepare the test. Please try again.", "Non è stato possibile preparare la verifica. Riprova."))
            }
        }
    }

    private func preparar() async throws {
        guard DisponibilidadIA.actual == .lista else {
            fase = .error(DisponibilidadIA.actual.mensaje)
            return
        }
        fase = .preparando
        let texto = try await TrabajoIA.ajustar(material, maximo: TrabajoIA.caracteresMaximos - 2500)
        let nuevas = try await generar(texto, cuantas: cuantas, sobre: tema)
        guard !nuevas.isEmpty else {
            fase = .error(L("No se han podido sacar preguntas de este texto.", "Couldn't make questions from this text.", "Non è stato possibile fare domande da questo testo."))
            return
        }
        conMuelle {
            preguntas = nuevas
            actual = 0
            fase = .preguntando
        }
    }

    private func generar(_ texto: String, cuantas: Int, sobre tema: String) async throws -> [PreguntaPrueba] {
        let pregunta = DynamicGenerationSchema(name: "Pregunta", properties: [
            .init(name: "pregunta", description: L("La pregunta, en una frase", "The question, in one sentence", "La domanda, in una frase"), schema: .init(type: String.self)),
            .init(name: "respuesta", description: L("La respuesta que se espera, breve y con los datos clave", "The expected answer, short, with the key facts", "La risposta attesa, breve e con i dati chiave"), schema: .init(type: String.self)),
        ])
        let raiz = DynamicGenerationSchema(name: "Prueba", properties: [
            .init(name: "preguntas", schema: .init(arrayOf: .init(referenceTo: "Pregunta"), minimumElements: cuantas, maximumElements: cuantas)),
        ])
        let esquema = try GenerationSchema(root: raiz, dependencies: [pregunta])
        let sesion = LanguageModelSession(model: SystemLanguageModel(guardrails: .permissiveContentTransformations), instructions: instrucciones)
        vigilar(120)
        let r = try await sesion.respond(to: peticionPreguntas(texto, cuantas: cuantas, sobre: tema), schema: esquema,
                                         options: GenerationOptions(temperature: 0.8, maximumResponseTokens: 800))
        vigilante?.cancel()
        try Task.checkCancellation()
        let lista = try r.content.value([GeneratedContent].self, forProperty: "preguntas")
        return lista.compactMap { c -> PreguntaPrueba? in
            guard let p = try? c.value(String.self, forProperty: "pregunta"),
                  let e = try? c.value(String.self, forProperty: "respuesta"),
                  !p.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return PreguntaPrueba(pregunta: p.trimmingCharacters(in: .whitespacesAndNewlines), esperada: e.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func comprobar(_ respuesta: String) {
        guard let p = pregunta else { return }
        let limpia = respuesta.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !limpia.isEmpty else { return }
        preguntas[actual].respuesta = limpia
        fase = .corrigiendo
        let indice = actual
        tarea?.cancel()
        tarea = Task { [weak self] in
            guard let self else { return }
            do {
                let veredicto = DynamicGenerationSchema(name: "Veredicto", anyOf: Veredicto.allCases.map(\.rawValue))
                let raiz = DynamicGenerationSchema(name: "Correccion", properties: [
                    .init(name: "veredicto", schema: .init(referenceTo: "Veredicto")),
                    .init(name: "nota", description: L("De 0 a 10", "From 0 to 10", "Da 0 a 10"), schema: .init(type: Int.self, guides: [.range(0...10)])),
                    .init(name: "comentario", description: L("Una o dos frases para el alumno", "One or two sentences for the student", "Una o due frasi per lo studente"), schema: .init(type: String.self)),
                    .init(name: "consejo", description: L("Qué añadir o cómo explicarlo mejor; vacío si no hace falta", "What to add or how to explain it better; empty if not needed", "Cosa aggiungere o come spiegarlo meglio; vuoto se non serve"), schema: .init(type: String.self)),
                ])
                let esquema = try GenerationSchema(root: raiz, dependencies: [veredicto])
                let sesion = LanguageModelSession(model: SystemLanguageModel(guardrails: .permissiveContentTransformations), instructions: self.instruccionesCorregir)
                let apuntes = String((p.temaID.flatMap { self.materiales[$0] } ?? self.material).prefix(2500))
                self.vigilar(75)
                let r = try await sesion.respond(to: self.peticionCorregir(p, respuesta: limpia, apuntes: apuntes), schema: esquema,
                                                 options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 350))
                self.vigilante?.cancel()
                try Task.checkCancellation()
                let v = Veredicto(rawValue: (try? r.content.value(String.self, forProperty: "veredicto")) ?? "") ?? .incompleta
                let nota = (try? r.content.value(Int.self, forProperty: "nota")).map(Double.init)
                conMuelle {
                    self.preguntas[indice].veredicto = v
                    self.preguntas[indice].nota = nota ?? Self.notaPorDefecto(v)
                    self.preguntas[indice].comentario = (try? r.content.value(String.self, forProperty: "comentario")) ?? ""
                    self.preguntas[indice].consejo = (try? r.content.value(String.self, forProperty: "consejo")) ?? ""
                    self.fase = .preguntando
                }
            } catch is CancellationError {
                return
            } catch let e as LanguageModelSession.GenerationError {
                self.fase = .error(TrabajoIA.mensaje(e))
            } catch {
                self.fase = .error(L("No se ha podido corregir. Inténtalo otra vez.", "Couldn't check it. Please try again.", "Non è stato possibile correggere. Riprova."))
            }
        }
    }

    static func notaPorDefecto(_ v: Veredicto) -> Double {
        switch v {
        case .correcta: 10
        case .ampliable: 8
        case .consejo: 8
        case .incompleta: 5
        case .incorrecta: 2
        }
    }

    func siguiente() {
        if actual + 1 < preguntas.count {
            conMuelle { actual += 1 }
        } else {
            conMuelle { fase = .terminada }
        }
    }

    func reintentar() {
        if preguntas.isEmpty { nuevaPrueba() } else { fase = .preguntando }
    }

    private var instrucciones: String {
        let c = curso.isEmpty ? "" : L(" de \(curso)", " in \(curso)", " di \(curso)")
        return L("Eres Hoot, un profesor que prepara a estudiantes\(c) para sus exámenes. Escribe en español, claro y breve. Usa solo la información del texto que te dan.",
                 "You are Hoot, a teacher who prepares students\(c) for their tests. Write in English, clear and brief. Use only the information in the text you're given.",
                 "Sei Hoot, un professore che prepara gli studenti\(c) alle verifiche. Scrivi in italiano, in modo chiaro e breve. Usa solo le informazioni del testo che ti danno.")
    }

    private var instruccionesCorregir: String {
        let c = curso.isEmpty ? "" : L(" de \(curso)", " in \(curso)", " di \(curso)")
        return L("Eres Hoot, un profesor justo y amable que corrige respuestas de examen de estudiantes\(c). Escribe en español, con frases cortas, tuteando. No inventes datos: compara con la respuesta esperada y los apuntes.",
                 "You are Hoot, a fair and kind teacher who marks test answers from students\(c). Write in English, with short sentences, speaking directly to the student. Don't make up facts: compare with the expected answer and the notes.",
                 "Sei Hoot, un professore giusto e gentile che corregge le risposte delle verifiche di studenti\(c). Scrivi in italiano, con frasi brevi, dando del tu. Non inventare dati: confronta con la risposta attesa e gli appunti.")
    }

    private func peticionPreguntas(_ texto: String, cuantas: Int, sobre tema: String) -> String {
        let materia = asignatura.map { L(" de \($0)", " in \($0)", " di \($0)") } ?? ""
        let t = tema.trimmingCharacters(in: .whitespaces)
        let sobre = t.isEmpty ? "" : L(" sobre «\(t)»", " about “\(t)”", " su «\(t)»")
        let evitar = anteriores.isEmpty ? "" : L("\nNo repitas estas preguntas ni las hagas casi iguales:\n", "\nDon't repeat these questions or make nearly identical ones:\n", "\nNon ripetere queste domande né farne di quasi uguali:\n")
            + anteriores.suffix(30).map { "- \($0)" }.joined(separator: "\n")
        return L(
            "Haz \(cuantas) preguntas de examen sobre este tema\(materia)\(sobre) para que el alumno practique. Que sean variadas: definir, explicar, comparar, relacionar y poner un ejemplo. Cada una se contesta en dos o tres frases. Para cada pregunta, escribe también la respuesta que se espera.\(evitar)\n\nTEXTO:\n\(texto)",
            "Write \(cuantas) test questions about this topic\(materia)\(sobre) so the student can practise. Make them varied: define, explain, compare, relate and give an example. Each one is answered in two or three sentences. For each question, also write the expected answer.\(evitar)\n\nTEXT:\n\(texto)",
            "Fai \(cuantas) domande da verifica su questo argomento\(materia)\(sobre) perché lo studente si eserciti. Che siano varie: definire, spiegare, confrontare, collegare e fare un esempio. Ognuna si risponde in due o tre frasi. Per ogni domanda, scrivi anche la risposta attesa.\(evitar)\n\nTESTO:\n\(texto)"
        )
    }

    private func peticionCorregir(_ p: PreguntaPrueba, respuesta: String, apuntes: String) -> String {
        L(
            """
            Pregunta: «\(p.pregunta)»
            Respuesta esperada: «\(p.esperada)»
            Respuesta del alumno: «\(respuesta)»

            Corrige la respuesta del alumno y elige el veredicto:
            - correcta: está bien y completa.
            - ampliable: está bien, pero puede añadir algo importante (di qué).
            - consejo: está bien, pero se puede explicar mejor en el examen (da un consejo para exponerlo).
            - incompleta: falta información importante (di qué falta).
            - incorrecta: tiene datos que no son ciertos (di cuáles y cómo son de verdad).

            APUNTES DEL TEMA:
            \(apuntes)
            """,
            """
            Question: “\(p.pregunta)”
            Expected answer: “\(p.esperada)”
            Student's answer: “\(respuesta)”

            Mark the student's answer and choose the verdict:
            - correcta: right and complete.
            - ampliable: right, but they can add something important (say what).
            - consejo: right, but it could be explained better in the test (give a tip on how to present it).
            - incompleta: important information is missing (say what).
            - incorrecta: it has facts that aren't true (say which, and what's actually true).

            NOTES ON THE TOPIC:
            \(apuntes)
            """,
            """
            Domanda: «\(p.pregunta)»
            Risposta attesa: «\(p.esperada)»
            Risposta dello studente: «\(respuesta)»

            Correggi la risposta dello studente e scegli il verdetto:
            - correcta: giusta e completa.
            - ampliable: giusta, ma può aggiungere qualcosa di importante (di' cosa).
            - consejo: giusta, ma si può spiegare meglio nella verifica (dai un consiglio per esporla).
            - incompleta: manca un'informazione importante (di' cosa manca).
            - incorrecta: ha dati che non sono veri (di' quali e come sono davvero).

            APPUNTI DELL'ARGOMENTO:
            \(apuntes)
            """
        )
    }
}
