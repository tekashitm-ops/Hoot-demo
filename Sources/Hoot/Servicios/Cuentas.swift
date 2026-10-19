import Foundation
import CryptoKit
import UIKit

enum Cuentas {
    static func correoValido(_ texto: String) -> Bool {
        let t = texto.trimmingCharacters(in: .whitespaces)
        let partes = t.split(separator: "@")
        guard partes.count == 2, !partes[0].isEmpty else { return false }
        let dominio = partes[1]
        guard dominio.contains("."), !dominio.hasPrefix("."), !dominio.hasSuffix("."), !t.contains(" ") else { return false }
        return true
    }

    static func nuevoCodigo() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
    }

    static func nuevaSal() -> String {
        UUID().uuidString
    }

    static func hash(_ contrasena: String, sal: String) -> String {
        let datos = Data((sal + contrasena).utf8)
        return SHA256.hash(data: datos).map { String(format: "%02x", $0) }.joined()
    }

    struct Requisitos {
        let largo: Bool, numero: Bool, mayuscula: Bool
        var cumple: Bool { largo && numero && mayuscula }

        init(_ c: String) {
            largo = c.count >= 8
            numero = c.contains { $0.isNumber }
            mayuscula = c.contains { $0.isUppercase }
        }
    }

    private static var carpetaCuentas: URL {
        let url = Almacen.carpeta.appendingPathComponent("Cuentas", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func nombreArchivo(_ correo: String) -> String {
        let limpio = correo.lowercased().trimmingCharacters(in: .whitespaces)
        return SHA256.hash(data: Data(limpio.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func guardarCopia(_ estado: EstadoGuardado, foto: UIImage?, correo: String) {
        let base = carpetaCuentas.appendingPathComponent(nombreArchivo(correo))
        if let data = try? JSONEncoder().encode(estado) {
            try? data.write(to: base.appendingPathExtension("json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
        if let foto, let data = foto.jpegData(compressionQuality: 0.85) {
            try? data.write(to: base.appendingPathExtension("jpg"), options: .atomic)
        }
    }

    static func existe(_ correo: String) -> Bool {
        FileManager.default.fileExists(atPath: carpetaCuentas.appendingPathComponent(nombreArchivo(correo)).appendingPathExtension("json").path)
    }

    enum ErrorSesion: Error {
        case noExiste, contrasena
    }

    static func iniciarSesion(correo: String, contrasena: String) -> Result<(EstadoGuardado, UIImage?), ErrorSesion> {
        let base = carpetaCuentas.appendingPathComponent(nombreArchivo(correo))
        guard let data = try? Data(contentsOf: base.appendingPathExtension("json")),
              let estado = try? JSONDecoder().decode(EstadoGuardado.self, from: data) else {
            return .failure(.noExiste)
        }
        guard hash(contrasena, sal: estado.cuenta.sal) == estado.cuenta.hash else {
            return .failure(.contrasena)
        }
        let foto = (try? Data(contentsOf: base.appendingPathExtension("jpg"))).flatMap(UIImage.init(data:))
        return .success((estado, foto))
    }
}
