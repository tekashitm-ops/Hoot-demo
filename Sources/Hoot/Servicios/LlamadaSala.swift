@preconcurrency import AVFoundation
import CallKit
import SwiftUI

@Observable
final class LlamadaSala: NSObject, ParteDeSala {
    nonisolated enum Fase: Equatable {
        case nada

        case llamando

        case entrante
        case enCurso(desde: Date)
    }

    let nombre = "llamada"
    weak var sala: SalaEnVivo?
    let yo: String

    private(set) var fase: Fase = .nada
    var silenciado = false { didSet { motor.silenciado = silenciado } }
    var altavoz = false { didSet { motor.altavoz(altavoz) } }

    private(set) var nivelAmigo: Double = 0
    private(set) var error: String?

    @ObservationIgnored let motor = MotorVoz()
    @ObservationIgnored private var proveedor: CXProvider?
    @ObservationIgnored private let controlador = CXCallController()
    @ObservationIgnored private var uuid: UUID?
    @ObservationIgnored private var ultimoN = -1
    @ObservationIgnored private var miN = 0
    @ObservationIgnored private var idLlamada = ""

    @ObservationIgnored private var audioActivo = false

    init(yo: String) {
        self.yo = yo
        super.init()
        motor.alTenerTrozo = { [weak self] datos in
            Task { @MainActor in self?.mandarTrozo(datos) }
        }
        motor.alOirAmigo = { [weak self] nivel in
            Task { @MainActor in self?.nivelAmigo = nivel }
        }
    }

    var enLlamada: Bool { if case .enCurso = fase { return true }; return false }

    func actualizar(_ valor: JSONVivo, cambio: [String]) {
        if cambio.first == "audio" {
            leerAudio(valor["audio"], ruta: Array(cambio.dropFirst()))
            return
        }
        let estado = valor["estado"]
        let de = estado["de"].texto ?? ""
        let id = estado["id"].texto ?? ""

        let vieja = (estado["t"].numero).map { Date().timeIntervalSince1970 * 1000 - $0 > 60_000 } ?? false
        switch estado["fase"].texto {
        case "llamando" where de != yo && fase == .nada && !vieja:
            idLlamada = id
            entrante(de: sala?.amigo?.nombre ?? "")
        case "en curso":
            if fase == .llamando || fase == .entrante { empezarVoz() }
        case "fin", nil:
            if fase != .nada { terminarAqui() }
        default: break
        }
    }

    private func leerAudio(_ j: JSONVivo, ruta: [String]) {
        guard enLlamada, let amigo = sala?.amigo?.uid else { return }
        let trozos = j[amigo].objeto.values.compactMap { t -> (Int, Data)? in
            guard let n = t["n"].numero, let s = t["d"].texto, let d = Data(base64Encoded: s) else { return nil }
            return (Int(n), d)
        }.filter { $0.0 > ultimoN }.sorted { $0.0 < $1.0 }
        for (n, d) in trozos {
            ultimoN = n
            motor.recibir(d)
        }
    }

    func llamar() {
        guard fase == .nada, let sala, let amigo = sala.amigo else { return }
        error = nil
        let u = UUID()
        uuid = u
        idLlamada = u.uuidString
        fase = .llamando
        ultimoN = -1
        sala.escribir("llamada", ["estado": ["de": .texto(yo), "fase": "llamando", "id": .texto(idLlamada), "t": JSONVivo.horaServidor]])
        prepararProveedor()
        let accion = CXStartCallAction(call: u, handle: CXHandle(type: .generic, value: amigo.nombre))
        controlador.request(CXTransaction(action: accion)) { _ in }
    }

    private func entrante(de nombre: String) {
        let u = UUID()
        uuid = u
        fase = .entrante
        ultimoN = -1
        prepararProveedor()
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: nombre)
        update.localizedCallerName = nombre
        update.hasVideo = false
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsDTMF = false
        proveedor?.reportNewIncomingCall(with: u, update: update) { _ in }
    }

    func contestar() {
        guard fase == .entrante, let u = uuid else { return }
        controlador.request(CXTransaction(action: CXAnswerCallAction(call: u))) { [weak self] e in
            if e != nil { Task { @MainActor in self?.contestado() } }
        }
    }

    private func contestado() {
        sala?.escribir("llamada/estado", ["de": .texto(sala?.amigo?.uid ?? ""), "fase": "en curso", "id": .texto(idLlamada), "t": JSONVivo.horaServidor])
        empezarVoz()
    }

    func colgar() {
        guard fase != .nada else { return }
        if let u = uuid {
            controlador.request(CXTransaction(action: CXEndCallAction(call: u))) { [weak self] e in
                if e != nil { Task { @MainActor in self?.colgado() } }
            }
        } else {
            colgado()
        }
    }

    private func colgado() {
        sala?.escribir("llamada", ["estado": ["de": .texto(yo), "fase": "fin", "id": .texto(idLlamada), "t": JSONVivo.horaServidor]])
        terminarAqui()
    }

    private func terminarAqui() {
        motor.parar()
        if let u = uuid { proveedor?.reportCall(with: u, endedAt: Date(), reason: .remoteEnded) }
        uuid = nil
        fase = .nada
        silenciado = false
        altavoz = false
        nivelAmigo = 0
    }

    private func empezarVoz() {
        guard !enLlamada else { return }
        fase = .enCurso(desde: Date())
        miN = 0
        if let u = uuid { proveedor?.reportOutgoingCall(with: u, connectedAt: Date()) }

        if proveedor == nil || audioActivo { arrancarMotor() }
    }

    private func arrancarMotor() {
        do {
            try motor.empezar()
        } catch {
            self.error = L("No se ha podido usar el micrófono.", "Couldn't use the microphone.", "Impossibile usare il microfono.")
            colgar()
        }
    }

    private func mandarTrozo(_ datos: Data) {
        guard enLlamada, !silenciado, let sala else { return }
        let n = miN
        miN += 1
        sala.escribir("llamada/audio/\(yo)/\(n % 8)", ["n": .numero(Double(n)), "d": .texto(datos.base64EncodedString())])
    }

    func parar() {
        if fase != .nada { colgar() }
    }

    private func prepararProveedor() {
        guard proveedor == nil, !ModoCapturas.activo else { return }
        let c = CXProviderConfiguration()
        c.supportsVideo = false
        c.maximumCallGroups = 1
        c.maximumCallsPerCallGroup = 1
        c.supportedHandleTypes = [.generic]
        c.includesCallsInRecents = false
        if let icono = UIImage(systemName: "moonphase.first.quarter")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 40)).pngData() {
            c.iconTemplateImageData = icono
        }
        let p = CXProvider(configuration: c)
        p.setDelegate(self, queue: nil)
        proveedor = p
    }

    func ponerEjemplo() {
        fase = .enCurso(desde: Reloj.ahora.addingTimeInterval(-724))
        nivelAmigo = 0.6
    }

    func ponerEntranteEjemplo() {
        fase = .entrante
    }
}

extension LlamadaSala: CXProviderDelegate {
    nonisolated func providerDidReset(_ provider: CXProvider) {
        Task { @MainActor in self.terminarAqui() }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: nil)
        action.fulfill()
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Task { @MainActor in self.contestado() }
        action.fulfill()
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Task { @MainActor in
            if self.fase != .nada { self.colgado() }
        }
        action.fulfill()
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        let silencio = action.isMuted
        Task { @MainActor in self.silenciado = silencio }
        action.fulfill()
    }

    nonisolated func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        Task { @MainActor in
            self.audioActivo = true
            if self.enLlamada { self.arrancarMotor() }
        }
    }

    nonisolated func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        Task { @MainActor in
            self.audioActivo = false
            self.motor.parar()
        }
    }
}

nonisolated final class MotorVoz: @unchecked Sendable {
    var alTenerTrozo: (@Sendable (Data) -> Void)?
    var alOirAmigo: (@Sendable (Double) -> Void)?
    var silenciado = false

    private let cola = DispatchQueue(label: "hoot.voz")
    private var motor: AVAudioEngine?
    private var jugador: AVAudioPlayerNode?
    private let voz = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
    private let ley = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 8_000, channels: 1, interleaved: true)!
    private var aVoz: AVAudioConverter?
    private var aLey: AVAudioConverter?
    private var desdeLey: AVAudioConverter?
    private var codificador: AVAudioConverter?
    private var decodificador: AVAudioConverter?
    private var formatoELD: AVAudioFormat?
    private var acumulado: AVAudioPCMBuffer?
    private var enCola = 0
    private static let framesPorTrozo: AVAudioFrameCount = 1_600

    init() {
        var asbd = AudioStreamBasicDescription(mSampleRate: 16_000, mFormatID: kAudioFormatMPEG4AAC_ELD, mFormatFlags: 0, mBytesPerPacket: 0,
                                               mFramesPerPacket: 480, mBytesPerFrame: 0, mChannelsPerFrame: 1, mBitsPerChannel: 0, mReserved: 0)
        if let f = AVAudioFormat(streamDescription: &asbd), let c = AVAudioConverter(from: voz, to: f), let d = AVAudioConverter(from: f, to: voz) {
            c.bitRate = 24_000
            formatoELD = f
            codificador = c
            decodificador = d
        }
        aLey = AVAudioConverter(from: voz, to: ley)
        desdeLey = AVAudioConverter(from: ley, to: voz)
    }

    func empezar() throws {
        try cola.sync {
            guard motor == nil else { return }
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP])
            try s.setActive(true)
            let m = AVAudioEngine()
            try m.inputNode.setVoiceProcessingEnabled(true)
            let j = AVAudioPlayerNode()
            m.attach(j)
            m.connect(j, to: m.mainMixerNode, format: voz)
            let entrada = m.inputNode.outputFormat(forBus: 0)
            aVoz = AVAudioConverter(from: entrada, to: voz)
            m.inputNode.installTap(onBus: 0, bufferSize: 1_024, format: entrada) { [weak self] buffer, _ in
                self?.cola.async { self?.grabado(buffer) }
            }
            try m.start()

            motor = m
            jugador = j
            enCola = 0
        }
    }

    func parar() {
        cola.sync {
            motor?.inputNode.removeTap(onBus: 0)
            jugador?.stop()
            motor?.stop()
            motor = nil
            jugador = nil
            acumulado = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func altavoz(_ si: Bool) {
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(si ? .speaker : .none)
    }

    private func grabado(_ buffer: AVAudioPCMBuffer) {
        guard let aVoz, motor != nil else { return }
        let capacidad = AVAudioFrameCount(Double(buffer.frameLength) * voz.sampleRate / buffer.format.sampleRate) + 32
        guard let pcm = AVAudioPCMBuffer(pcmFormat: voz, frameCapacity: capacidad) else { return }
        var dado = false
        aVoz.convert(to: pcm, error: nil) { _, estado in
            if dado { estado.pointee = .noDataNow; return nil }
            dado = true
            estado.pointee = .haveData
            return buffer
        }
        anadir(pcm)
    }

    private func anadir(_ pcm: AVAudioPCMBuffer) {
        if acumulado == nil { acumulado = AVAudioPCMBuffer(pcmFormat: voz, frameCapacity: Self.framesPorTrozo * 3) }
        guard let a = acumulado, let origen = pcm.floatChannelData?[0], let destino = a.floatChannelData?[0] else { return }
        let n = Int(min(pcm.frameLength, a.frameCapacity - a.frameLength))
        (destino + Int(a.frameLength)).update(from: origen, count: n)
        a.frameLength += AVAudioFrameCount(n)
        guard a.frameLength >= Self.framesPorTrozo else { return }
        let trozo = silenciado ? nil : comprimir(a)
        acumulado = nil
        if let trozo { alTenerTrozo?(trozo) }
    }

    private func comprimir(_ pcm: AVAudioPCMBuffer) -> Data? {
        if let codificador, let formatoELD {
            let salida = AVAudioCompressedBuffer(format: formatoELD, packetCapacity: 8, maximumPacketSize: max(codificador.maximumOutputPacketSize, 512))
            var dado = false
            let r = codificador.convert(to: salida, error: nil) { _, estado in
                if dado { estado.pointee = .noDataNow; return nil }
                dado = true
                estado.pointee = .haveData
                return pcm
            }
            if r != .error, salida.packetCount > 0, let desc = salida.packetDescriptions {
                var d = Data([1, UInt8(salida.packetCount)])
                for i in 0..<Int(salida.packetCount) {
                    let t = UInt16(desc[i].mDataByteSize)
                    d.append(UInt8(t >> 8)); d.append(UInt8(t & 0xFF))
                }
                d.append(Data(bytes: salida.data, count: Int(salida.byteLength)))
                return d
            }
            if r != .error { return nil }
        }
        guard let aLey, let s = AVAudioPCMBuffer(pcmFormat: ley, frameCapacity: pcm.frameLength / 2 + 16) else { return nil }
        var dado = false
        aLey.convert(to: s, error: nil) { _, estado in
            if dado { estado.pointee = .noDataNow; return nil }
            dado = true
            estado.pointee = .haveData
            return pcm
        }
        guard let muestras = s.int16ChannelData?[0] else { return nil }
        var d = Data([2])
        d.append(contentsOf: (0..<Int(s.frameLength)).map { LeyMu.codificar(muestras[$0]) })
        return d
    }

    func recibir(_ datos: Data) {
        cola.async { [weak self] in self?.sonar(datos) }
    }

    private func sonar(_ datos: Data) {
        guard let jugador, motor != nil, let tipo = datos.first else { return }
        var pcm: AVAudioPCMBuffer?
        if tipo == 1, let decodificador, let formatoELD, datos.count > 2 {
            let n = Int(datos[1])
            var tam: [Int] = []
            var i = 2
            for _ in 0..<n where i + 1 < datos.count { tam.append(Int(datos[i]) << 8 | Int(datos[i + 1])); i += 2 }
            let total = tam.reduce(0, +)
            guard i + total <= datos.count else { return }
            let entrada = AVAudioCompressedBuffer(format: formatoELD, packetCapacity: AVAudioPacketCount(n), maximumPacketSize: max(tam.max() ?? 1, 1))
            var desp = 0
            datos.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                entrada.data.copyMemory(from: base + i, byteCount: total)
            }
            if let desc = entrada.packetDescriptions {
                for (k, t) in tam.enumerated() {
                    desc[k] = AudioStreamPacketDescription(mStartOffset: Int64(desp), mVariableFramesInPacket: 0, mDataByteSize: UInt32(t))
                    desp += t
                }
            }
            entrada.packetCount = AVAudioPacketCount(n)
            entrada.byteLength = UInt32(total)
            if let salida = AVAudioPCMBuffer(pcmFormat: voz, frameCapacity: AVAudioFrameCount(480 * n + 480)) {
                var dado = false
                decodificador.convert(to: salida, error: nil) { _, estado in
                    if dado { estado.pointee = .noDataNow; return nil }
                    dado = true
                    estado.pointee = .haveData
                    return entrada
                }
                pcm = salida
            }
        } else if tipo == 2, let desdeLey, let s = AVAudioPCMBuffer(pcmFormat: ley, frameCapacity: AVAudioFrameCount(datos.count)) {
            let bytes = Array(datos.dropFirst())
            guard let destino = s.int16ChannelData?[0] else { return }
            for (k, b) in bytes.enumerated() { destino[k] = LeyMu.decodificar(b) }
            s.frameLength = AVAudioFrameCount(bytes.count)
            if let salida = AVAudioPCMBuffer(pcmFormat: voz, frameCapacity: AVAudioFrameCount(bytes.count * 2 + 32)) {
                var dado = false
                desdeLey.convert(to: salida, error: nil) { _, estado in
                    if dado { estado.pointee = .noDataNow; return nil }
                    dado = true
                    estado.pointee = .haveData
                    return s
                }
                pcm = salida
            }
        }
        guard let pcm, pcm.frameLength > 0 else { return }

        if let m = pcm.floatChannelData?[0] {
            var suma: Float = 0
            for k in 0..<Int(pcm.frameLength) { suma += m[k] * m[k] }
            let rms = sqrt(suma / Float(pcm.frameLength))
            alOirAmigo?(Double(min(1, rms * 6)))
        }

        if enCola > 6 { return }
        enCola += 1
        jugador.scheduleBuffer(pcm) { [weak self] in
            self?.cola.async {
                guard let self else { return }
                self.enCola -= 1
                if self.enCola == 0 { self.jugador?.pause() }
            }
        }
        if !jugador.isPlaying && enCola >= 2 { jugador.play() }
    }
}
