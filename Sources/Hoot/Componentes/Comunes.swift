import SwiftUI

struct IconoAjustes: View {
    var simbolo: String
    var color: ColorHoot
    @ScaledMetric(relativeTo: .body) private var lado = Diseno.iconoAjustes

    var body: some View {
        let l = min(lado, Diseno.iconoAjustes * 1.5)
        Image(systemName: simbolo)
            .font(.system(size: l * 0.55, weight: .semibold))
            .foregroundStyle(color.sobre)
            .frame(width: l, height: l)
            .background(color.color.gradient, in: RoundedRectangle(cornerRadius: Diseno.radioIconoAjustes * l / Diseno.iconoAjustes, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct IconoAsignatura: View {
    var asignatura: Asignatura?
    var lado: CGFloat

    var body: some View {
        let color = asignatura?.color ?? .gris
        Image(systemName: asignatura?.simbolo ?? "tray.fill")
            .font(.system(size: lado * 0.46, weight: .semibold))
            .foregroundStyle(color.sobre)
            .frame(width: lado, height: lado)
            .background(color.color.gradient, in: Circle())
            .accessibilityHidden(true)
    }
}

struct Anillo: View {
    var progreso: Double
    var color: Color
    var grosor: CGFloat
    @State private var mostrado: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: grosor)
            Circle()
                .trim(from: 0, to: max(0.0001, mostrado))
                .stroke(color, style: StrokeStyle(lineWidth: grosor, lineCap: .round))
                .rotationEffect(.degrees(-90))

                .opacity(mostrado > 0.004 ? 1 : 0)
        }
        .padding(grosor / 2)
        .onAppear {
            if reducirMovimiento {
                mostrado = progreso
            } else {
                withAnimation(Diseno.muelleAnillo.delay(0.15)) { mostrado = progreso }
            }
        }
        .onChange(of: progreso) { _, nuevo in
            if reducirMovimiento { mostrado = nuevo } else { withAnimation(Diseno.muelleLento) { mostrado = nuevo } }
        }
        .accessibilityHidden(true)
    }
}

struct Visto: Shape {
    var progreso: CGFloat

    var animatableData: CGFloat {
        get { progreso }
        set { progreso = newValue }
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.22, y: r.minY + r.height * 0.53))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.42, y: r.minY + r.height * 0.72))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.78, y: r.minY + r.height * 0.32))
        return p.trimmedPath(from: 0, to: progreso)
    }
}

struct Casilla: View {
    var marcada: Bool
    var color: ColorHoot
    var etiqueta: String
    var accion: () -> Void
    @ScaledMetric(relativeTo: .body) private var lado = Diseno.casilla

    var body: some View {
        Button(action: accion) {
            ZStack {
                Circle()
                    .strokeBorder(marcada ? AnyShapeStyle(color.color) : AnyShapeStyle(EstiloSecundario().opacity(0.7)), lineWidth: 2)
                Circle()
                    .fill(color.color)
                    .scaleEffect(marcada ? 1 : 0.001)
                Visto(progreso: marcada ? 1 : 0)
                    .stroke(color.sobre, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            }
            .frame(width: lado, height: lado)
            .zonaTactil()
        }
        .buttonStyle(.borderless)
        .animando(Diseno.muelleRebote, valor: marcada)
        .sensoryFeedback(trigger: marcada) { _, nueva in nueva ? .success : .selection }
        .accessibilityLabel(etiqueta)
        .accessibilityValue(marcada ? L("Hecho", "Done", "Fatto") : L("Pendiente", "To do", "Da fare"))
        .accessibilityAddTraits(.isButton)
    }
}

struct EncabezadoSeccion: View {
    var titulo: String
    var accion: (titulo: String, hacer: () -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titulo)
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Diseno.hueco)
            if let accion {
                Button(accion.titulo, action: accion.hacer)
                    .buttonStyle(.borderless)
                    .font(.body)
                    .foregroundStyle(Color.acento)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .padding(.vertical, -10)
            }
        }
        .padding(.top, Diseno.huecoSeccion)
        .padding(.bottom, Diseno.huecoTitulo)
    }
}

struct EstadoVacio: View {
    var texto: String
    var gesto: GestoLobo = .dormido
    var accion: (titulo: String, hacer: () -> Void)?
    @ScaledMetric(relativeTo: .largeTitle) private var lado = 84

    var body: some View {
        VStack(spacing: Diseno.hueco) {
            LoboInteractivo(tamano: lado, gesto: gesto)
                .accessibilityHidden(true)
            Text(texto)
                .font(.body)
                .textoSecundario()
                .multilineTextAlignment(.center)
            if let accion {
                Button(accion.titulo, action: accion.hacer)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .padding(.top, Diseno.huecoPequeno)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Diseno.huecoSeccion)
    }
}

struct Vence: View {
    var fecha: Date
    var hecha: Bool = false

    var body: some View {
        let (texto, color, simbolo) = Vence.estilo(fecha, hecha: hecha)
        let aviso = color == .urgente || color == .pronto
        Label(texto, systemImage: simbolo)
            .labelStyle(.titleAndIcon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(aviso ? AnyShapeStyle(EstiloAviso(color: color)) : AnyShapeStyle(color))
            .lineLimit(1)
            .accessibilityLabel(simbolo == "exclamationmark.circle.fill" ? L("Atrasada", "Late", "In ritardo") + ", " + texto : texto)
    }

    static func estilo(_ fecha: Date, hecha: Bool) -> (String, Color, String) {
        let cal = calendarioActual
        let ahora = Reloj.ahora
        if hecha { return (Formato.diaRelativo(fecha), .hecho, "checkmark") }
        let dias = cal.dateComponents([.day], from: cal.startOfDay(for: ahora), to: cal.startOfDay(for: fecha)).day ?? 0

        if dias == 0 && fecha < ahora {
            return (L("Hoy, \(Formato.hora(DatosEscolares.minutos(fecha)))", "Today, \(Formato.hora(DatosEscolares.minutos(fecha)))",
                      "Oggi, \(Formato.hora(DatosEscolares.minutos(fecha)))"), .urgente, "exclamationmark.circle.fill")
        }
        if dias == -1 { return (L("Ayer", "Yesterday", "Ieri"), .urgente, "exclamationmark.circle.fill") }
        if dias < -1 { return (L("Hace \(-dias) días", "\(-dias) days ago", "\(-dias) giorni fa"), .urgente, "exclamationmark.circle.fill") }
        if dias == 0 { return (L("Hoy", "Today", "Oggi"), .urgente, "clock.fill") }
        if dias == 1 { return (L("Mañana", "Tomorrow", "Domani"), .pronto, "clock") }
        return (Formato.diaRelativo(fecha), .texto2, "calendar")
    }
}

struct EstiloAviso: ShapeStyle {
    var color: Color

    func resolve(in entorno: EnvironmentValues) -> Color {
        entorno.sobreCielo ? Color.avisoCielo : color
    }
}

struct FilaAjuste: View {
    var simbolo: String
    var color: ColorHoot
    var titulo: String
    var valor: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            IconoAjustes(simbolo: simbolo, color: color)
            Text(titulo)
                .foregroundStyle(Color.primary)
            Spacer(minLength: Diseno.hueco)
            if let valor {
                Text(valor)
                    .textoSecundario()
                    .lineLimit(1)
            }
        }
    }
}

struct SelectorDias: View {
    @Binding var seleccion: Set<Int>
    var color: ColorHoot = .indigo

    var minimo = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DatosEscolares.ordenSemana, id: \.self) { d in
                let on = seleccion.contains(d)
                Button {
                    conMuelle(Diseno.muelleRapido) {
                        if on {
                            if seleccion.count > minimo { seleccion.remove(d) }
                        } else {
                            seleccion.insert(d)
                        }
                    }
                } label: {
                    Text(Formato.nombreDia(iso: d, estilo: .narrow))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(on ? color.sobre : Color.primary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(on ? AnyShapeStyle(color.color) : AnyShapeStyle(Color.relleno), in: Circle())
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Formato.nombreDia(iso: d, estilo: .wide))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: seleccion)
    }
}
