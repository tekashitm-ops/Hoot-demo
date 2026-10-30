import Foundation
#if canImport(Compression)
import Compression
#endif

nonisolated struct ZipLeido {
    private struct Entrada {
        var metodo: Int
        var comprimido: Int
        var tamano: Int
        var cabecera: Int
    }

    private let datos: Data
    private var entradas: [String: Entrada] = [:]
    private(set) var nombres: [String] = []

    init?(_ datos: Data) {
        self.datos = datos
        let n = datos.count
        guard n >= 22 else { return nil }

        var fin = -1
        var i = n - 22
        let limite = max(0, n - 22 - 65_535)
        while i >= limite {
            if u32(i) == 0x0605_4b50 { fin = i; break }
            i -= 1
        }
        guard fin >= 0 else { return nil }
        let total = u16(fin + 10)
        var p = u32(fin + 16)
        for _ in 0..<total {
            guard p + 46 <= n, u32(p) == 0x0201_4b50 else { break }
            let largoNombre = u16(p + 28), extra = u16(p + 30), comentario = u16(p + 32)
            guard p + 46 + largoNombre <= n else { break }
            let nombre = String(decoding: datos[datos.startIndex + p + 46 ..< datos.startIndex + p + 46 + largoNombre], as: UTF8.self)
            entradas[nombre] = Entrada(metodo: u16(p + 10), comprimido: u32(p + 20), tamano: u32(p + 24), cabecera: u32(p + 42))
            nombres.append(nombre)
            p += 46 + largoNombre + extra + comentario
        }
        if entradas.isEmpty { return nil }
    }

    func datos(_ nombre: String) -> Data? {
        guard let e = entradas[nombre] else { return nil }
        let h = e.cabecera
        guard h + 30 <= datos.count, u32(h) == 0x0403_4b50 else { return nil }
        let inicio = h + 30 + u16(h + 26) + u16(h + 28)
        guard inicio + e.comprimido <= datos.count else { return nil }
        let trozo = datos[datos.startIndex + inicio ..< datos.startIndex + inicio + e.comprimido]
        switch e.metodo {
        case 0: return Data(trozo)
        case 8:
            #if canImport(Compression)
            guard e.tamano > 0, e.tamano < 200_000_000 else { return e.tamano == 0 ? Data() : nil }
            var salida = Data(count: e.tamano)
            let escritos = salida.withUnsafeMutableBytes { (d: UnsafeMutableRawBufferPointer) -> Int in
                Data(trozo).withUnsafeBytes { (o: UnsafeRawBufferPointer) -> Int in
                    guard let dd = d.bindMemory(to: UInt8.self).baseAddress, let oo = o.bindMemory(to: UInt8.self).baseAddress else { return 0 }

                    return compression_decode_buffer(dd, e.tamano, oo, e.comprimido, nil, COMPRESSION_ZLIB)
                }
            }
            return escritos == e.tamano ? salida : nil
            #else
            return nil
            #endif
        default:
            return nil
        }
    }

    private func u16(_ o: Int) -> Int {
        let b = datos.startIndex + o
        return Int(datos[b]) | Int(datos[b + 1]) << 8
    }

    private func u32(_ o: Int) -> Int {
        let b = datos.startIndex + o
        return Int(datos[b]) | Int(datos[b + 1]) << 8 | Int(datos[b + 2]) << 16 | Int(datos[b + 3]) << 24
    }
}

nonisolated enum TextoOffice {

    nonisolated static func textoXML(_ xml: String, parrafo: String, texto: String?) -> String {
        let patron = texto.map { "<\($0)(?:\\s[^>]*)?>([^<]*)</\($0)>" }
        let expresion = patron.flatMap { try? NSRegularExpression(pattern: $0) }
        var lineas: [String] = []
        for trozo in xml.components(separatedBy: "</\(parrafo)>") {
            let linea: String
            if let expresion {
                let r = NSRange(trozo.startIndex..., in: trozo)
                linea = expresion.matches(in: trozo, range: r).compactMap { m in Range(m.range(at: 1), in: trozo).map { String(trozo[$0]) } }.joined()
            } else {
                linea = sinEtiquetas(trozo)
            }
            let limpia = entidades(linea).trimmingCharacters(in: .whitespacesAndNewlines)
            if !limpia.isEmpty { lineas.append(limpia) }
        }
        return lineas.joined(separator: "\n")
    }

    nonisolated static func textoODF(_ xml: String) -> String {
        xml.components(separatedBy: "</text:p>").flatMap { $0.components(separatedBy: "</text:h>") }
            .map { entidades(sinEtiquetas($0)).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    nonisolated static func sinEtiquetas(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    nonisolated static func entidades(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var r = s.replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&apos;", with: "'")

        if let e = try? NSRegularExpression(pattern: "&#(x?)([0-9A-Fa-f]+);") {
            let ns = r as NSString
            var salida = ""
            var ultimo = 0
            for m in e.matches(in: r, range: NSRange(location: 0, length: ns.length)) {
                salida += ns.substring(with: NSRange(location: ultimo, length: m.range.location - ultimo))
                let hex = ns.substring(with: m.range(at: 1)) == "x"
                if let v = UInt32(ns.substring(with: m.range(at: 2)), radix: hex ? 16 : 10), let u = Unicode.Scalar(v) {
                    salida.unicodeScalars.append(u)
                }
                ultimo = m.range.location + m.range.length
            }
            salida += ns.substring(from: ultimo)
            r = salida
        }
        return r.replacingOccurrences(of: "&amp;", with: "&")
    }
}
