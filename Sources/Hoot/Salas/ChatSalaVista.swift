import PhotosUI
import SwiftUI

struct ChatSalaVista: View {
    var chat: ChatSala
    var yo: String
    var nombreAmigo: String

    @State private var texto = ""
    @State private var fotos: [PhotosPickerItem] = []
    @State private var cancelando = false
    @State private var sinMicro = false
    @FocusState private var escribiendo: Bool
    @ScaledMetric(relativeTo: .body) private var anchoFoto: CGFloat = 220

    var body: some View {
        ScrollViewReader { lector in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(chat.mensajes.enumerated()), id: \.element.id) { i, m in

                        if i == 0 || m.fecha.timeIntervalSince(chat.mensajes[i - 1].fecha) >= 15 * 60 {
                            Text("\(Formato.diaRelativo(m.fecha)) · \(Formato.hora(m.fecha))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, i == 0 ? 0 : 10)
                                .padding(.bottom, 2)
                        }
                        burbuja(m)
                            .id(m.id)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: chat.mensajes.last?.id) { _, id in
                guard let id else { return }
                conMuelle { lector.scrollTo(id, anchor: .bottom) }
            }
        }
        .safeAreaBar(edge: .bottom) { entrada }
        .onAppear { chat.viendo = true }
        .onDisappear { chat.viendo = false }
        .onChange(of: fotos) { _, items in
            guard !items.isEmpty else { return }
            fotos = []

            Task {
                for item in items {
                    if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { await chat.mandarFoto(img) }
                }
            }
        }
        .alert(L("Sin permiso para el micrófono", "No microphone permission", "Nessun permesso per il microfono"), isPresented: $sinMicro) {
            Button(L("Abrir Ajustes", "Open Settings", "Apri Impostazioni")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button(L("Ahora no", "Not Now", "Non ora"), role: .cancel) {}
        } message: {
            Text(L("Para mandar notas de voz, deja que Hoot use el micrófono en Ajustes.", "To send voice messages, let Hoot use the microphone in Settings.",
                   "Per mandare note vocali, lascia che Hoot usi il microfono in Impostazioni."))
        }
    }

    @ViewBuilder
    private func burbuja(_ m: MensajeSala) -> some View {
        let mio = m.de == yo
        HStack {
            if mio { Spacer(minLength: 48) }
            Group {
                switch m.tipo {
                case .texto:
                    Text(m.texto)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .foregroundStyle(mio ? .white : .primary)
                        .background(mio ? Color.blue : Color(.systemGray5), in: forma(mio))
                case .voz:
                    notaDeVoz(m, mio: mio)
                case .foto:
                    if let img = chat.fotos[m.archivo] {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: anchoFoto, height: anchoFoto * min(1.3, max(0.6, img.size.height / max(img.size.width, 1))))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .accessibilityLabel(mio ? L("Tu foto", "Your photo", "La tua foto") : L("Foto de \(nombreAmigo)", "Photo from \(nombreAmigo)", "Foto di \(nombreAmigo)"))
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.systemGray5))
                            .frame(width: anchoFoto, height: anchoFoto * 0.75)
                            .overlay { ProgressView() }
                    }
                }
            }
            .contextMenu {
                if m.tipo == .texto {
                    Button(L("Copiar", "Copy", "Copia"), systemImage: "doc.on.doc") { UIPasteboard.general.string = m.texto }
                }
            }
            if !mio { Spacer(minLength: 48) }
        }
    }

    private func forma(_ mio: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 19, bottomLeadingRadius: mio ? 19 : 6, bottomTrailingRadius: mio ? 6 : 19, topTrailingRadius: 19, style: .continuous)
    }

    private func notaDeVoz(_ m: MensajeSala, mio: Bool) -> some View {
        let sonando = chat.sonando == m.id
        let tinta: Color = mio ? .white : .primary
        return Button { chat.alternar(m) } label: {
            HStack(spacing: 10) {
                Image(systemName: sonando ? "pause.fill" : "play.fill")
                    .font(.body.weight(.bold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 30, height: 30)
                    .background(mio ? Color.white.opacity(0.25) : Color(.systemBackground), in: Circle())
                OndaNota(semilla: m.id, avance: sonando ? chat.avance : 0, color: tinta)
                    .frame(width: 120, height: 24)
                Text(Formato.reloj(m.duracion))
                    .font(.subheadline)
                    .monospacedDigit()
            }
            .foregroundStyle(tinta)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(mio ? Color.blue : Color(.systemGray5), in: forma(mio))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("Nota de voz de \(Formato.reloj(m.duracion))", "Voice message, \(Formato.reloj(m.duracion))",
                              "Nota vocale di \(Formato.reloj(m.duracion))"))
        .accessibilityHint(sonando ? L("Toca para parar", "Tap to stop", "Tocca per fermare") : L("Toca para escucharla", "Tap to listen", "Tocca per ascoltarla"))
    }

    private var entrada: some View {
        let grabando = chat.grabadora.grabando
        return HStack(spacing: 8) {
            if !grabando {
                PhotosPicker(selection: $fotos, maxSelectionCount: 10, selectionBehavior: .ordered, matching: .images) {
                    Image(systemName: "photo")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel(L("Mandar fotos", "Send photos", "Manda foto"))
            }
            if grabando {
                HStack {
                    Circle().fill(.red).frame(width: 9, height: 9)
                    Text(Formato.reloj(chat.grabadora.segundos)).monospacedDigit()
                    Spacer()
                    Text(cancelando ? L("Suelta para no mandarla", "Release to cancel", "Rilascia per annullare")
                                    : L("Desliza para cancelar", "Slide to cancel", "Scorri per annullare"))
                        .font(.subheadline)
                        .foregroundStyle(cancelando ? Color.red : Color.secondary)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .glassEffect(.regular, in: Capsule())
            } else {
                TextField(L("Mensaje", "Message", "Messaggio"), text: $texto, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($escribiendo)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .submitLabel(.send)
            }
            if !texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !grabando {
                Button {
                    chat.mandarTexto(texto)
                    texto = ""
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .accessibilityLabel(L("Mandar", "Send", "Invia"))
            } else {
                micro(grabando: grabando)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .animation(Diseno.muelle, value: grabando)
    }

    private func micro(grabando: Bool) -> some View {
        Image(systemName: "mic.fill")
            .font(.body.weight(.semibold))
            .foregroundStyle(grabando ? Color.white : Color.primary)
            .frame(width: 44, height: 44)
            .background(grabando ? Color.red : Color.clear, in: Circle())
            .glassEffect(grabando ? .identity : .regular.interactive(), in: Circle())
            .scaleEffect(grabando ? 1.25 : 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if !chat.grabadora.grabando && !empezando {
                            empezando = true
                            Task {
                                if await chat.grabadora.empezar() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() } else { sinMicro = true }
                                empezando = false
                            }
                        }
                        cancelando = v.translation.width < -80
                    }
                    .onEnded { _ in
                        if cancelando { chat.grabadora.cancelar() } else { Task { await chat.mandarVoz() } }
                        cancelando = false
                    }
            )
            .accessibilityLabel(L("Nota de voz", "Voice message", "Nota vocale"))
            .accessibilityHint(L("Mantén pulsado para grabar; suelta para mandarla.", "Touch and hold to record; release to send.",
                                 "Tieni premuto per registrare; rilascia per inviarla."))
            .accessibilityAction(named: L("Grabar", "Record", "Registra")) {
                Task { if await chat.grabadora.empezar() == false { sinMicro = true } }
            }
            .accessibilityAction(named: L("Mandar la nota", "Send the message", "Invia la nota")) { Task { await chat.mandarVoz() } }
    }

    @State private var empezando = false
}

struct OndaNota: View {
    var semilla: String
    var avance: Double
    var color: Color

    var body: some View {
        Canvas { ctx, tam in
            let n = 22
            let paso = tam.width / CGFloat(n)
            var h = semilla.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) }
            for i in 0..<n {
                h = h &* 6364136223846793005 &+ 1442695040888963407
                let alto = max(3, tam.height * (0.25 + 0.75 * CGFloat((h >> 33) % 1000) / 1000))
                let rect = CGRect(x: CGFloat(i) * paso + paso * 0.2, y: (tam.height - alto) / 2, width: paso * 0.55, height: alto)
                let hecho = Double(i) / Double(n) < avance
                ctx.fill(Path(roundedRect: rect, cornerRadius: paso * 0.3), with: .color(color.opacity(hecho ? 1 : 0.55)))
            }
        }
        .accessibilityHidden(true)
    }
}
