import SwiftUI

enum PasoConfig: String, Hashable, Codable {
    case region, rol, nombre, nacimiento, correo, contrasena, verificar, iniciarSesion

    case colegio, teams, asignaturas, horario, avisos, familia, vincularHijo, final
    case materiales, calendarios, servicios
}

@Observable
final class FlujoConfig {
    var ruta: [PasoConfig] = []
    var correo = ""
    var contrasena = ""

    var entrando = false

    var alTerminar: ((_ entrando: Bool) -> Void)?
    var repetir = ""

    var elegidas: Set<String> = []

    func orden(_ rol: Rol) -> [PasoConfig] {
        switch rol {
        case .estudiante:
            [.region, .rol, .nombre, .nacimiento, .correo, .contrasena, .verificar, .asignaturas, .materiales, .horario, .avisos, .familia,
             .calendarios, .servicios, .final]
        case .familia:
            [.region, .rol, .nombre, .correo, .contrasena, .verificar, .vincularHijo, .avisos, .final]
        }
    }

    func avanzar(desde paso: PasoConfig?, rol: Rol) {
        let lista = orden(rol)
        guard let paso else {
            ruta.append(lista[0])
            return
        }
        if let i = lista.firstIndex(of: paso), i + 1 < lista.count {
            ruta.append(lista[i + 1])
        }
    }

    func ir(_ paso: PasoConfig) {
        ruta.append(paso)
    }

    func despuesDeLaCuenta(rol: Rol) {
        if let alTerminar {
            alTerminar(false)
            return
        }
        avanzar(desde: .verificar, rol: rol)
    }

    private struct Guardado: Codable {
        var ruta: [PasoConfig]
        var correo: String
    }

    private static let clave = "hoot.configuracion.ruta"

    func guardar() {
        guard let data = try? JSONEncoder().encode(Guardado(ruta: ruta, correo: correo)) else { return }
        UserDefaults.standard.set(data, forKey: Self.clave)
    }

    func retomar() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.clave),
              let g = try? JSONDecoder().decode(Guardado.self, from: data), !g.ruta.isEmpty else { return false }
        correo = g.correo

        ruta = g.ruta.filter { $0 != .teams && $0 != .colegio }
        return true
    }

    static func olvidar() {
        UserDefaults.standard.removeObject(forKey: clave)
    }
}

struct Configuracion: View {
    @Environment(Almacen.self) private var almacen
    @State private var flujo = FlujoConfig()
    @State private var empezado = false

    var body: some View {
        ZStack {
            if empezado {
                NavigationStack(path: $flujo.ruta) {
                    PasoIdioma()
                        .navigationDestination(for: PasoConfig.self) { paso in
                            destino(paso)
                        }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            } else {
                PantallaHola {
                    conMuelle(Diseno.muelleGesto) { empezado = true }
                }
                .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .top).combined(with: .opacity)))
            }
        }
        .environment(flujo)

        .tint(Color.azulConfig)
        .onAppear {
            if let ruta = ModoCapturas.rutaConfiguracion, ModoCapturas.pantalla != "config-hola" {
                empezado = true
                flujo.correo = almacen.perfil.correo
                flujo.ruta = ruta
            } else if !ModoCapturas.activo, flujo.ruta.isEmpty, flujo.retomar() {
                empezado = true
            }
        }
        .onChange(of: flujo.ruta) { _, _ in
            if !ModoCapturas.activo { flujo.guardar() }
        }
    }

    @ViewBuilder
    private func destino(_ paso: PasoConfig) -> some View {
        switch paso {
        case .region: PasoRegion()
        case .rol: PasoRol()
        case .nombre: PasoNombre()
        case .nacimiento: PasoNacimiento()
        case .correo: PasoCorreo()
        case .verificar: PasoVerificar()
        case .contrasena: PasoContrasena()
        case .iniciarSesion: PasoIniciarSesion()
        case .colegio, .teams, .asignaturas: PasoAsignaturas()
        case .materiales: PasoMateriales()
        case .calendarios: PasoCalendarios()
        case .servicios: PasoServicios()
        case .horario: PasoHorario()
        case .avisos: PasoAvisos()
        case .familia: PasoFamiliaEstudiante()
        case .vincularHijo: PasoVincularHijo()
        case .final: PantallaBienvenida()
        }
    }
}
