import SwiftUI

struct RutaTarea: Hashable {
    let id: UUID
}

struct InicioVista: View {
    var body: some View {
        HoyLunas()
    }
}

struct Cielo: View {
    @Environment(\.colorScheme) private var esquema

    var body: some View {
        TimelineView(.everyMinute) { contexto in
            let h = calendarioActual.component(.hour, from: Reloj.desde(contexto.date))
            let oscuro = esquema == .dark
            let color: Color = switch h {
            case 6..<11: Color(uiColor: oscuro ? .systemBlue : .systemYellow)
            case 11..<17: Color(uiColor: .systemTeal)
            case 17..<21: Color(uiColor: oscuro ? .systemPurple : .systemOrange)
            default: Color(uiColor: .systemIndigo)
            }
            LinearGradient(
                colors: [color.opacity(esquema == .dark ? 0.32 : 0.28), color.opacity(0)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 420)
            .ignoresSafeArea(edges: .top)
            .animation(Diseno.muelleLento, value: h)
        }
        .accessibilityHidden(true)
    }
}

struct SeccionClases: View {
    var datos: DatosEscolares
    var alPonerHorario: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var tamanoLetra

    var body: some View {
        TimelineView(.everyMinute) { contexto in
            let ahora = Reloj.desde(contexto.date)
            let hoy = datos.clases(en: ahora)
            let terminadas = hoy.last.map { DatosEscolares.minutos(ahora) >= $0.fin } ?? true
            let dia = (!hoy.isEmpty && !terminadas) ? ahora : (datos.siguienteDiaConClase(despuesDe: ahora) ?? ahora)
            let esHoy = calendarioActual.isDate(dia, inSameDayAs: ahora)

            VStack(alignment: .leading, spacing: 0) {
                EncabezadoSeccion(titulo: esHoy
                                  ? L("Clases", "Classes", "Lezioni")
                                  : L("Clases · \(Formato.diaRelativo(dia, desde: ahora))", "Classes · \(Formato.diaRelativo(dia, desde: ahora))", "Lezioni · \(Formato.diaRelativo(dia, desde: ahora))"))
                if datos.horario.isEmpty {
                    VStack(alignment: .leading, spacing: Diseno.hueco) {
                        Text(L("Pon tu horario para ver aquí tus clases.", "Add your timetable to see your classes here.", "Aggiungi il tuo orario per vedere qui le lezioni."))
                            .textoSecundario()
                        if let alPonerHorario {
                            Button(L("Poner el horario", "Add timetable", "Aggiungi l'orario"), systemImage: "calendar.badge.plus", action: alPonerHorario)
                                .buttonStyle(.bordered)
                        }
                    }
                } else {
                    let clases = datos.clases(en: dia)
                    CintaDia(tramos: datos.tramosClases(dia), desde: clases.first?.inicio ?? 8 * 60,
                             hasta: clases.last?.fin ?? 15 * 60, dia: dia, ahora: ahora)
                        .padding(.top, 4)
                    claseDestacada(dia: dia, ahora: ahora, esHoy: esHoy)
                        .padding(.top, 14)
                }
            }
        }
    }

    @ViewBuilder
    private func claseDestacada(dia: Date, ahora: Date, esHoy: Bool) -> some View {
        let (actual, siguiente) = esHoy ? datos.claseAhora(ahora) : (nil, datos.clases(en: dia).first)
        if let c = actual ?? siguiente, let a = datos.asignatura(c.asignaturaID) {
            let disposicion = tamanoLetra.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
            disposicion {
                IconoAsignatura(asignatura: a, lado: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(actual != nil ? L("Ahora", "Now", "Ora") : (esHoy ? L("Siguiente", "Next", "Prossima") : L("Primera clase", "First class", "Prima lezione")))
                        .font(.subheadline)
                        .textoSecundario()
                    Text(a.nombre)
                        .font(.headline)
                        .lineLimit(1)
                }
                if !tamanoLetra.isAccessibilitySize { Spacer(minLength: 8) }
                VStack(alignment: tamanoLetra.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                    Text("\(Formato.hora(c.inicio))–\(Formato.hora(c.fin))")
                        .font(.subheadline.monospacedDigit())
                    if actual != nil {
                        let quedan = c.fin - DatosEscolares.minutos(ahora)
                        Text(L("quedan \(quedan) min", "\(quedan) min left", "mancano \(quedan) min"))
                            .font(.subheadline.monospacedDigit())
                            .textoSecundario()
                            .contentTransition(.numericText(countsDown: true))
                    } else if !(c.aula.isEmpty ? a.aula : c.aula).isEmpty {
                        Text(L("Aula \(c.aula.isEmpty ? a.aula : c.aula)", "Room \(c.aula.isEmpty ? a.aula : c.aula)", "Aula \(c.aula.isEmpty ? a.aula : c.aula)"))
                            .font(.subheadline)
                            .textoSecundario()
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

struct MochilaLlena: View {
    var progreso: Double
    var color: Color = .acento
    var lado: CGFloat

    var body: some View {
        ZStack {
            Image(systemName: "backpack.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(color.opacity(0.22))
            Image(systemName: "backpack.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)
                .mask(alignment: .bottom) {
                    Rectangle()
                        .frame(height: lado * max(0, min(1, progreso)))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
        }
        .frame(width: lado, height: lado)
        .animation(Diseno.muelle, value: progreso)
        .accessibilityHidden(true)
    }
}

struct SeccionMochila: View {
    var datos: DatosEscolares
    var soloLectura: Bool
    var alAbrir: (() -> Void)?

    var body: some View {
        if let dia = datos.diaMochila() {
            let items = datos.itemsMochila(para: dia)
            let metidas = items.filter { datos.marcadas(dia).contains($0.id) }.count
            if !items.isEmpty {
                let lista = metidas == items.count
                VStack(alignment: .leading, spacing: 0) {
                    EncabezadoSeccion(titulo: L("Mochila · \(Formato.diaRelativo(dia))", "Backpack · \(Formato.diaRelativo(dia))", "Zaino · \(Formato.diaRelativo(dia))"))
                    HStack(spacing: 14) {
                        MochilaLlena(progreso: Double(metidas) / Double(items.count), color: lista ? .hecho : .acento, lado: 44)
                        Text(lista ? L("Lista", "Packed", "Pronto") : L("\(metidas) de \(items.count)", "\(metidas) of \(items.count)", "\(metidas) di \(items.count)"))
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .contentTransition(.numericText())
                        Spacer(minLength: 8)
                        if !soloLectura, !lista, let alAbrir {
                            Button(L("Preparar", "Pack", "Prepara"), action: alAbrir)
                                .buttonStyle(.borderedProminent)
                                .tint(Color.acentoRelleno)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

struct FilaRecordatorio: View {
    var recordatorio: Recordatorio
    var soloLectura = false

    var conDia = true

    var horaDerecha = false
    var alAlternar: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        let derecha = horaDerecha && recordatorio.conHora && !letra.isAccessibilitySize
        HStack(spacing: 12) {
            if soloLectura {
                Image(systemName: recordatorio.hecho ? "checkmark.circle.fill" : "bell.fill")
                    .foregroundStyle(recordatorio.hecho ? Color.hecho : ColorHoot.naranja.color)
                    .frame(width: 44, height: 44)
            } else {
                Casilla(marcada: recordatorio.hecho, color: .naranja, etiqueta: recordatorio.titulo, accion: alAlternar)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(recordatorio.titulo)
                    .foregroundStyle(recordatorio.hecho ? AnyShapeStyle(EstiloSecundario()) : AnyShapeStyle(Color.primary))
                    .strikethrough(recordatorio.hecho)
                    .lineLimit(2)
                let detalle = [
                    conDia ? Formato.diaRelativo(recordatorio.fecha) : nil,
                    recordatorio.conHora && !derecha ? Formato.hora(recordatorio.fecha) : nil,
                    recordatorio.origen == .familia ? L("de tu familia", "from your family", "dalla tua famiglia") : nil,
                ].compactMap { $0 }.joined(separator: " · ")
                if !detalle.isEmpty {
                    Text(detalle)
                        .font(.subheadline)
                        .textoSecundario()
                }
            }
            Spacer(minLength: derecha ? 8 : 0)
            if derecha {
                Text(Formato.hora(recordatorio.fecha))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
        }
    }
}

struct HojaHorario: View {
    @Environment(Almacen.self) private var almacen

    var editando = true

    var body: some View {
        NavigationStack {
            if almacen.datos.asignaturas.isEmpty {
                ContentUnavailableView(
                    L("Primero, tus asignaturas", "First, your subjects", "Prima, le tue materie"),
                    systemImage: "books.vertical",
                    description: Text(L("Añádelas en Cuenta > Asignaturas.", "Add them in Account > Subjects.", "Aggiungile in Account > Materie."))
                )
                .toolbar { ToolbarItem(placement: .topBarLeading) { BotonCerrarHoja() } }
            } else {
                HorarioCielo(enHoja: true, editando: editando || almacen.datos.horario.isEmpty)
            }
        }
    }
}

private struct BotonCerrarHoja: View {
    @Environment(\.dismiss) private var cerrar
    var body: some View { BotonCerrar { cerrar() } }
}
