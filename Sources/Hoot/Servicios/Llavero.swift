import Foundation
import Security

nonisolated enum Llavero {
    private static let servicio = "com.ejemplo.hoot.nube"

    static func guardar<T: Encodable>(_ valor: T, como cuenta: String) {
        guard let datos = try? JSONEncoder().encode(valor) else { return }
        borrar(cuenta)
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: datos,
        ]
        SecItemAdd(consulta as CFDictionary, nil)
    }

    static func leer<T: Decodable>(_ tipo: T.Type, de cuenta: String) -> T? {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var resultado: AnyObject?
        guard SecItemCopyMatching(consulta as CFDictionary, &resultado) == errSecSuccess,
              let datos = resultado as? Data else { return nil }
        return try? JSONDecoder().decode(tipo, from: datos)
    }

    static func borrar(_ cuenta: String) {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
        ]
        SecItemDelete(consulta as CFDictionary)
    }
}
