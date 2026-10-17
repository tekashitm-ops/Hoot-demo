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
        }
        .tenidaDelCielo()
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaBar(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    temaAbierto = (p.temas.first { $0.textoLeido.isEmpty } ?? p.temas.first).map { UUIDIdentificable(id: $0.id) }
                } label: {
                    Label(L("Fotos", "Photos", "Foto"), systemImage: "camera.fill")
                }
                .buttonStyle(.glass)
                .controlSize(.large)
                Button {
                    evaluar(p, plan: plan)
                } label: {
                    Text(L("Evalúame", "Quiz me", "Interrogami")).frame(maxWidth: .infinity)
                }
                .botonAmbar()
                .controlSize(.large)
                .disabled(p.temas.isEmpty)
            }
            .padding(.horizontal, Diseno.margen)
            .padding(.bottom, 8)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(L("Editar", "Edit", "Modifica"), systemImage: "pencil") { editando = true }
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
        if p.temas.allSatisfy({ $0.luna(cal: cal) == .llena }) {
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

    private func evaluar(_ p: Prueba, plan: PlanRepaso) {
        let cal = calendarioActual
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
        if sesion.mezclada { return L("\(sesion.minutos) min · \(lista), mezclados", "\(sesion.minutos) min · \(lista), mixed", "\(sesion.minutos) min · \(lista), mescolati") }
        return "\(sesion.minutos) min · \(lista)"
    }
}

struct SorpresaChips: View {
    var prueba: Prueba
    @Environment(Almacen.self) private var almacen

    var body: some View {
        Fluido(hueco: 8) {
            ForEach(prueba.temas) { t in
                Button(t.nombre) { elegir(t.id) }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.6))
                    .foregroundStyle(.white)
            }
            Button(L("Ninguno", "None", "Nessuno")) { elegir(prueba.id) }
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
    @State private var eligiendo = false
    @State private var seleccion: [PhotosPickerItem] = []
    @State private var escaneando = false
    @State private var fotografiando = false
    @State private var leyendo = false

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
                    }
                    Section {
                        if !t.miniaturas.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(Array(t.miniaturas.enumerated()), id: \.offset) { _, datos in
                                        if let img = UIImage(data: datos) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 72, height: 96)
                                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                    }
                                }
                            }
                            .listRowBackground(Color.clear)
                        }
                        if leyendo {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text(L("Leyendo las fotos…", "Reading the photos…", "Sto leggendo le foto…")).foregroundStyle(EstiloSecundario())
                            }
                        }
                        Button { eligiendo = true } label: { Label(L("Elegir fotos", "Choose Photos", "Scegli foto"), systemImage: "photo.on.rectangle") }
                        if EscanerDocumentos.disponible {
                            Button { escaneando = true } label: { Label(L("Escanear páginas", "Scan Pages", "Scansiona pagine"), systemImage: "doc.viewfinder") }
                        }
                        if CamaraFoto.disponible {
                            Button { fotografiando = true } label: { Label(L("Hacer una foto", "Take a Photo", "Scatta una foto"), systemImage: "camera") }
                        }
                    } header: {
                        Text(L("Fotos del libro o los apuntes", "Photos of the book or notes", "Foto del libro o degli appunti")).foregroundStyle(EstiloSecundario())
                    } footer: {
                        Text(L("Las preguntas de Hoot salen de aquí.", "Hoot's questions come from here.", "Le domande di Hoot escono da qui."))
                            .foregroundStyle(EstiloSecundario())
                    }
                    .filaTenida()
                }
                .tenidaDelCielo(hoja: true)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .navigationTitle(L("Tema", "Topic", "Argomento"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar() } }
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
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground { FondoHojaTenida() }
        .environment(\.pestanaVisible, false)
        .photosPicker(isPresented: $eligiendo, selection: $seleccion, maxSelectionCount: 8, matching: .images)
        .onChange(of: seleccion) { _, items in cargar(items) }
        .fullScreenCover(isPresented: $escaneando) {
            EscanerDocumentos { paginas in
                escaneando = false
                anadir(paginas)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $fotografiando) {
            CamaraFoto { foto in
                fotografiando = false
                if let foto { anadir([foto]) }
            }
            .ignoresSafeArea()
        }
    }

    private func cargar(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var imagenes: [UIImage] = []
            for item in items {
                if let datos = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: datos) { imagenes.append(img) }
            }
            seleccion = []
            anadir(imagenes)
        }
    }

    private func anadir(_ imagenes: [UIImage]) {
        guard !imagenes.isEmpty else { return }
        leyendo = true
        Task {
            let reducidas = imagenes.map { $0.reducida(a: 2400) }
            let texto = (try? await TrabajoIA.leer(reducidas, escrito: "") { _, _ in }) ?? ""
            let miniaturas = reducidas.compactMap { $0.reducida(a: 360).jpegData(compressionQuality: 0.6) }
            conMuelle {
                leyendo = false
                cambiarTema { t in
                    t.miniaturas += miniaturas

                    t.textoLeido = String(([t.textoLeido, texto].filter { !$0.isEmpty }.joined(separator: "\n\n")).prefix(TrabajoIA.caracteresMaximos * 2))
                }
            }
        }
    }

    private func cambiarTema(_ cambio: (inout Tema) -> Void) {
        for i in almacen.datos.pruebas.indices {
            if let j = almacen.datos.pruebas[i].temas.firstIndex(where: { $0.id == temaID }) {
                cambio(&almacen.datos.pruebas[i].temas[j])
                return
            }
        }
        if let i = almacen.datos.temasDeAhora.firstIndex(where: { $0.tema.id == temaID }) {
            cambio(&almacen.datos.temasDeAhora[i].tema)
        }
    }
}
