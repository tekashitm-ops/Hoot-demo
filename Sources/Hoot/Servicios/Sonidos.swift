import AVFoundation
import CoreHaptics
import UIKit

final class Sonidos {
    static let compartido = Sonidos()

    enum Cual: CaseIterable { case aullido, acierto, fallo }

    private var reproductores: [Cual: AVAudioPlayer] = [:]
    private var motor: CHHapticEngine?

    private init() {}

    func tocar(_ cual: Cual) {
        guard !ModoCapturas.activo else { return }
        prepararSesion()
        if let r = reproductor(cual) {
            r.currentTime = 0
            r.play()
        }
        vibrar(cual)
    }

    private func prepararSesion() {
        let sesion = AVAudioSession.sharedInstance()
        guard sesion.category != .playAndRecord, sesion.category != .record else { return }
        if sesion.category != .ambient {
            try? sesion.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        }
    }

    private func reproductor(_ cual: Cual) -> AVAudioPlayer? {
        if let r = reproductores[cual] { return r }
        let base64 = switch cual {
        case .aullido: SonidosDatos.aullido
        case .acierto: SonidosDatos.acierto
        case .fallo: SonidosDatos.fallo
        }
        guard let datos = Data(base64Encoded: base64), let r = try? AVAudioPlayer(data: datos) else { return nil }
        r.prepareToPlay()
        reproductores[cual] = r
        return r
    }

    private func vibrar(_ cual: Cual) {
        switch cual {
        case .acierto: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .fallo: UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
        case .aullido: aullar()
        }
    }

    private func aullar() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        do {
            if motor == nil {
                motor = try CHHapticEngine()
                motor?.isAutoShutdownEnabled = true
            }
            try motor?.start()
            let golpe = CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)], relativeTime: 0)
            let largo = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15)], relativeTime: 0.05, duration: 1.25)
            let curva = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: 0.2),
                CHHapticParameterCurve.ControlPoint(relativeTime: 0.35, value: 1),
                CHHapticParameterCurve.ControlPoint(relativeTime: 0.95, value: 0.8),
                CHHapticParameterCurve.ControlPoint(relativeTime: 1.3, value: 0)], relativeTime: 0)
            let patron = try CHHapticPattern(events: [golpe, largo], parameterCurves: [curva])
            try motor?.makePlayer(with: patron).start(atTime: CHHapticTimeImmediate)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
