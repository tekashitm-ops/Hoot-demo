import Foundation
import SwiftUI

nonisolated struct MiembroSala: Equatable, Hashable, Sendable, Codable {
    var uid: String
    var nombre: String
}

nonisolated struct Companero: Codable, Equatable, Hashable, Sendable, Identifiable {
    var uid: String
    var nombre: String
    var ultimaVez: Date
    var id: String { uid }
}

nonisolated struct SalaReciente: Codable, Equatable, Hashable, Sendable, Identifiable {
    var id: String
    var codigo: String
    var soyAnfitrion: Bool
    var amigo: String
    var ultimaVez: Date
}

nonisolated enum SalasGuardadas {
    private static let claveCompaneros = "hoot.salas.companeros"
    private static let claveRecientes = "hoot.salas.recientes"
    private static let claveInvitados = "hoot.salas.invitados"

    static var companeros: [Companero] {
        get { leer(claveCompaneros) ?? [] }
        set { guardar(newValue.sorted { $0.ultimaVez > $1.ultimaVez }.prefix(30).map { $0 }, claveCompaneros) }
    }

    static var recientes: [SalaReciente] {
        get { leer(claveRecientes) ?? [] }
        set { guardar(newValue.sorted { $0.ultimaVez > $1.ultimaVez }.prefix(20).map { $0 }, claveRecientes) }
    }

    static var invitados: [String: [String]] {
        get { leer(claveInvitados) ?? [:] }
        set { guardar(newValue, claveInvitados) }
    }

    static func recordar(_ m: MiembroSala) {
        var c = companeros.filter { $0.uid != m.uid }
        c.append(Companero(uid: m.uid, nombre: m.nombre, ultimaVez: Date()))
        companeros = c
    }

    static func recordar(_ s: SalaReciente) {
        var r = recientes.filter { $0.id != s.id }
        r.append(s)
        recientes = r
    }

    static func olvidar(sala id: String) {
        recientes = recientes.filter { $0.id != id }
        invitados[id] = nil
    }

    private static func leer<T: Decodable>(_ clave: String) -> T? {
        UserDefaults.standard.data(forKey: clave).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    private static func guardar<T: Encodable>(_ v: T, _ clave: String) {
        if let d = try? JSONEncoder().encode(v) { UserDefaults.standard.set(d, forKey: clave) }
    }
}

nonisolated struct AvisoSala: Equatable, Hashable, Sendable, Identifiable {
    var id: String
    var tipo: String
    var sala: String
    var codigo: String
    var de: String
    var nombre: String
    var fecha: Date

    var datos: String
}

@Observable
final class Salas {
    static let compartidas = Salas()

    private(set) var avisos: [AvisoSala] = []

    var abierta: SalaEnVivo?

    var entrando = false
    var codigoPendiente = ""

    var retoPendiente: (temas: [Tema], tema: String)?
    var resultados: [AvisoSala] { avisos.filter { $0.tipo == "resultadoReto" } }
    @ObservationIgnored private var mirando: Task<Void, Never>?

    var invitaciones: [AvisoSala] { avisos.filter { $0.tipo == "sala" } }
    var retosPendientes: [AvisoSala] { avisos.filter { $0.tipo == "reto" } }

    static func faltaPermiso(_ almacen: Almacen) -> Bool {
        EdadIA.hacePermiso(perfil: almacen.perfil, region: almacen.ajustes.region) && !almacen.ajustes.permisoSalas
    }

    static func conCuenta() async -> Bool {
        guard ConfigBaseEnVivo.lista, let s = await Nube.compartida.sesionActual else { return false }
        return s.verificada
    }

    static func yo(_ almacen: Almacen) async -> MiembroSala? {
        guard let s = await Nube.compartida.sesionActual else { return nil }
        let nombre = almacen.perfil.nombre.trimmingCharacters(in: .whitespaces)
        return MiembroSala(uid: s.uid, nombre: nombre.isEmpty ? L("Tu amigo", "Your friend", "Il tuo amico") : nombre)
    }

    func empezarAMirar() {
        guard mirando == nil, !ModoCapturas.activo else { return }
        mirando = Task { [weak self] in
            while !Task.isCancelled {
                await self?.mirarBuzon()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    func dejarDeMirar() {
        mirando?.cancel()
        mirando = nil
    }

    func mirarBuzon() async {
        guard await Salas.conCuenta(), let uid = await Nube.compartida.sesionActual?.uid else { return }
        guard let arbol = try? await BaseEnVivo.compartido.leer("buzon/\(uid)") else { return }
        var nuevos: [AvisoSala] = []
        for (id, a) in arbol.objeto {
            let fecha = Date(timeIntervalSince1970: (a["t"].numero ?? 0) / 1000)

            let vida: TimeInterval = a["tipo"].texto == "reto" ? 7 * 86400 : 86400
            if Date().timeIntervalSince(fecha) > vida {
                try? await BaseEnVivo.compartido.borrar("buzon/\(uid)/\(id)")
                continue
            }
            nuevos.append(AvisoSala(id: id, tipo: a["tipo"].texto ?? "", sala: a["sala"].texto ?? "", codigo: a["codigo"].texto ?? "",
                                    de: a["de"].texto ?? "", nombre: a["nombre"].texto ?? "", fecha: fecha, datos: a["datos"].texto ?? ""))
        }
        nuevos.sort { $0.fecha > $1.fecha }
        if nuevos != avisos { conMuelle { avisos = nuevos } }
    }

    func quitar(_ aviso: AvisoSala) {
        conMuelle { avisos.removeAll { $0.id == aviso.id } }
        Task {
            guard let uid = await Nube.compartida.sesionActual?.uid else { return }
            try? await BaseEnVivo.compartido.borrar("buzon/\(uid)/\(aviso.id)")
        }
    }

    func ponerEjemplo() {
        avisos = [AvisoSala(id: "ejemplo", tipo: "sala", sala: "ejemplo", codigo: "K7Q4ZP", de: "ana", nombre: "Ana",
                            fecha: Reloj.ahora.addingTimeInterval(-120), datos: "")]
    }

    nonisolated enum FalloSala: Error, Equatable {
        case sinCuenta, noExiste, caducado, llena, sinRed, otro
    }

    static func crear(almacen: Almacen) async throws -> SalaEnVivo {
        guard await conCuenta(), let yo = await yo(almacen) else { throw FalloSala.sinCuenta }
        var empuje = IDEmpuje()
        let id = empuje.nuevo()
        do {
            try await BaseEnVivo.compartido.poner("salas/\(id)/miembros/anfitrion", ["uid": .texto(yo.uid), "nombre": .texto(yo.nombre)])
            try await BaseEnVivo.compartido.poner("salas/\(id)/info", ["creada": JSONVivo.horaServidor])
            let codigo = try await nuevoCodigo(sala: id, anfitrion: yo.uid, nombre: yo.nombre)
            SalasGuardadas.recordar(SalaReciente(id: id, codigo: codigo, soyAnfitrion: true, amigo: "", ultimaVez: Date()))
            let sala = SalaEnVivo(id: id, codigo: codigo, yo: yo, soyAnfitrion: true)
            sala.entrar()
            return sala
        } catch let f as FalloVivo {
            throw f == .sinRed ? FalloSala.sinRed : FalloSala.otro
        }
    }

    static func nuevoCodigo(sala: String, anfitrion: String, nombre: String) async throws -> String {
        let caduca = (Date().timeIntervalSince1970 + 23 * 3600) * 1000
        for _ in 0..<6 {
            let codigo = CodigoSala.nuevo()
            do {
                try await BaseEnVivo.compartido.poner("codigos/\(codigo)", ["sala": .texto(sala), "anfitrion": .texto(anfitrion), "nombre": .texto(nombre),
                                                                             "caduca": .numero(caduca)])
                return codigo
            } catch FalloVivo.sinPermiso {
                continue
            }
        }
        throw FalloSala.otro
    }

    static func pedirEntrar(codigo: String, almacen: Almacen) async throws -> SalaEnVivo {
        guard await conCuenta(), let yo = await yo(almacen) else { throw FalloSala.sinCuenta }
        let c = CodigoSala.limpio(codigo)
        let info: JSONVivo
        do { info = try await BaseEnVivo.compartido.leer("codigos/\(c)") } catch FalloVivo.sinRed { throw FalloSala.sinRed }
        guard let id = info["sala"].texto else { throw FalloSala.noExiste }
        if let caduca = info["caduca"].numero, caduca / 1000 < Date().timeIntervalSince1970 { throw FalloSala.caducado }
        if info["anfitrion"].texto == yo.uid {

            let sala = SalaEnVivo(id: id, codigo: c, yo: yo, soyAnfitrion: true)
            sala.entrar()
            return sala
        }
        do {
            try await BaseEnVivo.compartido.poner("salas/\(id)/solicitudes/\(yo.uid)", ["nombre": .texto(yo.nombre), "t": JSONVivo.horaServidor])
        } catch FalloVivo.sinRed { throw FalloSala.sinRed }
        let sala = SalaEnVivo(id: id, codigo: c, yo: yo, soyAnfitrion: false)
        sala.nombreQuienCrea = info["nombre"].texto ?? ""
        sala.esperarPermiso()
        return sala
    }

    static func volver(a r: SalaReciente, almacen: Almacen) async throws -> SalaEnVivo {
        guard await conCuenta(), let yo = await yo(almacen) else { throw FalloSala.sinCuenta }
        var codigo = r.codigo
        if r.soyAnfitrion {

            let info = try? await BaseEnVivo.compartido.leer("codigos/\(codigo)")
            if info?["sala"].texto != r.id || (info?["caduca"].numero ?? 0) / 1000 < Date().timeIntervalSince1970 + 600 {
                codigo = (try? await nuevoCodigo(sala: r.id, anfitrion: yo.uid, nombre: yo.nombre)) ?? codigo
            }
        }
        var nueva = r
        nueva.codigo = codigo
        nueva.ultimaVez = Date()
        SalasGuardadas.recordar(nueva)
        let sala = SalaEnVivo(id: r.id, codigo: codigo, yo: yo, soyAnfitrion: r.soyAnfitrion)
        sala.entrar()
        return sala
    }

    static func invitar(_ c: Companero, a sala: SalaEnVivo) async -> Bool {
        var empuje = IDEmpuje()
        let id = empuje.nuevo()
        var inv = SalasGuardadas.invitados
        inv[sala.id, default: []].append(c.uid)
        SalasGuardadas.invitados = inv
        do {
            try await BaseEnVivo.compartido.poner("buzon/\(c.uid)/\(id)", [
                "tipo": "sala", "sala": .texto(sala.id), "codigo": .texto(sala.codigo), "de": .texto(sala.yo.uid),
                "nombre": .texto(sala.yo.nombre), "t": JSONVivo.horaServidor,
            ])
            return true
        } catch {
            return false
        }
    }

    static func limpiarViejas() async {
        let viejas = SalasGuardadas.recientes.filter { $0.soyAnfitrion && Date().timeIntervalSince($0.ultimaVez) > 14 * 86400 }
        for r in viejas {
            try? await BaseEnVivo.compartido.borrar("archivos/\(r.id)")
            try? await BaseEnVivo.compartido.borrar("codigos/\(r.codigo)")
            try? await BaseEnVivo.compartido.borrar("salas/\(r.id)")
            SalasGuardadas.olvidar(sala: r.id)
        }

        SalasGuardadas.recientes = SalasGuardadas.recientes.filter { $0.soyAnfitrion || Date().timeIntervalSince($0.ultimaVez) < 28 * 86400 }
    }
}

nonisolated enum EspacioSala: String, CaseIterable, Sendable { case pizarra, apuntes, chat }

@Observable
final class SalaEnVivo: Identifiable {
    nonisolated enum Estado: Equatable {
        case conectando

        case esperandoPermiso

        case rechazado
        case dentro

        case cerrada
    }

    let id: String
    private(set) var codigo: String
    let yo: MiembroSala

    private(set) var esLocal = false
    let soyAnfitrion: Bool
    private(set) var estado: Estado = .conectando
    private(set) var anfitrion: MiembroSala?
    private(set) var invitado: MiembroSala?

    private(set) var solicitudes: [MiembroSala] = []
    private(set) var amigoConectado = false
    private(set) var amigoEspacio: EspacioSala?
    var espacio: EspacioSala = .pizarra { didSet { if espacio != oldValue { latirAhora() } } }

    var nombreQuienCrea = ""

    let pizarra: PizarraCompartida
    let apuntes: ApuntesCompartidos
    let chat: ChatSala
    let llamada: LlamadaSala
    let reto: RetoEnSala

    private(set) var arbol: JSONVivo = .nulo
    private var escucha: EscuchaVivo?
    private var consumidor: Task<Void, Never>?
    private var latido: Task<Void, Never>?
    private var ultimaSenalAmigo: Date?
    private var visto: Set<String> = []

    var amigo: MiembroSala? { soyAnfitrion ? invitado : anfitrion }
    var codigoBonito: String { CodigoSala.bonito(codigo) }

    init(id: String, codigo: String, yo: MiembroSala, soyAnfitrion: Bool) {
        self.id = id
        self.codigo = codigo
        self.yo = yo
        self.soyAnfitrion = soyAnfitrion
        pizarra = PizarraCompartida(yo: yo.uid)
        apuntes = ApuntesCompartidos(yo: yo.uid)
        chat = ChatSala(yo: yo.uid)
        llamada = LlamadaSala(yo: yo.uid)
        reto = RetoEnSala(yo: yo.uid)
        for parte in partes { parte.sala = self }
    }

    private var partes: [ParteDeSala] { [pizarra, apuntes, chat, llamada, reto] }

    func entrar() {
        escuchar(ruta: "salas/\(id)") { [weak self] c in self?.recibir(c) }
        empezarLatido()
    }

    func esperarPermiso() {
        estado = .esperandoPermiso
        var vista = false
        var nodo = JSONVivo.nulo
        escuchar(ruta: "salas/\(id)/solicitudes/\(yo.uid)") { [weak self] c in
            guard let self, self.estado == .esperandoPermiso else { return }
            switch c {
            case .poner(let ruta, let valor): nodo.poner(valor, en: ruta)
            case .parchear(let ruta, let hijos): nodo.parchear(hijos, en: ruta)
            case .sinPermiso:
                self.estado = .rechazado
                self.parar()
                return
            case .paseCaducado: return
            }
            if nodo["admitido"].bool == true {
                self.estado = .conectando
                self.entrar()
            } else if nodo.existe {
                vista = true
            } else if vista {

                self.estado = .rechazado
                self.parar()
            }
        }
    }

    private func escuchar(ruta: String, _ manejar: @escaping (CambioVivo) -> Void) {
        consumidor?.cancel()
        escucha?.cancelar()
        let (flujo, continuacion) = AsyncStream<CambioVivo>.makeStream()
        escucha = BaseEnVivo.compartido.escuchar(ruta) { continuacion.yield($0) }

        consumidor = Task { for await c in flujo { manejar(c) } }
    }

    private func recibir(_ c: CambioVivo) {
        switch c {
        case .poner(let ruta, let valor):
            arbol.poner(valor, en: ruta)
            repartir(ruta)
        case .parchear(let ruta, let hijos):
            arbol.parchear(hijos, en: ruta)
            if hijos.count == 1, let k = hijos.keys.first { repartir(ruta + JSONVivo.trozos(k)) } else { repartir(ruta) }
        case .sinPermiso:
            estado = .cerrada
            parar()
        case .paseCaducado:
            break
        }
    }

    private func repartir(_ ruta: [String]) {
        let raiz = ruta.first
        if raiz == nil || raiz == "miembros" || raiz == "solicitudes" || raiz == "cerrada" { leerMiembros() }
        if raiz == nil || raiz == "presencia" { leerPresencia(cambiado: ruta.count > 1 ? ruta[1] : nil) }
        let resto = Array(ruta.dropFirst())
        for parte in partes where raiz == nil || raiz == parte.nombre {
            parte.actualizar(arbol[parte.nombre], cambio: raiz == nil ? [] : resto)
        }
    }

    private func leerMiembros() {
        func miembro(_ j: JSONVivo) -> MiembroSala? {
            j["uid"].texto.map { MiembroSala(uid: $0, nombre: j["nombre"].texto ?? "") }
        }
        let m = arbol["miembros"]
        anfitrion = miembro(m["anfitrion"])
        invitado = miembro(m["invitado"])
        if arbol["cerrada"].bool == true || (estado == .dentro && anfitrion == nil) {
            estado = .cerrada
            parar()
            return
        }
        if estado != .dentro && (anfitrion?.uid == yo.uid || invitado?.uid == yo.uid) {
            estado = .dentro
        }
        if let a = amigo {
            SalasGuardadas.recordar(a)
            SalasGuardadas.recordar(SalaReciente(id: id, codigo: codigo, soyAnfitrion: soyAnfitrion, amigo: a.nombre, ultimaVez: Date()))
        }
        guard soyAnfitrion else { return }
        var pendientes: [MiembroSala] = []
        let invitados = Set(SalasGuardadas.invitados[id] ?? [])
        for (uid, s) in arbol["solicitudes"].objeto where s["admitido"].bool != true {
            let quien = MiembroSala(uid: uid, nombre: s["nombre"].texto ?? "")
            if invitado != nil && invitado?.uid != uid { continue }
            if invitados.contains(uid) || invitado?.uid == uid { dejarPasar(quien) } else { pendientes.append(quien) }
        }
        if pendientes != solicitudes { conMuelle { solicitudes = pendientes } }
    }

    private func leerPresencia(cambiado: String?) {
        guard let a = amigo else { return }
        let p = arbol["presencia"][a.uid]
        if cambiado == nil || cambiado == a.uid {
            if p["fuera"].bool == true { ultimaSenalAmigo = nil } else if p.existe { ultimaSenalAmigo = Date() }
        }
        amigoEspacio = p["espacio"].texto.flatMap(EspacioSala.init(rawValue:))
        let conectado = ultimaSenalAmigo.map { Date().timeIntervalSince($0) < 45 } ?? false
        if conectado != amigoConectado { conMuelle { amigoConectado = conectado } }
    }

    func dejarPasar(_ m: MiembroSala) {
        solicitudes.removeAll { $0.uid == m.uid }
        Task {
            try? await BaseEnVivo.compartido.parchear("salas/\(id)", [
                "miembros/invitado": ["uid": .texto(m.uid), "nombre": .texto(m.nombre)],
                "solicitudes/\(m.uid)/admitido": true,
            ])
        }
    }

    func noDejarPasar(_ m: MiembroSala) {
        solicitudes.removeAll { $0.uid == m.uid }
        Task { try? await BaseEnVivo.compartido.borrar("salas/\(id)/solicitudes/\(m.uid)") }
    }

    func cerrarSala() async {
        parar()
        try? await BaseEnVivo.compartido.borrar("archivos/\(id)")
        try? await BaseEnVivo.compartido.borrar("codigos/\(codigo)")
        try? await BaseEnVivo.compartido.borrar("salas/\(id)")
        SalasGuardadas.olvidar(sala: id)
        estado = .cerrada
    }

    func salirDeLaSala() async {
        parar()
        try? await BaseEnVivo.compartido.borrar("salas/\(id)/miembros/invitado")
        try? await BaseEnVivo.compartido.borrar("salas/\(id)/solicitudes/\(yo.uid)")
        SalasGuardadas.olvidar(sala: id)
        estado = .cerrada
    }

    private func empezarLatido() {
        latido?.cancel()
        latido = Task { [weak self] in
            var n = 0
            while !Task.isCancelled {
                guard let self else { return }
                if n % 3 == 0 { await self.latir() }
                self.leerPresencia(cambiado: "")
                n += 1
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    private func latir() async {
        try? await BaseEnVivo.compartido.poner("salas/\(id)/presencia/\(yo.uid)", [
            "t": JSONVivo.horaServidor, "espacio": .texto(espacio.rawValue), "nombre": .texto(yo.nombre),
        ])
    }

    private func latirAhora() {
        guard estado == .dentro, !sinRed else { return }
        Task { await latir() }
    }

    func parar() {
        let estaba = escucha != nil
        escucha?.cancelar(); escucha = nil
        consumidor?.cancel(); consumidor = nil
        latido?.cancel(); latido = nil
        llamada.colgar()
        for parte in partes { parte.parar() }
        if estaba && estado == .dentro && !sinRed {
            let ruta = "salas/\(id)/presencia/\(yo.uid)"
            Task.detached { try? await BaseEnVivo.compartido.poner(ruta, ["t": JSONVivo.horaServidor, "fuera": true]) }
        }
    }

    func escribir(_ ruta: String, _ valor: JSONVivo) {
        guard !sinRed else { return }
        let r = "salas/\(id)/\(ruta)"
        Task { try? await BaseEnVivo.compartido.poner(r, valor) }
    }

    func escribirYEsperar(_ ruta: String, _ valor: JSONVivo) async throws {
        guard !sinRed else { return }
        try await BaseEnVivo.compartido.poner("salas/\(id)/\(ruta)", valor)
    }

    func parchear(_ ruta: String, _ hijos: [String: JSONVivo]) {
        guard !sinRed else { return }
        let r = "salas/\(id)/\(ruta)"
        Task { try? await BaseEnVivo.compartido.parchear(r, hijos) }
    }

    func borrar(_ ruta: String) {
        guard !sinRed else { return }
        let r = "salas/\(id)/\(ruta)"
        Task { try? await BaseEnVivo.compartido.borrar(r) }
    }

    func subirArchivo(_ datos: Data) async -> String? {
        guard !sinRed else { return nil }
        var empuje = IDEmpuje()
        let nombre = empuje.nuevo()
        do {
            try await BaseEnVivo.compartido.poner("archivos/\(id)/\(nombre)", .texto(datos.base64EncodedString()))
            ArchivosSala.guardar(datos, nombre)
            return nombre
        } catch {
            return nil
        }
    }

    func bajarArchivo(_ nombre: String) async -> Data? {
        if let d = ArchivosSala.leer(nombre) { return d }
        guard !sinRed, let j = try? await BaseEnVivo.compartido.leer("archivos/\(id)/\(nombre)"), let s = j.texto,
              let d = Data(base64Encoded: s) else { return nil }
        ArchivosSala.guardar(d, nombre)
        return d
    }

    static func ejemplo(espacio: EspacioSala = .pizarra, conLlamada: Bool = true, soyAnfitrion: Bool = true) -> SalaEnVivo {
        let yo = MiembroSala(uid: "lucia", nombre: L("Lucía", "Lucy", "Lucia"))
        let ana = MiembroSala(uid: "ana", nombre: "Ana")
        let s = SalaEnVivo(id: "ejemplo", codigo: "K7Q4ZP", yo: yo, soyAnfitrion: soyAnfitrion)
        s.anfitrion = soyAnfitrion ? yo : ana
        s.invitado = soyAnfitrion ? ana : yo
        s.estado = .dentro
        s.amigoConectado = true
        s.amigoEspacio = espacio
        s.espacio = espacio
        s.pizarra.ponerEjemplo()
        s.apuntes.ponerEjemplo()
        s.chat.ponerEjemplo(amigo: ana.uid)
        if conLlamada { s.llamada.ponerEjemplo() }
        return s
    }

    func local() -> SalaEnVivo {
        esLocal = true
        return self
    }

    private var sinRed: Bool { esLocal || ModoCapturas.activo }

    func ponerSolicitudEjemplo() {
        solicitudes = [MiembroSala(uid: "ana", nombre: "Ana")]
        invitado = nil
    }

    static func ejemploPara(_ pantalla: String) -> SalaEnVivo {
        switch pantalla {
        case "sala-apuntes": return ejemplo(espacio: .apuntes)
        case "sala-chat": return ejemplo(espacio: .chat)
        case "sala-esperando":
            let s = ejemplo(conLlamada: false)
            s.invitado = nil
            return s
        case "sala-dejar-pasar":
            let s = ejemplo(conLlamada: false)
            s.ponerSolicitudEjemplo()
            return s
        case "sala-entrante":
            let s = ejemplo(conLlamada: false)
            s.llamada.ponerEntranteEjemplo()
            return s
        case "sala-reto":
            let s = ejemplo(conLlamada: true)
            s.reto.ponerInvitacionEjemplo()
            return s
        case "sala-esperando-permiso":
            let s = ejemplo(conLlamada: false, soyAnfitrion: false)
            s.estado = .esperandoPermiso
            s.nombreQuienCrea = "Ana"
            return s
        default: return ejemplo(espacio: .pizarra)
        }
    }
}

protocol ParteDeSala: AnyObject {
    var nombre: String { get }
    var sala: SalaEnVivo? { get set }

    func actualizar(_ valor: JSONVivo, cambio: [String])
    func parar()
}

nonisolated enum ArchivosSala {
    private static var carpeta: URL {
        let c = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("salas", isDirectory: true)
        try? FileManager.default.createDirectory(at: c, withIntermediateDirectories: true)
        return c
    }

    static func guardar(_ d: Data, _ nombre: String) {
        try? d.write(to: carpeta.appendingPathComponent(nombre))
    }

    static func leer(_ nombre: String) -> Data? {
        try? Data(contentsOf: carpeta.appendingPathComponent(nombre))
    }
}
