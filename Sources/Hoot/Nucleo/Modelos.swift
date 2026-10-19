import Foundation

enum Rol: String, Codable, Sendable {

    case estudiante

    case familia
}

enum EstiloAvatar: String, Codable, Sendable {

    case lobo = "buho", iniciales, foto
}

struct Perfil: Codable, Equatable, Sendable {
    var nombre = ""
    var apellidos = ""
    var nacimiento: Date?
    var correo = ""
    var rol: Rol = .estudiante
    var colegio = ""
    var curso = ""
    var avatar: EstiloAvatar = .lobo
    var colorAvatar: ColorHoot = .indigo

    var nombreCompleto: String {
        [nombre, apellidos].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var iniciales: String {
        let a = nombre.first.map(String.init) ?? ""
        let b = apellidos.first.map(String.init) ?? ""
        let r = (a + b).uppercased()
        return r.isEmpty ? "?" : r
    }

    var edad: Int? {
        guard let nacimiento else { return nil }
        return calendarioActual.dateComponents([.year], from: nacimiento, to: Reloj.ahora).year
    }
}

enum TipoMaterial: String, Codable, CaseIterable, Identifiable, Sendable {
    case libro, cuaderno, utiles, ropa, dispositivo, instrumento, otro

    var id: String { rawValue }

    var simbolo: String {
        switch self {
        case .libro: "book.closed.fill"
        case .cuaderno: "book.pages.fill"
        case .utiles: "pencil.and.ruler.fill"
        case .ropa: "tshirt.fill"
        case .dispositivo: "laptopcomputer"
        case .instrumento: "music.note"
        case .otro: "shippingbox.fill"
        }
    }

    var nombre: String {
        switch self {
        case .libro: L("Libro", "Book", "Libro")
        case .cuaderno: L("Cuaderno", "Notebook", "Quaderno")
        case .utiles: L("Material", "Supplies", "Materiale")
        case .ropa: L("Ropa", "Clothes", "Abbigliamento")
        case .dispositivo: L("Aparato", "Device", "Dispositivo")
        case .instrumento: L("Instrumento", "Instrument", "Strumento")
        case .otro: L("Otra cosa", "Other", "Altro")
        }
    }
}

struct Material: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var nombre: String
    var tipo: TipoMaterial = .libro

    var dias: Set<Int> = []
}

struct Asignatura: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var nombre: String
    var color: ColorHoot
    var simbolo: String
    var profesor = ""
    var aula = ""
    var materiales: [Material] = []
    var deTeams = false
}

struct Franja: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()

    var inicio: Int
    var fin: Int
    var esRecreo = false

    var duracion: Int { fin - inicio }
}

struct Clase: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()

    var dia: Int
    var inicio: Int
    var fin: Int
    var asignaturaID: UUID
    var aula = ""
}

enum Repeticion: Codable, Hashable, Sendable {
    case nunca
    case diaria

    case semanal(Set<Int>)
    case quincenal(Set<Int>)
    case mensual

    var nombre: String {
        switch self {
        case .nunca: L("Nunca", "Never", "Mai")
        case .diaria: L("Cada día", "Every day", "Ogni giorno")
        case .semanal: L("Cada semana", "Every week", "Ogni settimana")
        case .quincenal: L("Cada dos semanas", "Every two weeks", "Ogni due settimane")
        case .mensual: L("Cada mes", "Every month", "Ogni mese")
        }
    }
}

struct Actividad: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var titulo: String
    var simbolo = "star.fill"
    var color: ColorHoot = .naranja

    var fecha: Date

    var inicio: Int?
    var fin: Int?
    var repeticion: Repeticion = .nunca
    var hasta: Date?
    var lugar = ""

    var llevar: [String] = []

    var aviso: Int?
    var notas = ""
}

struct Vacaciones: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var nombre: String
    var desde: Date
    var hasta: Date
}

enum TipoTarea: String, Codable, CaseIterable, Identifiable, Sendable {
    case deberes, examen, trabajo

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .deberes: L("Deberes", "Homework", "Compiti")
        case .examen: L("Examen", "Exam", "Verifica")
        case .trabajo: L("Trabajo", "Project", "Progetto")
        }
    }

    var simbolo: String {
        switch self {
        case .deberes: "pencil.line"
        case .examen: "doc.text.magnifyingglass"
        case .trabajo: "folder.fill"
        }
    }
}

enum Origen: String, Codable, Sendable {
    case manual, teams, familia
}

struct Tarea: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var titulo: String
    var tipo: TipoTarea = .deberes
    var asignaturaID: UUID?

    var entrega: Date
    var notas = ""
    var hecha = false
    var hechaEl: Date?
    var origen: Origen = .manual

    var temas = ""

    var ratosHechos: [Date] = []
}

struct Recordatorio: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var titulo: String
    var fecha: Date
    var conHora = true
    var hecho = false
    var notas = ""
    var origen: Origen = .manual

    var privada = false
}

enum TipoNota: String, Codable, CaseIterable, Identifiable, Sendable {
    case examen, trabajo, deberes, oral, otra

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .examen: L("Examen", "Exam", "Verifica")
        case .trabajo: L("Trabajo", "Project", "Progetto")
        case .deberes: L("Deberes", "Homework", "Compiti")
        case .oral: L("Oral", "Oral", "Interrogazione")
        case .otra: L("Otra", "Other", "Altro")
        }
    }
}

struct Nota: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var asignaturaID: UUID
    var valor: Double
    var peso: Double = 1
    var titulo: String
    var fecha: Date
    var tipo: TipoNota = .examen
    var origen: Origen = .manual
}

struct EscalaNotas: Codable, Hashable, Sendable {
    var minimo: Double
    var maximo: Double
    var aprobado: Double

    var mayorEsMejor = true
    var paso: Double = 0.25

    func proporcion(_ valor: Double) -> Double {
        let p = (valor - minimo) / (maximo - minimo)
        return max(0, min(1, mayorEsMejor ? p : 1 - p))
    }

    func aprueba(_ valor: Double) -> Bool {
        mayorEsMejor ? valor >= aprobado : valor <= aprobado
    }

    static let espana = EscalaNotas(minimo: 0, maximo: 10, aprobado: 5)
    static let italia = EscalaNotas(minimo: 1, maximo: 10, aprobado: 6)
    static let veinte = EscalaNotas(minimo: 0, maximo: 20, aprobado: 10, paso: 0.5)
    static let alemania = EscalaNotas(minimo: 1, maximo: 6, aprobado: 4, mayorEsMejor: false, paso: 0.5)
    static let suiza = EscalaNotas(minimo: 1, maximo: 6, aprobado: 4, paso: 0.5)
    static let porcentaje = EscalaNotas(minimo: 0, maximo: 100, aprobado: 60, paso: 1)
    static let chile = EscalaNotas(minimo: 1, maximo: 7, aprobado: 4, paso: 0.1)
    static let colombia = EscalaNotas(minimo: 1, maximo: 5, aprobado: 3, paso: 0.1)
    static let peru = EscalaNotas(minimo: 0, maximo: 20, aprobado: 11, paso: 1)
    static let mexico = EscalaNotas(minimo: 0, maximo: 10, aprobado: 6)

    static func para(region: String) -> EscalaNotas {
        switch region {
        case "ES", "AR", "UY", "PY", "BO", "EC", "VE", "CU", "DO", "PA", "CR", "GT", "HN", "SV", "NI": .espana
        case "MX": .mexico
        case "IT", "SM", "VA": .italia
        case "FR", "PT", "BE", "LU", "MA", "TN": .veinte
        case "DE", "AT": .alemania
        case "CH": .suiza
        case "CL": .chile
        case "CO": .colombia
        case "PE": .peru
        case "US", "CA", "GB", "IE", "AU", "NZ", "IN", "PH": .porcentaje
        default: .espana
        }
    }
}

enum TipoAyuda: String, Codable, CaseIterable, Identifiable, Sendable {
    case revisar, explicar, resumen, esquema, evaluar

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .revisar: L("Revisar deberes", "Check homework", "Controlla i compiti")
        case .explicar: L("Pregúntale a Hoot", "Ask Hoot", "Chiedi a Hoot")
        case .resumen: L("Resumir un tema", "Summarize a topic", "Riassumi un argomento")
        case .esquema: L("Hacer un esquema", "Make an outline", "Fai uno schema")
        case .evaluar: L("Evalúame", "Quiz me", "Interrogami")
        }
    }

    var nombreCorto: String {
        switch self {
        case .revisar: L("Revisión", "Review", "Revisione")
        case .explicar: L("Charla", "Chat", "Chat")
        case .resumen: L("Resumen", "Summary", "Riassunto")
        case .esquema: L("Esquema", "Outline", "Schema")
        case .evaluar: L("Prueba", "Quiz", "Verifica")
        }
    }

    var simbolo: String {
        switch self {
        case .revisar: "checkmark.seal.fill"
        case .explicar: "bubble.left.and.text.bubble.right.fill"
        case .resumen: "text.alignleft"
        case .esquema: "point.3.connected.trianglepath.dotted"
        case .evaluar: "questionmark.bubble.fill"
        }
    }

    var color: ColorHoot {
        switch self {
        case .revisar: .verde
        case .explicar: .amarillo
        case .resumen: .naranja
        case .esquema: .morado
        case .evaluar: .azul
        }
    }
}

enum ModoRevision: String, Codable, CaseIterable, Identifiable, Sendable {

    case comprobar

    case corregir

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .comprobar: L("Comprobar", "Check", "Verifica")
        case .corregir: L("Corregir", "Correct", "Correggi")
        }
    }
}

enum Longitud: String, Codable, CaseIterable, Identifiable, Sendable {
    case corto, normal, completo

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .corto: L("Corto", "Short", "Breve")
        case .normal: L("Normal", "Normal", "Normale")
        case .completo: L("Completo", "Detailed", "Completo")
        }
    }
}

struct EstudioGuardado: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var tipo: TipoAyuda
    var titulo: String
    var asignaturaID: UUID?
    var fecha: Date
    var resultado: String
    var textoLeido: String

    var miniaturas: [Data] = []

    var prueba: PruebaGuardada?

    var esquema: EsquemaDatos?
}

struct Vinculo: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var nombre: String
    var fecha: Date

    var uid = ""
    var aceptado = true
}

struct EnvioFamilia: Identifiable, Codable, Hashable, Sendable {
    var id: UUID

    var tipo: String
    var json: String

    var mandado = false
}

enum TipoAviso: String, Codable, Sendable {
    case tareaHecha, tareaNueva, examen, nota, mochila, recordatorio, atrasada

    case luna, prueba

    var simbolo: String {
        switch self {
        case .tareaHecha: "checkmark.circle.fill"
        case .tareaNueva: "tray.and.arrow.down.fill"
        case .examen: "doc.text.magnifyingglass"
        case .nota: "chart.bar.fill"
        case .mochila: "backpack.fill"
        case .recordatorio: "bell.fill"
        case .atrasada: "exclamationmark.circle.fill"
        case .luna: "moon.fill"
        case .prueba: "moonphase.first.quarter"
        }
    }

    var color: ColorHoot {
        switch self {
        case .tareaHecha: .verde
        case .tareaNueva: .azul
        case .examen: .rojo
        case .nota: .morado
        case .mochila: .marron
        case .recordatorio: .naranja
        case .atrasada: .rojo
        case .luna: .amarillo
        case .prueba: .indigo
        }
    }
}

struct Aviso: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var tipo: TipoAviso
    var fecha: Date
    var texto: String
    var leido = false
}

struct DatosEscolares: Codable, Equatable, Sendable {
    var asignaturas: [Asignatura] = []
    var franjas: [Franja] = Franja.porDefecto
    var horario: [Clase] = []
    var actividades: [Actividad] = []
    var tareas: [Tarea] = []
    var recordatorios: [Recordatorio] = []
    var notas: [Nota] = []

    var siempre: [String] = []

    var mochilaMarcada: [String: Set<String>] = [:]

    var mochilaExtra: [String: [String]] = [:]

    var diasLectivos: Set<Int> = [1, 2, 3, 4, 5]

    var pruebas: [Prueba] = []

    var temasDeAhora: [TemaDeAhora] = []

    var examenesEnPruebas = false

    var vacaciones: [Vacaciones] = []

    var pruebasAntiguas: [PruebaAntigua] = []

    var delCalendario: [Actividad] = []

    private enum CodingKeys: String, CodingKey {
        case asignaturas, franjas, horario, actividades, tareas, recordatorios, notas, siempre, mochilaMarcada, mochilaExtra, diasLectivos
        case pruebas, temasDeAhora, examenesEnPruebas, vacaciones
    }
}

struct Hijo: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var nombre: String
    var curso = ""
    var colorAvatar: ColorHoot = .naranja
    var datos = DatosEscolares()
    var avisos: [Aviso] = []
    var vinculadoEl = Reloj.ahora

    var uid = ""

    var esperando = false

    var pendientes: [EnvioFamilia] = []

    var actualizado: Date?

    var pideSalas = false
}

extension Franja {

    static var porDefecto: [Franja] {
        func m(_ h: Int, _ min: Int) -> Int { h * 60 + min }
        return [
            Franja(inicio: m(8, 30), fin: m(9, 25)),
            Franja(inicio: m(9, 25), fin: m(10, 20)),
            Franja(inicio: m(10, 20), fin: m(11, 15)),
            Franja(inicio: m(11, 15), fin: m(11, 45), esRecreo: true),
            Franja(inicio: m(11, 45), fin: m(12, 40)),
            Franja(inicio: m(12, 40), fin: m(13, 35)),
            Franja(inicio: m(13, 35), fin: m(14, 30)),
        ]
    }
}
