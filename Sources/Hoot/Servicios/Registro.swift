import Foundation
import MetricKit
import UIKit

@Observable
final class Registro {
    static let compartido = Registro()

    struct Entrada: Codable, Identifiable, Hashable {
        var id = UUID()
        var fecha = Date()

        var donde: String

        var que: String
        var enviado = false
    }

    private static let claveEntradas = "registro.entradas"
    private static let claveCompartir = "registro.compartir"
    private static let claveAparato = "registro.aparato"

    private(set) var entradas: [Entrada] = Registro.leer()

    var compartir = UserDefaults.standard.object(forKey: claveCompartir) as? Bool ?? true {
        didSet { UserDefaults.standard.set(compartir, forKey: Self.claveCompartir) }
    }
    @ObservationIgnored private var suscriptor: SuscriptorDiagnosticos?
    @ObservationIgnored private var enviando = false

    func empezar() {
        guard !ModoCapturas.activo, suscriptor == nil else { return }
        let s = SuscriptorDiagnosticos { [weak self] informes in
            Task { @MainActor in
                for (donde, que) in informes { self?.apuntar(donde: donde, que: que) }
            }
        }
        suscriptor = s
        MXMetricManager.shared.add(s)
        enviarPendientes()
    }

    static func error(_ e: Error, en donde: String) {
        guard let que = descripcion(e) else { return }
        compartido.apuntar(donde: donde, que: que)
    }

    static func aviso(_ que: String, en donde: String) {
        compartido.apuntar(donde: donde, que: que)
    }

    private func apuntar(donde: String, que: String) {
        guard !ModoCapturas.activo else { return }
        entradas.insert(Entrada(donde: String(donde.prefix(60)), que: String(que.prefix(6000))), at: 0)
        if entradas.count > 100 { entradas.removeLast(entradas.count - 100) }
        guardar()
        enviarPendientes()
    }

    static func descripcion(_ e: Error) -> String? {
        if e is CancellationError { return nil }
        if let f = e as? ClaudeIA.Fallo {
            switch f {
            case .sinRed, .tope: return nil
            default: return "Claude: \(f.codigo)"
            }
        }
        if let u = e as? URLError {
            if [.notConnectedToInternet, .networkConnectionLost, .cancelled, .dataNotAllowed].contains(u.code) { return nil }
            return "URLError \(u.code.rawValue)"
        }
        if let d = e as? DecodingError {
            switch d {
            case let .keyNotFound(k, c): return "Decoding keyNotFound \(k.stringValue) en \(ruta(c))"
            case let .typeMismatch(t, c): return "Decoding typeMismatch \(t) en \(ruta(c))"
            case let .valueNotFound(t, c): return "Decoding valueNotFound \(t) en \(ruta(c))"
            case let .dataCorrupted(c): return "Decoding dataCorrupted en \(ruta(c))"
            @unknown default: return "Decoding"
            }
        }
        let n = e as NSError
        return "\(String(reflecting: type(of: e))) \(n.domain) \(n.code): \(String(describing: e).prefix(200))"
    }

    private static func ruta(_ c: DecodingError.Context) -> String {
        c.codingPath.map(\.stringValue).joined(separator: ".")
    }

    private static var aparato: [String: Any] {
        var id = UserDefaults.standard.string(forKey: claveAparato)
        if id == nil {
            id = UUID().uuidString
            UserDefaults.standard.set(id, forKey: claveAparato)
        }
        var info = utsname()
        uname(&info)
        let modelo = withUnsafePointer(to: &info.machine) { $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) } }
        let bundle = Bundle.main.infoDictionary ?? [:]
        return [
            "aparato": id ?? "",
            "version": bundle["CFBundleShortVersionString"] as? String ?? "",
            "build": bundle["CFBundleVersion"] as? String ?? "",
            "ios": UIDevice.current.systemVersion,
            "modelo": modelo,
            "idioma": idiomaActual.rawValue,
            "claude": ClaudeIA.activa,
        ]
    }

    func enviarPendientes() {
        guard compartir, !enviando, ConfigNube.lista, !ModoCapturas.activo else { return }
        let pendientes = entradas.filter { !$0.enviado }
        guard !pendientes.isEmpty else { return }
        enviando = true
        let base = Self.aparato
        Task {
            defer { enviando = false }
            for e in pendientes {
                var cuerpo = base
                cuerpo["fecha"] = Int(e.fecha.timeIntervalSince1970 * 1000)
                cuerpo["donde"] = e.donde
                cuerpo["que"] = e.que
                guard let url = URL(string: "https://\(ConfigNube.proyecto)-default-rtdb.europe-west1.firebasedatabase.app/errores.json"),
                      let datos = try? JSONSerialization.data(withJSONObject: cuerpo) else { continue }
                var p = URLRequest(url: url)
                p.httpMethod = "POST"
                p.httpBody = datos
                p.setValue("application/json", forHTTPHeaderField: "content-type")
                guard let (_, r) = try? await URLSession.shared.data(for: p), (r as? HTTPURLResponse)?.statusCode == 200 else { return }
                if let i = entradas.firstIndex(where: { $0.id == e.id }) { entradas[i].enviado = true }
                guardar()
            }
        }
    }

    func borrarTodo() {
        entradas = []
        guardar()
    }

    var texto: String {
        let f = Date.FormatStyle(date: .numeric, time: .standard)
        let cabecera = (Self.aparato.map { "\($0.key): \($0.value)" }.sorted()).joined(separator: " · ")
        return ([cabecera] + entradas.map { "[\($0.fecha.formatted(f))] \($0.donde): \($0.que)" }).joined(separator: "\n")
    }

    private func guardar() {
        if let d = try? JSONEncoder().encode(entradas) { UserDefaults.standard.set(d, forKey: Self.claveEntradas) }
    }

    private static func leer() -> [Entrada] {
        guard let d = UserDefaults.standard.data(forKey: claveEntradas), let e = try? JSONDecoder().decode([Entrada].self, from: d) else { return [] }
        return e
    }
}

nonisolated private final class SuscriptorDiagnosticos: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    let recibir: @Sendable ([(String, String)]) -> Void
    init(_ recibir: @escaping @Sendable ([(String, String)]) -> Void) { self.recibir = recibir }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        var informes: [(String, String)] = []
        for p in payloads {
            for c in p.crashDiagnostics ?? [] {
                let meta = c.metaData
                var que = "Cierre \(meta.applicationBuildVersion): excepción \(c.exceptionType?.stringValue ?? "-") código \(c.exceptionCode?.stringValue ?? "-") señal \(c.signal?.stringValue ?? "-")"
                if let r = c.terminationReason { que += " · \(r.prefix(300))" }
                if let pila = String(data: c.callStackTree.jsonRepresentation(), encoding: .utf8) { que += "\n" + pila.prefix(4500) }
                informes.append(("cierre", que))
            }
            for h in p.hangDiagnostics ?? [] {
                var que = "Cuelgue de \(h.hangDuration.converted(to: .seconds).value.formatted(.number.precision(.fractionLength(1)))) s"
                if let pila = String(data: h.callStackTree.jsonRepresentation(), encoding: .utf8) { que += "\n" + pila.prefix(4500) }
                informes.append(("cuelgue", que))
            }
        }
        if !informes.isEmpty { recibir(informes) }
    }
}
