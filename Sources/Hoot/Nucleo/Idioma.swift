import SwiftUI

enum Idioma: String, Codable, CaseIterable, Identifiable, Sendable {
    case es, en, it

    var id: String { rawValue }

    var nombrePropio: String {
        switch self {
        case .es: "Español"
        case .en: "English"
        case .it: "Italiano"
        }
    }

    var nombreTraducido: String {
        switch self {
        case .es: L("Español", "Spanish", "Spagnolo")
        case .en: L("Inglés", "English", "Inglese")
        case .it: L("Italiano", "Italian", "Italiano")
        }
    }

    static var delSistema: Idioma {
        for codigo in Locale.preferredLanguages {
            let base = String(codigo.prefix(2))
            if let idioma = Idioma(rawValue: base) { return idioma }
        }
        return .en
    }
}

var idiomaActual: Idioma = .delSistema

var regionActual: String = Locale.current.region?.identifier ?? "ES"

func L(_ es: String, _ en: String, _ it: String) -> String {
    switch idiomaActual {
    case .es: es
    case .en: en
    case .it: it
    }
}

var localeActual: Locale {
    Locale(identifier: "\(idiomaActual.rawValue)_\(regionActual)")
}

var calendarioActual: Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.locale = localeActual
    cal.timeZone = .current
    return cal
}

extension String {

    var conMayuscula: String {
        guard let primera = first else { return self }
        return String(primera).uppercased(with: localeActual) + dropFirst()
    }

    var conMarkdown: AttributedString {
        (try? AttributedString(markdown: self, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(self)
    }
}

enum Formato {

    static func hora(_ minutos: Int) -> String {

        let m = (minutos % (24 * 60) + 24 * 60) % (24 * 60)
        let fecha = calendarioActual.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Reloj.ahora) ?? Reloj.ahora
        return fecha.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(localeActual))
    }

    static func hora(_ fecha: Date) -> String {
        fecha.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(localeActual))
    }

    static func diaLargo(_ fecha: Date) -> String {
        fecha.formatted(Date.FormatStyle().weekday(.wide).day().month(.wide).locale(localeActual))
    }

    static func diaMes(_ fecha: Date) -> String {
        fecha.formatted(Date.FormatStyle().day().month(.wide).locale(localeActual))
    }

    static func diaCorto(_ fecha: Date) -> String {
        fecha.formatted(Date.FormatStyle().day().month(.abbreviated).locale(localeActual))
    }

    static func diaSemanaCorto(_ fecha: Date) -> String {
        fecha.formatted(Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated).locale(localeActual))
    }

    static func diaSemana(_ fecha: Date) -> String {
        fecha.formatted(Date.FormatStyle().weekday(.wide).locale(localeActual))
    }

    static func mes(_ fecha: Date) -> String {
        fecha.formatted(Date.FormatStyle().month(.wide).year().locale(localeActual))
    }

    static func mesSolo(_ fecha: Date) -> String {
        fecha.formatted(Date.FormatStyle().month(.wide).locale(localeActual))
    }

    static func nombreDia(iso: Int, estilo: Date.FormatStyle.Symbol.Weekday = .abbreviated) -> String {

        let base = calendarioActual.date(from: DateComponents(year: 2026, month: 1, day: 5)) ?? Reloj.ahora
        let dia = calendarioActual.date(byAdding: .day, value: iso - 1, to: base) ?? base
        return dia.formatted(Date.FormatStyle().weekday(estilo).locale(localeActual))
    }

    static func diaRelativo(_ fecha: Date, desde hoy: Date = Reloj.ahora) -> String {
        let cal = calendarioActual
        let dias = cal.dateComponents([.day], from: cal.startOfDay(for: hoy), to: cal.startOfDay(for: fecha)).day ?? 0
        switch dias {
        case 0: return L("Hoy", "Today", "Oggi")
        case 1: return L("Mañana", "Tomorrow", "Domani")
        case -1: return L("Ayer", "Yesterday", "Ieri")
        case 2...6: return diaSemana(fecha).conMayuscula
        default: return diaCorto(fecha)
        }
    }

    static func diaEnFrase(_ fecha: Date, desde hoy: Date = Reloj.ahora) -> String {
        let cal = calendarioActual
        let dias = cal.dateComponents([.day], from: cal.startOfDay(for: hoy), to: cal.startOfDay(for: fecha)).day ?? 0
        switch dias {
        case 0: return L("hoy", "today", "oggi")
        case 1: return L("mañana", "tomorrow", "domani")
        case 2...6:
            let d = diaSemana(fecha)
            return L("el \(d)", "on \(d)", d)
        default:
            let d = diaCorto(fecha)
            return L("el \(d)", "on \(d)", "il \(d)")
        }
    }

    static func numero(_ valor: Double, decimales: Int = 1) -> String {
        valor.formatted(.number.precision(.fractionLength(0...decimales)).locale(localeActual))
    }

    static func reloj(_ segundos: Double) -> String {
        let t = max(0, Int(segundos.rounded()))
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60)
    }

    static func duracionCorta(minutos: Int) -> String {
        let h = minutos / 60, m = minutos % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) h" }
        return "\(h) h \(m)"
    }

    static func duracion(minutos: Int) -> String {
        let h = minutos / 60, m = minutos % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) h" }
        return "\(h) h \(m) min"
    }
}
