import SwiftUI

struct CieloDeTemas: View {
    var grupos: [(asignatura: Asignatura?, temas: [Biblioteca.Entrada])]
    var hayMas: Bool
    var abrir: (UUID) -> Void
    var repasar: (UUID) -> Void
    var borrar: (Biblioteca.Entrada) -> Void
    var verTodos: () -> Void

    static let maximoAsignaturas = 4
    static let maximoTemas = 6

    @ScaledMetric(relativeTo: .caption) private var altoFila: CGFloat = 150
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        if letra.isAccessibilitySize {

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(grupos.enumerated()), id: \.offset) { _, g in
                    FilaDeLunas(asignatura: g.asignatura, temas: g.temas, abrir: abrir, repasar: repasar, borrar: borrar)
                }
                if hayMas {
                    Button(L("Ver todos", "See All", "Vedi tutti"), action: verTodos)
                        .buttonStyle(.glass)
                        .chocable(.capsula, reacciona: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            mapa
        }
    }

    private var mapa: some View {
        let filas = (grupos.count + 1) / 2
        return GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                ForEach(Array(grupos.enumerated()), id: \.offset) { i, g in
                    let centro = Self.centro(i, de: grupos.count, ancho: w, altoFila: altoFila)
                    Constelacion(asignatura: g.asignatura, temas: g.temas, centro: centro, ancho: min(w * 0.40, 168),
                                 abrir: abrir, repasar: repasar, borrar: borrar)
                }
            }
        }
        .frame(height: CGFloat(filas) * altoFila + (hayMas ? 30 : 0))
        .overlay(alignment: .bottomTrailing) {
            if hayMas {
                Button(action: verTodos) {
                    HStack(spacing: 3) {
                        Text(L("Ver todos", "See All", "Vedi tutti"))
                        Image(systemName: "chevron.forward").font(.caption.weight(.bold))
                    }
                    .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .chocable(.capsula, reacciona: true)
            }
        }
        .animation(Diseno.muelle, value: grupos.flatMap(\.temas).map(\.id))
    }

    static func centro(_ i: Int, de n: Int, ancho w: CGFloat, altoFila: CGFloat) -> CGPoint {
        let fila = i / 2
        let sola = n % 2 == 1 && i == n - 1
        let x = sola ? w / 2 : (i % 2 == 0 ? w * 0.26 : w * 0.74)

        let y = CGFloat(fila) * altoFila + altoFila * (i % 2 == 0 ? 0.38 : 0.46)
        return CGPoint(x: x, y: y)
    }
}

private struct Constelacion: View {
    @Environment(Almacen.self) private var almacen
    var asignatura: Asignatura?
    var temas: [Biblioteca.Entrada]
    var centro: CGPoint
    var ancho: CGFloat
    var abrir: (UUID) -> Void
    var repasar: (UUID) -> Void
    var borrar: (Biblioteca.Entrada) -> Void
    @ScaledMetric(relativeTo: .body) private var ladoEscalado: CGFloat = 30
    private var lado: CGFloat { min(ladoEscalado, 38) }

    private static let forma: [CGPoint] = [CGPoint(x: -0.42, y: 0.10), CGPoint(x: -0.12, y: -0.32), CGPoint(x: 0.16, y: 0.16),
                                           CGPoint(x: 0.44, y: -0.20), CGPoint(x: 0.04, y: 0.52), CGPoint(x: -0.36, y: -0.44)]

    var body: some View {

        let n = min(temas.count, Self.forma.count)
        let medio = n > 0 ? Self.forma.prefix(n).map(\.x).reduce(0, +) / CGFloat(n) : 0
        let puntos = temas.prefix(Self.forma.count).indices.map { i in
            CGPoint(x: centro.x + (Self.forma[i].x - medio) * ancho, y: centro.y + (n == 1 ? 0 : Self.forma[i].y * 64))
        }
        let cal = calendarioActual
        ZStack {
            Path { p in
                for (i, q) in puntos.enumerated() { if i == 0 { p.move(to: q) } else { p.addLine(to: q) } }
            }
            .stroke(.white.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
            .accessibilityHidden(true)
            ForEach(Array(temas.prefix(Self.forma.count).enumerated()), id: \.element.id) { i, e in
                Button { abrir(e.id) } label: {
                    Luna(parte: e.tema.luna(cal: cal).fraccion, tamano: lado)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(EstiloPulsar())
                .chocable(.circulo, reacciona: true)
                .contextMenu {
                    if !e.tema.textoLeido.isEmpty {
                        Button { repasar(e.id) } label: { Label(L("Repasar", "Review", "Ripassa"), systemImage: "play.fill") }
                    }
                    Button { abrir(e.id) } label: { Label(L("Ver el tema", "Open Topic", "Apri l'argomento"), systemImage: "book.closed") }
                    Button(role: .destructive) { borrar(e) } label: { Label(L("Borrar", "Delete", "Elimina"), systemImage: "trash") }
                } preview: {
                    VistaPreviaTema(entrada: e, asignatura: asignatura, fondo: TonoCielo.actual(almacen).fondo.color)
                }
                .accessibilityLabel("\(e.tema.nombre), \(asignatura?.nombre ?? "")")
                .accessibilityValue(EstadoLuna.texto(e.tema, cal: cal))
                .position(puntos[i])
                .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
            Label((asignatura?.nombre ?? L("Sin asignatura", "No subject", "Senza materia")).uppercased(with: localeActual),
                  systemImage: asignatura?.simbolo ?? "book.closed.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .fondoModulo(radio: 13)
                .fixedSize()

                .position(x: centro.x, y: (puntos.map(\.y).max() ?? centro.y) + lado / 2 + 24)
                .accessibilityHidden(true)
        }
    }
}

private struct FilaDeLunas: View {
    var asignatura: Asignatura?
    var temas: [Biblioteca.Entrada]
    var abrir: (UUID) -> Void
    var repasar: (UUID) -> Void
    var borrar: (Biblioteca.Entrada) -> Void

    var body: some View {
        let cal = calendarioActual
        VStack(alignment: .leading, spacing: 6) {
            Label((asignatura?.nombre ?? L("Sin asignatura", "No subject", "Senza materia")).uppercased(with: localeActual),
                  systemImage: asignatura?.simbolo ?? "book.closed.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .fondoModulo(radio: 16)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 0) {
                ForEach(temas) { e in
                    Button { abrir(e.id) } label: {
                        Luna(parte: e.tema.luna(cal: cal).fraccion, tamano: 38)
                            .frame(width: 52, height: 52)
                            .contentShape(Circle())
                    }
                    .buttonStyle(EstiloPulsar())
                    .chocable(.circulo, reacciona: true)
                    .contextMenu {
                        if !e.tema.textoLeido.isEmpty {
                            Button { repasar(e.id) } label: { Label(L("Repasar", "Review", "Ripassa"), systemImage: "play.fill") }
                        }
                        Button { abrir(e.id) } label: { Label(L("Ver el tema", "Open Topic", "Apri l'argomento"), systemImage: "book.closed") }
                        Button(role: .destructive) { borrar(e) } label: { Label(L("Borrar", "Delete", "Elimina"), systemImage: "trash") }
                    }
                    .accessibilityLabel("\(e.tema.nombre), \(asignatura?.nombre ?? "")")
                    .accessibilityValue(EstadoLuna.texto(e.tema, cal: cal))
                }
            }
        }
    }
}

private struct VistaPreviaTema: View {
    var entrada: Biblioteca.Entrada
    var asignatura: Asignatura?

    var fondo: Color

    var body: some View {
        let cal = calendarioActual
        VStack(spacing: 10) {
            Luna(parte: entrada.tema.luna(cal: cal).fraccion, tamano: 72)
            Text(entrada.tema.nombre).font(.title3.weight(.bold)).fontDesign(.rounded).foregroundStyle(.white)
            Text([asignatura?.nombre, EstadoLuna.texto(entrada.tema, cal: cal)].compactMap { $0 }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.86))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: 280)
        .background(fondo)
    }
}
