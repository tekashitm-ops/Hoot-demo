import AVFoundation
import Speech
import SwiftUI

@Observable
final class Dictado {
    var escuchando = false

    var texto = ""

    var nivel: Double = 0
    var error: String?

    var pararAlCallar = false

    @ObservationIgnored private let motor = AVAudioEngine()
    @ObservationIgnored private var ultimoSonido = Date()
    @ObservationIgnored private var haHablado = false
    @ObservationIgnored private var caja: CajaPeticion?
    @ObservationIgnored private var tarea: SFSpeechRecognitionTask?
    @ObservationIgnored private var base = ""

    func empezar(desde base: String) async {
        guard !escuchando else { return }
        error = nil
        guard await Self.permisos() else {
            error = L("Hoot necesita el micrófono y el reconocimiento de voz. Actívalos en Ajustes > Hoot.",
                      "Hoot needs the microphone and speech recognition. Turn them on in Settings > Hoot.",
                      "Hoot ha bisogno del microfono e del riconoscimento vocale. Attivali in Impostazioni > Hoot.")
            return
        }
        guard let reconocedor = Self.reconocedor(), reconocedor.isAvailable else {
            error = L("El dictado no está disponible ahora.", "Dictation isn't available right now.", "La dettatura non è disponibile ora.")
            return
        }
        do {
            let sesion = AVAudioSession.sharedInstance()
            try sesion.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
            try sesion.setActive(true, options: .notifyOthersOnDeactivation)

            let peticion = SFSpeechAudioBufferRecognitionRequest()
            peticion.shouldReportPartialResults = true
            peticion.addsPunctuation = true
            if reconocedor.supportsOnDeviceRecognition { peticion.requiresOnDeviceRecognition = true }
            let caja = CajaPeticion(peticion)
            self.caja = caja
            self.base = base.trimmingCharacters(in: .whitespacesAndNewlines)
            texto = base

            let entrada = motor.inputNode
            let formato = entrada.outputFormat(forBus: 0)

            guard formato.sampleRate > 0, formato.channelCount > 0 else { throw CocoaError(.featureUnsupported) }
            entrada.removeTap(onBus: 0)
            entrada.installTap(onBus: 0, bufferSize: 1024, format: formato, block: Self.bloqueAudio(caja) { [weak self] v in
                Task { @MainActor in
                    guard let self else { return }
                    self.nivel = v
                    if v > 0.18 {
                        self.ultimoSonido = Date()
                        self.haHablado = true
                    }
                }
            })
            motor.prepare()
            try motor.start()
            tarea = reconocedor.recognitionTask(with: peticion, resultHandler: Self.bloqueResultado { [weak self] texto, final in
                Task { @MainActor in
                    guard let self else { return }
                    if let texto {
                        self.texto = self.base.isEmpty ? texto : self.base + " " + texto
                    }
                    if final { self.parar() }
                }
            })
            conMuelle(Diseno.muelleRapido) { escuchando = true }
            if pararAlCallar { vigilarSilencio() }
        } catch {
            parar()
            self.error = L("No se ha podido usar el micrófono.", "Couldn't use the microphone.", "Non è stato possibile usare il microfono.")
        }
    }

    private func vigilarSilencio() {
        haHablado = false
        ultimoSonido = Date()
        let inicio = Date()
        Task { [weak self] in
            while let self, self.escuchando {
                try? await Task.sleep(for: .milliseconds(250))
                guard self.escuchando else { return }
                let callado = Date().timeIntervalSince(self.ultimoSonido)
                if (self.haHablado && callado > 1.4) || (!self.haHablado && Date().timeIntervalSince(inicio) > 8) {
                    self.parar()
                    return
                }
            }
        }
    }

    func parar() {
        if motor.isRunning { motor.stop() }
        motor.inputNode.removeTap(onBus: 0)
        caja?.peticion.endAudio()
        caja = nil
        tarea?.finish()
        tarea = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        conMuelle(Diseno.muelleRapido) {
            escuchando = false
            nivel = 0
        }
    }

    nonisolated private static func bloqueAudio(_ caja: CajaPeticion, nivel: @escaping @Sendable (Double) -> Void) -> AVAudioNodeTapBlock {
        { buffer, _ in
            caja.peticion.append(buffer)
            guard let canal = buffer.floatChannelData?[0] else { return }
            let n = Int(buffer.frameLength)
            guard n > 0 else { return }
            var suma: Float = 0
            for i in 0..<n { suma += canal[i] * canal[i] }
            let rms = sqrt(suma / Float(n))

            let db = 20 * log10(max(rms, 0.000_01))
            nivel(Double(max(0, min(1, (db + 50) / 40))))
        }
    }

    nonisolated private static func bloqueResultado(_ hecho: @escaping @Sendable (String?, Bool) -> Void) -> (SFSpeechRecognitionResult?, (any Error)?) -> Void {
        { resultado, error in
            hecho(resultado?.bestTranscription.formattedString, resultado?.isFinal ?? (error != nil))
        }
    }

    private static func reconocedor() -> SFSpeechRecognizer? {
        SFSpeechRecognizer(locale: Locale(identifier: "\(idiomaActual.rawValue)-\(regionActual)"))
            ?? SFSpeechRecognizer(locale: Locale(identifier: idiomaActual.rawValue))
    }

    nonisolated private static func permisos() async -> Bool {
        let voz = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { estado in c.resume(returning: estado == .authorized) }
        }
        guard voz else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}

nonisolated private final class CajaPeticion: @unchecked Sendable {
    let peticion: SFSpeechAudioBufferRecognitionRequest
    init(_ p: SFSpeechAudioBufferRecognitionRequest) { peticion = p }
}

@Observable
final class VozLobo {
    var hablando = false
    @ObservationIgnored private let sintetizador = AVSpeechSynthesizer()
    @ObservationIgnored private var delegado: DelegadoVoz?

    func decir(_ texto: String) {
        sintetizador.stopSpeaking(at: .immediate)
        let frase = AVSpeechUtterance(string: texto)

        frase.voice = LlamadaVoz.mejorVoz(para: texto)
        frase.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        let d = DelegadoVoz { [weak self] activo in
            Task { @MainActor in self?.hablando = activo }
        }
        delegado = d
        sintetizador.delegate = d
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        sintetizador.speak(frase)
    }

    func callar() {
        sintetizador.stopSpeaking(at: .immediate)
        hablando = false
    }
}

nonisolated private final class DelegadoVoz: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    let cambio: @Sendable (Bool) -> Void
    init(_ cambio: @escaping @Sendable (Bool) -> Void) { self.cambio = cambio }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) { cambio(true) }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { cambio(false) }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) { cambio(false) }
}
