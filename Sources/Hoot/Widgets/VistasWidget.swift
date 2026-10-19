import ActivityKit
import SwiftUI
import WidgetKit

nonisolated struct InstantaneaWidget: Codable, Equatable, Sendable {
    struct PruebaW: Codable, Equatable, Sendable {
        var id: UUID
        var asignatura: String
        var simbolo: String
        var tipo: String
        var dia: Date
        var lunas: [Double]
    }

    struct TemaW: Codable, Equatable, Sendable {
        var nombre: String
        var luna: Double
    }

    struct RepasoW: Codable, Equatable, Sendable {
        var hora: Int
        var minutos: Int
        var temas: [TemaW]
        var simulacro: Bool
    }

    var prueba: PruebaW?
    var repaso: RepasoW?

    var idioma: String

    static let clave = "hoot.instantanea"

    func L(_ es: String, _ en: String, _ it: String) -> String {
        switch idioma {
        case "en": en
        case "it": it
        default: es
        }
    }

    var locale: Locale { Locale(identifier: idioma) }

    static var grupo: UserDefaults? {
        let propio = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String]

        let app = Bundle(url: Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent())?
            .object(forInfoDictionaryKey: "ALTAppGroups") as? [String]
        guard let id = propio?.first ?? app?.first else { return nil }
        return UserDefaults(suiteName: id)
    }

    static func leer() -> InstantaneaWidget? {
        guard let d = grupo?.data(forKey: clave) else { return nil }
        return try? JSONDecoder().decode(InstantaneaWidget.self, from: d)
    }

    func guardar() {
        guard let d = try? JSONEncoder().encode(self) else { return }
        Self.grupo?.set(d, forKey: Self.clave)
    }

    static var ejemplo: InstantaneaWidget {
        let jueves = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
        return InstantaneaWidget(
            prueba: PruebaW(id: UUID(), asignatura: "Historia", simbolo: "building.columns.fill", tipo: "Escrita", dia: jueves, lunas: [1, 0.5, 0.25, 0]),
            repaso: RepasoW(hora: 17 * 60 + 30, minutos: 20, temas: [TemaW(nombre: "Cartago", luna: 0.5), TemaW(nombre: "Augusto", luna: 0)], simulacro: false),
            idioma: "es")
    }
}

nonisolated struct ActividadRepaso: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var pregunta: Int
        var total: Int
        var luna: Double

        var fin: Date?
    }

    var titulo: String
    var simulacro: Bool
    var idioma: String
}

nonisolated struct LunaWidgetForma: Shape {
    var parte: Double

    func path(in r: CGRect) -> Path {
        let radio = min(r.width, r.height) / 2
        let c = CGPoint(x: r.midX, y: r.midY)
        let k = min(max(parte, 0), 1)
        var p = Path()
        if k <= 0.001 { return p }
        if k >= 0.999 {
            p.addEllipse(in: CGRect(x: c.x - radio, y: c.y - radio, width: radio * 2, height: radio * 2))
            return p
        }
        p.addArc(center: c, radius: radio, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        let ancho = max(abs(cos(.pi * k)), 0.0001)
        let elipse = CGAffineTransform(translationX: c.x, y: c.y).scaledBy(x: ancho, y: 1).translatedBy(x: -c.x, y: -c.y)
        p.addArc(center: c, radius: radio, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: k < 0.5, transform: elipse)
        p.closeSubpath()
        return p
    }
}

struct LunaWidget: View {
    var parte: Double
    var lado: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.03, green: 0.055, blue: 0.157).opacity(0.42))
            Circle().strokeBorder(Color(red: 1, green: 0.886, blue: 0.667).opacity(0.55), lineWidth: max(1, lado / 34))
            LunaWidgetForma(parte: parte)
                .fill(RadialGradient(colors: [Color(red: 1, green: 0.902, blue: 0.651), Color(red: 1, green: 0.76, blue: 0.29), Color(red: 0.95, green: 0.62, blue: 0.11)],
                                     center: UnitPoint(x: 0.38, y: 0.34), startRadius: 0, endRadius: lado * 0.75))
                .widgetAccentable()
        }
        .frame(width: lado, height: lado)
        .accessibilityHidden(true)
    }
}

struct FilaLunasWidget: View {
    var partes: [Double]
    var lado: CGFloat
    var hueco: CGFloat = 4

    var body: some View {
        HStack(spacing: hueco) {
            ForEach(Array(partes.prefix(6).enumerated()), id: \.offset) { _, k in LunaWidget(parte: k, lado: lado) }
        }
    }
}

private let ambarWidget = Color(red: 1, green: 0.722, blue: 0.2)
private let sobreAmbarWidget = Color(red: 0.165, green: 0.09, blue: 0)

struct VistaProximaPrueba: View {
    var i: InstantaneaWidget

    var body: some View {
        if let p = i.prueba {
            let faltan = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: p.dia)).day ?? 0
            let llenas = p.lunas.filter { $0 >= 0.999 }.count
            VStack(alignment: .leading, spacing: 8) {
                Label(p.asignatura, systemImage: p.simbolo)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                FilaLunasWidget(partes: p.lunas, lado: 22)
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 1) {
                    Text(faltan == 0 ? i.L("Hoy", "Today", "Oggi") : (faltan == 1 ? i.L("Mañana", "Tomorrow", "Domani")
                                                                                  : p.dia.formatted(.dateTime.weekday(.wide).locale(i.locale)).capitalized(with: i.locale)))
                        .font(.title3.weight(.bold))
                    Text(i.L("\(llenas) de \(p.lunas.count) temas", "\(llenas) of \(p.lunas.count) topics", "\(llenas) di \(p.lunas.count) argomenti"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                LunaWidget(parte: 1, lado: 28)
                Spacer(minLength: 0)
                Text(i.L("Sin pruebas apuntadas", "No tests yet", "Nessuna verifica")).font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

struct VistaRepasoHoy: View {
    var i: InstantaneaWidget
    @Environment(\.widgetRenderingMode) private var modo

    var body: some View {
        if let r = i.repaso {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(r.simulacro ? i.L("Simulacro", "Mock test", "Simulazione") : i.L("Repaso de hoy", "Today's review", "Ripasso di oggi"),
                          systemImage: r.simulacro ? "checklist" : "moonphase.first.quarter")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(String(format: "%d:%02d", r.hora / 60, r.hora % 60)) · \(r.minutos) min")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                    ForEach(Array(r.temas.prefix(3).enumerated()), id: \.offset) { _, t in
                        HStack(spacing: 7) {
                            LunaWidget(parte: t.luna, lado: 18)
                            Text(t.nombre).font(.subheadline.weight(.semibold)).lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 8)
                VStack {
                    Spacer(minLength: 0)
                    Link(destination: URL(string: "hoot://repaso")!) {

                        Text(i.L("Empezar", "Start", "Inizia"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(modo == .fullColor ? sobreAmbarWidget : Color.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background {
                                if modo == .fullColor { Capsule().fill(ambarWidget) } else { Capsule().strokeBorder(Color.primary, lineWidth: 1.5).widgetAccentable() }
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(i.L("Repaso de hoy", "Today's review", "Ripasso di oggi"), systemImage: "moonphase.first.quarter")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(i.L("Hoy no toca", "Nothing today", "Oggi niente")).font(.title3.weight(.bold))
                    if let p = i.prueba {
                        Text(i.L("Próxima: \(p.asignatura), \(p.dia.formatted(.dateTime.weekday(.wide).locale(i.locale)))",
                                 "Next: \(p.asignatura), \(p.dia.formatted(.dateTime.weekday(.wide).locale(i.locale)))",
                                 "Prossima: \(p.asignatura), \(p.dia.formatted(.dateTime.weekday(.wide).locale(i.locale)))"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                if let p = i.prueba { FilaLunasWidget(partes: p.lunas, lado: 16, hueco: 3) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

struct VistaCircular: View {
    var i: InstantaneaWidget

    var body: some View {
        if let p = i.prueba {
            let llenas = p.lunas.filter { $0 >= 0.999 }.count
            let faltan = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: p.dia)).day ?? 0)
            Gauge(value: Double(llenas), in: 0...Double(max(p.lunas.count, 1))) {
                Image(systemName: "moonphase.first.quarter")
            } currentValueLabel: {
                Text(i.L("\(faltan)d", "\(faltan)d", "\(faltan)g")).font(.system(.body, design: .rounded).weight(.bold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
        } else {
            Image(systemName: "moon.stars.fill").font(.title2)
        }
    }
}

struct VistaRectangular: View {
    var i: InstantaneaWidget

    var body: some View {
        if let p = i.prueba {
            let llenas = p.lunas.filter { $0 >= 0.999 }.count
            VStack(alignment: .leading, spacing: 3) {
                Text("\(p.asignatura) · \(p.dia.formatted(.dateTime.weekday(.wide).locale(i.locale)))")
                    .font(.headline)
                    .lineLimit(1)
                FilaLunasWidget(partes: p.lunas, lado: 15, hueco: 3)
                Text(i.L("\(llenas) de \(p.lunas.count) temas", "\(llenas) of \(p.lunas.count) topics", "\(llenas) di \(p.lunas.count) argomenti"))
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(i.L("Sin pruebas apuntadas", "No tests yet", "Nessuna verifica")).font(.headline)
        }
    }
}

struct VistaInline: View {
    var i: InstantaneaWidget

    var body: some View {
        if let p = i.prueba {
            let llenas = p.lunas.filter { $0 >= 0.999 }.count
            Text(i.L("\(p.asignatura) el \(p.dia.formatted(.dateTime.weekday(.wide).locale(i.locale))) · \(llenas)/\(p.lunas.count)",
                     "\(p.asignatura) on \(p.dia.formatted(.dateTime.weekday(.wide).locale(i.locale))) · \(llenas)/\(p.lunas.count)",
                     "\(p.asignatura) \(p.dia.formatted(.dateTime.weekday(.wide).locale(i.locale))) · \(llenas)/\(p.lunas.count)"))
        } else {
            Text(i.L("Sin pruebas", "No tests", "Nessuna verifica"))
        }
    }
}

struct VistaActividadBloqueo: View {
    var atributos: ActividadRepaso
    var estado: ActividadRepaso.ContentState

    private func L(_ es: String, _ en: String, _ it: String) -> String {
        atributos.idioma == "en" ? en : (atributos.idioma == "it" ? it : es)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                LunaWidget(parte: estado.luna, lado: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(atributos.titulo).font(.headline).lineLimit(1)
                    Text(L("Pregunta \(estado.pregunta) de \(estado.total)", "Question \(estado.pregunta) of \(estado.total)", "Domanda \(estado.pregunta) di \(estado.total)"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let fin = estado.fin {
                    Text(timerInterval: Date.now...max(fin, .now), countsDown: true)
                        .font(.title2.weight(.heavy))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(ambarWidget)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                }
            }
            ProgressView(value: Double(estado.pregunta), total: Double(max(estado.total, 1)))
                .tint(ambarWidget)
        }
        .padding(16)
    }
}
