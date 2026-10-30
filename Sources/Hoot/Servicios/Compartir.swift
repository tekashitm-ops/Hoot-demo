import SwiftUI
import UniformTypeIdentifiers

extension UTType {

    nonisolated static let temaHoot: UTType = {
        if let t = UTType(filenameExtension: "hoot", conformingTo: .data), t.isDeclared { return t }
        return UTType(exportedAs: "\(Bundle.main.bundleIdentifier ?? "hoot").tema", conformingTo: .data)
    }()
}

nonisolated struct TemaCompartido: Codable, Sendable, Identifiable {
    var id = UUID()
    var version = 1
    var de: String
    var nombre: String
    var asignatura: String?
    var texto: String
    var fuentes: [FuenteTema]
    var miniaturas: [Data]
    var fecha = Date()

    var nombreArchivo: String {
        let limpio = nombre.components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|")).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return limpio.isEmpty ? "Tema" : limpio
    }

    var resumen: [String] { fuentes.map(\.nombre) }

    static func leer(_ url: URL) -> TemaCompartido? {
        let acceso = url.startAccessingSecurityScopedResource()
        defer { if acceso { url.stopAccessingSecurityScopedResource() } }
        guard let datos = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TemaCompartido.self, from: datos)
    }
}

nonisolated extension TemaCompartido: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .temaHoot) { t in
            let carpeta = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
            let url = carpeta.appendingPathComponent("\(t.nombreArchivo).hoot")
            try JSONEncoder().encode(t).write(to: url)
            return SentTransferredFile(url)
        }
    }
}

extension Tema {

    func compartido(de: String, asignatura: String?) -> TemaCompartido {
        TemaCompartido(de: de, nombre: nombre, asignatura: asignatura, texto: textoLeido, fuentes: fuentes, miniaturas: Array(miniaturas.prefix(8)))
    }
}

struct RecibirTemaVista: View {
    var tema: TemaCompartido
    var alTerminar: () -> Void

    @Environment(Almacen.self) private var almacen
    @State private var destino: UUID?
    @State private var aTemasDeAhora = false

    var body: some View {
        NavigationStack {
            let cal = calendarioActual
            let ahora = Reloj.ahora
            let mismaAsignatura = { (p: Prueba) in almacen.datos.asignatura(p.asignaturaID)?.nombre.lowercased() == tema.asignatura?.lowercased() }
            let pruebas = almacen.datos.pruebas.filter { $0.diasQueFaltan(desde: ahora, cal: cal) >= 0 }
                .sorted { (mismaAsignatura($0) ? 0 : 1, $0.fecha) < (mismaAsignatura($1) ? 0 : 1, $1.fecha) }
            Form {
                Section {
                    HootDice(frase: L("Material de contrabando. Legal, eso sí.", "Smuggled material. Legal, though.", "Materiale di contrabbando. Legale, però."),
                             gesto: .feliz, tamano: 96, paraguasSiLlueve: false)
                        .listRowBackground(Color.clear)
                }
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tema.nombre).font(.title2.weight(.bold)).fontDesign(.rounded).foregroundStyle(.white)
                        Text([L("Te lo pasa \(tema.de)", "From \(tema.de)", "Te lo passa \(tema.de)"), tema.asignatura].compactMap { $0 }.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(EstiloSecundario())
                        if !tema.miniaturas.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(tema.miniaturas.enumerated()), id: \.offset) { _, d in
                                        if let img = UIImage(data: d) {
                                            Image(uiImage: img).resizable().scaledToFill().frame(width: 64, height: 84)
                                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(pruebas) { p in
                        Button {
                            destino = p.id
                            aTemasDeAhora = false
                        } label: {
                            HStack(spacing: 12) {
                                IconoAsignatura(asignatura: almacen.datos.asignatura(p.asignaturaID), lado: 30)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(almacen.datos.asignatura(p.asignaturaID)?.nombre ?? p.tipo.nombre).foregroundStyle(.white)
                                    Text("\(p.tipo.nombre) · \(Formato.diaRelativo(p.fecha))").font(.subheadline).foregroundStyle(EstiloSecundario())
                                }
                                Spacer()
                                if destino == p.id && !aTemasDeAhora { Image(systemName: "checkmark").foregroundStyle(Color.ambar).font(.headline) }
                            }
                        }
                    }
                    Button {
                        aTemasDeAhora = true
                        destino = nil
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock").font(.body.weight(.semibold)).frame(width: 30, height: 30).foregroundStyle(.white)
                            Text(L("Temas de ahora", "Current topics", "Argomenti di adesso")).foregroundStyle(.white)
                            Spacer()
                            if aTemasDeAhora { Image(systemName: "checkmark").foregroundStyle(Color.ambar).font(.headline) }
                        }
                    }
                } header: {
                    Text(L("¿Dónde lo pones?", "Where does it go?", "Dove lo metti?")).foregroundStyle(EstiloSecundario())
                }
                .filaTenida()
            }
            .tenidaDelCielo(hoja: true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle(L("Un tema para ti", "A topic for you", "Un argomento per te"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { BotonCerrar { alTerminar() } } }
            .safeAreaBar(edge: .bottom) {
                Button(action: anadir) { Text(L("Añadir", "Add", "Aggiungi")).frame(maxWidth: .infinity) }
                    .botonAmbar()
                    .controlSize(.large)
                    .disabled(destino == nil && !aTemasDeAhora)
                    .padding(.horizontal, Diseno.margen)
                    .padding(.bottom, 8)
            }
            .onAppear {
                if destino == nil, !aTemasDeAhora {
                    if let p = pruebas.first(where: mismaAsignatura) { destino = p.id } else if pruebas.isEmpty { aTemasDeAhora = true }
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground { FondoHojaTenida() }
    }

    private func anadir() {
        let nuevo = Tema(nombre: tema.nombre, miniaturas: tema.miniaturas, textoLeido: tema.texto,
                         fuentes: tema.fuentes.map { var f = $0; f.id = UUID(); return f })
        conMuelle {
            if aTemasDeAhora {
                let asig = almacen.datos.asignaturas.first { $0.nombre.lowercased() == tema.asignatura?.lowercased() }
                almacen.datos.temasDeAhora.append(TemaDeAhora(asignaturaID: asig?.id, tema: nuevo))
            } else if let id = destino, let i = almacen.datos.pruebas.firstIndex(where: { $0.id == id }) {
                almacen.datos.pruebas[i].temas.append(nuevo)
            }
        }
        alTerminar()
    }
}
