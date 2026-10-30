import SwiftUI
import UserNotifications

@main
struct HootApp: App {
    @State private var almacen: Almacen

    init() {
        UNUserNotificationCenter.current().delegate = DelegadoAvisos.compartido

        Desarrollo.compartido.cargarHora()
        let almacen = Almacen()

        ModoCapturas.preparar(almacen)

        Sincronizacion.compartida.conectar(almacen)

        Registro.compartido.empezar()
        _almacen = State(initialValue: almacen)
    }

    var body: some Scene {
        WindowGroup {
            Raiz()
                .environment(almacen)
        }
    }
}
