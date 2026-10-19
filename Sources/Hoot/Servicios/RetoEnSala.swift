import Foundation

@Observable
final class RetoEnSala: ParteDeSala {
    let nombre = "reto"
    weak var sala: SalaEnVivo?
    let yo: String

    private(set) var reto: RetoCercano?

    private(set) var invitacion: String?

    @ObservationIgnored private var enlace: EnlaceSala?
    @ObservationIgnored private var vistos: Set<String> = []
    @ObservationIgnored private var inicioVisto: Double = 0

    init(yo: String) { self.yo = yo }

    func actualizar(_ valor: JSONVivo, cambio: [String]) {
        let inicio = valor["inicio"]
        let t = inicio["t"].numero ?? 0
        if t != inicioVisto {

            inicioVisto = t
            vistos = []
            if let de = inicio["de"].texto, de != yo, reto == nil {
                conMuelle { invitacion = inicio["tema"].texto ?? "" }
            }
        }
        if !inicio.existe {
            invitacion = nil
        }
        if inicio["de"].texto == yo, let si = valor["respuesta"]["si"].bool {
            if si { enlace?.aceptado(rival: sala?.amigo?.nombre ?? "") } else { enlace?.rechazado() }
        }
        for (id, m) in valor["m"].objeto.sorted(by: { $0.key < $1.key }) where !vistos.contains(id) && m["de"].texto != yo {
            vistos.insert(id)
            if let s = m["d"].texto, let d = Data(base64Encoded: s) { enlace?.alRecibir?(d) }
        }
    }

    func retar(temas: [Tema], nombreTema: String, curso: String) {
        guard let sala, let amigo = sala.amigo else { return }
        let e = EnlaceSala(parte: self, reta: true)
        enlace = e
        let r = RetoCercano(nombre: sala.yo.nombre, enlace: e)
        r.buscar(temas: temas, nombreTema: nombreTema, curso: curso)
        r.retar(RetoCercano.Amigo(id: amigo.uid, nombre: amigo.nombre))
        reto = r
    }

    func responder(_ si: Bool, temas: [Tema], curso: String) {
        guard let tema = invitacion, let sala else { return }
        invitacion = nil
        guard si else {
            sala.escribir("reto/respuesta", ["si": false, "de": .texto(yo)])
            return
        }
        let e = EnlaceSala(parte: self, reta: false)
        enlace = e
        let r = RetoCercano(nombre: sala.yo.nombre, enlace: e)
        r.buscar(temas: temas, nombreTema: tema, curso: curso)
        r.invitacion = (sala.amigo?.nombre ?? "", tema)
        reto = r
        r.responderInvitacion(true)
        e.rival = sala.amigo?.nombre ?? ""
        e.alConectar?(e.rival)
    }

    func terminar() {
        reto?.salir()
        reto = nil
        enlace = nil
        if inicioVisto != 0 { sala?.borrar("reto") }
    }

    fileprivate func escribir(_ ruta: String, _ v: JSONVivo) { sala?.escribir(ruta, v) }

    func parar() {
        reto?.salir()
    }

    func ponerInvitacionEjemplo() {
        invitacion = "Cartago"
    }
}

nonisolated final class EnlaceSala: EnlaceReto, @unchecked Sendable {
    var alCambiarAmigos: (@Sendable ([String]) -> Void)?
    var alInvitar: (@Sendable (String, String) -> Void)?
    var alConectar: (@Sendable (String) -> Void)?
    var alDesconectar: (@Sendable () -> Void)?
    var alRecibir: (@Sendable (Data) -> Void)?
    var rival = ""

    private weak var parte: RetoEnSala?
    private let reta: Bool
    private var empuje = IDEmpuje()

    init(parte: RetoEnSala, reta: Bool) {
        self.parte = parte
        self.reta = reta
    }

    func empezar(tema: String) {
        guard reta else { return }
        Task { @MainActor [weak parte] in
            guard let parte else { return }
            parte.escribir("reto", ["inicio": ["de": .texto(parte.yo), "tema": .texto(tema), "t": .numero(Date().timeIntervalSince1970 * 1000)]])
        }
    }

    func dejarDeBuscar() {}
    func parar() {}
    func invitar(_ nombre: String, tema: String) {}

    func responder(_ si: Bool) {
        Task { @MainActor [weak parte] in
            guard let parte else { return }
            parte.escribir("reto/respuesta", ["si": .bool(si), "de": .texto(parte.yo)])
        }
    }

    func mandar(_ datos: Data) {
        let id = empuje.nuevo()
        let texto = datos.base64EncodedString()
        Task { @MainActor [weak parte] in
            guard let parte else { return }
            parte.escribir("reto/m/\(id)", ["de": .texto(parte.yo), "d": .texto(texto)])
        }
    }

    func aceptado(rival nombre: String) {
        guard rival.isEmpty else { return }
        rival = nombre
        alConectar?(nombre)
    }

    func rechazado() {
        alDesconectar?()
    }
}
