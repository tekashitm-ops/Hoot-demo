import SwiftUI
import CoreLocation

@MainActor
@Observable
final class TiempoReal: NSObject, CLLocationManagerDelegate {
    static let compartido = TiempoReal()

    private(set) var tiempo: Tiempo?
    private(set) var deDia: Bool?
    private(set) var actualizado: Date?

    private(set) var permiso: CLAuthorizationStatus = .notDetermined

    @ObservationIgnored private let ubicacion = CLLocationManager()
    @ObservationIgnored private var pidiendo = false

    private static let claveGuardado = "hoot.tiempo.ultimo"

    override private init() {
        super.init()
        ubicacion.delegate = self
        ubicacion.desiredAccuracy = kCLLocationAccuracyReduced
        permiso = ubicacion.authorizationStatus
        if let g = UserDefaults.standard.dictionary(forKey: Self.claveGuardado),
           let codigo = g["codigo"] as? Int, let dia = g["dia"] as? Bool, let cuando = g["fecha"] as? Double {
            tiempo = Tiempo(wmo: codigo)
            deDia = dia
            actualizado = Date(timeIntervalSince1970: cuando)
        }
    }

    func escena(fijado: TiempoFijo) -> Escena {
        let deDiaAhora = Self.esDeDia(Reloj.ahora)

        let reciente = actualizado.map { Date().timeIntervalSince($0) < 3 * 3600 } ?? false
        var dia = reciente && !Desarrollo.compartido.horaSimulada ? (deDia ?? deDiaAhora) : deDiaAhora
        let d = Desarrollo.compartido
        if let noche = d.nocheForzada { dia = !noche }
        if !ModoCapturas.activo, let t = d.tiempoForzado { return Escena.de(t, noche: !dia) }

        if ModoCapturas.activo, ModoCapturas.valor("-tiempo") == "algunasnubes" { return Escena.de(.algunasNubes, noche: !dia) }
        switch ModoCapturas.tiempoFijo ?? fijado {
        case .real: return Escena.de(tiempo ?? .despejado, noche: !dia)
        case .lluvia: return Escena.de(.lluvia, noche: !dia)
        case .tormenta: return Escena.de(.tormenta, noche: !dia)
        case .nieve: return Escena.de(.nieve, noche: !dia)
        case .granizo: return Escena.de(.granizo, noche: !dia)
        case .sol: return Escena.de(.despejado, noche: false)
        case .noche: return Escena.de(.despejado, noche: true)
        case .nubes: return Escena.de(.nubes, noche: !dia)
        case .niebla: return Escena.de(.niebla, noche: !dia)
        }
    }

    static func esDeDia(_ fecha: Date) -> Bool {
        let m = DatosEscolares.minutos(fecha)
        return m >= 7 * 60 + 30 && m < 19 * 60 + 30
    }

    var ultimo: (tiempo: Tiempo, deDia: Bool, cuando: Date)? {
        guard let tiempo, let deDia, let actualizado else { return nil }
        return (tiempo, deDia, actualizado)
    }

    func olvidar() {
        tiempo = nil
        deDia = nil
        actualizado = nil
        UserDefaults.standard.removeObject(forKey: Self.claveGuardado)
    }

    func pedir() {
        guard !ModoCapturas.activo else { return }
        permiso = ubicacion.authorizationStatus
        switch permiso {
        case .notDetermined:
            ubicacion.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            guard !pidiendo else { return }
            pidiendo = true
            ubicacion.requestLocation()
        default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let antes = self.permiso
            self.permiso = self.ubicacion.authorizationStatus

            if antes == .notDetermined, self.permiso == .authorizedWhenInUse || self.permiso == .authorizedAlways { self.pedir() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last else { return }

        let lat = (l.coordinate.latitude * 100).rounded() / 100
        let lon = (l.coordinate.longitude * 100).rounded() / 100
        Task { @MainActor in
            self.pidiendo = false
            await self.consultar(latitud: lat, longitud: lon)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.pidiendo = false }
    }

    private func consultar(latitud: Double, longitud: Double) async {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        c?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.2f", latitud)),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", longitud)),
            URLQueryItem(name: "current", value: "weather_code,is_day,precipitation"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = c?.url,
              let (datos, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: datos) as? [String: Any],
              let actual = json["current"] as? [String: Any],
              let codigo = (actual["weather_code"] as? NSNumber)?.intValue,
              let dia = (actual["is_day"] as? NSNumber)?.intValue
        else { return }
        let ahora = Date()
        withAnimation(Diseno.muelleLento) {
            tiempo = Tiempo(wmo: codigo)
            deDia = dia == 1
            actualizado = ahora
        }
        UserDefaults.standard.set(["codigo": codigo, "dia": dia == 1, "fecha": ahora.timeIntervalSince1970], forKey: Self.claveGuardado)
    }
}
