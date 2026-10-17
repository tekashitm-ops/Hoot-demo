import SwiftUI

enum RutaPruebas: Hashable {
    case prueba(UUID)
    case cielo
}

struct PruebasVista: View {
    @Environment(Almacen.self) private var almacen
    @State private var ruta = NavigationPath()
    @State private var nueva: HojaNueva?
    @State private var borrando: Prueba?
    @State private var nuevoDeAhora = false

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
                        cabecera(proximas, datos: datos, ahora: ahora)
                            .padding(.bottom, 2)
                        if proximas.isEmpty {
                            sinPruebas
                        } else {
                            tarjetaProximas(proximas, datos: datos, ahora: ahora)
                        }
                        if let pasada = sorpresaPendiente(datos, ahora: ahora) {
                            TarjetaSorpresa(prueba: pasada, asignatura: datos.asignatura(pasada.asignaturaID))
                        }
                        tarjetaDeAhora(datos)
                        tarjetaCielo(datos)
                    }
                    .padding(.horizontal, Diseno.margenTarjeta)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .environment(\.colorScheme, .dark)
            .environment(\.sobreCielo, true)
            .background { FondoTiempo() }
            .navigationTitle(L("Pruebas", "Tests", "Verifiche"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        nueva = .elegir
                    } label: {
                        Image(systemName: "plus")
                    }
                    .chocable(.circulo, reacciona: true)
                    .accessibilityLabel(L("Apuntar una prueba", "Add a test", "Aggiungi una verifica"))
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
            .sheet(isPresented: $nuevoDeAhora) {
                EditorTemaDeAhora()
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
        case "prueba": if let proxima { ruta.append(RutaPruebas.prueba(proxima.id)) }
        case "nueva-prueba": nueva = .con(.foto)
        case "nueva-prueba-elegir": nueva = .elegir
        case "tu-cielo": ruta.append(RutaPruebas.cielo)
        case "luna-llena": celebrando = almacen.datos.pruebas.first { p in p.temas.allSatisfy { $0.luna(cal: cal) == .llena } }
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
            if p.temas.allSatisfy({ $0.luna(cal: cal) == .llena }) { return (FrasesHoot.pruebaLista(asignatura: asig, dia: dia), .feliz) }
            if let nueva = p.temas.first(where: { $0.luna(cal: cal) == .nueva }) {
                return (FrasesHoot.repasoPendiente(asignatura: asig, dia: dia, tema: nueva.nombre), .preocupado)
            }
            let vacia = p.temas.min { $0.luna(cal: cal) < $1.luna(cal: cal) }
            return (FrasesHoot.repasoEnMarcha(tema: vacia?.nombre ?? asig), .normal)
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

    private func tarjetaDeAhora(_ datos: DatosEscolares) -> some View {
        let cal = calendarioActual
        let activos = datos.temasDeAhora.filter(\.activo)
        return TarjetaCielo(titulo: L("Temas de ahora", "Current topics", "Argomenti di adesso"), simbolo: "clock",
                            accion: (L("Añadir", "Add", "Aggiungi"), { nuevoDeAhora = true })) {
            if activos.isEmpty {
                Text(L("Lo que estáis dando ahora, por si te preguntan sin avisar.",
                       "What you're covering now, in case they quiz you out of nowhere.",
                       "Quello che state facendo adesso, nel caso ti interroghino senza preavviso."))
                    .font(.subheadline)
                    .foregroundStyle(EstiloSecundario())
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(activos.enumerated()), id: \.element.id) { n, a in
                    if n > 0 { Separador() }
                    let asig = datos.asignatura(a.asignaturaID)
                    HStack(spacing: 12) {
                        IconoAsignatura(asignatura: asig, lado: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(a.tema.nombre).font(.headline)
                            if let asig { Text(asig.nombre).font(.subheadline).foregroundStyle(EstiloSecundario()) }
                        }
                        Spacer(minLength: 8)
                        Luna(parte: a.tema.luna(cal: cal).fraccion, tamano: 26)
                    }
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                    .contextMenu {
                        Button(L("Ya pasó en clase", "Done in class", "Già fatto in classe"), systemImage: "checkmark") {
                            conMuelle {
                                if let i = almacen.datos.temasDeAhora.firstIndex(where: { $0.id == a.id }) {
                                    almacen.datos.temasDeAhora[i].activo = false
                                }
                            }
                        }
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

    var body: some View {
        HStack(spacing: 12) {
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
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                FilaLunas(partes: prueba.temas.prefix(6).map { $0.luna(cal: cal).fraccion }, tamano: 16, hueco: 3)
                Text(L("\(prueba.llenos(cal: cal)) de \(prueba.temas.count)", "\(prueba.llenos(cal: cal)) of \(prueba.temas.count)",
                       "\(prueba.llenos(cal: cal)) di \(prueba.temas.count)"))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(EstiloSecundario())
            }
        }
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
