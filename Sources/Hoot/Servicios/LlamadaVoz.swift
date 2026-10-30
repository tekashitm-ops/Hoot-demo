@preconcurrency import AVFoundation
import NaturalLanguage
import Speech
import SwiftUI

@Observable
final class LlamadaVoz {
    enum Estado: Equatable { case parada, escuchando, pensando, hablando }

    var estado: Estado = .parada

    var oido = ""

    var nivel: Double = 0
    var silenciado = false
    var error: String?

    private(set) var interrumpibleConVoz = false

    @ObservationIgnored var alTerminarTurno: ((String) -> Void)?

    @ObservationIgnored var alInterrumpir: ((_ dicho: String, _ pensando: Bool) -> Void)?

    @ObservationIgnored private let motor = AVAudioEngine()
    @ObservationIgnored private let reproductor = AVAudioPlayerNode()
    @ObservationIgnored private let sintetizador = AVSpeechSynthesizer()
    @ObservationIgnored private let formatoVoz = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1)!
    @ObservationIgnored private let caja = CajaEscucha()
    @ObservationIgnored private var reconocedor: SFSpeechRecognizer?
    @ObservationIgnored private var tareaReconocer: SFSpeechRecognitionTask?

    @ObservationIgnored private var ventana = 0

    @ObservationIgnored private var ultimoSonido = Date()
    @ObservationIgnored private var haHablado = false

    @ObservationIgnored private var acumulado = ""
    @ObservationIgnored private var pensandoDesde = Date()
    @ObservationIgnored private var vigilante: Task<Void, Never>?

    @ObservationIgnored private var consumido = 0
    @ObservationIgnored private var ultimoTexto = ""
    @ObservationIgnored private var respuestaCompleta = false
    @ObservationIgnored private var frasesPendientes: [String] = []
    @ObservationIgnored private var sintetizando = false
    @ObservationIgnored private var frasesEnCurso = 0
    @ObservationIgnored private var dicho: [String] = []
    @ObservationIgnored private var fraseSonando = ""
    @ObservationIgnored private var voz: AVSpeechSynthesisVoice?
    @ObservationIgnored private var turno = 0

    func empezar() async {
        guard estado == .parada else { return }

        if ModoCapturas.activo {
            interrumpibleConVoz = true
            estado = .hablando
            return
        }
        error = nil
        guard await Self.permisos() else {
            error = L("Hoot necesita el micrófono y el reconocimiento de voz. Actívalos en Ajustes > Hoot.",
                      "Hoot needs the microphone and speech recognition. Turn them on in Settings > Hoot.",
                      "Hoot ha bisogno del microfono e del riconoscimento vocale. Attivali in Impostazioni > Hoot.")
            return
        }
        reconocedor = SFSpeechRecognizer(locale: Locale(identifier: "\(idiomaActual.rawValue)-\(regionActual)"))
            ?? SFSpeechRecognizer(locale: Locale(identifier: idiomaActual.rawValue))
        guard let reconocedor, reconocedor.isAvailable else {
            error = L("El dictado no está disponible ahora.", "Dictation isn't available right now.", "La dettatura non è disponibile ora.")
            return
        }
        do {
            let sesion = AVAudioSession.sharedInstance()
            try sesion.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers])
            try sesion.setActive(true, options: .notifyOthersOnDeactivation)

            do {
                try motor.inputNode.setVoiceProcessingEnabled(true)
                interrumpibleConVoz = true
            } catch {
                interrumpibleConVoz = false
                Registro.error(error, en: "voz.procesado")
            }
            let entrada = motor.inputNode
            let formato = entrada.outputFormat(forBus: 0)
            guard formato.sampleRate > 0, formato.channelCount > 0 else { throw CocoaError(.featureUnsupported) }
            motor.attach(reproductor)
            motor.connect(reproductor, to: motor.mainMixerNode, format: formatoVoz)
            entrada.removeTap(onBus: 0)
            entrada.installTap(onBus: 0, bufferSize: 1024, format: formato, block: Self.bloqueAudio(caja) { [weak self] v in
                Task { @MainActor in self?.oyeVolumen(v) }
            })
            motor.prepare()
            try motor.start()
            reproductor.play()
            nuevaVentana()
            conMuelle(Diseno.muelleRapido) { estado = .escuchando }
            vigilarSilencio()
        } catch {
            Registro.error(error, en: "voz.empezar")
            parar()
            self.error = L("No se ha podido usar el micrófono.", "Couldn't use the microphone.", "Non è stato possibile usare il microfono.")
        }
    }

    func parar() {
        vigilante?.cancel()
        vigilante = nil
        callarse()
        tareaReconocer?.cancel()
        tareaReconocer = nil
        caja.cambiar(nil)
        if motor.isRunning { motor.stop() }
        motor.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        estado = .parada
        nivel = 0
    }

    private func nuevaVentana(seguir: Bool = false) {
        tareaReconocer?.cancel()
        ventana += 1
        let estaVentana = ventana
        let peticion = SFSpeechAudioBufferRecognitionRequest()
        peticion.shouldReportPartialResults = true
        peticion.addsPunctuation = true
        peticion.taskHint = .dictation
        if reconocedor?.supportsOnDeviceRecognition == true { peticion.requiresOnDeviceRecognition = true }
        caja.cambiar(peticion)
        if !seguir {
            acumulado = ""
            oido = ""
            haHablado = false
        }
        tareaReconocer = reconocedor?.recognitionTask(with: peticion, resultHandler: Self.bloqueResultado { [weak self] texto, final in
            Task { @MainActor in self?.oye(texto, final: final, ventana: estaVentana) }
        })
    }

    private func oyeVolumen(_ v: Double) {
        nivel = silenciado ? 0 : v
        if v > 0.16 && !silenciado { ultimoSonido = Date() }
    }

    private func oye(_ texto: String?, final: Bool, ventana v: Int) {
        guard v == ventana, !silenciado else { return }
        let t = (texto ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        switch estado {
        case .escuchando:
            if !t.isEmpty {
                oido = (acumulado + " " + t).trimmingCharacters(in: .whitespaces)
                haHablado = true
                ultimoSonido = Date()
            }

            if final {
                acumulado = oido
                nuevaVentana(seguir: true)
            }
        case .pensando, .hablando:
            if !t.isEmpty, interrumpibleConVoz || estado == .pensando, esInterrupcion(t) {
                interrumpir()
                oido = t
                haHablado = true
                ultimoSonido = Date()
                if final {
                    acumulado = oido
                    nuevaVentana(seguir: true)
                }
            } else if final {
                nuevaVentana()
            }
        case .parada:
            break
        }
    }

    private func esInterrupcion(_ t: String) -> Bool {
        let palabras = Self.palabras(t)
        guard !palabras.isEmpty else { return false }
        let deHoot = Set(Self.palabras((dicho + [fraseSonando]).joined(separator: " ")))
        let suyas = palabras.filter { !deHoot.contains($0) }
        if suyas.count >= 2 { return true }
        let cortes: Set<String> = ["espera", "para", "pero", "oye", "hoot", "perdona", "vale", "stop", "wait", "aspetta", "basta", "ferma",
                                   "scusa", "no", "si", "sí", "como", "cómo", "que", "qué", "why", "what", "perche", "perché", "porque"]
        return suyas.count == 1 && cortes.contains(suyas[0])
    }

    static func palabras(_ t: String) -> [String] {
        t.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    private func vigilarSilencio() {
        vigilante?.cancel()
        vigilante = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, !Task.isCancelled else { return }

                if self.estado == .pensando, Date().timeIntervalSince(self.pensandoDesde) > 45 { self.sinRespuesta() }
                guard self.estado == .escuchando, self.haHablado, !self.silenciado else { continue }

                let espera = self.oido.hasSuffix(",") || Self.palabras(self.oido).last.map(Self.sinAcabar.contains) == true ? 2.2 : 1.3
                if Date().timeIntervalSince(self.ultimoSonido) > espera { self.terminarTurno() }
            }
        }
    }

    private static let sinAcabar: Set<String> = ["y", "o", "que", "de", "el", "la", "los", "las", "un", "una", "pero", "porque", "como", "e",
                                                 "di", "il", "and", "the", "of", "to", "a", "en", "con", "in", "per"]

    private func terminarTurno() {
        let t = oido.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        caja.peticion?.endAudio()
        oido = t
        haHablado = false
        empezarRespuesta()
        pensandoDesde = Date()
        conMuelle(Diseno.muelleRapido) { estado = .pensando }

        nuevaVentana()
        oido = t
        alTerminarTurno?(t)
    }

    func interrumpir() {
        let estabaPensando = estado == .pensando
        let lo = (dicho + (fraseSonando.isEmpty ? [] : [fraseSonando])).joined(separator: " ")
        callarse()
        conMuelle(Diseno.muelleRapido) { estado = .escuchando }
        ultimoSonido = Date()
        alInterrumpir?(lo, estabaPensando)
    }

    func cambiarSilencio() {
        silenciado.toggle()
        nivel = 0
        if silenciado { haHablado = false; oido = "" }
    }

    func respuesta(_ texto: String, completa: Bool) {
        guard estado == .pensando || estado == .hablando else { return }
        let limpio = Self.paraDecir(texto)
        if !limpio.hasPrefix(String(ultimoTexto.prefix(consumido))) { consumido = 0 }
        ultimoTexto = limpio
        var resto = String(limpio.dropFirst(consumido))
        while let fin = Self.finDeFrase(resto) {
            let frase = String(resto[..<fin]).trimmingCharacters(in: .whitespacesAndNewlines)
            consumido += resto.distance(from: resto.startIndex, to: fin)
            resto = String(resto[fin...])
            if !frase.isEmpty { encolar(frase) }
        }
        if completa {
            let ultima = resto.trimmingCharacters(in: .whitespacesAndNewlines)
            consumido = limpio.count
            if !ultima.isEmpty { encolar(ultima) }
            respuestaCompleta = true
            if frasesEnCurso == 0 && frasesPendientes.isEmpty && !sintetizando { acabarDeHablar() }
        }
    }

    func sinRespuesta() {
        callarse()
        if estado != .parada { conMuelle(Diseno.muelleRapido) { estado = .escuchando } }
    }

    private func empezarRespuesta() {
        turno += 1
        consumido = 0
        ultimoTexto = ""
        respuestaCompleta = false
        frasesPendientes = []
        dicho = []
        fraseSonando = ""
        voz = nil
    }

    private func encolar(_ frase: String) {
        if voz == nil { voz = Self.mejorVoz(para: frase) }
        frasesPendientes.append(frase)
        sintetizarSiguiente()
    }

    private func sintetizarSiguiente() {
        guard !sintetizando, !frasesPendientes.isEmpty, estado == .pensando || estado == .hablando else { return }
        sintetizando = true
        let frase = frasesPendientes.removeFirst()
        let u = AVSpeechUtterance(string: frase)
        u.voice = voz
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.98
        u.prefersAssistiveTechnologySettings = false
        let esteTurno = turno
        sintetizador.write(u, toBufferCallback: Self.bloqueVoz(destino: formatoVoz) { [weak self] trozos in
            Task { @MainActor in self?.sonar(trozos.buffers, frase: frase, turno: esteTurno) }
        })
    }

    private func sonar(_ trozos: [AVAudioPCMBuffer], frase: String, turno t: Int) {

        guard t == turno else { return }
        sintetizando = false
        guard estado == .pensando || estado == .hablando else { return }
        guard !trozos.isEmpty else { sintetizarSiguiente(); return }
        if estado == .pensando { conMuelle(Diseno.muelleRapido) { estado = .hablando } }
        frasesEnCurso += 1
        for (i, b) in trozos.enumerated() {
            let ultimo = i == trozos.count - 1
            let primero = i == 0
            reproductor.scheduleBuffer(b, completionCallbackType: .dataPlayedBack,
                                       completionHandler: Self.bloqueSonado { [weak self] in
                                           Task { @MainActor in
                                               if primero { self?.empiezaFrase(frase, turno: t) }
                                               if ultimo { self?.acabaFrase(frase, turno: t) }
                                           }
                                       })
        }
        if !reproductor.isPlaying { reproductor.play() }
        sintetizarSiguiente()
    }

    private func empiezaFrase(_ f: String, turno t: Int) {
        guard t == turno else { return }
        fraseSonando = f
    }

    private func acabaFrase(_ f: String, turno t: Int) {
        guard t == turno else { return }
        frasesEnCurso = max(0, frasesEnCurso - 1)
        dicho.append(f)
        if fraseSonando == f { fraseSonando = "" }
        if respuestaCompleta && frasesEnCurso == 0 && frasesPendientes.isEmpty && !sintetizando { acabarDeHablar() }
    }

    private func acabarDeHablar() {
        guard estado == .hablando || estado == .pensando else { return }
        conMuelle(Diseno.muelleRapido) { estado = .escuchando }
        ultimoSonido = Date()

        nuevaVentana()
    }

    private func callarse() {
        turno += 1
        frasesPendientes = []
        frasesEnCurso = 0
        sintetizando = false
        fraseSonando = ""
        sintetizador.stopSpeaking(at: .immediate)
        reproductor.stop()
        if motor.isRunning { reproductor.play() }
    }

    static func paraDecir(_ t: String) -> String {
        var r = t
        for marca in ["Ahora tú:", "Your turn:", "Ora tu:", "Ora tocca a te:"] {
            r = r.replacingOccurrences(of: marca, with: "", options: [.caseInsensitive, .diacriticInsensitive])
        }
        r = r.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "#", with: "").replacingOccurrences(of: "…", with: ".")
        return r.components(separatedBy: "\n").map { l in
            var x = l.trimmingCharacters(in: .whitespaces)
            if x.hasPrefix("- ") || x.hasPrefix("• ") { x.removeFirst(2) }
            return x
        }.joined(separator: "\n")
    }

    static func finDeFrase(_ t: String) -> String.Index? {
        var i = t.startIndex
        while i < t.endIndex {
            let c = t[i]
            let siguiente = t.index(after: i)
            if c == "\n" { return siguiente }
            if ".!?:;".contains(c) {
                guard siguiente < t.endIndex else { return nil }
                let d = t[siguiente]
                if d == " " || d == "\n" {

                    let antes = t[..<i].split(separator: " ").last.map(String.init) ?? ""
                    if c == "." && antes.count <= 2 && antes.first?.isUppercase == true { i = siguiente; continue }
                    return t.index(after: siguiente)
                }
            }
            i = siguiente
        }
        return nil
    }

    static func mejorVoz(para texto: String) -> AVSpeechSynthesisVoice? {
        let r = NLLanguageRecognizer()
        r.processString(texto)
        let idioma = r.dominantLanguage?.rawValue.prefix(2).description ?? idiomaActual.rawValue
        let codigo = ["es", "en", "it", "fr", "de", "pt"].contains(idioma) && texto.count > 25 ? idioma : idiomaActual.rawValue
        let voces = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(codigo) }
        let region = codigo == idiomaActual.rawValue ? "\(codigo)-\(regionActual)" : ""
        return voces.max { a, b in
            (a.quality.rawValue, a.language == region ? 1 : 0) < (b.quality.rawValue, b.language == region ? 1 : 0)
        } ?? AVSpeechSynthesisVoice(language: codigo)
    }

    nonisolated private static func bloqueAudio(_ caja: CajaEscucha, nivel: @escaping @Sendable (Double) -> Void) -> AVAudioNodeTapBlock {
        { buffer, _ in
            caja.peticion?.append(buffer)
            guard let canal = buffer.floatChannelData?[0] else { return }
            let n = Int(buffer.frameLength)
            guard n > 0 else { return }
            var suma: Float = 0
            for i in 0..<n { suma += canal[i] * canal[i] }
            let db = 20 * log10(max(sqrt(suma / Float(n)), 0.000_01))
            nivel(Double(max(0, min(1, (db + 50) / 40))))
        }
    }

    nonisolated private static func bloqueResultado(_ hecho: @escaping @Sendable (String?, Bool) -> Void) -> (SFSpeechRecognitionResult?, (any Error)?) -> Void {
        { resultado, error in
            hecho(resultado?.bestTranscription.formattedString, resultado?.isFinal ?? (error != nil))
        }
    }

    nonisolated private static func bloqueVoz(destino: AVAudioFormat, listo: @escaping @Sendable (TrozosVoz) -> Void) -> (AVAudioBuffer) -> Void {
        let trozos = TrozosVoz()
        var conversor: AVAudioConverter?
        return { buffer in
            guard let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0 else {
                listo(trozos)
                return
            }
            if conversor == nil || conversor?.inputFormat != pcm.format { conversor = AVAudioConverter(from: pcm.format, to: destino) }
            guard let conversor else { return }
            let capacidad = AVAudioFrameCount(Double(pcm.frameLength) * destino.sampleRate / pcm.format.sampleRate) + 64
            guard let salida = AVAudioPCMBuffer(pcmFormat: destino, frameCapacity: capacidad) else { return }
            let dado = TrozosVoz()
            var error: NSError?
            conversor.convert(to: salida, error: &error) { _, estado in
                if dado.dado { estado.pointee = .noDataNow; return nil }
                dado.dado = true
                estado.pointee = .haveData
                return pcm
            }
            if error == nil, salida.frameLength > 0 { trozos.buffers.append(salida) }
        }
    }

    nonisolated private static func bloqueSonado(_ hecho: @escaping @Sendable () -> Void) -> @Sendable (AVAudioPlayerNodeCompletionCallbackType) -> Void {
        { _ in hecho() }
    }

    nonisolated private static func permisos() async -> Bool {
        let voz = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { estado in c.resume(returning: estado == .authorized) }
        }
        guard voz else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}

nonisolated private final class CajaEscucha: @unchecked Sendable {
    private let cerrojo = NSLock()
    private var actual: SFSpeechAudioBufferRecognitionRequest?

    var peticion: SFSpeechAudioBufferRecognitionRequest? {
        cerrojo.lock(); defer { cerrojo.unlock() }
        return actual
    }

    func cambiar(_ p: SFSpeechAudioBufferRecognitionRequest?) {
        cerrojo.lock(); defer { cerrojo.unlock() }
        actual = p
    }
}

nonisolated private final class TrozosVoz: @unchecked Sendable {
    var buffers: [AVAudioPCMBuffer] = []

    var dado = false
}
