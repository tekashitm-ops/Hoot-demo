import SwiftUI
import FoundationModels

struct EsquemaDatos: Codable, Hashable, Sendable {
    struct Idea: Codable, Hashable, Sendable, Identifiable {
        var id = UUID()
        var texto: String
        var detalles: [String] = []
    }

    struct Rama: Codable, Hashable, Sendable, Identifiable {
        var id = UUID()
        var titulo: String
        var ideas: [Idea]
    }

    var titulo: String
    var ramas: [Rama]

    var texto: String {
        var t = "## \(titulo)\n"
        for r in ramas {
            t += "- **\(r.titulo)**\n"
            for i in r.ideas {
                t += "  - \(i.texto)\n"
                for d in i.detalles { t += "    - \(d)\n" }
            }
        }
        return t
    }

    static let colores: [ColorHoot] = [.azul, .verde, .naranja, .morado, .rosa, .turquesa, .indigo, .marron]

    static func color(_ i: Int) -> ColorHoot { colores[i % colores.count] }
}

@Observable
final class EsquemaIA: Hashable {
    nonisolated static func == (a: EsquemaIA, b: EsquemaIA) -> Bool { a === b }
    nonisolated func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }

    enum Fase: Equatable { case leyendo(Int, Int), resumiendo(Int, Int), pensando, escribiendo, listo, error(String) }

    var fase: Fase = .pensando
    var esquema: EsquemaDatos?
    var textoLeido = ""
    @ObservationIgnored private var tarea: Task<Void, Never>?

    func cancelar() {
        tarea?.cancel()
        vigilante?.cancel()
    }

    func empezar(imagenes: [UIImage], escrito: String, tema: String, asignatura: String?, curso: String,
                 alTerminar: @escaping (EsquemaIA) -> Void) {
        tarea?.cancel()
        tarea = Task { [weak self] in
            guard let self else { return }
            do {
                let texto = try await TrabajoIA.leer(imagenes, escrito: escrito) { i, n in self.fase = .leyendo(i, n) }
                self.textoLeido = texto

                let conClaude = MotorIA.quien(.esquema) == .claude
                let fotos = conClaude ? imagenes.prefix(20).compactMap { $0.reducida(a: 1568).jpegData(compressionQuality: 0.8) } : []
                guard texto.count > 20 || !fotos.isEmpty else {
                    self.fase = .error(L("No se lee texto en las fotos. Prueba con más luz y la hoja entera.", "No text found in the photos. Try with more light and the whole page.", "Nessun testo nelle foto. Riprova con più luce e la pagina intera."))
                    return
                }
                guard DisponibilidadIA.actual == .lista else {
                    self.fase = .error(DisponibilidadIA.actual.mensaje)
                    return
                }
                self.fase = .pensando

                let material = try await TrabajoIA.ajustar(texto, maximo: TrabajoIA.caracteresMaximos - 3000) { i, n in
                    self.fase = .resumiendo(i, n)
                }
                self.fase = .pensando
                let idea = DynamicGenerationSchema(name: "Idea", properties: [
                    .init(name: "texto", description: L("Una idea, en diez palabras como mucho", "One idea, ten words at most", "Un'idea, al massimo dieci parole"), schema: .init(type: String.self)),
                    .init(name: "detalles", description: L("Cero, uno o dos detalles muy cortos", "Zero, one or two very short details", "Zero, uno o due dettagli brevissimi"),
                          schema: .init(arrayOf: .init(type: String.self), minimumElements: 0, maximumElements: 2)),
                ])
                let rama = DynamicGenerationSchema(name: "Rama", properties: [
                    .init(name: "titulo", description: L("Título del apartado, dos a cinco palabras", "Section title, two to five words", "Titolo della sezione, da due a cinque parole"), schema: .init(type: String.self)),
                    .init(name: "ideas", schema: .init(arrayOf: .init(referenceTo: "Idea"), minimumElements: 2, maximumElements: 4)),
                ])
                let raiz = DynamicGenerationSchema(name: "Esquema", properties: [
                    .init(name: "titulo", description: L("El tema", "The topic", "L'argomento"), schema: .init(type: String.self)),
                    .init(name: "ramas", schema: .init(arrayOf: .init(referenceTo: "Rama"), minimumElements: 3, maximumElements: 5)),
                ])
                let esquema = try GenerationSchema(root: raiz, dependencies: [rama, idea])
                let c = curso.isEmpty ? "" : L(" de \(curso)", " in \(curso)", " di \(curso)")
                let instrucciones = L("Eres Hoot y haces esquemas para que estudiantes\(c) estudien. Escribe en español. Usa solo la información del texto.",
                                      "You are Hoot and you make outlines so students\(c) can study. Write in English. Use only the information in the text.",
                                      "Sei Hoot e fai schemi perché gli studenti\(c) studino. Scrivi in italiano. Usa solo le informazioni del testo.")
                let materia = asignatura.map { L(" de \($0)", " in \($0)", " di \($0)") } ?? ""
                let t = tema.trimmingCharacters(in: .whitespaces)
                let sobre = t.isEmpty ? "" : L(" sobre «\(t)»", " about “\(t)”", " su «\(t)»")
                let prompt = L("Haz el esquema del tema\(materia)\(sobre): el título, los apartados principales, las ideas clave de cada apartado y algún detalle importante (fechas, fórmulas, ejemplos). Frases muy cortas.\n\nTEXTO:\n\(material)",
                          "Make the outline of this topic\(materia)\(sobre): the title, the main sections, the key ideas in each section and a few important details (dates, formulas, examples). Very short phrases.\n\nTEXT:\n\(material)",
                          "Fai lo schema dell'argomento\(materia)\(sobre): il titolo, le sezioni principali, le idee chiave di ogni sezione e qualche dettaglio importante (date, formule, esempi). Frasi brevissime.\n\nTESTO:\n\(material)")

                if conClaude {
                    self.ultimoAvance = .now.addingTimeInterval(60)
                    self.vigilar()
                    let r = try await MotorIA.conForma(.esquema, instrucciones: instrucciones, prompt: prompt, esquema: esquema, fotos: fotos,
                                                       maximo: 900, temperatura: 0.3)
                    self.vigilante?.cancel()
                    let datos = Self.leer(r)
                    guard !datos.ramas.isEmpty else {
                        Registro.aviso("Esquema vacío", en: "esquema")
                        self.fase = .error(L("No se ha podido hacer el esquema. Inténtalo otra vez.", "Couldn't make the outline. Please try again.", "Non è stato possibile fare lo schema. Riprova."))
                        return
                    }
                    conMuelle {
                        self.esquema = datos
                        self.fase = .listo
                    }
                    alTerminar(self)
                    return
                }

                let sesion = LanguageModelSession(model: SystemLanguageModel(guardrails: .permissiveContentTransformations), instructions: instrucciones)
                let flujo = sesion.streamResponse(to: prompt, schema: esquema, options: GenerationOptions(temperature: 0.3, maximumResponseTokens: 900))
                self.ultimoAvance = .now
                self.vigilar()
                var final: GeneratedContent?
                for try await parcial in flujo {
                    try Task.checkCancellation()
                    self.ultimoAvance = .now
                    final = parcial.rawContent
                    let datos = Self.leer(parcial.rawContent)
                    if !datos.ramas.isEmpty {
                        if self.fase != .escribiendo { self.fase = .escribiendo }
                        self.esquema = datos
                    }
                }
                self.vigilante?.cancel()
                guard let final else {
                    self.fase = .error(L("No se ha podido hacer el esquema. Inténtalo otra vez.", "Couldn't make the outline. Please try again.", "Non è stato possibile fare lo schema. Riprova."))
                    return
                }
                let datos = Self.leer(final)
                guard !datos.ramas.isEmpty else {
                    self.fase = .error(L("No se ha podido hacer el esquema. Inténtalo otra vez.", "Couldn't make the outline. Please try again.", "Non è stato possibile fare lo schema. Riprova."))
                    return
                }
                conMuelle {
                    self.esquema = datos
                    self.fase = .listo
                }
                alTerminar(self)
            } catch is CancellationError {
                return
            } catch {
                Registro.error(error, en: "esquema")
                self.fase = .error(MotorIA.mensaje(error, siNo: L("No se ha podido hacer el esquema. Inténtalo otra vez.", "Couldn't make the outline. Please try again.", "Non è stato possibile fare lo schema. Riprova.")))
            }
        }
    }

    @ObservationIgnored private var ultimoAvance = Date.now
    @ObservationIgnored private var vigilante: Task<Void, Never>?

    private func vigilar() {
        vigilante?.cancel()
        vigilante = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, !Task.isCancelled else { return }
                if Date.now.timeIntervalSince(self.ultimoAvance) > 60 {
                    self.tarea?.cancel()
                    self.fase = .error(L("Está tardando demasiado. Prueba con menos fotos o con un tema más corto.",
                                         "It's taking too long. Try fewer photos or a shorter topic.",
                                         "Ci sta mettendo troppo. Prova con meno foto o un argomento più breve."))
                    return
                }
            }
        }
    }

    private static func leer(_ c: GeneratedContent) -> EsquemaDatos {
        func id(_ a: Int, _ b: Int = 0) -> UUID {
            UUID(uuidString: String(format: "00000000-0000-0000-%04d-%012d", a, b)) ?? UUID()
        }
        let titulo = (try? c.value(String.self, forProperty: "titulo")) ?? ""
        let ramas = ((try? c.value([GeneratedContent].self, forProperty: "ramas")) ?? []).enumerated().map { i, r in
            EsquemaDatos.Rama(
                id: id(i + 1),
                titulo: (try? r.value(String.self, forProperty: "titulo")) ?? "",
                ideas: ((try? r.value([GeneratedContent].self, forProperty: "ideas")) ?? []).enumerated().map { j, idea in
                    EsquemaDatos.Idea(id: id(i + 1, j + 1),
                                      texto: (try? idea.value(String.self, forProperty: "texto")) ?? "",
                                      detalles: ((try? idea.value([String].self, forProperty: "detalles")) ?? []).filter { !$0.isEmpty })
                }.filter { !$0.texto.isEmpty }
            )
        }.filter { !$0.titulo.isEmpty }
        return EsquemaDatos(titulo: titulo, ramas: ramas)
    }
}

struct EsquemaDibujo: View {
    var esquema: EsquemaDatos

    var body: some View {
        EsquemaCajas(esquema: esquema)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(esquema.titulo)
            .accessibilityValue(esquema.ramas.map { r in r.titulo + ": " + r.ideas.map(\.texto).joined(separator: ", ") }.joined(separator: ". "))
    }
}

struct EsquemaCajas: View {
    var esquema: EsquemaDatos
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(esquema.titulo)
                .font(.title.bold())
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)
            if letra.isAccessibilitySize {

                VStack(spacing: 12) {
                    ForEach(esquema.ramas.indices, id: \.self) { i in caja(i) }
                }
            } else {

                Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 12) {
                    ForEach(Array(stride(from: 0, to: esquema.ramas.count, by: 2)), id: \.self) { i in
                        GridRow(alignment: .top) {
                            if i + 1 < esquema.ramas.count {
                                caja(i)
                                caja(i + 1)
                            } else {
                                caja(i).gridCellColumns(2)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func caja(_ i: Int) -> some View {
        let rama = esquema.ramas[i]
        let color = EsquemaDatos.color(i)
        return VStack(alignment: .leading, spacing: 8) {
            Text(rama.titulo)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.hondo, in: UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rama.ideas) { idea in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(idea.texto)
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(idea.detalles, id: \.self) { d in
                            Text("– " + d)
                                .font(.caption)
                                .foregroundStyle(Color.texto2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(color.color.opacity(0.35), lineWidth: 1))
    }
}

enum PDFEsquema {

    @MainActor
    static func crear(_ esquema: EsquemaDatos) -> URL? {
        let nombre = esquema.titulo.isEmpty ? L("Esquema", "Outline", "Schema") : esquema.titulo
        let limpio = nombre.components(separatedBy: CharacterSet(charactersIn: "/\\?%*|\"<>:")).joined(separator: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(limpio).pdf")
        let ancho: CGFloat = 640
        let margen: CGFloat = 36
        let vista = EsquemaDibujo(esquema: esquema)
            .frame(width: ancho)
            .background(Color.white)
            .environment(\.colorScheme, .light)
            .environment(\.dynamicTypeSize, .large)
        let renderer = ImageRenderer(content: vista)
        var hecho = false
        renderer.render { tamano, dibujar in
            let vertical = CGSize(width: 595, height: 842), apaisado = CGSize(width: 842, height: 595)
            func escala(_ p: CGSize) -> CGFloat {
                min((p.width - 2 * margen) / tamano.width, (p.height - 2 * margen) / tamano.height, 1.2)
            }
            var pagina: CGRect
            var e: CGFloat
            if max(escala(vertical), escala(apaisado)) >= 0.8 {
                let p = escala(vertical) >= escala(apaisado) ? vertical : apaisado
                pagina = CGRect(origin: .zero, size: p)
                e = escala(p)
            } else {
                e = min(1, (vertical.width - 2 * margen) / tamano.width)
                pagina = CGRect(x: 0, y: 0, width: vertical.width, height: tamano.height * e + 2 * margen)
            }
            guard let ctx = CGContext(url as CFURL, mediaBox: &pagina, nil) else { return }
            ctx.beginPDFPage(nil)
            ctx.setFillColor(CGColor(gray: 1, alpha: 1))
            ctx.fill(pagina)

            ctx.translateBy(x: (pagina.width - tamano.width * e) / 2, y: pagina.height - margen - tamano.height * e)
            ctx.scaleBy(x: e, y: e)
            dibujar(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
            hecho = true
        }
        return hecho ? url : nil
    }
}

struct ResultadoEsquema: View {
    var trabajo: EsquemaIA?
    var guardado: EsquemaDatos?
    var titulo: String
    var alTerminar: (() -> Void)?

    @State private var pdf: URL?

    private var esquema: EsquemaDatos? { guardado ?? trabajo?.esquema }
    private var terminado: Bool { guardado != nil || trabajo?.fase == .listo }

    var body: some View {
        ScrollView {
            if let esquema {
                EsquemaDibujo(esquema: esquema)
                    .padding(Diseno.margen)
                    .animando(Diseno.muelle, valor: esquema.ramas.count)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                if !terminado, !(trabajo?.fase.esError ?? false) {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(L("Escribiendo", "Writing", "Sto scrivendo")).textoSecundario()
                    }
                    .padding(.bottom, 30)
                }
                if let trabajo, case .error(let m) = trabajo.fase {
                    Label(m, systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(Color.urgente)
                        .padding(Diseno.margen)
                }
            } else if let trabajo {
                VStack(spacing: 18) {
                    Group {
                        if trabajo.fase.esError { Lobo(tamano: 120, gesto: .sorprendido) } else { LoboTrabajando(tamano: 120, gesto: .escribiendo) }
                    }
                    .padding(.top, 60)
                    Text(estado(trabajo.fase))
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    if !trabajo.fase.esError { ProgressView() }
                }
                .frame(maxWidth: .infinity)
                .padding(Diseno.margen)
            }
        }

        .navigationTitle(TipoAyuda.esquema.nombreCorto)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(trabajo != nil && !terminado && !(trabajo?.fase.esError ?? false))
        .toolbar {
            if let pdf {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: pdf) {
                        Label("PDF", systemImage: "arrow.down.doc")
                    }
                }
            }
            if let alTerminar, terminado {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm, action: alTerminar)
                }
            } else if let trabajo, !terminado, !trabajo.fase.esError {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Parar", "Stop", "Ferma")) { trabajo.cancelar(); alTerminar?() }
                }
            }
        }

        .onChange(of: terminado) { _, listo in if listo, let e = esquema { pdf = PDFEsquema.crear(e) } }
        .onAppear { if terminado, let e = esquema { pdf = PDFEsquema.crear(e) } }
        .sensoryFeedback(.success, trigger: terminado) { _, listo in listo }
    }

    private func estado(_ f: EsquemaIA.Fase) -> String {
        switch f {
        case .leyendo(let i, let n):
            n > 1 ? L("Leyendo la foto \(i) de \(n)", "Reading photo \(i) of \(n)", "Sto leggendo la foto \(i) di \(n)") : L("Leyendo la foto", "Reading the photo", "Sto leggendo la foto")
        case .resumiendo(let i, let n): L("Leyendo el tema (\(i) de \(n))", "Reading the topic (\(i) of \(n))", "Leggo l'argomento (\(i) di \(n))")
        case .pensando: L("Ordenando las ideas", "Organizing the ideas", "Metto in ordine le idee")
        case .escribiendo, .listo: ""
        case .error(let m): m
        }
    }
}

extension EsquemaIA.Fase {
    var esError: Bool {
        if case .error = self { return true }
        return false
    }
}
