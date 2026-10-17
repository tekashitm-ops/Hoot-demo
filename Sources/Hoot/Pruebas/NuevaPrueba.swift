import SwiftUI

enum ComoApuntar: String, CaseIterable, Identifiable {
    case foto, dictado, aMano

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .foto: L("Foto del diario", "Planner photo", "Foto del diario")
        case .dictado: L("Dictarla", "Dictate it", "Dettala")
        case .aMano: L("A mano", "Type it", "A mano")
        }
    }

    var simbolo: String {
        switch self {
        case .foto: "camera.fill"
        case .dictado: "mic.fill"
        case .aMano: "pencil"
        }
    }
}

struct BotonesApuntar: View {
    var elegir: (ComoApuntar) -> Void
    @Environment(\.dynamicTypeSize) private var letra
    @ScaledMetric(relativeTo: .subheadline) private var alto: CGFloat = 96

    var body: some View {
        let disposicion = letra.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        disposicion {
            ForEach(ComoApuntar.allCases) { c in
                Button { elegir(c) } label: {
                    VStack(spacing: 8) {
                        Image(systemName: c.simbolo).font(.title2.weight(.semibold))
                        Text(c.nombre)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: letra.isAccessibilitySize ? 64 : alto)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: Diseno.radioModulo))
                .tint(.white.opacity(0.6))
            }
        }
    }
}

struct NuevaPrueba: View {
    var empezarCon: ComoApuntar?
    var alGuardar: (UUID) -> Void

    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var borrador: BorradorPrueba?
    @State private var leyendo = false
    @State private var escaneando = false
    @State private var dictando = false
    @State private var dictado = Dictado()
    @State private var empezado = false

    var body: some View {
        NavigationStack {
            Group {
                if let borrador {
                    EditorPrueba(borrador: borrador, alGuardar: { id in
                        cerrar()
                        alGuardar(id)
                    })
                } else if leyendo {
                    leyendoVista
                } else if dictando {
                    dictadoVista
                } else {
                    eleccion
                }
            }
            .tenidaDelCielo(hoja: true)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents(borrador == nil && !dictando ? [.medium, .large] : [.large])
        .presentationBackground { FondoHojaTenida() }
        .environment(\.pestanaVisible, false)
        .fullScreenCover(isPresented: $escaneando) {
            EscanerDocumentos { paginas in
                escaneando = false
                leer(paginas)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            guard !empezado else { return }
            empezado = true
            if let empezarCon { empezar(empezarCon) }
        }
    }

    private var eleccion: some View {
        VStack(alignment: .leading, spacing: 22) {
            HootDice(frase: L("¿Foto, voz o a mano? Tú mandas. Por ahora.", "Photo, voice or typing? You're the boss. For now.",
                              "Foto, voce o a mano? Comandi tu. Per ora."),
                     gesto: .hablando, tamano: 104, paraguasSiLlueve: false)
            BotonesApuntar { empezar($0) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Diseno.margen)
        .padding(.top, 8)
        .navigationTitle(L("Nueva prueba", "New test", "Nuova verifica"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar() } }
        }
    }

    private var leyendoVista: some View {
        VStack(spacing: 18) {
            Spacer()
            LoboTrabajando(tamano: 150, gesto: .pensando)
            Text(L("Leyendo tu letra…", "Reading your handwriting…", "Sto leggendo la tua calligrafia…"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .navigationTitle(L("Nueva prueba", "New test", "Nuova verifica"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dictadoVista: some View {
        VStack(spacing: 22) {
            HootDice(frase: L("Dímela: la asignatura, el día y los temas.", "Tell me: the subject, the day and the topics.",
                              "Dimmela: la materia, il giorno e gli argomenti."),
                     gesto: .normal, tamano: 104, paraguasSiLlueve: false)
            Text(dictado.texto.isEmpty ? L("«El jueves, examen de Historia: Roma, Cartago y Augusto»",
                                           "“Thursday, History test: Rome, Carthage and Augustus”",
                                           "«Giovedì, verifica di Storia: Roma, Cartagine e Augusto»") : dictado.texto)
                .font(.title3)
                .foregroundStyle(dictado.texto.isEmpty ? AnyShapeStyle(EstiloSecundario()) : AnyShapeStyle(Color.white))
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(Diseno.muelleRapido, value: dictado.texto)
            if let error = dictado.error {
                Text(error).font(.subheadline).foregroundStyle(EstiloAviso(color: .pronto))
            }
            Spacer(minLength: 0)
            Button {
                Task {
                    dictado.parar()
                    let texto = dictado.texto
                    dictando = false
                    await interpretar(texto)
                }
            } label: {
                Label(L("Listo", "Done", "Fatto"), systemImage: "checkmark").frame(maxWidth: .infinity)
            }
            .botonAmbar()
            .controlSize(.large)
            .disabled(dictado.texto.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, Diseno.margen)
        .padding(.vertical, 12)
        .navigationTitle(L("Dictarla", "Dictate it", "Dettala"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                BotonCerrar {
                    dictado.parar()
                    dictando = false
                }
            }
        }
        .task { await dictado.empezar(desde: "") }
    }

    private func empezar(_ c: ComoApuntar) {
        switch c {
        case .aMano:
            conMuelle { borrador = BorradorPrueba() }
        case .dictado:
            conMuelle { dictando = true }
        case .foto:
            if ModoCapturas.activo {
                conMuelle { borrador = LectorDiario.interpretar(ModoCapturas.notaDiario, asignaturas: almacen.datos.asignaturas, ahora: Reloj.ahora) }
            } else if EscanerDocumentos.disponible {
                escaneando = true
            } else {
                conMuelle { borrador = BorradorPrueba() }
            }
        }
    }

    private func leer(_ paginas: [UIImage]) {
        guard !paginas.isEmpty else { return }
        conMuelle { leyendo = true }
        Task {
            var texto = ""
            for p in paginas.prefix(3) {
                if let t = try? await LectorTexto.leer(p.reducida(a: 2400)) { texto += t + "\n" }
            }
            await interpretar(texto)
        }
    }

    private func interpretar(_ texto: String) async {
        conMuelle { leyendo = true }
        var b = await LectorDiario.leer(texto, asignaturas: almacen.datos.asignaturas)
        b.texto = texto
        conMuelle {
            leyendo = false
            borrador = b
        }
        if !texto.isEmpty { Sonidos.compartido.tocar(.acierto) }
    }
}

struct EditorPrueba: View {
    var prueba: Prueba?
    var alGuardar: (UUID) -> Void

    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var asignaturaID: UUID?
    @State private var tipo: TipoPrueba = .escrita
    @State private var fecha: Date
    @State private var temas: [String]
    @State private var privada = false
    @State private var leido = ""
    @FocusState private var foco: Int?

    init(borrador: BorradorPrueba, alGuardar: @escaping (UUID) -> Void) {
        self.prueba = nil
        self.alGuardar = alGuardar
        _asignaturaID = State(initialValue: borrador.asignaturaID)
        _tipo = State(initialValue: borrador.tipo)
        _fecha = State(initialValue: Self.conHora(borrador.fecha ?? calendarioActual.date(byAdding: .day, value: 7, to: Reloj.ahora) ?? Reloj.ahora))
        _temas = State(initialValue: borrador.temas.isEmpty ? [""] : borrador.temas)
        _leido = State(initialValue: borrador.texto)
    }

    init(prueba: Prueba, alGuardar: @escaping (UUID) -> Void = { _ in }) {
        self.prueba = prueba
        self.alGuardar = alGuardar
        _asignaturaID = State(initialValue: prueba.asignaturaID)
        _tipo = State(initialValue: prueba.tipo)
        _fecha = State(initialValue: prueba.fecha)
        _temas = State(initialValue: prueba.temas.map(\.nombre) + [""])
        _privada = State(initialValue: prueba.privada)
    }

    private static func conHora(_ d: Date) -> Date {
        calendarioActual.date(bySettingHour: 8, minute: 0, second: 0, of: d) ?? d
    }

    private var limpios: [String] {
        temas.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    var body: some View {
        Form {
            if !leido.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, prueba == nil {
                Section {
                    HootDice(frase: FrasesHoot.fotoDiario(), gesto: .feliz, tamano: 92, paraguasSiLlueve: false)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }
            Section {
                Picker(L("Asignatura", "Subject", "Materia"), selection: $asignaturaID) {
                    Text(L("Ninguna", "None", "Nessuna")).tag(UUID?.none)
                    ForEach(almacen.datos.asignaturas) { a in
                        Label(a.nombre, systemImage: a.simbolo).tag(UUID?.some(a.id))
                    }
                }
                Picker(L("Tipo", "Type", "Tipo"), selection: $tipo) {
                    ForEach(TipoPrueba.allCases) { Text($0.nombre).tag($0) }
                }
                .pickerStyle(.segmented)
                DatePicker(L("Día", "Day", "Giorno"), selection: $fecha, displayedComponents: .date)
                    .tint(Color.acento)
            }
            .filaTenida()
            Section {
                ForEach(temas.indices, id: \.self) { i in
                    TextField(text: Binding(get: { temas.indices.contains(i) ? temas[i] : "" },
                                            set: { nuevo in
                                                guard temas.indices.contains(i) else { return }
                                                temas[i] = nuevo
                                                if i == temas.count - 1, !nuevo.isEmpty { temas.append("") }
                                            }),
                              prompt: Indicacion.texto(i == 0 ? L("Primer tema", "First topic", "Primo argomento") : L("Otro tema", "Another topic", "Un altro argomento"))) {
                        Text(L("Tema", "Topic", "Argomento"))
                    }
                    .focused($foco, equals: i)
                    .submitLabel(.next)
                    .onSubmit { foco = i + 1 }
                }
                .onDelete { idx in temas.remove(atOffsets: idx); if temas.isEmpty { temas = [""] } }
            } header: {
                Text(L("Temas", "Topics", "Argomenti")).foregroundStyle(EstiloSecundario())
            } footer: {
                Text(L("Cada tema tendrá su luna.", "Each topic gets its own moon.", "Ogni argomento avrà la sua luna."))
                    .foregroundStyle(EstiloSecundario())
            }
            .filaTenida()
            Section {
                Toggle(isOn: $privada) {
                    Label(L("Solo para mí", "Just for me", "Solo per me"), systemImage: "lock")
                }
                .interruptorApple()
            } footer: {
                Text(L("Tu familia no la verá.", "Your family won't see it.", "La tua famiglia non la vedrà."))
                    .foregroundStyle(EstiloSecundario())
            }
            .filaTenida()
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(prueba == nil ? L("Nueva prueba", "New test", "Nuova verifica") : L("Editar", "Edit", "Modifica"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) { guardar() }
                    .disabled(limpios.isEmpty && asignaturaID == nil)
            }
        }
    }

    private func guardar() {
        let nombres = limpios.isEmpty ? [almacen.datos.asignatura(asignaturaID)?.nombre ?? L("Tema", "Topic", "Argomento")] : limpios
        var p = prueba ?? Prueba(fecha: fecha)
        p.asignaturaID = asignaturaID
        p.tipo = tipo
        p.fecha = fecha
        p.privada = privada

        let viejos = p.temas
        p.temas = nombres.map { n in viejos.first { $0.nombre == n } ?? Tema(nombre: n) }
        let id = p.id
        conMuelle {
            if let i = almacen.datos.pruebas.firstIndex(where: { $0.id == id }) {
                almacen.datos.pruebas[i] = p
            } else {
                almacen.datos.pruebas.append(p)
            }
        }
        alGuardar(id)
        cerrar()
    }
}

struct EditorTemaDeAhora: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var asignaturaID: UUID?
    @State private var nombre = ""
    @FocusState private var foco: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(text: $nombre, prompt: Indicacion.texto(L("La célula, los ríos de Europa…", "The cell, European rivers…", "La cellula, i fiumi d'Europa…"))) {
                        Text(L("Tema", "Topic", "Argomento"))
                    }
                    .font(.title3)
                    .focused($foco)
                    Picker(L("Asignatura", "Subject", "Materia"), selection: $asignaturaID) {
                        Text(L("Ninguna", "None", "Nessuna")).tag(UUID?.none)
                        ForEach(almacen.datos.asignaturas) { a in
                            Label(a.nombre, systemImage: a.simbolo).tag(UUID?.some(a.id))
                        }
                    }
                } footer: {
                    Text(L("Hoot te lo repasa poco a poco, por si te preguntan sin avisar.",
                           "Hoot reviews it with you bit by bit, in case they quiz you out of nowhere.",
                           "Hoot te lo ripassa un po' alla volta, nel caso ti interroghino senza preavviso."))
                        .foregroundStyle(EstiloSecundario())
                }
                .filaTenida()
            }
            .tenidaDelCielo(hoja: true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle(L("Tema de ahora", "Current topic", "Argomento di adesso"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        let n = nombre.trimmingCharacters(in: .whitespacesAndNewlines)
                        conMuelle { almacen.datos.temasDeAhora.append(TemaDeAhora(asignaturaID: asignaturaID, tema: Tema(nombre: n))) }
                        cerrar()
                    }
                    .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { foco = true }
        }
        .presentationDetents([.medium])
        .presentationBackground { FondoHojaTenida() }
        .environment(\.pestanaVisible, false)
    }
}
