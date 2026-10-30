@preconcurrency import AVFoundation
import SwiftUI

struct MensajeSala: Identifiable, Equatable {
    nonisolated enum Tipo: String { case texto, voz, foto }

    var id: String
    var de: String
    var tipo: Tipo
    var texto: String
    var archivo: String
    var duracion: Double
    var fecha: Date
}

@Observable
final class ChatSala: ParteDeSala {
    let nombre = "chat"
    weak var sala: SalaEnVivo?
    let yo: String

    private(set) var mensajes: [MensajeSala] = []
    private(set) var sinLeer = 0
    private(set) var fotos: [String: UIImage] = [:]

    private(set) var sonando: String?
    private(set) var avance: Double = 0

    var viendo = false { didSet { if viendo { marcarLeido() } } }

    let grabadora = GrabadoraVoz()
    @ObservationIgnored private var empuje = IDEmpuje()
    @ObservationIgnored private var reproductor: AVAudioPlayer?
    @ObservationIgnored private var reloj: Timer?
    @ObservationIgnored private var bajando: Set<String> = []

    init(yo: String) { self.yo = yo }

    private var claveLeido: String { "hoot.salas.leido.\(sala?.id ?? "")" }

    func actualizar(_ valor: JSONVivo, cambio: [String]) {
        var lista: [MensajeSala] = []
        for (id, m) in valor.objeto {
            lista.append(MensajeSala(id: id, de: m["de"].texto ?? "", tipo: MensajeSala.Tipo(rawValue: m["tipo"].texto ?? "") ?? .texto,
                                     texto: m["texto"].texto ?? "", archivo: m["archivo"].texto ?? "", duracion: m["dur"].numero ?? 0,
                                     fecha: Date(timeIntervalSince1970: (m["t"].numero ?? 0) / 1000)))
        }
        lista.sort { $0.id < $1.id }

        let mios = mensajes.filter { m in m.de == yo && !lista.contains { $0.id == m.id } }
        let todos = (lista + mios).sorted { $0.id < $1.id }
        if todos != mensajes { conMuelle { mensajes = todos } }
        for m in todos where m.tipo == .foto && fotos[m.archivo] == nil { bajarFoto(m.archivo) }
        if viendo { marcarLeido() } else { contarSinLeer() }
    }

    private func contarSinLeer() {
        let leido = UserDefaults.standard.string(forKey: claveLeido) ?? ""
        sinLeer = mensajes.filter { $0.de != yo && $0.id > leido }.count
    }

    private func marcarLeido() {
        if let ultimo = mensajes.last?.id { UserDefaults.standard.set(ultimo, forKey: claveLeido) }
        sinLeer = 0
    }

    private func bajarFoto(_ archivo: String) {
        guard !bajando.contains(archivo) else { return }
        bajando.insert(archivo)
        Task {
            if let d = await sala?.bajarArchivo(archivo), let img = UIImage(data: d) { fotos[archivo] = img }
            bajando.remove(archivo)
        }
    }

    func mandarTexto(_ t: String) {
        let texto = String(t.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000))
        guard !texto.isEmpty else { return }
        mandar(MensajeSala(id: empuje.nuevo(), de: yo, tipo: .texto, texto: texto, archivo: "", duracion: 0, fecha: Date()))
    }

    func mandarFoto(_ imagen: UIImage) async {
        let img = imagen.reducida(lado: 1400)
        guard let datos = img.jpegData(compressionQuality: 0.7) else { return }
        let id = empuje.nuevo()
        let archivo = await sala?.subirArchivo(datos) ?? "local-\(id)"
        fotos[archivo] = img
        mandar(MensajeSala(id: id, de: yo, tipo: .foto, texto: "", archivo: archivo, duracion: 0, fecha: Date()))
    }

    func mandarVoz() async {
        guard let (url, dur) = grabadora.terminar(), dur >= 0.6, let datos = try? Data(contentsOf: url) else { return }
        let id = empuje.nuevo()
        let archivo = await sala?.subirArchivo(datos) ?? "local-\(id)"
        if archivo.hasPrefix("local-") { ArchivosSala.guardar(datos, archivo) }
        mandar(MensajeSala(id: id, de: yo, tipo: .voz, texto: "", archivo: archivo, duracion: dur, fecha: Date()))
    }

    private func mandar(_ m: MensajeSala) {
        conMuelle { mensajes.append(m) }
        var v: JSONVivo = ["de": .texto(m.de), "tipo": .texto(m.tipo.rawValue), "t": JSONVivo.horaServidor]
        if !m.texto.isEmpty { v.poner(.texto(m.texto), en: ["texto"]) }
        if !m.archivo.isEmpty { v.poner(.texto(m.archivo), en: ["archivo"]) }
        if m.duracion > 0 { v.poner(.numero((m.duracion * 10).rounded() / 10), en: ["dur"]) }
        sala?.escribir("chat/\(m.id)", v)
        marcarLeido()
    }

    func alternar(_ m: MensajeSala) {
        if sonando == m.id { pararVoz(); return }
        pararVoz()
        sonando = m.id
        avance = 0
        Task {
            guard let datos = await sala?.bajarArchivo(m.archivo) ?? ArchivosSala.leer(m.archivo) else { sonando = nil; return }
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            guard sonando == m.id, let r = try? AVAudioPlayer(data: datos) else { sonando = nil; return }
            reproductor = r
            r.play()
            reloj = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let r = self.reproductor else { return }
                    self.avance = r.duration > 0 ? r.currentTime / r.duration : 0
                    if !r.isPlaying { self.pararVoz() }
                }
            }
        }
    }

    func pararVoz() {
        reproductor?.stop()
        reproductor = nil
        reloj?.invalidate()
        reloj = nil
        sonando = nil
        avance = 0
    }

    func parar() {
        pararVoz()
        grabadora.cancelar()
    }

    func ponerEjemplo(amigo: String) {
        let ahora = Reloj.ahora
        mensajes = [
            MensajeSala(id: "m1", de: amigo, tipo: .texto, texto: L("¿Hacemos primero el 3?", "Shall we do number 3 first?", "Facciamo prima il 3?"),
                        archivo: "", duracion: 0, fecha: ahora.addingTimeInterval(-300)),
            MensajeSala(id: "m2", de: yo, tipo: .texto, texto: L("Vale. Yo dibujo el triángulo", "OK. I'll draw the triangle", "Ok. Disegno io il triangolo"),
                        archivo: "", duracion: 0, fecha: ahora.addingTimeInterval(-280)),
            MensajeSala(id: "m3", de: amigo, tipo: .voz, texto: "", archivo: "ejemplo-voz", duracion: 14, fecha: ahora.addingTimeInterval(-200)),
            MensajeSala(id: "m4", de: yo, tipo: .foto, texto: "", archivo: "ejemplo-libro", duracion: 0, fecha: ahora.addingTimeInterval(-120)),
            MensajeSala(id: "m5", de: amigo, tipo: .texto, texto: L("La foto del libro va en la pizarra, ¿no?", "The book photo goes on the board, right?",
                                                                   "La foto del libro va sulla lavagna, no?"),
                        archivo: "", duracion: 0, fecha: ahora.addingTimeInterval(-60)),
        ]
        fotos["ejemplo-libro"] = UIImage.paginaDeLibro
        sinLeer = 2
    }
}

@Observable
final class GrabadoraVoz: NSObject, AVAudioRecorderDelegate {
    private(set) var grabando = false
    private(set) var segundos: Double = 0

    private(set) var nivel: Double = 0

    @ObservationIgnored private var grabador: AVAudioRecorder?
    @ObservationIgnored private var reloj: Timer?
    static let maximo: TimeInterval = 120

    func empezar() async -> Bool {
        guard await AVAudioApplication.requestRecordPermission() else { return false }
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try? s.setActive(true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nota-\(UUID().uuidString).m4a")
        let ajustes: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 22_050, AVNumberOfChannelsKey: 1,
                                      AVEncoderBitRateKey: 24_000, AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue]
        guard let g = try? AVAudioRecorder(url: url, settings: ajustes) else { return false }
        g.isMeteringEnabled = true
        g.delegate = self
        guard g.record(forDuration: Self.maximo) else { return false }
        grabador = g
        grabando = true
        segundos = 0
        reloj = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let g = self.grabador else { return }
                g.updateMeters()
                self.segundos = g.currentTime
                self.nivel = Double(max(0, min(1, (g.averagePower(forChannel: 0) + 50) / 50)))
            }
        }
        return true
    }

    func terminar() -> (URL, Double)? {
        guard let g = grabador else { return nil }
        let dur = g.currentTime
        g.stop()
        limpiar()
        return (g.url, dur)
    }

    func cancelar() {
        guard let g = grabador else { return }
        g.stop()
        g.deleteRecording()
        limpiar()
    }

    private func limpiar() {
        reloj?.invalidate()
        reloj = nil
        grabador = nil
        grabando = false
        nivel = 0
    }
}
