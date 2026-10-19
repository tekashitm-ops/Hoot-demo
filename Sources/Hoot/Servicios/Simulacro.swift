import Foundation
import FoundationModels
import UIKit

@Observable
final class SimulacroIA: Identifiable {
    enum Forma: String, CaseIterable, Identifiable {
        case iPhone, papel, oral
        var id: String { rawValue }
    }

    enum Fase: Equatable {
        case preparando(Int, Int)
        case contestando

        case hoja
        case leyendoHoja

        case revisando
        case corrigiendo(Int, Int)
        case corregido
        case error(String)
    }

    struct Pregunta: Identifiable, Equatable {
        var id = UUID()
        var temaID: UUID
        var texto: String
        var esperada: String
        var respuesta = ""

        var repregunta = ""
        var respuestaRepregunta = ""
        var correccion: Veredicto?
        var comentario = ""
    }

    let pruebaID: UUID
    let titulo: String
    let asignatura: Asignatura?
    let curso: String
    let forma: Forma

    let minutos: Int?
    private(set) var preguntas: [Pregunta] = []
    var actual = 0
    private(set) var fase: Fase = .preparando(0, 1)
    private(set) var fin: Date?

    private(set) var lunasAntes: [UUID: Double] = [:]
    let nombres: [UUID: String]

    @ObservationIgnored private var materiales: [UUID: String] = [:]
    @ObservationIgnored private let estilo: String
    @ObservationIgnored private var tarea: Task<Void, Never>?

    init(prueba p: Prueba, asignatura: Asignatura?, curso: String, forma: Forma, minutos: Int?, estilo: String) {
        pruebaID = p.id
        titulo = asignatura?.nombre ?? p.tipo.nombre
        self.asignatura = asignatura
        self.curso = curso
        self.forma = forma
        self.minutos = minutos
        self.estilo = estilo
        let cal = calendarioActual
        let temas = p.temas.filter { !$0.textoLeido.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        nombres = Dictionary(p.temas.map { ($0.id, $0.nombre) }, uniquingKeysWith: { a, _ in a })
        lunasAntes = Dictionary(p.temas.map { ($0.id, $0.luna(cal: cal).fraccion) }, uniquingKeysWith: { a, _ in a })
        materiales = Dictionary(temas.map { ($0.id, $0.textoLeido) }, uniquingKeysWith: { a, _ in a })
    }

    static func cuantas(_ temas: Int) -> Int { min(10, max(6, temas * 2)) }

    var pregunta: Pregunta? { preguntas.indices.contains(actual) ? preguntas[actual] : nil }
    var contestadas: Int { preguntas.filter { !$0.respuesta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count }

    func empezar() {
        guard DisponibilidadIA.actual == .lista else {
            fase = .error(DisponibilidadIA.actual.mensaje)
            return
        }
        let ids = Array(materiales.keys).sorted { (nombres[$0] ?? "") < (nombres[$1] ?? "") }
        guard !ids.isEmpty else {
            fase = .error(L("Ningún tema tiene material. Dales fotos o un PDF y vuelve.", "No topic has material yet. Give them photos or a PDF and come back.",
                            "Nessun argomento ha materiale. Dagli foto o un PDF e torna."))
            return
        }
        let total = Self.cuantas(ids.count)
        tarea = Task { [weak self] in
            guard let self else { return }
            do {
                var porTema: [[Pregunta]] = []
                for (i, id) in ids.enumerated() {
                    self.fase = .preparando(i + 1, ids.count)
                    let n = total / ids.count + (i < total % ids.count ? 1 : 0)
                    guard n > 0 else { continue }
                    porTema.append(try await self.generar(n, tema: id))
                    try Task.checkCancellation()
                }

                var mezcla: [Pregunta] = []
                while porTema.contains(where: { !$0.isEmpty }) {
                    for k in porTema.indices where !porTema[k].isEmpty { mezcla.append(porTema[k].removeFirst()) }
                }
                guard !mezcla.isEmpty else {
                    self.fase = .error(L("No se han podido sacar preguntas del material.", "Couldn't make questions from the material.",
                                         "Non è stato possibile fare domande dal materiale."))
                    return
                }
                self.preguntas = mezcla
                self.actual = 0
                if let m = self.minutos { self.fin = Date().addingTimeInterval(Double(m) * 60) }
                conMuelle { self.fase = .contestando }
            } catch is CancellationError {
                return
            } catch let e as LanguageModelSession.GenerationError {
                self.fase = .error(TrabajoIA.mensaje(e))
            } catch {
                self.fase = .error(L("No se ha podido preparar. Inténtalo otra vez.", "Couldn't get it ready. Please try again.", "Non è stato possibile prepararla. Riprova."))
            }
        }
    }

    private func generar(_ n: Int, tema id: UUID) async throws -> [Pregunta] {
        let material = try await TrabajoIA.ajustar(materiales[id] ?? "", maximo: TrabajoIA.caracteresMaximos - 3200)
        let p = DynamicGenerationSchema(name: "Pregunta", properties: [
            .init(name: "pregunta", description: L("La pregunta, como en un examen", "The question, as in a test", "La domanda, come in una verifica"), schema: .init(type: String.self)),
            .init(name: "respuesta", description: L("La respuesta que se espera, breve y con los datos clave", "The expected answer, short, with the key facts", "La risposta attesa, breve e con i dati chiave"), schema: .init(type: String.self)),
        ])
        let raiz = DynamicGenerationSchema(name: "Simulacro", properties: [
            .init(name: "preguntas", schema: .init(arrayOf: .init(referenceTo: "Pregunta"), minimumElements: n, maximumElements: n)),
        ])
        let esquema = try GenerationSchema(root: raiz, dependencies: [p])
        let sesion = LanguageModelSession(model: SystemLanguageModel(guardrails: .permissiveContentTransformations), instructions: instrucciones)
        let r = try await sesion.respond(to: peticion(n, tema: nombres[id] ?? "", material: material), schema: esquema,
                                         options: GenerationOptions(temperature: 0.7, maximumResponseTokens: 700))
        let lista = try r.content.value([GeneratedContent].self, forProperty: "preguntas")
        return lista.compactMap { c in
            guard let q = try? c.value(String.self, forProperty: "pregunta"), let e = try? c.value(String.self, forProperty: "respuesta"),
                  !q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return Pregunta(temaID: id, texto: q.trimmingCharacters(in: .whitespacesAndNewlines), esperada: e.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private var instrucciones: String {
        let c = curso.isEmpty ? "" : L(" de \(curso)", " in \(curso)", " di \(curso)")
        return L("Eres un profesor que prepara el examen de un alumno\(c). Escribe en español, claro y breve. Usa solo la información del material.",
                 "You are a teacher writing a student's test\(c). Write in English, clear and brief. Use only the information in the material.",
                 "Sei un professore che prepara la verifica di uno studente\(c). Scrivi in italiano, in modo chiaro e breve. Usa solo le informazioni del materiale.")
    }

    private func peticion(_ n: Int, tema: String, material: String) -> String {
        let materia = asignatura.map { L(" de \($0.nombre)", " in \($0.nombre)", " di \($0.nombre)") } ?? ""
        let oral = forma == .oral
        let como = oral
            ? L("Son para una interrogazione oral: preguntas para contestar hablando, en unas frases.", "They're for an oral test: questions to answer out loud, in a few sentences.",
                "Sono per un'interrogazione: domande a cui rispondere a voce, in qualche frase.")
            : L("Que sean variadas, como en un examen escrito: verdadero o falso (con su corrección), completar, preguntas cortas y alguna de explicar.",
                "Make them varied, as in a written test: true or false (with the correction), fill in the blank, short questions and one to explain.",
                "Che siano varie, come in una verifica scritta: vero o falso (con la correzione), completare, domande brevi e qualcuna da spiegare.")
        let ejemplo = estilo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : L(
            "\n\nASÍ PREGUNTA SU PROFE (una prueba suya de antes: imita sus tipos de pregunta y su forma de preguntar, sin copiar las preguntas):\n",
            "\n\nHOW THEIR TEACHER ASKS (one of their old tests: imitate the question types and the way of asking, without copying the questions):\n",
            "\n\nCOME CHIEDE IL SUO PROF (una sua verifica di prima: imita i tipi di domanda e il modo di chiedere, senza copiare le domande):\n") + String(estilo.prefix(1400))
        return L(
            "Haz \(n) preguntas de examen\(materia) sobre «\(tema)». \(como) Para cada una, escribe también la respuesta que se espera.\(ejemplo)\n\nMATERIAL:\n\(material)",
            "Write \(n) test questions\(materia) about “\(tema)”. \(como) For each one, also write the expected answer.\(ejemplo)\n\nMATERIAL:\n\(material)",
            "Fai \(n) domande da verifica\(materia) su «\(tema)». \(como) Per ognuna, scrivi anche la risposta attesa.\(ejemplo)\n\nMATERIALE:\n\(material)"
        )
    }

    func responder(_ texto: String) {
        guard preguntas.indices.contains(actual) else { return }
        preguntas[actual].respuesta = texto
    }

    func responderRepregunta(_ texto: String) {
        guard preguntas.indices.contains(actual) else { return }
        preguntas[actual].respuestaRepregunta = texto
    }

    func siguiente() {
        if actual + 1 < preguntas.count { conMuelle { actual += 1 } } else { entregar() }
    }

    func anterior() {
        if actual > 0 { conMuelle { actual -= 1 } }
    }

    func entregar() {
        fin = nil
        if forma == .papel { conMuelle { fase = .hoja } } else { corregir() }
    }

    var tiempoAcabado: Bool { fin.map { Date() >= $0 } ?? false }

    func leerHoja(_ imagenes: [UIImage]) {
        guard !imagenes.isEmpty else { return }
        fase = .leyendoHoja
        tarea = Task { [weak self] in
            guard let self else { return }
            let texto = (try? await TrabajoIA.leer(imagenes.map { $0.reducida(a: 2400) }, escrito: "") { _, _ in }) ?? ""
            let partes = Self.repartir(texto, preguntas: self.preguntas.count)
            for (i, t) in partes { if self.preguntas.indices.contains(i) { self.preguntas[i].respuesta = t } }
            conMuelle { self.fase = .revisando }
        }
    }

    static func repartir(_ texto: String, preguntas n: Int) -> [Int: String] {
        var r: [Int: String] = [:]
        var actual: Int?
        for linea in texto.components(separatedBy: "\n") {
            let l = linea.trimmingCharacters(in: .whitespaces)
            guard !l.isEmpty, !l.hasPrefix("[") else { continue }
            var digitos = ""
            for c in l { if c.isNumber && digitos.count < 2 { digitos.append(c) } else { break } }
            let resto = l.dropFirst(digitos.count)
            if let num = Int(digitos), num >= 1, num <= n, let sep = resto.first, ".)-:".contains(sep) || sep == " " {
                actual = num - 1
                let t = resto.dropFirst().trimmingCharacters(in: CharacterSet(charactersIn: ".)-: ").union(.whitespaces))
                r[num - 1] = t
            } else if let a = actual {
                r[a] = [r[a] ?? "", l].filter { !$0.isEmpty }.joined(separator: " ")
            }
        }
        return r
    }

    func volverAFotografiar() { fase = .hoja }

    func repreguntar() async -> String {
        guard let p = pregunta, DisponibilidadIA.actual == .lista, !p.respuesta.isEmpty else { return "" }
        let sesion = LanguageModelSession(model: SystemLanguageModel(guardrails: .permissiveContentTransformations), instructions: instrucciones)
        let apuntes = String((materiales[p.temaID] ?? "").prefix(1800))
        let r = try? await sesion.respond(to: L(
            "En una interrogazione oral has preguntado: «\(p.texto)». El alumno ha contestado: «\(p.respuesta)». Haz UNA repregunta corta, como un profe, para ver si lo entiende de verdad (por qué, un ejemplo o una relación con otra cosa del tema). Escribe solo la pregunta.\n\nMATERIAL:\n\(apuntes)",
            "In an oral test you asked: “\(p.texto)”. The student answered: “\(p.respuesta)”. Ask ONE short follow-up question, like a teacher, to see if they really understand (why, an example or a link to something else in the topic). Write only the question.\n\nMATERIAL:\n\(apuntes)",
            "In un'interrogazione hai chiesto: «\(p.texto)». Lo studente ha risposto: «\(p.respuesta)». Fai UNA domanda di approfondimento breve, come un prof, per vedere se ha capito davvero (perché, un esempio o un collegamento con un'altra cosa dell'argomento). Scrivi solo la domanda.\n\nMATERIALE:\n\(apuntes)"),
            options: GenerationOptions(temperature: 0.5, maximumResponseTokens: 80))
        let q = r?.content.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "") ?? ""
        if preguntas.indices.contains(actual) { preguntas[actual].repregunta = q }
        return q
    }

    func corregir() {
        let total = preguntas.count
        tarea = Task { [weak self] in
            guard let self else { return }
            for i in 0..<total {
                self.fase = .corrigiendo(i + 1, total)
                let p = self.preguntas[i]
                var respuesta = p.respuesta.trimmingCharacters(in: .whitespacesAndNewlines)
                if !p.repregunta.isEmpty {
                    respuesta += L(" (A la repregunta «\(p.repregunta)»: \(p.respuestaRepregunta))", " (To the follow-up “\(p.repregunta)”: \(p.respuestaRepregunta))",
                                   " (Alla domanda «\(p.repregunta)»: \(p.respuestaRepregunta))")
                }
                if respuesta.isEmpty {

                    self.preguntas[i].correccion = .incorrecta
                    self.preguntas[i].comentario = p.esperada
                    continue
                }
                do {
                    let c = try await PruebaIA.corregir(pregunta: p.texto, esperada: p.esperada, respuesta: respuesta,
                                                        apuntes: String((self.materiales[p.temaID] ?? "").prefix(2500)), curso: self.curso)
                    try Task.checkCancellation()
                    self.preguntas[i].correccion = c.veredicto
                    self.preguntas[i].comentario = c.veredicto.fallada ? (c.consejo.isEmpty ? c.comentario : c.consejo) : c.comentario
                } catch is CancellationError {
                    return
                } catch {
                    self.preguntas[i].correccion = .incompleta
                    self.preguntas[i].comentario = L("No se ha podido corregir esta.", "Couldn't mark this one.", "Non è stato possibile correggere questa.")
                }
            }
            conMuelle { self.fase = .corregido }
        }
    }

    func intentos(fecha: Date = Reloj.ahora) -> [UUID: Intento] {
        var porTema: [UUID: [Respuesta]] = [:]
        for p in preguntas {
            guard let v = p.correccion else { continue }
            porTema[p.temaID, default: []].append(Respuesta(acierto: !v.fallada, seguridad: nil))
        }
        return porTema.mapValues { Intento(fecha: fecha, respuestas: $0, mezclado: true) }
    }

    func cancelar() { tarea?.cancel() }

    static func demo(prueba p: Prueba, asignatura: Asignatura?, forma: Forma, corregido: Bool) -> SimulacroIA {
        let s = SimulacroIA(prueba: p, asignatura: asignatura, curso: "", forma: forma, minutos: corregido ? nil : 50, estilo: "")
        let t = p.temas
        guard t.count >= 4 else { return s }
        s.preguntas = [
            Pregunta(temaID: t[0].id, texto: L("Verdadero o falso: Roma empezó siendo una república.", "True or false: Rome started as a republic.", "Vero o falso: Roma nacque come repubblica."),
                     esperada: L("Falso: primero fue una monarquía.", "False: it was a monarchy first.", "Falso: prima fu una monarchia."),
                     respuesta: L("Falso, primero hubo reyes.", "False, first there were kings.", "Falso, prima c'erano i re."), correccion: .correcta,
                     comentario: L("Bien.", "Good.", "Bene.")),
            Pregunta(temaID: t[1].id, texto: L("¿Por qué se enfrentaron Roma y Cartago?", "Why did Rome and Carthage fight?", "Perché si scontrarono Roma e Cartagine?"),
                     esperada: L("Por el control del Mediterráneo y de Sicilia.", "For control of the Mediterranean and Sicily.", "Per il controllo del Mediterraneo e della Sicilia."),
                     respuesta: L("Por el Mediterráneo y Sicilia.", "For the Mediterranean and Sicily.", "Per il Mediterraneo e la Sicilia."), correccion: .correcta),
            Pregunta(temaID: t[2].id, texto: L("Ordena: República, Monarquía, Imperio.", "Put in order: Republic, Monarchy, Empire.", "Metti in ordine: Repubblica, Monarchia, Impero."),
                     esperada: L("Monarquía, República, Imperio.", "Monarchy, Republic, Empire.", "Monarchia, Repubblica, Impero."),
                     respuesta: L("República, Monarquía, Imperio.", "Republic, Monarchy, Empire.", "Repubblica, Monarchia, Impero."), correccion: .incorrecta,
                     comentario: L("Primero la Monarquía.", "The Monarchy came first.", "Prima la Monarchia.")),
            Pregunta(temaID: t[3].id, texto: L("¿Qué hizo Augusto en el 27 a. C.?", "What did Augustus do in 27 BC?", "Che cosa fece Augusto nel 27 a.C.?"),
                     esperada: L("Se convirtió en el primer emperador.", "He became the first emperor.", "Diventò il primo imperatore."),
                     respuesta: "", correccion: .incorrecta, comentario: L("Fue el primer emperador.", "He became the first emperor.", "Diventò il primo imperatore.")),
        ]
        if corregido {
            s.fase = .corregido
        } else {
            for i in s.preguntas.indices { s.preguntas[i].correccion = nil; s.preguntas[i].comentario = "" }
            s.preguntas[2].respuesta = ""
            s.preguntas[3].respuesta = ""
            s.actual = 2
            s.fin = Date().addingTimeInterval(32 * 60 + 10)
            s.fase = .contestando
        }
        return s
    }
}
