import PhotosUI
import SwiftUI

struct SalaVista: View {
    var sala: SalaEnVivo
    var alCerrar: () -> Void

    @Environment(Almacen.self) private var almacen
    @Environment(\.scenePhase) private var fase
    @State private var control = ControlPizarra()
    @State private var pedido: PedidoPizarra?
    @State private var fotos: [PhotosPickerItem] = []
    @State private var eligiendoFotos = false
    @State private var estiloEscritura = EstiloLetra.normal
    @State private var seleccionApuntes = 0..<0
    @State private var confirmandoCierre = false
    @State private var compartir: [Any]?
    @State private var invitando = false
    @State private var viendoCodigo = false
    @State private var guardandoEnTema = false
    @State private var eligiendoReto = false

    var body: some View {
        @Bindable var s = sala
        NavigationStack {
            contenido
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .modifier(FondoSala(tenida: !conLosDos))
                .animation(Diseno.muelle, value: sala.amigo?.uid)
                .sensoryFeedback(trigger: sala.amigo?.uid) { antes, ahora in antes == nil && ahora != nil ? .success : nil }
                .navigationTitle(conLosDos ? "" : (sala.soyAnfitrion && sala.estado == .dentro ? L("Tu sala", "Your room", "La tua stanza") : ""))
                .navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(conLosDos ? nil : .dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        BotonCerrar { cerrar() }
                    }
                    if sala.estado == .dentro && sala.amigo != nil {
                        ToolbarItem(placement: .principal) {
                            Picker(L("Espacio", "Space", "Spazio"), selection: $s.espacio) {
                                Text(L("Pizarra", "Board", "Lavagna")).tag(EspacioSala.pizarra)
                                Text(L("Apuntes", "Notes", "Appunti")).tag(EspacioSala.apuntes)
                                Text(sala.chat.sinLeer > 0 ? "\(L("Chat", "Chat", "Chat")) · \(sala.chat.sinLeer)" : L("Chat", "Chat", "Chat")).tag(EspacioSala.chat)
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 300)
                        }
                    }
                    if sala.estado == .dentro {
                        ToolbarItem(placement: .primaryAction) { menu }
                    }
                }
                .safeAreaBar(edge: .top) {

                    Group {
                        if sala.estado == .dentro { avisos }
                        if sala.estado == .dentro, sala.amigo != nil, sala.solicitudes.isEmpty, sala.reto.invitacion == nil {
                            BannerLlamada(sala: sala)
                        }
                    }
                    .animation(Diseno.muelle, value: sala.solicitudes.count)
                    .animation(Diseno.muelle, value: sala.reto.invitacion)
                }
        }
        .sheet(item: $pedido) { p in hojaPedido(p) }
        .photosPicker(isPresented: $eligiendoFotos, selection: $fotos, maxSelectionCount: 10, matching: .images)
        .onChange(of: fotos) { _, items in
            guard !items.isEmpty else { return }
            fotos = []
            Task {
                for item in items {
                    if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { await ponerEnPizarra(img) }
                }
            }
        }
        .sheet(isPresented: Binding(get: { compartir != nil }, set: { if !$0 { compartir = nil } })) {
            if let compartir { HojaCompartir(elementos: compartir).ignoresSafeArea() }
        }
        .sheet(isPresented: $invitando) { InvitarCompaneros(sala: sala) }
        .sheet(isPresented: $viendoCodigo) { CodigoDeSala(sala: sala) }
        .sheet(isPresented: $guardandoEnTema) { GuardarEnTema(sala: sala) }
        .sheet(isPresented: $eligiendoReto) { ElegirTemasReto(sala: sala) }
        .fullScreenCover(item: Binding(get: { sala.reto.reto.map(RetoAbierto.init) }, set: { if $0 == nil { sala.reto.terminar() } })) { r in
            RetoVista(temas: [], nombreTema: r.reto.tema, externo: r.reto) { sala.reto.terminar() }
        }
        .confirmationDialog(sala.soyAnfitrion ? L("¿Cerrar la sala?", "Close the room?", "Chiudere la stanza?") : L("¿Salir de la sala?", "Leave the room?", "Uscire dalla stanza?"),
                            isPresented: $confirmandoCierre, titleVisibility: .visible) {
            Button(sala.soyAnfitrion ? L("Cerrar la sala", "Close Room", "Chiudi la stanza") : L("Salir de la sala", "Leave Room", "Esci dalla stanza"), role: .destructive) {
                Task {
                    if sala.soyAnfitrion { await sala.cerrarSala() } else { await sala.salirDeLaSala() }
                    alCerrar()
                }
            }
        } message: {
            Text(sala.soyAnfitrion
                 ? L("Se borran la pizarra, los apuntes y el chat, también para \(sala.amigo?.nombre ?? "tu amigo"). Expórtalos antes si los quieres.",
                     "The board, notes and chat are deleted, for \(sala.amigo?.nombre ?? "your friend") too. Export them first if you want them.",
                     "Lavagna, appunti e chat vengono cancellati, anche per \(sala.amigo?.nombre ?? "il tuo amico"). Esportali prima se li vuoi.")
                 : L("Para volver, \(sala.anfitrion?.nombre ?? "quien la creó") tendrá que dejarte pasar otra vez.",
                     "To come back, \(sala.anfitrion?.nombre ?? "the host") will have to let you in again.",
                     "Per tornare, \(sala.anfitrion?.nombre ?? "chi l'ha creata") dovrà farti entrare di nuovo."))
        }
        .onChange(of: sala.amigo?.uid) { _, uid in

            guard uid != nil, sala.soyAnfitrion, let r = Salas.compartidas.retoPendiente else { return }
            Salas.compartidas.retoPendiente = nil
            sala.reto.retar(temas: r.temas, nombreTema: r.tema, curso: almacen.perfil.curso)
        }
        .onChange(of: fase) { _, f in

            if f == .active { sala.chat.viendo = sala.espacio == .chat }
        }
        .environment(\.sobreCielo, false)
    }

    private var conLosDos: Bool { sala.estado == .dentro && sala.amigo != nil }

    @ViewBuilder
    private var contenido: some View {
        switch sala.estado {
        case .conectando:
            VStack(spacing: 14) {
                ProgressView()
                Text(L("Entrando en la sala…", "Joining the room…", "Entro nella stanza…")).foregroundStyle(.secondary)
            }
        case .esperandoPermiso:
            Espera(frase: L("Esperando a que \(sala.nombreQuienCrea.isEmpty ? "quien creó la sala" : sala.nombreQuienCrea) te deje pasar. Yo mientras afilo los lápices.",
                            "Waiting for \(sala.nombreQuienCrea.isEmpty ? "the host" : sala.nombreQuienCrea) to let you in. I'll sharpen the pencils meanwhile.",
                            "Aspetto che \(sala.nombreQuienCrea.isEmpty ? "chi ha creato la stanza" : sala.nombreQuienCrea) ti faccia entrare. Intanto tempero le matite."),
                   gesto: .pensando, detalle: L("Sala \(sala.codigoBonito)", "Room \(sala.codigoBonito)", "Stanza \(sala.codigoBonito)"), conEspera: true)
        case .rechazado:
            Espera(frase: L("No te ha dejado pasar. Igual se ha equivocado de botón: pídele otro código.", "They didn't let you in. Maybe a wrong tap: ask for another code.",
                            "Non ti ha fatto entrare. Forse ha sbagliato tasto: chiedigli un altro codice."), gesto: .preocupado, detalle: nil, conEspera: false)
        case .cerrada:
            Espera(frase: L("Esta sala ya no existe. Si queréis seguir, cread otra.", "This room no longer exists. If you want to go on, create another one.",
                            "Questa stanza non esiste più. Se volete continuare, createne un'altra."), gesto: .preocupado, detalle: nil, conEspera: false)
        case .dentro:
            if sala.amigo == nil {
                EsperandoAmigo(sala: sala)
            } else {
                espacios
            }
        }
    }

    @ViewBuilder
    private var espacios: some View {
        ZStack {
            PizarraVista(pizarra: sala.pizarra, control: control, nombreAmigo: sala.amigo?.nombre ?? "", activa: sala.espacio == .pizarra) { p in
                if p == .foto { eligiendoFotos = true } else { pedido = p }
            }
            .ignoresSafeArea(edges: .bottom)
            .opacity(sala.espacio == .pizarra ? 1 : 0)
            .allowsHitTesting(sala.espacio == .pizarra)
            .accessibilityHidden(sala.espacio != .pizarra)
            if sala.espacio == .apuntes {
                EditorApuntesVista(apuntes: sala.apuntes, nombreAmigo: sala.amigo?.nombre ?? "", estiloEscritura: $estiloEscritura, seleccion: $seleccionApuntes)
                    .ignoresSafeArea(edges: .bottom)
            }
            if sala.espacio == .chat {
                ChatSalaVista(chat: sala.chat, yo: sala.yo.uid, nombreAmigo: sala.amigo?.nombre ?? "")
            }
        }
        .overlay(alignment: .topLeading) {
            if sala.espacio == .pizarra { DeshacerRehacer(pizarra: sala.pizarra).padding(.leading, 16).padding(.top, 8) }
        }
    }

    @ViewBuilder
    private var avisos: some View {
        if let s = sala.solicitudes.first {
            AvisoSalaVista(titulo: L("\(s.nombre) quiere entrar", "\(s.nombre) wants to join", "\(s.nombre) vuole entrare"),
                           detalle: L("Con el código \(sala.codigoBonito)", "With the code \(sala.codigoBonito)", "Con il codice \(sala.codigoBonito)"),
                           inicial: String(s.nombre.prefix(1)), si: L("Dejar pasar", "Let In", "Fai entrare"), no: L("No", "No", "No"),
                           alSi: { sala.dejarPasar(s) }, alNo: { sala.noDejarPasar(s) })
        } else if let tema = sala.reto.invitacion {
            AvisoSalaVista(titulo: L("\(sala.amigo?.nombre ?? "Tu amigo") te reta", "\(sala.amigo?.nombre ?? "Your friend") challenges you", "\(sala.amigo?.nombre ?? "Il tuo amico") ti sfida"),
                           detalle: tema, inicial: String((sala.amigo?.nombre ?? "?").prefix(1)), si: L("Jugar", "Play", "Gioca"), no: L("Ahora no", "Not Now", "Non ora"),
                           alSi: { sala.reto.responder(true, temas: temasPara(tema), curso: almacen.perfil.curso) },
                           alNo: { sala.reto.responder(false, temas: [], curso: "") })
        }
    }

    private func temasPara(_ nombre: String) -> [Tema] {
        let n = nombre.lowercased()
        return almacen.datos.pruebas.flatMap(\.temas).filter { $0.nombre.lowercased() == n || n.contains($0.nombre.lowercased()) }
    }

    private var menu: some View {
        Menu {
            if sala.soyAnfitrion {
                Button(L("Código de la sala", "Room Code", "Codice della stanza"), systemImage: "qrcode") { viendoCodigo = true }
                Button(L("Invitar a un compañero", "Invite a Classmate", "Invita un compagno"), systemImage: "person.badge.plus") { invitando = true }
            }
            if let amigo = sala.amigo {
                Button(L("Retar a \(amigo.nombre)", "Challenge \(amigo.nombre)", "Sfida \(amigo.nombre)"), systemImage: "moonphase.first.quarter") { eligiendoReto = true }
                    .disabled(DisponibilidadIA.actual != .lista)
            }
            Section {
                Button(L("Exportar la pizarra", "Export the Board", "Esporta la lavagna"), systemImage: "square.and.arrow.up") { exportarPizarra() }
                Button(L("Exportar los apuntes", "Export the Notes", "Esporta gli appunti"), systemImage: "doc.richtext") { exportarApuntes() }
                Button(L("Guardar en un tema", "Save to a Topic", "Salva in un argomento"), systemImage: "moon.stars") { guardandoEnTema = true }
            }
            Section {
                Button(sala.soyAnfitrion ? L("Cerrar la sala", "Close Room", "Chiudi la stanza") : L("Salir de la sala", "Leave Room", "Esci dalla stanza"),
                       systemImage: sala.soyAnfitrion ? "xmark.circle" : "rectangle.portrait.and.arrow.right", role: .destructive) { confirmandoCierre = true }
            }
        } label: {
            Image(systemName: "ellipsis")
                .accessibilityLabel(L("Más", "More", "Altro"))
        }
    }

    private func exportarPizarra() {
        guard let img = sala.pizarra.imagen() else { return }
        var cosas: [Any] = [img]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(L("Pizarra", "Board", "Lavagna") + ".pdf")
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: img.size)).pdfData { ctx in
            ctx.beginPage()
            img.draw(in: CGRect(origin: .zero, size: img.size))
        }
        if (try? pdf.write(to: url)) != nil { cosas.append(url) }
        compartir = cosas
    }

    private func exportarApuntes() {
        let titulo = sala.apuntes.texto.split(separator: "\n").first.map(String.init) ?? L("Apuntes", "Notes", "Appunti")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(titulo.prefix(40)).pdf")
        guard (try? RenderApuntes.pdf(sala.apuntes.visibles, titulo: titulo).write(to: url)) != nil else { return }
        compartir = [url, sala.apuntes.texto]
    }

    @ViewBuilder
    private func hojaPedido(_ p: PedidoPizarra) -> some View {
        switch p {
        case .camara:
            CamaraFoto { img in
                pedido = nil
                if let img { Task { await ponerEnPizarra(img) } }
            }
            .ignoresSafeArea()
        case .escanear:
            EscanerDocumentos { imgs in
                pedido = nil
                Task { for img in imgs { await ponerEnPizarra(img) } }
            }
            .ignoresSafeArea()
        case .foto:
            EmptyView()
        }
    }

    private func ponerEnPizarra(_ img: UIImage) async {
        let v = control.visible
        await sala.pizarra.ponerFoto(img, en: v.centro, anchoVisible: v.ancho)
    }

    private func cerrar() {
        sala.parar()
        alCerrar()
    }
}

private struct RetoAbierto: Identifiable {
    let reto: RetoCercano
    var id: ObjectIdentifier { ObjectIdentifier(reto) }
}

struct BannerLlamada: View {
    var sala: SalaEnVivo

    static let verde = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .systemGreen : UIColor(red: 0.12, green: 0.49, blue: 0.2, alpha: 1) })

    var body: some View {
        let llamada = sala.llamada
        let amigo = sala.amigo?.nombre ?? ""
        HStack(spacing: 10) {
            Text(String(amigo.prefix(1)).uppercased())
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color(ContenedorPizarra.colorAmigo), in: Circle())
                .overlay {
                    if llamada.enLlamada {
                        Circle().stroke(Color.green, lineWidth: 3).padding(-4)
                            .scaleEffect(1 + 0.12 * llamada.nivelAmigo)
                            .animation(Diseno.muelleRapido, value: llamada.nivelAmigo)
                    }
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(amigo).font(.headline).lineLimit(1)
                estado(llamada)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            botones(llamada)
        }
        .padding(.leading, 9)
        .padding(.trailing, 7)
        .padding(.vertical, 7)
        .glassEffect(.regular, in: Capsule())
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .accessibilityElement(children: .contain)

        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    @ViewBuilder
    private func estado(_ l: LlamadaSala) -> some View {
        switch l.fase {
        case .enCurso(let desde):

            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text(Formato.reloj(Reloj.ahora.timeIntervalSince(desde)))
                    .monospacedDigit()
                    .foregroundStyle(Self.verde)
                    .contentTransition(.numericText())
                    .accessibilityLabel(L("En llamada, \(Formato.reloj(Reloj.ahora.timeIntervalSince(desde)))", "On call, \(Formato.reloj(Reloj.ahora.timeIntervalSince(desde)))",
                                          "In chiamata, \(Formato.reloj(Reloj.ahora.timeIntervalSince(desde)))"))
            }
        case .llamando:
            Text(L("Llamando…", "Calling…", "Chiamata…")).foregroundStyle(.secondary)
        case .entrante:
            Text(L("Te llama", "Calling you", "Ti chiama")).foregroundStyle(Self.verde)
        case .nada:
            if sala.amigoConectado {
                Text(lugar).foregroundStyle(.secondary)
            } else {
                Text(L("Fuera de la sala", "Not in the room", "Fuori dalla stanza")).foregroundStyle(.secondary)
            }
        }
    }

    private var lugar: String {
        switch sala.amigoEspacio {
        case .apuntes: L("En los apuntes", "In the notes", "Negli appunti")
        case .chat: L("En el chat", "In the chat", "Nella chat")
        default: L("En la pizarra", "On the board", "Sulla lavagna")
        }
    }

    @ViewBuilder
    private func botones(_ l: LlamadaSala) -> some View {
        switch l.fase {
        case .nada:
            Button { l.llamar() } label: {
                Image(systemName: "phone.fill").font(.body.weight(.semibold)).frame(width: 40, height: 40)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .tint(.green)
            .disabled(!sala.amigoConectado)
            .accessibilityLabel(L("Llamar a \(sala.amigo?.nombre ?? "")", "Call \(sala.amigo?.nombre ?? "")", "Chiama \(sala.amigo?.nombre ?? "")"))
        case .entrante:
            HStack(spacing: 8) {
                Button { l.colgar() } label: { Image(systemName: "phone.down.fill").frame(width: 40, height: 40) }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.circle).tint(.red)
                    .accessibilityLabel(L("Rechazar", "Decline", "Rifiuta"))
                Button { l.contestar() } label: { Image(systemName: "phone.fill").frame(width: 40, height: 40) }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.circle).tint(.green)
                    .accessibilityLabel(L("Contestar", "Answer", "Rispondi"))
            }
        case .llamando, .enCurso:
            HStack(spacing: 8) {
                if l.enLlamada {

                    BotonDeLlamada(simbolo: l.silenciado ? "mic.slash.fill" : "mic.fill", activo: l.silenciado,
                                   etiqueta: l.silenciado ? L("Activar el micrófono", "Unmute", "Riattiva il microfono") : L("Silenciar", "Mute", "Silenzia")) {
                        l.silenciado.toggle()
                    }
                    BotonDeLlamada(simbolo: l.altavoz ? "speaker.wave.3.fill" : "speaker.fill", activo: l.altavoz, etiqueta: L("Altavoz", "Speaker", "Altoparlante")) {
                        l.altavoz.toggle()
                    }
                }
                Button { l.colgar() } label: { Image(systemName: "phone.down.fill").frame(width: 40, height: 40) }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.circle).tint(.red)
                    .accessibilityLabel(L("Colgar", "Hang Up", "Riaggancia"))
            }
        }
    }
}

private struct BotonDeLlamada: View {
    var simbolo: String
    var activo: Bool
    var etiqueta: String
    var accion: () -> Void

    var body: some View {
        if activo {
            Button(action: accion) { Image(systemName: simbolo).frame(width: 40, height: 40) }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(.primary)
                .accessibilityLabel(etiqueta)
                .accessibilityAddTraits(.isSelected)
        } else {
            Button(action: accion) { Image(systemName: simbolo).frame(width: 40, height: 40) }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(.primary)
                .accessibilityLabel(etiqueta)
        }
    }
}

struct DeshacerRehacer: View {
    var pizarra: PizarraCompartida
    @ScaledMetric(relativeTo: .body) private var lado: CGFloat = 44

    var body: some View {
        if pizarra.puedeDeshacer || pizarra.puedeRehacer {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button { pizarra.deshacer() } label: {
                        Image(systemName: "arrow.uturn.backward").font(.body.weight(.semibold)).frame(width: lado, height: lado)
                    }
                    .disabled(!pizarra.puedeDeshacer)
                    .accessibilityLabel(L("Deshacer", "Undo", "Annulla"))
                    Button { pizarra.rehacer() } label: {
                        Image(systemName: "arrow.uturn.forward").font(.body.weight(.semibold)).frame(width: lado, height: lado)
                    }
                    .disabled(!pizarra.puedeRehacer)
                    .accessibilityLabel(L("Rehacer", "Redo", "Ripristina"))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
    }
}

struct AvisoSalaVista: View {
    var titulo: String
    var detalle: String
    var inicial: String
    var si: String
    var no: String
    var alSi: () -> Void
    var alNo: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(inicial.uppercased())
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color(ContenedorPizarra.colorAmigo), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo).font(.headline)
                    Text(detalle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Button(action: alNo) { Text(no).frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                Button(action: alSi) { Text(si).frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
            .buttonBorderShape(.capsule)
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .transition(.move(edge: .top).combined(with: .opacity))
        .sensoryFeedback(.impact, trigger: titulo)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

private struct Espera: View {
    var frase: String
    var gesto: GestoLobo
    var detalle: String?
    var conEspera: Bool

    var body: some View {
        VStack(spacing: 18) {
            HootDice(frase: frase, gesto: gesto, tamano: 112, paraguasSiLlueve: false)
                .padding(.top, 24)
            if let detalle {
                Text(detalle).font(.subheadline).foregroundStyle(EstiloSecundario())
            }
            if conEspera { ProgressView().tint(.white) }
            Spacer()
        }
        .padding(Diseno.margen)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }
}

private struct FondoSala: ViewModifier {
    var tenida: Bool

    func body(content: Content) -> some View {
        if tenida {
            content.tenidaDelCielo().environment(\.sobreCielo, true)
        } else {
            content.background(Color(.systemBackground))
        }
    }
}

struct EsperandoAmigo: View {
    var sala: SalaEnVivo
    @State private var invitados: Set<String> = []

    var body: some View {
        let compas = Array(SalasGuardadas.companeros.filter { $0.uid != sala.yo.uid }.prefix(3))
        ScrollView {
            VStack(spacing: 18) {
                HootDice(frase: L("Sala lista. Que tu amigo traiga la goma.", "Room ready. Tell your friend to bring an eraser.", "Stanza pronta. Che il tuo amico porti la gomma."),
                         gesto: .feliz, tamano: 96, paraguasSiLlueve: false)
                VStack(spacing: 10) {
                    Text(L("Dile este código a tu amigo", "Give your friend this code", "Di' questo codice al tuo amico"))
                        .font(.subheadline)
                        .foregroundStyle(EstiloSecundario())
                    CodigoGrande(codigo: sala.codigo)
                    CodigoQR(contenido: "hoot://sala/\(sala.codigo)")
                        .frame(width: 150, height: 150)
                        .padding(10)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityLabel(L("Código QR de la sala", "Room QR code", "Codice QR della stanza"))
                    Text(L("O que lo escanee con su Hoot", "Or they can scan it with their Hoot", "Oppure lo scansiona con il suo Hoot"))
                        .font(.footnote)
                        .foregroundStyle(EstiloSecundario())
                }
                VStack(alignment: .leading, spacing: 6) {
                    TituloCielo(titulo: L("Invitar a un compañero", "Invite a classmate", "Invita un compagno"), simbolo: "person.badge.plus")
                    VStack(spacing: 0) {
                        ForEach(compas) { c in
                            HStack(spacing: 12) {
                                Text(String(c.nombre.prefix(1)).uppercased())
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color(ContenedorPizarra.colorAmigo), in: Circle())
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(c.nombre).foregroundStyle(.white)
                                    Text(L("Estuvisteis \(Formato.diaEnFrase(c.ultimaVez))", "Together \(Formato.diaEnFrase(c.ultimaVez))", "Insieme \(Formato.diaEnFrase(c.ultimaVez))"))
                                        .font(.subheadline)
                                        .foregroundStyle(EstiloSecundario())
                                }
                                Spacer()
                                if invitados.contains(c.uid) {
                                    Label(L("Invitado", "Invited", "Invitato"), systemImage: "checkmark").foregroundStyle(EstiloSecundario())
                                } else {
                                    Button(L("Invitar", "Invite", "Invita")) {
                                        Task { if await Salas.invitar(c, a: sala) { conMuelle { _ = invitados.insert(c.uid) } } }
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.white)
                                }
                            }
                            .padding(.vertical, 10)
                            Separador()
                        }
                        ShareLink(item: L("Entra en mi sala de Hoot con el código \(sala.codigoBonito)", "Join my Hoot room with the code \(sala.codigoBonito)",
                                          "Entra nella mia stanza di Hoot con il codice \(sala.codigoBonito)")) {
                            HStack(spacing: 12) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.body.weight(.semibold))
                                    .frame(width: 36, height: 36)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(L("Mandar el enlace", "Send the Link", "Manda il link"))
                                    Text(L("Por Mensajes o WhatsApp", "By Messages or WhatsApp", "Con Messaggi o WhatsApp")).font(.subheadline).foregroundStyle(EstiloSecundario())
                                }
                                Spacer()
                                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(EstiloSecundario())
                            }
                            .foregroundStyle(.white)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Diseno.margenTarjeta)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Diseno.radioModulo, style: .continuous))
                }
                HStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text(L("Esperando a tu amigo…", "Waiting for your friend…", "Aspetto il tuo amico…")).foregroundStyle(EstiloSecundario())
                }
                .padding(.top, 4)
            }
            .padding(Diseno.margen)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }
}

struct CodigoGrande: View {
    var codigo: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(codigo.enumerated()), id: \.offset) { i, c in
                if i == 3 { Text("–").font(.title).foregroundStyle(EstiloSecundario()) }
                Text(String(c))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 40, minHeight: 54)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Código: \(codigo.map(String.init).joined(separator: " "))", "Code: \(codigo.map(String.init).joined(separator: " "))",
                              "Codice: \(codigo.map(String.init).joined(separator: " "))"))
        .textSelection(.enabled)
    }
}

struct CodigoDeSala: View {
    var sala: SalaEnVivo
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                CodigoGrande(codigo: sala.codigo)
                CodigoQR(contenido: "hoot://sala/\(sala.codigo)")
                    .frame(width: 200, height: 200)
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityLabel(L("Código QR de la sala", "Room QR code", "Codice QR della stanza"))
                Text(L("Vale hasta mañana. Aunque lo tenga, tú decides si entra.", "Valid until tomorrow. Even with it, you decide who gets in.",
                       "Vale fino a domani. Anche con il codice, decidi tu chi entra."))
                    .font(.footnote)
                    .foregroundStyle(EstiloSecundario())
                    .multilineTextAlignment(.center)
            }
            .padding(Diseno.margen)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tenidaDelCielo(hoja: true)
            .environment(\.sobreCielo, true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle(L("Código de la sala", "Room Code", "Codice della stanza"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar() } } }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground { FondoHojaTenida() }
    }
}

struct InvitarCompaneros: View {
    var sala: SalaEnVivo
    @Environment(\.dismiss) private var cerrar
    @State private var invitados: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                let compas = SalasGuardadas.companeros.filter { $0.uid != sala.yo.uid }
                if compas.isEmpty {
                    Text(L("Aún no has estado en una sala con nadie. Mándale el código.", "You haven't been in a room with anyone yet. Send them the code.",
                           "Non sei ancora stato in una stanza con nessuno. Mandagli il codice."))
                        .foregroundStyle(.secondary)
                }
                ForEach(compas) { c in
                    HStack(spacing: 12) {
                        Text(String(c.nombre.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color(ContenedorPizarra.colorAmigo), in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.nombre)
                            Text(L("Estuvisteis \(Formato.diaEnFrase(c.ultimaVez))", "Together \(Formato.diaEnFrase(c.ultimaVez))", "Insieme \(Formato.diaEnFrase(c.ultimaVez))"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if invitados.contains(c.uid) {
                            Label(L("Invitado", "Invited", "Invitato"), systemImage: "checkmark").labelStyle(.titleAndIcon).foregroundStyle(.secondary)
                        } else {
                            Button(L("Invitar", "Invite", "Invita")) {
                                Task {
                                    if await Salas.invitar(c, a: sala) { conMuelle { _ = invitados.insert(c.uid) } }
                                }
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
                Section {
                    ShareLink(item: L("Entra en mi sala de Hoot con el código \(sala.codigoBonito)", "Join my Hoot room with the code \(sala.codigoBonito)",
                                      "Entra nella mia stanza di Hoot con il codice \(sala.codigoBonito)")) {
                        Label(L("Mandar el código por Mensajes o WhatsApp", "Send the code by Messages or WhatsApp", "Manda il codice con Messaggi o WhatsApp"),
                              systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text(L("La invitación le sale en Hoy cuando abre Hoot.", "The invitation shows up on Today when they open Hoot.",
                           "L'invito appare in Oggi quando apre Hoot."))
                }
            }
            .navigationTitle(L("Invitar", "Invite", "Invita"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

struct ElegirTemasReto: View {
    var sala: SalaEnVivo
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            List {
                let pruebas = almacen.datos.pruebas.filter { p in p.temas.contains { !$0.textoLeido.isEmpty } }
                if pruebas.isEmpty {
                    Text(L("Para retar hace falta un tema con material (fotos o un PDF).", "To challenge, you need a topic with material (photos or a PDF).",
                           "Per sfidare serve un argomento con materiale (foto o un PDF)."))
                        .foregroundStyle(.secondary)
                }
                ForEach(pruebas) { p in
                    Section(almacen.datos.asignatura(p.asignaturaID)?.nombre ?? p.tipo.nombre) {
                        ForEach(p.temas.filter { !$0.textoLeido.isEmpty }) { t in
                            Button {
                                sala.reto.retar(temas: [t], nombreTema: t.nombre, curso: almacen.perfil.curso)
                                cerrar()
                            } label: {
                                HStack(spacing: 12) {
                                    Luna(parte: t.luna(cal: calendarioActual).fraccion, tamano: 22)
                                    Text(t.nombre).foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L("¿De qué?", "On what?", "Su cosa?"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

struct GuardarEnTema: View {
    var sala: SalaEnVivo
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var guardando: UUID?

    var body: some View {
        NavigationStack {
            List {
                ForEach(almacen.datos.pruebas.filter { $0.diasQueFaltan(desde: Reloj.ahora, cal: calendarioActual) >= 0 }) { p in
                    Section(almacen.datos.asignatura(p.asignaturaID)?.nombre ?? p.tipo.nombre) {
                        ForEach(p.temas) { t in
                            Button { guardar(en: t.id) } label: {
                                HStack(spacing: 12) {
                                    Luna(parte: t.luna(cal: calendarioActual).fraccion, tamano: 22)
                                    Text(t.nombre).foregroundStyle(.primary)
                                    Spacer()
                                    if guardando == t.id { ProgressView() }
                                }
                            }
                            .disabled(guardando != nil)
                        }
                    }
                }
            }
            .navigationTitle(L("Guardar en un tema", "Save to a Topic", "Salva in un argomento"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func guardar(en temaID: UUID) {
        guardando = temaID
        let amigo = sala.amigo?.nombre ?? ""
        let texto = sala.apuntes.texto
        let imagen = sala.pizarra.imagen(escala: 1.5)
        Task {
            var fuentes: [FuenteTema] = []
            var miniaturas: [Data] = []
            if texto.trimmingCharacters(in: .whitespacesAndNewlines).count > 10 {
                fuentes.append(FuenteTema(tipo: .texto, nombre: L("Apuntes con \(amigo)", "Notes with \(amigo)", "Appunti con \(amigo)"), texto: texto))
            }
            if let imagen {
                let leido = (try? await TrabajoIA.leer([imagen], escrito: "") { _, _ in }) ?? ""
                fuentes.append(FuenteTema(tipo: .fotos, nombre: L("Pizarra con \(amigo)", "Board with \(amigo)", "Lavagna con \(amigo)"), paginas: 1,
                                          texto: leido.isEmpty ? L("(Un dibujo de la pizarra)", "(A drawing from the board)", "(Un disegno della lavagna)") : leido))
                if let m = imagen.reducida(a: 360).jpegData(compressionQuality: 0.6) { miniaturas.append(m) }
            }
            conMuelle {
                almacen.datos.cambiarTema(temaID) { t in
                    t.prepararFuentes()
                    t.fuentes += fuentes
                    t.miniaturas += miniaturas
                    if t.puedeQuitarFuentes { t.textoLeido = String(t.textoDeFuentes.prefix(TrabajoIA.caracteresMaximos * 2)) }
                }
            }
            guardando = nil
            cerrar()
        }
    }
}

struct HojaCompartir: UIViewControllerRepresentable {
    var elementos: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: elementos, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
