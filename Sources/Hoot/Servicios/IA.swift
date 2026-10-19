import SwiftUI
import FoundationModels

enum DisponibilidadIA: Equatable {
    case lista
    case noCompatible
    case desactivada
    case preparando
    case idiomaNoDisponible

    case sinPermiso

    static var faltaPermisoFamilia = false

    static var actual: DisponibilidadIA {

        if ModoCapturas.activo, ModoCapturas.valor("-ia") == "lista" { return .lista }

        if let forzada = Desarrollo.compartido.iaForzada { return forzada }
        if faltaPermisoFamilia { return .sinPermiso }
        return real
    }

    static var real: DisponibilidadIA {
        let modelo = SystemLanguageModel.default
        switch modelo.availability {
        case .available:
            return modelo.supportsLocale(localeActual) ? .lista : .idiomaNoDisponible
        case .unavailable(.deviceNotEligible): return .noCompatible
        case .unavailable(.appleIntelligenceNotEnabled): return .desactivada
        case .unavailable(.modelNotReady): return .preparando
        case .unavailable: return .preparando
        }
    }

    var mensaje: String {
        switch self {
        case .lista: ""
        case .noCompatible: L("Este iPhone no tiene Apple Intelligence.", "This iPhone doesn't support Apple Intelligence.", "Questo iPhone non supporta Apple Intelligence.")
        case .desactivada: L("Activa Apple Intelligence en Ajustes > Apple Intelligence y Siri.", "Turn on Apple Intelligence in Settings > Apple Intelligence & Siri.", "Attiva Apple Intelligence in Impostazioni > Apple Intelligence e Siri.")
        case .preparando: L("Apple Intelligence se está preparando. Prueba dentro de unos minutos.", "Apple Intelligence is getting ready. Try again in a few minutes.", "Apple Intelligence si sta preparando. Riprova tra qualche minuto.")
        case .idiomaNoDisponible: L("Apple Intelligence aún no está disponible en este idioma.", "Apple Intelligence isn't available in this language yet.", "Apple Intelligence non è ancora disponibile in questa lingua.")
        case .sinPermiso: L("Falta el permiso de tu madre o tu padre: Cuenta > Ayuda de estudio.",
                            "Your parent's permission is missing: Account > Study Help.",
                            "Manca il permesso di tua madre o tuo padre: Account > Aiuto allo studio.")
        }
    }
}

@Observable
final class TrabajoIA: Hashable {
    nonisolated static func == (a: TrabajoIA, b: TrabajoIA) -> Bool { a === b }
    nonisolated func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }

    enum Fase: Equatable {
        case leyendo(Int, Int)
        case pensando
        case escribiendo
        case listo
        case error(String)
    }

    var fase: Fase = .pensando
    var resultado = ""
    var textoLeido = ""

    @ObservationIgnored private var tarea: Task<Void, Never>?

    var terminado: Bool {
        if case .listo = fase { return true }
        return false
    }

    var fallido: Bool {
        if case .error = fase { return true }
        return false
    }

    func cancelar() {
        tarea?.cancel()
    }

    struct Peticion {
        var tipo: TipoAyuda
        var imagenes: [UIImage]
        var textoEscrito: String
        var ejercicio: String
        var tema: String
        var modo: ModoRevision
        var longitud: Longitud
        var asignatura: String?
        var curso: String
    }

    func empezar(_ p: Peticion, alTerminar: @escaping (TrabajoIA) -> Void) {
        tarea?.cancel()
        resultado = ""
        tarea = Task { [weak self] in
            guard let self else { return }
            do {

                let texto = try await Self.leer(p.imagenes, escrito: p.textoEscrito) { i, n in self.fase = .leyendo(i, n) }
                self.textoLeido = texto
                guard texto.count > 20 else {
                    self.fase = .error(L("No se lee texto en las fotos. Prueba con más luz y la hoja entera.", "No text found in the photos. Try with more light and the whole page.", "Nessun testo nelle foto. Riprova con più luce e la pagina intera."))
                    return
                }

                guard DisponibilidadIA.actual == .lista else {
                    self.fase = .error(DisponibilidadIA.actual.mensaje)
                    return
                }
                self.fase = .pensando
                let material = try await Self.ajustar(texto, cortarSinResumir: p.tipo == .revisar)

                let modelo = p.tipo == .revisar ? SystemLanguageModel.default : SystemLanguageModel(guardrails: .permissiveContentTransformations)
                let sesion = LanguageModelSession(model: modelo, instructions: Self.instrucciones(p))
                let opciones = GenerationOptions(temperature: p.tipo == .revisar ? 0.2 : 0.4, maximumResponseTokens: Self.tokensRespuesta(p))
                let flujo = sesion.streamResponse(to: Self.peticion(p, material: material), options: opciones)
                for try await parcial in flujo {
                    try Task.checkCancellation()
                    if self.fase != .escribiendo { self.fase = .escribiendo }
                    self.resultado = parcial.content
                }
                self.fase = .listo
                alTerminar(self)
            } catch is CancellationError {
                return
            } catch let error as LanguageModelSession.GenerationError {
                self.fase = .error(Self.mensaje(error))
            } catch {
                self.fase = .error(L("No se ha podido terminar. Inténtalo otra vez.", "Couldn't finish. Please try again.", "Non è stato possibile finire. Riprova."))
            }
        }
    }

    static func leer(_ imagenes: [UIImage], escrito: String, progreso: (Int, Int) -> Void) async throws -> String {
        var partes: [String] = []
        for (i, img) in imagenes.enumerated() {
            try Task.checkCancellation()
            progreso(i + 1, imagenes.count)
            let texto = try await LectorTexto.leer(img)
            if !texto.isEmpty {
                partes.append(imagenes.count > 1 ? "[\(L("Foto", "Photo", "Foto")) \(i + 1)]\n\(texto)" : texto)
            }
        }
        let escrito = escrito.trimmingCharacters(in: .whitespacesAndNewlines)
        if !escrito.isEmpty { partes.append(escrito) }
        return partes.joined(separator: "\n\n")
    }

    static var caracteresMaximos: Int {
        #if compiler(>=6.3)
        let contexto = SystemLanguageModel.default.contextSize
        #else

        let contexto = 4096
        #endif
        return max(3000, (contexto - 1500) * 3)
    }

    static func ajustar(_ texto: String, cortarSinResumir: Bool = false, maximo: Int = TrabajoIA.caracteresMaximos,
                        progreso: ((Int, Int) -> Void)? = nil) async throws -> String {
        guard texto.count > maximo else { return texto }
        if cortarSinResumir { return String(texto.prefix(maximo)) }

        let trozos = Self.trocear(texto, tamano: Int(Double(maximo) * 0.8))
        var apuntes: [String] = []
        for (i, trozo) in trozos.enumerated() {
            try Task.checkCancellation()
            progreso?(i + 1, trozos.count)
            let sesion = LanguageModelSession(
                model: SystemLanguageModel(guardrails: .permissiveContentTransformations),
                instructions: L("Extraes apuntes de estudio. Escribe en español.", "You extract study notes. Write in English.", "Estrai appunti di studio. Scrivi in italiano.")
            )
            let r = try await sesion.respond(
                to: L("Escribe en viñetas breves las ideas, datos, fechas, fórmulas y nombres importantes de este fragmento. Solo viñetas.\n\nFRAGMENTO:\n",
                      "Write short bullet points with the important ideas, facts, dates, formulas and names in this passage. Bullets only.\n\nPASSAGE:\n",
                      "Scrivi in punti brevi le idee, i dati, le date, le formule e i nomi importanti di questo brano. Solo punti.\n\nBRANO:\n") + trozo,
                options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 450)
            )
            apuntes.append(r.content)
        }
        return String(apuntes.joined(separator: "\n").prefix(maximo))
    }

    private static func trocear(_ texto: String, tamano: Int) -> [String] {
        var trozos: [String] = []
        var actual = ""
        for parrafo in texto.components(separatedBy: "\n") {
            if actual.count + parrafo.count > tamano, !actual.isEmpty {
                trozos.append(actual)
                actual = ""
            }
            if parrafo.count > tamano {
                var resto = Substring(parrafo)
                while !resto.isEmpty {
                    trozos.append(String(resto.prefix(tamano)))
                    resto = resto.dropFirst(tamano)
                }
            } else {
                actual += parrafo + "\n"
            }
        }
        if !actual.isEmpty { trozos.append(actual) }
        return trozos
    }

    private static func tokensRespuesta(_ p: Peticion) -> Int {
        switch p.tipo {
        case .revisar: p.modo == .corregir ? 900 : 450
        case .explicar: 850
        case .esquema, .evaluar: 800
        case .resumen:
            switch p.longitud {
            case .corto: 350
            case .normal: 650
            case .completo: 950
            }
        }
    }

    private static func instrucciones(_ p: Peticion) -> String {
        let curso = p.curso.isEmpty ? "" : L(" de \(p.curso)", " in \(p.curso)", " di \(p.curso)")
        return L(
            "Eres Hoot, un tutor paciente que ayuda a estudiantes\(curso) a aprender y preparar exámenes. Escribe siempre en español, con frases cortas y claras, tuteando al alumno. Usa solo la información del texto que te dan y no inventes datos. Formato Markdown: títulos con ##, listas con -, y los términos importantes en **negrita**.",
            "You are Hoot, a patient tutor who helps students\(curso) learn and prepare for tests. Always write in English, with short, clear sentences, speaking directly to the student. Use only the information in the text you're given and never make up facts. Markdown format: headings with ##, lists with -, and key terms in **bold**.",
            "Sei Hoot, un tutor paziente che aiuta gli studenti\(curso) a imparare e a prepararsi alle verifiche. Scrivi sempre in italiano, con frasi brevi e chiare, dando del tu allo studente. Usa solo le informazioni del testo che ti danno e non inventare dati. Formato Markdown: titoli con ##, elenchi con -, e i termini importanti in **grassetto**."
        )
    }

    private static func peticion(_ p: Peticion, material: String) -> String {
        let materia = p.asignatura.map { L(" de \($0)", " in \($0)", " di \($0)") } ?? ""
        let tema = p.tema.trimmingCharacters(in: .whitespaces)
        let sobre = tema.isEmpty ? "" : L(" sobre «\(tema)»", " about “\(tema)”", " su «\(tema)»")
        switch p.tipo {
        case .revisar:
            let ejercicio = p.ejercicio.trimmingCharacters(in: .whitespaces)
            if p.modo == .comprobar {
                return L(
                    """
                    El alumno quiere saber si ha hecho bien este ejercicio\(materia): «\(ejercicio)». Abajo está el texto de sus fotos, con el enunciado y su respuesta. Comprueba si es correcto. NO le des la solución.
                    Responde así:
                    ## Resultado
                    Una línea: Correcto, Tiene errores o Incompleto.
                    ## Dónde mirar
                    Señala el primer paso o la parte que está mal, sin corregirla.
                    ## Pista
                    Una pista para que lo arregle solo.

                    TEXTO DE LAS FOTOS:
                    \(material)
                    """,
                    """
                    The student wants to know if this exercise\(materia) is right: “\(ejercicio)”. Below is the text from their photos, with the question and their answer. Check whether it's correct. Do NOT give the solution.
                    Answer like this:
                    ## Result
                    One line: Correct, Has mistakes or Incomplete.
                    ## Where to look
                    Point to the first step or part that's wrong, without fixing it.
                    ## Hint
                    One hint so they can fix it on their own.

                    TEXT FROM THE PHOTOS:
                    \(material)
                    """,
                    """
                    Lo studente vuole sapere se ha fatto bene questo esercizio\(materia): «\(ejercicio)». Qui sotto c'è il testo delle sue foto, con la consegna e la sua risposta. Controlla se è corretto. NON dargli la soluzione.
                    Rispondi così:
                    ## Risultato
                    Una riga: Corretto, Ha degli errori o Incompleto.
                    ## Dove guardare
                    Indica il primo passaggio o la parte sbagliata, senza correggerla.
                    ## Suggerimento
                    Un suggerimento per correggerlo da solo.

                    TESTO DELLE FOTO:
                    \(material)
                    """
                )
            }
            return L(
                """
                Corrige este ejercicio\(materia): «\(ejercicio)». Abajo está el texto de las fotos, con el enunciado y la respuesta del alumno.
                Responde así:
                ## Resultado
                Una línea: Correcto, Tiene errores o Incompleto.
                ## Errores
                Lista de errores. Si no hay, dilo.
                ## Solución paso a paso
                Explicada para que la entienda.
                ## Para la próxima
                Un consejo breve.

                TEXTO DE LAS FOTOS:
                \(material)
                """,
                """
                Correct this exercise\(materia): “\(ejercicio)”. Below is the text from the photos, with the question and the student's answer.
                Answer like this:
                ## Result
                One line: Correct, Has mistakes or Incomplete.
                ## Mistakes
                A list of mistakes. If there are none, say so.
                ## Step-by-step solution
                Explained so they understand it.
                ## Next time
                One short tip.

                TEXT FROM THE PHOTOS:
                \(material)
                """,
                """
                Correggi questo esercizio\(materia): «\(ejercicio)». Qui sotto c'è il testo delle foto, con la consegna e la risposta dello studente.
                Rispondi così:
                ## Risultato
                Una riga: Corretto, Ha degli errori o Incompleto.
                ## Errori
                Elenco degli errori. Se non ce ne sono, dillo.
                ## Soluzione passo per passo
                Spiegata in modo che la capisca.
                ## La prossima volta
                Un consiglio breve.

                TESTO DELLE FOTO:
                \(material)
                """
            )
        case .resumen:
            let largo: String = switch p.longitud {
            case .corto: L("breve (unas 150 palabras)", "short (about 150 words)", "breve (circa 150 parole)")
            case .normal: L("de unas 300 palabras", "of about 300 words", "di circa 300 parole")
            case .completo: L("detallado (unas 500 palabras)", "detailed (about 500 words)", "dettagliato (circa 500 parole)")
            }
            return L(
                """
                Haz un resumen \(largo) para estudiar el tema\(materia)\(sobre). Tiene que ayudar a aprobar el examen.
                Estructura:
                ## Idea principal
                Dos o tres frases.
                ## Lo más importante
                Viñetas con los conceptos, fechas, fórmulas y nombres clave en negrita.
                ## Palabras clave
                - **término**: definición breve
                ## Preguntas de repaso
                De 3 a 5 preguntas que podrían salir en el examen.

                TEXTO:
                \(material)
                """,
                """
                Write a \(largo) summary to study this topic\(materia)\(sobre). It should help pass the test.
                Structure:
                ## Main idea
                Two or three sentences.
                ## Key points
                Bullets with the key concepts, dates, formulas and names in bold.
                ## Key terms
                - **term**: short definition
                ## Review questions
                3 to 5 questions that could be on the test.

                TEXT:
                \(material)
                """,
                """
                Scrivi un riassunto \(largo) per studiare l'argomento\(materia)\(sobre). Deve aiutare a superare la verifica.
                Struttura:
                ## Idea principale
                Due o tre frasi.
                ## Le cose più importanti
                Punti con i concetti, le date, le formule e i nomi chiave in grassetto.
                ## Parole chiave
                - **termine**: definizione breve
                ## Domande di ripasso
                Da 3 a 5 domande che potrebbero uscire nella verifica.

                TESTO:
                \(material)
                """
            )
        case .explicar:
            let duda = p.tema.trimmingCharacters(in: .whitespaces)
            let que = duda.isEmpty ? "" : L(" Lo que no entiende: «\(duda)».", " What they don't understand: “\(duda)”.", " Cosa non capisce: «\(duda)».")
            return L(
                """
                El alumno no entiende esto\(materia) y quiere que se lo expliques.\(que) Explícalo como un buen profesor: sencillo, paso a paso y con un ejemplo. Si es un ejercicio, explica cómo se hace con un ejemplo parecido, pero NO lo resuelvas: que lo haga él.
                Estructura:
                ## En pocas palabras
                Una o dos frases.
                ## Paso a paso
                Lista numerada.
                ## Un ejemplo
                Uno parecido, resuelto.
                ## Para comprobar que lo entiendes
                Una pregunta corta.

                TEXTO DE LAS FOTOS:
                \(material)
                """,
                """
                The student doesn't understand this\(materia) and wants you to explain it.\(que) Explain it like a good teacher: simple, step by step and with an example. If it's an exercise, explain how to do it with a similar example, but do NOT solve it: they should do it themselves.
                Structure:
                ## In a nutshell
                One or two sentences.
                ## Step by step
                A numbered list.
                ## An example
                A similar one, solved.
                ## Check you understand
                One short question.

                TEXT FROM THE PHOTOS:
                \(material)
                """,
                """
                Lo studente non capisce questo\(materia) e vuole che glielo spieghi.\(que) Spiegalo come un bravo professore: semplice, passo per passo e con un esempio. Se è un esercizio, spiega come si fa con un esempio simile, ma NON risolverlo: deve farlo lui.
                Struttura:
                ## In poche parole
                Una o due frasi.
                ## Passo per passo
                Elenco numerato.
                ## Un esempio
                Uno simile, risolto.
                ## Per verificare che hai capito
                Una domanda breve.

                TESTO DELLE FOTO:
                \(material)
                """
            )
        case .esquema, .evaluar:
            return L(
                """
                Haz un esquema para estudiar el tema\(materia)\(sobre). Empieza con el título del tema con ##. Después, una lista con viñetas de dos o tres niveles (dos espacios de sangría por nivel), agrupada por apartados. Cada línea, una idea corta de diez palabras como mucho. Los términos clave en negrita.

                TEXTO:
                \(material)
                """,
                """
                Make an outline to study this topic\(materia)\(sobre). Start with the topic title as ##. Then a bulleted list with two or three levels (two spaces of indentation per level), grouped by section. Each line is one short idea of ten words at most. Key terms in bold.

                TEXT:
                \(material)
                """,
                """
                Fai uno schema per studiare l'argomento\(materia)\(sobre). Inizia con il titolo dell'argomento con ##. Poi un elenco puntato di due o tre livelli (due spazi di rientro per livello), diviso in sezioni. Ogni riga è un'idea breve di massimo dieci parole. I termini chiave in grassetto.

                TESTO:
                \(material)
                """
            )
        }
    }

    static func mensaje(_ error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .exceededContextWindowSize:
            L("Hay demasiado texto. Prueba con menos fotos.", "There's too much text. Try fewer photos.", "C'è troppo testo. Prova con meno foto.")
        case .guardrailViolation, .refusal:
            L("No puedo ayudar con este contenido.", "I can't help with this content.", "Non posso aiutarti con questo contenuto.")
        case .unsupportedLanguageOrLocale:
            DisponibilidadIA.idiomaNoDisponible.mensaje
        case .assetsUnavailable:
            DisponibilidadIA.preparando.mensaje
        case .rateLimited, .concurrentRequests:
            L("Espera un momento y vuelve a probar.", "Wait a moment and try again.", "Aspetta un momento e riprova.")
        default:
            L("No se ha podido terminar. Inténtalo otra vez.", "Couldn't finish. Please try again.", "Non è stato possibile finire. Riprova.")
        }
    }
}

enum EdadIA {
    static func minima(region: String) -> Int {
        switch region {
        case "IT", "SM", "VA", "ES", "AT", "BG", "CY", "LT": 14
        case "FR", "GR", "CZ", "SI": 15
        case "DE", "NL", "IE", "HU", "LU", "SK", "HR", "RO", "PL", "CH": 16
        case "GB", "US", "BE", "DK", "EE", "FI", "LV", "MT", "PT", "SE", "NO": 13
        default: 14
        }
    }

    static func hacePermiso(perfil: Perfil, region: String) -> Bool {
        guard perfil.rol == .estudiante, let edad = perfil.edad else { return false }
        return edad < minima(region: region)
    }
}
