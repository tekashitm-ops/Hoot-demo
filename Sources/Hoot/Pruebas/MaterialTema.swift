import SwiftUI
import PhotosUI

@Observable
final class ControlMaterial {
    let temaID: UUID
    var leyendo = false
    var progreso: String?
    var aviso: String?
    var eligiendo = false
    var seleccion: [PhotosPickerItem] = []
    var escaneando = false
    var fotografiando = false
    var importando = false
    var pegando = false

    static let maximoFotos = 30

    init(temaID: UUID) { self.temaID = temaID }

    func prepararTemaViejo(_ almacen: Almacen) {
        guard let t = almacen.datos.tema(temaID), t.fuentes.isEmpty, !t.textoLeido.isEmpty || !t.miniaturas.isEmpty else { return }
        almacen.datos.cambiarTema(temaID) { $0.prepararFuentes() }
    }

    func cargarFotos(_ items: [PhotosPickerItem], _ almacen: Almacen) {
        guard !items.isEmpty else { return }
        Task {
            var imagenes: [UIImage] = []
            for item in items {
                if let datos = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: datos) { imagenes.append(img) }
            }
            seleccion = []
            anadirFotos(imagenes, almacen)
        }
    }

    func anadirFotos(_ imagenes: [UIImage], _ almacen: Almacen) {
        guard !imagenes.isEmpty else { return }
        trabajar(almacen) {
            let reducidas = imagenes.map { $0.reducida(a: 2400) }
            let texto = try await TrabajoIA.leer(reducidas, escrito: "") { i, n in self.progreso = Self.leyendoFoto(i, n) }
            guard texto.trimmingCharacters(in: .whitespacesAndNewlines).count > 20 else {
                self.aviso = L("No se lee texto en las fotos. Prueba con más luz y la hoja entera.", "No text found in the photos. Try with more light and the whole page.",
                               "Nessun testo nelle foto. Riprova con più luce e la pagina intera.")
                return
            }
            let miniaturas = reducidas.compactMap { $0.reducida(a: 360).jpegData(compressionQuality: 0.6) }
            await self.guardar(FuenteTema(tipo: .fotos, nombre: "", paginas: miniaturas.count, texto: texto), miniaturas: miniaturas, almacen)
        }
    }

    func anadirArchivos(_ urls: [URL], _ almacen: Almacen) {
        guard !urls.isEmpty else { return }
        trabajar(almacen) {
            for url in urls {
                let nombre = url.deletingPathExtension().lastPathComponent
                self.progreso = L("Abriendo «\(nombre)»…", "Opening “\(nombre)”…", "Apro «\(nombre)»…")
                guard let leido = try? await LectorDocumentos.leer(url) else {
                    self.aviso = Self.noSeLee(nombre)
                    continue
                }
                var texto = leido.texto
                var miniaturas: [Data] = []
                if !leido.imagenes.isEmpty {
                    let reducidas = leido.imagenes.map { $0.reducida(a: 2400) }
                    let fotos = leido.tipo == .fotos
                    let ocr = try await TrabajoIA.leer(reducidas, escrito: "") { i, n in
                        self.progreso = fotos ? Self.leyendoFoto(i, n) : L("Leyendo la página \(i) de \(n)…", "Reading page \(i) of \(n)…", "Leggo la pagina \(i) di \(n)…")
                    }
                    texto = [texto, ocr].filter { !$0.isEmpty }.joined(separator: "\n\n")
                    if fotos { miniaturas = reducidas.compactMap { $0.reducida(a: 360).jpegData(compressionQuality: 0.6) } }
                }
                guard texto.trimmingCharacters(in: .whitespacesAndNewlines).count > 20 else {
                    self.aviso = Self.noSeLee(nombre)
                    continue
                }
                await self.guardar(FuenteTema(tipo: leido.tipo, nombre: leido.tipo == .fotos ? "" : leido.nombre,
                                              paginas: leido.paginas, texto: texto), miniaturas: miniaturas, almacen)
            }
        }
    }

    func anadirTexto(_ texto: String, _ almacen: Almacen) {
        trabajar(almacen) { await self.guardar(FuenteTema(tipo: .texto, nombre: "", texto: texto), miniaturas: [], almacen) }
    }

    func quitar(_ id: UUID, _ almacen: Almacen) {
        conMuelle { almacen.datos.cambiarTema(temaID) { $0.quitarFuente(id) } }
        trabajar(almacen) { await self.juntarTexto(almacen) }
    }

    private func trabajar(_ almacen: Almacen, _ cuerpo: @escaping () async throws -> Void) {
        aviso = nil
        leyendo = true
        Task {
            do { try await cuerpo() } catch is CancellationError {} catch {
                aviso = L("No se ha podido leer. Inténtalo otra vez.", "Couldn't read it. Please try again.", "Non è stato possibile leggerlo. Riprova.")
            }
            progreso = nil
            leyendo = false
        }
    }

    private func guardar(_ f: FuenteTema, miniaturas: [Data], _ almacen: Almacen) async {
        conMuelle {
            almacen.datos.cambiarTema(temaID) { t in
                t.prepararFuentes()
                t.fuentes.append(f)
                t.miniaturas += miniaturas
            }
        }
        await juntarTexto(almacen)
    }

    private func juntarTexto(_ almacen: Almacen) async {
        guard let t = almacen.datos.tema(temaID), t.puedeQuitarFuentes else { return }
        let junto = t.textoDeFuentes
        let maximo = TrabajoIA.caracteresMaximos * 2
        var texto = junto
        if junto.count > maximo {
            texto = String(junto.prefix(maximo))
            if DisponibilidadIA.actual == .lista {
                progreso = L("Preparando el material para Hoot…", "Getting the material ready for Hoot…", "Preparo il materiale per Hoot…")
                if let apuntes = try? await TrabajoIA.ajustar(junto, maximo: maximo, progreso: { i, n in
                    self.progreso = L("Preparando el material para Hoot… \(i) de \(n)", "Getting the material ready for Hoot… \(i) of \(n)", "Preparo il materiale per Hoot… \(i) di \(n)")
                }) {
                    texto = apuntes
                }
            }
        }
        almacen.datos.cambiarTema(temaID) { $0.textoLeido = texto }
    }

    static func leyendoFoto(_ i: Int, _ n: Int) -> String {
        n == 1 ? L("Leyendo la foto…", "Reading the photo…", "Leggo la foto…")
               : L("Leyendo la foto \(i) de \(n)…", "Reading photo \(i) of \(n)…", "Leggo la foto \(i) di \(n)…")
    }

    private static func noSeLee(_ nombre: String) -> String {
        L("No se puede leer «\(nombre)». Si es de Keynote o Pages, expórtalo como PDF.",
          "“\(nombre)” can't be read. If it's from Keynote or Pages, export it as a PDF.",
          "Non si riesce a leggere «\(nombre)». Se è di Keynote o Pages, esportalo in PDF.")
    }
}

extension View {

    func presentacionesMaterial(_ control: ControlMaterial) -> some View {
        modifier(PresentacionesMaterial(control: control))
    }
}

private struct PresentacionesMaterial: ViewModifier {
    @Bindable var control: ControlMaterial
    @Environment(Almacen.self) private var almacen

    func body(content: Content) -> some View {
        content
            .task { control.prepararTemaViejo(almacen) }
            .photosPicker(isPresented: $control.eligiendo, selection: $control.seleccion, maxSelectionCount: ControlMaterial.maximoFotos,
                          selectionBehavior: .ordered, matching: .images)
            .onChange(of: control.seleccion) { _, items in control.cargarFotos(items, almacen) }
            .fullScreenCover(isPresented: $control.escaneando) {
                EscanerDocumentos { paginas in
                    control.escaneando = false
                    control.anadirFotos(paginas, almacen)
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $control.fotografiando) {
                CamaraFoto { foto in
                    control.fotografiando = false
                    if let foto { control.anadirFotos([foto], almacen) }
                }
                .ignoresSafeArea()
            }
            .fileImporter(isPresented: $control.importando, allowedContentTypes: LectorDocumentos.tipos, allowsMultipleSelection: true) { r in
                if case .success(let urls) = r { control.anadirArchivos(urls, almacen) }
            }
            .sheet(isPresented: $control.pegando) {
                EditorTextoTema { control.anadirTexto($0, almacen) }
            }
    }
}

struct SeccionMaterial: View {
    var control: ControlMaterial

    var alAnadir: () -> Void = {}

    @Environment(Almacen.self) private var almacen
    @Environment(\.dynamicTypeSize) private var letra
    @ScaledMetric(relativeTo: .subheadline) private var altoBaldosa: CGFloat = 76
    @ScaledMetric(relativeTo: .body) private var ladoIcono: CGFloat = 34

    var body: some View {

        let t = almacen.datos.tema(control.temaID) ?? Tema(id: control.temaID, nombre: "")
        Group {
            if !t.fuentes.isEmpty || control.progreso != nil || control.aviso != nil {
                Section {
                    ForEach(t.fuentes) { f in
                        fila(f, tema: t)
                            .swipeActions {
                                if t.puedeQuitarFuentes {
                                    Button(role: .destructive) { control.quitar(f.id, almacen) } label: {
                                        Label(L("Quitar", "Remove", "Togli"), systemImage: "trash")
                                    }
                                }
                            }
                    }
                    .filaTenida()
                    if let progreso = control.progreso {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(progreso).foregroundStyle(EstiloSecundario())
                        }
                        .filaTenida()
                    }
                    if let aviso = control.aviso {
                        Label(aviso, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(EstiloAviso(color: .pronto))
                            .filaTenida()
                    }
                } header: {
                    Text(L("Material", "Material", "Materiale")).foregroundStyle(EstiloSecundario())
                }
            }

            Section {
                baldosas
            } header: {
                Text(t.fuentes.isEmpty ? L("Material", "Material", "Materiale") : L("Añadir", "Add", "Aggiungi"))
                    .foregroundStyle(EstiloSecundario())
            }
            Section {
                Button { alAnadir(); control.pegando = true } label: {
                    Label(L("Pegar un texto", "Paste Text", "Incolla un testo"), systemImage: "text.alignleft")
                }
                .disabled(control.leyendo)
                .filaTenida()
            } footer: {
                Text(L("Las preguntas de Hoot salen de aquí.", "Hoot's questions come from here.", "Le domande di Hoot escono da qui."))
                    .foregroundStyle(EstiloSecundario())
            }
        }
    }

    private func fila(_ f: FuenteTema, tema t: Tema) -> some View {
        HStack(spacing: 12) {
            icono(f, tema: t)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo(f)).foregroundStyle(.white).lineLimit(2)
                Text(detalle(f)).font(.subheadline).foregroundStyle(EstiloSecundario())
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func icono(_ f: FuenteTema, tema t: Tema) -> some View {
        if f.tipo == .fotos, let datos = primeraMiniatura(f, tema: t), let img = UIImage(data: datos) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: ladoIcono, height: ladoIcono * 1.3)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                .accessibilityHidden(true)
        } else {
            let (simbolo, color): (String, Color) = switch f.tipo {
            case .fotos: ("photo.on.rectangle", Color(.systemTeal))
            case .pdf: ("doc.richtext", Color(.systemRed))
            case .diapositivas: ("rectangle.on.rectangle", Color(.systemOrange))
            case .documento: ("doc.text", Color(.systemBlue))
            case .texto: ("text.alignleft", Color(.systemGray))
            }
            Image(systemName: simbolo)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: ladoIcono, height: ladoIcono)
                .background(color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
        }
    }

    private func primeraMiniatura(_ f: FuenteTema, tema t: Tema) -> Data? {
        guard let i = t.fuentes.firstIndex(where: { $0.id == f.id }) else { return nil }
        let antes = t.fuentes[..<i].filter { $0.tipo == .fotos }.reduce(0) { $0 + $1.paginas }
        return t.miniaturas.indices.contains(antes) ? t.miniaturas[antes] : nil
    }

    private func titulo(_ f: FuenteTema) -> String {
        switch f.tipo {
        case .fotos: f.nombre.isEmpty ? L("Fotos", "Photos", "Foto") : f.nombre
        case .texto: L("Texto pegado", "Pasted text", "Testo incollato")
        default: f.nombre
        }
    }

    private func detalle(_ f: FuenteTema) -> String {
        let n = f.paginas
        switch f.tipo {
        case .fotos: return n == 1 ? L("1 foto", "1 photo", "1 foto") : L("\(n) fotos", "\(n) photos", "\(n) foto")
        case .pdf: return n == 1 ? L("PDF · 1 página", "PDF · 1 page", "PDF · 1 pagina") : L("PDF · \(n) páginas", "PDF · \(n) pages", "PDF · \(n) pagine")
        case .diapositivas: return n == 1 ? L("1 diapositiva", "1 slide", "1 diapositiva") : L("\(n) diapositivas", "\(n) slides", "\(n) diapositive")
        case .documento: return L("Documento", "Document", "Documento")
        case .texto:
            let palabras = f.texto.split(whereSeparator: \.isWhitespace).count
            return L("\(palabras) palabras", "\(palabras) words", "\(palabras) parole")
        }
    }

    @ViewBuilder
    private var baldosas: some View {
        let escaner = EscanerDocumentos.disponible || ModoCapturas.activo
        let camara = !escaner && CamaraFoto.disponible
        if letra.isAccessibilitySize {
            if escaner {
                Button { alAnadir(); control.escaneando = true } label: { Label(L("Escanear páginas", "Scan Pages", "Scansiona pagine"), systemImage: "doc.viewfinder") }
                    .disabled(control.leyendo).filaTenida()
            } else if camara {
                Button { alAnadir(); control.fotografiando = true } label: { Label(L("Hacer una foto", "Take a Photo", "Scatta una foto"), systemImage: "camera") }
                    .disabled(control.leyendo).filaTenida()
            }
            Button { alAnadir(); control.eligiendo = true } label: { Label(L("Elegir fotos", "Choose Photos", "Scegli foto"), systemImage: "photo.on.rectangle") }
                .disabled(control.leyendo).filaTenida()
            Button { alAnadir(); control.importando = true } label: { Label(L("PDF o diapositivas", "PDF or Slides", "PDF o diapositive"), systemImage: "doc") }
                .disabled(control.leyendo).filaTenida()
        } else {
            HStack(spacing: 10) {
                if escaner {
                    Button { alAnadir(); control.escaneando = true } label: { BaldosaTenida(titulo: L("Escanear", "Scan", "Scansiona"), simbolo: "doc.viewfinder", alto: altoBaldosa) }
                        .accessibilityLabel(L("Escanear páginas", "Scan Pages", "Scansiona pagine"))
                } else if camara {
                    Button { alAnadir(); control.fotografiando = true } label: { BaldosaTenida(titulo: L("Cámara", "Camera", "Fotocamera"), simbolo: "camera", alto: altoBaldosa) }
                        .accessibilityLabel(L("Hacer una foto", "Take a Photo", "Scatta una foto"))
                }
                Button { alAnadir(); control.eligiendo = true } label: { BaldosaTenida(titulo: L("Fotos", "Photos", "Foto"), simbolo: "photo.on.rectangle", alto: altoBaldosa) }
                    .accessibilityLabel(L("Elegir fotos", "Choose Photos", "Scegli foto"))
                Button { alAnadir(); control.importando = true } label: {
                    BaldosaTenida(titulo: L("PDF o diapositivas", "PDF or Slides", "PDF o diapositive"), simbolo: "doc", alto: altoBaldosa)
                }
            }
            .botonTenido()
            .disabled(control.leyendo)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
        }
    }
}

struct BaldosaTenida: View {
    var titulo: String
    var simbolo: String
    var alto: CGFloat = 76

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: simbolo).font(.title2.weight(.semibold))
            Text(titulo)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: alto)
    }
}

struct EditorTextoTema: View {
    var alAnadir: (String) -> Void

    @Environment(\.dismiss) private var cerrar
    @State private var texto = ""
    @FocusState private var escribiendo: Bool

    private var vale: Bool { texto.trimmingCharacters(in: .whitespacesAndNewlines).count > 20 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $texto)
                        .frame(minHeight: 260)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(.white)
                        .focused($escribiendo)
                        .overlay(alignment: .topLeading) {
                            if texto.isEmpty {
                                Indicacion.texto(L("Pega o escribe aquí", "Paste or type here", "Incolla o scrivi qui"))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                .filaTenida()
            }
            .tenidaDelCielo(hoja: true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle(L("Pegar un texto", "Paste Text", "Incolla un testo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Añadir", "Add", "Aggiungi")) {
                        alAnadir(texto)
                        cerrar()
                    }
                    .disabled(!vale)
                }
                ToolbarItem(placement: .bottomBar) {
                    PasteButton(payloadType: String.self) { trozos in
                        let pegado = trozos.joined(separator: "\n")
                        texto = texto.isEmpty ? pegado : texto + "\n" + pegado
                    }
                    .labelStyle(.titleAndIcon)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground { FondoHojaTenida() }
        .onAppear { escribiendo = true }
    }
}
