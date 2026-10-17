import SwiftUI
import Charts

struct RutaNotas: Hashable {
    let id: UUID
}

struct NotasLista: View {
    @Environment(Almacen.self) private var almacen
    var datosFamilia: DatosEscolares?
    @ScaledMetric(relativeTo: .largeTitle) private var ladoAnillo: CGFloat = 128

    private var datos: DatosEscolares { datosFamilia ?? almacen.datos }

    var body: some View {
        let escala = almacen.ajustes.escala
        let conNotas = datos.asignaturas.filter { datos.media(de: $0.id) != nil }
        if let media = datos.mediaGeneral {
            Section {
                HStack(spacing: 20) {
                    ZStack {
                        Anillo(progreso: escala.proporcion(media), color: Color.acento, grosor: 12)
                        VStack(spacing: 0) {
                            Text(Formato.numero(media, decimales: 1))
                                .font(.largeTitle.bold().monospacedDigit())
                                .fontDesign(.rounded)
                                .contentTransition(.numericText())
                            Text(L("media", "average", "media"))
                                .font(.caption.weight(.semibold))
                                .textoSecundario()
                        }
                        .minimumScaleFactor(0.5)
                        .padding(16)
                    }
                    .frame(width: min(ladoAnillo, 180), height: min(ladoAnillo, 180))
                    VStack(alignment: .leading, spacing: 8) {
                        let aprobadas = conNotas.filter { datos.media(de: $0.id).map(escala.aprueba) ?? false }.count
                        Label(L("\(aprobadas) de \(conNotas.count) aprobadas", "\(aprobadas) of \(conNotas.count) passing", "\(aprobadas) di \(conNotas.count) sufficienti"),
                              systemImage: aprobadas == conNotas.count ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(aprobadas == conNotas.count ? Color.hecho : Color.pronto)
                        if let mejor = conNotas.max(by: { escala.proporcion(datos.media(de: $0.id) ?? 0) < escala.proporcion(datos.media(de: $1.id) ?? 0) }) {
                            Label(mejor.nombre, systemImage: "star.fill")
                                .font(.subheadline)
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)
                        }
                        Text(L("Sobre \(Formato.numero(escala.maximo, decimales: 0))", "Out of \(Formato.numero(escala.maximo, decimales: 0))", "Su \(Formato.numero(escala.maximo, decimales: 0))"))
                            .font(.subheadline)
                            .textoSecundario()
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(L("Media \(Formato.numero(media))", "Average \(Formato.numero(media))", "Media \(Formato.numero(media))"))
            }
            .listRowSeparator(.hidden)

            Section {
                ForEach(conNotas) { a in
                    NavigationLink(value: RutaNotas(id: a.id)) {
                        FilaMedia(asignatura: a, media: datos.media(de: a.id) ?? 0, cuantas: datos.notas(de: a.id).count, escala: escala)
                    }
                }
            } header: {
                Text(L("Por asignatura", "By subject", "Per materia"))
                    .font(.headline)
                    .foregroundStyle(Color.primary)
            }
        } else {
            Section {
                EstadoVacio(texto: L("Aún no hay notas.", "No grades yet.", "Ancora nessun voto."), gesto: .normal)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
    }
}

struct FilaMedia: View {
    var asignatura: Asignatura
    var media: Double
    var cuantas: Int
    var escala: EscalaNotas
    @State private var mostrada: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        HStack(spacing: 12) {
            IconoAjustes(simbolo: asignatura.simbolo, color: asignatura.color)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(asignatura.nombre).lineLimit(1)
                    Spacer()
                    NotaValor(valor: media, aprueba: escala.aprueba(media), fuente: .body.weight(.semibold))
                }
                ZStack(alignment: .leading) {
                    Capsule().fill(asignatura.color.color.opacity(0.18))

                    Capsule().fill(asignatura.color.color.gradient)
                        .scaleEffect(x: max(0.02, mostrada), anchor: .leading)
                }
                .frame(height: 6)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            let p = escala.proporcion(media)
            if reducirMovimiento { mostrada = p } else { withAnimation(Diseno.muelleLento.delay(0.1)) { mostrada = p } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(asignatura.nombre)
        .accessibilityValue(L("Media \(Formato.numero(media)), \(cuantas) notas", "Average \(Formato.numero(media)), \(cuantas) grades", "Media \(Formato.numero(media)), \(cuantas) voti"))
    }
}

struct NotasAsignatura: View {
    var asignaturaID: UUID
    var datosFamilia: DatosEscolares?

    @Environment(Almacen.self) private var almacen
    @State private var seleccion: Nota?
    @State private var editando: Nota?
    @State private var borrando: Nota?

    private var datos: DatosEscolares { datosFamilia ?? almacen.datos }

    var body: some View {
        let escala = almacen.ajustes.escala
        let a = datos.asignatura(asignaturaID)
        let notas = datos.notas(de: asignaturaID)
        let color = a?.color ?? .indigo
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        IconoAsignatura(asignatura: a, lado: 44)
                        VStack(alignment: .leading) {
                            Text(L("Media", "Average", "Media")).font(.subheadline).textoSecundario()
                            Text(datos.media(de: asignaturaID).map { Formato.numero($0) } ?? "–")
                                .font(.largeTitle.bold().monospacedDigit())
                                .fontDesign(.rounded)
                        }
                    }
                    if notas.count >= 2 {
                        grafica(notas, escala: escala, color: color)
                            .frame(height: 200)
                            .padding(.top, 50)
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowSeparator(.hidden)

            Section {
                ForEach(notas.reversed()) { n in
                    Button {
                        if datosFamilia == nil { editando = n }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(n.titulo).foregroundStyle(Color.primary)
                                Text([n.tipo.nombre, Formato.diaCorto(n.fecha), n.peso != 1 ? "×\(Formato.numero(n.peso))" : nil].compactMap { $0 }.joined(separator: " · "))
                                    .font(.subheadline)
                                    .textoSecundario()
                            }
                            Spacer()
                            NotaValor(valor: n.valor, aprueba: escala.aprueba(n.valor), fuente: .title3.weight(.semibold), decimales: 2)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        if datosFamilia == nil {
                            Button(role: .destructive) { borrando = n } label: {
                                Label(L("Borrar", "Delete", "Elimina"), systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text(L("Notas", "Grades", "Voti")).font(.headline).foregroundStyle(Color.primary)
            }
        }
        .listStyle(.plain)
        .navigationTitle(a?.nombre ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editando) { n in
            EditorNota(nota: n, esNueva: false)
        }
        .confirmationDialog(L("¿Borrar esta nota?", "Delete this grade?", "Eliminare questo voto?"),
                            isPresented: Binding(get: { borrando != nil }, set: { if !$0 { borrando = nil } }),
                            titleVisibility: .visible, presenting: borrando) { n in
            Button(L("Borrar", "Delete", "Elimina"), role: .destructive) {
                conMuelle { almacen.datos.notas.removeAll { $0.id == n.id } }
            }
        } message: { _ in
            Text(L("Cambia la media. No se puede deshacer.", "It changes the average. This can't be undone.", "Cambia la media. Non si può annullare."))
        }
        .sensoryFeedback(.selection, trigger: seleccion?.id)
    }

    private func grafica(_ notas: [Nota], escala: EscalaNotas, color: ColorHoot) -> some View {
        Chart {
            RuleMark(y: .value(L("Aprobado", "Pass", "Sufficienza"), escala.aprobado))
                .foregroundStyle(Color.texto2)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            ForEach(notas) { n in
                AreaMark(x: .value(L("Fecha", "Date", "Data"), n.fecha), yStart: .value("", escala.mayorEsMejor ? escala.minimo : escala.maximo), yEnd: .value(L("Nota", "Grade", "Voto"), n.valor))
                    .foregroundStyle(LinearGradient(colors: [color.color.opacity(0.28), color.color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value(L("Fecha", "Date", "Data"), n.fecha), y: .value(L("Nota", "Grade", "Voto"), n.valor))
                    .foregroundStyle(color.color)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .interpolationMethod(.monotone)
                PointMark(x: .value(L("Fecha", "Date", "Data"), n.fecha), y: .value(L("Nota", "Grade", "Voto"), n.valor))
                    .foregroundStyle(color.color)
                    .symbolSize(seleccion?.id == n.id ? 140 : 50)
            }
            if let s = seleccion {
                RuleMark(x: .value(L("Fecha", "Date", "Data"), s.fecha))
                    .foregroundStyle(LinearGradient(colors: [color.color.opacity(0.6), color.color.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 2) {
                            Text(Formato.numero(s.valor, decimales: 2))
                                .font(.headline.monospacedDigit())
                            Text(s.titulo)
                                .font(.caption)
                                .lineLimit(1)
                            Text(Formato.diaCorto(s.fecha))
                                .font(.caption2)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
            }
        }
        .modifier(EscalaGrafica(escala: escala))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated).locale(localeActual))
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        LongPressGesture(minimumDuration: 0.2)
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onChanged { valor in
                                guard case .second(true, let arrastre?) = valor, let marco = proxy.plotFrame else { return }
                                let x = arrastre.location.x - geo[marco].origin.x
                                guard let fecha: Date = proxy.value(atX: x) else { return }
                                let cercana = notas.min { abs($0.fecha.timeIntervalSince(fecha)) < abs($1.fecha.timeIntervalSince(fecha)) }
                                if cercana?.id != seleccion?.id {
                                    withAnimation(Diseno.muelleRapido) { seleccion = cercana }
                                }
                            }
                            .onEnded { _ in withAnimation(Diseno.muelle) { seleccion = nil } }
                    )
            }
        }
        .accessibilityLabel(L("Evolución de las notas", "Grade trend", "Andamento dei voti"))
    }
}

struct EditorNota: View {
    @State var nota: Nota
    var esNueva = true
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        let escala = almacen.ajustes.escala
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 6) {
                        Text(Formato.numero(nota.valor, decimales: 2))
                            .font(.system(.largeTitle, design: .rounded).weight(.bold).monospacedDigit())
                            .foregroundStyle(escala.aprueba(nota.valor) ? Color.primary : Color.urgente)
                            .contentTransition(.numericText())
                            .animation(Diseno.muelleRapido, value: nota.valor)
                        Slider(value: $nota.valor, in: escala.minimo...escala.maximo, step: escala.paso) {
                            Text(L("Nota", "Grade", "Voto"))
                        } minimumValueLabel: {
                            Text(Formato.numero(escala.minimo, decimales: 0)).font(.caption).textoSecundario()
                        } maximumValueLabel: {
                            Text(Formato.numero(escala.maximo, decimales: 0)).font(.caption).textoSecundario()
                        }
                        .tint(almacen.datos.asignatura(nota.asignaturaID)?.color.color ?? Color.acento)
                    }
                    .padding(.vertical, 6)
                }
                .sensoryFeedback(.selection, trigger: nota.valor)

                Section {
                    TextField(L("Examen del tema 2, trabajo…", "Unit 2 test, project…", "Verifica unità 2, progetto…"), text: $nota.titulo)
                    Picker(L("Asignatura", "Subject", "Materia"), selection: $nota.asignaturaID) {
                        ForEach(almacen.datos.asignaturas) { a in
                            Label(a.nombre, systemImage: a.simbolo).tag(a.id)
                        }
                    }
                    Picker(L("Tipo", "Type", "Tipo"), selection: $nota.tipo) {
                        ForEach(TipoNota.allCases) { Text($0.nombre).tag($0) }
                    }
                    Picker(L("Cuenta", "Weight", "Peso"), selection: $nota.peso) {
                        Text(L("Normal", "Normal", "Normale")).tag(1.0)
                        Text(L("La mitad", "Half", "Metà")).tag(0.5)
                        Text(L("Doble", "Double", "Doppio")).tag(2.0)
                        Text(L("Triple", "Triple", "Triplo")).tag(3.0)
                    }
                    DatePicker(L("Fecha", "Date", "Data"), selection: $nota.fecha, displayedComponents: .date)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(esNueva ? L("Nueva nota", "New grade", "Nuovo voto") : L("Editar nota", "Edit grade", "Modifica voto"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BotonCerrar { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { guardar() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func guardar() {
        if nota.titulo.trimmingCharacters(in: .whitespaces).isEmpty { nota.titulo = nota.tipo.nombre }
        conMuelle {
            if let i = almacen.datos.notas.firstIndex(where: { $0.id == nota.id }) {
                almacen.datos.notas[i] = nota
            } else {
                almacen.datos.notas.append(nota)
            }
        }
        cerrar()
    }
}

struct EscalaGrafica: ViewModifier {
    var escala: EscalaNotas

    func body(content: Content) -> some View {
        if escala.mayorEsMejor {
            content.chartYScale(domain: escala.minimo...escala.maximo)
        } else {
            content.chartYScale(domain: .automatic(includesZero: false, reversed: true))
        }
    }
}

struct NotaValor: View {
    var valor: Double
    var aprueba: Bool
    var fuente: Font
    var decimales = 1

    var body: some View {
        HStack(spacing: 4) {
            if !aprueba {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))
                    .accessibilityLabel(L("Suspenso", "Failing", "Insufficiente"))
            }
            Text(Formato.numero(valor, decimales: decimales))
                .font(fuente.monospacedDigit())
        }
        .foregroundStyle(aprueba ? Color.primary : Color.urgente)
    }
}
