import AVKit
import SwiftUI

struct EscuchaloVista: View {
    @State private var r = ReproductorHoot.compartido
    @Environment(\.dismiss) private var cerrar
    @Environment(\.dynamicTypeSize) private var letra
    @ScaledMetric(relativeTo: .largeTitle) private var ladoPlay: CGFloat = 52

    var body: some View {
        GeometryReader { geo in
            let lado = min(geo.size.width - 2 * 40, geo.size.height * (letra.isAccessibilitySize ? 0.3 : 0.42))
            ScrollView {
                VStack(spacing: 0) {

                    HStack {
                        Spacer()
                        Menu {
                            Button { r.parar(); cerrar() } label: { Label(L("Dejar de escuchar", "Stop Listening", "Smetti di ascoltare"), systemImage: "stop.fill") }
                        } label: { Image(systemName: "ellipsis") }
                            .buttonStyle(.glass)
                            .buttonBorderShape(.circle)
                            .controlSize(.large)
                            .accessibilityLabel(L("Más", "More", "Altro"))
                    }
                    Spacer(minLength: 8)
                    portada(lado)
                    Spacer(minLength: 20)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(r.pista?.titulo ?? "").font(.title2.weight(.bold)).lineLimit(2)
                        Text(subtitulo).font(.body).foregroundStyle(EstiloSecundario())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 18)
                    progreso
                    Spacer(minLength: 16)
                    controles
                    Spacer(minLength: 16)
                    HStack {
                        Button { r.cambiarVelocidad() } label: {
                            Text(velocidadTexto).font(.subheadline.weight(.bold)).monospacedDigit()
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(EstiloMando())
                        .accessibilityLabel(L("Velocidad: \(velocidadTexto)", "Speed: \(velocidadTexto)", "Velocità: \(velocidadTexto)"))
                        Spacer()
                        if let s = r.siguientePista {
                            Text(L("A continuación: \(s.titulo)", "Up next: \(s.titulo)", "A seguire: \(s.titulo)"))
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Spacer()
                        }
                        SelectorAirPlay()
                            .frame(width: 44, height: 44)
                    }
                    .foregroundStyle(EstiloSecundario())
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .padding(.bottom, 16)
                .frame(minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .foregroundStyle(.white)
        .background {
            LinearGradient(colors: [Color(red: 0.055, green: 0.098, blue: 0.251), Color(red: 0.094, green: 0.153, blue: 0.353)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .presentationDragIndicator(.visible)
        .environment(\.colorScheme, .dark)
        .environment(\.sobreCielo, true)
    }

    private var subtitulo: String {
        let n = r.trozos.filter { if case .pregunta = $0 { return true } else { return false } }.count
        let contenido = n == 0 ? L("resumen", "summary", "riassunto") : L("resumen y \(n) preguntas", "summary and \(n) questions", "riassunto e \(n) domande")
        return [r.pista?.asignatura, r.trozos.isEmpty ? nil : contenido].compactMap { $0 }.joined(separator: " · ")
    }

    private var velocidadTexto: String {
        r.velocidad == 1 ? "1×" : (r.velocidad > 1 ? "1,25×" : "0,8×")
    }

    private func portada(_ lado: CGFloat) -> some View {
        PortadaEscuchalo(luna: r.pista?.luna ?? 0, lado: lado, conLobo: true, gesto: r.sonando && r.cuenta == nil ? .hablando : .normal)
            .overlay {
                if r.preparando {
                    ZStack {
                        Color.black.opacity(0.45)
                        VStack(spacing: 10) {
                            ProgressView().controlSize(.large).tint(.white)
                            Text(L("Hoot prepara el audio…", "Hoot is getting the audio ready…", "Hoot prepara l'audio…")).font(.subheadline.weight(.semibold))
                        }
                    }
                } else if let error = r.error {
                    ZStack {
                        Color.black.opacity(0.55)
                        Text(error).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center).padding(24)
                    }
                } else if let p = r.pregunta {
                    ZStack {
                        Color.black.opacity(0.55)
                        VStack(spacing: 16) {
                            Text(p)
                                .font(.title3.weight(.bold))
                                .fontDesign(.rounded)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.7)
                            if let c = r.cuenta {
                                CuentaAtras(queda: c, total: ReproductorHoot.pausaPregunta)
                                    .frame(width: lado * 0.3, height: lado * 0.3)
                            } else if let resp = r.respuesta {
                                VStack(spacing: 4) {
                                    Text(L("La respuesta", "The answer", "La risposta")).font(.footnote.weight(.semibold)).foregroundStyle(EstiloSecundario())
                                    Text(resp).font(.headline).multilineTextAlignment(.center)
                                }
                            }
                        }
                        .padding(22)
                    }
                    .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.45), radius: 24, y: 14)
            .scaleEffect(r.sonando || r.preparando ? 1 : 0.88)
            .animation(Diseno.muelle, value: r.sonando)
            .animation(Diseno.muelle, value: r.pregunta)
            .accessibilityElement(children: .combine)
    }

    private var progreso: some View {
        let total = max(r.duracion, 1)
        let resumen = r.duracionResumen
        let hecho = r.transcurrido
        return VStack(spacing: 7) {
            GeometryReader { g in
                let hueco: CGFloat = 4
                let anchoResumen = (g.size.width - hueco) * resumen / total
                HStack(spacing: hueco) {
                    barra(lleno: min(hecho, resumen) / max(resumen, 0.1), ancho: anchoResumen)
                    barra(lleno: max(0, hecho - resumen) / max(total - resumen, 0.1), ancho: g.size.width - hueco - anchoResumen)
                }
            }
            .frame(height: 6)

            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(Self.tiempo(hecho))
                    Spacer()
                    parte
                    Spacer()
                    Text("−" + Self.tiempo(max(0, total - hecho)))
                }
                VStack(spacing: 4) {
                    HStack {
                        Text(Self.tiempo(hecho))
                        Spacer()
                        Text("−" + Self.tiempo(max(0, total - hecho)))
                    }
                    parte
                }
            }
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(EstiloSecundario())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Quedan \(Self.tiempo(max(0, total - hecho)))", "\(Self.tiempo(max(0, total - hecho))) left", "Mancano \(Self.tiempo(max(0, total - hecho)))"))
    }

    @ViewBuilder
    private var parte: some View {
        if !r.trozos.isEmpty {
            Text(r.enPreguntas ? L("Preguntas", "Questions", "Domande") : L("Resumen", "Summary", "Riassunto"))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
    }

    private func barra(lleno: Double, ancho: CGFloat) -> some View {
        Capsule()
            .fill(.white.opacity(0.25))
            .frame(width: max(ancho, 0))
            .overlay(alignment: .leading) {
                Capsule().fill(.white).frame(width: max(ancho, 0) * min(max(lleno, 0), 1))
            }
    }

    private var controles: some View {
        HStack {
            Button { r.atras() } label: { Image(systemName: "backward.fill").font(.title) }
                .accessibilityLabel(L("Anterior", "Previous", "Precedente"))
            Spacer()
            Button { r.alternar() } label: {
                Image(systemName: r.sonando ? "pause.fill" : "play.fill")
                    .font(.system(size: ladoPlay))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 72, height: 72)
            }
            .accessibilityLabel(r.sonando ? L("Pausa", "Pause", "Pausa") : L("Reproducir", "Play", "Riproduci"))
            Spacer()
            Button { r.adelante() } label: { Image(systemName: "forward.fill").font(.title) }
                .accessibilityLabel(L("Siguiente", "Next", "Successivo"))
        }
        .buttonStyle(EstiloMando())
        .padding(.horizontal, 20)
        .disabled(r.preparando || r.trozos.isEmpty)
        .sensoryFeedback(.impact(weight: .light), trigger: r.sonando)
    }

    static func tiempo(_ s: Double) -> String {
        let t = Int(s.rounded())
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

private struct CuentaAtras: View {
    var queda: Double
    var total: Double

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: queda / max(total, 0.1))
                .stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: queda)
            Text("\(Int(queda.rounded(.up)))")
                .font(.title.weight(.heavy))
                .fontDesign(.rounded)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
        }
        .accessibilityLabel(L("Piensa la respuesta: \(Int(queda.rounded(.up))) segundos", "Think of the answer: \(Int(queda.rounded(.up))) seconds", "Pensa alla risposta: \(Int(queda.rounded(.up))) secondi"))
    }
}

private struct SelectorAirPlay: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let v = AVRoutePickerView()
        v.tintColor = UIColor.white.withAlphaComponent(0.86)
        v.activeTintColor = UIColor(Color.ambar)
        v.prioritizesVideoDevices = false
        return v
    }

    func updateUIView(_ v: AVRoutePickerView, context: Context) {}
}

struct MiniReproductor: View {
    @State private var r = ReproductorHoot.compartido
    var abrir: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: abrir) {
                HStack(spacing: 10) {
                    PortadaEscuchalo(luna: r.pista?.luna ?? 0, lado: 34, conLobo: false)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(r.pista?.titulo ?? "").font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text(r.preparando ? L("Preparando…", "Getting ready…", "Preparazione…") : "Hoot").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("Escúchalo: \(r.pista?.titulo ?? "")", "Listen: \(r.pista?.titulo ?? "")", "Ascoltalo: \(r.pista?.titulo ?? "")"))
            Button { r.alternar() } label: {
                Image(systemName: r.sonando ? "pause.fill" : "play.fill").font(.title3).contentTransition(.symbolEffect(.replace))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(EstiloMando())
            .accessibilityLabel(r.sonando ? L("Pausa", "Pause", "Pausa") : L("Reproducir", "Play", "Riproduci"))
            Button { r.adelante() } label: {
                Image(systemName: "forward.fill").font(.title3).frame(width: 36, height: 36)
            }
            .buttonStyle(EstiloMando())
            .accessibilityLabel(L("Siguiente", "Next", "Successivo"))
        }
        .padding(.horizontal, 12)
        .disabled(r.preparando && r.trozos.isEmpty)
    }
}

struct EstiloMando: ButtonStyle {
    @Environment(\.isEnabled) private var activo

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .opacity(!activo ? 0.4 : (configuration.isPressed ? 0.6 : 1))
            .animation(Diseno.muelleRapido, value: configuration.isPressed)
    }
}
