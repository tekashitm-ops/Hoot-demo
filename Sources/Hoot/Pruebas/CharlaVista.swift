import SwiftUI
import PhotosUI

struct CharlaVista: View {
    @State var charla: CharlaHoot

    var alCerrar: (() -> Void)?

    var enHoja = false

    @Environment(Almacen.self) private var almacen
    @State private var texto = ""
    @FocusState private var foco: Bool
    @State private var dictado = Dictado()
    @State private var hablando = false
    @State private var eligiendo = false
    @State private var seleccion: [PhotosPickerItem] = []
    @State private var escaneando = false
    @State private var fotografiando = false
    @ScaledMetric(relativeTo: .body) private var caraEscalada: CGFloat = 30
    private var cara: CGFloat { min(caraEscalada, 44) }

    var body: some View {
        ScrollViewReader { lector in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if charla.mensajes.isEmpty && !charla.escribiendo && !charla.leyendoFoto {
                        vacio
                    }
                    ForEach(Array(charla.mensajes.enumerated()), id: \.element.id) { i, m in
                        let siguiente = i + 1 < charla.mensajes.count ? charla.mensajes[i + 1] : nil
                        let ultimoDelGrupo = siguiente?.quien != m.quien && !(m.quien == .hoot && charla.escribiendo && siguiente == nil)
                        fila(m, cara: m.quien == .hoot && ultimoDelGrupo)
                            .padding(.top, i > 0 && charla.mensajes[i - 1].quien != m.quien ? 10 : 0)
                    }
                    if charla.leyendoFoto {
                        HStack(spacing: 8) {
                            Spacer(minLength: 48)
                            ProgressView()
                            Text(ControlMaterial.leyendoFoto(charla.fotosLeidas.actual, charla.fotosLeidas.total))
                                .font(.subheadline)
                                .foregroundStyle(EstiloSecundario())
                                .contentTransition(.numericText())
                        }
                        .padding(.top, 10)
                    }
                    if charla.escribiendo { enDirecto.padding(.top, 10) }
                    if let aviso = charla.aviso {
                        Label(aviso, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(EstiloAviso(color: .pronto))
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                    }
                    Color.clear.frame(height: 1).id("fin")
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: charla.mensajes.count) { _, _ in
                withAnimation(Diseno.muelle) { lector.scrollTo("fin", anchor: .bottom) }
                guardar()
            }
            .onChange(of: charla.parcial) { _, _ in lector.scrollTo("fin", anchor: .bottom) }
        }
        .safeAreaBar(edge: .bottom) { barra }
        .tenidaDelCielo(hoja: enHoja)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle(charla.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            TituloBarra(titulo: charla.titulo, subtitulo: subtitulo)
            if let alCerrar {
                ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar(alCerrar) } }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { hablando = true } label: {
                    Label(L("Hablar", "Talk", "Parla"), systemImage: "waveform")
                }
                .disabled(DisponibilidadIA.actual != .lista)
            }
        }
        .fullScreenCover(isPresented: $hablando) {
            HablarConHoot(charla: charla) { hablando = false }
        }
        .photosPicker(isPresented: $eligiendo, selection: $seleccion, maxSelectionCount: Self.maximoFotos, selectionBehavior: .ordered, matching: .images)
        .onChange(of: seleccion) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var imagenes: [UIImage] = []
                for item in items {
                    if let datos = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: datos) { imagenes.append(img) }
                }
                seleccion = []
                mandarFotos(imagenes)
            }
        }
        .fullScreenCover(isPresented: $escaneando) {
            EscanerDocumentos { paginas in
                escaneando = false
                mandarFotos(paginas)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $fotografiando) {
            CamaraFoto { foto in
                fotografiando = false
                if let foto { mandarFotos([foto]) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: dictado.texto) { _, t in if dictado.escuchando { texto = t } }
        .onDisappear {
            dictado.parar()
            if alCerrar == nil { guardarEnEstudio() }
        }
    }

    private var subtitulo: String {
        if case .suelta = charla.origen { return charla.asignatura ?? "" }
        return charla.asignatura ?? L("Pregúntale a Hoot", "Ask Hoot", "Chiedi a Hoot")
    }

    @ViewBuilder
    private func fila(_ m: MensajeCharla, cara conCara: Bool) -> some View {
        if m.quien == .yo {
            VStack(alignment: .trailing, spacing: 4) {
                let fotos = m.fotos.compactMap(UIImage.init(data:))
                if fotos.count == 1 {
                    Image(uiImage: fotos[0])
                        .resizable()
                        .scaledToFill()
                        .frame(width: 168, height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .accessibilityLabel(L("Tu foto", "Your photo", "La tua foto"))
                } else if fotos.count > 1 {
                    MosaicoFotos(fotos: fotos)
                }
                if !m.texto.isEmpty {
                    Text(m.texto)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.18), in: UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20,
                                                                                       bottomTrailingRadius: 6, topTrailingRadius: 20, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 48)
        } else {
            globoHoot(m.texto, fuente: m.fuente, cara: conCara)
        }
    }

    private func globoHoot(_ texto: String, fuente: String, cara conCara: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            Group {
                if conCara {
                    Avatar(tamano: cara, estilo: .lobo, color: .azul, iniciales: "", foto: nil)
                } else {
                    Color.clear
                }
            }
            .frame(width: cara, height: cara)
            VStack(alignment: .leading, spacing: 5) {
                Text(Self.conNegritas(texto))
                    .font(.body.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.tintaBocadillo)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 6,
                                                                   bottomTrailingRadius: 20, topTrailingRadius: 20, style: .continuous))
                if !fuente.isEmpty {
                    Label(fuente, systemImage: "book.closed")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(EstiloSecundario())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.12), in: Capsule())
                        .accessibilityLabel(L("De: \(fuente)", "From: \(fuente)", "Da: \(fuente)"))
                }
            }
            Spacer(minLength: 40)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var enDirecto: some View {
        if charla.parcial.isEmpty {
            HStack(alignment: .bottom, spacing: 8) {
                Avatar(tamano: cara, estilo: .lobo, color: .azul, iniciales: "", foto: nil)
                PuntosEscribiendo()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 6,
                                                                   bottomTrailingRadius: 20, topTrailingRadius: 20, style: .continuous))
                    .accessibilityLabel(L("Hoot está escribiendo", "Hoot is typing", "Hoot sta scrivendo"))
                Spacer()
            }
        } else {
            let (respuesta, deVuelta) = CharlaHoot.partir(charla.parcial)
            VStack(alignment: .leading, spacing: 4) {
                globoHoot(respuesta, fuente: "", cara: deVuelta == nil)
                if let deVuelta { globoHoot(deVuelta, fuente: "", cara: true) }
            }
        }
    }

    private var vacio: some View {
        VStack(alignment: .leading, spacing: 16) {
            HootDice(frase: fraseVacia, gesto: .normal, tamano: 104, paraguasSiLlueve: false)
            if case .suelta = charla.origen {
                HStack(spacing: 10) {
                    if EscanerDocumentos.disponible || ModoCapturas.activo {
                        Button { escaneando = true } label: { baldosa(L("Escanear", "Scan", "Scansiona"), "doc.viewfinder") }
                    } else if CamaraFoto.disponible {
                        Button { fotografiando = true } label: { baldosa(L("Cámara", "Camera", "Fotocamera"), "camera") }
                    }
                    Button { eligiendo = true } label: { baldosa(L("Fotos", "Photos", "Foto"), "photo.on.rectangle") }
                }
                .botonTenido()
            } else if charla.hayMaterial {
                FlowSugerencias(sugerencias: sugerencias) { charla.enviar($0) }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    private var fraseVacia: String {
        if case .suelta = charla.origen {
            return L("Hazle una foto a lo que no entiendes. O escríbemelo, que también leo.",
                     "Take a photo of what you don't get. Or type it, I read too.",
                     "Fai una foto a quello che non capisci. O scrivimelo, che leggo anche.")
        }
        if !charla.hayMaterial {
            return L("Sin material de este tema no sé de qué hablar. Dale fotos o un PDF y vuelve.",
                     "Without material for this topic I've got nothing to say. Give it photos or a PDF and come back.",
                     "Senza materiale di questo argomento non so di cosa parlare. Dagli foto o un PDF e torna.")
        }
        return L("Pregúntame lo que quieras de \(FrasesHoot.enFrase(charla.titulo)). Lo saco de tu material.",
                 "Ask me anything about \(FrasesHoot.enFrase(charla.titulo)). I take it from your material.",
                 "Chiedimi quello che vuoi su \(FrasesHoot.enFrase(charla.titulo)). Lo prendo dal tuo materiale.")
    }

    private var sugerencias: [String] {
        [L("Explícamelo fácil", "Explain it simply", "Spiegamelo facile"),
         L("¿Qué es lo más importante?", "What matters most?", "Qual è la cosa più importante?"),
         L("Pregúntame tú", "Quiz me", "Fammi tu una domanda")]
    }

    private func baldosa(_ titulo: String, _ simbolo: String) -> some View {
        BaldosaTenida(titulo: titulo, simbolo: simbolo)
    }

    private var barra: some View {
        let vacio = texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let lista = DisponibilidadIA.actual == .lista
        return HStack(alignment: .bottom, spacing: 8) {
            Menu {
                if EscanerDocumentos.disponible {
                    Button { escaneando = true } label: { Label(L("Escanear páginas", "Scan Pages", "Scansiona pagine"), systemImage: "doc.viewfinder") }
                }
                if CamaraFoto.disponible {
                    Button { fotografiando = true } label: { Label(L("Hacer una foto", "Take a Photo", "Scatta una foto"), systemImage: "camera") }
                }
                Button { eligiendo = true } label: { Label(L("Elegir fotos", "Choose Photos", "Scegli foto"), systemImage: "photo.on.rectangle") }
            } label: {
                Image(systemName: "camera.fill")
                    .font(.body.weight(.semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel(L("Mandar fotos", "Send Photos", "Manda foto"))

            TextField(text: $texto, prompt: Indicacion.texto(L("Pregúntale a Hoot", "Ask Hoot", "Chiedi a Hoot")), axis: .vertical) {
                Text(L("Pregunta", "Question", "Domanda"))
            }
            .lineLimit(1...5)
            .focused($foco)
            .foregroundStyle(.white)
            .submitLabel(.send)
            .onSubmit(enviar)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .glassEffect(.regular, in: .rect(cornerRadius: 22, style: .continuous))

            if vacio {
                Button {
                    if dictado.escuchando { dictado.parar() } else { Task { await dictado.empezar(desde: texto) } }
                } label: {
                    Image(systemName: dictado.escuchando ? "stop.fill" : "mic.fill")
                        .font(.body.weight(.semibold))
                        .frame(width: 24, height: 24)
                        .symbolEffect(.variableColor.iterative, isActive: dictado.escuchando)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityLabel(dictado.escuchando ? L("Dejar de dictar", "Stop Dictation", "Ferma la dettatura") : L("Dictar", "Dictate", "Detta"))
            } else {
                Button(action: enviar) {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color.sobreAmbar)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(.ambar)
                .disabled(charla.escribiendo)
                .accessibilityLabel(L("Enviar", "Send", "Invia"))
            }
        }
        .disabled(!lista)
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func enviar() {
        if dictado.escuchando { dictado.parar() }
        let t = texto
        texto = ""
        charla.enviar(t)
    }

    static let maximoFotos = 10

    private func mandarFotos(_ imagenes: [UIImage]) {
        guard !imagenes.isEmpty else { return }
        let pregunta = texto
        texto = ""
        charla.enviarFotos(Array(imagenes.prefix(Self.maximoFotos)), pregunta: pregunta)
    }

    private func guardar() {
        guard case .tema(let id) = charla.origen, !ModoCapturas.activo else { return }
        almacen.datos.cambiarTema(id) { $0.charla = Array(charla.mensajes.suffix(40)) }
    }

    private func cerrar(_ accion: () -> Void) {
        guardarEnEstudio()
        accion()
    }

    private func guardarEnEstudio() {
        guard case .suelta = charla.origen, charla.mensajes.contains(where: { $0.quien == .hoot }), !ModoCapturas.activo else { return }
        let primera = charla.mensajes.first { $0.quien == .yo && !$0.texto.isEmpty }?.texto
        let titulo = primera.map { String($0.prefix(60)) } ?? TipoAyuda.explicar.nombre
        let fotos = charla.mensajes.flatMap(\.fotos)
        guard !almacen.estudios.contains(where: { $0.tipo == .explicar && $0.resultado == charla.transcripcion }) else { return }
        almacen.estudios.insert(EstudioGuardado(tipo: .explicar, titulo: titulo, asignaturaID: charla.asignaturaID, fecha: Reloj.ahora,
                                                resultado: charla.transcripcion, textoLeido: "", miniaturas: Array(fotos.prefix(6))), at: 0)
        if almacen.estudios.count > 150 { almacen.estudios.removeLast(almacen.estudios.count - 150) }
    }

    static func conNegritas(_ texto: String) -> AttributedString {
        (try? AttributedString(markdown: texto, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(texto)
    }
}

private struct PuntosEscribiendo: View {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reducirMovimiento)) { contexto in
            let t = contexto.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.tintaBocadillo.opacity(0.45))
                        .frame(width: 8, height: 8)
                        .opacity(reducirMovimiento ? 1 : 0.45 + 0.55 * max(0, sin(t * 5 - Double(i) * 0.9)))
                }
            }
        }
    }
}

private struct FlowSugerencias: View {
    var sugerencias: [String]
    var elegir: (String) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { botones }
            VStack(alignment: .leading, spacing: 8) { botones }
        }
    }

    private var botones: some View {
        ForEach(sugerencias, id: \.self) { s in
            Button { elegir(s) } label: { Text(s).font(.subheadline.weight(.semibold)) }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(.white.opacity(0.6))
                .foregroundStyle(.white)
        }
    }
}

struct HablarConHoot: View {
    @Bindable var charla: CharlaHoot
    var alSalir: () -> Void

    @State private var dictado = Dictado()
    @State private var voz = VozLobo()
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        let ultimoYo = charla.mensajes.last { $0.quien == .yo }?.texto ?? ""
        VStack(spacing: 18) {
            HStack {
                Button(action: salir) { Image(systemName: "xmark") }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .accessibilityLabel(L("Cerrar", "Close", "Chiudi"))
                Spacer()
                VStack(spacing: 1) {
                    Text(L("Hablando", "Talking", "Parlando")).font(.headline)
                    Text(charla.titulo).font(.footnote).foregroundStyle(EstiloSecundario())
                }
                Spacer()
                Button(action: salir) { Image(systemName: "keyboard") }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .accessibilityLabel(L("Escribir", "Type", "Scrivi"))
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.top, 8)

            Spacer(minLength: 0)
            LoboInteractivo(tamano: letra.isAccessibilitySize ? 150 : 210, gesto: gesto)
            VStack(spacing: 12) {
                if !ultimoYo.isEmpty {
                    Text("«\(ultimoYo)»").font(.body).foregroundStyle(EstiloSecundario()).lineLimit(3)
                }
                Text(subtitulo)
                    .font(.title3.weight(.bold))
                    .fontDesign(.rounded)
                    .lineLimit(6)
                    .contentTransition(.opacity)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
            Spacer(minLength: 0)
            estado
                .padding(.bottom, 40)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { LinearGradient(colors: [Color(red: 0.055, green: 0.098, blue: 0.251), Color(red: 0.094, green: 0.153, blue: 0.353)], startPoint: .top, endPoint: .bottom).ignoresSafeArea() }
        .environment(\.sobreCielo, true)
        .environment(\.colorScheme, .dark)
        .task { escuchar() }
        .onChange(of: dictado.escuchando) { antes, ahora in
            guard antes, !ahora else { return }
            let t = dictado.texto.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { charla.enviar(t) } else { escuchar() }
        }
        .onChange(of: charla.escribiendo) { antes, ahora in
            guard antes, !ahora else { return }
            let nuevos = charla.mensajes.reversed().prefix { $0.quien == .hoot }.reversed().map(\.texto)
            if nuevos.isEmpty { escuchar() } else { voz.decir(nuevos.joined(separator: " ")) }
        }
        .onChange(of: voz.hablando) { antes, ahora in
            if antes, !ahora { escuchar() }
        }
        .onDisappear {
            dictado.parar()
            voz.callar()
        }
    }

    private var gesto: GestoLobo {
        if voz.hablando { return .hablando }
        if charla.escribiendo { return .pensando }
        return .normal
    }

    private var subtitulo: String {
        if charla.escribiendo { return CharlaHoot.partir(charla.parcial).respuesta }
        if dictado.escuchando, !dictado.texto.isEmpty { return dictado.texto }
        let nuevos = charla.mensajes.reversed().prefix { $0.quien == .hoot }.reversed().map(\.texto)
        return nuevos.joined(separator: " ")
    }

    private var estado: some View {
        VStack(spacing: 12) {
            Group {
                if let error = dictado.error ?? charla.aviso {
                    Text(error).font(.footnote).foregroundStyle(EstiloAviso(color: .pronto))
                } else if dictado.escuchando {
                    Text(L("Te escucho", "I'm listening", "Ti ascolto"))
                } else if charla.escribiendo {
                    Text(L("Pensando…", "Thinking…", "Sto pensando…")).foregroundStyle(EstiloSecundario())
                } else if voz.hablando || ModoCapturas.activo {
                    Text(L("Cuando acabe, te escucho", "When I finish, I'll listen", "Quando finisco, ti ascolto")).foregroundStyle(EstiloSecundario())
                } else {
                    Text(L("Toca para hablar", "Tap to speak", "Tocca per parlare")).foregroundStyle(EstiloSecundario())
                }
            }
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
            BotonHablar(escuchando: dictado.escuchando, nivel: dictado.nivel) {
                if dictado.escuchando { dictado.parar() } else {
                    voz.callar()
                    escuchar()
                }
            }
            .disabled(charla.escribiendo)
        }
    }

    private func escuchar() {
        guard !voz.hablando, !charla.escribiendo, !dictado.escuchando, !ModoCapturas.activo else { return }
        dictado.pararAlCallar = true
        Task { await dictado.empezar(desde: "") }
    }

    private func salir() {
        dictado.parar()
        voz.callar()
        alSalir()
    }
}

private struct OndaVoz: View {
    var nivel: Double
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reducirMovimiento)) { contexto in
            let t = contexto.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<16) { i in
                    let onda = reducirMovimiento ? 0.5 : 0.5 + 0.5 * sin(t * 7 + Double(i) * 0.7)
                    Capsule()
                        .fill(Color.ambar)
                        .frame(width: 6, height: 8 + 44 * max(0.08, nivel) * (0.4 + 0.6 * onda))
                }
            }
            .frame(height: 56)
        }
        .accessibilityHidden(true)
    }
}

private struct MosaicoFotos: View {
    var fotos: [UIImage]
    private let lado: CGFloat = 96
    private let hueco: CGFloat = 3

    var body: some View {
        let vistas = Array(fotos.prefix(4))
        let mas = fotos.count - vistas.count
        Grid(horizontalSpacing: hueco, verticalSpacing: hueco) {
            ForEach(Array(stride(from: 0, to: vistas.count, by: 2)), id: \.self) { i in
                GridRow {
                    if i + 1 < vistas.count {
                        celda(vistas[i], ancho: lado)
                        celda(vistas[i + 1], ancho: lado, mas: i + 1 == 3 ? mas : 0)
                    } else {
                        celda(vistas[i], ancho: lado * 2 + hueco)
                            .gridCellColumns(2)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement()
        .accessibilityLabel(L("Tus fotos: \(fotos.count)", "Your photos: \(fotos.count)", "Le tue foto: \(fotos.count)"))
    }

    private func celda(_ img: UIImage, ancho: CGFloat, mas: Int = 0) -> some View {
        Image(uiImage: img)
            .resizable()
            .scaledToFill()
            .frame(width: ancho, height: lado)
            .clipped()
            .overlay {
                if mas > 0 {
                    ZStack {
                        Color.black.opacity(0.45)
                        Text("+\(mas)").font(.title2.weight(.bold)).foregroundStyle(.white).monospacedDigit()
                    }
                }
            }
    }
}
