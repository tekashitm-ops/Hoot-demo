import SwiftUI
import PhotosUI

struct AyudaFlujo: View {
    var tipo: TipoAyuda
    var asignaturaID: UUID?

    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var imagenes: [UIImage] = []
    @State private var saliendo = false
    @State private var seleccionFotos: [PhotosPickerItem] = []
    @State private var eligiendoFotos = false
    @State private var escaneando = false
    @State private var fotografiando = false
    @State private var cargandoFotos = false
    @State private var ejercicio = ""
    @State private var tema = ""
    @State private var textoEscrito = ""
    @State private var modo: ModoRevision = .comprobar
    @State private var longitud: Longitud = .normal
    @State private var asignatura: UUID?

    @State private var ruta = NavigationPath()
    @State private var preparado = false
    @State private var miniaturasPrueba: [Data] = []
    @State private var modoPrueba: ModoPrueba = .oral
    @ScaledMetric(relativeTo: .subheadline) private var altoBaldosa: CGFloat = 76
    @Environment(\.dynamicTypeSize) private var letra

    private var puedeEmpezar: Bool {
        let hayMaterial = !imagenes.isEmpty || textoEscrito.trimmingCharacters(in: .whitespacesAndNewlines).count > 20
        if tipo == .revisar { return hayMaterial && !ejercicio.trimmingCharacters(in: .whitespaces).isEmpty }
        return hayMaterial
    }

    var body: some View {
        NavigationStack(path: $ruta) {

            Form {
                seccionFotos

                if tipo == .revisar {
                    Section {
                        TextField(text: $ejercicio, prompt: Indicacion.texto(L("Por ejemplo: ejercicio 3 de la página 45", "For example: exercise 3 on page 45", "Per esempio: esercizio 3 a pagina 45")), axis: .vertical) {
                            Text(L("Qué ejercicio", "Which exercise", "Quale esercizio"))
                        }
                        Picker(L("Qué quieres", "What you want", "Cosa vuoi"), selection: $modo) {
                            ForEach(ModoRevision.allCases) { Text($0.nombre).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        cabeceraSeccion(L("Qué ejercicio", "Which exercise", "Quale esercizio"))
                    } footer: {
                        pie(modo == .comprobar
                            ? L("Te dice si está bien y te da una pista, sin la solución.", "Tells you if it's right and gives you a hint, without the solution.", "Ti dice se va bene e ti dà un suggerimento, senza la soluzione.")
                            : L("Te enseña los errores y la solución paso a paso.", "Shows you the mistakes and the step-by-step solution.", "Ti mostra gli errori e la soluzione passo per passo."))
                    }
                    .filaTenida()
                } else if tipo == .evaluar {
                    Section {
                        TextField(text: $tema, prompt: Indicacion.texto(L("Tema (opcional)", "Topic (optional)", "Argomento (facoltativo)"))) {
                            Text(L("Tema", "Topic", "Argomento"))
                        }
                        Picker(L("Cómo te pregunta", "How it asks", "Come ti interroga"), selection: $modoPrueba) {
                            ForEach(ModoPrueba.allCases) { m in Text(m.nombre).tag(m) }
                        }
                        .pickerStyle(.segmented)
                    } footer: {
                        pie(modoPrueba.explicacion)
                    }
                    .filaTenida()
                } else if tipo == .explicar {
                    Section {
                        TextField(text: $tema, prompt: Indicacion.texto(L("Qué no entiendes (opcional)", "What you don't get (optional)", "Cosa non capisci (facoltativo)")), axis: .vertical) {
                            Text(L("Qué no entiendes", "What you don't get", "Cosa non capisci"))
                        }
                    } footer: {
                        pie(L("Si es un ejercicio, te explica cómo se hace con otro parecido.", "If it's an exercise, it shows you how with a similar one.", "Se è un esercizio, ti spiega come si fa con uno simile."))
                    }
                    .filaTenida()
                } else {
                    Section {
                        TextField(text: $tema, prompt: Indicacion.texto(L("Tema (opcional)", "Topic (optional)", "Argomento (facoltativo)"))) {
                            Text(L("Tema", "Topic", "Argomento"))
                        }
                        if tipo == .resumen {
                            Picker(L("Largo", "Length", "Lunghezza"), selection: $longitud) {
                                ForEach(Longitud.allCases) { Text($0.nombre).tag($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .filaTenida()
                }

                Section {
                    Picker(L("Asignatura", "Subject", "Materia"), selection: $asignatura) {
                        Text(L("Ninguna", "None", "Nessuna")).tag(UUID?.none)
                        ForEach(almacen.datos.asignaturas) { a in
                            Label(a.nombre, systemImage: a.simbolo).tag(UUID?.some(a.id))
                        }
                    }
                }
                .filaTenida()

                Section {
                    TextField(text: $textoEscrito, prompt: Indicacion.texto(L("O pega aquí el texto", "Or paste the text here", "Oppure incolla qui il testo")), axis: .vertical) {
                        Text(L("Texto", "Text", "Testo"))
                    }
                    .lineLimit(3...10)
                }
                .filaTenida()
            }
            .tenidaDelCielo()
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle(tipo.nombre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {

                    BotonCerrar {
                        if imagenes.isEmpty && textoEscrito.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { cerrar() } else { saliendo = true }
                    }
                }
            }
            .confirmationDialog(L("¿Salir sin usarlo?", "Leave without using it?", "Uscire senza usarlo?"), isPresented: $saliendo, titleVisibility: .visible) {
                Button(L("Salir", "Leave", "Esci"), role: .destructive) { cerrar() }
            } message: {
                Text(imagenes.isEmpty
                     ? L("Se pierde el texto que has puesto.", "The text you added is lost.", "Si perde il testo che hai messo.")
                     : L("Se pierden las fotos que has hecho.", "The photos you took are lost.", "Si perdono le foto che hai fatto."))
            }
            .safeAreaBar(edge: .bottom) {

                Button(action: empezar) {
                    Label(textoBoton, systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(tono.fondo.color)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .tint(tono.boton.color)
                .disabled(!puedeEmpezar)
                .padding(.horizontal, Diseno.margen)
                .padding(.bottom, 8)
            }
            .navigationDestination(for: TrabajoIA.self) { trabajo in
                ResultadoIA(trabajo: trabajo, tipo: tipo, color: tipo.color) {
                    cerrar()
                }
            }
            .navigationDestination(for: EsquemaIA.self) { trabajo in
                ResultadoEsquema(trabajo: trabajo, guardado: nil, titulo: tipo.nombreCorto) { cerrar() }
            }
            .navigationDestination(for: PruebaIA.self) { prueba in
                VistaPrueba(prueba: prueba, alTerminar: { cerrar() }, alAcabar: guardarPrueba)
            }
            .photosPicker(isPresented: $eligiendoFotos, selection: $seleccionFotos, maxSelectionCount: 10, matching: .images)
            .onChange(of: seleccionFotos) { _, items in cargar(items) }
            .fullScreenCover(isPresented: $escaneando) {
                EscanerDocumentos { paginas in
                    escaneando = false
                    conMuelle { imagenes += paginas.map { $0.reducida(a: 2400) } }
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $fotografiando) {
                CamaraFoto { foto in
                    fotografiando = false
                    if let foto { conMuelle { imagenes.append(foto.reducida(a: 2400)) } }
                }
                .ignoresSafeArea()
            }
            .onAppear {
                guard !preparado else { return }
                preparado = true
                asignatura = asignaturaID
                modo = almacen.ajustes.modoRevision
                longitud = almacen.ajustes.longitudResumen
                modoPrueba = almacen.ajustes.modoPrueba
                if ModoCapturas.rellenar {
                    ejercicio = L("Ejercicio 3 de la página 45", "Exercise 3 on page 45", "Esercizio 3 a pagina 45")
                    textoEscrito = L("La célula es la unidad más pequeña de los seres vivos. Todas tienen membrana, citoplasma y material genético.", "The cell is the smallest unit of living things. All cells have a membrane, cytoplasm and genetic material.", "La cellula è l'unità più piccola dei viventi. Tutte hanno membrana, citoplasma e materiale genetico.")
                }
            }
        }
    }

    private var tono: TonoCielo { TonoCielo.actual(almacen) }

    private func cabeceraSeccion(_ texto: String) -> some View {
        Text(texto).foregroundStyle(EstiloSecundario())
    }

    private func pie(_ texto: String) -> some View {
        Text(texto).foregroundStyle(EstiloSecundario())
    }

    @ViewBuilder
    private var seccionFotos: some View {

        let baldosas = !letra.isAccessibilitySize
        let tituloFotos = L("Elegir fotos", "Choose Photos", "Scegli foto")
        Section {
            if !imagenes.isEmpty {
                miniaturas
                    .modifier(FondoFilaFotos(transparente: baldosas))
            }
            if baldosas {
                HStack(spacing: 10) {
                    Button { eligiendoFotos = true } label: { baldosa(L("Fotos", "Photos", "Foto"), "photo.on.rectangle") }
                        .accessibilityLabel(tituloFotos)
                    if EscanerDocumentos.disponible || ModoCapturas.activo {
                        Button { escaneando = true } label: { baldosa(L("Escanear", "Scan", "Scansiona"), "doc.viewfinder") }
                            .accessibilityLabel(L("Escanear páginas", "Scan Pages", "Scansiona pagine"))
                    }
                    if CamaraFoto.disponible || ModoCapturas.activo {
                        Button { fotografiando = true } label: { baldosa(L("Cámara", "Camera", "Fotocamera"), "camera") }
                            .accessibilityLabel(L("Hacer una foto", "Take a Photo", "Scatta una foto"))
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: Diseno.radioModulo))

                .tint(.white.opacity(0.6))
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } else {
                Button { eligiendoFotos = true } label: {
                    Label(tituloFotos, systemImage: "photo.on.rectangle")
                }
                .filaTenida()
                if EscanerDocumentos.disponible || ModoCapturas.activo {
                    Button { escaneando = true } label: {
                        Label(L("Escanear páginas", "Scan Pages", "Scansiona pagine"), systemImage: "doc.viewfinder")
                    }
                    .filaTenida()
                }
                if CamaraFoto.disponible || ModoCapturas.activo {
                    Button { fotografiando = true } label: {
                        Label(L("Hacer una foto", "Take a Photo", "Scatta una foto"), systemImage: "camera")
                    }
                    .filaTenida()
                }
            }
            if cargandoFotos {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .modifier(FondoFilaFotos(transparente: baldosas))
            }
        } header: {
            cabeceraSeccion(imagenes.isEmpty ? L("Fotos", "Photos", "Foto") : L("Fotos · \(imagenes.count)", "Photos · \(imagenes.count)", "Foto · \(imagenes.count)"))
        } footer: {
            if tipo == .revisar {
                pie(L("Que se vean el enunciado y tu respuesta.", "Make sure the question and your answer are visible.", "Si devono vedere la consegna e la tua risposta."))
            }
        }
    }

    private func baldosa(_ titulo: String, _ simbolo: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: simbolo)
                .font(.title2.weight(.semibold))
            Text(titulo)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: altoBaldosa)
    }

    private var miniaturas: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(imagenes.enumerated()), id: \.offset) { i, img in
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 84, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                conMuelle { if imagenes.indices.contains(i) { imagenes.remove(at: i) } }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .black.opacity(0.55))
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.borderless)
                            .offset(x: 12, y: -12)
                            .accessibilityLabel(L("Quitar la foto \(i + 1)", "Remove photo \(i + 1)", "Togli la foto \(i + 1)"))
                        }
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 12)
            .padding(.trailing, 12)
        }
    }

    private var textoBoton: String {
        switch tipo {
        case .revisar: modo == .comprobar ? L("Comprobar", "Check", "Verifica") : L("Corregir", "Correct", "Correggi")
        case .explicar: L("Explícamelo", "Explain it", "Spiegamelo")
        case .resumen: L("Resumir", "Summarize", "Riassumi")
        case .esquema: L("Hacer el esquema", "Make the outline", "Fai lo schema")
        case .evaluar: L("Empezar la prueba", "Start the quiz", "Inizia la verifica")
        }
    }

    private func guardarPrueba(_ p: PruebaIA) {
        let a = almacen.datos.asignatura(asignatura)
        let tm = p.tema.trimmingCharacters(in: .whitespaces)
        let titulo = tm.isEmpty ? [TipoAyuda.evaluar.nombreCorto, a?.nombre].compactMap { $0 }.joined(separator: " · ") : tm
        let guardada = p.guardada
        let nota = guardada.nota.map { Formato.numero(almacen.ajustes.escala.desdeDiez($0)) } ?? ""
        let resumen = p.preguntas.map { "- \($0.veredicto?.fallada == true ? "✗" : "✓") \($0.pregunta)" }.joined(separator: "\n")
        almacen.estudios.insert(EstudioGuardado(tipo: .evaluar, titulo: titulo, asignaturaID: asignatura, fecha: Reloj.ahora,
                                                resultado: L("## Nota: \(nota)\n\(resumen)", "## Grade: \(nota)\n\(resumen)", "## Voto: \(nota)\n\(resumen)"),
                                                textoLeido: p.material, miniaturas: miniaturasPrueba, prueba: guardada), at: 0)
        if almacen.estudios.count > 150 { almacen.estudios.removeLast(almacen.estudios.count - 150) }
    }

    private func cargar(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        cargandoFotos = true
        Task {
            var nuevas: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    nuevas.append(img.reducida(a: 2400))
                }
            }
            conMuelle { imagenes += nuevas }
            seleccionFotos = []
            cargandoFotos = false
        }
    }

    private func empezar() {
        let a = almacen.datos.asignatura(asignatura)
        let miniaturas = imagenes.prefix(6).compactMap { $0.reducida(a: 320).jpegData(compressionQuality: 0.7) }
        let asignaturaID = asignatura
        let tm = tema.trimmingCharacters(in: .whitespaces)
        let tituloTema = tm.isEmpty ? [tipo.nombreCorto, a?.nombre].compactMap { $0 }.joined(separator: " · ") : tm
        switch tipo {
        case .esquema:
            let e = EsquemaIA()
            e.empezar(imagenes: imagenes, escrito: textoEscrito, tema: tema, asignatura: a?.nombre, curso: almacen.perfil.curso) { [almacen] hecho in
                guard let datos = hecho.esquema else { return }
                let titulo = tm.isEmpty ? (datos.titulo.isEmpty ? tituloTema : datos.titulo) : tm
                almacen.estudios.insert(EstudioGuardado(tipo: .esquema, titulo: titulo, asignaturaID: asignaturaID, fecha: Reloj.ahora,
                                                        resultado: datos.texto, textoLeido: hecho.textoLeido, miniaturas: Array(miniaturas), esquema: datos), at: 0)
                if almacen.estudios.count > 150 { almacen.estudios.removeLast(almacen.estudios.count - 150) }
            }
            ruta.append(e)
            return
        case .evaluar:
            let p = PruebaIA()
            p.asignatura = a?.nombre
            p.curso = almacen.perfil.curso
            p.tema = tema
            p.modo = modoPrueba
            almacen.ajustes.modoPrueba = modoPrueba
            p.empezar(imagenes: imagenes, escrito: textoEscrito)
            miniaturasPrueba = Array(miniaturas)
            ruta.append(p)
            return
        default:
            break
        }
        let t = TrabajoIA()
        let peticion = TrabajoIA.Peticion(
            tipo: tipo, imagenes: imagenes, textoEscrito: textoEscrito, ejercicio: ejercicio, tema: tema,
            modo: modo, longitud: longitud, asignatura: a?.nombre, curso: almacen.perfil.curso
        )
        let titulo = tipo == .revisar ? ejercicio.trimmingCharacters(in: .whitespaces) : tituloTema
        t.empezar(peticion) { [almacen] hecho in
            let guardado = EstudioGuardado(tipo: tipo, titulo: titulo, asignaturaID: asignaturaID, fecha: Reloj.ahora,
                                           resultado: hecho.resultado, textoLeido: hecho.textoLeido, miniaturas: Array(miniaturas))
            almacen.estudios.insert(guardado, at: 0)
            if almacen.estudios.count > 150 { almacen.estudios.removeLast(almacen.estudios.count - 150) }
        }
        ruta.append(t)
    }
}

struct ResultadoIA: View {
    @Bindable var trabajo: TrabajoIA
    var tipo: TipoAyuda
    var color: ColorHoot
    var alTerminar: () -> Void

    @Environment(\.dismiss) private var volver

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if trabajo.resultado.isEmpty {
                    VStack(spacing: 18) {
                        Group {
                            if trabajo.fallido { Lobo(tamano: 120, gesto: .sorprendido) } else { LoboTrabajando(tamano: 120, gesto: tipo == .resumen ? .escribiendo : .pensando) }
                        }
                        .padding(.top, 60)
                        Text(estado)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .contentTransition(.opacity)
                            .animation(Diseno.muelle, value: estado)
                        if !trabajo.fallido {
                            ProgressView()
                        } else {
                            Button(L("Volver", "Go back", "Indietro")) { volver() }
                                .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    TextoMarkdown(texto: trabajo.resultado, color: color.color, esquema: tipo == .esquema)
                        .animando(Diseno.muelle, valor: trabajo.resultado.count / 40)
                    if trabajo.terminado {

                        Label {
                            Text(L("Guardado en Estudio", "Saved in Study", "Salvato in Studio"))
                        } icon: {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.hecho)
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.top, 24)
                        .transition(.opacity)
                    }
                    if case .error(let m) = trabajo.fase {
                        Label(m, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(EstiloUrgente())
                            .padding(.top, 20)
                    }
                }
            }
            .padding(Diseno.margen)
        }

        .tenidaDelCielo()
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle(tipo.nombreCorto)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(!trabajo.terminado && !trabajo.fallido)
        .toolbar {
            if trabajo.terminado {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: trabajo.resultado)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm, action: alTerminar)
                }
            } else if !trabajo.fallido {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Parar", "Stop", "Ferma")) {
                        trabajo.cancelar()
                        volver()
                    }
                }
            }
        }
        .sensoryFeedback(.success, trigger: trabajo.terminado) { _, t in t }
        .sensoryFeedback(.error, trigger: trabajo.fallido) { _, f in f }
    }

    private var estado: String {
        switch trabajo.fase {
        case .leyendo(let i, let n):
            n > 1 ? L("Leyendo la foto \(i) de \(n)", "Reading photo \(i) of \(n)", "Sto leggendo la foto \(i) di \(n)")
                  : L("Leyendo la foto", "Reading the photo", "Sto leggendo la foto")
        case .pensando:
            L("Pensando", "Thinking", "Sto pensando")
        case .escribiendo, .listo:
            ""
        case .error(let m):
            m
        }
    }
}

private struct FondoFilaFotos: ViewModifier {
    var transparente: Bool

    func body(content: Content) -> some View {
        if transparente {
            content.listRowBackground(Color.clear)
        } else {
            content.filaTenida()
        }
    }
}
