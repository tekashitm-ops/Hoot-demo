import SwiftUI

struct PeticionRepaso: Identifiable {
    let id = UUID()
    var temaIDs: [UUID]
    var mezclado: Bool

    var porTema = FaseLuna.minimoRespuestas

    var falladas = false

    var modo: ModoPrueba? = nil
}

struct RepasoTemas: View {
    var peticion: PeticionRepaso
    var alTerminar: () -> Void

    @Environment(Almacen.self) private var almacen
    @State private var prueba = PruebaIA()
    @State private var empezado = false

    private var lunaAhora: Double {
        guard let id = prueba.pregunta?.temaID else { return 0 }
        return prueba.parteEnVivo(id)
    }

    var body: some View {
        NavigationStack {
            VistaPrueba(prueba: prueba, alTerminar: alTerminar, alAcabar: apuntar)
                .tenidaDelCielo()
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .environment(\.pestanaVisible, false)

        .onChange(of: prueba.fase) { _, f in
            if f == .preguntando, !ModoCapturas.activo {
                let nombres = peticion.temaIDs.compactMap { almacen.datos.tema($0)?.nombre }
                ActividadEnDirecto.compartida.empezar(titulo: L("Repaso · \(nombres.prefix(2).joined(separator: ", "))", "Review · \(nombres.prefix(2).joined(separator: ", "))",
                                                                 "Ripasso · \(nombres.prefix(2).joined(separator: ", "))"),
                                                      simulacro: false, total: prueba.preguntas.count, luna: lunaAhora, fin: nil)
            } else if f == .terminada {
                ActividadEnDirecto.compartida.terminar()
            }
        }
        .onChange(of: prueba.actual) { _, a in
            ActividadEnDirecto.compartida.actualizar(pregunta: a + 1, total: prueba.preguntas.count, luna: lunaAhora, fin: nil)
        }
        .onDisappear { ActividadEnDirecto.compartida.terminar() }
        .onAppear {
            guard !empezado else { return }
            empezado = true

            if ModoCapturas.activo, let demo = ModoCapturas.repasoEjemplo(almacen, final: ModoCapturas.pantalla == "repaso-final") {
                prueba = demo
                if demo.fase == .terminada { apuntar(demo) }
                return
            }
            let cal = calendarioActual
            let datos = almacen.datos
            let temas = peticion.temaIDs.compactMap { datos.tema($0) }
            prueba.modo = peticion.modo ?? almacen.ajustes.modoPrueba
            prueba.curso = almacen.perfil.curso
            prueba.porTema = peticion.porTema
            prueba.asignatura = temas.first.flatMap { datos.asignaturaDeTema($0.id) }.flatMap { datos.asignatura($0)?.nombre }

            if peticion.modo == nil, temas.first.flatMap({ datos.prueba(deTema: $0.id) })?.tipo == .oral { prueba.modo = .oral }

            let ahora = Reloj.ahora
            let mezclado = peticion.falladas ? temas.count > 1 : peticion.mezclado
            let siAprueba = Dictionary(uniqueKeysWithValues: temas.map { t in
                let cuantas = peticion.falladas && !t.falladas.isEmpty ? t.falladas.count : peticion.porTema
                return (t.id, FaseLuna.de(t.intentos + [Intento(fecha: ahora, respuestas: Array(repeating: Respuesta(acierto: true, seguridad: nil),
                                                                                                 count: cuantas),
                                                                mezclado: mezclado)], cal: cal))
            })
            let fases = Dictionary(uniqueKeysWithValues: temas.map { ($0.id, $0.luna(cal: cal)) })
            if peticion.falladas {
                prueba.empezar(falladasDe: temas, fases: fases, siAprueba: siAprueba)
            } else {
                prueba.empezar(temas: temas, fases: fases, siAprueba: siAprueba, mezclar: peticion.mezclado)
            }
        }
    }

    private func apuntar(_ p: PruebaIA) {
        let intentos = p.intentos()
        guard !intentos.isEmpty else { return }
        var falladas: [UUID: [PreguntaFallada]] = [:]
        var acertadas: [UUID: Set<String>] = [:]
        for q in p.preguntas {
            guard let id = q.temaID, let v = q.veredicto else { continue }
            if v.fallada {
                falladas[id, default: []].append(PreguntaFallada(pregunta: q.pregunta, esperada: q.esperada, fecha: Reloj.ahora))
            } else {
                acertadas[id, default: []].insert(q.pregunta)
            }
        }
        conMuelle {
            for (id, intento) in intentos { almacen.datos.apuntar(intento, enTema: id) }
            for id in Set(falladas.keys).union(acertadas.keys) {
                almacen.datos.apuntarFalladas(falladas[id] ?? [], acertadas: acertadas[id] ?? [], enTema: id)
            }
        }
    }
}

struct SelectorSeguridad: View {
    @Bindable var prueba: PruebaIA

    var body: some View {
        VStack(spacing: 8) {
            Text(L("¿Cuánto de seguro estás?", "How sure are you?", "Quanto sei sicuro?"))
                .font(.subheadline)
                .foregroundStyle(EstiloSecundario())
            Picker(L("¿Cuánto de seguro estás?", "How sure are you?", "Quanto sei sicuro?"), selection: Binding(
                get: { prueba.pregunta?.seguridad },
                set: { s in if prueba.preguntas.indices.contains(prueba.actual) { prueba.preguntas[prueba.actual].seguridad = s } }
            )) {
                Text(L("Ni idea", "No idea", "Non so")).tag(Seguridad?.some(.niIdea))
                Text(L("Creo que sí", "I think so", "Credo di sì")).tag(Seguridad?.some(.creoQueSi))
                Text(L("Seguro", "Sure", "Sicuro")).tag(Seguridad?.some(.seguro))
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }
}

struct ResultadoRepaso: View {
    @Bindable var prueba: PruebaIA
    var alTerminar: () -> Void

    @Environment(Almacen.self) private var almacen
    @State private var crecidas = false
    @State private var celebrar: Prueba?
    @State private var aullado = false
    @Environment(\.dynamicTypeSize) private var letra
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        let cal = calendarioActual
        let datos = almacen.datos
        let ids = prueba.preguntas.compactMap(\.temaID).reduce(into: [UUID]()) { if !$0.contains($1) { $0.append($1) } }
        let temas = ids.compactMap { datos.tema($0) }
        let llenadas = temas.filter { $0.luna(cal: cal) == .llena && prueba.faseInicial[$0.id] != .llena }
        let calibracion = Calibracion(prueba.preguntas.compactMap { q in q.veredicto.map { Respuesta(acierto: !$0.fallada, seguridad: q.seguridad) } })
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HootDice(frase: frase(llenadas: llenadas, temas: temas, cal: cal),
                         gesto: llenadas.isEmpty ? (prueba.falladas.isEmpty ? .feliz : .normal) : .aullando,
                         tamano: 120, paraguasSiLlueve: false)
                VStack(spacing: 0) {
                    ForEach(Array(temas.enumerated()), id: \.element.id) { n, t in
                        if n > 0 { Separador() }
                        let antes = prueba.faseInicial[t.id] ?? .nueva
                        let ahora = t.luna(cal: cal)
                        HStack(spacing: 14) {
                            Luna(parte: crecidas ? ahora.fraccion : antes.fraccion, tamano: 46)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.nombre).font(.headline)
                                Text(EstadoLuna.texto(t, cal: cal))
                                    .font(.subheadline)
                                    .foregroundStyle(EstiloSecundario())
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, Diseno.margenTarjeta)
                .background(TonoCielo.actual(almacen).fila.color, in: RoundedRectangle(cornerRadius: Diseno.radioModulo, style: .continuous))
                if let linea = lineaCalibracion(calibracion) {
                    Label(linea, systemImage: "scope")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.top, 8)
        }
        .safeAreaBar(edge: .bottom) {
            let disposicion = letra.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 12))
            disposicion {
                Button { prueba.nuevaPrueba() } label: {
                    Text(L("Otra ronda", "Another round", "Un altro giro")).frame(maxWidth: letra.isAccessibilitySize ? .infinity : nil)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                Button {
                    if let p = pruebaEntera(temas) { celebrar = p } else { alTerminar() }
                } label: {
                    Text(L("Seguir", "Continue", "Continua")).frame(maxWidth: .infinity)
                }
                .botonAmbar()
                .controlSize(.large)
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, 8)
        }
        .navigationTitle(L("Tus lunas", "Your moons", "Le tue lune"))
        .onAppear {
            if reducirMovimiento { crecidas = true } else { withAnimation(Diseno.muelleRebote.delay(0.35)) { crecidas = true } }
            if llenadas.contains(where: { !prueba.aullados.contains($0.id) }), !aullado {
                aullado = true
                Task {
                    try? await Task.sleep(for: .milliseconds(420))
                    Sonidos.compartido.tocar(.aullido)
                }
            }
        }
        .fullScreenCover(item: $celebrar) { p in
            NocheDeLunaLlena(asignatura: datosAsignatura(p), temas: p.temas.map(\.nombre),
                             dia: Formato.diaEnFrase(p.fecha)) {
                celebrar = nil
                alTerminar()
            }
        }
    }

    private func datosAsignatura(_ p: Prueba) -> String {
        almacen.datos.asignatura(p.asignaturaID)?.nombre ?? L("Prueba", "Test", "Verifica")
    }

    private func pruebaEntera(_ temas: [Tema]) -> Prueba? {
        let cal = calendarioActual
        guard let t = temas.first, let p = almacen.datos.prueba(deTema: t.id), !p.temas.isEmpty,
              p.temas.allSatisfy({ $0.luna(cal: cal) == .llena }),
              p.temas.contains(where: { prueba.faseInicial[$0.id].map { $0 != .llena } ?? false }) else { return nil }
        return p
    }

    private func frase(llenadas: [Tema], temas: [Tema], cal: Calendar) -> String {
        if let t = llenadas.first { return FrasesHoot.lunaLlena(tema: t.nombre) }
        if prueba.falladas.isEmpty { return FrasesHoot.acierto(semilla: temas.count) }
        if let t = temas.min(by: { $0.luna(cal: cal) < $1.luna(cal: cal) }) { return FrasesHoot.repasoEnMarcha(tema: t.nombre) }
        return FrasesHoot.fallo(semilla: 0)
    }

    private func lineaCalibracion(_ c: Calibracion) -> String? {
        switch c.lectura {
        case .sinDatos: nil
        case .ajustada: L("Sabes cuánto sabes: cuando dices «seguro», aciertas.", "You know what you know: when you say “sure”, you're right.",
                          "Sai quanto sai: quando dici «sicuro», hai ragione.")
        case .demasiadoSeguro: L("Ojo: con «seguro» también fallas. Repasa esas.", "Careful: you miss some you were “sure” about. Review those.",
                                 "Attenzione: anche con «sicuro» sbagli. Ripassa quelle.")
        case .pocoSeguro: L("Sabes más de lo que crees.", "You know more than you think.", "Sai più di quanto pensi.")
        }
    }
}

enum EstadoLuna {
    static func texto(_ t: Tema, cal: Calendar) -> String {
        let sinFotos = t.textoLeido.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch t.luna(cal: cal) {
        case .llena: return L("Lo sabes", "You know it", "Lo sai")
        case .gibosa:
            let mezclado = t.intentos.contains { $0.aprueba && $0.mezclado }
            return mezclado ? L("Falta otro día", "One more day", "Manca un altro giorno")
                            : L("Falta mezclarlo con otros temas", "Mix it with other topics", "Manca mescolarlo con altri argomenti")
        case .cuarto: return L("Bien un día · falta otro", "Right one day · one more to go", "Bene un giorno · ne manca un altro")
        case .creciente: return L("Algo sabes", "You know some", "Qualcosa sai")
        case .nueva: return sinFotos ? L("Sin empezar · faltan las fotos", "Not started · needs photos", "Da iniziare · mancano le foto")
                                     : L("Sin empezar", "Not started", "Da iniziare")
        }
    }
}
