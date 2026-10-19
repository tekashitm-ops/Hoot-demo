import PhotosUI
import SwiftUI

struct PruebaDetalle: View {
    var id: UUID

    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var editando = false
    @State private var borrando = false
    @State private var repaso: PeticionRepaso?
    @State private var temaAbierto: UUIDIdentificable?
    @State private var simulacroDe: UUID?
    @State private var retando = false
    @State private var opcionesReto = false
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        if let p = almacen.datos.pruebas.first(where: { $0.id == id }) {
            contenido(p)
        } else {
            ContentUnavailableView(L("Ya no está", "It's gone", "Non c'è più"), systemImage: "moon")
                .tenidaDelCielo()
        }
    }

    private func contenido(_ p: Prueba) -> some View {
        let cal = calendarioActual
        let datos = almacen.datos
        let asig = datos.asignatura(p.asignaturaID)
        let ahora = Reloj.ahora
        let faltan = p.diasQueFaltan(desde: ahora, cal: cal)
        let plan = datos.planRepaso(ajustes: almacen.ajustes, ahora: ahora)
        let sesiones = plan.sesiones(de: p).filter { $0.dia >= cal.startOfDay(for: ahora) }.prefix(6)
        return List {
            Section {
                cabecera(p, asig: asig, faltan: faltan, cal: cal)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: Diseno.margen, bottom: 8, trailing: Diseno.margen))

            if faltan < 0, p.sorpresaTemaID == nil, p.temas.count > 1 {
                Section {
                    SorpresaChips(prueba: p)
                } header: {
                    Text(FrasesHoot.despuesPrueba()).foregroundStyle(EstiloSecundario())
                }
                .filaTenida()
            }

            Section {
                ForEach(p.temas) { t in
                    Button {
                        temaAbierto = UUIDIdentificable(id: t.id)
                    } label: {
                        HStack(spacing: 14) {
                            Luna(parte: t.luna(cal: cal).fraccion, tamano: 42)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.nombre).font(.headline).foregroundStyle(.white)
                                HStack(spacing: 5) {
                                    if t.luna(cal: cal) == .llena {
                                        Image(systemName: "star.fill").foregroundStyle(Color.ambar).font(.caption)
                                    }
                                    Text(EstadoLuna.texto(t, cal: cal))
                                    if !t.miniaturas.isEmpty {
                                        Text("· \(t.miniaturas.count)")
                                        Image(systemName: "photo").font(.caption)
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(EstiloSecundario())
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(EstiloSecundario())
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text(L("Temas", "Topics", "Argomenti")).foregroundStyle(EstiloSecundario())
            }
            .filaTenida()

            if faltan >= 0 {
                Section {
                    if plan.justas.contains(p.id) {
                        Label(L("Va justa: no da tiempo a llenar todas las lunas. Empieza hoy.",
                                "Tight: not enough time to fill every moon. Start today.",
                                "È al pelo: non c'è tempo per riempire tutte le lune. Inizia oggi."),
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(EstiloAviso(color: .pronto))
                    }
                    if sesiones.isEmpty {
                        Text(faltan == 0 ? L("Es hoy. Suerte, aunque no la necesitas.", "It's today. Good luck, not that you need it.",
                                             "È oggi. In bocca al lupo, anche se non serve.")
                                         : L("Sin ratos libres hasta el día.", "No free time before the day.", "Nessun momento libero fino al giorno."))
                            .foregroundStyle(EstiloSecundario())
                    }
                    ForEach(Array(sesiones), id: \.id) { s in
                        FilaSesionRepaso(sesion: s, datos: datos, ahora: ahora)
                    }
                } header: {
                    Text(L("Plan", "Plan", "Piano")).foregroundStyle(EstiloSecundario())
                }
                .filaTenida()
            }
            if letra.isAccessibilitySize {
                Section {
                    Button { evaluar(p, plan: plan) } label: {
                        Text(tocaSimulacro(p, plan: plan) ? L("Simulacro", "Mock test", "Simulazione") : L("Evalúame", "Quiz me", "Interrogami")).frame(maxWidth: .infinity)
                    }
                    .botonAmbar()
                    .controlSize(.large)
                    .disabled(p.temas.isEmpty)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
        }
        .tenidaDelCielo()
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaBar(edge: .bottom) {
            if !letra.isAccessibilitySize {
            HStack(spacing: 12) {
                Button {
                    temaAbierto = (p.temas.first { $0.textoLeido.isEmpty } ?? p.temas.first).map { UUIDIdentificable(id: $0.id) }
                } label: {
                    Label(L("Fotos", "Photos", "Foto"), systemImage: "camera.fill")
                        .frame(maxWidth: letra.isAccessibilitySize ? .infinity : nil)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                Button {
                    evaluar(p, plan: plan)
                } label: {
                    Text(tocaSimulacro(p, plan: plan) ? L("Simulacro", "Mock test", "Simulazione") : L("Evalúame", "Quiz me", "Interrogami")).frame(maxWidth: .infinity)
                }
                .botonAmbar()
                .controlSize(.large)
                .disabled(p.temas.isEmpty)
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, 8)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(L("Editar", "Edit", "Modifica"), systemImage: "pencil") { editando = true }
                    if faltan >= 0 {
                        Button(L("Hacer el simulacro", "Take the Mock Test", "Fai la simulazione"), systemImage: "checklist") { simulacroDe = p.id }
                    }
                    Button(L("Retar a un amigo", "Challenge a Friend", "Sfida un amico"), systemImage: "person.2.wave.2") { opcionesReto = true }
                    Button(L("Fotos de los temas", "Topic photos", "Foto degli argomenti"), systemImage: "camera") {
                        temaAbierto = (p.temas.first { $0.textoLeido.isEmpty } ?? p.temas.first).map { UUIDIdentificable(id: $0.id) }
                    }
                    Toggle(isOn: Binding(get: { p.privada }, set: { v in cambiar { $0.privada = v } })) {
                        Label(L("Solo para mí", "Just for me", "Solo per me"), systemImage: "lock")
                    }
                    Divider()
                    Button(L("Borrar", "Delete", "Elimina"), systemImage: "trash", role: .destructive) { borrando = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel(L("Más", "More", "Altro"))
            }
        }
        .sheet(isPresented: $editando) {
            NavigationStack { EditorPrueba(prueba: p) }
                .tenidaDelCielo(hoja: true)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .presentationDetents([.large])
                .presentationBackground { FondoHojaTenida() }
                .environment(\.pestanaVisible, false)
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
        .simulacro(de: $simulacroDe)
        .task {
            if ModoCapturas.activo && ModoCapturas.pantalla == "reto-opciones" {
                try? await Task.sleep(for: .seconds(1))
                opcionesReto = true
            }
        }
        .sheet(isPresented: $opcionesReto) {
            OpcionesReto(prueba: p) {
                Task { try? await Task.sleep(for: .milliseconds(400)); retando = true }
            }
        }
        .fullScreenCover(isPresented: $retando) {
            RetoVista(temas: p.temas, nombreTema: almacen.datos.asignatura(p.asignaturaID)?.nombre ?? p.tipo.nombre) { retando = false }
        }
        .confirmationDialog(L("¿Borrar esta prueba?", "Delete this test?", "Eliminare questa verifica?"), isPresented: $borrando,
                            titleVisibility: .visible) {
            Button(L("Borrar", "Delete", "Elimina"), role: .destructive) {
                cerrar()
                conMuelle { almacen.datos.pruebas.removeAll { $0.id == id } }
            }
        } message: {
            Text(L("Se borran sus temas, sus fotos y sus lunas. No se puede deshacer.",
                   "Its topics, photos and moons are deleted. This can't be undone.",
                   "Si eliminano argomenti, foto e lune. Non si può annullare."))
        }
    }

    private func cabecera(_ p: Prueba, asig: Asignatura?, faltan: Int, cal: Calendar) -> some View {
        let peor = p.temas.min { $0.luna(cal: cal) < $1.luna(cal: cal) }
        let frase: String
        let gesto: GestoLobo
        if !p.temas.isEmpty && p.temas.allSatisfy({ $0.luna(cal: cal) == .llena }) {
            frase = FrasesHoot.pruebaLista(asignatura: asig?.nombre ?? p.tipo.nombre, dia: Formato.diaEnFrase(p.fecha))
            gesto = .feliz
        } else if let peor, peor.luna(cal: cal) == .nueva {
            frase = L("\(peor.nombre) ni lo has mirado. Te lo digo con cariño.", "You haven't even looked at \(peor.nombre). Said with love.",
                      "\(peor.nombre) non l'hai neanche guardato. Te lo dico con affetto.")
            gesto = .preocupado
        } else {
            frase = FrasesHoot.repasoEnMarcha(tema: peor?.nombre ?? "")
            gesto = .normal
        }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                IconoAsignatura(asignatura: asig, lado: 26)
                Text((asig?.nombre ?? L("Prueba", "Test", "Verifica")).uppercased(with: localeActual))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.86))
            }
            Text(p.tipo.nombre)
                .font(.largeTitle.weight(.heavy))
                .fontDesign(.rounded)
                .foregroundStyle(.white)
                .accessibilityAddTraits(.isHeader)
            Text(cuando(p, faltan: faltan))
                .font(.title3.weight(.medium))
                .foregroundStyle(EstiloSecundario())
            HootDice(frase: frase, gesto: gesto, tamano: 104, loboALaDerecha: true, paraguasSiLlueve: false)
                .padding(.top, 10)
        }
    }

    private func cuando(_ p: Prueba, faltan: Int) -> String {
        let dia = Formato.diaRelativo(p.fecha)
        switch faltan {
        case ..<0: return L("\(dia) · ya pasó", "\(dia) · done", "\(dia) · già passata")
        case 0: return L("Hoy", "Today", "Oggi")
        case 1: return L("Mañana", "Tomorrow", "Domani")
        default: return L("\(dia) · faltan \(faltan) días", "\(dia) · \(faltan) days to go", "\(dia) · mancano \(faltan) giorni")
        }
    }

    private func tocaSimulacro(_ p: Prueba, plan: PlanRepaso) -> Bool {
        plan.sesiones(en: Reloj.ahora, cal: calendarioActual).contains { $0.simulacro && $0.pruebaID == p.id }
    }

    private func evaluar(_ p: Prueba, plan: PlanRepaso) {
        let cal = calendarioActual
        if tocaSimulacro(p, plan: plan) {
            simulacroDe = p.id
            return
        }
        let ids = Set(p.temas.map(\.id))
        if let s = plan.sesiones(en: Reloj.ahora, cal: cal).first(where: { !ids.isDisjoint(with: $0.temaIDs) }) {
            let conTexto = s.temaIDs.filter { id in almacen.datos.tema(id).map { !$0.textoLeido.isEmpty } ?? false }
            if !conTexto.isEmpty {
                repaso = PeticionRepaso(temaIDs: conTexto, mezclado: s.mezclada)
                return
            }
        }
        let orden = p.temas.filter { !$0.textoLeido.isEmpty }.sorted { $0.luna(cal: cal) < $1.luna(cal: cal) }
        if orden.isEmpty {

            temaAbierto = p.temas.first.map { UUIDIdentificable(id: $0.id) }
        } else {
            repaso = PeticionRepaso(temaIDs: orden.prefix(2).map(\.id), mezclado: false)
        }
    }

    private func cambiar(_ cambio: (inout Prueba) -> Void) {
        guard let i = almacen.datos.pruebas.firstIndex(where: { $0.id == id }) else { return }
        conMuelle { cambio(&almacen.datos.pruebas[i]) }
    }
}

struct UUIDIdentificable: Identifiable, Hashable {
    let id: UUID
}

struct FilaSesionRepaso: View {
    var sesion: SesionRepaso
    var datos: DatosEscolares
    var ahora: Date

    var body: some View {
        let cal = calendarioActual
        let temas = sesion.temaIDs.compactMap { datos.tema($0) }
        HStack(spacing: 12) {
            Circle()
                .fill(Color.ambar)
                .frame(width: sesion.ligera ? 8 : 12, height: sesion.ligera ? 8 : 12)
                .shadow(color: Color.ambar.opacity(0.6), radius: 5)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(calendarioActual.isDate(sesion.dia, inSameDayAs: ahora)
                     ? L("Hoy, \(Formato.hora(sesion.hora))", "Today, \(Formato.hora(sesion.hora))", "Oggi, \(Formato.hora(sesion.hora))")
                     : Formato.diaRelativo(sesion.dia, desde: ahora))
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(detalle(temas))
                    .font(.subheadline)
                    .foregroundStyle(EstiloSecundario())
            }
            Spacer(minLength: 4)
            FilaLunas(partes: temas.prefix(4).map { $0.luna(cal: cal).fraccion }, tamano: 16, hueco: 3)
        }
        .accessibilityElement(children: .combine)
    }

    private func detalle(_ temas: [Tema]) -> String {
        let nombres = temas.map(\.nombre)
        let lista = nombres.count <= 2 ? nombres.joined(separator: L(" y ", " and ", " e "))
                                       : L("\(nombres.count) temas", "\(nombres.count) topics", "\(nombres.count) argomenti")
        if sesion.ligera { return L("\(sesion.minutos) min · repaso ligero", "\(sesion.minutos) min · light review", "\(sesion.minutos) min · ripasso leggero") }
        if sesion.simulacro { return L("\(sesion.minutos) min · simulacro, la prueba entera", "\(sesion.minutos) min · mock test, the whole thing", "\(sesion.minutos) min · simulazione, la verifica intera") }
        if sesion.mezclada { return L("\(sesion.minutos) min · \(lista), mezclados", "\(sesion.minutos) min · \(lista), mixed", "\(sesion.minutos) min · \(lista), mescolati") }
        return "\(sesion.minutos) min · \(lista)"
    }
}

struct SorpresaChips: View {
    var prueba: Prueba
    @Environment(Almacen.self) private var almacen

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(prueba.temas) { t in
                Button { elegir(t.id) } label: { Text(t.nombre).frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.6))
                    .foregroundStyle(.white)
            }
            Button { elegir(prueba.id) } label: { Text(L("Ninguno, fue bien", "None, it went well", "Nessuno, è andata bene")).frame(maxWidth: .infinity) }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.6))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 6)
    }

    private func elegir(_ id: UUID) {
        guard let i = almacen.datos.pruebas.firstIndex(where: { $0.id == prueba.id }) else { return }
        conMuelle { almacen.datos.pruebas[i].sorpresaTemaID = id }
    }
}

struct TemaHoja: View {
    var temaID: UUID
    var alEvaluar: ([UUID]) -> Void

    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var material: ControlMaterial
    @State private var charlando = false
    @State private var escuchando = false

    @State private var borrando = false
    @State private var detente: PresentationDetent = .medium
    @Environment(\.dynamicTypeSize) private var letraHoja

    init(temaID: UUID, alEvaluar: @escaping ([UUID]) -> Void) {
        self.temaID = temaID
        self.alEvaluar = alEvaluar
        _material = State(initialValue: ControlMaterial(temaID: temaID))
    }

    private var leyendo: Bool { material.leyendo }

    var body: some View {
        let cal = calendarioActual
        NavigationStack {
            if let t = almacen.datos.tema(temaID) {
                Form {
                    Section {
                        HStack(spacing: 16) {
                            Luna(parte: t.luna(cal: cal).fraccion, tamano: 84)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t.nombre).font(.title2.weight(.bold)).fontDesign(.rounded).foregroundStyle(.white)
                                Text(EstadoLuna.texto(t, cal: cal)).font(.subheadline).foregroundStyle(EstiloSecundario())
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        acciones(t)
                            .listRowSeparator(.hidden)
                    }
                    SeccionMaterial(control: material)
                }
                .presentacionesMaterial(material)
                .contentMargins(.top, 4, for: .scrollContent)
                .listSectionSpacing(.compact)
                .tenidaDelCielo(hoja: true)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar() } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if !t.textoLeido.isEmpty {
                                let c = t.compartido(de: almacen.perfil.nombre, asignatura: almacen.datos.asignatura(asignaturaID)?.nombre)
                                ShareLink(item: c, preview: SharePreview(t.nombre, image: Image(systemName: "moonphase.first.quarter"))) {
                                    Label(L("Pasárselo a un compañero", "Send to a Classmate", "Passalo a un compagno"), systemImage: "square.and.arrow.up")
                                }
                            }
                            Button(role: .destructive) { borrando = true } label: {
                                Label(L("Borrar el tema", "Delete Topic", "Elimina l'argomento"), systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                        .accessibilityLabel(L("Más", "More", "Altro"))
                    }
                }
                .confirmationDialog(L("¿Borrar «\(t.nombre)»?", "Delete “\(t.nombre)”?", "Eliminare «\(t.nombre)»?"), isPresented: $borrando,
                                    titleVisibility: .visible) {
                    Button(L("Borrar el tema", "Delete Topic", "Elimina l'argomento"), role: .destructive) {
                        cerrar()
                        conMuelle { almacen.datos.borrarTema(temaID) }
                    }
                } message: {
                    Text(L("Se borran sus fotos y su luna. No se puede deshacer.", "Its photos and its moon are deleted. This can't be undone.",
                           "Si cancellano le sue foto e la sua luna. Non si può annullare."))
                }
                .safeAreaBar(edge: .bottom) {
                    Button {
                        alEvaluar([temaID])
                    } label: {
                        Text(L("Evalúame este tema", "Quiz me on this topic", "Interrogami su questo argomento")).frame(maxWidth: .infinity)
                    }
                    .botonAmbar()
                    .controlSize(.large)
                    .disabled(t.textoLeido.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || leyendo)
                    .padding(.horizontal, Diseno.margen)
                    .padding(.bottom, 8)
                }
                .navigationDestination(isPresented: $charlando) {
                    CharlaVista(charla: CharlaHoot(tema: t, asignatura: almacen.datos.asignatura(asignaturaID), curso: almacen.perfil.curso), enHoja: true)
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $detente)
        .presentationBackground { FondoHojaTenida() }
        .environment(\.pestanaVisible, false)
        .sheet(isPresented: $escuchando) { EscuchaloVista() }

        .onAppear { if letraHoja.isAccessibilitySize || (ModoCapturas.activo && ModoCapturas.pantalla == "tema-grande") { detente = .large } }
    }

    private var asignaturaID: UUID? {
        almacen.datos.prueba(deTema: temaID)?.asignaturaID ?? almacen.datos.temasDeAhora.first { $0.tema.id == temaID }?.asignaturaID
    }

    private func acciones(_ t: Tema) -> some View {
        let sinMaterial = t.textoLeido.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let disposicion = letraHoja.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return disposicion {
            Button {
                detente = .large
                charlando = true
            } label: {
                accion(L("Pregúntale a Hoot", "Ask Hoot", "Chiedi a Hoot"), "bubble.left.and.text.bubble.right.fill")
            }
            Button {
                ReproductorHoot.compartido.reproducir(temas: [temaID], almacen: almacen)
                escuchando = true
            } label: {
                accion(L("Escúchalo", "Listen", "Ascoltalo"), "headphones")
            }
        }
        .botonTenido()
        .disabled(sinMaterial || leyendo)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
    }

    private func accion(_ titulo: String, _ simbolo: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: simbolo).font(.title3.weight(.semibold))
            Text(titulo).font(.caption.weight(.semibold)).lineLimit(2).minimumScaleFactor(0.8).multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 56)
    }
}
