import SwiftUI

struct TituloCielo: View {
    var titulo: String
    var simbolo: String

    var accion: (titulo: String, hacer: () -> Void)? = nil

    var enTarjeta = false

    var detalle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(titulo.uppercased(with: localeActual), systemImage: simbolo)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if let detalle, !detalle.isEmpty {
                    Text(detalle)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.86))
                }
                if let accion {
                    Button(action: accion.hacer) {
                        HStack(spacing: 3) {
                            Text(accion.titulo)
                            Image(systemName: "chevron.forward").font(.caption2.weight(.bold))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 20)
            Rectangle().fill(.white.opacity(0.22)).frame(height: 0.5)
        }
        .padding(.top, enTarjeta ? (accion == nil ? 14 : 2) : (accion == nil ? 30 : 18))
        .padding(.bottom, 4)
    }
}

struct TarjetaCielo<Contenido: View>: View {
    var titulo: String
    var simbolo: String
    var accion: (titulo: String, hacer: () -> Void)? = nil
    @ViewBuilder var contenido: Contenido

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TituloCielo(titulo: titulo, simbolo: simbolo, accion: accion, enTarjeta: true)
            contenido
        }
        .padding(.horizontal, Diseno.margenTarjeta)
        .padding(.bottom, 6)
        .clipShape(RoundedRectangle(cornerRadius: Diseno.radioModulo, style: .continuous))
        .fondoModulo()
    }
}

struct FondoModulo: ViewModifier {
    var radio: CGFloat = Diseno.radioModulo
    @Environment(Almacen.self) private var almacen
    @Environment(\.cieloSinVelo) private var cieloSinVelo

    func body(content: Content) -> some View {

        let tono = TiempoReal.compartido.escena(fijado: TiempoFijo(rawValue: almacen.ajustes.tiempoFondo) ?? .real).tono
        let color = cieloSinVelo ? tono.modulo : tono.fondo
        let opacidad = cieloSinVelo ? Self.opacidadSinVelo : Self.opacidad
        let forma = RoundedRectangle(cornerRadius: radio, style: .continuous)
        content
            .background {
                ZStack {
                    forma.fill(Self.material)
                    forma.fill(color.color.opacity(opacidad))
                }
                .animation(Diseno.muelleLento, value: tono)
            }
            .chocable(.caja(radio: radio))
    }

    static let opacidad = 0.85

    static let opacidadSinVelo = 0.93

    static var material: SwiftUI.Material {
        switch ModoCapturas.activo ? ModoCapturas.valor("-modulo") : nil {
        case "fino": .thinMaterial
        case "normal": .regularMaterial
        default: .ultraThinMaterial
        }
    }
}

extension View {

    func fondoModulo(radio: CGFloat = Diseno.radioModulo) -> some View {
        modifier(FondoModulo(radio: radio))
    }

    func filaEnTarjeta(_ sitio: SitioEnTarjeta, raya: Bool = false, margen: CGFloat = Diseno.margen,
                       arriba: CGFloat = 0, abajo: CGFloat = 0) -> some View {

        let huecoArriba = sitio.redondeaArriba ? Diseno.huecoTarjetas / 2 : 0
        let huecoAbajo = sitio.redondeaAbajo ? Diseno.huecoTarjetas / 2 : 0
        return listRowInsets(EdgeInsets(top: arriba + huecoArriba, leading: margen + Diseno.margenTarjeta,
                                        bottom: abajo + huecoAbajo, trailing: margen + Diseno.margenTarjeta))
            .listRowBackground(TrozoDeTarjeta(sitio: sitio, raya: raya)
                .padding(.horizontal, margen)
                .padding(.top, huecoArriba)
                .padding(.bottom, huecoAbajo))
            .listRowSeparator(.hidden)
    }
}

enum SitioEnTarjeta {
    case arriba, medio, abajo, sola

    var redondeaArriba: Bool { self == .arriba || self == .sola }
    var redondeaAbajo: Bool { self == .abajo || self == .sola }
}

struct TrozoDeTarjeta: View {
    var sitio: SitioEnTarjeta
    var raya = false
    @Environment(Almacen.self) private var almacen
    @Environment(\.cieloSinVelo) private var cieloSinVelo

    var body: some View {
        let tono = TiempoReal.compartido.escena(fijado: TiempoFijo(rawValue: almacen.ajustes.tiempoFondo) ?? .real).tono
        let color = cieloSinVelo ? tono.modulo : tono.fondo
        let opacidad = cieloSinVelo ? FondoModulo.opacidadSinVelo : FondoModulo.opacidad
        let r = Diseno.radioModulo
        let forma = UnevenRoundedRectangle(topLeadingRadius: sitio.redondeaArriba ? r : 0, bottomLeadingRadius: sitio.redondeaAbajo ? r : 0,
                                           bottomTrailingRadius: sitio.redondeaAbajo ? r : 0, topTrailingRadius: sitio.redondeaArriba ? r : 0,
                                           style: .continuous)
        ZStack(alignment: .top) {
            forma.fill(FondoModulo.material)
            forma.fill(color.color.opacity(opacidad))
            if raya {
                Rectangle().fill(.white.opacity(0.14)).frame(height: 0.5).padding(.horizontal, Diseno.margenTarjeta)
            }
        }
        .animation(Diseno.muelleLento, value: tono)
        .modifier(ChocaSiArriba(arriba: sitio.redondeaArriba))
    }
}

private struct ChocaSiArriba: ViewModifier {
    var arriba: Bool

    func body(content: Content) -> some View {
        if arriba { content.chocable(.caja(radio: Diseno.radioModulo)) } else { content }
    }
}

func loImportante(_ d: DiaSemana, _ datos: DatosEscolares) -> (simbolo: String, color: Color, nombre: String, libre: Bool) {
    func color(_ t: Tarea) -> Color { datos.asignatura(t.asignaturaID)?.color.color ?? Color.acento }
    if let p = d.pruebas.first {
        return ("moonphase.first.quarter", datos.asignatura(p.asignaturaID)?.color.color ?? Color.ambar, p.tipo.nombre, false)
    }
    if let s = d.repasos.first {
        let a = datos.prueba(deTema: s.temaIDs.first ?? UUID()).flatMap { datos.asignatura($0.asignaturaID) }
        return ("book.fill", a?.color.color ?? Color.ambar, L("Repaso", "Review", "Ripasso"), false)
    }
    if let t = d.examenes.first { return (t.tipo.simbolo, color(t), t.tipo.nombre, false) }
    let entregas = d.atrasadas + d.entregas
    if let t = entregas.first(where: { $0.tipo == .trabajo }) ?? entregas.first { return (t.tipo.simbolo, color(t), t.tipo.nombre, false) }
    if let s = d.ratos.first, let t = datos.tareas.first(where: { $0.id == s.tareaID }) {
        return ("book.fill", color(t), L("Estudio", "Study", "Studio"), false)
    }
    return ("checkmark", .white, L("Libre", "Free", "Libero"), true)
}

struct EstiloFilaCielo: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? .white.opacity(Diseno.resalteElegido) : .clear,
                        in: RoundedRectangle(cornerRadius: Diseno.radioResalte, style: .continuous))
            .animation(configuration.isPressed ? nil : Diseno.muelleRapido, value: configuration.isPressed)
    }
}

struct EstiloPulsar: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(Diseno.muelleRapido, value: configuration.isPressed)
    }
}

struct GraficoSemanaCielo: View {
    var semana: [DiaSemana]
    var datos: DatosEscolares
    var ahora: Date

    var alTocar: (DiaSemana) -> Void = { _ in }

    var alSoltar: (DiaSemana) -> Void = { _ in }

    var alElegir: (DiaSemana) -> Void = { _ in }

    var compacta = false
    @ScaledMetric(relativeTo: .body) private var altoBase: CGFloat = 116
    private var alto: CGFloat { compacta ? altoBase * 0.72 : altoBase }

    @ScaledMetric(relativeTo: .footnote) private var lineaNombre: CGFloat = 18
    @ScaledMetric(relativeTo: .caption2) private var lineaNumero: CGFloat = 13
    @State private var elegido: Int?

    @State private var pildora: Int? = ModoCapturas.activo ? ModoCapturas.valor("-pildora").flatMap(Int.init) : nil

    @State private var arrastre: CGFloat?

    @State private var soltadas = 0
    @State private var agarre: CGFloat = 0
    @State private var origen: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var menosMovimiento

    private var indiceHoy: Int { semana.firstIndex { calendarioActual.isDate($0.dia, inSameDayAs: ahora) } ?? 0 }

    var body: some View {
        let maximo = max(60, semana.map(\.carga).max() ?? 0)
        GeometryReader { geo in
            let ancho = geo.size.width / CGFloat(max(1, semana.count))
            let dia = pildora ?? indiceHoy
            let x = arrastre ?? CGFloat(dia) * ancho
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(semana.enumerated()), id: \.element.id) { i, d in
                    columna(d, maximo: maximo, elegida: elegido == i, enPildora: i == dia)
                        .frame(width: ancho)

                        .accessibilityAction {
                            pildora = i
                            alElegir(d)
                        }
                        .accessibilityAction(named: L("Ver el día", "Show the day", "Mostra il giorno")) { alTocar(d) }
                        .accessibilityAddTraits(i == dia ? .isSelected : [])
                }
            }

            .background(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Diseno.radioLente, style: .continuous)
                    .fill(.white.opacity(Diseno.resalteElegido))
                    .frame(width: ancho - 6, height: geo.size.height)
                    .offset(x: x + 3)
                    .opacity(arrastre == nil ? 1 : 0)
                    .accessibilityHidden(true)
            }

            .overlay(alignment: .topLeading) {
                if arrastre != nil {
                    Color.clear
                        .frame(width: ancho - 6, height: geo.size.height)
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: Diseno.radioLente, style: .continuous))

                        .scaleEffect(menosMovimiento ? 1 : 1.06)
                        .offset(x: x + 3)
                        .transition(.opacity.combined(with: .scale(scale: menosMovimiento ? 1 : 0.94)))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())

            .gesture(ArrastreHorizontal(
                alEmpezar: { p in
                    soltadas += 1
                    let base = CGFloat(dia) * ancho
                    let enPildora = p.x >= base && p.x <= base + ancho
                    agarre = enPildora ? p.x - base : ancho / 2
                    origen = p.x
                    conMuelle(Diseno.muelleRapido) { arrastre = base }
                },
                alMover: { movido in
                    let maximoX = CGFloat(semana.count - 1) * ancho
                    var nueva = origen + movido - agarre
                    if nueva < 0 { nueva = goma(nueva, dimension: ancho) }
                    if nueva > maximoX { nueva = maximoX + goma(nueva - maximoX, dimension: ancho) }
                    arrastre = nueva
                    let i = min(max(Int((nueva / ancho).rounded()), 0), semana.count - 1)
                    if i != dia { pildora = i }
                },
                alSoltar: { movido, velocidad in
                    let actual = arrastre ?? CGFloat(dia) * ancho
                    let destino = min(max(Int(((actual + proyeccion(velocidad)) / ancho).rounded()), 0), semana.count - 1)
                    let objetivo = CGFloat(destino) * ancho

                    let relativa = abs(objetivo - actual) > 0.5 ? velocidad / (objetivo - actual) : 0
                    let muelle: Animation? = menosMovimiento ? nil : .interpolatingSpring(duration: 0.4, bounce: 0.2, initialVelocity: relativa)

                    soltadas += 1
                    let esta = soltadas
                    withAnimation(muelle) {
                        pildora = destino
                        arrastre = objetivo
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(menosMovimiento ? 0 : 300))
                        if soltadas == esta { conMuelle(Diseno.muelleRapido) { arrastre = nil } }
                    }
                    if semana.indices.contains(destino) { alElegir(semana[destino]) }
                }
            ))

            .gesture(MantenerYDeslizar(
                alEmpezar: { p in conMuelle(Diseno.muelleRapido) { elegido = columna(p.x, ancho: ancho) } },
                alMover: { p in
                    let i = columna(p.x, ancho: ancho)
                    if i != elegido { conMuelle(Diseno.muelleRapido) { elegido = i } }
                },
                alAcabar: {
                    if let i = elegido, semana.indices.contains(i) { alSoltar(semana[i]) }
                    conMuelle { elegido = nil }
                }
            ))

            .onTapGesture { p in
                let i = columna(p.x, ancho: ancho)
                guard semana.indices.contains(i) else { return }
                if i == dia {
                    alTocar(semana[i])
                } else {
                    withAnimation(menosMovimiento ? nil : Diseno.muelle) { pildora = i }
                    alElegir(semana[i])
                }
            }
            .overlay {
                let d = elegido.flatMap { semana.indices.contains($0) ? semana[$0] : nil }
                ColocarLente(centro: (CGFloat(elegido ?? 0) + 0.5) * ancho, hueco: 6) {
                    if let d {
                        LenteSemana(dia: d, datos: datos, ahora: ahora)
                            .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .frame(height: alto + 96 + max(0, lineaNombre + lineaNumero - 31))
        .onAppear {

            if ModoCapturas.activo, let i = pildora, semana.indices.contains(i) {
                let d = semana[i]
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(700))
                    alElegir(d)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: elegido)
        .sensoryFeedback(.selection, trigger: pildora)
        .environment(\.colorScheme, .dark)
        .environment(\.sobreCielo, true)
    }

    private func columna(_ x: CGFloat, ancho: CGFloat) -> Int {
        min(max(0, Int(x / max(1, ancho))), semana.count - 1)
    }

    @ViewBuilder
    private func columna(_ d: DiaSemana, maximo: Int, elegida: Bool, enPildora: Bool) -> some View {
        let esHoy = calendarioActual.isDate(d.dia, inSameDayAs: ahora)
        let pasado = d.dia < calendarioActual.startOfDay(for: ahora)

        let apagado = pasado && !elegida ? 0.45 : 1
        VStack(spacing: 6) {

            Luna(parte: d.pruebas.first?.progreso(cal: calendarioActual) ?? 0, tamano: 20)
                .frame(width: 22, height: 22)
                .opacity(d.pruebas.isEmpty ? 0 : apagado)
                .modifier(ChocaSi(activo: !d.pruebas.isEmpty, forma: .circulo))
            VStack(spacing: 2) {
                Spacer(minLength: 0)
                if d.carga == 0 {
                    Capsule().fill(.white.opacity(0.25)).frame(width: 22, height: 4)
                }
                ForEach(Self.segmentos(d, datos), id: \.0) { color, minutos in
                    RoundedRectangle(cornerRadius: Diseno.radioBarra, style: .continuous)
                        .fill(color.color.gradient)
                        .frame(width: 22, height: max(6, alto * CGFloat(minutos) / CGFloat(maximo) - 2))
                        .chocable(.caja(radio: Diseno.radioBarra))
                }
            }
            .frame(height: alto)
            .scaleEffect(elegida ? 1.08 : 1, anchor: .bottom)
            .opacity(apagado)
            Color.clear.frame(height: 6)
            Text(Formato.nombreDia(iso: DatosEscolares.diaISO(d.dia), estilo: .narrow))
                .font(.footnote.weight(.bold))
            Text("\(calendarioActual.component(.day, from: d.dia))")
                .font(.caption2.monospacedDigit())
                .opacity(esHoy || elegida || enPildora ? 1 : 0.86)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)

        .background(elegida ? .white.opacity(Diseno.resalteElegido) : .clear,
                    in: RoundedRectangle(cornerRadius: Diseno.radioLente, style: .continuous))
        .padding(.horizontal, 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(d.resumen(datos))
        .accessibilityAddTraits(.isButton)
    }

    static func segmentos(_ d: DiaSemana, _ datos: DatosEscolares) -> [(ColorHoot, Int)] {
        var por: [ColorHoot: Int] = [:]
        var orden: [ColorHoot] = []
        for s in d.repasos {
            let id = s.pruebaID ?? datos.prueba(deTema: s.temaIDs.first ?? UUID())?.id
            let c = datos.asignatura(datos.pruebas.first { $0.id == id }?.asignaturaID
                                     ?? datos.temasDeAhora.first { s.temaIDs.contains($0.tema.id) }?.asignaturaID)?.color ?? .indigo
            if por[c] == nil { orden.append(c) }
            por[c, default: 0] += s.minutos
        }
        return orden.map { ($0, por[$0] ?? 0) }
    }
}

struct LenteSemana: View {
    var dia: DiaSemana
    var datos: DatosEscolares
    var ahora: Date

    var body: some View {
        let primera = dia.cosas(datos).first
        VStack(alignment: .leading, spacing: 1) {
            Text(dia.titulo(ahora: ahora))
                .font(.subheadline.weight(.semibold))
            Text([dia.carga > 0 ? Formato.duracion(minutos: dia.carga) : L("Libre", "Free", "Libero"), primera?.titulo]
                    .compactMap { $0 }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(EstiloSecundario())
                .lineLimit(1)
        }
        .frame(maxWidth: 240, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: Capsule())
        .allowsHitTesting(false)
    }
}
