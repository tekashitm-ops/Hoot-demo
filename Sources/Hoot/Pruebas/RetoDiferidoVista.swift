import SwiftUI

nonisolated struct DatosRetoDiferido: Codable, Sendable {
    var id: String
    var tema: String
    var preguntas: [RetoCercano.PreguntaReto]
    var aciertos: [Bool]

    var rival: [Bool] = []
}

@Observable
final class RetoDiferido {
    nonisolated enum Fase: Equatable { case preparando, jugando, corrigiendo, fin, error(String) }

    private(set) var fase: Fase = .preparando
    private(set) var preguntas: [RetoCercano.PreguntaReto] = []
    private(set) var actual = 0
    private(set) var mios: [Bool] = []

    let suyos: [Bool]?
    let rival: String
    let tema: String
    private(set) var ultimo: (bien: Bool, comentario: String)?

    @ObservationIgnored private let curso: String
    @ObservationIgnored private let nombreYo: String
    @ObservationIgnored private let temaIDs: [UUID]
    @ObservationIgnored private let para: Companero?
    @ObservationIgnored private let aviso: AvisoSala?
    @ObservationIgnored private let datosRecibidos: DatosRetoDiferido?

    init(para c: Companero, temas: [Tema], tema: String, curso: String, nombreYo: String) {
        para = c
        self.nombreYo = nombreYo
        aviso = nil
        datosRecibidos = nil
        suyos = nil
        rival = c.nombre
        self.tema = tema
        self.curso = curso
        temaIDs = temas.map(\.id)
        let materiales = temas.filter { !$0.textoLeido.isEmpty }.map(\.textoLeido)
        Task { await preparar(materiales) }
    }

    init(aviso a: AvisoSala, temas: [Tema], curso: String, nombreYo: String) {
        para = nil
        self.nombreYo = nombreYo
        aviso = a
        let d = try? JSONDecoder().decode(DatosRetoDiferido.self, from: Data(a.datos.utf8))
        datosRecibidos = d
        suyos = d?.aciertos
        rival = a.nombre
        tema = d?.tema ?? ""
        self.curso = curso
        temaIDs = temas.map(\.id)
        if let d, !d.preguntas.isEmpty {
            preguntas = d.preguntas
            fase = .jugando
        } else {
            fase = .error(L("Este reto no se puede abrir.", "This challenge can't be opened.", "Questa sfida non si può aprire."))
        }
    }

    var pregunta: RetoCercano.PreguntaReto? { preguntas.indices.contains(actual) ? preguntas[actual] : nil }
    var cuantas: Int { max(preguntas.count, 1) }

    var suyosHastaAhora: Int { (suyos ?? []).prefix(mios.count).filter { $0 }.count }

    private func preparar(_ materiales: [String]) async {
        guard DisponibilidadIA.actual == .lista else {
            fase = .error(L("Para retar, tu iPhone tiene que tener Apple Intelligence.", "To challenge, your iPhone needs Apple Intelligence.",
                            "Per sfidare, il tuo iPhone deve avere Apple Intelligence."))
            return
        }
        var lista: [RetoCercano.PreguntaReto] = []
        for (i, m) in materiales.enumerated() {
            let k = 4 / max(materiales.count, 1) + (i < 4 % max(materiales.count, 1) ? 1 : 0)
            guard k > 0 else { continue }
            lista += (try? await RetoCercano.generar(k, material: m)) ?? []
        }
        guard !lista.isEmpty else {
            fase = .error(L("No se han podido sacar preguntas del material.", "Couldn't make questions from the material.", "Non è stato possibile fare domande dal materiale."))
            return
        }
        preguntas = Array(lista.shuffled().prefix(4))
        conMuelle { fase = .jugando }
    }

    func responder(_ texto: String) {
        guard fase == .jugando, let p = pregunta else { return }
        fase = .corrigiendo
        Task {
            let bien = await RetoCercano.acierta(p, texto, curso: curso)
            conMuelle(Diseno.muelleRebote) {
                mios.append(bien)
                ultimo = (bien, L("Era: \(p.esperada)", "It was: \(p.esperada)", "Era: \(p.esperada)"))
            }
            try? await Task.sleep(for: .seconds(1.8))
            if actual + 1 < preguntas.count {
                conMuelle {
                    actual += 1
                    ultimo = nil
                    fase = .jugando
                }
            } else {
                await terminar()
            }
        }
    }

    private func terminar() async {
        guard let uid = await Nube.compartida.sesionActual?.uid else { conMuelle { fase = .fin }; return }
        let nombre = nombreYo
        var empuje = IDEmpuje()
        if let para {

            let d = DatosRetoDiferido(id: empuje.nuevo(), tema: tema, preguntas: preguntas, aciertos: mios)
            if let json = try? JSONEncoder().encode(d), let s = String(data: json, encoding: .utf8) {
                try? await BaseEnVivo.compartido.poner("buzon/\(para.uid)/\(empuje.nuevo())", [
                    "tipo": "reto", "de": .texto(uid), "nombre": .texto(nombre), "t": JSONVivo.horaServidor, "datos": .texto(s),
                ])
            }
        } else if let aviso, let d = datosRecibidos {

            let r = DatosRetoDiferido(id: d.id, tema: tema, preguntas: [], aciertos: mios, rival: d.aciertos)
            if let json = try? JSONEncoder().encode(r), let s = String(data: json, encoding: .utf8) {
                try? await BaseEnVivo.compartido.poner("buzon/\(aviso.de)/\(empuje.nuevo())", [
                    "tipo": "resultadoReto", "de": .texto(uid), "nombre": .texto(nombre), "t": JSONVivo.horaServidor, "datos": .texto(s),
                ])
            }
            Salas.compartidas.quitar(aviso)
        }
        conMuelle { fase = .fin }
    }

    func intento(fecha: Date = Reloj.ahora) -> (temas: [UUID], intento: Intento)? {
        guard !temaIDs.isEmpty, !mios.isEmpty else { return nil }
        return (temaIDs, Intento(fecha: fecha, respuestas: mios.map { Respuesta(acierto: $0, seguridad: nil) }, mezclado: temaIDs.count > 1))
    }
}

struct RetoDiferidoVista: View {
    var reto: RetoDiferido
    var alTerminar: () -> Void

    @Environment(Almacen.self) private var almacen
    @State private var respuesta = ""
    @State private var dictado = Dictado()
    @State private var apuntado = false

    var body: some View {
        NavigationStack {
            Group {
                switch reto.fase {
                case .preparando:
                    VStack(spacing: 18) {
                        Spacer()
                        LoboTrabajando(tamano: 130, gesto: .escribiendo)
                        Text(L("Preparando las preguntas…", "Getting the questions ready…", "Preparo le domande…")).font(.headline)
                        ProgressView()
                        Spacer()
                    }
                case .error(let m):
                    VStack {
                        Spacer()
                        HootDice(frase: m, gesto: .preocupado, tamano: 110, paraguasSiLlueve: false)
                        Spacer()
                    }
                    .padding(Diseno.margen)
                case .jugando, .corrigiendo, .fin:
                    jugando
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
                TituloBarra(titulo: L("Reto", "Challenge", "Sfida"),
                            subtitulo: reto.fase == .fin ? reto.tema : L("Pregunta \(reto.actual + 1) de \(reto.cuantas)", "Question \(reto.actual + 1) of \(reto.cuantas)",
                                                                         "Domanda \(reto.actual + 1) di \(reto.cuantas)"))
                ToolbarItem(placement: .cancellationAction) { BotonCerrar { alTerminar() } }
            }
        }
        .environment(\.colorScheme, .dark)
        .onDisappear { dictado.parar() }
        .onChange(of: reto.fase) { _, f in if f == .fin { apuntar() } }
    }

    private var jugando: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    jugador(L("Tú", "You", "Tu"), aciertos: reto.mios.filter { $0 }.count, oculto: false)
                    jugador(reto.rival, aciertos: reto.suyosHastaAhora, oculto: reto.suyos == nil)
                }
                LoboInteractivo(tamano: 104, gesto: reto.ultimo.map { $0.bien ? GestoLobo.feliz : .sorprendido } ?? (reto.fase == .fin ? .aullando : .hablando))
                Bocadillo(texto: frase, pico: .arriba)
                    .padding(.horizontal, 24)
                if reto.fase != .fin, let p = reto.pregunta {
                    Text(p.texto)
                        .font(.title3.weight(.bold))
                        .fontDesign(.rounded)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                    if let u = reto.ultimo {
                        Text(u.comentario).font(.subheadline).foregroundStyle(EstiloSecundario())
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
                    Button(action: alTerminar) { Text(L("Hecho", "Done", "Fatto")).frame(maxWidth: .infinity) }
                        .botonAmbar()
                } else if reto.fase == .jugando && reto.ultimo == nil {
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
        .sensoryFeedback(.success, trigger: reto.mios.filter { $0 }.count)
    }

    private func jugador(_ nombre: String, aciertos: Int, oculto: Bool) -> some View {
        VStack(spacing: 8) {
            Luna(parte: Double(aciertos) / Double(reto.cuantas), tamano: 132, brillo: aciertos == reto.cuantas)
                .opacity(oculto ? 0.45 : 1)
                .overlay { if oculto { Text("?").font(.system(.largeTitle, design: .rounded).weight(.bold)) } }
            Text(nombre).font(.headline).lineLimit(1)
            Text(oculto ? "–" : "\(aciertos)").font(.title.weight(.heavy)).fontDesign(.rounded).monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var frase: String {
        let yo = reto.mios.filter { $0 }.count
        if reto.fase == .fin {
            guard let suyos = reto.suyos else {
                return L("Hecho. Se lo he dejado a \(reto.rival): lo verá al abrir Hoot.", "Done. I've left it for \(reto.rival): they'll see it when they open Hoot.",
                         "Fatto. L'ho lasciata a \(reto.rival): la vedrà quando apre Hoot.")
            }
            let el = suyos.filter { $0 }.count
            if yo > el { return L("Ganas \(yo) a \(el). Ya le he contado a \(reto.rival) cómo ha ido.", "You win \(yo) to \(el). I've told \(reto.rival) how it went.",
                                  "Vinci \(yo) a \(el). Ho già detto a \(reto.rival) com'è andata.") }
            if yo == el { return L("Empate a \(yo). Dos lunas iguales: esto no lo había visto.", "A tie at \(yo). Two identical moons: never seen that.",
                                   "Pareggio a \(yo). Due lune uguali: mai visto.") }
            return L("Esta vez \(reto.rival), \(el) a \(yo). La revancha, cuando quieras.", "\(reto.rival) this time, \(el) to \(yo). Rematch whenever you want.",
                     "Stavolta \(reto.rival), \(el) a \(yo). La rivincita, quando vuoi.")
        }
        if reto.suyos == nil { return L("Juegas tú primero. Luego se lo dejo a \(reto.rival).", "You play first. Then I'll leave it for \(reto.rival).",
                                        "Giochi prima tu. Poi la lascio a \(reto.rival).") }
        return L("\(reto.rival) ya jugó: su luna va apareciendo según contestas.", "\(reto.rival) already played: their moon appears as you answer.",
                 "\(reto.rival) ha già giocato: la sua luna appare man mano che rispondi.")
    }

    private func apuntar() {
        guard !apuntado, !ModoCapturas.activo, let (ids, intento) = reto.intento() else { return }
        apuntado = true
        conMuelle { for id in ids { almacen.datos.apuntar(intento, enTema: id) } }
    }
}

struct OpcionesReto: View {
    var prueba: Prueba
    var alLado: () -> Void

    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var eligiendoCompanero = false
    @State private var diferido: RetoDiferido?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                opcion("antenna.radiowaves.left.and.right", .teal, L("Está a mi lado", "They're next to me", "È accanto a me"),
                       L("Con el radar, sin internet", "With the radar, no internet needed", "Con il radar, senza internet")) {
                    cerrar()
                    alLado()
                }
                Separador().padding(.leading, 82)
                opcion("house.fill", .indigo, L("Está en su casa", "They're at home", "È a casa sua"),
                       L("Una sala con código o invitación", "A room with a code or invitation", "Una stanza con codice o invito")) {
                    cerrar()
                    Salas.compartidas.retoPendiente = (prueba.temas.filter { !$0.textoLeido.isEmpty }, nombreTema)
                    Salas.compartidas.codigoPendiente = ""
                    Salas.compartidas.entrando = true
                }
                Separador().padding(.leading, 82)
                opcion("clock.fill", .orange, L("Cuando pueda", "Whenever they can", "Quando può"),
                       L("Le dejas el reto y lo hace al abrir Hoot", "Leave the challenge; they play it when they open Hoot",
                         "Gli lasci la sfida e la fa quando apre Hoot")) {
                    eligiendoCompanero = true
                }
            }
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Diseno.radioModulo, style: .continuous))
            .padding(Diseno.margen)
            .frame(maxHeight: .infinity, alignment: .top)
            .tenidaDelCielo(hoja: true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle(L("Retar a un amigo", "Challenge a Friend", "Sfida un amico"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar() } } }
            .confirmationDialog(L("¿A quién?", "Who?", "A chi?"), isPresented: $eligiendoCompanero, titleVisibility: .visible) {
                ForEach(SalasGuardadas.companeros.prefix(8)) { c in
                    Button(c.nombre) {
                        diferido = RetoDiferido(para: c, temas: prueba.temas.filter { !$0.textoLeido.isEmpty }, tema: nombreTema, curso: almacen.perfil.curso,
                                                nombreYo: almacen.perfil.nombre)
                    }
                }
            } message: {
                Text(SalasGuardadas.companeros.isEmpty
                     ? L("Antes tenéis que haber estado juntos en una sala.", "You need to have been in a room together first.", "Prima dovete essere stati insieme in una stanza.")
                     : L("Compañeros con los que ya estuviste en una sala.", "Classmates you've been in a room with.", "Compagni con cui sei già stato in una stanza."))
            }
            .fullScreenCover(item: Binding(get: { diferido.map(RetoDiferidoAbierto.init) }, set: { if $0 == nil { diferido = nil } })) { r in
                RetoDiferidoVista(reto: r.reto) { diferido = nil; cerrar() }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground { FondoHojaTenida() }
    }

    private var nombreTema: String {
        let temas = prueba.temas.filter { !$0.textoLeido.isEmpty }
        return temas.count == 1 ? temas[0].nombre : (almacen.datos.asignatura(prueba.asignaturaID)?.nombre ?? prueba.tipo.nombre)
    }

    private func opcion(_ simbolo: String, _ color: Color, _ titulo: String, _ detalle: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: 14) {
                Image(systemName: simbolo)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo).font(.headline).foregroundStyle(.white)
                    Text(detalle).font(.subheadline).foregroundStyle(EstiloSecundario())
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(EstiloSecundario())
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct RetoDiferidoAbierto: Identifiable {
    let reto: RetoDiferido
    var id: ObjectIdentifier { ObjectIdentifier(reto) }
}
