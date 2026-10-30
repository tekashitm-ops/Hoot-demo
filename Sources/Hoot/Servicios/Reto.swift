import Foundation
import FoundationModels
import MultipeerConnectivity

@Observable
final class RetoCercano {
    enum Fase: Equatable {
        case buscando
        case invitando(String)
        case preparando
        case jugando
        case fin
        case error(String)
    }

    struct Amigo: Identifiable, Hashable {
        var id: String
        var nombre: String
    }

    struct PreguntaReto: Codable, Hashable, Sendable {
        var texto: String
        var esperada: String
    }

    enum Mensaje: Codable, Sendable {
        case preguntas([PreguntaReto], tema: String)
        case respuesta(Int, String)
        case resultado(Int, anfitrion: Bool, invitado: Bool, comentario: String)
        case fin
    }

    private(set) var fase: Fase = .buscando
    private(set) var amigos: [Amigo] = []

    var invitacion: (nombre: String, tema: String)?
    private(set) var rival = ""
    private(set) var anfitrion = false
    private(set) var tema = ""
    private(set) var preguntas: [PreguntaReto] = []
    private(set) var actual = 0
    private(set) var aciertosYo = 0
    private(set) var aciertosRival = 0

    private(set) var contestada = false

    private(set) var ultimo: (yo: Bool, rival: Bool, comentario: String)?

    private(set) var misAciertos: [Bool] = []

    @ObservationIgnored private let enlace: EnlaceReto
    @ObservationIgnored private var temaIDs: [UUID] = []
    @ObservationIgnored private var materiales: [UUID: String] = [:]
    @ObservationIgnored private var respuestasAnfitrion: [Int: String] = [:]
    @ObservationIgnored private var respuestasInvitado: [Int: String] = [:]
    @ObservationIgnored private var curso = ""

    init(nombre: String, enlace propio: EnlaceReto? = nil) {
        enlace = propio ?? EnlaceMC(nombre: nombre.isEmpty ? "Hoot" : nombre)
        enlace.alCambiarAmigos = { [weak self] nombres in
            Task { @MainActor in self?.amigos = nombres.map { Amigo(id: $0, nombre: Self.limpio($0)) } }
        }
        enlace.alInvitar = { [weak self] nombre, tema in
            Task { @MainActor in self?.invitacion = (Self.limpio(nombre), tema) }
        }
        enlace.alConectar = { [weak self] nombre in
            Task { @MainActor in self?.conectado(con: Self.limpio(nombre)) }
        }
        enlace.alDesconectar = { [weak self] in
            Task { @MainActor in self?.desconectado() }
        }
        enlace.alRecibir = { [weak self] datos in
            Task { @MainActor in self?.recibir(datos) }
        }
    }

    private static func limpio(_ s: String) -> String { s.components(separatedBy: "·").first?.trimmingCharacters(in: .whitespaces) ?? s }

    var cuantas: Int { preguntas.count }
    var pregunta: PreguntaReto? { preguntas.indices.contains(actual) ? preguntas[actual] : nil }

    func buscar(temas: [Tema], nombreTema: String, curso: String) {
        temaIDs = temas.filter { !$0.textoLeido.isEmpty }.map(\.id)
        materiales = Dictionary(temas.map { ($0.id, $0.textoLeido) }, uniquingKeysWith: { a, _ in a })
        tema = nombreTema
        self.curso = curso
        fase = .buscando
        enlace.empezar(tema: nombreTema)
    }

    func retar(_ amigo: Amigo) {
        guard DisponibilidadIA.actual == .lista else {
            fase = .error(L("Para retar, tu iPhone tiene que tener Apple Intelligence. Que te rete tu amigo.",
                            "To challenge, your iPhone needs Apple Intelligence. Let your friend challenge you.",
                            "Per sfidare, il tuo iPhone deve avere Apple Intelligence. Fatti sfidare dal tuo amico."))
            return
        }
        guard !temaIDs.isEmpty else {
            fase = .error(L("Estos temas aún no tienen material. Dales fotos o un PDF.", "These topics have no material yet. Give them photos or a PDF.",
                            "Questi argomenti non hanno ancora materiale. Dagli foto o un PDF."))
            return
        }
        anfitrion = true
        fase = .invitando(amigo.nombre)
        enlace.invitar(amigo.id, tema: tema)
    }

    func responderInvitacion(_ si: Bool) {
        anfitrion = false
        enlace.responder(si)
        invitacion = nil
    }

    func salir() {
        if fase == .jugando { mandar(.fin) }
        enlace.parar()
    }

    private func conectado(con nombre: String) {
        rival = nombre
        enlace.dejarDeBuscar()
        if anfitrion {
            fase = .preparando
            Task { await prepararYMandar() }
        } else {
            fase = .preparando
        }
    }

    private func desconectado() {
        guard fase != .fin else { return }
        if case .buscando = fase { return }
        fase = .error(L("Se ha cortado: \(rival.isEmpty ? "tu amigo" : rival) se ha ido.", "Disconnected: \(rival.isEmpty ? "your friend" : rival) left.",
                        "Si è interrotta: \(rival.isEmpty ? "il tuo amico" : rival) se n'è andato."))
    }

    private func prepararYMandar() async {
        let n = 4
        let ids = temaIDs
        var lista: [PreguntaReto] = []
        for (i, id) in ids.enumerated() {
            let k = n / ids.count + (i < n % ids.count ? 1 : 0)
            guard k > 0 else { continue }
            lista += (try? await Self.generar(k, material: materiales[id] ?? "")) ?? []
        }
        guard !lista.isEmpty else {
            fase = .error(L("No se han podido sacar preguntas del material.", "Couldn't make questions from the material.", "Non è stato possibile fare domande dal materiale."))
            return
        }
        lista.shuffle()
        empezar(lista)
        mandar(.preguntas(lista, tema: tema))
    }

    static func generar(_ n: Int, material: String) async throws -> [PreguntaReto] {
        let texto = try await TrabajoIA.ajustar(material, maximo: TrabajoIA.caracteresMaximos - 2500)
        let p = DynamicGenerationSchema(name: "Pregunta", properties: [
            .init(name: "pregunta", description: L("Una pregunta corta", "A short question", "Una domanda breve"), schema: .init(type: String.self)),
            .init(name: "respuesta", description: L("La respuesta, en pocas palabras", "The answer, in a few words", "La risposta, in poche parole"), schema: .init(type: String.self)),
        ])
        let raiz = DynamicGenerationSchema(name: "Reto", properties: [
            .init(name: "preguntas", schema: .init(arrayOf: .init(referenceTo: "Pregunta"), minimumElements: n, maximumElements: n)),
        ])
        let esquema = try GenerationSchema(root: raiz, dependencies: [p])
        let r = try await MotorIA.conForma(.reto,
                                           instrucciones: L("Haces preguntas de repaso cortas, de respuesta corta. Usa solo el material. Escribe en español.",
                                                            "You write short review questions with short answers. Use only the material. Write in English.",
                                                            "Fai domande di ripasso brevi, a risposta breve. Usa solo il materiale. Scrivi in italiano."),
                                           prompt: L("Haz \(n) preguntas de respuesta corta (una palabra o una frase) para un reto entre dos amigos.\n\nMATERIAL:\n\(texto)",
                                               "Write \(n) short-answer questions (one word or one sentence) for a challenge between two friends.\n\nMATERIAL:\n\(texto)",
                                               "Fai \(n) domande a risposta breve (una parola o una frase) per una sfida tra due amici.\n\nMATERIALE:\n\(texto)"),
                                           esquema: esquema, maximo: 500, temperatura: 0.8)
        let lista = try r.value([GeneratedContent].self, forProperty: "preguntas")
        return lista.compactMap { c in
            guard let q = try? c.value(String.self, forProperty: "pregunta"), let e = try? c.value(String.self, forProperty: "respuesta") else { return nil }
            return PreguntaReto(texto: q, esperada: e)
        }
    }

    private func empezar(_ lista: [PreguntaReto]) {
        preguntas = lista
        actual = 0
        aciertosYo = 0
        aciertosRival = 0
        misAciertos = []
        respuestasAnfitrion = [:]
        respuestasInvitado = [:]
        contestada = false
        ultimo = nil
        conMuelle { fase = .jugando }
    }

    func responder(_ texto: String) {
        guard fase == .jugando, !contestada else { return }
        contestada = true
        if anfitrion {
            respuestasAnfitrion[actual] = texto
            corregirSiEstan()
        } else {
            mandar(.respuesta(actual, texto))
        }
    }

    private func corregirSiEstan() {
        guard anfitrion, let a = respuestasAnfitrion[actual], let b = respuestasInvitado[actual], let p = pregunta else { return }
        let i = actual
        Task {
            async let ca = Self.acierta(p, a, curso: curso)
            async let cb = Self.acierta(p, b, curso: curso)
            let (bienA, bienB) = await (ca, cb)
            let comentario = L("Era: \(p.esperada)", "It was: \(p.esperada)", "Era: \(p.esperada)")
            mandar(.resultado(i, anfitrion: bienA, invitado: bienB, comentario: comentario))
            aplicar(i, yo: bienA, rival: bienB, comentario: comentario)
        }
    }

    static func acierta(_ p: PreguntaReto, _ respuesta: String, curso: String) async -> Bool {
        let r = respuesta.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !r.isEmpty else { return false }
        if r.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) == p.esperada.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) { return true }
        guard let c = try? await PruebaIA.corregir(pregunta: p.texto, esperada: p.esperada, respuesta: r, apuntes: "", curso: curso) else { return false }
        return !c.veredicto.fallada
    }

    private func aplicar(_ i: Int, yo: Bool, rival: Bool, comentario: String) {
        guard i == actual else { return }
        conMuelle(Diseno.muelleRebote) {
            if yo { aciertosYo += 1 }
            if rival { aciertosRival += 1 }
            ultimo = (yo, rival, comentario)
        }
        misAciertos.append(yo)
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            guard self.fase == .jugando else { return }
            if self.actual + 1 < self.preguntas.count {
                conMuelle {
                    self.actual += 1
                    self.contestada = false
                    self.ultimo = nil
                }
            } else {
                conMuelle { self.fase = .fin }
            }
        }
    }

    private func mandar(_ m: Mensaje) {
        guard let datos = try? JSONEncoder().encode(m) else { return }
        enlace.mandar(datos)
    }

    private func recibir(_ datos: Data) {
        guard let m = try? JSONDecoder().decode(Mensaje.self, from: datos) else { return }
        switch m {
        case .preguntas(let lista, let t):
            tema = t
            empezar(lista)
        case .respuesta(let i, let texto):
            guard anfitrion else { return }
            respuestasInvitado[i] = texto
            corregirSiEstan()
        case .resultado(let i, let a, let b, let comentario):
            guard !anfitrion else { return }
            aplicar(i, yo: b, rival: a, comentario: comentario)
        case .fin:
            if fase == .jugando { fase = .fin }
        }
    }

    func intento(fecha: Date = Reloj.ahora) -> (temas: [UUID], intento: Intento)? {
        guard !temaIDs.isEmpty, !misAciertos.isEmpty else { return nil }
        return (temaIDs, Intento(fecha: fecha, respuestas: misAciertos.map { Respuesta(acierto: $0, seguridad: nil) }, mezclado: temaIDs.count > 1))
    }

    func demo(fase f: Fase, rival r: String) {
        rival = r
        tema = "Cartago"
        amigos = [Amigo(id: "Marco", nombre: "Marco"), Amigo(id: "Sara", nombre: "Sara")]
        preguntas = [PreguntaReto(texto: L("¿Quién fundó Cartago según la leyenda?", "Who founded Carthage, according to legend?", "Chi fondò Cartagine secondo la leggenda?"), esperada: "Dido"),
                     PreguntaReto(texto: L("¿Contra quién luchó Cartago en las guerras púnicas?", "Who did Carthage fight in the Punic Wars?", "Contro chi combatté Cartagine nelle guerre puniche?"), esperada: "Roma"),
                     PreguntaReto(texto: L("¿Qué cruzó Aníbal con sus elefantes?", "What did Hannibal cross with his elephants?", "Cosa attraversò Annibale con i suoi elefanti?"), esperada: "Los Alpes"),
                     PreguntaReto(texto: L("¿En qué batalla rodeó Aníbal a los romanos?", "In which battle did Hannibal surround the Romans?", "In quale battaglia Annibale accerchiò i romani?"),
                                  esperada: "Cannas")]
        actual = 3
        aciertosYo = 2
        aciertosRival = 3
        fase = f
    }
}

nonisolated protocol EnlaceReto: AnyObject, Sendable {
    var alCambiarAmigos: (@Sendable ([String]) -> Void)? { get set }
    var alInvitar: (@Sendable (String, String) -> Void)? { get set }
    var alConectar: (@Sendable (String) -> Void)? { get set }
    var alDesconectar: (@Sendable () -> Void)? { get set }
    var alRecibir: (@Sendable (Data) -> Void)? { get set }
    func empezar(tema: String)
    func dejarDeBuscar()
    func parar()
    func invitar(_ nombre: String, tema: String)
    func responder(_ si: Bool)
    func mandar(_ datos: Data)
}

nonisolated private final class EnlaceMC: NSObject, EnlaceReto, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, @unchecked Sendable {
    static let servicio = "hoot-reto"

    var alCambiarAmigos: (@Sendable ([String]) -> Void)?
    var alInvitar: (@Sendable (String, String) -> Void)?
    var alConectar: (@Sendable (String) -> Void)?
    var alDesconectar: (@Sendable () -> Void)?
    var alRecibir: (@Sendable (Data) -> Void)?

    private let yo: MCPeerID
    private let sesion: MCSession
    private var anunciante: MCNearbyServiceAdvertiser?
    private var buscador: MCNearbyServiceBrowser?
    private var vistos: [String: MCPeerID] = [:]
    private var pendiente: ((Bool, MCSession?) -> Void)?
    private let cola = DispatchQueue(label: "hoot.reto")

    init(nombre: String) {

        yo = MCPeerID(displayName: "\(nombre.prefix(40)) · \(Int.random(in: 100...999))")
        sesion = MCSession(peer: yo, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        sesion.delegate = self
    }

    func empezar(tema: String) {
        cola.sync {
            let a = MCNearbyServiceAdvertiser(peer: yo, discoveryInfo: ["tema": String(tema.prefix(60))], serviceType: Self.servicio)
            a.delegate = self
            a.startAdvertisingPeer()
            anunciante = a
            let b = MCNearbyServiceBrowser(peer: yo, serviceType: Self.servicio)
            b.delegate = self
            b.startBrowsingForPeers()
            buscador = b
        }
    }

    func dejarDeBuscar() {
        cola.sync {
            anunciante?.stopAdvertisingPeer()
            buscador?.stopBrowsingForPeers()
        }
    }

    func parar() {
        dejarDeBuscar()
        sesion.disconnect()
    }

    func invitar(_ nombre: String, tema: String) {
        guard let p = cola.sync(execute: { vistos[nombre] }) else { return }
        buscador?.invitePeer(p, to: sesion, withContext: tema.data(using: .utf8), timeout: 30)
    }

    func responder(_ si: Bool) {
        let p = cola.sync { () -> ((Bool, MCSession?) -> Void)? in
            let x = pendiente
            pendiente = nil
            return x
        }
        p?(si, si ? sesion : nil)
    }

    func mandar(_ datos: Data) {
        guard !sesion.connectedPeers.isEmpty else { return }
        try? sesion.send(datos, toPeers: sesion.connectedPeers, with: .reliable)
    }

    private func avisarAmigos() {
        let nombres = cola.sync { Array(vistos.keys).sorted() }
        alCambiarAmigos?(nombres)
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        cola.sync { vistos[peerID.displayName] = peerID }
        avisarAmigos()
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        cola.sync { vistos[peerID.displayName] = nil }
        avisarAmigos()
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        cola.sync { pendiente = invitationHandler }
        alInvitar?(peerID.displayName, context.flatMap { String(data: $0, encoding: .utf8) } ?? "")
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected: alConectar?(peerID.displayName)
        case .notConnected: alDesconectar?()
        default: break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) { alRecibir?(data) }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {}
}
