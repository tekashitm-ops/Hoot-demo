import SwiftUI

enum Momento: Hashable {
    case manana, tarde, noche

    static func de(_ ahora: Date, datos: DatosEscolares) -> Momento {
        let m = DatosEscolares.minutos(ahora)
        if m >= 19 * 60 + 30 || m < 5 * 60 { return .noche }
        if let ultima = datos.clases(en: ahora).last { return m < ultima.fin ? .manana : .tarde }
        return m < 13 * 60 ? .manana : .tarde
    }
}

struct ResumenInicio {
    let ahora: Date
    let momento: Momento
    let hoy: Date

    let diaClases: Date?
    let clases: [Clase]
    let mochilaDia: Date?
    let metidas: Int
    let totalMochila: Int
    let plan: PlanEstudio

    let ratosHoy: [Sesion]

    let hechosHoy: [Tarea]

    let actividadesHoy: [Actividad]

    let entregasHoy: [Tarea]

    let entregasProximo: [Tarea]
    let examen: Tarea?
    let diasExamen: Int

    let nombreExamen: String?
    let recordatorios: [Recordatorio]

    let tareasPorID: [UUID: Tarea]

    init(datos: DatosEscolares, ahora: Date) {
        let cal = calendarioActual
        self.ahora = ahora
        let momento = Momento.de(ahora, datos: datos)
        self.momento = momento
        let hoy = cal.startOfDay(for: ahora)
        self.hoy = hoy
        let manana = cal.date(byAdding: .day, value: 1, to: hoy) ?? hoy

        let clasesHoy = datos.clases(en: ahora)
        let terminadas = clasesHoy.last.map { DatosEscolares.minutos(ahora) >= $0.fin } ?? true

        let antesDeClase = clasesHoy.first.map { DatosEscolares.minutos(ahora) < $0.inicio } ?? false
        let diaClases: Date? = !clasesHoy.isEmpty && (antesDeClase || (momento == .manana && !terminadas))
            ? hoy : datos.siguienteDiaConClase(despuesDe: ahora)
        self.diaClases = diaClases
        self.clases = diaClases.map { datos.clases(en: $0) } ?? []

        let mochilaDia = datos.diaMochila(ahora: ahora)
        self.mochilaDia = mochilaDia
        if let mochilaDia {
            let items = datos.itemsMochila(para: mochilaDia)
            let marcadas = datos.marcadas(mochilaDia)
            totalMochila = items.count
            metidas = items.filter { marcadas.contains($0.id) }.count
        } else {
            totalMochila = 0
            metidas = 0
        }

        let plan = datos.plan(ahora: ahora)
        self.plan = plan
        ratosHoy = plan.sesiones(en: hoy)
        hechosHoy = datos.tareas.filter { t in
            if t.tipo == .deberes { return t.hecha && (t.hechaEl.map { cal.isDate($0, inSameDayAs: hoy) } ?? false) }
            return t.ratosHechos.contains { cal.isDate($0, inSameDayAs: hoy) }
        }
        let m = DatosEscolares.minutos(ahora)
        actividadesHoy = datos.actividades(en: hoy).filter { a in (a.fin ?? a.inicio.map { $0 + 60 } ?? 24 * 60) > m }
        entregasHoy = datos.tareas
            .filter { !$0.hecha && $0.tipo != .examen && $0.entrega < manana }
            .sorted { $0.entrega < $1.entrega }

        if let diaClases, diaClases > hoy || momento == .noche {
            entregasProximo = datos.tareas
                .filter { !$0.hecha && $0.tipo != .examen && cal.isDate($0.entrega, inSameDayAs: diaClases) }
                .sorted { $0.entrega < $1.entrega }
        } else {
            entregasProximo = []
        }
        if let ex = datos.proximoExamen(desde: ahora) {
            let dias = cal.dateComponents([.day], from: hoy, to: cal.startOfDay(for: ex.entrega)).day ?? 0
            examen = dias <= 14 ? ex : nil
            diasExamen = dias
        } else {
            examen = nil
            diasExamen = 0
        }
        recordatorios = datos.recordatorios(en: hoy).filter { !$0.hecho }
        nombreExamen = examen.map { datos.asignatura($0.asignaturaID)?.nombre ?? $0.titulo }
        tareasPorID = Dictionary(datos.tareas.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var examenSinPreparar: Bool {
        examen.map { ex in diasExamen <= 2 && ex.ratosHechos.count * 2 < DatosEscolares.esfuerzo(ex).ratos } ?? false
    }

    var motivoPreocupacion: String? {
        let atrasadas = entregasHoy.filter { $0.entrega < ahora }.count
        let examenYa = examenSinPreparar && diasExamen <= 1
        if !examenYa && atrasadas == 1 { return L("Una tarea atrasada", "One late task", "Un compito in ritardo") }
        if !examenYa && atrasadas > 1 { return L("\(atrasadas) tareas atrasadas", "\(atrasadas) late tasks", "\(atrasadas) compiti in ritardo") }
        if examenSinPreparar, let ex = examen, let nombre = nombreExamen {
            let cuando = Formato.diaRelativo(ex.entrega, desde: ahora).lowercased(with: localeActual)
            let total = DatosEscolares.esfuerzo(ex).ratos
            let hechos = min(ex.ratosHechos.count, total)
            return L("Examen de \(nombre) \(cuando): \(hechos) de \(total) ratos", "\(nombre) test \(cuando): \(hechos) of \(total) sessions",
                     "Verifica di \(nombre) \(cuando): \(hechos) di \(total) sessioni")
        }
        if momento == .noche, totalMochila > 0, !mochilaLista {
            return L("Falta la mochila: \(metidas) de \(totalMochila)", "Backpack not ready: \(metidas) of \(totalMochila)", "Manca lo zaino: \(metidas) di \(totalMochila)")
        }
        return nil
    }

    var mochilaLista: Bool { totalMochila > 0 && metidas == totalMochila }

    var gestoLobo: GestoLobo {
        let m = DatosEscolares.minutos(ahora)
        let atrasadas = entregasHoy.contains { $0.entrega < ahora }
        let examenSinPreparar = examen.map { ex in diasExamen <= 2 && ex.ratosHechos.count * 2 < DatosEscolares.esfuerzo(ex).ratos } ?? false
        let mochilaSinHacer = momento == .noche && totalMochila > 0 && !mochilaLista
        if atrasadas || examenSinPreparar || mochilaSinHacer { return .preocupado }
        if m >= 22 * 60 || m < 6 * 60 { return .dormido }
        if ratosHoy.isEmpty && entregasHoy.isEmpty { return .feliz }
        return .normal
    }

    var nombreDiaMochila: String {
        guard let mochilaDia else { return "" }
        return Formato.diaRelativo(mochilaDia, desde: ahora).lowercased(with: localeActual)
    }
}

struct FilaRato: View {
    var sesion: Sesion?
    var tarea: Tarea
    var asignatura: Asignatura?
    var hecho: Bool
    var ahora: Date

    var minutos: Int? = nil
    var alAlternar: () -> Void
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        HStack(alignment: letra.isAccessibilitySize ? .top : .center, spacing: 12) {
            Casilla(marcada: hecho, color: asignatura?.color ?? .indigo, etiqueta: titulo, accion: alAlternar)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .foregroundStyle(hecho ? AnyShapeStyle(EstiloSecundario()) : AnyShapeStyle(Color.primary))
                    .strikethrough(hecho)
                    .lineLimit(letra.isAccessibilitySize ? nil : 2)
                Text(detalle)
                    .font(.subheadline)
                    .textoSecundario()
                    .lineLimit(letra.isAccessibilitySize ? nil : 1)
                if letra.isAccessibilitySize, let sesion, !hecho {
                    Text("\(Formato.hora(sesion.hora)) · \(sesion.minutos) min")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
            }
            Spacer(minLength: 8)
            if let sesion, !hecho, !letra.isAccessibilitySize {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Formato.hora(sesion.hora))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    Text("\(sesion.minutos) min")
                        .font(.caption.monospacedDigit())
                        .textoSecundario()
                }
                .accessibilityElement(children: .combine)
            }
        }
        .contentShape(Rectangle())
    }

    private var titulo: String {
        switch tarea.tipo {
        case .examen:
            let a = asignatura?.nombre ?? tarea.titulo
            return L("Estudiar \(a)", "Study \(a)", "Studiare \(a)")
        default:
            return tarea.titulo
        }
    }

    private var detalle: String {
        let cuando = Formato.diaRelativo(tarea.entrega, desde: ahora).lowercased(with: localeActual)
        let rato = sesion.map { s in s.total > 1 ? L(" · rato \(s.numero) de \(s.total)", " · part \(s.numero) of \(s.total)", " · parte \(s.numero) di \(s.total)") : "" } ?? ""
        let duracion = minutos.map { " · \($0) min" } ?? ""
        switch tarea.tipo {
        case .deberes:
            return [asignatura?.nombre, L("para \(cuando)", "due \(cuando)", "per \(cuando)")].compactMap { $0 }.joined(separator: " · ") + duracion
        case .examen:
            let r = sesion.map { s in L("Rato \(s.numero) de \(s.total)", "Part \(s.numero) of \(s.total)", "Parte \(s.numero) di \(s.total)") }
            return (r ?? L("Examen \(cuando)", "Test \(cuando)", "Verifica \(cuando)")) + duracion
        case .trabajo:
            return L("Se entrega \(cuando)", "Due \(cuando)", "Consegna \(cuando)") + rato + duracion
        }
    }
}

struct FilaActividadInicio: View {
    var actividad: Actividad
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        if letra.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                Label(actividad.titulo, systemImage: actividad.simbolo)
                    .foregroundStyle(Color.primary)
                Text(actividad.inicio.map { i in actividad.fin.map { "\(Formato.hora(i))–\(Formato.hora($0))" } ?? Formato.hora(i) } ?? L("Todo el día", "All day", "Tutto il giorno"))
                    .font(.subheadline.monospacedDigit())
                    .textoSecundario()
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
        } else {
            fila
        }
    }

    private var fila: some View {
        HStack(spacing: 12) {
            Image(systemName: actividad.simbolo)
                .font(.body.weight(.semibold))
                .foregroundStyle(actividad.color.sobre)
                .frame(width: 32, height: 32)
                .background(actividad.color.color.gradient, in: Circle())
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(actividad.titulo)
                    .lineLimit(1)
                let detalle = [actividad.lugar, actividad.llevar.isEmpty ? "" : L("Llevar: ", "Bring: ", "Portare: ") + actividad.llevar.joined(separator: ", ")]
                    .filter { !$0.isEmpty }.joined(separator: " · ")
                if !detalle.isEmpty {
                    Text(detalle)
                        .font(.subheadline)
                        .textoSecundario()
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let inicio = actividad.inicio {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Formato.hora(inicio))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    if let fin = actividad.fin {
                        Text(Formato.hora(fin))
                            .font(.caption.monospacedDigit())
                            .textoSecundario()
                    }
                }
            } else {
                Text(L("Todo el día", "All day", "Tutto il giorno"))
                    .font(.subheadline)
                    .textoSecundario()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct FilaMochilaInicio: View {
    var resumen: ResumenInicio

    var mostrarCuenta = true
    var alPreparar: () -> Void
    @ScaledMetric(relativeTo: .body) private var lado: CGFloat = 30
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        let lista = resumen.mochilaLista
        Button(action: alPreparar) {
            HStack(alignment: letra.isAccessibilitySize ? .top : .center, spacing: 12) {
                MochilaLlena(progreso: resumen.totalMochila == 0 ? 0 : Double(resumen.metidas) / Double(resumen.totalMochila),
                             color: lista ? .hecho : .acento, lado: min(lado, 44))
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Mochila para \(resumen.nombreDiaMochila)", "Backpack for \(resumen.nombreDiaMochila)", "Zaino per \(resumen.nombreDiaMochila)"))
                        .foregroundStyle(Color.primary)
                    Text(lista
                         ? L("Preparada", "Packed", "Pronto")
                         : L("Faltan \(resumen.totalMochila - resumen.metidas) cosas", "\(resumen.totalMochila - resumen.metidas) things left", "Mancano \(resumen.totalMochila - resumen.metidas) cose"))
                        .font(.subheadline)
                        .foregroundStyle(lista ? AnyShapeStyle(Color.hecho) : AnyShapeStyle(EstiloSecundario()))
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 8)
                if mostrarCuenta && !letra.isAccessibilitySize {
                    Text("\(resumen.metidas)/\(resumen.totalMochila)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(lista ? Color.hecho : Color.primary)
                        .contentTransition(.numericText())
                }
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(EstiloSecundario())
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct FilaExamenInicio: View {
    var examen: Tarea
    var dias: Int
    var asignatura: Asignatura?
    var ahora: Date
    @ScaledMetric(relativeTo: .body) private var lado: CGFloat = 40
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        let color: Color = dias <= 1 ? .urgente : (dias <= 3 ? .pronto : (asignatura?.color.color ?? .acento))
        let total = DatosEscolares.esfuerzo(examen).ratos
        let hechos = min(examen.ratosHechos.count, total)
        HStack(alignment: letra.isAccessibilitySize ? .top : .center, spacing: 12) {

            RatosExamen(hechos: hechos, total: total, color: color)
                .frame(width: min(lado, 56), height: min(lado, 56))
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Examen de \(asignatura?.nombre ?? examen.titulo)", "\(asignatura?.nombre ?? examen.titulo) test", "Verifica di \(asignatura?.nombre ?? examen.titulo)"))
                    .lineLimit(2)
                Text([Formato.diaRelativo(examen.entrega, desde: ahora), examen.temas.isEmpty ? nil : examen.temas].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .textoSecundario()
                    .lineLimit(letra.isAccessibilitySize ? nil : 1)
            }
            Spacer(minLength: 8)
            if !letra.isAccessibilitySize {
                textoDias
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(L("Preparado: \(hechos) de \(total) ratos", "Prepared: \(hechos) of \(total) sessions", "Preparato: \(hechos) di \(total) sessioni"))
    }

    private var textoDias: some View {
            Text(dias == 0 ? L("Hoy", "Today", "Oggi") : (dias == 1 ? L("1 día", "1 day", "1 giorno") : L("\(dias) días", "\(dias) days", "\(dias) giorni")))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(dias <= 1 ? AnyShapeStyle(EstiloUrgente()) : AnyShapeStyle(Color.primary))
    }
}

struct SeparadorInicio: View {
    var body: some View {
        Divider().padding(.leading, 56)
    }
}

struct RatosExamen: View {
    var hechos: Int
    var total: Int
    var color: Color
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        GeometryReader { geo in
            let lado = min(geo.size.width, geo.size.height)
            let n = max(total, 1)
            let hueco = 0.035
            ZStack {
                ForEach(0..<n, id: \.self) { i in
                    let desde = Double(i) / Double(n) + hueco / 2
                    let hasta = Double(i + 1) / Double(n) - hueco / 2
                    let hecho = i < hechos
                    Circle()
                        .trim(from: desde, to: hasta)
                        .stroke(color, style: StrokeStyle(lineWidth: hecho ? lado * 0.13 : lado * 0.045, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(lado * 0.07)
                        .animation(reducirMovimiento ? nil : Diseno.muelleRebote, value: hecho)
                }
                Image(systemName: TipoTarea.examen.simbolo)
                    .font(.system(size: lado * 0.34, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: lado, height: lado)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
