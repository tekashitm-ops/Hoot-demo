import SwiftUI

struct RetoVista: View {
    var temas: [Tema]
    var nombreTema: String

    var externo: RetoCercano? = nil
    var alTerminar: () -> Void

    @Environment(Almacen.self) private var almacen
    @State private var reto: RetoCercano?
    @State private var respuesta = ""
    @State private var dictado = Dictado()
    @State private var apuntado = false

    var body: some View {
        NavigationStack {
            Group {
                if let reto {
                    contenido(reto)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.white)
            .background {
                LinearGradient(colors: [Color(red: 0.055, green: 0.098, blue: 0.251), Color(red: 0.094, green: 0.153, blue: 0.353)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                TituloBarra(titulo: L("Reto", "Challenge", "Sfida"), subtitulo: subtitulo)
                ToolbarItem(placement: .cancellationAction) {
                    BotonCerrar {
                        reto?.salir()
                        alTerminar()
                    }
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .task {
            guard reto == nil else { return }
            if let externo { reto = externo; return }
            let r = RetoCercano(nombre: almacen.perfil.nombre)
            if ModoCapturas.activo {
                r.demo(fase: ModoCapturas.pantalla == "reto" ? .jugando : .buscando, rival: "Marco")
            } else {
                r.buscar(temas: temas, nombreTema: nombreTema, curso: almacen.perfil.curso)
            }
            reto = r
        }
        .onDisappear {
            dictado.parar()
            reto?.salir()
        }
    }

    private var subtitulo: String {
        guard let reto else { return nombreTema }
        switch reto.fase {
        case .jugando: return L("Pregunta \(reto.actual + 1) de \(reto.cuantas)", "Question \(reto.actual + 1) of \(reto.cuantas)", "Domanda \(reto.actual + 1) di \(reto.cuantas)")
        default: return reto.tema.isEmpty ? nombreTema : reto.tema
        }
    }

    @ViewBuilder
    private func contenido(_ reto: RetoCercano) -> some View {
        switch reto.fase {
        case .buscando, .invitando:
            if externo != nil {

                VStack(spacing: 18) {
                    Spacer()
                    HootDice(frase: L("Ya le he avisado. Si tarda, es que está buscando el estuche.", "I've told them. If they take a while, they're looking for their pencil case.",
                                      "Gliel'ho detto. Se ci mette tanto, sta cercando l'astuccio."),
                             gesto: .pensando, tamano: 120, paraguasSiLlueve: false)
                    ProgressView()
                    Spacer()
                }
                .padding(Diseno.margen)
            } else {
                buscando(reto)
            }
        case .preparando:
            VStack(spacing: 18) {
                Spacer()
                LoboTrabajando(tamano: 130, gesto: .escribiendo)
                Text(reto.anfitrion ? L("Preparando las preguntas…", "Getting the questions ready…", "Preparo le domande…")
                                    : L("\(reto.rival) prepara las preguntas…", "\(reto.rival) is getting the questions ready…", "\(reto.rival) prepara le domande…"))
                    .font(.headline)
                ProgressView()
                Spacer()
            }
        case .jugando, .fin:
            jugando(reto)
        case .error(let m):
            VStack(spacing: 16) {
                Spacer()
                HootDice(frase: m, gesto: .preocupado, tamano: 110, paraguasSiLlueve: false)
                Spacer()
            }
            .padding(Diseno.margen)
        }
    }

    private func buscando(_ reto: RetoCercano) -> some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            ZStack {
                RadarReto()
                    .frame(width: 300, height: 300)
                LoboInteractivo(tamano: 100, gesto: .normal)
                ForEach(Array(reto.amigos.enumerated()), id: \.element.id) { i, a in
                    let angulo = Double(i) * 2.4 + 0.6
                    Button { reto.retar(a) } label: {
                        VStack(spacing: 6) {
                            Text(String(a.nombre.prefix(1)).uppercased())
                                .font(.title2.weight(.bold))
                                .frame(width: 58, height: 58)
                                .background(Circle().fill([Color.blue, .orange, .green, .purple][i % 4].gradient))
                                .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 3))
                            Text(a.nombre).font(.subheadline.weight(.semibold)).lineLimit(1)
                        }
                    }
                    .buttonStyle(EstiloMando())
                    .offset(x: cos(angulo) * 118, y: sin(angulo) * 118)
                    .accessibilityLabel(L("Retar a \(a.nombre)", "Challenge \(a.nombre)", "Sfida \(a.nombre)"))
                }
            }
            if case .invitando(let n) = reto.fase {
                Bocadillo(texto: L("Esperando a que \(n) acepte…", "Waiting for \(n) to accept…", "Aspetto che \(n) accetti…"), pico: .arriba)
                    .padding(.horizontal, 40)
            } else {
                Bocadillo(texto: L("Busco rival. Que sepa de \(FrasesHoot.enFrase(reto.tema.isEmpty ? nombreTema : reto.tema)), o que por lo menos lo intente.",
                                   "Looking for a rival. Someone who knows \(FrasesHoot.enFrase(reto.tema.isEmpty ? nombreTema : reto.tema)), or at least tries.",
                                   "Cerco un rivale. Che sappia di \(FrasesHoot.enFrase(reto.tema.isEmpty ? nombreTema : reto.tema)), o che almeno ci provi."),
                          pico: .arriba)
                    .padding(.horizontal, 40)
            }
            Spacer(minLength: 0)
            Text(reto.amigos.isEmpty ? L("Pide a tu amigo que abra el reto en su Hoot", "Ask your friend to open the challenge in their Hoot", "Chiedi al tuo amico di aprire la sfida nel suo Hoot")
                                     : L("Toca a quien quieras retar", "Tap who you want to challenge", "Tocca chi vuoi sfidare"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EstiloSecundario())
            Text(L("Solo ves a quien tiene Hoot abierto a tu lado", "You only see people with Hoot open next to you", "Vedi solo chi ha Hoot aperto accanto a te"))
                .font(.footnote)
                .foregroundStyle(EstiloSecundario())
                .padding(.bottom, 12)
        }
        .padding(.horizontal, Diseno.margen)
        .alert(L("\(reto.invitacion?.nombre ?? "") te reta", "\(reto.invitacion?.nombre ?? "") challenges you", "\(reto.invitacion?.nombre ?? "") ti sfida"),
               isPresented: Binding(get: { reto.invitacion != nil }, set: { if !$0 { reto.responderInvitacion(false) } })) {
            Button(L("Aceptar", "Accept", "Accetta")) { reto.responderInvitacion(true) }
            Button(L("Ahora no", "Not Now", "Non ora"), role: .cancel) { reto.responderInvitacion(false) }
        } message: {
            Text(reto.invitacion?.tema ?? "")
        }
    }

    private func jugando(_ reto: RetoCercano) -> some View {
        let n = max(reto.cuantas, 1)
        return ScrollView {
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    jugador(L("Tú", "You", "Tu"), aciertos: reto.aciertosYo, de: n, marca: reto.ultimo?.yo)
                    jugador(reto.rival, aciertos: reto.aciertosRival, de: n, marca: reto.ultimo?.rival)
                }
                LoboInteractivo(tamano: 104, gesto: gesto(reto))
                Bocadillo(texto: frase(reto), pico: .arriba)
                    .padding(.horizontal, 24)
                if reto.fase == .jugando, let p = reto.pregunta {
                    Text(p.texto)
                        .font(.title3.weight(.bold))
                        .fontDesign(.rounded)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                    if let u = reto.ultimo {
                        Text(u.comentario).font(.subheadline).foregroundStyle(EstiloSecundario())
                    } else if reto.contestada {
                        Text(L("Esperando a \(reto.rival)…", "Waiting for \(reto.rival)…", "Aspetto \(reto.rival)…")).font(.subheadline).foregroundStyle(EstiloSecundario())
                    } else {
                        CampoRespuesta(texto: $respuesta, dictado: dictado, lineas: 1...3)
                    }
                }
            }
            .padding(Diseno.margen)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaBar(edge: .bottom) {
            Group {
                if reto.fase == .fin {
                    Button {
                        apuntar(reto)
                        alTerminar()
                    } label: { Text(L("Hecho", "Done", "Fatto")).frame(maxWidth: .infinity) }
                        .botonAmbar()
                } else if !reto.contestada {
                    Button {
                        dictado.parar()
                        reto.responder(respuesta)
                        respuesta = ""
                    } label: { Text(L("Responder", "Answer", "Rispondi")).frame(maxWidth: .infinity) }
                        .botonAmbar()
                        .disabled(respuesta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .controlSize(.large)
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, 8)
        }
        .sensoryFeedback(.success, trigger: reto.aciertosYo)
        .onChange(of: reto.fase) { _, f in if f == .fin { apuntar(reto) } }
    }

    private func jugador(_ nombre: String, aciertos: Int, de n: Int, marca: Bool?) -> some View {
        VStack(spacing: 8) {
            Luna(parte: Double(aciertos) / Double(n), tamano: 132, brillo: aciertos == n)
                .overlay(alignment: .topTrailing) {
                    if let marca {
                        Image(systemName: marca ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, marca ? Color.green : Color.red)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            Text(nombre).font(.headline).lineLimit(1)
            Text("\(aciertos)").font(.title.weight(.heavy)).fontDesign(.rounded).monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func gesto(_ r: RetoCercano) -> GestoLobo {
        if r.fase == .fin { return r.aciertosYo >= r.aciertosRival ? .aullando : .sorprendido }
        if let u = r.ultimo { return u.yo ? .feliz : .sorprendido }
        return .hablando
    }

    private func frase(_ r: RetoCercano) -> String {
        if r.fase == .fin {
            if r.aciertosYo > r.aciertosRival { return L("Luna llena primero. AUUU.", "Full moon first. AWOOO.", "Luna piena per primo. AUUU.") }
            if r.aciertosYo == r.aciertosRival { return L("Empate. Las dos lunas iguales: esto no lo había visto.", "A tie. Two identical moons: never seen that.", "Pareggio. Due lune uguali: mai visto.") }
            return L("Esta vez \(r.rival). La revancha, cuando quieras.", "\(r.rival) this time. Rematch whenever you want.", "Stavolta \(r.rival). La rivincita, quando vuoi.")
        }
        if r.aciertosRival > r.aciertosYo { return L("\(r.rival) va a toda pastilla. Respira: aún queda luna.", "\(r.rival) is flying. Breathe: there's moon left.", "\(r.rival) va a tutta birra. Respira: c'è ancora luna.") }
        if r.aciertosYo > r.aciertosRival { return L("Vas por delante. No te relajes, que \(r.rival) muerde.", "You're ahead. Don't relax, \(r.rival) bites.", "Sei avanti. Non rilassarti, \(r.rival) morde.") }
        return L("Igualados. Esto se pone interesante.", "Neck and neck. Getting interesting.", "Pari. Si fa interessante.")
    }

    private func apuntar(_ r: RetoCercano) {
        guard !apuntado, !ModoCapturas.activo, let (ids, intento) = r.intento() else { return }
        apuntado = true
        conMuelle { for id in ids { almacen.datos.apuntar(intento, enTema: id) } }
    }
}

private struct RadarReto: View {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reducirMovimiento)) { contexto in
            let t = contexto.date.timeIntervalSinceReferenceDate
            Canvas { c, tam in
                let centro = CGPoint(x: tam.width / 2, y: tam.height / 2)
                let r = min(tam.width, tam.height) / 2
                for k in 1...3 {
                    let rr = r * Double(k) / 3
                    c.stroke(Path(ellipseIn: CGRect(x: centro.x - rr, y: centro.y - rr, width: rr * 2, height: rr * 2)), with: .color(.white.opacity(0.16)), lineWidth: 1)
                }
                if !reducirMovimiento {
                    let f = (t.truncatingRemainder(dividingBy: 2.6)) / 2.6
                    let rr = r * (0.25 + 0.75 * f)
                    c.stroke(Path(ellipseIn: CGRect(x: centro.x - rr, y: centro.y - rr, width: rr * 2, height: rr * 2)),
                             with: .color(Color.ambar.opacity(0.55 * (1 - f))), lineWidth: 2)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
