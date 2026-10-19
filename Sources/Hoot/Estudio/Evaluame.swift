import SwiftUI

enum ModoPrueba: String, Codable, CaseIterable, Identifiable, Sendable {

    case oral

    case pagina

    case tarjetas

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .oral: L("Oral", "Spoken", "Orale")
        case .pagina: L("Por escrito", "Written", "Scritta")
        case .tarjetas: L("Tarjetas", "Cards", "Carte")
        }
    }

    var simbolo: String {
        switch self {
        case .oral: "waveform"
        case .pagina: "doc.text"
        case .tarjetas: "rectangle.on.rectangle.angled"
        }
    }

    var explicacion: String {
        switch self {
        case .oral: L("El lobo pregunta en voz alta y contestas hablando.", "The wolf asks out loud and you answer by speaking.", "Il lupo chiede ad alta voce e rispondi parlando.")
        case .pagina: L("Una pregunta cada vez, como en un examen escrito.", "One question at a time, like a written test.", "Una domanda alla volta, come in una verifica scritta.")
        case .tarjetas: L("Cada pregunta es una tarjeta que va al montón de sabidas o de repasar.", "Each question is a card that goes to the known or review pile.", "Ogni domanda è una carta che va nel mazzo delle sapute o da ripassare.")
        }
    }
}

struct VistaPrueba: View {
    @Bindable var prueba: PruebaIA
    var alTerminar: () -> Void

    var alAcabar: (PruebaIA) -> Void = { _ in }
    @State private var saliendo = false
    @State private var porQue: CharlaHoot?
    @Environment(Almacen.self) private var almacen

    var body: some View {
        Group {
            switch prueba.fase {
            case .leyendo, .preparando:
                PreparandoPrueba(prueba: prueba)
            case .terminada:
                if prueba.esRepaso {
                    ResultadoRepaso(prueba: prueba, alTerminar: alTerminar)
                } else {
                    ResultadoPrueba(prueba: prueba, alNueva: { prueba.nuevaPrueba() }, alTerminar: alTerminar)
                }
            case .error(let m):
                ErrorPrueba(mensaje: m) { prueba.reintentar() }
            case .preguntando, .corrigiendo:
                switch prueba.modo {
                case .oral: PruebaOral(prueba: prueba)
                case .pagina: PruebaPagina(prueba: prueba)
                case .tarjetas: PruebaTarjetas(prueba: prueba)
                }
            }
        }
        .environment(\.porQue, abrirPorQue)
        .sheet(item: $porQue) { c in
            NavigationStack { CharlaVista(charla: c, alCerrar: { porQue = nil }, enHoja: true) }
                .presentationBackground { FondoHojaTenida() }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if prueba.fase != .terminada {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Salir", "Quit", "Esci")) {

                        if prueba.preguntas.contains(where: { $0.veredicto != nil }) {
                            saliendo = true
                        } else {
                            prueba.cancelar()
                            alTerminar()
                        }
                    }
                    .confirmationDialog(L("¿Salir de la prueba?", "Quit the quiz?", "Uscire dalla prova?"), isPresented: $saliendo, titleVisibility: .visible) {
                        Button(L("Salir", "Quit", "Esci"), role: .destructive) {
                            prueba.cancelar()
                            alTerminar()
                        }
                    } message: {
                        Text(L("Se pierde lo que llevas: no se guarda.", "What you've done so far is lost: it isn't saved.", "Si perde quello che hai fatto: non si salva."))
                    }
                }
            }
            if prueba.esRepaso, prueba.fase == .preguntando || prueba.fase == .corrigiendo, let id = prueba.pregunta?.temaID {
                ToolbarItem(placement: .principal) {
                    Text(prueba.nombresTemas[id] ?? "")
                        .font(.headline)
                        .lineLimit(1)
                }
            }
            if prueba.fase == .preguntando || prueba.fase == .corrigiendo {
                ToolbarItem(placement: .topBarTrailing) {

                    Menu {
                        Picker(L("Cómo te pregunta", "How it asks", "Come ti interroga"), selection: Binding(
                            get: { prueba.modo },
                            set: { m in
                                conMuelle { prueba.modo = m }
                                almacen.ajustes.modoPrueba = m
                            }
                        )) {
                            ForEach(ModoPrueba.allCases) { m in
                                Label(m.nombre, systemImage: m.simbolo).tag(m)
                            }
                        }
                    } label: {
                        Image(systemName: prueba.modo.simbolo)
                    }
                    .accessibilityLabel(L("Cómo te pregunta: \(prueba.modo.nombre)", "How it asks: \(prueba.modo.nombre)", "Come ti interroga: \(prueba.modo.nombre)"))
                }
            }
        }
        .sensoryFeedback(trigger: prueba.pregunta?.veredicto) { _, v in

            guard let v, !prueba.esRepaso else { return nil }
            return v.fallada ? .warning : .success
        }
        .onChange(of: prueba.pregunta?.veredicto) { _, v in
            guard prueba.esRepaso, let v else { return }

            if !v.fallada, let id = prueba.pregunta?.temaID, prueba.seLlenaAhora(id) {
                prueba.aullados.insert(id)
                Sonidos.compartido.tocar(.aullido)
            } else {
                Sonidos.compartido.tocar(v.fallada ? .fallo : .acierto)
            }
        }
        .onChange(of: prueba.fase) { _, f in
            if f == .terminada, !ModoCapturas.activo { alAcabar(prueba) }
        }
    }

    private func abrirPorQue(_ p: PreguntaPrueba) {
        let datos = almacen.datos
        let c: CharlaHoot
        if let id = p.temaID, let t = datos.tema(id) {
            let asignatura = datos.asignatura(datos.prueba(deTema: id)?.asignaturaID ?? datos.temasDeAhora.first { $0.tema.id == id }?.asignaturaID)
            c = CharlaHoot(tema: t, asignatura: asignatura, curso: almacen.perfil.curso)
        } else {
            let titulo = prueba.tema.trimmingCharacters(in: .whitespaces)
            c = CharlaHoot(origen: .suelta, titulo: titulo.isEmpty ? L("La pregunta", "The question", "La domanda") : titulo, asignatura: nil,
                           curso: almacen.perfil.curso, trozos: BuscarMaterial.trozos(prueba.material, etiqueta: L("Tu material", "Your material", "Il tuo materiale")))
        }
        c.porQue(pregunta: p.pregunta, esperada: p.esperada, dada: p.respuesta)
        porQue = c
    }
}

struct PreparandoPrueba: View {
    var prueba: PruebaIA

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            LoboTrabajando(tamano: 130, gesto: .pensando)
            Text(texto)
                .font(.headline)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(Diseno.margen)
    }

    private var texto: String {
        if case .leyendo(let i, let n) = prueba.fase {
            return n > 1 ? L("Leyendo la foto \(i) de \(n)", "Reading photo \(i) of \(n)", "Sto leggendo la foto \(i) di \(n)")
                         : L("Leyendo la foto", "Reading the photo", "Sto leggendo la foto")
        }
        return L("Preparando las preguntas", "Getting the questions ready", "Preparo le domande")
    }
}

struct ErrorPrueba: View {
    var mensaje: String
    var alReintentar: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Lobo(tamano: 110, gesto: .sorprendido)
            Text(mensaje)
                .font(.headline)
                .multilineTextAlignment(.center)
            Button(L("Intentarlo otra vez", "Try again", "Riprova"), action: alReintentar)
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        .padding(Diseno.margen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PuntosPrueba: View {
    var prueba: PruebaIA

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(prueba.preguntas.enumerated()), id: \.element.id) { i, p in
                if let v = p.veredicto {
                    Image(systemName: v.fallada ? (v == .incorrecta ? "xmark.circle.fill" : "minus.circle.fill") : "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(v.color)
                } else {
                    Capsule()
                        .fill(i == prueba.actual ? Color.primary : Color.primary.opacity(0.18))
                        .frame(width: i == prueba.actual ? 22 : 8, height: 8)
                        .animando(Diseno.muelle, valor: prueba.actual)
                }
            }
        }
        .frame(minHeight: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Pregunta \(prueba.actual + 1) de \(prueba.preguntas.count)", "Question \(prueba.actual + 1) of \(prueba.preguntas.count)", "Domanda \(prueba.actual + 1) di \(prueba.preguntas.count)"))
        .accessibilityValue(prueba.preguntas.compactMap(\.veredicto).map(\.titulo).joined(separator: ", "))
    }
}

private struct ClavePorQue: EnvironmentKey {
    nonisolated static let defaultValue: (@MainActor (PreguntaPrueba) -> Void)? = nil
}

extension EnvironmentValues {
    nonisolated var porQue: (@MainActor (PreguntaPrueba) -> Void)? {
        get { self[ClavePorQue.self] }
        set { self[ClavePorQue.self] = newValue }
    }
}

struct CorreccionVista: View {
    var pregunta: PreguntaPrueba
    var alineacion: HorizontalAlignment = .leading
    @Environment(\.porQue) private var porQue
    @Environment(\.colorScheme) private var esquema

    var body: some View {
        if let v = pregunta.veredicto {
            VStack(alignment: alineacion, spacing: 10) {
                Label(v.titulo, systemImage: v.simbolo)
                    .font(.headline)
                    .foregroundStyle(v.color)
                    .symbolEffect(.bounce, value: v)
                if !pregunta.comentario.isEmpty {
                    Text(pregunta.comentario)
                        .font(.body)
                        .multilineTextAlignment(alineacion == .center ? .center : .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !pregunta.consejo.isEmpty {
                    Label {
                        Text(pregunta.consejo)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: v == .consejo ? "text.bubble" : "plus.bubble")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.texto2)
                }
                if v.fallada {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("La respuesta", "The answer", "La risposta"))
                            .font(.subheadline.weight(.semibold))
                        Text(pregunta.esperada)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                    if let porQue, DisponibilidadIA.actual == .lista {
                        Button { porQue(pregunta) } label: {
                            Label(L("¿Por qué?", "Why?", "Perché?"), systemImage: "bubble.left.and.text.bubble.right.fill")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(esquema == .dark ? .white.opacity(0.6) : Color.acento)
                        .foregroundStyle(esquema == .dark ? Color.white : Color.acento)
                        .padding(.top, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: alineacion == .center ? .center : .leading)
            .accessibilityElement(children: .contain)
        }
    }
}

struct CampoRespuesta: View {
    @Binding var texto: String
    var dictado: Dictado
    var lineas: ClosedRange<Int> = 3...8
    @FocusState private var foco: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(text: $texto, prompt: Indicacion.texto(L("Tu respuesta", "Your answer", "La tua risposta")), axis: .vertical) {
                Text(L("Tu respuesta", "Your answer", "La tua risposta"))
            }
                .lineLimit(lineas)
                .focused($foco)
                .padding(.vertical, 12)
                .padding(.leading, 14)
            BotonMicro(dictado: dictado, texto: $texto, pequeno: true)
                .padding(.bottom, 4)
                .padding(.trailing, 4)
        }
        .background(Color.relleno, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onChange(of: dictado.texto) { _, t in if dictado.escuchando { texto = t } }
    }
}

struct BotonMicro: View {
    var dictado: Dictado
    @Binding var texto: String
    var pequeno = false
    @Environment(\.sobreCielo) private var sobreCielo

    var body: some View {
        Button {
            if dictado.escuchando {
                dictado.parar()
            } else {
                Task { await dictado.empezar(desde: texto) }
            }
        } label: {
            Image(systemName: dictado.escuchando ? "stop.fill" : "mic.fill")
                .font(pequeno ? .body.weight(.semibold) : .title.weight(.semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: pequeno ? 36 : 76, height: pequeno ? 36 : 76)
        }
        .modifier(EstiloMicro(escuchando: dictado.escuchando, sobreCielo: sobreCielo))
        .buttonBorderShape(.circle)
        .background {

            if dictado.escuchando {
                Circle()
                    .stroke(Color.acento.opacity(0.6), lineWidth: 4)
                    .scaleEffect(1 + dictado.nivel * (pequeno ? 0.5 : 0.6))
                    .animation(.spring(response: 0.18, dampingFraction: 1), value: dictado.nivel)
            }
        }
        .accessibilityLabel(dictado.escuchando ? L("Parar el dictado", "Stop dictation", "Ferma la dettatura") : L("Contestar hablando", "Answer by speaking", "Rispondi parlando"))
        .sensoryFeedback(.impact(weight: .light), trigger: dictado.escuchando)
    }
}

struct PruebaOral: View {
    @Bindable var prueba: PruebaIA
    @State private var dictado = Dictado()
    @State private var voz = VozLobo()
    @State private var respuesta = ""
    @State private var escribiendo = false
    @AppStorage("hoot.evaluame.voz") private var conVoz = true
    @FocusState private var foco: Bool
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        let p = prueba.pregunta
        ScrollView {
            VStack(spacing: 18) {
                PuntosPrueba(prueba: prueba)
                    .padding(.top, 4)
                if prueba.esRepaso, let id = p?.temaID {
                    LunaDelRepaso(prueba: prueba, temaID: id, gesto: gesto)
                        .padding(.top, 2)
                } else {
                    LoboInteractivo(tamano: 112, gesto: gesto, saludo: prueba.pregunta?.veredicto.map { $0.fallada ? nil : .saltando } ?? nil)
                        .padding(.top, 6)
                }
                if let p {
                    Text(p.pregunta)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(p.id)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    if prueba.conSeguridad && !prueba.corregida {
                        SelectorSeguridad(prueba: prueba)
                    }

                    if escribiendo && !prueba.corregida {
                        TextField(L("Tu respuesta", "Your answer", "La tua risposta"), text: $respuesta, axis: .vertical)
                            .lineLimit(3...8)
                            .focused($foco)
                            .padding(14)
                            .background(Color.relleno, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    } else if !respuesta.isEmpty || !(p.respuesta.isEmpty) {
                        Text(prueba.corregida ? p.respuesta : respuesta)
                            .font(.title3)
                            .foregroundStyle(dictado.escuchando ? Color.texto2 : Color.primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(Color.relleno, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .padding(.top, 4)
                    } else {
                        Text(L("Toca el micrófono y contesta", "Tap the microphone and answer", "Tocca il microfono e rispondi"))
                            .font(.body)
                            .textoSecundario()
                    }
                    if prueba.fase == .corrigiendo {
                        ProgressView().padding(.top, 6)
                    }
                    CorreccionVista(pregunta: p, alineacion: .center)
                        .padding(.top, 6)
                    if prueba.esRepaso, let v = p.veredicto {
                        Bocadillo(texto: v.fallada ? FrasesHoot.fallo(semilla: prueba.actual) : FrasesHoot.acierto(semilla: prueba.actual),
                                  pico: .arribaIzquierda)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.scale(scale: 0.9, anchor: .topLeading).combined(with: .opacity))
                    }
                    if let e = dictado.error {
                        Text(e).font(.footnote).foregroundStyle(Color.urgente).multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaBar(edge: .bottom) { barra }
        .navigationTitle(L("Evalúame", "Quiz me", "Interrogami"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    conVoz.toggle()
                    if !conVoz { voz.callar() }
                } label: {
                    Image(systemName: conVoz ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .accessibilityLabel(conVoz ? L("Quitar la voz", "Turn voice off", "Togli la voce") : L("Poner la voz", "Turn voice on", "Attiva la voce"))
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        .onAppear {
            if respuesta.isEmpty { respuesta = prueba.borrador }
            leer()
        }
        .onChange(of: prueba.actual) { _, _ in
            respuesta = ""
            escribiendo = false
            leer()
        }
        .onChange(of: dictado.texto) { _, t in if dictado.escuchando { respuesta = t } }

        .onChange(of: dictado.escuchando) { _, escucha in if escucha { voz.callar() } }
        .onDisappear {
            voz.callar()
            dictado.parar()
        }
    }

    private var gesto: GestoLobo {
        if voz.hablando { return .hablando }
        guard let v = prueba.pregunta?.veredicto else { return .normal }
        if let id = prueba.pregunta?.temaID, prueba.aullados.contains(id), !v.fallada { return .aullando }
        return v.fallada ? .sorprendido : .feliz
    }

    private func leer() {
        guard conVoz, !ModoCapturas.activo, let p = prueba.pregunta else { return }
        voz.decir(p.pregunta)
    }

    @ViewBuilder
    private var barra: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
                if prueba.corregida {
                    Button {
                        prueba.siguiente()
                    } label: {
                        Text(prueba.actual + 1 < prueba.preguntas.count ? L("Siguiente pregunta", "Next question", "Domanda successiva") : (prueba.esRepaso ? L("Ver tus lunas", "See your moons", "Vedi le tue lune") : L("Ver la nota", "See my grade", "Vedi il voto")))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)
                    .tint(Color.acentoRelleno)
                } else {
                    Button {
                        conMuelle { escribiendo.toggle() }
                        foco = escribiendo
                    } label: {
                        Image(systemName: escribiendo ? "waveform" : "keyboard")
                            .font(.title3.weight(.semibold))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .accessibilityLabel(escribiendo ? L("Contestar hablando", "Answer by speaking", "Rispondi parlando") : L("Contestar escribiendo", "Answer by typing", "Rispondi scrivendo"))
                    BotonMicro(dictado: dictado, texto: $respuesta)
                    Button {
                        dictado.parar()
                        voz.callar()
                        prueba.comprobar(respuesta)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.title3.weight(.bold))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .tint(Color.hecho)
                    .disabled(respuesta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || prueba.fase == .corrigiendo)
                    .accessibilityLabel(L("Comprobar", "Check", "Verifica"))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Diseno.margen)
        .padding(.bottom, 8)
    }
}

struct PruebaPagina: View {
    @Bindable var prueba: PruebaIA
    @State private var dictado = Dictado()
    @State private var respuesta = ""

    var body: some View {
        ScrollView {
            if let p = prueba.pregunta {
                VStack(alignment: .leading, spacing: 18) {
                    ProgressView(value: Double(prueba.actual + (prueba.corregida ? 1 : 0)), total: Double(max(prueba.preguntas.count, 1)))
                        .tint(Color.acento)
                        .animando(Diseno.muelle, valor: prueba.actual)
                        .accessibilityLabel(L("Pregunta \(prueba.actual + 1) de \(prueba.preguntas.count)", "Question \(prueba.actual + 1) of \(prueba.preguntas.count)", "Domanda \(prueba.actual + 1) di \(prueba.preguntas.count)"))
                    if prueba.esRepaso, let id = p.temaID {
                        LunaDelRepaso(prueba: prueba, temaID: id, gesto: prueba.pregunta?.veredicto.map { $0.fallada ? .sorprendido : .feliz } ?? .normal)
                            .frame(maxWidth: .infinity)
                    }
                    HStack(alignment: .top, spacing: 12) {
                        Lobo(tamano: 44, gesto: prueba.pregunta?.veredicto.map { $0.fallada ? .sorprendido : .feliz } ?? .normal)
                        Text(p.pregunta)
                            .font(.title2.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .id(p.id)
                    if prueba.conSeguridad && !prueba.corregida {
                        SelectorSeguridad(prueba: prueba)
                    }
                    if prueba.corregida {
                        Text(p.respuesta)
                            .font(.body)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.relleno, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    } else {
                        CampoRespuesta(texto: $respuesta, dictado: dictado, lineas: 4...10)
                    }
                    if prueba.fase == .corrigiendo {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(L("Corrigiendo", "Checking", "Correggo")).textoSecundario()
                        }
                    }
                    CorreccionVista(pregunta: p)
                    if let e = dictado.error {
                        Text(e).font(.footnote).foregroundStyle(Color.urgente)
                    }
                }
                .padding(Diseno.margen)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { if respuesta.isEmpty { respuesta = prueba.borrador } }
        .navigationTitle(L("Evalúame", "Quiz me", "Interrogami"))
        .safeAreaBar(edge: .bottom) {
            Button {
                if prueba.corregida {
                    prueba.siguiente()
                } else {
                    dictado.parar()
                    prueba.comprobar(respuesta)
                }
            } label: {
                Text(prueba.corregida
                     ? (prueba.actual + 1 < prueba.preguntas.count ? L("Siguiente", "Next", "Avanti") : (prueba.esRepaso ? L("Ver tus lunas", "See your moons", "Vedi le tue lune") : L("Ver la nota", "See my grade", "Vedi il voto")))
                     : L("Comprobar", "Check", "Verifica"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .tint(Color.acentoRelleno)
            .disabled(!prueba.corregida && (respuesta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || prueba.fase == .corrigiendo))
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, 8)
        }
        .onChange(of: prueba.actual) { _, _ in respuesta = "" }
        .onDisappear { dictado.parar() }
    }
}

struct PruebaTarjetas: View {
    @Bindable var prueba: PruebaIA
    @State private var dictado = Dictado()
    @State private var respuesta = ""
    @State private var volando: (indice: Int, haciaSabidas: Bool)?
    @State private var arrastre: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        GeometryReader { geo in
            let ancho = geo.size.width - 2 * Diseno.margen
            VStack(spacing: 18) {
                ZStack {

                    let quedan = max(0, prueba.preguntas.count - prueba.actual - 1)
                    ForEach(0..<min(quedan, 2), id: \.self) { k in
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                            .frame(width: ancho - CGFloat(k + 1) * 18, height: alto(geo))
                            .offset(y: CGFloat(k + 1) * 12)
                            .zIndex(Double(-k - 1))
                    }
                    if let p = prueba.pregunta {
                        Tarjeta(pregunta: p, corrigiendo: prueba.fase == .corrigiendo)
                            .frame(width: ancho, height: alto(geo))
                            .offset(arrastre)
                            .rotationEffect(.degrees(Double(arrastre.width) / 24))
                            .gesture(prueba.corregida ? lanzar(geo) : nil)
                            .id(p.id)
                            .transition(.asymmetric(insertion: .scale(scale: 0.94).combined(with: .opacity), removal: .identity))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                Montones(prueba: prueba)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Diseno.margen)
        }
        .navigationTitle(L("Evalúame", "Quiz me", "Interrogami"))
        .onAppear { if respuesta.isEmpty { respuesta = prueba.borrador } }
        .safeAreaBar(edge: .bottom) {
            Group {
                if prueba.corregida {
                    Button { enviar(sabida: !(prueba.pregunta?.veredicto?.fallada ?? false), velocidad: .zero) } label: {
                        Text(prueba.actual + 1 < prueba.preguntas.count ? L("Siguiente tarjeta", "Next card", "Carta successiva") : (prueba.esRepaso ? L("Ver tus lunas", "See your moons", "Vedi le tue lune") : L("Ver la nota", "See my grade", "Vedi il voto")))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)
                    .tint(Color.acentoRelleno)
                } else {
                    HStack(alignment: .bottom, spacing: 10) {
                        CampoRespuesta(texto: $respuesta, dictado: dictado, lineas: 1...4)
                        Button {
                            dictado.parar()
                            prueba.comprobar(respuesta)
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.headline.weight(.bold))
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                        .tint(Color.acentoRelleno)
                        .disabled(respuesta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || prueba.fase == .corrigiendo)
                        .accessibilityLabel(L("Comprobar", "Check", "Verifica"))
                    }
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, 8)
        }
        .onChange(of: prueba.actual) { _, _ in respuesta = "" }
        .onDisappear { dictado.parar() }
    }

    private func alto(_ geo: GeometryProxy) -> CGFloat {
        min(geo.size.height * 0.62, 460)
    }

    private func lanzar(_ geo: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { v in arrastre = v.translation }
            .onEnded { v in
                let rapida = hypot(v.velocity.width, v.velocity.height) > 500 || hypot(v.translation.width, v.translation.height) > 120
                if rapida {
                    enviar(sabida: !(prueba.pregunta?.veredicto?.fallada ?? false), velocidad: v.velocity)
                } else {
                    withAnimation(Diseno.muelleGesto) { arrastre = .zero }
                }
            }
    }

    private func enviar(sabida: Bool, velocidad: CGSize) {
        let destino = CGSize(width: sabida ? 260 : -260, height: 520)
        if reducirMovimiento {
            arrastre = .zero
            prueba.siguiente()
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { arrastre = destino }
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            arrastre = .zero
            prueba.siguiente()
        }
    }
}

private struct Tarjeta: View {
    var pregunta: PreguntaPrueba
    var corrigiendo: Bool

    var body: some View {
        let girada = pregunta.veredicto != nil
        ZStack {

            VStack(spacing: 16) {
                Lobo(tamano: 54)
                Text(pregunta.pregunta)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                if corrigiendo { ProgressView() }
            }
            .padding(26)
            .opacity(girada ? 0 : 1)

            ScrollView {
                VStack(spacing: 14) {
                    Text(pregunta.pregunta)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text(pregunta.respuesta)
                        .font(.body)
                        .foregroundStyle(Color.texto2)
                        .multilineTextAlignment(.center)
                    CorreccionVista(pregunta: pregunta, alineacion: .center)
                }
                .padding(24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .opacity(girada ? 1 : 0)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke((pregunta.veredicto?.color ?? .clear).opacity(0.9), lineWidth: 3)
        }
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        .rotation3DEffect(.degrees(girada ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: girada)
    }
}

private struct Montones: View {
    var prueba: PruebaIA

    var body: some View {
        let hechas = prueba.preguntas.prefix(prueba.corregida ? prueba.actual : prueba.actual)
        let repasar = hechas.filter { $0.veredicto?.fallada == true }.count
        let sabidas = hechas.count - repasar
        HStack {
            monton(L("Para repasar", "To review", "Da ripassare"), repasar, Color.pronto, "arrow.counterclockwise")
            Spacer()
            monton(L("Sabidas", "Known", "Sapute"), sabidas, Color.hecho, "checkmark")
        }
    }

    private func monton(_ titulo: String, _ n: Int, _ color: Color, _ simbolo: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                ForEach(0..<min(n, 3), id: \.self) { k in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(color.opacity(0.85 - Double(k) * 0.2))
                        .frame(width: 30, height: 40)
                        .rotationEffect(.degrees(Double(k) * 7 - 7))
                }
                if n == 0 {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(color.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .frame(width: 30, height: 40)
                }
            }
            .frame(width: 44, height: 48)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(n)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .contentTransition(.numericText())
                Text(titulo)
                    .font(.caption)
                    .textoSecundario()
            }
        }
        .accessibilityElement(children: .combine)
        .animando(Diseno.muelleRebote, valor: n)
    }
}

struct ResultadoPrueba: View {
    var prueba: PruebaIA
    var alNueva: () -> Void
    var alTerminar: () -> Void
    @Environment(Almacen.self) private var almacen
    @Environment(\.dynamicTypeSize) private var letra
    @ScaledMetric(relativeTo: .largeTitle) private var lado: CGFloat = 132

    var body: some View {
        let escala = almacen.ajustes.escala
        let media = prueba.guardada.nota ?? 0
        let nota = escala.desdeDiez(media)
        let aprueba = escala.aprueba(nota)
        List {
            Section {
                VStack(spacing: 12) {
                    ZStack {
                        Anillo(progreso: media / 10, color: aprueba ? Color.hecho : Color.urgente, grosor: 10)
                        VStack(spacing: -2) {
                            Text(Formato.numero(nota))
                                .font(.largeTitle.weight(.bold).monospacedDigit())
                                .fontDesign(.rounded)
                            Text(L("de \(Formato.numero(escala.mayorEsMejor ? escala.maximo : escala.minimo, decimales: 0))", "out of \(Formato.numero(escala.mayorEsMejor ? escala.maximo : escala.minimo, decimales: 0))", "su \(Formato.numero(escala.mayorEsMejor ? escala.maximo : escala.minimo, decimales: 0))"))
                                .font(.caption.weight(.semibold))
                                .textoSecundario()
                        }
                    }
                    .frame(width: min(lado, 180), height: min(lado, 180))
                    Text(frase(aprueba: aprueba))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .accessibilityElement(children: .combine)
            }
            if !prueba.falladas.isEmpty {
                Section(L("Para repasar", "To review", "Da ripassare")) {
                    ForEach(prueba.falladas) { p in fila(p, abierta: true) }
                }
            }
            let bien = prueba.preguntas.filter { $0.veredicto.map { !$0.fallada } ?? false }
            if !bien.isEmpty {
                Section(L("Bien", "Good", "Bene")) {
                    ForEach(bien) { p in fila(p, abierta: false) }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(L("Tu nota", "Your grade", "Il tuo voto"))
        .safeAreaBar(edge: .bottom) {
            let disposicion = letra.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 12))

            disposicion {
                if letra.isAccessibilitySize { botonNueva }
                Button(action: alTerminar) {
                    Text(L("Terminar", "Done", "Fine")).font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.extraLarge)
                if !letra.isAccessibilitySize { botonNueva }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, 8)
        }
    }

    private var botonNueva: some View {
        Button(action: alNueva) {
            Label(L("Otra prueba", "New test", "Altra verifica"), systemImage: "arrow.clockwise")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.extraLarge)
        .tint(Color.acentoRelleno)
    }

    private func frase(aprueba: Bool) -> String {
        let n = prueba.falladas.count
        if n == 0 { return L("Todo bien. Estás listo para el examen.", "All good. You're ready for the test.", "Tutto bene. Sei pronto per la verifica.") }
        return aprueba
            ? L("Aprobado. Repasa \(n == 1 ? "una pregunta" : "\(n) preguntas") y lo tienes.", "Passed. Review \(n == 1 ? "one question" : "\(n) questions") and you've got it.", "Promosso. Ripassa \(n == 1 ? "una domanda" : "\(n) domande") e ci sei.")
            : L("Aún no. Repasa estas preguntas y haz otra prueba.", "Not yet. Review these questions and try another test.", "Non ancora. Ripassa queste domande e fai un'altra verifica.")
    }

    @ViewBuilder
    private func fila(_ p: PreguntaPrueba, abierta: Bool) -> some View {
        if abierta {
            VStack(alignment: .leading, spacing: 8) {
                Text(p.pregunta).font(.headline)
                Text(p.respuesta).font(.subheadline).textoSecundario()
                CorreccionVista(pregunta: p)
            }
            .padding(.vertical, 4)
        } else {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    Text(p.respuesta).font(.subheadline).textoSecundario()
                    CorreccionVista(pregunta: p)
                }
                .padding(.vertical, 4)
            } label: {
                Label {
                    Text(p.pregunta).lineLimit(2)
                } icon: {
                    Image(systemName: p.veredicto?.simbolo ?? "circle")
                        .foregroundStyle(p.veredicto?.color ?? .gray)
                }
            }
        }
    }
}

struct PruebaGuardadaVista: View {
    var estudio: EstudioGuardado
    var guardada: PruebaGuardada
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var volver
    @State private var vista = PruebaIA()
    @State private var nueva: PruebaIA?

    var body: some View {
        ResultadoPrueba(prueba: vista, alNueva: empezarOtra, alTerminar: { volver() })
            .onAppear {
                vista.preguntas = guardada.preguntas
                vista.fase = .terminada
            }
            .fullScreenCover(item: $nueva) { p in
                NavigationStack {
                    VistaPrueba(prueba: p, alTerminar: { nueva = nil }, alAcabar: guardar)
                }
            }
    }

    private func empezarOtra() {
        let p = PruebaIA()
        p.material = estudio.textoLeido
        p.anteriores = guardada.preguntas.map(\.pregunta)
        p.asignatura = almacen.datos.asignatura(estudio.asignaturaID)?.nombre
        p.curso = almacen.perfil.curso
        p.tema = estudio.titulo
        p.modo = almacen.ajustes.modoPrueba
        p.nuevaPrueba()
        nueva = p
    }

    private func guardar(_ p: PruebaIA) {
        let g = p.guardada
        let nota = g.nota.map { Formato.numero(almacen.ajustes.escala.desdeDiez($0)) } ?? ""
        let resumen = p.preguntas.map { "- \($0.veredicto?.fallada == true ? "✗" : "✓") \($0.pregunta)" }.joined(separator: "\n")
        almacen.estudios.insert(EstudioGuardado(tipo: .evaluar, titulo: estudio.titulo, asignaturaID: estudio.asignaturaID, fecha: Reloj.ahora,
                                                resultado: L("## Nota: \(nota)\n\(resumen)", "## Grade: \(nota)\n\(resumen)", "## Voto: \(nota)\n\(resumen)"),
                                                textoLeido: p.material, miniaturas: estudio.miniaturas, prueba: g), at: 0)
    }
}

extension PruebaIA: Identifiable {
    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }
}

struct LunaDelRepaso: View {
    @Bindable var prueba: PruebaIA
    var temaID: UUID
    var gesto: GestoLobo
    @ScaledMetric(relativeTo: .largeTitle) private var lado: CGFloat = 132
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        let parte = prueba.parteEnVivo(temaID)
        let acierto = prueba.corregida && prueba.pregunta?.veredicto.map { !$0.fallada } == true
        ZStack(alignment: .bottomTrailing) {
            Luna(parte: parte, tamano: min(lado, 170), brillo: acierto || parte >= 0.999)
                .animation(reducirMovimiento ? nil : Diseno.muelleRebote, value: parte)
                .padding(.trailing, 34)
            Lobo(tamano: min(lado, 170) * 0.5, gesto: gesto)
                .offset(x: 6, y: 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(prueba.nombresTemas[temaID] ?? ""): \(Luna.nombre(parte))")
    }
}

private struct EstiloMicro: ViewModifier {
    var escuchando: Bool
    var sobreCielo: Bool

    func body(content: Content) -> some View {
        if escuchando {
            content.buttonStyle(.glassProminent).tint(Color.urgente)
        } else if sobreCielo {
            content.buttonStyle(.glass).foregroundStyle(.white)
        } else {
            content.buttonStyle(.glassProminent).tint(Color.acentoRelleno)
        }
    }
}
