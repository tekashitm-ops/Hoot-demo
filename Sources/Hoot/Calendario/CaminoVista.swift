import SwiftUI

struct CaminoVista: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dynamicTypeSize) private var letra
    @State private var repaso: PeticionRepaso?
    @State private var simulacroDe: UUID?

    static let dias = 21

    var body: some View {
        TimelineView(.everyMinute) { contexto in
            let ahora = Reloj.desde(contexto.date)
            let datos = almacen.datosConCalendario
            let plan = almacen.datos.planRepaso(ajustes: almacen.ajustes, ahora: ahora)
            let cal = calendarioActual
            let dias = DiaCamino.siguientes(Self.dias, datos: datos, plan: plan, desde: ahora)
            let proximas = datos.pruebas.filter { $0.diasQueFaltan(desde: ahora, cal: cal) >= 0 }.sorted { $0.fecha < $1.fecha }
            let enCamino = proximas.filter { $0.diasQueFaltan(desde: ahora, cal: cal) < Self.dias }
            let despues = proximas.filter { $0.diasQueFaltan(desde: ahora, cal: cal) >= Self.dias }
            ScrollView {
                VStack(alignment: .leading, spacing: Diseno.huecoTarjetas) {
                    if proximas.isEmpty {
                        HootDice(frase: FrasesHoot.sinPruebas(), gesto: .pensando, tamano: 104, loboALaDerecha: true, paraguasSiLlueve: false)
                            .padding(.top, 8)
                    } else {

                        let disposicion = letra.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
                        disposicion {
                            resumen("\(enCamino.count)", enCamino.count == 1 ? L("prueba en 3 semanas", "test in 3 weeks", "verifica in 3 settimane")
                                                                             : L("pruebas en 3 semanas", "tests in 3 weeks", "verifiche in 3 settimane"))
                            resumen(proximas.first.map { "\($0.diasQueFaltan(desde: ahora, cal: cal))" } ?? "–",
                                    L("días a la próxima", "days to the next", "giorni alla prossima"))
                        }
                    }
                    let semanas = Dictionary(grouping: dias) { cal.component(.weekOfYear, from: $0.dia) }
                        .sorted { ($0.value.first?.dia ?? .distantPast) < ($1.value.first?.dia ?? .distantPast) }
                    ForEach(Array(semanas.enumerated()), id: \.offset) { si, s in
                        TarjetaCielo(titulo: Self.titulo(semana: si), simbolo: "point.topleft.down.to.point.bottomright.curvepath.fill") {
                            let lista = s.value.sorted { $0.dia < $1.dia }
                            VStack(spacing: 0) {
                                ForEach(Array(lista.enumerated()), id: \.element.id) { i, d in
                                    PasoDelCamino(d: d, datos: datos, primero: si == 0 && i == 0,
                                                  abrirRepaso: empezar, abrirSimulacro: { simulacroDe = $0 })
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    if !despues.isEmpty {
                        TarjetaCielo(titulo: L("Más adelante", "Later", "Più avanti"), simbolo: "calendar.badge.clock") {
                            ForEach(Array(despues.enumerated()), id: \.element.id) { n, p in
                                if n > 0 { Separador() }
                                NavigationLink(value: RutaPruebas.prueba(p.id)) {
                                    FilaPrueba(prueba: p, asignatura: datos.asignatura(p.asignaturaID), ahora: ahora, cal: cal)
                                        .padding(.vertical, 9)
                                }
                                .buttonStyle(EstiloFilaCielo())
                            }
                        }
                    }
                }
                .padding(.horizontal, Diseno.margenTarjeta)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .fullScreenCover(item: $repaso) { r in
            RepasoTemas(peticion: r) { repaso = nil }
        }
        .simulacro(de: $simulacroDe)
    }

    private func empezar(_ s: SesionRepaso) {
        let ids = s.temaIDs.filter { almacen.datos.tema($0).map { !$0.textoLeido.isEmpty } ?? false }
        if !ids.isEmpty { repaso = PeticionRepaso(temaIDs: ids, mezclado: s.mezclada) }
    }

    private func resumen(_ cifra: String, _ texto: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(cifra).font(.title.weight(.bold)).fontDesign(.rounded).monospacedDigit().foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(texto).font(.caption.weight(.semibold)).foregroundStyle(EstiloSecundario()).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .fondoModulo()
        .accessibilityElement(children: .combine)
    }

    static func titulo(semana: Int) -> String {
        switch semana {
        case 0: L("Esta semana", "This week", "Questa settimana")
        case 1: L("La que viene", "Next week", "La prossima")
        case 2: L("Dentro de dos", "In two weeks", "Tra due settimane")
        default: L("Dentro de tres", "In three weeks", "Tra tre settimane")
        }
    }
}

struct DiaCamino: Identifiable {
    var dia: Date
    var pruebas: [Prueba]
    var repasos: [SesionRepaso]
    var id: Date { dia }

    static func siguientes(_ n: Int, datos: DatosEscolares, plan: PlanRepaso, desde: Date) -> [DiaCamino] {
        let cal = calendarioActual
        let hoy = cal.startOfDay(for: desde)
        return (0..<n).compactMap { i in
            guard let d = cal.date(byAdding: .day, value: i, to: hoy) else { return nil }
            return DiaCamino(dia: d, pruebas: datos.pruebas.filter { cal.isDate($0.fecha, inSameDayAs: d) }.sorted { $0.fecha < $1.fecha },
                             repasos: plan.sesiones(en: d, cal: cal))
        }
    }

    static func corto(_ d: Date) -> String {
        d.formatted(Date.FormatStyle().weekday(.abbreviated).day().locale(localeActual)).replacingOccurrences(of: ",", with: "").conMayuscula
    }
}

private struct PasoDelCamino: View {
    var d: DiaCamino
    var datos: DatosEscolares
    var primero: Bool
    var abrirRepaso: (SesionRepaso) -> Void
    var abrirSimulacro: (UUID) -> Void
    @ScaledMetric(relativeTo: .body) private var lado: CGFloat = 30

    var body: some View {
        let cal = calendarioActual
        let hoy = cal.isDate(d.dia, inSameDayAs: Reloj.ahora)
        let vacio = d.pruebas.isEmpty && d.repasos.isEmpty
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Rectangle().fill(.white.opacity(0.28)).frame(width: 2)
                    .padding(.top, primero ? 22 : 0)
                senal(hoy: hoy, cal: cal)
            }
            .frame(width: 36)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(hoy ? L("Hoy", "Today", "Oggi") : DiaCamino.corto(d.dia))
                    .font(vacio ? .footnote : .subheadline.weight(.semibold))
                    .foregroundStyle(vacio ? AnyShapeStyle(EstiloSecundario()) : AnyShapeStyle(.white))
                ForEach(d.pruebas) { p in
                    NavigationLink(value: RutaPruebas.prueba(p.id)) { filaPrueba(p, cal: cal) }
                        .buttonStyle(EstiloFilaCielo())
                }

                if let s = d.repasos.first {
                    Button { if s.simulacro, let id = s.pruebaID { abrirSimulacro(id) } else { abrirRepaso(s) } } label: {
                        filaRepaso(s)
                    }
                    .buttonStyle(EstiloFilaCielo())
                }
            }
            .padding(.vertical, vacio ? 3 : 9)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func senal(hoy: Bool, cal: Calendar) -> some View {
        if let p = d.pruebas.first {
            Luna(parte: Self.parte(p, cal: cal), tamano: lado)
                .overlay { if hoy { Circle().strokeBorder(.white, lineWidth: 2).padding(-4) } }
        } else if !d.repasos.isEmpty {
            Circle().fill(Color.ambar).frame(width: 14, height: 14)
                .overlay { if hoy { Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2).padding(-4) } }
        } else {
            Circle().fill(.white.opacity(hoy ? 1 : 0.45)).frame(width: hoy ? 12 : 6, height: hoy ? 12 : 6)
        }
    }

    static func parte(_ p: Prueba, cal: Calendar) -> Double {
        let partes = p.temas.map { $0.luna(cal: cal).fraccion }
        guard !partes.isEmpty else { return 0 }
        return ((partes.reduce(0, +) / Double(partes.count)) * 4).rounded() / 4
    }

    private func filaPrueba(_ p: Prueba, cal: Calendar) -> some View {
        let a = datos.asignatura(p.asignaturaID)
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(a?.nombre ?? p.tipo.nombre) · \(p.tipo.nombre.lowercased()) · \(Formato.hora(p.fecha))")
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            HStack(spacing: 8) {
                FilaLunas(partes: p.temas.prefix(6).map { $0.luna(cal: cal).fraccion }, tamano: 16, hueco: 3)
                Text(L("\(p.llenos(cal: cal)) de \(p.temas.count) temas", "\(p.llenos(cal: cal)) of \(p.temas.count) topics",
                       "\(p.llenos(cal: cal)) di \(p.temas.count) argomenti"))
                    .font(.subheadline)
                    .foregroundStyle(EstiloSecundario())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func filaRepaso(_ s: SesionRepaso) -> some View {
        let nombres = s.temaIDs.compactMap { datos.tema($0)?.nombre }.prefix(2).joined(separator: ", ")
        return VStack(alignment: .leading, spacing: 1) {
            Text(nombre(s)).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ambar)
            if !nombres.isEmpty {
                Text(nombres).font(.subheadline).foregroundStyle(EstiloSecundario()).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(L("Empieza el repaso", "Starts the review", "Inizia il ripasso"))
    }

    private func nombre(_ s: SesionRepaso) -> String {
        let prueba = s.pruebaID.flatMap { id in datos.pruebas.first { $0.id == id } } ?? datos.prueba(deTema: s.temaIDs.first ?? UUID())
        let a = datos.asignatura(prueba?.asignaturaID)?.nombre
        if s.simulacro { return L("Simulacro de \(a ?? "la prueba")", "Mock test: \(a ?? "the test")", "Simulazione di \(a ?? "la verifica")") }
        guard let a, !(s.pruebaID == nil && s.mezclada) else {
            return L("Repaso mezclado · \(s.minutos) min", "Mixed review · \(s.minutos) min", "Ripasso misto · \(s.minutos) min")
        }
        return L("Repasa \(a) · \(s.minutos) min", "Review \(a) · \(s.minutos) min", "Ripassa \(a) · \(s.minutos) min")
    }
}
