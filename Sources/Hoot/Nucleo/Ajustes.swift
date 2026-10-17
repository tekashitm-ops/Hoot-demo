import Foundation

struct AjustesAvisos: Codable, Equatable, Sendable {

    var activados = false
    var entregas = true

    var horaEntregas = 18 * 60
    var examenes = true

    var cuandoEmpezar = true
    var mochila = true

    var horaMochila = 20 * 60
    var recordatorios = true
    var actividades = true

    var resumenFamilia = true
    var horaResumenFamilia = 19 * 60
}

struct Ajustes: Codable, Equatable, Sendable {
    var idioma: Idioma = .delSistema
    var region: String = Locale.current.region?.identifier ?? "ES"
    var escala: EscalaNotas = .para(region: Locale.current.region?.identifier ?? "ES")
    var avisos = AjustesAvisos()
    var bloqueoFaceID = false
    var longitudResumen: Longitud = .normal
    var modoRevision: ModoRevision = .comprobar

    var modoPrueba: ModoPrueba = .oral

    var minutosRato = 20
    var inicioCurso: Date = Ajustes.inicioCursoPorDefecto
    var finCurso: Date = Ajustes.finCursoPorDefecto

    var tiempoFondo: String = TiempoFijo.real.rawValue

    static var inicioCursoPorDefecto: Date {
        let cal = Calendar(identifier: .gregorian)
        let hoy = Reloj.ahora
        let ano = cal.component(.year, from: hoy)
        let mes = cal.component(.month, from: hoy)
        let anoInicio = mes >= 8 ? ano : ano - 1
        return cal.date(from: DateComponents(year: anoInicio, month: 9, day: 8)) ?? hoy
    }

    static var finCursoPorDefecto: Date {
        let cal = Calendar(identifier: .gregorian)
        let inicio = inicioCursoPorDefecto
        let ano = cal.component(.year, from: inicio) + 1
        return cal.date(from: DateComponents(year: ano, month: 6, day: 23)) ?? inicio
    }
}

struct EstadoTeams: Codable, Equatable, Sendable {
    enum Estado: String, Codable, Sendable {
        case sinVincular

        case prueba
        case vinculado
    }

    var estado: Estado = .sinVincular
    var idAplicacion = ""
    var idDirectorio = ""
    var cuentaColegio = ""
    var ultimaSincronizacion: Date?

    var activo: Bool { estado != .sinVincular }
}

struct Cuenta: Codable, Equatable, Sendable {
    var correo = ""
    var hash = ""
    var sal = ""
    var verificada = false
    var creada: Date?
}
