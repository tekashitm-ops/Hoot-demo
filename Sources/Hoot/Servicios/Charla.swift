import Foundation
import FoundationModels
import UIKit

@Observable
final class CharlaHoot: Identifiable {
    enum Origen: Equatable {

        case tema(UUID)

        case suelta
    }

    var mensajes: [MensajeCharla]

    var escribiendo = false
    var parcial = ""
    var leyendoFoto = false

    var fotosLeidas = (actual: 0, total: 0)
    var aviso: String?

    let origen: Origen
    let titulo: String
    let asignatura: String?
    let asignaturaID: UUID?
    let curso: String

    @ObservationIgnored var alResponder: (([MensajeCharla]) -> Void)?
    @ObservationIgnored private var trozos: [TrozoMaterial]
    @ObservationIgnored private var tarea: Task<Void, Never>?

    init(origen: Origen, titulo: String, asignatura: Asignatura?, curso: String, trozos: [TrozoMaterial], mensajes: [MensajeCharla] = []) {
        self.origen = origen
        self.titulo = titulo
        self.asignatura = asignatura?.nombre
        self.asignaturaID = asignatura?.id
        self.curso = curso
        self.trozos = trozos
        self.mensajes = mensajes
    }

    convenience init(tema t: Tema, asignatura: Asignatura?, curso: String) {
        self.init(origen: .tema(t.id), titulo: t.nombre, asignatura: asignatura, curso: curso, trozos: Self.trozos(de: t), mensajes: t.charla)
    }

    var hayMaterial: Bool { !trozos.isEmpty }

    func enviar(_ texto: String) {
        let t = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !escribiendo else { return }
        mensajes.append(MensajeCharla(quien: .yo, texto: t))
        responder(consulta: t)
    }

    func enviarFotos(_ imagenes: [UIImage], pregunta: String) {
        guard !imagenes.isEmpty, !escribiendo, !leyendoFoto else { return }
        aviso = nil
        leyendoFoto = true
        fotosLeidas = (0, imagenes.count)
        Task {
            var textos: [String] = []
            var miniaturas: [Data] = []
            for (i, imagen) in imagenes.enumerated() {
                fotosLeidas = (i + 1, imagenes.count)
                let reducida = imagen.reducida(a: 2400)
                textos.append((try? await LectorTexto.leer(reducida)) ?? "")
                if let m = reducida.reducida(a: 480).jpegData(compressionQuality: 0.7) { miniaturas.append(m) }
            }
            leyendoFoto = false
            let varias = imagenes.count > 1
            var nuevos: [TrozoMaterial] = []
            for (i, t) in textos.enumerated() where t.trimmingCharacters(in: .whitespacesAndNewlines).count > 15 {
                let etiqueta = varias ? L("Tu foto \(i + 1)", "Your photo \(i + 1)", "La tua foto \(i + 1)") : L("Tu foto", "Your photo", "La tua foto")
                nuevos += BuscarMaterial.trozos(t, etiqueta: etiqueta)
            }
            guard !nuevos.isEmpty else {
                aviso = varias
                    ? L("No se lee texto en las fotos. Prueba con más luz y la hoja entera.", "No text found in the photos. Try with more light and the whole page.",
                        "Nessun testo nelle foto. Riprova con più luce e la pagina intera.")
                    : L("No se lee texto en la foto. Prueba con más luz y la hoja entera.", "No text found in the photo. Try with more light and the whole page.",
                        "Nessun testo nella foto. Riprova con più luce e la pagina intera.")
                return
            }
            trozos = nuevos + trozos
            let todo = textos.joined(separator: "\n\n")
            let p = pregunta.trimmingCharacters(in: .whitespacesAndNewlines)
            mensajes.append(MensajeCharla(quien: .yo, texto: p, foto: miniaturas.first, masFotos: Array(miniaturas.dropFirst())))
            let encargo = varias
                ? L("El alumno te manda fotos de algo que no entiende (en el MATERIAL, «Tu foto 1», «Tu foto 2»…). Explícale de qué va, fácil y paso a paso. Si es un ejercicio, no lo resuelvas: explícale cómo se hace con uno parecido y dale una pista.",
                    "The student sends you photos of something they don't understand (in the MATERIAL, “Your photo 1”, “Your photo 2”…). Explain what it's about, simply and step by step. If it's an exercise, don't solve it: show how it's done with a similar one and give a hint.",
                    "Lo studente ti manda delle foto di qualcosa che non capisce (nel MATERIALE, «La tua foto 1», «La tua foto 2»…). Spiegagli di cosa si tratta, facile e passo per passo. Se è un esercizio, non risolverlo: spiegagli come si fa con uno simile e dagli un suggerimento.")
                : L("El alumno te manda la foto de algo que no entiende (en el MATERIAL, «Tu foto»). Explícale de qué va, fácil y paso a paso. Si es un ejercicio, no lo resuelvas: explícale cómo se hace con uno parecido y dale una pista.",
                    "The student sends you a photo of something they don't understand (in the MATERIAL, “Your photo”). Explain what it's about, simply and step by step. If it's an exercise, don't solve it: show how it's done with a similar one and give a hint.",
                    "Lo studente ti manda la foto di qualcosa che non capisce (nel MATERIALE, «La tua foto»). Spiegagli di cosa si tratta, facile e passo per passo. Se è un esercizio, non risolverlo: spiegagli come si fa con uno simile e dagli un suggerimento.")
            responder(consulta: p.isEmpty ? String(todo.prefix(300)) : p + " " + String(todo.prefix(200)), encargo: p.isEmpty ? encargo : nil)
        }
    }

    func porQue(pregunta: String, esperada: String, dada: String) {
        mensajes.append(MensajeCharla(quien: .yo, texto: L("¿Por qué era «\(esperada)»?", "Why was it “\(esperada)”?", "Perché era «\(esperada)»?")))
        let contesto = dada.trimmingCharacters(in: .whitespacesAndNewlines)
        let suya = contesto.isEmpty ? L("no contestó", "didn't answer", "non ha risposto") : L("contestó «\(contesto)»", "answered “\(contesto)”", "ha risposto «\(contesto)»")
        responder(consulta: pregunta + " " + esperada,
                  encargo: L("El alumno ha fallado esta pregunta: «\(pregunta)». La respuesta buena es «\(esperada)»; él \(suya). Explícale por qué la buena es la buena y en qué se equivocó.",
                             "The student got this question wrong: “\(pregunta)”. The right answer is “\(esperada)”; they \(suya). Explain why the right answer is right and where they went wrong.",
                             "Lo studente ha sbagliato questa domanda: «\(pregunta)». La risposta giusta è «\(esperada)»; lui \(suya). Spiegagli perché quella giusta è giusta e dove ha sbagliato."))
    }

    func cancelar() {
        tarea?.cancel()
        escribiendo = false
        parcial = ""
    }

    private func responder(consulta: String, encargo: String? = nil) {
        guard DisponibilidadIA.actual == .lista else {
            aviso = DisponibilidadIA.actual.mensaje
            return
        }
        aviso = nil
        escribiendo = true
        parcial = ""

        let anterior = mensajes.dropLast().last { $0.quien == .hoot }?.texto ?? ""
        let (elegidos, encontrado) = BuscarMaterial.relevantes(consulta + " " + anterior, en: trozos, maximo: 2400)
        let fuente = encontrado ? (elegidos.first?.etiqueta ?? "") : ""
        let prompt = Self.peticion(material: elegidos, historial: Array(mensajes.suffix(7)), encargo: encargo)
        let instrucciones = Self.instrucciones(titulo: titulo, asignatura: asignatura, curso: curso)
        tarea = Task { [weak self] in
            guard let self else { return }
            do {
                let sesion = LanguageModelSession(model: .default, instructions: instrucciones)
                let flujo = sesion.streamResponse(to: prompt, options: GenerationOptions(temperature: 0.5, maximumResponseTokens: 380))
                for try await p in flujo {
                    try Task.checkCancellation()
                    self.parcial = p.content
                }
                let (respuesta, deVuelta) = Self.partir(self.parcial)
                var nuevos = [MensajeCharla(quien: .hoot, texto: respuesta, fuente: fuente)]
                if let deVuelta { nuevos.append(MensajeCharla(quien: .hoot, texto: deVuelta)) }
                self.mensajes += nuevos
                self.parcial = ""
                self.escribiendo = false
                self.alResponder?(nuevos)
            } catch is CancellationError {
                return
            } catch let error as LanguageModelSession.GenerationError {
                self.parcial = ""
                self.escribiendo = false
                if case .guardrailViolation = error {
                    self.aviso = L("De eso mejor pregúntale a tu profe.", "Better ask your teacher about that one.", "Di questo è meglio parlare con il tuo prof.")
                } else {
                    self.aviso = TrabajoIA.mensaje(error)
                }
            } catch {
                self.parcial = ""
                self.escribiendo = false
                self.aviso = L("Hoot se ha liado. Pregúntaselo otra vez.", "Hoot got muddled. Ask again.", "Hoot si è confuso. Chiediglielo di nuovo.")
            }
        }
    }

    static func partir(_ texto: String) -> (respuesta: String, deVuelta: String?) {
        let limpio = texto.replacingOccurrences(of: "**", with: "")
        let marca = L("Ahora tú:", "Your turn:", "Ora tu:")
        guard let r = limpio.range(of: marca, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return (limpio.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }
        let antes = limpio[..<r.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let despues = limpio[r.lowerBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        return (antes, despues.count > marca.count + 2 ? despues : nil)
    }

    private static func instrucciones(titulo: String, asignatura: String?, curso: String) -> String {
        let deCurso = curso.isEmpty ? "" : L(" de \(curso)", " in \(curso)", " di \(curso)")
        let materia = asignatura.map { L(", de \($0)", ", in \($0)", ", di \($0)") } ?? ""
        return L(
            "Eres Hoot, un lobo gris que ayuda a estudiar a un alumno\(deCurso). Habláis del tema «\(titulo)»\(materia). Escribes como en un chat de mensajes: frases cortas, tuteas, con un poco de humor y sin signos de exclamación. Los datos, solo del MATERIAL; no te inventes nada. Si el MATERIAL no lo dice, empieza con «Eso no sale en tu material» y explica lo general en una frase. No hagas sus ejercicios ni sus deberes: si te pide una solución, explícale cómo se hace con un ejemplo parecido y dale una pista. Si se va del tema, contesta en una frase y vuelve al tema. Nunca te rías de él ni de lo que sabe. Escribe en español.",
            "You are Hoot, a grey wolf who helps a student\(deCurso) study. You're talking about “\(titulo)”\(materia). You write like in a messaging chat: short sentences, a bit of humour and no exclamation marks. Facts only from the MATERIAL; never make anything up. If the MATERIAL doesn't say it, start with “That's not in your material” and explain the general idea in one sentence. Don't do their exercises or homework: if they ask for a solution, show how it's done with a similar example and give a hint. If they go off topic, answer in one sentence and come back to the topic. Never make fun of them or of what they know. Write in English.",
            "Sei Hoot, un lupo grigio che aiuta a studiare uno studente\(deCurso). Parlate dell'argomento «\(titulo)»\(materia). Scrivi come in una chat di messaggi: frasi brevi, dai del tu, con un po' di umorismo e senza punti esclamativi. I dati, solo dal MATERIALE; non inventare niente. Se il MATERIALE non lo dice, comincia con «Questo non c'è nel tuo materiale» e spiega l'idea generale in una frase. Non fare i suoi esercizi né i compiti: se ti chiede una soluzione, spiegagli come si fa con un esempio simile e dagli un suggerimento. Se va fuori tema, rispondi in una frase e torna all'argomento. Non prenderlo mai in giro né per quello che sa. Scrivi in italiano."
        )
    }

    private static func peticion(material: [TrozoMaterial], historial: [MensajeCharla], encargo: String?) -> String {
        let alumno = L("Alumno", "Student", "Studente")
        let charla = historial.map { m in
            let n = m.fotos.count
            let texto = !m.texto.isEmpty || n == 0 ? String(m.texto.prefix(400))
                : n == 1 ? L("(manda una foto)", "(sends a photo)", "(manda una foto)") : L("(manda \(n) fotos)", "(sends \(n) photos)", "(manda \(n) foto)")
            return "\(m.quien == .yo ? alumno : "Hoot"): \(texto)"
        }.joined(separator: "\n")
        let trozos = material.map { "[\($0.etiqueta)]\n\($0.texto)" }.joined(separator: "\n\n")
        let pedido = encargo ?? L("Contesta al último mensaje del alumno.", "Answer the student's last message.", "Rispondi all'ultimo messaggio dello studente.")
        return L(
            """
            MATERIAL:
            \(trozos.isEmpty ? "(sin material)" : trozos)

            LA CHARLA HASTA AHORA:
            \(charla)

            \(pedido) Escribe como Hoot, en 2 a 4 frases cortas. Si el último mensaje del alumno contesta a tu última pregunta, empieza diciendo si está bien («Bien», «Casi» o «No») y por qué. Después, si viene a cuento, añade una línea que empiece por «Ahora tú:» con una pregunta corta para comprobar que lo ha entendido.
            """,
            """
            MATERIAL:
            \(trozos.isEmpty ? "(no material)" : trozos)

            THE CHAT SO FAR:
            \(charla)

            \(pedido) Write as Hoot, in 2 to 4 short sentences. If the student's last message answers your last question, start by saying whether it's right (“Right”, “Almost” or “No”) and why. Then, if it fits, add a line starting with “Your turn:” with a short question to check they've understood.
            """,
            """
            MATERIALE:
            \(trozos.isEmpty ? "(nessun materiale)" : trozos)

            LA CHAT FINO A ORA:
            \(charla)

            \(pedido) Scrivi come Hoot, in 2-4 frasi brevi. Se l'ultimo messaggio dello studente risponde alla tua ultima domanda, comincia dicendo se va bene («Bene», «Quasi» o «No») e perché. Poi, se ha senso, aggiungi una riga che comincia con «Ora tu:» con una domanda breve per verificare che abbia capito.
            """
        )
    }

    static func trozos(de t: Tema) -> [TrozoMaterial] {
        if !t.fuentes.isEmpty, t.puedeQuitarFuentes {
            return t.fuentes.flatMap { f in BuscarMaterial.trozos(f.texto, etiqueta: etiqueta(f)) }
        }
        return BuscarMaterial.trozos(t.textoLeido, etiqueta: L("Tu material", "Your material", "Il tuo materiale"))
    }

    private static func etiqueta(_ f: FuenteTema) -> String {
        switch f.tipo {
        case .fotos: L("Tus fotos", "Your photos", "Le tue foto")
        case .texto: L("Texto pegado", "Pasted text", "Testo incollato")
        default: f.nombre
        }
    }

    var transcripcion: String {
        mensajes.map { m in
            m.quien == .yo ? "**\(L("Tú", "You", "Tu")):** \(m.texto.isEmpty ? L("(una foto)", "(a photo)", "(una foto)") : m.texto)" : "**Hoot:** \(m.texto)"
        }.joined(separator: "\n\n")
    }
}
