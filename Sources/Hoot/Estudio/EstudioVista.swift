import SwiftUI

struct EstudioVista: View {
    @Environment(Almacen.self) private var almacen
    @State private var abierta: PeticionAyuda?
    @State private var borrando: [UUID]?

    @State private var pruebaDemo = ModoCapturas.pruebaDemo()
    @State private var esquemaDemo = ModoCapturas.verEsquema

    var body: some View {
        NavigationStack {
            ScrollViewReader { desplazar in
                List {
                    ayuda
                    Color.clear.frame(height: 1).id("fin")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                .task {
                    guard ModoCapturas.activo, ModoCapturas.pantalla == "estudio-abajo" else { return }
                    try? await Task.sleep(for: .seconds(1.5))
                    desplazar.scrollTo("fin", anchor: .bottom)
                }
            }
            .modifier(Noche(activa: true))
            .navigationTitle(L("Estudio", "Study", "Studio"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BotonCuenta()
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .navigationDestination(for: EstudioGuardado.self) { e in
                ResultadoGuardado(estudio: e)
            }
            .fullScreenCover(item: $abierta) { p in
                if p.tipo == .explicar {

                    NavigationStack {
                        CharlaVista(charla: CharlaHoot(origen: .suelta, titulo: TipoAyuda.explicar.nombre,
                                                       asignatura: almacen.datos.asignatura(p.asignaturaID), curso: almacen.perfil.curso, trozos: []),
                                    alCerrar: { abierta = nil })
                    }
                } else {
                    AyudaFlujo(tipo: p.tipo, asignaturaID: p.asignaturaID)
                }
            }
            .confirmationDialog(L("¿Borrar lo guardado?", "Delete saved item?", "Eliminare il salvataggio?"),
                                isPresented: Binding(get: { borrando != nil }, set: { if !$0 { borrando = nil } }),
                                titleVisibility: .visible) {
                Button(L("Borrar", "Delete", "Elimina"), role: .destructive) {
                    let ids = borrando ?? []
                    conMuelle { almacen.estudios.removeAll { ids.contains($0.id) } }
                    borrando = nil
                }
            } message: {
                Text(L("No se puede deshacer.", "This can't be undone.", "Non si può annullare."))
            }
            .fullScreenCover(item: $pruebaDemo) { p in
                NavigationStack { VistaPrueba(prueba: p, alTerminar: { pruebaDemo = nil }) }
            }
            .fullScreenCover(isPresented: $esquemaDemo) {
                NavigationStack {
                    ResultadoEsquema(trabajo: nil, guardado: ModoCapturas.esquemaDemo, titulo: "La célula") { esquemaDemo = false }
                }
                .onAppear { ModoCapturas.guardarPDFDemo() }
            }
            .onAppear(perform: abrirPendiente)
            .onChange(of: almacen.pestana) { _, _ in abrirPendiente() }
        }
    }

    private func abrirPendiente() {
        guard almacen.pestana == .estudio, let p = almacen.ayudaPendiente else { return }
        almacen.ayudaPendiente = nil
        abierta = PeticionAyuda(tipo: p.tipo, asignaturaID: p.asignaturaID)
    }

    @ViewBuilder
    private var ayuda: some View {
        let disponible = DisponibilidadIA.actual
        let datos = almacen.datos
        let cal = calendarioActual

        let prueba = datos.pruebas.filter { (1...14).contains($0.diasQueFaltan(desde: Reloj.ahora, cal: cal)) }.min { $0.fecha < $1.fecha }
        TutorLobo(disponible: disponible, prueba: prueba, asignatura: datos.asignatura(prueba?.asignaturaID)) {
            abierta = PeticionAyuda(tipo: .evaluar, asignaturaID: prueba?.asignaturaID)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: Diseno.margen, bottom: 6, trailing: Diseno.margen))

        grupo(L("Un ejercicio", "An exercise", "Un esercizio"), simbolo: "pencil.and.list.clipboard", tipos: [.revisar, .explicar], disponible: disponible)
        grupo(L("Un tema", "A topic", "Un argomento"), simbolo: "book.pages", tipos: [.resumen, .esquema, .evaluar], disponible: disponible)
        TarjetaEstudiarConAmigo()

        let guardados = almacen.estudios.sorted { $0.fecha > $1.fecha }
        if !guardados.isEmpty {
            let grupos = Dictionary(grouping: guardados, by: { $0.asignaturaID })
                .sorted { ($0.value.first?.fecha ?? .distantPast) > ($1.value.first?.fecha ?? .distantPast) }
            ForEach(grupos, id: \.key) { id, lista in
                let asig = datos.asignatura(id)
                TituloCielo(titulo: L("Guardado · \(asig?.nombre ?? "Sin asignatura")", "Saved · \(asig?.nombre ?? "No subject")",
                                      "Salvati · \(asig?.nombre ?? "Senza materia")"),
                            simbolo: asig?.simbolo ?? "tray.full", enTarjeta: true)
                    .filaEnTarjeta(.arriba)
                ForEach(Array(lista.enumerated()), id: \.element.id) { i, e in
                    let sitio: SitioEnTarjeta = i == lista.count - 1 ? .abajo : .medio
                    NavigationLink(value: e) {
                        FilaEstudio(estudio: e, asignatura: asig)
                    }
                    .padding(.vertical, 4)
                    .filaEnTarjeta(sitio, raya: i > 0, abajo: sitio == .abajo ? 6 : 0)
                }
                .onDelete { indices in
                    borrando = indices.map { lista[$0].id }
                }
            }
            Color.clear.frame(height: 20)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private func grupo(_ titulo: String, simbolo: String, tipos: [TipoAyuda], disponible: DisponibilidadIA) -> some View {

        TarjetaCielo(titulo: titulo, simbolo: simbolo) {
            VStack(spacing: 0) {
                ForEach(Array(tipos.enumerated()), id: \.element) { i, tipo in
                    Button {
                        abierta = PeticionAyuda(tipo: tipo, asignaturaID: nil)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: tipo.simbolo)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 46, height: 46)
                                .background(Circle().fill(Color.acentoRelleno.opacity(0.6)))
                                .accessibilityHidden(true)

                            Text(tipo.nombre)
                                .font(.headline)
                                .foregroundStyle(Color.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(EstiloSecundario())
                                .accessibilityHidden(true)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(EstiloFilaCielo())
                    .padding(.horizontal, -6)
                    .disabled(disponible != .lista)
                    .opacity(disponible == .lista ? 1 : 0.45)
                    if i < tipos.count - 1 {
                        Rectangle().fill(.white.opacity(0.14)).frame(height: 0.5).padding(.leading, 60)
                    }
                }
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: Diseno.margen, bottom: 6, trailing: Diseno.margen))
    }
}

private struct TutorLobo: View {
    var disponible: DisponibilidadIA
    var prueba: Prueba?
    var asignatura: Asignatura?
    var alRepasar: () -> Void
    @Environment(Almacen.self) private var almacen
    @Environment(\.dynamicTypeSize) private var letra

    private var conParaguas: Bool {
        TiempoReal.compartido.escena(fijado: TiempoFijo(rawValue: almacen.ajustes.tiempoFondo) ?? .real).caeAlgo
    }

    var body: some View {

        let grande = letra.isAccessibilitySize
        let disposicion = grande ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        disposicion {
            LoboInteractivo(tamano: grande ? 72 : 112, gesto: disponible != .lista ? .dormido : (prueba == nil ? .feliz : .pensando),
                            mirada: CGPoint(x: 0.6, y: 0.1), paraguasSiLlueve: true)
                .frame(width: grande ? 76 : 118, height: grande ? 76 : 118)
            VStack(alignment: .leading, spacing: 6) {
                Text(titulo)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detalle)
                    .font(.subheadline)
                    .textoSecundario()
                    .fixedSize(horizontal: false, vertical: true)
                if let prueba, disponible == .lista {
                    FilaLunas(partes: prueba.temas.prefix(6).map { $0.luna(cal: calendarioActual).fraccion }, tamano: 16, hueco: 3)
                }
                if disponible == .lista, prueba != nil {
                    Button(action: alRepasar) {
                        Label(L("Que me pregunte", "Quiz me", "Interrogami"), systemImage: "questionmark.bubble")
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: grande ? .infinity : nil, alignment: .leading)
                    }
                        .fixedSize(horizontal: false, vertical: true)
                        .buttonStyle(.glassProminent)
                        .tint(Color.acentoRelleno)
                        .controlSize(grande ? .regular : .small)
                        .chocable(.capsula, reacciona: true)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }

        .padding(.horizontal, Diseno.margenTarjeta)
        .padding(.vertical, 10)
        .fondoModulo()
        .padding(.top, conParaguas ? 34 : 0)
    }

    private var titulo: String {
        if disponible != .lista { return L("Ahora no puedo ayudarte", "I can't help right now", "Ora non posso aiutarti") }
        guard let prueba else { return L("Cuando quieras", "Whenever you want", "Quando vuoi") }
        let nombre = asignatura?.nombre ?? prueba.tipo.nombre
        return L("\(nombre) \(Formato.diaEnFrase(prueba.fecha))", "\(nombre) \(Formato.diaEnFrase(prueba.fecha))",
                 "\(nombre) \(Formato.diaEnFrase(prueba.fecha))")
    }

    private var detalle: String {
        if disponible != .lista { return disponible.mensaje }
        guard let prueba else { return L("Repasamos un tema, explico un ejercicio o hago un esquema.", "We can review a topic, explain an exercise or make an outline.",
                                         "Ripassiamo un argomento, ti spiego un esercizio o faccio uno schema.") }
        let llenos = prueba.llenos(cal: calendarioActual)
        return L("\(llenos) de \(prueba.temas.count) temas en luna llena", "\(llenos) of \(prueba.temas.count) topics at full moon",
                 "\(llenos) di \(prueba.temas.count) argomenti in luna piena")
    }
}

private struct Noche: ViewModifier {
    var activa: Bool

    func body(content: Content) -> some View {
        if activa {
            content
                .environment(\.colorScheme, .dark)
                .environment(\.sobreCielo, true)

                .environment(\.cieloSinVelo, true)
                .background {
                    FondoTiempo(sinVelo: true)
                }
        } else {
            content
        }
    }
}

struct PeticionAyuda: Identifiable {
    let id = UUID()
    var tipo: TipoAyuda
    var asignaturaID: UUID?
}

struct FilaEstudio: View {
    var estudio: EstudioGuardado
    var asignatura: Asignatura?

    var body: some View {
        HStack(spacing: 12) {
            if let dato = estudio.miniaturas.first, let img = UIImage(data: dato) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: Diseno.radioTramo, style: .continuous))
                    .accessibilityHidden(true)
            } else {
                Image(systemName: estudio.tipo.simbolo)
                    .foregroundStyle(estudio.tipo.color.sobre)
                    .frame(width: 44, height: 44)
                    .background(estudio.tipo.color.color.gradient, in: RoundedRectangle(cornerRadius: Diseno.radioTramo, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(estudio.titulo)
                    .lineLimit(1)
                Text([estudio.tipo.nombreCorto, asignatura?.nombre, Formato.diaRelativo(estudio.fecha)].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .textoSecundario()
                    .lineLimit(1)
            }
        }
    }
}

struct ResultadoGuardado: View {
    var estudio: EstudioGuardado
    @State private var verTexto = false

    var body: some View {
        if estudio.tipo == .esquema, let e = estudio.esquema {
            ResultadoEsquema(trabajo: nil, guardado: e, titulo: estudio.titulo)
        } else if estudio.tipo == .evaluar, let p = estudio.prueba {
            PruebaGuardadaVista(estudio: estudio, guardada: p)
        } else {
            texto
        }
    }

    private var texto: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !estudio.miniaturas.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(estudio.miniaturas.enumerated()), id: \.offset) { _, d in
                                if let img = UIImage(data: d) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 96)
                                        .clipShape(RoundedRectangle(cornerRadius: Diseno.radioBloque, style: .continuous))
                                }
                            }
                        }
                    }
                    .accessibilityHidden(true)
                }
                TextoMarkdown(texto: estudio.resultado, color: estudio.tipo.color.color, esquema: estudio.tipo == .esquema)
                if !estudio.textoLeido.isEmpty {
                    DisclosureGroup(L("Texto leído de las fotos", "Text read from the photos", "Testo letto dalle foto"), isExpanded: $verTexto) {
                        Text(estudio.textoLeido)
                            .font(.footnote)
                            .textoSecundario()
                            .textSelection(.enabled)
                            .padding(.top, 6)
                    }
                    .padding(.top, 20)
                }
            }
            .padding(Diseno.margen)
        }
        .navigationTitle(estudio.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: estudio.resultado, subject: Text(estudio.titulo))
            }
        }
    }
}
