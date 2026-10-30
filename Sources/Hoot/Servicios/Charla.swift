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

    private(set) var ultimaRespuesta = ""
    var leyendoFoto = false

    var fotosLeidas = (actual: 0, total: 0)
    var aviso: String?

    let origen: Origen
    let titulo: String
    let asignatura: String?
    let asignaturaID: UUID?
    let curso: String

    var porVoz = false
    private var tareaIA: TareaIA { porVoz ? .voz : .charla }

    @ObservationIgnored var alResponder: (([MensajeCharla]) -> Void)?
    @ObservationIgnored private var trozos: [TrozoMaterial]
    @ObservationIgnored private var tarea: Task<Void, Never>?

    @ObservationIgnored private var fotosClaude: [UUID: [Data]] = [:]
    @ObservationIgnored private var fotoNueva = false
    @ObservationIgnored private var solucion = ""

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
            var grandes: [Data] = []
            for (i, imagen) in imagenes.enumerated() {
                fotosLeidas = (i + 1, imagenes.count)
                let reducida = imagen.reducida(a: 2400)
                textos.append((try? await LectorTexto.leer(reducida)) ?? "")
                if let m = reducida.reducida(a: 480).jpegData(compressionQuality: 0.7) { miniaturas.append(m) }
                if ClaudeIA.activa, let g = reducida.reducida(a: 1568).jpegData(compressionQuality: 0.8) { grandes.append(g) }
            }
            leyendoFoto = false
            let varias = imagenes.count > 1
            var nuevos: [TrozoMaterial] = []
            for (i, t) in textos.enumerated() where t.trimmingCharacters(in: .whitespacesAndNewlines).count > 15 {
                let etiqueta = varias ? L("Tu foto \(i + 1)", "Your photo \(i + 1)", "La tua foto \(i + 1)") : L("Tu foto", "Your photo", "La tua foto")
                nuevos += BuscarMaterial.trozos(t, etiqueta: etiqueta)
            }

            guard !nuevos.isEmpty || !grandes.isEmpty else {
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
            let mensaje = MensajeCharla(quien: .yo, texto: p, foto: miniaturas.first, masFotos: Array(miniaturas.dropFirst()))
            if !grandes.isEmpty {
                fotosClaude[mensaje.id] = grandes
                fotoNueva = true
                solucion = ""
            }
            mensajes.append(mensaje)
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

        let ultimo = mensajes.last { $0.quien == .yo }?.texto ?? ""
        if MotorIA.quien(tareaIA) == .claude && (DisponibilidadIA.apple != .lista || encargo != nil || !ClaudeIA.trivial(ultimo)) {
            responderConClaude(consulta: consulta, encargo: encargo)
            return
        }
        let apple = ClaudeIA.activa ? DisponibilidadIA.apple : DisponibilidadIA.actual
        guard apple == .lista else {
            aviso = apple.mensaje
            return
        }
        aviso = nil
        escribiendo = true
        parcial = ""
        ultimaRespuesta = ""

        let anterior = mensajes.dropLast().last { $0.quien == .hoot }?.texto ?? ""
        let (elegidos, encontrado) = BuscarMaterial.relevantes(consulta + " " + anterior, en: trozos, maximo: 2400)
        let fuente = encontrado ? (elegidos.first?.etiqueta ?? "") : ""
        let historial = Array(mensajes.suffix(7))
        let instrucciones = Self.instrucciones(titulo: titulo, asignatura: asignatura, curso: curso)

        let alumno = mensajes.last?.quien == .yo ? mensajes.last?.texto ?? "" : ""
        let preguntaHoot = encargo == nil ? mensajes.dropLast().last.flatMap { m -> String? in
            guard m.quien == .hoot, let r = ["Ahora tú:", "Your turn:", "Ora tu:", "Ora tocca a te:"].lazy
                .compactMap({ m.texto.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) }).first else { return nil }
            return m.texto[r.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        } : nil
        tarea = Task { [weak self] in
            guard let self else { return }
            do {

                var veredicto: Veredicto?
                var encargoFinal = encargo
                if let preguntaHoot, !alumno.isEmpty {
                    let c = try await Self.corregir(pregunta: preguntaHoot, respuesta: alumno, material: elegidos)
                    veredicto = c.veredicto
                    encargoFinal = Self.encargoCorregido(c, alumno: alumno)
                }
                try Task.checkCancellation()
                let prompt = Self.peticion(material: elegidos, historial: historial, encargo: encargoFinal)
                let sesion = LanguageModelSession(model: .default, instructions: instrucciones)
                let flujo = sesion.streamResponse(to: prompt, options: GenerationOptions(temperature: 0.4, maximumResponseTokens: 700))
                for try await p in flujo {
                    try Task.checkCancellation()
                    self.parcial = Self.conVeredicto(p.content, veredicto)
                }
                let (respuesta, deVuelta) = Self.partir(self.parcial)
                var nuevos = [MensajeCharla(quien: .hoot, texto: respuesta, fuente: fuente)]
                if let deVuelta { nuevos.append(MensajeCharla(quien: .hoot, texto: deVuelta)) }
                self.mensajes += nuevos
                self.ultimaRespuesta = self.parcial
                self.parcial = ""
                self.escribiendo = false
                ClaudeIA.compartida.apuntarApple(self.tareaIA)
                self.alResponder?(nuevos)
            } catch is CancellationError {
                return
            } catch let error as LanguageModelSession.GenerationError {
                self.parcial = ""
                self.escribiendo = false
                if case .guardrailViolation = error {
                    self.aviso = L("De eso mejor pregúntale a tu profe.", "Better ask your teacher about that one.", "Di questo è meglio parlare con il tuo prof.")
                } else {
                    Registro.error(error, en: "charla.apple")
                    self.aviso = TrabajoIA.mensaje(error)
                }
            } catch {
                self.parcial = ""
                self.escribiendo = false
                Registro.error(error, en: "charla.apple")
                self.aviso = L("Hoot se ha liado. Pregúntaselo otra vez.", "Hoot got muddled. Ask again.", "Hoot si è confuso. Chiediglielo di nuovo.")
            }
        }
    }

    enum Veredicto: Equatable { case bien, casi, mal }

    struct Correccion: Equatable {
        var buena: String
        var veredicto: Veredicto
    }

    static func corregir(pregunta: String, respuesta: String, material: [TrozoMaterial]) async throws -> Correccion {
        let trozos = material.map { "[\($0.etiqueta)]\n\($0.texto)" }.joined(separator: "\n\n")
        let sesion = LanguageModelSession(model: .default, instructions: L(
            "Corriges con mucho cuidado la respuesta de un alumno. Contestas solo con las dos líneas que se piden.",
            "You carefully mark a student's answer. You reply only with the two lines asked for.",
            "Correggi con molta attenzione la risposta di uno studente. Rispondi solo con le due righe richieste."))
        let prompt = L(
            "MATERIAL:\n\(trozos.isEmpty ? "(sin material)" : trozos)\n\nPREGUNTA: \(pregunta)\nRESPUESTA DEL ALUMNO: \(respuesta)\n\nPiensa tú la respuesta correcta antes de mirar la del alumno. Escribe exactamente:\nCORRECTA: (la respuesta correcta, corta)\nVEREDICTO: bien, casi o mal (bien si significa lo mismo que la correcta)",
            "MATERIAL:\n\(trozos.isEmpty ? "(no material)" : trozos)\n\nQUESTION: \(pregunta)\nSTUDENT'S ANSWER: \(respuesta)\n\nWork out the correct answer yourself before looking at the student's. Write exactly:\nCORRECT: (the correct answer, short)\nVERDICT: right, almost or wrong (right if it means the same as the correct one)",
            "MATERIALE:\n\(trozos.isEmpty ? "(nessun materiale)" : trozos)\n\nDOMANDA: \(pregunta)\nRISPOSTA DELLO STUDENTE: \(respuesta)\n\nPensa tu la risposta corretta prima di guardare quella dello studente. Scrivi esattamente:\nCORRETTA: (la risposta corretta, breve)\nGIUDIZIO: bene, quasi o male (bene se significa lo stesso della corretta)")
        let r = try await sesion.respond(to: prompt, options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 160))
        return leerCorreccion(r.content, alumno: respuesta)
    }

    static func leerCorreccion(_ texto: String, alumno: String) -> Correccion {
        var buena = ""
        var veredicto = Veredicto.casi
        for linea in texto.components(separatedBy: .newlines) {
            let l = linea.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
            guard let dos = l.firstIndex(of: ":") else { continue }
            let clave = l[..<dos].folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).trimmingCharacters(in: .whitespaces)
            let valor = l[l.index(after: dos)...].trimmingCharacters(in: .whitespaces)
            if ["correcta", "correct", "corretta"].contains(clave) { buena = valor }
            if ["veredicto", "verdict", "giudizio"].contains(clave) {
                let v = valor.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                if v.hasPrefix("bien") || v.hasPrefix("right") || v.hasPrefix("bene") { veredicto = .bien }
                else if v.hasPrefix("mal") || v.hasPrefix("wrong") { veredicto = .mal }
                else { veredicto = .casi }
            }
        }
        if !buena.isEmpty, coinciden(alumno, buena) { veredicto = .bien }
        return Correccion(buena: buena, veredicto: veredicto)
    }

    static func encargoCorregido(_ c: Correccion, alumno: String) -> String {
        let buena = c.buena.isEmpty ? "" : L(" La respuesta buena es «\(c.buena)».", " The right answer is “\(c.buena)”.", " La risposta giusta è «\(c.buena)».")
        return switch c.veredicto {
        case .bien: L("El alumno ha contestado «\(alumno)» a tu pregunta y está bien.\(buena) Díselo con un detalle útil, sin repetir «bien», y si viene a cuento, añade una línea que empiece por «Ahora tú:» con otra pregunta corta.",
                      "The student answered “\(alumno)” to your question and it's right.\(buena) Tell them with one useful detail, without saying “right” again, and if it fits, add a line starting with “Your turn:” with another short question.",
                      "Lo studente ha risposto «\(alumno)» alla tua domanda ed è giusto.\(buena) Diglielo con un dettaglio utile, senza ripetere «bene», e se ha senso aggiungi una riga che comincia con «Ora tu:» con un'altra domanda breve.")
        case .casi: L("El alumno ha contestado «\(alumno)» a tu pregunta y está casi bien.\(buena) Explícale qué le falta, sin decir «casi», y si viene a cuento, añade una línea que empiece por «Ahora tú:» con otra pregunta corta.",
                      "The student answered “\(alumno)” to your question and it's almost right.\(buena) Explain what's missing, without saying “almost”, and if it fits, add a line starting with “Your turn:” with another short question.",
                      "Lo studente ha risposto «\(alumno)» alla tua domanda ed è quasi giusto.\(buena) Spiegagli cosa manca, senza dire «quasi», e se ha senso aggiungi una riga che comincia con «Ora tu:» con un'altra domanda breve.")
        case .mal: L("El alumno ha contestado «\(alumno)» a tu pregunta y no está bien.\(buena) Explícale por qué con calma, sin decir «no», y si viene a cuento, añade una línea que empiece por «Ahora tú:» con otra pregunta corta.",
                     "The student answered “\(alumno)” to your question and it's not right.\(buena) Explain why calmly, without saying “no”, and if it fits, add a line starting with “Your turn:” with another short question.",
                     "Lo studente ha risposto «\(alumno)» alla tua domanda e non è giusto.\(buena) Spiegagli perché con calma, senza dire «no», e se ha senso aggiungi una riga che comincia con «Ora tu:» con un'altra domanda breve.")
        }
    }

    static func conVeredicto(_ texto: String, _ v: Veredicto?) -> String {
        guard let v else { return texto }
        let original = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return "" }
        let t = sinVeredicto(original)
        let palabra = switch v {
        case .bien: L("Bien.", "Right.", "Bene.")
        case .casi: L("Casi.", "Almost.", "Quasi.")
        case .mal: L("No.", "No.", "No.")
        }
        return t.isEmpty ? palabra : palabra + " " + t
    }

    static func coinciden(_ a: String, _ b: String) -> Bool {
        func limpio(_ t: String) -> String {
            t.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
        }
        let x = limpio(a), y = limpio(b)
        guard !x.isEmpty, !y.isEmpty else { return false }
        if x == y { return true }
        let (corto, largo) = x.count < y.count ? (x, y) : (y, x)
        return corto.count >= 4 && Double(corto.count) >= Double(largo.count) * 0.6 && (" " + largo + " ").contains(" " + corto + " ")
    }

    static func sinVeredicto(_ t: String) -> String {
        let frases = ["no esta bien", "esta bien", "no es correcto", "es correcto", "no es correcta", "es correcta", "bien", "casi",
                      "correcto", "exacto", "perfecto", "muy bien", "that's right", "not quite", "right", "almost", "correct",
                      "non e giusto", "e giusto", "giusto", "bene", "quasi", "esatto", "no"]
        var r = Substring(t)
        while let c = r.first, c == "¡" || c == " " { r = r.dropFirst() }
        var quitado = true
        while quitado {
            quitado = false
            let sinTildes = String(r).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            for f in frases.sorted(by: { $0.count > $1.count }) where sinTildes.hasPrefix(f) {
                let resto = r.dropFirst(f.count)
                if resto.allSatisfy({ ",.:;!¡ ".contains($0) }) { return "" }
                guard let c = resto.first, !c.isLetter else { continue }
                r = resto
                while let c = r.first, ",.:;!¡ ".contains(c) { r = r.dropFirst() }
                quitado = !r.isEmpty
                break
            }
            if r.isEmpty { return "" }
        }
        guard let primera = r.first else { return "" }
        return primera.uppercased() + r.dropFirst()
    }

    private func responderConClaude(consulta: String, encargo: String?) {
        let ia = ClaudeIA.compartida
        let tareaIA = tareaIA
        aviso = nil
        escribiendo = true
        parcial = ""
        ultimaRespuesta = ""
        let (elegidos, encontrado) = BuscarMaterial.relevantes(consulta, en: trozos, maximo: 6000)
        let fuente = encontrado ? (elegidos.first?.etiqueta ?? "") : ""
        let delAlumno = mensajes.filter { $0.quien == .yo }.map { ClaudeIA.sinTildes($0.texto) }

        let sonnetYa = delAlumno.count >= 2 && delAlumno.suffix(2).allSatisfy(ClaudeIA.noEntiende)
        let puedeSubir = MotorIA.puedeSubir(tareaIA, conFotos: fotoNueva || !fotosClaude.isEmpty)
        fotoNueva = false
        let sistema = Self.instrucciones(titulo: titulo, asignatura: asignatura, curso: curso) + "\n\n" + Pedagogia.reglas(tareaIA)
            + (elegidos.isEmpty ? "" : "\n\nMATERIAL:\n" + elegidos.map { "[\($0.etiqueta)]\n\($0.texto)" }.joined(separator: "\n\n"))
            + (solucion.isEmpty ? "" : "\n\nSOLUCIÓN SECRETA (ya la tienes resuelta; no se la des):\n" + solucion)
        var historial = mensajes.suffix(16).map { m in
            ClaudeIA.Mensaje(deHoot: m.quien == .hoot, texto: m.texto.isEmpty && m.quien == .yo ? L("(foto)", "(photo)", "(foto)") : m.texto,
                             fotos: fotosClaude[m.id] ?? [])
        }
        if let encargo { historial.append(ClaudeIA.Mensaje(deHoot: false, texto: encargo)) }
        tarea = Task { [weak self] in
            guard let self else { return }
            do {
                let (texto, modelo) = try await ia.responderBien(tarea: tareaIA, sistema: sistema, mensajes: historial,
                                                                 maximo: tareaIA == .voz ? 2000 : 4000, esfuerzo: MotorIA.esfuerzo(tareaIA),
                                                                 sonnetYa: sonnetYa, puedeSubir: puedeSubir) { t in
                    self.parcial = Self.sinSolucion(t)
                }
                try Task.checkCancellation()
                if let s = Self.solucionDe(texto) { self.solucion = s }
                let (respuesta, deVuelta) = Self.partir(Self.sinSolucion(texto))
                let etiqueta = [fuente, ia.verModelo ? modelo.nombre : ""].filter { !$0.isEmpty }.joined(separator: " · ")
                var nuevos = [MensajeCharla(quien: .hoot, texto: respuesta, fuente: etiqueta)]
                if let deVuelta { nuevos.append(MensajeCharla(quien: .hoot, texto: deVuelta)) }
                self.mensajes += nuevos
                self.ultimaRespuesta = self.parcial
                self.parcial = ""
                self.escribiendo = false
                self.alResponder?(nuevos)
            } catch is CancellationError {
                return
            } catch {
                self.parcial = ""
                self.escribiendo = false
                Registro.error(error, en: tareaIA.rawValue)
                self.aviso = MotorIA.mensaje(error, siNo: L("Hoot se ha liado. Pregúntaselo otra vez.", "Hoot got muddled. Ask again.", "Hoot si è confuso. Chiediglielo di nuovo."))
            }
        }
    }

    func cortarRespuesta(dicho: String) {
        let d = dicho.trimmingCharacters(in: .whitespacesAndNewlines)
        if escribiendo {

            cancelar()
            if !d.isEmpty { mensajes.append(MensajeCharla(quien: .hoot, texto: d + "…")) }
            return
        }
        let tanda = mensajes.reversed().prefix { $0.quien == .hoot }.count
        guard tanda > 0 else { return }
        let fuente = mensajes[mensajes.count - tanda].fuente
        mensajes.removeLast(tanda)
        if !d.isEmpty { mensajes.append(MensajeCharla(quien: .hoot, texto: d + "…", fuente: fuente)) }
    }

    func retomarPregunta() -> String {
        cancelar()
        guard let ultimo = mensajes.last, ultimo.quien == .yo, ultimo.fotos.isEmpty else { return "" }
        mensajes.removeLast()
        return ultimo.texto
    }

    static func sinSolucion(_ t: String) -> String {
        var r = t
        while let a = r.range(of: "<solucion>") {
            if let b = r.range(of: "</solucion>", range: a.upperBound..<r.endIndex) {
                r.removeSubrange(a.lowerBound..<b.upperBound)
            } else {
                r.removeSubrange(a.lowerBound..<r.endIndex)
            }
        }

        if let menor = r.lastIndex(of: "<"), "<solucion>".hasPrefix(r[menor...]) { r.removeSubrange(menor...) }
        return r.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func solucionDe(_ t: String) -> String? {
        guard let a = t.range(of: "<solucion>"), let b = t.range(of: "</solucion>", range: a.upperBound..<t.endIndex) else { return nil }
        return String(t[a.upperBound..<b.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func partir(_ texto: String) -> (respuesta: String, deVuelta: String?) {
        let limpio = texto.replacingOccurrences(of: "**", with: "")

        let r = ["Ahora tú:", "Your turn:", "Ora tu:", "Ora tocca a te:"].lazy
            .compactMap { limpio.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) }
            .min { $0.lowerBound < $1.lowerBound }
        guard let r else {
            return (limpio.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }
        let marca = String(limpio[r])
        let antes = limpio[..<r.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let despues = limpio[r.lowerBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        return (antes, despues.count > marca.count + 2 ? despues : nil)
    }

    private static func instrucciones(titulo: String, asignatura: String?, curso: String) -> String {
        let deCurso = curso.isEmpty ? "" : L(" de \(curso)", " in \(curso)", " di \(curso)")
        let materia = asignatura.map { L(", de \($0)", ", in \($0)", ", di \($0)") } ?? ""
        return L(
            "Eres Hoot, un lobo gris que ayuda a estudiar a un alumno\(deCurso). Habláis del tema «\(titulo)»\(materia). Escribes como en un chat de mensajes: frases cortas, tuteas, con un poco de humor y sin signos de exclamación. Usa primero el MATERIAL y no te inventes datos. Si lo que pregunta no sale en él, dilo en pocas palabras («Esto no sale en tu material, pero te lo explico») y ayúdale igual. No hagas sus ejercicios ni sus deberes: si te pide una solución, explícale cómo se hace con un ejemplo parecido y dale una pista. Ayúdale con lo que te pida, aunque sea de otro tema o de otra asignatura, y no le devuelvas al tema si no quiere. Nunca te rías de él ni de lo que sabe. Contesta en el idioma en que te escribe (si te escribe en italiano, en italiano); si no se sabe, en español.",
            "You are Hoot, a grey wolf who helps a student\(deCurso) study. You're talking about “\(titulo)”\(materia). You write like in a messaging chat: short sentences, a bit of humour and no exclamation marks. Use the MATERIAL first and never make facts up. If what they ask isn't in it, say so briefly (“That's not in your material, but here goes”) and help them anyway. Don't do their exercises or homework: if they ask for a solution, show how it's done with a similar example and give a hint. Help with whatever they ask, even if it's another topic or subject, and don't steer them back unless they want to. Never make fun of them or of what they know. Answer in the language they write in (if they write in Italian, in Italian); if it isn't clear, in English.",
            "Sei Hoot, un lupo grigio che aiuta a studiare uno studente\(deCurso). Parlate dell'argomento «\(titulo)»\(materia). Scrivi come in una chat di messaggi: frasi brevi, dai del tu, con un po' di umorismo e senza punti esclamativi. Usa prima il MATERIALE e non inventare dati. Se quello che chiede non c'è, dillo in poche parole («Questo non c'è nel tuo materiale, ma te lo spiego») e aiutalo lo stesso. Non fare i suoi esercizi né i compiti: se ti chiede una soluzione, spiegagli come si fa con un esempio simile e dagli un suggerimento. Aiutalo con quello che ti chiede, anche se è un altro argomento o un'altra materia, e non riportarlo all'argomento se non vuole. Non prenderlo mai in giro né per quello che sa. Rispondi nella lingua in cui ti scrive (se ti scrive in spagnolo, in spagnolo); se non si capisce, in italiano."
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

            \(pedido) Escribe como Hoot, en 2 a 4 frases cortas; si te pide que le expliques algo entero, hasta 8, por partes y con un ejemplo de cada cosa. Si viene a cuento, añade al final una línea que empiece por «Ahora tú:» con una pregunta corta para comprobar que lo ha entendido.
            """,
            """
            MATERIAL:
            \(trozos.isEmpty ? "(no material)" : trozos)

            THE CHAT SO FAR:
            \(charla)

            \(pedido) Write as Hoot, in 2 to 4 short sentences; if they ask you to explain something whole, up to 8, in parts with an example of each. If it fits, end with a line starting with “Your turn:” with a short question to check they've understood.
            """,
            """
            MATERIALE:
            \(trozos.isEmpty ? "(nessun materiale)" : trozos)

            LA CHAT FINO A ORA:
            \(charla)

            \(pedido) Scrivi come Hoot, in 2-4 frasi brevi; se ti chiede di spiegargli qualcosa per intero, fino a 8, per parti e con un esempio per ognuna. Se ha senso, finisci con una riga che comincia con «Ora tu:» con una domanda breve per verificare che abbia capito.
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
