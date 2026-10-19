import Foundation
import PDFKit
import UIKit
import UniformTypeIdentifiers

enum LectorDocumentos {
    struct Leido: Sendable {
        var tipo: FuenteTema.Tipo
        var nombre: String
        var texto: String

        var paginas: Int

        var imagenes: [UIImage]
    }

    enum Fallo: Error {
        case noSeLee
    }

    static var tipos: [UTType] {
        [.pdf, .image, .plainText, .rtf] + ["pptx", "docx", "odp", "odt"].compactMap { UTType(filenameExtension: $0) }
    }

    static func leer(_ url: URL) async throws -> Leido {
        let nombre = url.deletingPathExtension().lastPathComponent
        let extension_ = url.pathExtension.lowercased()
        let rotulo = L("Diapositiva", "Slide", "Diapositiva")
        let pagina = L("Página", "Page", "Pagina")
        let datos = try await Task.detached(priority: .userInitiated) { try Self.datos(de: url) }.value
        return try await Task.detached(priority: .userInitiated) { () throws -> Leido in
            switch extension_ {
            case "pdf": return try Self.pdf(datos, nombre: nombre, rotulo: pagina)
            case "pptx": return try Self.diapositivas(datos, nombre: nombre, rotulo: rotulo)
            case "docx": return try Self.zipXML(datos, nombre: nombre, entrada: "word/document.xml", parrafo: "w:p", texto: "w:t")
            case "odt", "odp": return try Self.zipXML(datos, nombre: nombre, entrada: "content.xml", parrafo: nil, texto: nil, tipo: extension_ == "odp" ? .diapositivas : .documento)
            case "txt", "text", "md":
                guard let t = String(data: datos, encoding: .utf8) ?? String(data: datos, encoding: .isoLatin1) else { throw Fallo.noSeLee }
                return Leido(tipo: .documento, nombre: nombre, texto: t, paginas: 0, imagenes: [])
            case "rtf":
                let t = try NSAttributedString(data: datos, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil).string
                return Leido(tipo: .documento, nombre: nombre, texto: t, paginas: 0, imagenes: [])
            default:
                guard let img = UIImage(data: datos) else { throw Fallo.noSeLee }
                return Leido(tipo: .fotos, nombre: nombre, texto: "", paginas: 1, imagenes: [img])
            }
        }.value
    }

    private nonisolated static func datos(de url: URL) throws -> Data {
        let acceso = url.startAccessingSecurityScopedResource()
        defer { if acceso { url.stopAccessingSecurityScopedResource() } }
        var leidos: Data?
        var fallo: Error?
        var errorCoordinador: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [.withoutChanges], error: &errorCoordinador) { u in
            do { leidos = try Data(contentsOf: u) } catch { fallo = error }
        }
        if let d = leidos { return d }
        throw fallo ?? errorCoordinador ?? Fallo.noSeLee
    }

    private nonisolated static func pdf(_ datos: Data, nombre: String, rotulo: String) throws -> Leido {
        guard let doc = PDFDocument(data: datos), doc.pageCount > 0 else { throw Fallo.noSeLee }
        let n = doc.pageCount
        var partes: [String] = []
        var letras = 0
        for i in 0..<min(n, 60) {
            if let t = doc.page(at: i)?.string?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                partes.append("[\(rotulo) \(i + 1)]\n\(t)")
                letras += t.count
            }
        }
        let texto = partes.joined(separator: "\n\n")
        if letras >= 40 * min(n, 60) / 2 {
            return Leido(tipo: .pdf, nombre: nombre, texto: texto, paginas: n, imagenes: [])
        }

        var imagenes: [UIImage] = []
        for i in 0..<min(n, 30) {
            guard let p = doc.page(at: i) else { continue }
            let caja = p.bounds(for: .mediaBox)
            let escala = 2000 / max(caja.width, caja.height, 1)
            imagenes.append(p.thumbnail(of: CGSize(width: caja.width * escala, height: caja.height * escala), for: .mediaBox))
        }
        return Leido(tipo: .pdf, nombre: nombre, texto: texto, paginas: n, imagenes: imagenes)
    }

    private nonisolated static func diapositivas(_ datos: Data, nombre: String, rotulo: String) throws -> Leido {
        guard let zip = ZipLeido(datos) else { throw Fallo.noSeLee }
        let numero: (String) -> Int? = { e in
            guard e.hasPrefix("ppt/slides/slide"), e.hasSuffix(".xml") else { return nil }
            return Int(e.dropFirst("ppt/slides/slide".count).dropLast(4))
        }
        let slides = zip.nombres.compactMap { e in numero(e).map { (e, $0) } }.sorted { $0.1 < $1.1 }
        guard !slides.isEmpty else { throw Fallo.noSeLee }
        var partes: [String] = []
        for (n, (entrada, _)) in slides.enumerated() {
            guard let d = zip.datos(entrada), let xml = String(data: d, encoding: .utf8) else { continue }
            let t = TextoOffice.textoXML(xml, parrafo: "a:p", texto: "a:t")
            if !t.isEmpty { partes.append("\(rotulo) \(n + 1)\n\(t)") }
        }
        return Leido(tipo: .diapositivas, nombre: nombre, texto: partes.joined(separator: "\n\n"), paginas: slides.count, imagenes: [])
    }

    private nonisolated static func zipXML(_ datos: Data, nombre: String, entrada: String, parrafo: String?, texto: String?,
                                           tipo: FuenteTema.Tipo = .documento) throws -> Leido {
        guard let zip = ZipLeido(datos), let d = zip.datos(entrada), let xml = String(data: d, encoding: .utf8) else { throw Fallo.noSeLee }
        let t: String
        if let parrafo {
            t = TextoOffice.textoXML(xml, parrafo: parrafo, texto: texto)
        } else {
            t = TextoOffice.textoODF(xml)
        }
        return Leido(tipo: tipo, nombre: nombre, texto: t, paginas: 0, imagenes: [])
    }
}
