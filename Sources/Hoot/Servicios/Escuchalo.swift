import AVFoundation
import FoundationModels
import MediaPlayer
import SwiftUI

enum PreparadorAudio {

    enum Fallo: LocalizedError {
        case sinIA(String)
        case sinMaterial(String)

        var errorDescription: String? {
            switch self {
            case .sinIA(let m), .sinMaterial(let m): m
            }
        }
    }

    static func preparar(_ t: Tema, asignatura: String?, curso: String) async throws -> AudioTema {
        let texto = t.textoLeido.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texto.isEmpty else {
            throw Fallo.sinMaterial(L("Este tema aún no tiene material. Dale fotos o un PDF.", "This topic has no material yet. Give it photos or a PDF.",
                                      "Questo argomento non ha ancora materiale. Dagli foto o un PDF."))
        }
        let huella = texto.huellaEstable
        if let a = t.audio, a.huella == huella, !a.resumen.isEmpty { return a }
        guard DisponibilidadIA.actual == .lista else { throw Fallo.sinIA(DisponibilidadIA.actual.mensaje) }
        let material = try await TrabajoIA.ajustar(texto, maximo: TrabajoIA.caracteresMaximos - 1200)
        let r = try await MotorIA.texto(.escuchalo, instrucciones: instrucciones(curso: curso),
                                        prompt: peticion(t.nombre, asignatura: asignatura, material: material), maximo: 700, temperatura: 0.3)
        return partir(r, huella: huella)
    }

    private static func instrucciones(curso: String) -> String {
        let deCurso = curso.isEmpty ? "" : L(" de \(curso)", " in \(curso)", " di \(curso)")
        return L("Eres Hoot, el lobo de una app de estudio. Preparas audios de repaso para un alumno\(deCurso), para escucharlos de camino al colegio. Usa solo el MATERIAL y no inventes nada. Escribe en español.",
                 "You are Hoot, the wolf of a study app. You prepare review audio for a student\(deCurso) to listen to on the way to school. Use only the MATERIAL and never make anything up. Write in English.",
                 "Sei Hoot, il lupo di un'app di studio. Prepari audio di ripasso per uno studente\(deCurso), da ascoltare andando a scuola. Usa solo il MATERIALE e non inventare niente. Scrivi in italiano.")
    }

    private static func peticion(_ tema: String, asignatura: String?, material: String) -> String {
        let materia = asignatura.map { L(" (\($0))", " (\($0))", " (\($0))") } ?? ""
        return L(
            """
            Con el MATERIAL del tema «\(tema)»\(materia), escribe dos partes.
            RESUMEN: un resumen para escucharlo, no para leerlo, de unas 150 palabras: frases cortas y completas, lo más importante primero, sin listas, sin símbolos y sin títulos.
            PREGUNTAS: 5 preguntas cortas sobre lo más importante, cada una con su respuesta corta, así:
            P: la pregunta
            R: la respuesta

            MATERIAL:
            \(material)
            """,
            """
            Using the MATERIAL for the topic “\(tema)”\(materia), write two parts.
            SUMMARY: a summary to listen to, not to read, of about 150 words: short, complete sentences, the most important first, no lists, no symbols and no headings.
            QUESTIONS: 5 short questions about the most important points, each with its short answer, like this:
            Q: the question
            A: the answer

            MATERIAL:
            \(material)
            """,
            """
            Con il MATERIALE dell'argomento «\(tema)»\(materia), scrivi due parti.
            RIASSUNTO: un riassunto da ascoltare, non da leggere, di circa 150 parole: frasi brevi e complete, la cosa più importante prima, senza elenchi, senza simboli e senza titoli.
            DOMANDE: 5 domande brevi sulle cose più importanti, ognuna con la sua risposta breve, così:
            D: la domanda
            R: la risposta

            MATERIALE:
            \(material)
            """
        )
    }

    static func partir(_ texto: String, huella: UInt64) -> AudioTema {
        let limpio = texto.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "#", with: "")
        let marcasPreguntas = ["PREGUNTAS:", "QUESTIONS:", "DOMANDE:"]
        let marcasResumen = ["RESUMEN:", "SUMMARY:", "RIASSUNTO:"]
        var resumen = limpio
        var bloque = ""
        if let r = marcasPreguntas.lazy.compactMap({ limpio.range(of: $0, options: .caseInsensitive) }).first {
            resumen = String(limpio[..<r.lowerBound])
            bloque = String(limpio[r.upperBound...])
        }
        for m in marcasResumen {
            if let r = resumen.range(of: m, options: .caseInsensitive) { resumen = String(resumen[r.upperBound...]) }
        }
        var preguntas: [PreguntaAudio] = []
        var pendiente: String?
        for linea in bloque.components(separatedBy: "\n") {
            var l = linea.trimmingCharacters(in: .whitespaces)
            while let c = l.first, c.isNumber || c == "." || c == "-" || c == ")" || c == " " { l.removeFirst() }
            let mayus = l.uppercased()
            if mayus.hasPrefix("P:") || mayus.hasPrefix("Q:") || mayus.hasPrefix("D:") {
                pendiente = l.dropFirst(2).trimmingCharacters(in: .whitespaces)
            } else if mayus.hasPrefix("R:") || mayus.hasPrefix("A:"), let p = pendiente {
                preguntas.append(PreguntaAudio(pregunta: p, respuesta: l.dropFirst(2).trimmingCharacters(in: .whitespaces)))
                pendiente = nil
            }
        }
        return AudioTema(huella: huella, resumen: resumen.trimmingCharacters(in: .whitespacesAndNewlines), preguntas: Array(preguntas.prefix(6)))
    }
}

@Observable
final class ReproductorHoot {
    static let compartido = ReproductorHoot()

    struct Pista: Identifiable, Equatable {
        var id: UUID
        var titulo: String
        var asignatura: String?
        var luna: Double
    }

    enum Trozo: Equatable {
        case titulo(String)
        case frase(String)
        case aviso(String)
        case pregunta(String)
        case pausa(Double)
        case respuesta(String)
    }

    private(set) var pistas: [Pista] = []
    private(set) var actual = 0
    private(set) var trozos: [Trozo] = []
    private(set) var indice = 0
    private(set) var sonando = false
    private(set) var preparando = false
    private(set) var terminado = false
    var error: String?

    private(set) var cuenta: Double?
    private(set) var pregunta: String?
    private(set) var respuesta: String?
    private(set) var velocidad: Double = 1

    static let pausaPregunta: Double = 5

    var activo: Bool { !pistas.isEmpty }
    var pista: Pista? { pistas.indices.contains(actual) ? pistas[actual] : nil }
    var siguientePista: Pista? { pistas.indices.contains(actual + 1) ? pistas[actual + 1] : nil }

    var inicioPreguntas: Int { trozos.firstIndex { if case .aviso = $0 { return true } else { return false } } ?? trozos.count }
    var enPreguntas: Bool { indice >= inicioPreguntas }

    @ObservationIgnored private let sintetizador = AVSpeechSynthesizer()
    @ObservationIgnored private var delegado: DelegadoReproductor?
    @ObservationIgnored private var tareaPausa: Task<Void, Never>?
    @ObservationIgnored private weak var almacen: Almacen?
    @ObservationIgnored private var mandosListos = false
    @ObservationIgnored private var saltando = false

    func reproducir(temas ids: [UUID], almacen: Almacen) {
        self.almacen = almacen
        parar(soltar: false)
        let datos = almacen.datos
        let cal = calendarioActual
        pistas = ids.compactMap { id in
            guard let t = datos.tema(id) else { return nil }
            let a = datos.asignatura(datos.prueba(deTema: id)?.asignaturaID ?? datos.temasDeAhora.first { $0.tema.id == id }?.asignaturaID)
            return Pista(id: id, titulo: t.nombre, asignatura: a?.nombre, luna: t.luna(cal: cal).fraccion)
        }
        actual = 0
        prepararMandos()
        empezarPista()
    }

    private func empezarPista() {
        guard let p = pista, let almacen, let t = almacen.datos.tema(p.id) else { return }
        error = nil
        terminado = false
        preparando = true
        trozos = []
        indice = 0
        actualizarPantallaBloqueada()
        Task {
            do {
                let audio = try await PreparadorAudio.preparar(t, asignatura: p.asignatura, curso: almacen.perfil.curso)
                if t.audio != audio { almacen.datos.cambiarTema(p.id) { $0.audio = audio } }
                guard pista?.id == p.id else { return }
                trozos = Self.trozos(titulo: p.titulo, audio: audio)
                preparando = false
                sonando = true
                hablar()
            } catch {
                preparando = false
                self.error = error.localizedDescription
            }
        }
    }

    static func trozos(titulo: String, audio: AudioTema) -> [Trozo] {
        var r: [Trozo] = [.titulo(titulo)]
        r += frases(audio.resumen).map { .frase($0) }
        if !audio.preguntas.isEmpty {
            r.append(.aviso(L("Ahora, preguntas. Piensa la respuesta antes de oírla.", "Now, questions. Think of the answer before you hear it.",
                              "Ora, domande. Pensa alla risposta prima di sentirla.")))
            for p in audio.preguntas { r += [.pregunta(p.pregunta), .pausa(pausaPregunta), .respuesta(p.respuesta)] }
        }
        return r
    }

    static func frases(_ texto: String) -> [String] {
        var r: [String] = []
        texto.enumerateSubstrings(in: texto.startIndex..., options: .bySentences) { s, _, _, _ in
            if let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { r.append(s) }
        }
        return r.isEmpty ? [texto] : r
    }

    func alternar() {
        if sonando {
            sonando = false
            if sintetizador.isSpeaking { sintetizador.pauseSpeaking(at: .word) }
            tareaPausa?.cancel()
        } else if terminado {
            actual = 0
            empezarPista()
        } else if !trozos.isEmpty {
            sonando = true
            if sintetizador.isPaused { sintetizador.continueSpeaking() } else { hablar() }
        }
        actualizarPantallaBloqueada()
    }

    func adelante() { saltar(a: indice + 1) }

    func atras() { saltar(a: max(0, indice - (sintetizador.isSpeaking ? 0 : 1))) }

    private func saltar(a nuevo: Int) {
        guard !trozos.isEmpty else { return }
        tareaPausa?.cancel()
        saltando = true
        sintetizador.stopSpeaking(at: .immediate)
        saltando = false
        if nuevo >= trozos.count { siguienteTrozoOPista(desde: trozos.count - 1); return }
        indice = nuevo
        if sonando { hablar() } else { mostrarTrozo() }
        actualizarPantallaBloqueada()
    }

    func cambiarVelocidad() {
        velocidad = velocidad < 0.9 ? 1 : (velocidad < 1.1 ? 1.25 : 0.8)
    }

    func parar(soltar: Bool = true) {
        tareaPausa?.cancel()
        saltando = true
        sintetizador.stopSpeaking(at: .immediate)
        saltando = false
        sonando = false
        cuenta = nil
        pregunta = nil
        respuesta = nil
        if soltar {
            pistas = []
            trozos = []
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func hablar() {
        guard trozos.indices.contains(indice) else { return }
        mostrarTrozo()
        let trozo = trozos[indice]
        if case .pausa(let s) = trozo {
            pensar(s)
            return
        }
        let texto: String = switch trozo {
        case .titulo(let t): t
        case .frase(let t), .aviso(let t), .pregunta(let t): t
        case .respuesta(let t): L("La respuesta: \(t)", "The answer: \(t)", "La risposta: \(t)")
        case .pausa: ""
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        let frase = AVSpeechUtterance(string: texto)
        frase.voice = Self.voz
        frase.rate = min(AVSpeechUtteranceMaximumSpeechRate, Float(Double(AVSpeechUtteranceDefaultSpeechRate) * 0.95 * velocidad))
        if case .titulo = trozo { frase.postUtteranceDelay = 0.5 }
        if case .aviso = trozo { frase.postUtteranceDelay = 0.4 }
        if delegado == nil {
            let d = DelegadoReproductor { [weak self] in
                Task { @MainActor in self?.alAcabarFrase() }
            }
            delegado = d
            sintetizador.delegate = d
        }
        sintetizador.speak(frase)
        actualizarPantallaBloqueada()
    }

    private func mostrarTrozo() {
        guard trozos.indices.contains(indice) else { return }
        switch trozos[indice] {
        case .pregunta(let p):
            pregunta = p
            respuesta = nil
            cuenta = nil
        case .pausa(let s):
            cuenta = s
            if pregunta == nil { pregunta = preguntaAnterior }
        case .respuesta(let r):
            cuenta = nil
            respuesta = r
            if pregunta == nil { pregunta = preguntaAnterior }
        default:
            pregunta = nil
            respuesta = nil
            cuenta = nil
        }
    }

    private var preguntaAnterior: String? {
        for i in stride(from: indice, through: 0, by: -1) {
            if case .pregunta(let p) = trozos[i] { return p }
        }
        return nil
    }

    private func pensar(_ segundos: Double) {
        tareaPausa?.cancel()
        let desde = cuenta ?? segundos
        tareaPausa = Task { [weak self] in
            var queda = desde
            while queda > 0 {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, !Task.isCancelled, self.sonando else { return }
                queda -= 0.1
                self.cuenta = max(0, queda)
            }
            guard let self, !Task.isCancelled else { return }
            self.siguienteTrozoOPista(desde: self.indice)
        }
    }

    private func alAcabarFrase() {
        guard !saltando, sonando else { return }
        siguienteTrozoOPista(desde: indice)
    }

    private func siguienteTrozoOPista(desde i: Int) {
        if i + 1 < trozos.count {
            indice = i + 1
            hablar()
        } else if actual + 1 < pistas.count {
            actual += 1
            empezarPista()
        } else {
            sonando = false
            terminado = true
            cuenta = nil
            actualizarPantallaBloqueada()
        }
    }

    private static var voz: AVSpeechSynthesisVoice? {
        let idioma = idiomaActual.rawValue
        let region = "\(idioma)-\(regionActual)"
        let voces = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(idioma) }
        let mejor = voces.max { a, b in
            (a.quality.rawValue, a.language == region ? 1 : 0) < (b.quality.rawValue, b.language == region ? 1 : 0)
        }
        return mejor ?? AVSpeechSynthesisVoice(language: region) ?? AVSpeechSynthesisVoice(language: idioma)
    }

    private func segundos(_ t: Trozo) -> Double {
        switch t {
        case .pausa(let s): s
        case .titulo(let x), .frase(let x), .aviso(let x), .pregunta(let x), .respuesta(let x):
            Double(x.split(separator: " ").count) / (2.6 * velocidad) + 0.4
        }
    }

    var duracion: Double { trozos.reduce(0) { $0 + segundos($1) } }
    var transcurrido: Double { trozos.prefix(indice).reduce(0) { $0 + segundos($1) } }
    var duracionResumen: Double { trozos.prefix(inicioPreguntas).reduce(0) { $0 + segundos($1) } }

    private func prepararMandos() {
        guard !mandosListos else { return }
        mandosListos = true
        Self.registrarMandos(self)
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] aviso in
            let empieza = (aviso.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            Task { @MainActor in if empieza, self?.sonando == true { self?.alternar() } }
        }
    }

    nonisolated private static func registrarMandos(_ r: ReproductorHoot) {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak r] _ in
            Task { @MainActor in if r?.sonando == false { r?.alternar() } }
            return .success
        }
        c.pauseCommand.addTarget { [weak r] _ in
            Task { @MainActor in if r?.sonando == true { r?.alternar() } }
            return .success
        }
        c.togglePlayPauseCommand.addTarget { [weak r] _ in
            Task { @MainActor in r?.alternar() }
            return .success
        }
        c.nextTrackCommand.addTarget { [weak r] _ in
            Task { @MainActor in r?.adelante() }
            return .success
        }
        c.previousTrackCommand.addTarget { [weak r] _ in
            Task { @MainActor in r?.atras() }
            return .success
        }
    }

    private func actualizarPantallaBloqueada() {
        guard let p = pista else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: p.titulo,
            MPMediaItemPropertyArtist: "Hoot",
            MPMediaItemPropertyPlaybackDuration: duracion,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: transcurrido,
            MPNowPlayingInfoPropertyPlaybackRate: sonando ? 1.0 : 0.0,
        ]
        if let a = p.asignatura { info[MPMediaItemPropertyAlbumTitle] = a }
        if let portada = Self.portada(luna: p.luna) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: portada.size) { _ in portada }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private static var portadas: [Double: UIImage] = [:]
    private static func portada(luna: Double) -> UIImage? {
        if let p = portadas[luna] { return p }
        let r = ImageRenderer(content: PortadaEscuchalo(luna: luna, lado: 600, conLobo: true))
        r.scale = 1
        let img = r.uiImage
        portadas[luna] = img
        return img
    }

    func demo(almacen: Almacen, tema t: Tema, asignatura: String?, enPregunta: Bool) {
        self.almacen = almacen
        let cal = calendarioActual
        pistas = [Pista(id: t.id, titulo: t.nombre, asignatura: asignatura, luna: t.luna(cal: cal).fraccion)]
        actual = 0
        let audio = AudioTema(huella: 0, resumen: L(
            "Cartago era una ciudad fenicia del norte de África. Roma y Cartago lucharon por el Mediterráneo en las guerras púnicas. En la segunda, Aníbal cruzó los Alpes con elefantes y venció en Cannas. Al final ganó Roma, que destruyó Cartago en el año 146 antes de Cristo.",
            "Carthage was a Phoenician city in North Africa. Rome and Carthage fought over the Mediterranean in the Punic Wars. In the second one, Hannibal crossed the Alps with elephants and won at Cannae. In the end Rome won and destroyed Carthage in 146 BC.",
            "Cartagine era una città fenicia del Nord Africa. Roma e Cartagine combatterono per il Mediterraneo nelle guerre puniche. Nella seconda, Annibale attraversò le Alpi con gli elefanti e vinse a Canne. Alla fine vinse Roma, che distrusse Cartagine nel 146 a.C."),
            preguntas: [PreguntaAudio(pregunta: L("¿Quién cruzó los Alpes con elefantes?", "Who crossed the Alps with elephants?", "Chi attraversò le Alpi con gli elefanti?"),
                                      respuesta: L("Aníbal", "Hannibal", "Annibale")),
                        PreguntaAudio(pregunta: L("¿Quién ganó las guerras púnicas?", "Who won the Punic Wars?", "Chi vinse le guerre puniche?"),
                                      respuesta: "Roma")])
        trozos = Self.trozos(titulo: t.nombre, audio: audio)
        indice = enPregunta ? inicioPreguntas + 2 : 2
        pregunta = nil
        mostrarTrozo()
        if enPregunta { cuenta = 3 }
        sonando = true
    }
}

nonisolated private final class DelegadoReproductor: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    let acabo: @Sendable () -> Void
    init(_ acabo: @escaping @Sendable () -> Void) { self.acabo = acabo }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { acabo() }
}

struct PortadaEscuchalo: View {
    var luna: Double
    var lado: CGFloat
    var conLobo = true
    var gesto: GestoLobo = .normal

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.043, green: 0.086, blue: 0.212), Color(red: 0.11, green: 0.188, blue: 0.4)], startPoint: .top, endPoint: .bottom)
            Canvas { c, tam in
                var g = Aleatorio(semilla: 11)
                for _ in 0..<60 {
                    let x = g.siguiente() * tam.width
                    let y = pow(g.siguiente(), 1.4) * tam.height * 0.8
                    let r = (0.5 + g.siguiente()) * tam.width / 320
                    c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.3 + g.siguiente() * 0.5)))
                }
            }
            Luna(parte: luna, tamano: lado * 0.58, brillo: luna >= 1)
                .offset(y: -lado * 0.06)
            if conLobo {
                Lobo(tamano: lado * 0.36, gesto: gesto)
                    .offset(x: lado * 0.33, y: lado * 0.34)
            }
        }
        .frame(width: lado, height: lado)
        .clipped()
        .accessibilityHidden(true)
    }
}
