import SwiftUI

struct TramoCinta: Identifiable, Hashable {
    enum Tipo: Hashable { case clase, actividad, rato }
    var id: String
    var tipo: Tipo
    var inicio: Int
    var fin: Int
    var color: ColorHoot
    var simbolo: String
    var titulo: String

    var horas: String { "\(Formato.hora(inicio))–\(Formato.hora(fin))" }
}

extension DatosEscolares {

    func tramosClases(_ dia: Date) -> [TramoCinta] {
        clases(en: dia).map { c in
            let a = asignatura(c.asignaturaID)
            return TramoCinta(id: "c\(c.id)", tipo: .clase, inicio: c.inicio, fin: c.fin, color: a?.color ?? .gris,
                              simbolo: a?.simbolo ?? "book.closed", titulo: a?.nombre ?? "")
        }
    }

    func tramos(_ dia: Date, ratos: [Sesion]) -> [TramoCinta] {
        var r = tramosClases(dia)
        for a in actividades(en: dia) {
            guard let i = a.inicio else { continue }
            r.append(TramoCinta(id: "a\(a.id)", tipo: .actividad, inicio: i, fin: a.fin ?? i + 60, color: a.color,
                                simbolo: a.simbolo, titulo: a.titulo))
        }
        for s in ratos {
            guard let t = tareas.first(where: { $0.id == s.tareaID }) else { continue }
            let a = asignatura(t.asignaturaID)
            r.append(TramoCinta(id: "s\(s.id)", tipo: .rato, inicio: s.hora, fin: s.hora + s.minutos, color: a?.color ?? .indigo,
                                simbolo: t.tipo.simbolo, titulo: t.tituloRato(a)))
        }
        return r.sorted { $0.inicio < $1.inicio }
    }
}

extension Tarea {

    func tituloRato(_ asignatura: Asignatura?) -> String {
        guard tipo == .examen else { return titulo }
        let a = asignatura?.nombre ?? titulo
        return L("Estudiar \(a)", "Study \(a)", "Studiare \(a)")
    }
}

struct CintaDia: View {
    var tramos: [TramoCinta]

    var desde: Int
    var hasta: Int
    var dia: Date
    var ahora: Date

    var conHoras = false

    @State private var seleccion: String?
    @State private var tareaOcultar: Task<Void, Never>?
    @GestureState private var manteniendo = false
    @ScaledMetric(relativeTo: .body) private var alto: CGFloat = 32
    @Environment(\.colorScheme) private var esquema

    private var total: CGFloat { CGFloat(max(1, hasta - desde)) }

    var body: some View {
        let h = min(alto, 48)
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let ancho = geo.size.width
                ZStack(alignment: .topLeading) {

                    RoundedRectangle(cornerRadius: Diseno.radioTramo, style: .continuous)
                        .fill(Color.primary.opacity(esquema == .dark ? 0.08 : 0.05))
                        .frame(width: ancho, height: h)
                    ForEach(tramos) { t in
                        bloque(t, ancho: ancho, h: h)
                    }
                    aguja(ancho: ancho, h: h)
                }
                .frame(width: ancho, height: h, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { punto in

                    elegir(tramo(en: punto.x, ancho: ancho)?.id)
                    tareaOcultar?.cancel()
                    tareaOcultar = Task {
                        try? await Task.sleep(for: .seconds(1.8))
                        guard !Task.isCancelled else { return }
                        conMuelle { seleccion = nil }
                    }
                }
                .gesture(
                    LongPressGesture(minimumDuration: 0.25)
                        .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                        .updating($manteniendo) { _, estado, _ in estado = true }
                        .onChanged { valor in
                            tareaOcultar?.cancel()
                            if case .second(true, let arrastre?) = valor {
                                elegir(tramo(en: arrastre.location.x, ancho: ancho)?.id)
                            } else if case .second(true, nil) = valor, seleccion == nil {
                                elegir(tramos.first?.id)
                            }
                        }
                        .onEnded { _ in conMuelle { seleccion = nil } }
                )
                .onChange(of: manteniendo) { _, sigue in
                    if !sigue { conMuelle { seleccion = nil } }
                }

                .overlay {
                    let elegido = tramos.first { $0.id == seleccion }
                    ColocarLente(centro: elegido.map { (x($0.inicio, ancho) + x($0.fin, ancho)) / 2 } ?? 0) {
                        if let elegido {
                            LenteCinta(tramo: elegido)
                                .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
                        }
                    }
                }
            }
            .frame(height: h)
            .zIndex(1)
            if conHoras {
                horas
            }
        }
        .sensoryFeedback(.selection, trigger: seleccion)
        .onAppear {
            if seleccion == nil, let m = ModoCapturas.minutos("-cinta") {
                seleccion = tramos.min { distancia($0, m) < distancia($1, m) }?.id
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("El día", "The day", "La giornata"))
        .accessibilityValue(tramos.map { "\($0.titulo), \($0.horas)" }.joined(separator: "; "))
    }

    private func x(_ minuto: Int, _ ancho: CGFloat) -> CGFloat {
        CGFloat(minuto - desde) / total * ancho
    }

    private func distancia(_ t: TramoCinta, _ m: Int) -> Int {
        m < t.inicio ? t.inicio - m : (m > t.fin ? m - t.fin : 0)
    }

    private func tramo(en x: CGFloat, ancho: CGFloat) -> TramoCinta? {
        let m = desde + Int(max(0, min(ancho, x)) / ancho * total)
        return tramos.min { a, b in
            let da = distancia(a, m), db = distancia(b, m)

            return da != db ? da < db : (a.tipo == .actividad && b.tipo != .actividad)
        }
    }

    private func elegir(_ id: String?) {
        guard id != seleccion else { return }
        conMuelle(Diseno.muelleRapido) { seleccion = id }
    }

    @ViewBuilder
    private func bloque(_ t: TramoCinta, ancho: CGFloat, h: CGFloat) -> some View {
        let x0 = x(t.inicio, ancho) + 1
        let w = max(3, x(t.fin, ancho) - x(t.inicio, ancho) - 2)
        let esHoy = calendarioActual.isDate(dia, inSameDayAs: ahora)
        let pasado = esHoy && DatosEscolares.minutos(ahora) >= t.fin
        let elegido = seleccion == t.id
        let forma = RoundedRectangle(cornerRadius: min(Diseno.radioTramo, w / 2), style: .continuous)
        let tinte = esquema == .dark ? 0.32 : 0.2
        ZStack {
            if t.tipo == .rato {
                forma.fill(t.color.color.opacity(elegido ? tinte : tinte * 0.4))
                forma.strokeBorder(t.color.color, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5]))
            } else {
                forma.fill(t.color.color.opacity(elegido ? tinte * 2 : tinte))
            }
            if w >= 18 {
                Image(systemName: t.simbolo)
                    .font(.system(size: min(h * 0.42, w * 0.62), weight: .semibold))
                    .foregroundStyle(t.color.color)
            }
        }
        .frame(width: w, height: h)
        .opacity(pasado && !elegido ? 0.6 : 1)
        .scaleEffect(y: elegido ? 1.1 : 1, anchor: .bottom)
        .offset(x: x0)
        .animando(Diseno.muelleRapido, valor: elegido)
    }

    @ViewBuilder
    private func aguja(ancho: CGFloat, h: CGFloat) -> some View {
        let m = DatosEscolares.minutos(ahora)
        if calendarioActual.isDate(dia, inSameDayAs: ahora), m >= desde, m <= hasta {
            Capsule()
                .fill(Color.primary)
                .frame(width: 3, height: h + 10)
                .overlay(Capsule().stroke(Color.fondo, lineWidth: 1.5))
                .offset(x: x(m, ancho) - 1.5, y: -5)
                .accessibilityHidden(true)
        }
    }

    private var horas: some View {
        GeometryReader { geo in
            let ancho = geo.size.width
            ZStack(alignment: .topLeading) {
                ForEach(Array(stride(from: 0, to: 24 * 60, by: 240)).filter { $0 >= desde && $0 <= hasta }, id: \.self) { m in
                    let cx = x(m, ancho)
                    Text(Formato.hora(m))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color.texto2)
                        .dynamicTypeSize(...DynamicTypeSize.xLarge)
                        .fixedSize()
                        .alignmentGuide(.leading) { d in d.width / 2 - min(max(cx, d.width / 2), ancho - d.width / 2) }
                }
            }
            .frame(width: ancho, alignment: .topLeading)
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }
}

struct ColocarLente: Layout {
    var centro: CGFloat
    var hueco: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for vista in subviews {
            let t = vista.sizeThatFits(.unspecified)
            let x = min(max(centro - t.width / 2, 0), max(0, bounds.width - t.width))
            vista.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY - hueco - t.height), anchor: .topLeading, proposal: ProposedViewSize(t))
        }
    }
}

struct LenteCinta: View {
    var tramo: TramoCinta

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: tramo.simbolo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tramo.color.color)
            VStack(alignment: .leading, spacing: 0) {
                Text(tramo.titulo)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(tramo.horas)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.texto2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: Capsule())
        .allowsHitTesting(false)
    }
}
