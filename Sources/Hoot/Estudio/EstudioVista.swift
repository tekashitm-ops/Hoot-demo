import SwiftUI

struct EstudioVista: View {
    @Environment(Almacen.self) private var almacen
    @State private var abierta: PeticionAyuda?
    @State private var borrando: [UUID]?

    @State private var pruebaDemo = ModoCapturas.pruebaDemo()
    @State private var esquemaDemo = ModoCapturas.verEsquema

    var body: some View {
        NavigationStack {
            List {
                ayuda
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
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
                AyudaFlujo(tipo: p.tipo, asignaturaID: p.asignaturaID)
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
        let examen = datos.proximoExamen().flatMap { ex -> Tarea? in
            let dias = calendarioActual.dateComponents([.day], from: calendarioActual.startOfDay(for: Reloj.ahora),
                                                        to: calendarioActual.startOfDay(for: ex.entrega)).day ?? 99
            return dias <= 14 ? ex : nil
        }
        TutorLobo(disponible: disponible, examen: examen, asignatura: datos.asignatura(examen?.asignaturaID)) {
            abierta = PeticionAyuda(tipo: .evaluar, asignaturaID: examen?.asignaturaID)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)

        grupo(L("Un ejercicio", "An exercise", "Un esercizio"), simbolo: "pencil.and.list.clipboard", tipos: [.revisar, .explicar], disponible: disponible)
        grupo(L("Un tema", "A topic", "Un argomento"), simbolo: "book.pages", tipos: [.resumen, .esquema, .evaluar], disponible: disponible)

        let guardados = almacen.estudios.sorted { $0.fecha > $1.fecha }
        if !guardados.isEmpty {
            TituloCielo(titulo: L("Guardado", "Saved", "Salvati"), simbolo: "tray.full")
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            let grupos = Dictionary(grouping: guardados, by: { $0.asignaturaID })
                .sorted { ($0.value.first?.fecha ?? .distantPast) > ($1.value.first?.fecha ?? .distantPast) }
            ForEach(grupos, id: \.key) { id, lista in
                let asig = datos.asignatura(id)
                Label(asig?.nombre ?? L("Sin asignatura", "No subject", "Senza materia"), systemImage: asig?.simbolo ?? "tray")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(asig?.color.color ?? Color.texto2)
                    .padding(.top, 6)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .accessibilityAddTraits(.isHeader)
                ForEach(lista) { e in
                    NavigationLink(value: e) {
                        FilaEstudio(estudio: e, asignatura: asig)
                    }
                    .listRowBackground(Color.clear)
                }
                .onDelete { indices in
                    borrando = indices.map { lista[$0].id }
                }
            }
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
    var examen: Tarea?
    var asignatura: Asignatura?
    var alRepasar: () -> Void
    @Environment(Almacen.self) private var almacen

    private var conParaguas: Bool {
        TiempoReal.compartido.escena(fijado: TiempoFijo(rawValue: almacen.ajustes.tiempoFondo) ?? .real).caeAlgo
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            LoboInteractivo(tamano: 112, gesto: disponible != .lista ? .dormido : (examen == nil ? .feliz : .pensando),
                            mirada: CGPoint(x: 0.6, y: 0.1), paraguasSiLlueve: true)
                .frame(width: 118, height: 118)
            VStack(alignment: .leading, spacing: 6) {
                Text(titulo)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detalle)
                    .font(.subheadline)
                    .textoSecundario()
                    .fixedSize(horizontal: false, vertical: true)
                if disponible == .lista, examen != nil {
                    Button(L("Que me pregunte", "Quiz me", "Interrogami"), systemImage: "questionmark.bubble", action: alRepasar)
                        .buttonStyle(.glassProminent)
                        .tint(Color.acentoRelleno)
                        .controlSize(.small)
                        .chocable(.capsula, reacciona: true)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.top, conParaguas ? 40 : 6)
        .padding(.bottom, 4)
    }

    private var titulo: String {
        if disponible != .lista { return L("Ahora no puedo ayudarte", "I can't help right now", "Ora non posso aiutarti") }
        guard let examen else { return L("Todo al día", "All caught up", "Tutto in pari") }
        let nombre = asignatura?.nombre ?? examen.titulo
        let dias = calendarioActual.dateComponents([.day], from: calendarioActual.startOfDay(for: Reloj.ahora),
                                                    to: calendarioActual.startOfDay(for: examen.entrega)).day ?? 0
        let cuando = Formato.diaRelativo(examen.entrega).lowercased(with: localeActual)

        let conArticulo = (2...6).contains(dias) ? L("el \(cuando)", "on \(cuando)", cuando) : cuando
        return L("Examen de \(nombre) \(conArticulo)", "\(nombre) test \(conArticulo)", "Verifica di \(nombre) \(conArticulo)")
    }

    private var detalle: String {
        if disponible != .lista { return disponible.mensaje }
        guard let examen else { return L("Cuando quieras, repasamos un tema.", "Whenever you want, we can review a topic.", "Quando vuoi, ripassiamo un argomento.") }
        let total = DatosEscolares.esfuerzo(examen).ratos
        let hechos = min(examen.ratosHechos.count, total)
        return L("\(hechos) de \(total) ratos de estudio hechos", "\(hechos) of \(total) study sessions done", "\(hechos) di \(total) sessioni fatte")
    }
}

private struct Noche: ViewModifier {
    var activa: Bool

    func body(content: Content) -> some View {
        if activa {
            content
                .environment(\.colorScheme, .dark)
                .environment(\.sobreCielo, true)
                .background {
                    FondoTiempo()
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
