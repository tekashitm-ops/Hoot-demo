import SwiftUI

enum SeccionTareas: String, CaseIterable, Identifiable {
    case deberes, examenes, recordatorios
    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .deberes: L("Deberes", "Homework", "Compiti")
        case .examenes: L("Exámenes", "Tests", "Verifiche")
        case .recordatorios: L("Recordatorios", "Reminders", "Promemoria")
        }
    }
}

enum NuevoElemento: String, Identifiable {
    case deberes, examen, actividad, recordatorio
    var id: String { rawValue }
}

enum GrupoFecha: Int, CaseIterable, Identifiable {
    case atrasadas, hoy, manana, semana, despues
    var id: Int { rawValue }

    var nombre: String {
        switch self {
        case .atrasadas: L("Atrasadas", "Late", "In ritardo")
        case .hoy: L("Hoy", "Today", "Oggi")
        case .manana: L("Mañana", "Tomorrow", "Domani")
        case .semana: L("Próximos 7 días", "Next 7 days", "Prossimi 7 giorni")
        case .despues: L("Más adelante", "Later", "Più avanti")
        }
    }

    static func de(_ fecha: Date, ahora: Date = Reloj.ahora) -> GrupoFecha {
        let cal = calendarioActual
        let dias = cal.dateComponents([.day], from: cal.startOfDay(for: ahora), to: cal.startOfDay(for: fecha)).day ?? 0
        if dias < 0 { return .atrasadas }
        if dias == 0 { return fecha < ahora ? .atrasadas : .hoy }
        if dias == 1 { return .manana }
        if dias <= 7 { return .semana }
        return .despues
    }
}

enum TareasVista {
    static func entregaPorDefecto(examen: Bool = false) -> Date {
        let cal = calendarioActual
        let manana = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Reloj.ahora)) ?? Reloj.ahora
        return DatosEscolares.fecha(manana, minutos: examen ? 9 * 60 : 23 * 60 + 59)
    }
}
