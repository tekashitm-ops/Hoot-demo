import Foundation

nonisolated enum ConfigBaseEnVivo {

    static var base: String {
        ConfigNube.proyecto.isEmpty ? "" : "https://\(ConfigNube.proyecto)-default-rtdb.europe-west1.firebasedatabase.app"
    }

    static var lista: Bool { ConfigNube.lista && !base.isEmpty }
}

nonisolated enum FalloVivo: Error, Equatable, Sendable {

    case sinCuenta

    case sinPermiso
    case sinRed
    case otro(Int)
}

actor BaseEnVivo {
    static let compartido = BaseEnVivo()

    private let red: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 15
        c.waitsForConnectivity = false
        c.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: c)
    }()

    func leer(_ ruta: String) async throws -> JSONVivo {
        JSONVivo.leer(try await pedir(ruta, "GET", nil))
    }

    func poner(_ ruta: String, _ valor: JSONVivo) async throws {
        _ = try await pedir(ruta, "PUT", valor.datos())
    }

    func parchear(_ ruta: String, _ hijos: [String: JSONVivo]) async throws {
        _ = try await pedir(ruta, "PATCH", JSONVivo.objeto(hijos).datos())
    }

    func anadir(_ ruta: String, _ valor: JSONVivo) async throws -> String {
        let r = JSONVivo.leer(try await pedir(ruta, "POST", valor.datos()))
        return r["name"].texto ?? ""
    }

    func borrar(_ ruta: String) async throws {
        _ = try await pedir(ruta, "DELETE", nil)
    }

    private func pedir(_ ruta: String, _ metodo: String, _ cuerpo: Data?) async throws -> Data {
        let url = try await BaseEnVivo.direccion(ruta)
        var p = URLRequest(url: url)
        p.httpMethod = metodo
        if let cuerpo {
            p.httpBody = cuerpo
            p.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let datos: Data, respuesta: URLResponse
        do { (datos, respuesta) = try await red.data(for: p) } catch { throw FalloVivo.sinRed }
        switch (respuesta as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200..<300: return datos
        case 401, 403: throw FalloVivo.sinPermiso
        case let e: throw FalloVivo.otro(e)
        }
    }

    fileprivate static func direccion(_ ruta: String) async throws -> URL {
        guard ConfigBaseEnVivo.lista else { throw FalloVivo.sinCuenta }
        let pase: String
        do { pase = try await Nube.compartida.pase() } catch { throw FalloVivo.sinCuenta }
        let limpia = ruta.split(separator: "/").joined(separator: "/")
        guard var c = URLComponents(string: "\(ConfigBaseEnVivo.base)/\(limpia).json") else { throw FalloVivo.otro(0) }
        c.queryItems = [URLQueryItem(name: "auth", value: pase)]
        guard let url = c.url else { throw FalloVivo.otro(0) }
        return url
    }

    nonisolated func escuchar(_ ruta: String, _ alCambiar: @escaping @Sendable (CambioVivo) -> Void) -> EscuchaVivo {
        EscuchaVivo(ruta: ruta, alCambiar: alCambiar)
    }
}

nonisolated final class EscuchaVivo: Sendable {
    private let tarea: Task<Void, Never>

    init(ruta: String, alCambiar: @escaping @Sendable (CambioVivo) -> Void) {
        tarea = Task.detached(priority: .userInitiated) {
            await EscuchaVivo.bucle(ruta: ruta, alCambiar: alCambiar)
        }
    }

    func cancelar() { tarea.cancel() }

    deinit { tarea.cancel() }

    private static func bucle(ruta: String, alCambiar: @escaping @Sendable (CambioVivo) -> Void) async {

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 75
        config.timeoutIntervalForResource = 7 * 24 * 3600
        let sesion = URLSession(configuration: config)
        defer { sesion.invalidateAndCancel() }
        var espera: Double = 1
        while !Task.isCancelled {
            var conectada = false
            do {
                var p = URLRequest(url: try await BaseEnVivo.direccion(ruta))
                p.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                let (bytes, respuesta) = try await sesion.bytes(for: p, delegate: RedireccionVivo())
                let estado = (respuesta as? HTTPURLResponse)?.statusCode ?? 0
                if estado == 401 || estado == 403 { alCambiar(.sinPermiso); return }
                guard estado == 200 else { throw FalloVivo.otro(estado) }
                conectada = true
                espera = 1
                var parser = ParserSSE()
                let inicio = Date()
                lectura: for try await byte in bytes {
                    if Task.isCancelled { return }
                    guard let evento = parser.anadir(byte) else { continue }
                    if let cambio = CambioVivo(evento) {
                        switch cambio {
                        case .sinPermiso: alCambiar(.sinPermiso); return
                        case .paseCaducado: break lectura
                        default: alCambiar(cambio)
                        }
                    }

                    if Date().timeIntervalSince(inicio) > 50 * 60 { break lectura }
                }
            } catch FalloVivo.sinCuenta {
                alCambiar(.sinPermiso)
                return
            } catch {
                if Task.isCancelled { return }
            }
            if Task.isCancelled { return }
            if !conectada {
                try? await Task.sleep(nanoseconds: UInt64(espera * 1_000_000_000))
                espera = min(espera * 2, 20)
            }
        }
    }
}

nonisolated final class RedireccionVivo: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        var r = request
        r.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        return r
    }
}
