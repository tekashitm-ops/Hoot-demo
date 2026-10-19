import SwiftUI

struct TareaDetalle: View {
    var id: UUID
    var soloLectura = false
    var datosFamilia: DatosEscolares?

    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var editando = false
    @State private var borrando = false
    @ScaledMetric(relativeTo: .largeTitle) private var ladoIcono = 64
    @Environment(\.dynamicTypeSize) private var letra

    private var datos: DatosEscolares { datosFamilia ?? almacen.datos }
    private var tarea: Tarea? { datos.tareas.first { $0.id == id } }

    var body: some View {
        Group {
            if let t = tarea {
                contenido(t)
            } else {
                ContentUnavailableView(L("Ya no existe", "No longer exists", "Non esiste più"), systemImage: "tray")
            }
        }
        .tenidaDelCielo()
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func contenido(_ t: Tarea) -> some View {
        let a = datos.asignatura(t.asignaturaID)
        let color = a?.color ?? .indigo
        let (texto, colorVence, _) = Vence.estilo(t.entrega, hecha: t.hecha)
        let tono = TonoCielo.actual(almacen)

        let estiloVence: AnyShapeStyle = colorVence == .urgente || colorVence == .pronto ? AnyShapeStyle(EstiloAviso(color: colorVence))
            : (colorVence == .texto2 ? AnyShapeStyle(EstiloSecundario()) : AnyShapeStyle(colorVence))
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    IconoAsignatura(asignatura: a, lado: ladoIcono)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(a?.nombre ?? L("Sin asignatura", "No subject", "Nessuna materia"))
                            .font(.headline)
                        Label(t.tipo.nombre, systemImage: t.tipo.simbolo)
                            .font(.subheadline)
                            .textoSecundario()
                    }
                }
                .padding(.top, 8)

                Text(t.titulo)
                    .font(.title.bold())
                    .padding(.top, 20)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(texto)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(estiloVence)
                    Text(fechaDetalle(t, dicho: texto) + " · " + Formato.hora(t.entrega))
                        .font(.subheadline)
                        .textoSecundario()
                }
                .padding(.top, 10)

                if !soloLectura, !t.hecha, t.tipo != .deberes, let plan = almacen.datos.plan().empezar(t.id) {
                    PlanDeTarea(tarea: t, plan: plan, color: color)
                        .padding(.top, Diseno.huecoSeccion)
                }
                if !t.temas.isEmpty {
                    bloque(L("Qué entra", "What's covered", "Cosa c'è"), t.temas, simbolo: "list.bullet")
                }
                if !t.notas.isEmpty {
                    bloque(L("Detalles", "Details", "Dettagli"), t.notas, simbolo: "text.alignleft")
                }
                if t.origen == .teams {
                    Label(L("Llegó de Microsoft Teams", "Came from Microsoft Teams", "Arrivato da Microsoft Teams"), systemImage: "person.3.fill")
                        .font(.subheadline)
                        .textoSecundario()
                        .padding(.top, Diseno.huecoSeccion)
                }

                if soloLectura {
                    Label(t.hecha ? L("Hecha", "Done", "Fatto") : L("Sin hacer", "Not done", "Non fatto"),
                          systemImage: t.hecha ? "checkmark.circle.fill" : "circle")
                        .font(.headline)
                        .foregroundStyle(t.hecha ? AnyShapeStyle(Color.hecho) : AnyShapeStyle(EstiloSecundario()))
                        .padding(.top, Diseno.huecoSeccion)
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaBar(edge: .bottom) {
            if !soloLectura {
                GlassEffectContainer(spacing: 10) {

                    let disposicion = letra.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
                    disposicion {
                        Button {
                            conMuelle(Diseno.muelleRebote) { almacen.alternarHecha(t.id) }
                        } label: {
                            Label(t.hecha ? L("Pendiente", "To do", "Da fare")
                                          : (t.tipo == .examen ? L("Ya lo hice", "I took it", "L'ho fatta") : L("Hecha", "Done", "Fatto")),
                                  systemImage: t.hecha ? "arrow.uturn.backward" : "checkmark")
                                .font(.headline)

                                .foregroundStyle(t.hecha ? AnyShapeStyle(Color.primary) : AnyShapeStyle(tono.fondo.color))
                                .frame(maxWidth: .infinity)
                        }
                        .modifier(EstiloAccionPrincipal(hecha: t.hecha, tono: tono))
                        .controlSize(.extraLarge)
                        .sensoryFeedback(trigger: t.hecha) { _, nueva in nueva ? .success : .selection }

                        Button {
                            almacen.ayudaPendiente = (t.tipo == .examen ? .resumen : .revisar, t.asignaturaID)
                            almacen.pestana = .estudio
                        } label: {
                            Label(t.tipo == .examen ? L("Resumen", "Summary", "Riassunto") : L("Revisar", "Check", "Controlla"),
                                  systemImage: "sparkles")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.extraLarge)
                    }
                }
                .padding(.horizontal, Diseno.margen)
                .padding(.bottom, 8)
            }
        }
        .background(alignment: .top) {
            LinearGradient(colors: [color.color.opacity(0.3), color.color.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 320)
                .ignoresSafeArea(edges: .top)
                .accessibilityHidden(true)
        }
        .toolbar {
            if !soloLectura {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(L("Editar", "Edit", "Modifica"), systemImage: "pencil") { editando = true }
                        Button(L("Borrar", "Delete", "Elimina"), systemImage: "trash", role: .destructive) { borrando = true }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel(L("Más", "More", "Altro"))
                }
            }
        }
        .sheet(isPresented: $editando) {
            EditorTarea(tarea: t, esNueva: false)
        }
        .confirmationDialog(L("¿Borrar esta tarea?", "Delete this task?", "Eliminare questo compito?"), isPresented: $borrando, titleVisibility: .visible) {
            Button(L("Borrar", "Delete", "Elimina"), role: .destructive) {
                cerrar()
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    conMuelle { almacen.datos.tareas.removeAll { $0.id == t.id } }
                }
            }
        } message: {
            Text(L("No se puede deshacer.", "This can't be undone.", "Non si può annullare."))
        }
    }

    private func fechaDetalle(_ t: Tarea, dicho: String) -> String {
        let cal = calendarioActual
        let dias = cal.dateComponents([.day], from: cal.startOfDay(for: Reloj.ahora), to: cal.startOfDay(for: t.entrega)).day ?? 0
        guard dicho == Formato.diaRelativo(t.entrega), !(-1...1).contains(dias) else { return Formato.diaLargo(t.entrega) }
        return (2...6).contains(dias) ? Formato.diaMes(t.entrega) : Formato.diaSemana(t.entrega)
    }

    private func bloque(_ titulo: String, _ texto: String, simbolo: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(titulo, systemImage: simbolo)
                .font(.headline)
                .padding(.top, Diseno.huecoSeccion)
            Text(texto)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct EditorTarea: View {
    @State var tarea: Tarea
    var esNueva = true
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @FocusState private var foco: Bool

    var body: some View {
        NavigationStack {

            Form {
                Section {
                    TextField(text: $tarea.titulo, prompt: Indicacion.texto(tarea.tipo == .examen ? L("Examen de…", "Test on…", "Verifica di…") : L("Qué hay que hacer", "What to do", "Cosa c'è da fare")),
                              axis: .vertical) {
                        Text(L("Título", "Title", "Titolo"))
                    }
                    .font(.title3)
                    .focused($foco)
                    Picker(L("Tipo", "Type", "Tipo"), selection: $tarea.tipo) {
                        ForEach(TipoTarea.allCases) { Text($0.nombre).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .filaTenida()
                Section {
                    Picker(L("Asignatura", "Subject", "Materia"), selection: $tarea.asignaturaID) {
                        Text(L("Ninguna", "None", "Nessuna")).tag(UUID?.none)
                        ForEach(almacen.datos.asignaturas) { a in
                            Label(a.nombre, systemImage: a.simbolo).tag(UUID?.some(a.id))
                        }
                    }
                    DatePicker(tarea.tipo == .examen ? L("Día y hora", "Date and time", "Giorno e ora") : L("Entrega", "Due", "Consegna"),
                               selection: $tarea.entrega)
                        .tint(Color.acento)
                }
                .filaTenida()
                if tarea.tipo == .examen {
                    Section {
                        TextField(text: $tarea.temas, prompt: Indicacion.texto(L("Temas o páginas que entran", "Topics or pages covered", "Argomenti o pagine")), axis: .vertical) {
                            Text(L("Temas", "Topics", "Argomenti"))
                        }
                    }
                    .filaTenida()
                }
                Section {
                    TextField(text: $tarea.notas, prompt: Indicacion.texto(L("Detalles", "Details", "Dettagli")), axis: .vertical) {
                        Text(L("Detalles", "Details", "Dettagli"))
                    }
                    .lineLimit(2...6)
                }
                .filaTenida()
            }
            .tenidaDelCielo(hoja: true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle(esNueva ? (tarea.tipo == .examen ? L("Nuevo examen", "New test", "Nuova verifica") : L("Nueva tarea", "New task", "Nuovo compito"))
                                     : L("Editar", "Edit", "Modifica"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BotonCerrar { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { guardar() }
                        .disabled(tarea.titulo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { if esNueva { foco = true } }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground { FondoHojaTenida() }
    }

    private func guardar() {
        tarea.titulo = tarea.titulo.trimmingCharacters(in: .whitespacesAndNewlines)
        conMuelle {
            if let i = almacen.datos.tareas.firstIndex(where: { $0.id == tarea.id }) {
                almacen.datos.tareas[i] = tarea
            } else {
                almacen.datos.tareas.append(tarea)
            }
        }
        cerrar()
    }
}

struct EditorRecordatorio: View {
    @State var recordatorio: Recordatorio
    var esNuevo = true

    var paraHijo = false
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @FocusState private var foco: Bool

    var body: some View {
        NavigationStack {

            Form {
                Section {
                    TextField(text: $recordatorio.titulo, prompt: Indicacion.texto(L("Qué hay que recordar", "What to remember", "Cosa ricordare")), axis: .vertical) {
                        Text(L("Qué hay que recordar", "What to remember", "Cosa ricordare"))
                    }
                    .font(.title3)
                    .focused($foco)
                }
                .filaTenida()
                Section {
                    DatePicker(L("Día", "Date", "Giorno"), selection: $recordatorio.fecha, displayedComponents: .date)
                        .tint(Color.acento)
                    Toggle(L("A una hora", "At a time", "A un'ora"), isOn: $recordatorio.conHora.animation(Diseno.muelle))
                        .interruptorApple()
                    if recordatorio.conHora {
                        DatePicker(L("Hora", "Time", "Ora"), selection: $recordatorio.fecha, displayedComponents: .hourAndMinute)
                            .tint(Color.acento)
                    }
                }
                .filaTenida()
                Section {
                    TextField(text: $recordatorio.notas, prompt: Indicacion.texto(L("Detalles", "Details", "Dettagli")), axis: .vertical) {
                        Text(L("Detalles", "Details", "Dettagli"))
                    }
                    .lineLimit(2...5)
                }
                .filaTenida()
                if !paraHijo && !almacen.esFamilia {
                    Section {
                        Toggle(isOn: $recordatorio.privada) {
                            Label(L("Solo para mí", "Just for me", "Solo per me"), systemImage: "lock")
                        }
                        .interruptorApple()
                    } footer: {
                        Text(L("Tu familia no lo verá.", "Your family won't see it.", "La tua famiglia non lo vedrà."))
                            .foregroundStyle(EstiloSecundario())
                    }
                    .filaTenida()
                }
            }
            .tenidaDelCielo(hoja: true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle(paraHijo ? L("Recordatorio para \(almacen.hijoActivo?.nombre ?? "")", "Reminder for \(almacen.hijoActivo?.nombre ?? "")", "Promemoria per \(almacen.hijoActivo?.nombre ?? "")")
                                      : (esNuevo ? L("Nuevo recordatorio", "New reminder", "Nuovo promemoria") : L("Editar", "Edit", "Modifica")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BotonCerrar { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { guardar() }
                        .disabled(recordatorio.titulo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { if esNuevo { foco = true } }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground { FondoHojaTenida() }
    }

    private func guardar() {
        recordatorio.titulo = recordatorio.titulo.trimmingCharacters(in: .whitespacesAndNewlines)
        if paraHijo { recordatorio.origen = .familia }
        let r = recordatorio
        conMuelle {
            almacen.modificarDatos { d in
                if let i = d.recordatorios.firstIndex(where: { $0.id == r.id }) {
                    d.recordatorios[i] = r
                } else {
                    d.recordatorios.append(r)
                }
            }
        }
        if paraHijo || almacen.esFamilia {

            Task { await FamiliaNube.compartida.mandar(r, tipo: "recordatorio", almacen: almacen) }
        }
        if paraHijo, let id = almacen.hijoActivo?.id, let i = almacen.hijos.firstIndex(where: { $0.id == id }) {
            almacen.hijos[i].avisos.insert(Aviso(tipo: .recordatorio, fecha: Reloj.ahora,
                                                 texto: L("Le has enviado: «\(r.titulo)»", "You sent: “\(r.titulo)”", "Gli hai inviato: «\(r.titulo)»"), leido: true), at: 0)
        }
        cerrar()
    }
}

struct EstiloAccionPrincipal: ViewModifier {
    var hecha: Bool
    var tono: TonoCielo

    func body(content: Content) -> some View {
        if hecha {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.glassProminent).tint(tono.boton.color)
        }
    }
}

struct PlanDeTarea: View {
    var tarea: Tarea
    var plan: PlanTarea
    var color: ColorHoot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L("Cuándo hacerlo", "When to do it", "Quando farlo"), systemImage: "calendar.badge.clock")
                .font(.headline)
            Text(L("Empieza \(cuando)", "Start \(cuando)", "Inizia \(cuando)"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(plan.justa ? AnyShapeStyle(EstiloAviso(color: .pronto)) : AnyShapeStyle(Color.primary))
            if plan.justa {
                Text(L("Va justo: haz un rato cada tarde hasta el día.", "It's tight: do a session every afternoon until then.", "È stretto: fai una sessione ogni pomeriggio fino al giorno."))
                    .font(.subheadline)
                    .foregroundStyle(EstiloAviso(color: .pronto))
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(tarea.ratosHechos.sorted().enumerated()), id: \.offset) { _, d in
                    fila(dia: d, detalle: L("Hecho", "Done", "Fatto"), hecho: true)
                }
                ForEach(plan.sesiones) { s in
                    fila(dia: s.dia, detalle: "\(Formato.hora(s.hora)) · \(s.minutos) min", hecho: false)
                }
            }
            .padding(.top, 2)
        }
        .accessibilityElement(children: .combine)
    }

    private var cuando: String {
        let d = Formato.diaRelativo(plan.empezar)

        let cal = calendarioActual
        let manana = cal.date(byAdding: .day, value: 1, to: Reloj.ahora) ?? Reloj.ahora
        return cal.isDate(plan.empezar, inSameDayAs: Reloj.ahora) || cal.isDate(plan.empezar, inSameDayAs: manana)
            ? d.lowercased(with: localeActual)
            : L("el \(d.lowercased(with: localeActual))", "on \(d)", d.lowercased(with: localeActual))
    }

    private func fila(dia: Date, detalle: String, hecho: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: hecho ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(hecho ? Color.hecho : color.color)
                .accessibilityHidden(true)
            Text(Formato.diaSemanaCorto(dia).conMayuscula)
                .font(.subheadline.weight(.medium))
                .strikethrough(hecho, color: Color.texto2)
            Spacer()
            Text(detalle)
                .font(.subheadline.monospacedDigit())
                .textoSecundario()
        }
    }
}
