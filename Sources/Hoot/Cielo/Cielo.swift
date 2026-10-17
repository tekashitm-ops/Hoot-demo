import SwiftUI

struct TituloCielo: View {
    var titulo: String
    var simbolo: String

    var accion: (titulo: String, hacer: () -> Void)? = nil

    var enTarjeta = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(titulo.uppercased(with: localeActual), systemImage: simbolo)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
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

struct ModuloTiempo<Accesorio: View, Contenido: View>: View {
    var titulo: String?
    var subtitulo: String?
    @ViewBuilder var accesorio: Accesorio
    @ViewBuilder var contenido: Contenido

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let titulo {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(titulo)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        if let subtitulo, !subtitulo.isEmpty {
                            Text(subtitulo)
                                .font(.footnote)
                                .foregroundStyle(EstiloSecundario())
                        }
                    }
                    Spacer(minLength: 0)
                    accesorio
                }
                .foregroundStyle(.white)
                .padding(.top, 13)
                .padding(.bottom, 11)
            }
            contenido
        }
        .padding(.horizontal, Diseno.margenTarjeta)
        .padding(.bottom, titulo == nil ? 0 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: Diseno.radioModulo, style: .continuous))
        .fondoModulo()
    }
}

extension ModuloTiempo where Accesorio == EmptyView {
    init(titulo: String? = nil, subtitulo: String? = nil, @ViewBuilder contenido: () -> Contenido) {
        self.init(titulo: titulo, subtitulo: subtitulo, accesorio: { EmptyView() }, contenido: contenido)
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
}

func loImportante(_ d: DiaSemana, _ datos: DatosEscolares) -> (simbolo: String, color: Color, nombre: String, libre: Bool) {
    func color(_ t: Tarea) -> Color { datos.asignatura(t.asignaturaID)?.color.color ?? Color.acento }
    if let t = d.examenes.first { return (t.tipo.simbolo, color(t), t.tipo.nombre, false) }
    let entregas = d.atrasadas + d.entregas
    if let t = entregas.first(where: { $0.tipo == .trabajo }) ?? entregas.first { return (t.tipo.simbolo, color(t), t.tipo.nombre, false) }
    if let s = d.ratos.first, let t = datos.tareas.first(where: { $0.id == s.tareaID }) {
        return ("book.fill", color(t), L("Estudio", "Study", "Studio"), false)
    }
    return ("checkmark", .white, L("Libre", "Free", "Libero"), true)
}

struct BarraFranja: View {

    var desde: Double
    var hasta: Double

    var carga: Double

    var ahora: Double?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x0 = w * min(max(desde, 0), 1)
            let x1 = max(w * min(max(hasta, 0), 1), x0 + 6)
            ZStack(alignment: .leading) {

                Capsule().fill(.black.opacity(0.16))
                Capsule()
                    .fill(LinearGradient(colors: Self.colores(hasta: carga), startPoint: .leading, endPoint: .trailing))
                    .frame(width: x1 - x0)
                    .offset(x: x0)
                if let ahora {

                    Circle().fill(.white)
                        .frame(width: 6, height: 6)
                        .padding(2.5)
                        .background(Circle().fill(.black.opacity(0.3)))
                        .offset(x: min(max(w * ahora, x0), x1) - 5.5)
                }
            }
            .frame(height: 5)
            .frame(maxHeight: .infinity)
        }
        .frame(height: 11)
        .accessibilityHidden(true)
    }

    static func colores(hasta carga: Double) -> [Color] {
        let escala: [(r: Double, g: Double, b: Double)] = [(0.45, 0.9, 0.8), (1, 0.84, 0.35), (1, 0.6, 0.27), (1, 0.38, 0.36)]
        func color(_ t: Double) -> Color {
            let x = min(max(t, 0), 1) * Double(escala.count - 1)
            let i = min(Int(x), escala.count - 2)
            let f = x - Double(i)
            let a = escala[i], b = escala[i + 1]
            return Color(red: a.r + (b.r - a.r) * f, green: a.g + (b.g - a.g) * f, blue: a.b + (b.b - a.b) * f)
        }
        let c = min(max(carga, 0), 1)
        return c == 0 ? [color(0), color(0)] : (0...4).map { color(c * Double($0) / 4) }
    }
}

struct MomentoHora: Identifiable {
    var id: String
    var hora: String
    var simbolo: String
    var color: ColorHoot
    var abajo: String

    var propuesta: Bool
    var ahora: Bool

    var nombre: String = ""

    var accion: AccionMomento? = nil

    var minutos = 0
}

enum AccionMomento {

    case clase(Clase)

    case tarea(UUID)
    case actividad(Actividad)

    case mochila

    case dia(Date)
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

struct TiraHoras: View {
    var momentos: [MomentoHora]
    var alTocar: (AccionMomento) -> Void = { _ in }
    @ScaledMetric(relativeTo: .headline) private var ladoIcono: CGFloat = 32
    @ScaledMetric(relativeTo: .headline) private var hueco: CGFloat = 19

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(momentos) { mo in
                    Button { if let a = mo.accion { alTocar(a) } } label: { momento(mo) }
                        .buttonStyle(EstiloPulsar())
                        .disabled(mo.accion == nil)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel([mo.nombre, mo.hora, mo.abajo].filter { !$0.isEmpty }.joined(separator: ", "))
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func momento(_ mo: MomentoHora) -> some View {
        VStack(spacing: hueco) {
            Text(mo.hora)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
            ZStack {
                if mo.propuesta {
                    Circle().fill(mo.color.color.opacity(0.22))
                    Circle().strokeBorder(.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5]))
                } else {
                    Circle().fill(mo.color.color.gradient)
                }
                Image(systemName: mo.simbolo)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: ladoIcono, height: ladoIcono)
            .chocable(.circulo)
            Text(mo.abajo.isEmpty ? " " : mo.abajo)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .frame(minWidth: 46)
        .fixedSize()
        .contentShape(Rectangle())
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
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Diseno.radioLente, style: .continuous))

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
            Image(systemName: "bolt.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.rayoExamen, in: Circle())
                .opacity(d.examenes.isEmpty ? 0 : apagado)
                .modifier(ChocaSi(activo: !d.examenes.isEmpty, forma: .circulo))
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
            HStack(spacing: 3) {
                ForEach(0..<min(d.entregas.count, 3), id: \.self) { _ in
                    Circle().fill(.white).frame(width: 5, height: 5)
                }
            }
            .frame(height: 6)
            .opacity(apagado)
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
        for s in d.ratos {
            let c = datos.asignatura(datos.tareas.first { $0.id == s.tareaID }?.asignaturaID)?.color ?? .indigo
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
