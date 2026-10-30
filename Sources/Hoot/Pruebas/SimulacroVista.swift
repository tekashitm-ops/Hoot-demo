import SwiftUI
import PhotosUI

struct EmpezarSimulacro: View {
    var pruebaID: UUID
    var alEmpezar: (SimulacroIA) -> Void

    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var enPapel = true
    @State private var conReloj = false
    @State private var minutos = 50
    @State private var viendoAntiguas = false

    var body: some View {
        NavigationStack {
            if let p = almacen.datos.pruebas.first(where: { $0.id == pruebaID }) {
                let asig = almacen.datos.asignatura(p.asignaturaID)
                let antiguas = almacen.datos.pruebasAntiguas.filter { $0.asignaturaID == p.asignaturaID }
                let oral = p.tipo == .oral
                Form {
                    Section {
                        HootDice(frase: FrasesHoot.simulacro(semilla: p.temas.count), gesto: .feliz, tamano: 96, paraguasSiLlueve: false)
                            .padding(.vertical, 4)
                            .listRowBackground(Color.clear)
                    }
                    Section {
                        HStack(spacing: 12) {
                            IconoAsignatura(asignatura: asig, lado: 36)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(asig?.nombre ?? p.tipo.nombre).font(.headline).foregroundStyle(.white)
                                Text(L("\(Formato.diaRelativo(p.fecha)) · \(p.temas.count) temas mezclados · \(SimulacroIA.cuantas(p.temas.count)) preguntas",
                                       "\(Formato.diaRelativo(p.fecha)) · \(p.temas.count) topics mixed · \(SimulacroIA.cuantas(p.temas.count)) questions",
                                       "\(Formato.diaRelativo(p.fecha)) · \(p.temas.count) argomenti mescolati · \(SimulacroIA.cuantas(p.temas.count)) domande"))
                                    .font(.subheadline)
                                    .foregroundStyle(EstiloSecundario())
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .filaTenida()
                    if !oral {
                        Section {
                            Picker(L("Cómo contestas", "How you answer", "Come rispondi"), selection: $enPapel) {
                                Text(L("En papel", "On paper", "Su carta")).tag(true)
                                Text(L("En el iPhone", "On iPhone", "Sull'iPhone")).tag(false)
                            }
                            .pickerStyle(.segmented)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        } header: {
                            Text(L("Cómo contestas", "How you answer", "Come rispondi")).foregroundStyle(EstiloSecundario())
                        } footer: {
                            if enPapel {
                                Text(L("Al acabar, le haces una foto a tu hoja. Pon el número de cada pregunta delante de la respuesta.",
                                       "When you finish, take a photo of your sheet. Write each question's number before the answer.",
                                       "Alla fine, fai una foto al tuo foglio. Scrivi il numero di ogni domanda prima della risposta."))
                                    .foregroundStyle(EstiloSecundario())
                            }
                        }
                    }
                    Section {
                        Toggle(isOn: $conReloj.animation(Diseno.muelle)) {
                            Label {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(L("Reloj", "Timer", "Timer"))
                                    Text(L("Como en clase: \(minutos) min", "Like in class: \(minutos) min", "Come in classe: \(minutos) min"))
                                        .font(.subheadline)
                                        .foregroundStyle(EstiloSecundario())
                                }
                            } icon: {
                                Image(systemName: "timer")
                            }
                        }
                        .interruptorApple()
                        if conReloj {
                            Stepper(value: $minutos, in: 10...120, step: 5) {
                                LabeledContent(L("Tiempo", "Time", "Tempo"), value: L("\(minutos) min", "\(minutos) min", "\(minutos) min"))
                            }
                        }
                        Button { viendoAntiguas = true } label: {
                            HStack(spacing: 12) {
                                Label {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(L("Como tu profe", "Like your teacher", "Come il tuo prof")).foregroundStyle(.white)
                                        Text(antiguas.isEmpty
                                             ? L("Con fotos de sus pruebas de antes", "With photos of their old tests", "Con foto delle sue verifiche di prima")
                                             : L("\(antiguas.count) \(antiguas.count == 1 ? "prueba antigua" : "pruebas antiguas") de \(asig?.nombre ?? "esta asignatura")",
                                                 "\(antiguas.count) old \(antiguas.count == 1 ? "test" : "tests") in \(asig?.nombre ?? "this subject")",
                                                 "\(antiguas.count) \(antiguas.count == 1 ? "verifica" : "verifiche") di prima di \(asig?.nombre ?? "questa materia")"))
                                            .font(.subheadline)
                                            .foregroundStyle(EstiloSecundario())
                                    }
                                } icon: {
                                    Image(systemName: "doc.text.magnifyingglass").foregroundStyle(.white)
                                }
                                Spacer()
                                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(EstiloSecundario())
                            }
                        }
                    }
                    .filaTenida()
                }
                .tenidaDelCielo(hoja: true)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .navigationTitle(L("Simulacro", "Mock test", "Simulazione"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar() } }
                }
                .safeAreaBar(edge: .bottom) {
                    Button {
                        let estilo = antiguas.map(\.texto).joined(separator: "\n\n")
                        let s = SimulacroIA(prueba: p, asignatura: asig, curso: almacen.perfil.curso,
                                            forma: oral ? .oral : (enPapel ? .papel : .iPhone), minutos: conReloj ? minutos : nil, estilo: estilo)
                        cerrar()
                        alEmpezar(s)
                    } label: {
                        Text(L("Empezar", "Start", "Inizia")).frame(maxWidth: .infinity)
                    }
                    .botonAmbar()
                    .controlSize(.large)
                    .disabled(DisponibilidadIA.actual != .lista || !p.temas.contains { !$0.textoLeido.isEmpty })
                    .padding(.horizontal, Diseno.margen)
                    .padding(.bottom, 8)
                }
                .sheet(isPresented: $viendoAntiguas) { PruebasAntiguasVista(asignaturaID: p.asignaturaID) }
            }
        }
        .presentationDetents([.large])
        .presentationBackground { FondoHojaTenida() }
        .environment(\.pestanaVisible, false)
    }
}

struct PruebasAntiguasVista: View {
    var asignaturaID: UUID?

    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var escaneando = false
    @State private var eligiendo = false
    @State private var seleccion: [PhotosPickerItem] = []
    @State private var leyendo = false

    var body: some View {
        NavigationStack {
            let lista = almacen.datos.pruebasAntiguas.filter { $0.asignaturaID == asignaturaID }
            Form {
                if !lista.isEmpty {
                    Section {
                        ForEach(lista) { a in
                            HStack(spacing: 12) {
                                if let d = a.miniatura, let img = UIImage(data: d) {
                                    Image(uiImage: img).resizable().scaledToFill().frame(width: 40, height: 52)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                } else {
                                    Image(systemName: "doc.text").font(.title3).frame(width: 40, height: 52)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(a.texto.prefix(60)).replacingOccurrences(of: "\n", with: " ")).lineLimit(2).foregroundStyle(.white)
                                    Text(Formato.diaCorto(a.fecha)).font(.subheadline).foregroundStyle(EstiloSecundario())
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    conMuelle { almacen.datos.pruebasAntiguas.removeAll { $0.id == a.id } }
                                } label: { Label(L("Quitar", "Remove", "Togli"), systemImage: "trash") }
                            }
                        }
                    }
                    .filaTenida()
                }
                Section {
                    if EscanerDocumentos.disponible {
                        Button { escaneando = true } label: { Label(L("Escanear una prueba", "Scan a Test", "Scansiona una verifica"), systemImage: "doc.viewfinder") }
                    }
                    Button { eligiendo = true } label: { Label(L("Elegir fotos", "Choose Photos", "Scegli foto"), systemImage: "photo.on.rectangle") }
                    if leyendo {
                        HStack(spacing: 10) { ProgressView(); Text(L("Leyendo…", "Reading…", "Leggo…")).foregroundStyle(EstiloSecundario()) }
                    }
                } footer: {
                    Text(L("Solo las preguntas cuentan: Hoot no mira las notas.", "Only the questions matter: Hoot doesn't look at grades.",
                           "Contano solo le domande: Hoot non guarda i voti."))
                        .foregroundStyle(EstiloSecundario())
                }
                .filaTenida()
                .disabled(leyendo)
            }
            .tenidaDelCielo(hoja: true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle(L("Pruebas de antes", "Old tests", "Verifiche di prima"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("OK", "OK", "OK")) { cerrar() } } }
            .photosPicker(isPresented: $eligiendo, selection: $seleccion, maxSelectionCount: 20, matching: .images)
            .onChange(of: seleccion) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    var imgs: [UIImage] = []
                    for i in items { if let d = try? await i.loadTransferable(type: Data.self), let img = UIImage(data: d) { imgs.append(img) } }
                    seleccion = []
                    anadir(imgs)
                }
            }
            .fullScreenCover(isPresented: $escaneando) {
                EscanerDocumentos { paginas in
                    escaneando = false
                    anadir(paginas)
                }
                .ignoresSafeArea()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground { FondoHojaTenida() }
    }

    private func anadir(_ imagenes: [UIImage]) {
        guard !imagenes.isEmpty else { return }
        leyendo = true
        Task {
            for img in imagenes {
                let r = img.reducida(a: 2400)
                let texto = (try? await LectorTexto.leer(r)) ?? ""
                guard texto.count > 30 else { continue }
                let antigua = PruebaAntigua(asignaturaID: asignaturaID, texto: String(texto.prefix(4000)),
                                            miniatura: r.reducida(a: 300).jpegData(compressionQuality: 0.6))
                conMuelle { almacen.datos.pruebasAntiguas.append(antigua) }
            }
            leyendo = false
        }
    }
}

struct SimulacroVista: View {
    @Bindable var simulacro: SimulacroIA
    var alTerminar: () -> Void

    @Environment(Almacen.self) private var almacen
    @State private var respuesta = ""
    @State private var dictado = Dictado()
    @State private var saliendo = false
    @State private var escaneando = false
    @State private var eligiendo = false
    @State private var seleccion: [PhotosPickerItem] = []
    @State private var apuntado = false

    var body: some View {
        NavigationStack {
            Group {
                switch simulacro.fase {
                case .preparando(let i, let n):
                    trabajando(n > 1 ? L("Preparando las preguntas… \(i) de \(n)", "Getting the questions ready… \(i) of \(n)", "Preparo le domande… \(i) di \(n)")
                                     : L("Preparando las preguntas…", "Getting the questions ready…", "Preparo le domande…"), gesto: .escribiendo)
                case .contestando:
                    if simulacro.forma == .oral {
                        SimulacroOral(simulacro: simulacro)
                    } else {
                        contestando
                    }
                case .hoja:
                    hoja
                case .leyendoHoja:
                    trabajando(L("Leyendo tu hoja…", "Reading your sheet…", "Leggo il tuo foglio…"), gesto: .pensando)
                case .revisando:
                    revisando
                case .corrigiendo(let i, let n):
                    trabajando(L("Corrigiendo \(i) de \(n)…", "Marking \(i) of \(n)…", "Correggo \(i) di \(n)…"), gesto: .escribiendo)
                case .corregido:
                    ResultadoSimulacro(simulacro: simulacro, alTerminar: alTerminar)
                case .error(let m):
                    VStack(spacing: 16) {
                        Spacer()
                        HootDice(frase: m, gesto: .preocupado, tamano: 110, paraguasSiLlueve: false)
                        Button(L("Volver a intentarlo", "Try Again", "Riprova")) { simulacro.empezar() }
                            .botonAmbar()
                            .controlSize(.large)
                        Spacer()
                    }
                    .padding(Diseno.margen)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tenidaDelCielo()
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle(simulacro.fase == .corregido ? L("Corregido", "Marked", "Corretta") : L("Simulacro", "Mock test", "Simulazione"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                TituloBarra(titulo: simulacro.fase == .corregido ? L("Corregido", "Marked", "Corretta") : L("Simulacro", "Mock test", "Simulazione"), subtitulo: subtitulo)
                if simulacro.fase != .corregido {
                    ToolbarItem(placement: .cancellationAction) {
                        BotonCerrar {
                            if simulacro.contestadas > 0 { saliendo = true } else { simulacro.cancelar(); alTerminar() }
                        }
                    }
                }
                if simulacro.fase == .contestando, simulacro.fin != nil {
                    ToolbarItem(placement: .topBarTrailing) { RelojSimulacro(simulacro: simulacro) }
                }
            }
            .confirmationDialog(L("¿Dejar el simulacro?", "Quit the mock test?", "Lasciare la simulazione?"), isPresented: $saliendo, titleVisibility: .visible) {
                Button(L("Dejarlo", "Quit", "Lascia"), role: .destructive) {
                    simulacro.cancelar()
                    alTerminar()
                }
            } message: {
                Text(L("Se pierde lo que llevas contestado.", "What you've answered so far is lost.", "Si perde quello che hai risposto."))
            }
        }
        .task { if case .preparando = simulacro.fase, !ModoCapturas.activo { simulacro.empezar() } }
        .onDisappear {
            dictado.parar()
            ActividadEnDirecto.compartida.terminar()
        }

        .onChange(of: simulacro.fase) { _, f in
            if f == .contestando {
                ActividadEnDirecto.compartida.empezar(titulo: L("Simulacro de \(simulacro.titulo)", "\(simulacro.titulo) mock test", "Simulazione di \(simulacro.titulo)"),
                                                      simulacro: true, total: simulacro.preguntas.count, luna: 0, fin: simulacro.fin)
            } else if f != .hoja {
                ActividadEnDirecto.compartida.terminar()
            }
        }
        .onChange(of: simulacro.actual) { _, a in
            ActividadEnDirecto.compartida.actualizar(pregunta: a + 1, total: simulacro.preguntas.count, luna: Double(a) / Double(max(simulacro.preguntas.count, 1)), fin: simulacro.fin)
        }
    }

    private var subtitulo: String {
        switch simulacro.fase {
        case .contestando where simulacro.forma != .oral:
            return L("Pregunta \(simulacro.actual + 1) de \(simulacro.preguntas.count)", "Question \(simulacro.actual + 1) of \(simulacro.preguntas.count)",
                     "Domanda \(simulacro.actual + 1) di \(simulacro.preguntas.count)")
        case .corregido:
            return L("Simulacro · \(Formato.diaSemana(Reloj.ahora)) \(Calendar.current.component(.day, from: Reloj.ahora))",
                     "Mock test · \(Formato.diaSemana(Reloj.ahora)) \(Calendar.current.component(.day, from: Reloj.ahora))",
                     "Simulazione · \(Formato.diaSemana(Reloj.ahora)) \(Calendar.current.component(.day, from: Reloj.ahora))")
        default:
            return simulacro.titulo
        }
    }

    private func trabajando(_ texto: String, gesto: GestoLobo) -> some View {
        VStack(spacing: 18) {
            Spacer()
            LoboTrabajando(tamano: 130, gesto: gesto)
            Text(texto).font(.headline).multilineTextAlignment(.center).contentTransition(.opacity)
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(Diseno.margen)
    }

    private var contestando: some View {
        let total = simulacro.preguntas.count
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 4) {
                    ForEach(0..<total, id: \.self) { i in
                        Capsule()
                            .fill(.white.opacity(i < simulacro.actual ? 0.92 : (i == simulacro.actual ? 0.55 : 0.2)))
                            .frame(height: 5)
                    }
                }
                .accessibilityHidden(true)
                if let p = simulacro.pregunta {
                    Text(p.texto)
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(p.id)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                    if simulacro.forma == .papel {
                        HStack(spacing: 14) {
                            Text("\(simulacro.actual + 1).")
                                .font(.largeTitle.weight(.heavy))
                                .fontDesign(.rounded)
                                .monospacedDigit()
                            Text(L("Contéstala en tu hoja, con este número delante.", "Answer it on your sheet, with this number in front.",
                                   "Rispondi sul tuo foglio, con questo numero davanti."))
                                .font(.body)
                                .foregroundStyle(EstiloSecundario())
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    } else {
                        CampoRespuesta(texto: $respuesta, dictado: dictado, lineas: 4...10)
                    }
                }
            }
            .padding(Diseno.margen)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaBar(edge: .bottom) {
            let ultima = simulacro.actual + 1 >= total
            HStack(spacing: 12) {
                Button {
                    guardarRespuesta()
                    simulacro.anterior()
                    respuesta = simulacro.pregunta?.respuesta ?? ""
                } label: {
                    Image(systemName: "chevron.backward").font(.headline).frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .disabled(simulacro.actual == 0)
                .accessibilityLabel(L("Pregunta anterior", "Previous question", "Domanda precedente"))
                Button {
                    guardarRespuesta()
                    if ultima { simulacro.entregar() } else {
                        simulacro.siguiente()
                        respuesta = simulacro.pregunta?.respuesta ?? ""
                    }
                } label: {
                    Text(ultima ? L("Entregar", "Hand In", "Consegna") : L("Siguiente", "Next", "Avanti")).frame(maxWidth: .infinity)
                }
                .botonAmbar()
                .controlSize(.large)
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, 8)
        }
        .onChange(of: simulacro.tiempoAcabado) { _, acabado in
            if acabado {
                guardarRespuesta()
                simulacro.entregar()
            }
        }
    }

    private func guardarRespuesta() {
        dictado.parar()
        if simulacro.forma == .iPhone { simulacro.responder(respuesta) }
    }

    private var hoja: some View {
        VStack(spacing: 24) {
            Spacer()
            HootDice(frase: L("Lápiz fuera. Ahora hazle una foto a tu hoja, que la corrijo yo.", "Pencils down. Now take a photo of your sheet and I'll mark it.",
                              "Penne giù. Ora fai una foto al tuo foglio, che la correggo io."), gesto: .feliz, tamano: 120, paraguasSiLlueve: false)
            VStack(spacing: 12) {
                if EscanerDocumentos.disponible || ModoCapturas.activo {
                    Button { escaneando = true } label: {
                        Label(L("Escanear la hoja", "Scan the Sheet", "Scansiona il foglio"), systemImage: "doc.viewfinder").frame(maxWidth: .infinity)
                    }
                    .botonAmbar()
                    .controlSize(.large)
                }
                Button { eligiendo = true } label: {
                    Label(L("Elegir fotos", "Choose Photos", "Scegli foto"), systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.white.opacity(0.6))
                .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(Diseno.margen)
        .photosPicker(isPresented: $eligiendo, selection: $seleccion, maxSelectionCount: 20, matching: .images)
        .onChange(of: seleccion) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var imgs: [UIImage] = []
                for i in items { if let d = try? await i.loadTransferable(type: Data.self), let img = UIImage(data: d) { imgs.append(img) } }
                seleccion = []
                simulacro.leerHoja(imgs)
            }
        }
        .fullScreenCover(isPresented: $escaneando) {
            EscanerDocumentos { paginas in
                escaneando = false
                simulacro.leerHoja(paginas)
            }
            .ignoresSafeArea()
        }
    }

    private var revisando: some View {
        Form {
            Section {
                Text(L("Esto es lo que he leído. Si algo está mal, cámbialo antes de corregir.", "This is what I read. If something's wrong, fix it before marking.",
                       "Questo è quello che ho letto. Se qualcosa è sbagliato, cambialo prima di correggere."))
                    .foregroundStyle(EstiloSecundario())
                    .listRowBackground(Color.clear)
            }
            ForEach(Array(simulacro.preguntas.enumerated()), id: \.element.id) { i, p in
                Section {
                    TextField(text: Binding(get: { simulacro.preguntas[i].respuesta }, set: { v in simulacro.actual = i; simulacro.responder(v) }),
                              prompt: Indicacion.texto(L("Sin contestar", "Not answered", "Senza risposta")), axis: .vertical) {
                        Text(L("Respuesta", "Answer", "Risposta"))
                    }
                    .lineLimit(1...6)
                    .foregroundStyle(.white)
                } header: {
                    Text("\(i + 1). \(p.texto)").foregroundStyle(EstiloSecundario()).textCase(nil)
                }
                .filaTenida()
            }
        }
        .safeAreaBar(edge: .bottom) {
            HStack(spacing: 12) {
                Button { simulacro.volverAFotografiar() } label: {
                    Image(systemName: "camera").font(.headline).frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityLabel(L("Otra foto", "Another photo", "Un'altra foto"))
                Button { simulacro.corregir() } label: {
                    Text(L("Corregir", "Mark", "Correggi")).frame(maxWidth: .infinity)
                }
                .botonAmbar()
                .controlSize(.large)
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, 8)
        }
    }
}

private struct RelojSimulacro: View {
    var simulacro: SimulacroIA

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { contexto in
            let queda = max(0, (simulacro.fin ?? contexto.date).timeIntervalSince(contexto.date))
            HStack(spacing: 5) {
                Image(systemName: "timer")
                Text(EscuchaloVista.tiempo(queda))
            }
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .padding(.horizontal, 4)
                .foregroundStyle(queda < 300 ? Color.avisoCielo : .white)
                .contentTransition(.numericText(countsDown: true))
                .accessibilityLabel(L("Quedan \(EscuchaloVista.tiempo(queda))", "\(EscuchaloVista.tiempo(queda)) left", "Mancano \(EscuchaloVista.tiempo(queda))"))
        }
    }
}

private struct SimulacroOral: View {
    @Bindable var simulacro: SimulacroIA
    @State private var dictado = Dictado()
    @State private var voz = VozLobo()
    @State private var paso: Paso = .preguntando
    @State private var subtitulo = ""

    enum Paso { case preguntando, escuchando, repreguntando, escuchandoRepregunta, pensando }

    var body: some View {
        VStack(spacing: 18) {
            Text(L("Pregunta \(simulacro.actual + 1) de \(simulacro.preguntas.count)", "Question \(simulacro.actual + 1) of \(simulacro.preguntas.count)",
                   "Domanda \(simulacro.actual + 1) di \(simulacro.preguntas.count)"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EstiloSecundario())
            Spacer(minLength: 0)
            LoboInteractivo(tamano: 190, gesto: voz.hablando ? .hablando : (paso == .pensando ? .pensando : .normal))
            if !subtitulo.isEmpty {
                Bocadillo(texto: subtitulo, pico: .arriba)
                    .padding(.horizontal, Diseno.margen)
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                if dictado.escuchando {
                    Text(dictado.texto.isEmpty ? L("Te escucho", "I'm listening", "Ti ascolto") : "«\(dictado.texto)»")
                        .font(.body.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                } else if let e = dictado.error {
                    Text(e).font(.footnote).foregroundStyle(EstiloAviso(color: .pronto)).multilineTextAlignment(.center)
                } else {
                    Text(voz.hablando || ModoCapturas.activo ? L("Hoot pregunta…", "Hoot is asking…", "Hoot chiede…")
                                                             : (paso == .pensando ? L("Pensando…", "Thinking…", "Sto pensando…") : " "))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(EstiloSecundario())
                }
                BotonHablar(escuchando: dictado.escuchando, nivel: dictado.nivel) {
                    if dictado.escuchando { dictado.parar() } else if !voz.hablando { escuchar() }
                }
                .disabled(voz.hablando || paso == .pensando)
            }
            .padding(.horizontal, Diseno.margen)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.sobreCielo, true)
        .task { preguntar() }
        .onChange(of: voz.hablando) { antes, ahora in
            guard antes, !ahora else { return }
            escuchar()
        }
        .onChange(of: dictado.escuchando) { antes, ahora in
            guard antes, !ahora else { return }
            let t = dictado.texto.trimmingCharacters(in: .whitespacesAndNewlines)
            if paso == .escuchando {
                simulacro.responder(t)
                paso = .pensando
                Task {
                    let r = await simulacro.repreguntar()
                    if r.isEmpty { avanzar() } else {
                        paso = .repreguntando
                        decir(r)
                    }
                }
            } else if paso == .escuchandoRepregunta {
                simulacro.responderRepregunta(t)
                avanzar()
            }
        }
        .onDisappear {
            dictado.parar()
            voz.callar()
        }
    }

    private func preguntar() {
        guard let p = simulacro.pregunta else { return }
        paso = .preguntando
        decir(p.texto)
    }

    private func decir(_ t: String) {
        withAnimation(Diseno.muelle) { subtitulo = t }
        if ModoCapturas.activo { return }
        voz.decir(t)
    }

    private func escuchar() {
        guard !ModoCapturas.activo else { return }
        paso = paso == .repreguntando ? .escuchandoRepregunta : .escuchando
        dictado.pararAlCallar = true
        Task { await dictado.empezar(desde: "") }
    }

    private func avanzar() {
        if simulacro.actual + 1 < simulacro.preguntas.count {
            simulacro.siguiente()
            preguntar()
        } else {
            simulacro.entregar()
        }
    }
}

struct ResultadoSimulacro: View {
    @Bindable var simulacro: SimulacroIA
    var alTerminar: () -> Void

    @Environment(Almacen.self) private var almacen
    @Environment(\.tonoCielo) private var tono
    @Environment(\.dynamicTypeSize) private var letra
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @State private var apuntado = false
    @State private var lunasNuevas = false

    var body: some View {
        let cal = calendarioActual
        let bien = simulacro.preguntas.filter { !($0.correccion?.fallada ?? true) }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hoja
                HootDice(frase: FrasesHoot.simulacroCorregido(bien: bien, de: simulacro.preguntas.count), gesto: bien * 2 >= simulacro.preguntas.count ? .feliz : .pensando,
                         tamano: 96, paraguasSiLlueve: false)
                porTemas(cal: cal)
            }
            .padding(Diseno.margen)
        }
        .safeAreaBar(edge: .bottom) {
            Button(action: alTerminar) { Text(L("Hecho", "Done", "Fatto")).frame(maxWidth: .infinity) }
                .botonAmbar()
                .controlSize(.large)
                .padding(.horizontal, Diseno.margen)
                .padding(.bottom, 8)
        }
        .task {
            apuntar()

            if reducirMovimiento { lunasNuevas = true } else {
                try? await Task.sleep(for: .milliseconds(450))
                lunasNuevas = true
            }
        }
    }

    private func porTemas(cal: Calendar) -> some View {
        let ids = simulacro.preguntas.map(\.temaID).reduce(into: [UUID]()) { if !$0.contains($1) { $0.append($1) } }
        return VStack(alignment: .leading, spacing: 0) {
            TituloCielo(titulo: L("Por temas", "By topic", "Per argomento"), simbolo: "moonphase.first.quarter")
            ForEach(Array(ids.enumerated()), id: \.element) { n, id in
                if n > 0 { Separador() }
                let antes = simulacro.lunasAntes[id] ?? 0
                let ahora = almacen.datos.tema(id)?.luna(cal: cal).fraccion ?? antes
                HStack(spacing: 10) {
                    Luna(parte: antes, tamano: 24)
                    Image(systemName: "arrow.forward").font(.caption.weight(.bold)).foregroundStyle(EstiloSecundario())
                    Luna(parte: lunasNuevas ? ahora : antes, tamano: 24)
                        .animation(reducirMovimiento ? nil : Diseno.muelleRebote.delay(Double(n) * 0.15), value: lunasNuevas)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(simulacro.nombres[id] ?? "").font(.headline)
                        Text(ahora > antes ? L("Sube", "Up", "Sale") : (ahora < antes ? L("Baja · vuelve al plan", "Down · back in the plan", "Scende · torna nel piano")
                                                                                     : (ahora >= 1 ? L("Sigue llena", "Still full", "Ancora piena") : L("Igual", "Same", "Uguale"))))
                            .font(.subheadline)
                            .foregroundStyle(EstiloSecundario())
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, Diseno.margenTarjeta)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background((tono ?? TonoCielo.dia).fila.color, in: RoundedRectangle(cornerRadius: Diseno.radioModulo, style: .continuous))
    }

    private var hoja: some View {
        let rojo = Color(red: 0.84, green: 0.18, blue: 0.15)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text([simulacro.titulo, simulacro.curso].filter { !$0.isEmpty }.joined(separator: " · "))
                Spacer(minLength: 8)
                Text(almacen.perfil.nombre)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(white: 0.4))
            .padding(.bottom, 10)
            ForEach(Array(simulacro.preguntas.enumerated()), id: \.element.id) { i, p in
                if i > 0 { Rectangle().fill(Color(white: 0.88)).frame(height: 0.5).padding(.vertical, 10) }
                let disposicion = letra.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
                disposicion {
                    if letra.isAccessibilitySize { marca(p, rojo: rojo) }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(i + 1). \(p.texto)").font(.subheadline.weight(.semibold)).foregroundStyle(Color(white: 0.2))
                        Text(p.respuesta.isEmpty ? L("Sin contestar", "Not answered", "Senza risposta") : p.respuesta)
                            .font(.body)
                            .foregroundStyle(p.respuesta.isEmpty ? Color(white: 0.4) : Color(red: 0.13, green: 0.2, blue: 0.45))
                        if let v = p.correccion, v.fallada, !p.comentario.isEmpty {
                            Text(p.comentario)
                                .font(.custom("Noteworthy-Bold", size: 17, relativeTo: .body))
                                .foregroundStyle(rojo)
                                .rotationEffect(.degrees(-1.2))
                                .padding(.top, 2)
                        }
                    }
                    if !letra.isAccessibilitySize {
                        Spacer(minLength: 0)
                        marca(p, rojo: rojo)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.984, green: 0.98, blue: 0.965))
                .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
        }
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private func marca(_ p: SimulacroIA.Pregunta, rojo: Color) -> some View {
        if let v = p.correccion {
            Image(systemName: v.fallada ? (v == .incompleta ? "circle.lefthalf.filled" : "xmark") : "checkmark")
                .font(.title2.weight(.heavy))
                .foregroundStyle(rojo)
                .rotationEffect(.degrees(v.fallada ? 4 : -6))
                .accessibilityLabel(v.titulo)
        }
    }

    private func apuntar() {
        guard !apuntado, !ModoCapturas.activo else { return }
        apuntado = true
        let intentos = simulacro.intentos()
        var falladas: [UUID: [PreguntaFallada]] = [:]
        var acertadas: [UUID: Set<String>] = [:]
        for p in simulacro.preguntas {
            guard let v = p.correccion else { continue }
            if v.fallada { falladas[p.temaID, default: []].append(PreguntaFallada(pregunta: p.texto, esperada: p.esperada, fecha: Reloj.ahora)) }
            else { acertadas[p.temaID, default: []].insert(p.texto) }
        }
        conMuelle {
            for (id, intento) in intentos { almacen.datos.apuntar(intento, enTema: id) }
            for id in Set(falladas.keys).union(acertadas.keys) {
                almacen.datos.apuntarFalladas(falladas[id] ?? [], acertadas: acertadas[id] ?? [], enTema: id)
            }
            if let i = almacen.datos.pruebas.firstIndex(where: { $0.id == simulacro.pruebaID }) { almacen.datos.pruebas[i].ultimoSimulacro = Reloj.ahora }
        }
    }
}

private struct PresentarSimulacro: ViewModifier {
    @Binding var pruebaID: UUID?
    @State private var pendiente: SimulacroIA?
    @State private var simulacro: SimulacroIA?

    func body(content: Content) -> some View {
        content
            .sheet(item: Binding(get: { pruebaID.map { UUIDIdentificable(id: $0) } }, set: { pruebaID = $0?.id }), onDismiss: {
                if let s = pendiente {
                    simulacro = s
                    pendiente = nil
                }
            }) { p in
                EmpezarSimulacro(pruebaID: p.id) { pendiente = $0 }
            }
            .fullScreenCover(item: $simulacro) { s in
                SimulacroVista(simulacro: s) { simulacro = nil }
            }
    }
}

extension View {

    func simulacro(de pruebaID: Binding<UUID?>) -> some View {
        modifier(PresentarSimulacro(pruebaID: pruebaID))
    }
}

struct BotonHablar: View {
    var escuchando: Bool
    var nivel: Double
    var accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Image(systemName: escuchando ? "stop.fill" : "mic.fill")
                .font(.title.weight(.semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 76, height: 76)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .background {
            if escuchando {
                Circle()
                    .stroke(Color.ambar.opacity(0.6), lineWidth: 4)
                    .scaleEffect(1 + nivel * 0.6)
                    .animation(.spring(response: 0.18, dampingFraction: 1), value: nivel)
            }
        }
        .accessibilityLabel(escuchando ? L("He terminado", "I'm done", "Ho finito") : L("Hablar", "Speak", "Parla"))
        .sensoryFeedback(.impact(weight: .light), trigger: escuchando)
    }
}
