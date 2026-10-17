import SwiftUI
import Observation

enum Pestana: Hashable {
    case hoy, pruebas, tareas, mochila, estudio

    case calendario

    case avisos, notas
}

struct EstadoGuardado: Codable, Equatable {
    var version = 1
    var configurado = false
    var perfil = Perfil()
    var ajustes = Ajustes()
    var datos = DatosEscolares()
    var hijos: [Hijo] = []
    var hijoActivoID: UUID?
    var vinculos: [Vinculo] = []
    var codigoVinculo = Almacen.nuevoCodigo()
    var teams = EstadoTeams()
    var estudios: [EstudioGuardado] = []
    var cuenta = Cuenta()
}

@Observable
final class Almacen {

    var configurado = false
    var perfil = Perfil()
    var ajustes = Ajustes() {
        didSet {
            if ajustes.idioma != idiomaActual || ajustes.region != regionActual {
                idiomaActual = ajustes.idioma
                regionActual = ajustes.region
                versionIdioma += 1
            }
        }
    }
    var datos = DatosEscolares()
    var hijos: [Hijo] = []
    var hijoActivoID: UUID?
    var vinculos: [Vinculo] = []
    var codigoVinculo = Almacen.nuevoCodigo()
    var teams = EstadoTeams()
    var estudios: [EstudioGuardado] = []
    var cuenta = Cuenta()

    var pestana: Pestana = .hoy
    var mostrandoCuenta = false

    var mostrandoCalendario = false
    var bloqueado = false

    var avisoPrueba: String?

    var versionIdioma = 0
    var fotoAvatar: UIImage?

    var tareaAbierta: UUID?

    var ayudaPendiente: (tipo: TipoAyuda, asignaturaID: UUID?)?

    var seccionTareasPedida: SeccionTareas?

    @ObservationIgnored private var tareaGuardado: Task<Void, Never>?
    @ObservationIgnored private var tareaAvisos: Task<Void, Never>?
    @ObservationIgnored private var cargando = false

    @ObservationIgnored private(set) var lecturaPendiente = false
    @ObservationIgnored private var observadorDesbloqueo: NSObjectProtocol?

    init() {
        cargar()
        vigilar()
        if ajustes.bloqueoFaceID && configurado { bloqueado = true }
    }

    var esFamilia: Bool { perfil.rol == .familia }

    var hijoActivo: Hijo? {
        guard esFamilia else { return nil }
        return hijos.first { $0.id == hijoActivoID } ?? hijos.first
    }

    var datosActivos: DatosEscolares {
        if esFamilia { return hijoActivo?.datos ?? DatosEscolares() }
        return datos
    }

    var datosConCalendario: DatosEscolares {
        var d = datos
        d.delCalendario = Calendarios.compartido.actividades
        return d
    }

    func modificarDatos(_ cambio: (inout DatosEscolares) -> Void) {
        if esFamilia {
            guard let id = hijoActivo?.id, let i = hijos.firstIndex(where: { $0.id == id }) else { return }
            cambio(&hijos[i].datos)
        } else {
            cambio(&datos)
        }
    }

    func alternarHecha(_ tareaID: UUID) {
        guard let i = datos.tareas.firstIndex(where: { $0.id == tareaID }) else { return }
        datos.tareas[i].hecha.toggle()
        datos.tareas[i].hechaEl = datos.tareas[i].hecha ? Reloj.ahora : nil
    }

    func alternarRato(_ tareaID: UUID, dia: Date = Reloj.ahora) {
        guard let i = datos.tareas.firstIndex(where: { $0.id == tareaID }) else { return }
        if datos.tareas[i].tipo == .deberes {
            alternarHecha(tareaID)
            return
        }
        let cal = calendarioActual
        if let j = datos.tareas[i].ratosHechos.firstIndex(where: { cal.isDate($0, inSameDayAs: dia) }) {
            datos.tareas[i].ratosHechos.remove(at: j)
        } else {
            datos.tareas[i].ratosHechos.append(dia)
        }
    }

    func alternarRecordatorio(_ id: UUID) {
        modificarDatos { d in
            guard let i = d.recordatorios.firstIndex(where: { $0.id == id }) else { return }
            d.recordatorios[i].hecho.toggle()
        }
    }

    func alternarMochila(_ clave: String, dia: Date) {
        let k = DatosEscolares.clave(dia)
        var marcadas = datos.mochilaMarcada[k] ?? []
        if marcadas.contains(clave) { marcadas.remove(clave) } else { marcadas.insert(clave) }
        datos.mochilaMarcada[k] = marcadas
    }

    static func nuevoCodigo() -> String {
        let letras = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        func bloque() -> String { String((0..<4).map { _ in letras.randomElement()! }) }
        return "HOOT-\(bloque())-\(bloque())"
    }

    var contenidoQR: String {
        var c = URLComponents()
        c.scheme = "hoot"
        c.host = "vincular"
        c.queryItems = [
            URLQueryItem(name: "codigo", value: codigoVinculo),
            URLQueryItem(name: "nombre", value: perfil.nombre),
        ]
        return c.string ?? codigoVinculo
    }

    private var estado: EstadoGuardado {
        EstadoGuardado(
            configurado: configurado, perfil: perfil, ajustes: ajustes, datos: datos, hijos: hijos,
            hijoActivoID: hijoActivoID, vinculos: vinculos, codigoVinculo: codigoVinculo, teams: teams,
            estudios: estudios, cuenta: cuenta
        )
    }

    private func aplicar(_ e: EstadoGuardado) {
        configurado = e.configurado
        perfil = e.perfil
        ajustes = e.ajustes
        datos = e.datos
        hijos = e.hijos
        hijoActivoID = e.hijoActivoID
        vinculos = e.vinculos
        codigoVinculo = e.codigoVinculo
        teams = e.teams
        estudios = e.estudios
        cuenta = e.cuenta
        idiomaActual = e.ajustes.idioma
        regionActual = e.ajustes.region

        datos.pasarExamenesAPruebas()
        for i in hijos.indices { hijos[i].datos.pasarExamenesAPruebas() }
    }

    static var carpeta: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Hoot", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var archivo: URL { carpeta.appendingPathComponent("estado.json") }
    static var archivoAvatar: URL { carpeta.appendingPathComponent("avatar.jpg") }

    private func cargar() {
        cargando = true
        defer { cargando = false }
        let existe = FileManager.default.fileExists(atPath: Self.archivo.path)
        guard existe else {
            idiomaActual = ajustes.idioma
            regionActual = ajustes.region
            lecturaPendiente = false
            return
        }
        guard let data = try? Data(contentsOf: Self.archivo) else {

            idiomaActual = ajustes.idioma
            regionActual = ajustes.region
            lecturaPendiente = true
            esperarDesbloqueo()
            return
        }
        lecturaPendiente = false
        if let e = try? CompatibilidadDatos.decodificar(data) {
            aplicar(e)

            if datos.examenesEnPruebas != e.datos.examenesEnPruebas { escribir(estado) }
        } else {

            let copia = Self.carpeta.appendingPathComponent("estado-\(Int(Reloj.ahora.timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: Self.archivo, to: copia)
            idiomaActual = ajustes.idioma
            regionActual = ajustes.region
        }
        if let data = try? Data(contentsOf: Self.archivoAvatar) {
            fotoAvatar = UIImage(data: data)
        }
    }

    func reintentarCarga() {
        guard lecturaPendiente else { return }
        cargar()
        if !lecturaPendiente && ajustes.bloqueoFaceID && configurado { bloqueado = true }
    }

    private func esperarDesbloqueo() {
        guard observadorDesbloqueo == nil else { return }
        observadorDesbloqueo = NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.reintentarCarga()
                if !self.lecturaPendiente, let o = self.observadorDesbloqueo {
                    NotificationCenter.default.removeObserver(o)
                    self.observadorDesbloqueo = nil
                }
            }
        }
    }

    func guardarYa() {
        tareaGuardado?.cancel()
        escribir(estado)
    }

    private func escribir(_ e: EstadoGuardado) {
        guard !lecturaPendiente else { return }
        do {
            let data = try JSONEncoder().encode(e)
            try data.write(to: Self.archivo, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])

            Sincronizacion.compartida.cambioLocal()
        } catch {
            print("Hoot: no se pudo guardar: \(error)")
        }
    }

    func datosParaNube() -> Data {
        var e = estado
        e.estudios = e.estudios.map { var x = $0; x.miniaturas = []; return x }
        e.datos = e.datos.sinMiniaturas
        e.hijos = e.hijos.map { var h = $0; h.datos = h.datos.sinMiniaturas; return h }
        return (try? JSONEncoder().encode(e)) ?? Data()
    }

    func ponerDeLaNube(_ nuevo: EstadoGuardado, foto: UIImage?) {
        var e = nuevo
        for i in e.estudios.indices where e.estudios[i].miniaturas.isEmpty {
            if let local = estudios.first(where: { $0.id == e.estudios[i].id }) { e.estudios[i].miniaturas = local.miniaturas }
        }
        e.datos.recuperarMiniaturas(de: datos)
        for i in e.hijos.indices {
            if let local = hijos.first(where: { $0.id == e.hijos[i].id }) { e.hijos[i].datos.recuperarMiniaturas(de: local.datos) }
        }
        cargando = true
        aplicar(e)
        if let foto { ponerFoto(foto) } else if e.perfil.avatar == .foto, fotoAvatar == nil { perfil.avatar = .lobo }
        cargando = false
        escribir(estado)
        tareaAvisos?.cancel()
        tareaAvisos = Task { [weak self] in
            guard let self else { return }
            await Avisos.reprogramar(self)
        }
    }

    private func vigilar() {
        withObservationTracking {
            _ = self.estado
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.vigilar()
                self?.programarGuardado()
            }
        }
    }

    private func programarGuardado() {
        guard !cargando else { return }
        tareaGuardado?.cancel()
        tareaGuardado = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            self.escribir(self.estado)
        }
        tareaAvisos?.cancel()
        tareaAvisos = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, let self else { return }
            await Avisos.reprogramar(self)
        }
    }

    func ponerFoto(_ imagen: UIImage?) {
        if let imagen, let data = imagen.reducida(a: 600).jpegData(compressionQuality: 0.85) {
            try? data.write(to: Self.archivoAvatar, options: .atomic)
            fotoAvatar = UIImage(data: data)
            perfil.avatar = .foto
        } else {
            try? FileManager.default.removeItem(at: Self.archivoAvatar)
            fotoAvatar = nil
            if perfil.avatar == .foto { perfil.avatar = .lobo }
        }
    }

    func cerrarSesion() {
        guardarYa()
        if !cuenta.correo.isEmpty {
            Cuentas.guardarCopia(estado, foto: fotoAvatar, correo: cuenta.correo)
        }
        borrarTodo()
    }

    func restaurar(_ e: EstadoGuardado, foto: UIImage?) {
        aplicar(e)
        configurado = true
        ponerFoto(foto)
        if foto == nil, e.perfil.avatar == .foto { perfil.avatar = .lobo }
        guardarYa()
    }

    var copiaDeTodo: EstadoGuardado { estado }

    func aplicarPrueba(_ e: EstadoGuardado, foto: UIImage?) {
        aplicar(e)
        ponerFoto(foto)
        if foto == nil, e.perfil.avatar == .foto { perfil.avatar = .lobo }
        guardarYa()
    }

    func borrarTodo() {
        FlujoConfig.olvidar()
        let idioma = ajustes.idioma
        let region = ajustes.region
        aplicar(EstadoGuardado())
        ajustes.idioma = idioma
        ajustes.region = region
        ajustes.escala = .para(region: region)
        ponerFoto(nil)
        pestana = .hoy
        mostrandoCuenta = false
        guardarYa()
        Task { await Avisos.reprogramar(self) }
    }
}

extension UIImage {

    func reducida(a lado: CGFloat) -> UIImage {
        let mayor = max(size.width, size.height)
        guard mayor > lado else { return self }
        let escala = lado / mayor
        let nuevo = CGSize(width: size.width * escala, height: size.height * escala)
        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = 1
        return UIGraphicsImageRenderer(size: nuevo, format: formato).image { _ in
            draw(in: CGRect(origin: .zero, size: nuevo))
        }
    }
}
