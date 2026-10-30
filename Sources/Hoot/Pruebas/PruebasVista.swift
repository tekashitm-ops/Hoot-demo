import SwiftUI

enum RutaPruebas: Hashable {
    case prueba(UUID)
    case cielo

    case asignatura(UUID?)
}

struct PruebasVista: View {
    @Environment(Almacen.self) private var almacen
    @State private var ruta = NavigationPath()
    @State private var nueva: HojaNueva?
    @State private var borrando: Prueba?

    @State private var busqueda = ModoCapturas.activo && ModoCapturas.pantalla == "buscar" ? "ro" : ""
    @State private var apuntandoTema: NuevoTema?
    @State private var examen = ModoCapturas.activo && ModoCapturas.pantalla == "examen"
    @State private var pendiente: PeticionRepaso?
    @State private var borrandoTema: Biblioteca.Entrada?
    @State private var repaso: PeticionRepaso?
    @State private var temaAbierto: UUIDIdentificable?

    @State private var charlaDemo: CharlaHoot?
    @State private var escuchandoDemo = false
    @State private var simulacroDe: UUID?
    @State private var simulacroDemo: SimulacroIA?
    @State private var retoDemo = false
    @State private var recibidoDemo: TemaCompartido?
    @State private var hablandoDemo: CharlaHoot?
    @State private var celebrando: Prueba?
    @State private var repasoDemo: PeticionRepaso?

    enum HojaNueva: Identifiable {
        case elegir
        case con(ComoApuntar)
        var id: String {
            switch self {
            case .elegir: "elegir"
            case .con(let c): c.rawValue
            }
        }
    }

    var body: some View {
        NavigationStack(path: $ruta) {
            TimelineView(.everyMinute) { contexto in
                let ahora = Reloj.desde(contexto.date)
                let datos = almacen.datos
                let cal = calendarioActual
                let proximas = datos.pruebas.filter { $0.diasQueFaltan(desde: ahora, cal: cal) >= 0 }.sorted { $0.fecha < $1.fecha }
                ScrollView {
                    VStack(alignment: .leading, spacing: Diseno.huecoTarjetas) {
                        if !busqueda.trimmingCharacters(in: .whitespaces).isEmpty {
                            resultados(datos)
                        } else {
                            cabecera(proximas, datos: datos, ahora: ahora)
                                .padding(.bottom, 2)
                            if proximas.isEmpty {
                                sinPruebas
                            } else {
                                tarjetaProximas(proximas, datos: datos, ahora: ahora)
                            }
                            if !ModoCapturas.sin("sorpresa"), let pasada = sorpresaPendiente(datos, ahora: ahora) {
                                TarjetaSorpresa(prueba: pasada, asignatura: datos.asignatura(pasada.asignaturaID))
                            }

                            if !ModoCapturas.sin("asignaturas") { tarjetaAsignaturas(datos) }
                            if !ModoCapturas.sin("fallado") { tarjetaFallado(datos, ahora: ahora) }
                            if !ModoCapturas.sin("cielo") { tarjetaCielo(datos) }
                            if !ModoCapturas.sin("pasadas") { tarjetaPasadas(datos, ahora: ahora) }
                        }
                    }
                    .padding(.horizontal, Diseno.margenTarjeta)
                    .padding(.bottom, 24)
                }
                .defaultScrollAnchor(ModoCapturas.sin("ancla") ? nil : (ModoCapturas.activo && ModoCapturas.pantalla == "pruebas-abajo" ? .bottom : .top))
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .searchable(text: $busqueda, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: Text(L("Buscar un tema", "Search topics", "Cerca un argomento")))
            .safeAreaBar(edge: .bottom) {

                if busqueda.isEmpty && almacen.datos.biblioteca().contains(where: { !$0.tema.textoLeido.isEmpty }) {
                    Button { examen = true } label: {
                        Label(L("Hazme un examen", "Quiz Me", "Fammi un compito"), systemImage: "sparkles")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .botonAmbar()
                    .controlSize(.large)
                    .chocable(.capsula, reacciona: true)
                    .padding(.horizontal, Diseno.margen)
                    .padding(.bottom, 8)
                }
            }
            .environment(\.colorScheme, .dark)
            .environment(\.sobreCielo, true)

            .environment(\.cieloSinVelo, true)
            .background { FondoTiempo(sinVelo: true) }

            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(L("Prueba", "Test", "Verifica"), systemImage: "moonphase.first.quarter") { nueva = .elegir }
                        Button(L("Tema", "Topic", "Argomento"), systemImage: "plus.viewfinder") { apuntandoTema = NuevoTema() }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .chocable(.circulo, reacciona: true)
                    .accessibilityLabel(L("Apuntar", "Add", "Aggiungi"))
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    BotonCuenta()
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .navigationDestination(for: RutaPruebas.self) { r in
                switch r {
                case .prueba(let id): PruebaDetalle(id: id)
                case .cielo: TuCielo()
                case .asignatura(let id): AsignaturaTemasVista(asignaturaID: id)
                }
            }
            .sheet(item: $nueva) { h in
                switch h {
                case .elegir: NuevaPrueba(empezarCon: nil) { id in ruta.append(RutaPruebas.prueba(id)) }
                case .con(let c): NuevaPrueba(empezarCon: c) { id in ruta.append(RutaPruebas.prueba(id)) }
                }
            }
            .fullScreenCover(item: $celebrando) { p in
                NocheDeLunaLlena(asignatura: almacen.datos.asignatura(p.asignaturaID)?.nombre ?? "", temas: p.temas.map(\.nombre),
                                 dia: Formato.diaEnFrase(p.fecha)) { celebrando = nil }
            }
            .fullScreenCover(item: $repasoDemo) { r in
                RepasoTemas(peticion: r) { repasoDemo = nil }
            }
            .task { await abrirEnCapturas() }
            .onChange(of: almacen.abrirPruebaID, initial: true) { _, id in
                guard let id else { return }
                almacen.abrirPruebaID = nil
                ruta = NavigationPath()
                ruta.append(RutaPruebas.prueba(id))
            }
            .fullScreenCover(item: $charlaDemo) { c in
                NavigationStack { CharlaVista(charla: c, alCerrar: { charlaDemo = nil }) }
            }
            .sheet(isPresented: $escuchandoDemo) { EscuchaloVista() }
            .simulacro(de: $simulacroDe)
            .fullScreenCover(isPresented: $retoDemo) {
                RetoVista(temas: [], nombreTema: "Historia") { retoDemo = false }
            }
            .sheet(item: $recibidoDemo) { t in
                RecibirTemaVista(tema: t) { recibidoDemo = nil }
            }
            .fullScreenCover(item: $simulacroDemo) { s in
                SimulacroVista(simulacro: s) { simulacroDemo = nil }
            }
            .fullScreenCover(item: $hablandoDemo) { c in
                HablarConHoot(charla: c) { hablandoDemo = nil }
            }
            .sheet(item: $apuntandoTema) { n in ApuntarTema(asignaturaInicial: n.asignaturaID, nombreInicial: n.nombre) }
            .sheet(isPresented: $examen, onDismiss: { if let p = pendiente { pendiente = nil; repaso = p } }) {
                ElegirTemas(para: .examen, asignaturaInicial: nil) { pendiente = $0 }
            }
            .confirmationDialog(L("¿Borrar «\(borrandoTema?.tema.nombre ?? "")»?", "Delete “\(borrandoTema?.tema.nombre ?? "")”?",
                                  "Eliminare «\(borrandoTema?.tema.nombre ?? "")»?"),
                                isPresented: Binding(get: { borrandoTema != nil }, set: { if !$0 { borrandoTema = nil } }),
                                titleVisibility: .visible, presenting: borrandoTema) { e in
                Button(L("Borrar el tema", "Delete Topic", "Elimina l'argomento"), role: .destructive) {
                    conMuelle { almacen.datos.borrarTema(e.id) }
                }
            } message: { _ in
                Text(L("Se borran sus fotos y su luna. No se puede deshacer.", "Its photos and its moon are deleted. This can't be undone.",
                       "Si cancellano le sue foto e la sua luna. Non si può annullare."))
            }
            .sheet(item: $temaAbierto) { t in
                TemaHoja(temaID: t.id) { ids in
                    temaAbierto = nil
                    repaso = PeticionRepaso(temaIDs: ids, mezclado: false)
                }
            }
            .fullScreenCover(item: $repaso) { r in
                RepasoTemas(peticion: r) { repaso = nil }
            }
            .confirmationDialog(L("¿Borrar esta prueba?", "Delete this test?", "Eliminare questa verifica?"),
                                isPresented: Binding(get: { borrando != nil }, set: { if !$0 { borrando = nil } }),
                                titleVisibility: .visible, presenting: borrando) { p in
                Button(L("Borrar", "Delete", "Elimina"), role: .destructive) {
                    conMuelle { almacen.datos.pruebas.removeAll { $0.id == p.id } }
                }
            } message: { _ in
                Text(L("Se borran sus temas, sus fotos y sus lunas. No se puede deshacer.",
                       "Its topics, photos and moons are deleted. This can't be undone.",
                       "Si eliminano argomenti, foto e lune. Non si può annullare."))
            }
        }
    }

    private func abrirEnCapturas() async {
        guard ModoCapturas.activo else { return }
        let cal = calendarioActual
        let proxima = almacen.datos.pruebas.filter { $0.diasQueFaltan(desde: Reloj.ahora, cal: cal) > 0 }.min { $0.fecha < $1.fecha }
        switch ModoCapturas.pantalla {
        case "prueba", "reto-opciones": if let proxima { ruta.append(RutaPruebas.prueba(proxima.id)) }
        case "tema", "tema-grande":

            if let t = proxima?.temas.first(where: { !$0.fuentes.isEmpty }) { temaAbierto = UUIDIdentificable(id: t.id) }
        case "charla", "charla-vacia", "charla-voz", "charla-fotos":
            guard let p = proxima, let t = p.temas.first(where: { !$0.fuentes.isEmpty }) else { break }
            let c = CharlaHoot(origen: .tema(t.id), titulo: t.nombre, asignatura: almacen.datos.asignatura(p.asignaturaID), curso: almacen.perfil.curso,
                               trozos: CharlaHoot.trozos(de: t), mensajes: ModoCapturas.pantalla == "charla-vacia" ? [] : ModoCapturas.mensajesCharla)
            if ModoCapturas.pantalla == "charla-voz" { hablandoDemo = c } else { charlaDemo = c }
        case "simulacro-empezar":
            simulacroDe = proxima?.id
        case "simulacro", "simulacro-papel", "simulacro-oral", "simulacro-corregido":
            guard let p = proxima else { break }
            let forma: SimulacroIA.Forma = ModoCapturas.pantalla == "simulacro-papel" ? .papel : (ModoCapturas.pantalla == "simulacro-oral" ? .oral : .iPhone)
            simulacroDemo = SimulacroIA.demo(prueba: p, asignatura: almacen.datos.asignatura(p.asignaturaID), forma: forma,
                                             corregido: ModoCapturas.pantalla == "simulacro-corregido")
        case "reto", "reto-radar":
            retoDemo = true
        case "recibir":
            guard let p = proxima, let t = p.temas.first(where: { !$0.fuentes.isEmpty }) else { break }
            recibidoDemo = t.compartido(de: "Sara", asignatura: almacen.datos.asignatura(p.asignaturaID)?.nombre)
        case "escuchando":

            guard let p = proxima, let t = p.temas.first(where: { !$0.fuentes.isEmpty }) else { break }
            ReproductorHoot.compartido.demo(almacen: almacen, tema: t, asignatura: almacen.datos.asignatura(p.asignaturaID)?.nombre, enPregunta: false)
        case "escuchalo", "escuchalo-pregunta":
            guard let p = proxima, let t = p.temas.first(where: { !$0.fuentes.isEmpty }) else { break }
            ReproductorHoot.compartido.demo(almacen: almacen, tema: t, asignatura: almacen.datos.asignatura(p.asignaturaID)?.nombre,
                                            enPregunta: ModoCapturas.pantalla == "escuchalo-pregunta")
            escuchandoDemo = true
        case "nueva-prueba": nueva = .con(.foto)
        case "nueva-prueba-elegir": nueva = .elegir
        case "tu-cielo": ruta.append(RutaPruebas.cielo)
        case "asignatura":

            if let id = proxima?.asignaturaID { ruta.append(RutaPruebas.asignatura(id)) }
        case "luna-llena": celebrando = proxima
        case "repaso", "repaso-final": repasoDemo = PeticionRepaso(temaIDs: [], mezclado: true)
        default: break
        }
    }

    private func cabecera(_ proximas: [Prueba], datos: DatosEscolares, ahora: Date) -> some View {
        let cal = calendarioActual
        let (frase, gesto): (String, GestoLobo) = {
            guard let p = proximas.first else { return (FrasesHoot.sinPruebas(), .pensando) }
            let asig = datos.asignatura(p.asignaturaID)?.nombre ?? L("La prueba", "The test", "La verifica")
            let dia = Formato.diaEnFrase(p.fecha, desde: ahora)

            let otra = FrasesHoot.hoy + 1
            if !p.temas.isEmpty && p.temas.allSatisfy({ $0.luna(cal: cal) == .llena }) { return (FrasesHoot.pruebaLista(asignatura: asig, dia: dia, semilla: otra), .feliz) }
            if let nueva = p.temas.first(where: { $0.luna(cal: cal) == .nueva }) {
                return (FrasesHoot.repasoPendiente(asignatura: asig, dia: dia, tema: nueva.nombre, semilla: otra), .preocupado)
            }
            let vacia = p.temas.min { $0.luna(cal: cal) < $1.luna(cal: cal) }
            return (FrasesHoot.repasoEnMarcha(tema: vacia?.nombre ?? asig, semilla: otra), .normal)
        }()
        return HootDice(frase: frase, gesto: gesto, tamano: 124, loboALaDerecha: true)
    }

    private func tarjetaProximas(_ proximas: [Prueba], datos: DatosEscolares, ahora: Date) -> some View {
        let cal = calendarioActual
        return TarjetaCielo(titulo: L("Próximas", "Coming up", "Prossime"), simbolo: "calendar") {
            ForEach(Array(proximas.enumerated()), id: \.element.id) { n, p in
                if n > 0 { Separador() }
                Button {
                    ruta.append(RutaPruebas.prueba(p.id))
                } label: {
                    FilaPrueba(prueba: p, asignatura: datos.asignatura(p.asignaturaID), ahora: ahora, cal: cal)
                }
                .buttonStyle(EstiloFilaCielo())
                .contextMenu {
                    Button(L("Borrar", "Delete", "Elimina"), systemImage: "trash", role: .destructive) { borrando = p }
                }
            }
        }
    }

    private var sinPruebas: some View {
        TarjetaCielo(titulo: L("Apunta una prueba", "Add a test", "Aggiungi una verifica"), simbolo: "plus") {
            BotonesApuntar { nueva = .con($0) }
                .padding(.vertical, 12)
        }
    }

    private func sorpresaPendiente(_ datos: DatosEscolares, ahora: Date) -> Prueba? {
        let cal = calendarioActual
        return datos.pruebas
            .filter { let d = $0.diasQueFaltan(desde: ahora, cal: cal); return d < 0 && d >= -3 && $0.sorpresaTemaID == nil && $0.temas.count > 1 }
            .max { $0.fecha < $1.fecha }
    }

    private func tarjetaAsignaturas(_ datos: DatosEscolares) -> some View {
        let grupos = Biblioteca.porAsignatura(datos.biblioteca())
        return TarjetaCielo(titulo: L("Asignaturas", "Subjects", "Materie"), simbolo: "books.vertical.fill",
                            accion: (L("Tema", "Topic", "Argomento"), { apuntandoTema = NuevoTema() })) {
            if grupos.isEmpty {
                Text(L("Apunta los temas que vais dando y aquí estarán, cada uno con su luna.",
                       "Add the topics you're covering and they'll be here, each with its moon.",
                       "Segna gli argomenti che state facendo e saranno qui, ognuno con la sua luna."))
                    .font(.subheadline)
                    .foregroundStyle(EstiloSecundario())
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(grupos.enumerated()), id: \.offset) { n, g in
                    if n > 0 { Separador() }
                    NavigationLink(value: RutaPruebas.asignatura(g.asignaturaID)) {
                        FilaAsignaturaBiblioteca(asignatura: datos.asignatura(g.asignaturaID), temas: g.temas)
                    }
                    .buttonStyle(EstiloFilaCielo())
                }
            }
        }
    }

    private func resultados(_ datos: DatosEscolares) -> some View {
        let encontrados = Biblioteca.buscar(busqueda, en: datos.biblioteca()) { datos.asignatura($0)?.nombre ?? "" }
        return TarjetaCielo(titulo: L("Temas", "Topics", "Argomenti"), simbolo: "magnifyingglass") {
            if encontrados.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("Ningún tema con «\(busqueda)».", "No topics with “\(busqueda)”.", "Nessun argomento con «\(busqueda)»."))
                        .font(.subheadline)
                        .foregroundStyle(EstiloSecundario())
                    Button {
                        apuntandoTema = NuevoTema(nombre: busqueda.trimmingCharacters(in: .whitespaces))
                    } label: {
                        Label(L("Apuntar «\(busqueda)» como tema", "Add “\(busqueda)” as a topic", "Aggiungi «\(busqueda)» come argomento"),
                              systemImage: "plus.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.large)
                }
                .padding(.vertical, 12)
            } else {
                ForEach(Array(encontrados.prefix(30).enumerated()), id: \.element.id) { n, e in
                    if n > 0 { Separador() }
                    Button { temaAbierto = UUIDIdentificable(id: e.id) } label: {
                        FilaTemaBiblioteca(entrada: e, conAsignatura: true)
                    }
                    .buttonStyle(EstiloFilaCielo())
                    .contextMenu {
                        if !e.tema.textoLeido.isEmpty {
                            Button { repaso = PeticionRepaso(temaIDs: [e.id], mezclado: false) } label: {
                                Label(L("Repasar", "Review", "Ripassa"), systemImage: "play.fill")
                            }
                        }
                        Button(role: .destructive) { borrandoTema = e } label: { Label(L("Borrar", "Delete", "Elimina"), systemImage: "trash") }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tarjetaFallado(_ datos: DatosEscolares, ahora: Date) -> some View {
        let cal = calendarioActual
        let lista = datos.porRepasar(ahora: ahora)
        let preguntas = lista.reduce(0) { $0 + $1.tema.falladas.count }
        let repasables = lista.filter { !$0.tema.falladas.isEmpty || !$0.tema.textoLeido.isEmpty }
        if !lista.isEmpty {
            TarjetaCielo(titulo: L("Repasar lo fallado", "Review what you missed", "Ripassa gli errori"), simbolo: "arrow.counterclockwise") {
                if preguntas > 0 {
                    Text(FrasesHoot.repasarFallado(preguntas))
                        .font(.subheadline)
                        .foregroundStyle(EstiloSecundario())
                        .padding(.top, 10)
                }
                ForEach(Array(lista.prefix(4).enumerated()), id: \.element.tema.id) { n, e in
                    if n > 0 { Separador() }
                    HStack(spacing: 12) {
                        Luna(parte: e.tema.luna(cal: cal).fraccion, tamano: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.tema.nombre).font(.headline)
                            Text(detalleFallado(e.tema, asignatura: datos.asignatura(e.asignaturaID), costo: e.costo))
                                .font(.subheadline)
                                .foregroundStyle(EstiloSecundario())
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 9)
                    .accessibilityElement(children: .combine)
                }
                if !repasables.isEmpty {
                    Button {
                        repaso = PeticionRepaso(temaIDs: repasables.prefix(4).map(\.tema.id), mezclado: repasables.count > 1, falladas: true)
                    } label: {
                        Text(L("Repasar", "Review", "Ripassa")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.large)
                    .chocable(.capsula, reacciona: true)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private func detalleFallado(_ t: Tema, asignatura: Asignatura?, costo: Bool) -> String {
        var partes: [String] = []
        if let asignatura { partes.append(asignatura.nombre) }
        if costo { partes.append(L("te costó en la prueba", "hard in the test", "ti è costato nella verifica")) }
        if !t.falladas.isEmpty {
            partes.append(t.falladas.count == 1 ? L("1 fallada", "1 missed", "1 sbagliata")
                                                : L("\(t.falladas.count) falladas", "\(t.falladas.count) missed", "\(t.falladas.count) sbagliate"))
        }
        return partes.joined(separator: " · ")
    }

    @ViewBuilder
    private func tarjetaPasadas(_ datos: DatosEscolares, ahora: Date) -> some View {
        let cal = calendarioActual
        let pasadas = datos.pruebas.filter { $0.diasQueFaltan(desde: ahora, cal: cal) < 0 }.sorted { $0.fecha > $1.fecha }
        if !pasadas.isEmpty {
            TarjetaCielo(titulo: L("Pasadas", "Past", "Passate"), simbolo: "clock.arrow.circlepath") {
                ForEach(Array(pasadas.prefix(8).enumerated()), id: \.element.id) { n, p in
                    if n > 0 { Separador() }
                    Button {
                        ruta.append(RutaPruebas.prueba(p.id))
                    } label: {
                        FilaPrueba(prueba: p, asignatura: datos.asignatura(p.asignaturaID), ahora: ahora, cal: cal)
                    }
                    .buttonStyle(EstiloFilaCielo())
                    .contextMenu {
                        Button(L("Borrar", "Delete", "Elimina"), systemImage: "trash", role: .destructive) { borrando = p }
                    }
                }
            }
        }
    }

    private func tarjetaCielo(_ datos: DatosEscolares) -> some View {
        let cielo = CieloDelCurso(datos: datos, cal: calendarioActual)
        return TarjetaCielo(titulo: L("Tu cielo", "Your sky", "Il tuo cielo"), simbolo: "sparkles") {
            Button {
                ruta.append(RutaPruebas.cielo)
            } label: {
                HStack(spacing: 14) {
                    ConstelacionTemas(cuantas: max(cielo.constelaciones.first?.estrellas.count ?? 5, 3),
                                      encendidas: cielo.constelaciones.first?.encendidas ?? 0)
                        .frame(width: 92, height: 56)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(cielo.encendidas == 1 ? L("1 estrella", "1 star", "1 stella")
                                                   : L("\(cielo.encendidas) estrellas", "\(cielo.encendidas) stars", "\(cielo.encendidas) stelle"))
                            .font(.headline)
                            .contentTransition(.numericText())
                        Text(cielo.encendidas == 0
                             ? L("Cada tema que sabes, una estrella", "Every topic you know, a star", "Ogni argomento che sai, una stella")
                             : L("\(cielo.constelaciones.count) asignaturas", "\(cielo.constelaciones.count) subjects", "\(cielo.constelaciones.count) materie"))
                            .font(.subheadline)
                            .foregroundStyle(EstiloSecundario())
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(EstiloSecundario())
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(EstiloFilaCielo())
        }
    }
}

struct FilaPrueba: View {
    var prueba: Prueba
    var asignatura: Asignatura?
    var ahora: Date
    var cal: Calendar
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        let disposicion = letra.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                                                    : AnyLayout(HStackLayout(spacing: 12))
        disposicion {
            IconoAsignatura(asignatura: asignatura, lado: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(asignatura?.nombre ?? prueba.temas.first?.nombre ?? L("Prueba", "Test", "Verifica"))
                    .font(.headline)
                HStack(spacing: 5) {
                    Text("\(prueba.tipo.nombre) · \(Formato.diaRelativo(prueba.fecha, desde: ahora))")
                    if prueba.tipo == .oral { Image(systemName: "waveform").font(.caption.weight(.semibold)) }
                    if prueba.privada { Image(systemName: "lock.fill").font(.caption) }
                }
                .font(.subheadline)
                .foregroundStyle(EstiloSecundario())
            }
            if !letra.isAccessibilitySize { Spacer(minLength: 8) }
            VStack(alignment: letra.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
                FilaLunas(partes: prueba.temas.prefix(6).map { $0.luna(cal: cal).fraccion }, tamano: 16, hueco: 3)
                Text(L("\(prueba.llenos(cal: cal)) de \(prueba.temas.count)", "\(prueba.llenos(cal: cal)) of \(prueba.temas.count)",
                       "\(prueba.llenos(cal: cal)) di \(prueba.temas.count)"))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(EstiloSecundario())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct Separador: View {
    var body: some View {
        Rectangle().fill(.white.opacity(0.14)).frame(height: 0.5)
    }
}

extension TipoPrueba {
    var nombre: String {
        switch self {
        case .escrita: L("Escrita", "Written", "Verifica")
        case .oral: L("Oral", "Oral", "Interrogazione")
        }
    }

    var simbolo: String { self == .oral ? "waveform" : "pencil.line" }
}

struct CieloDelCurso {
    struct Constelacion: Identifiable {
        var id: UUID?
        var asignatura: Asignatura?
        var estrellas: [Tema]
        var encendidas: Int
    }

    var constelaciones: [Constelacion] = []
    var encendidas: Int { constelaciones.reduce(0) { $0 + $1.encendidas } }

    init(datos: DatosEscolares, cal: Calendar) {
        var porAsignatura: [UUID?: [Tema]] = [:]
        var orden: [UUID?] = []
        let todos = datos.pruebas.sorted { $0.fecha < $1.fecha }.flatMap { p in p.temas.map { (p.asignaturaID, $0) } }
            + datos.temasDeAhora.map { ($0.asignaturaID, $0.tema) }
        for (asig, tema) in todos {
            if porAsignatura[asig] == nil { orden.append(asig) }
            porAsignatura[asig, default: []].append(tema)
        }
        constelaciones = orden.map { id in
            let temas = porAsignatura[id] ?? []
            return Constelacion(id: id, asignatura: datos.asignatura(id), estrellas: temas,
                                encendidas: temas.filter { $0.luna(cal: cal) == .llena }.count)
        }
        .sorted { $0.encendidas > $1.encendidas }
    }
}
