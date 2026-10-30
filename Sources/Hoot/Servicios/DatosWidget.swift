import ActivityKit
import Foundation
import WidgetKit

enum DatosWidget {
    private static var ultima: InstantaneaWidget?

    static func actualizar(_ almacen: Almacen) {
        guard !almacen.esFamilia, !ModoCapturas.activo else { return }
        let i = instantanea(almacen)
        guard i != ultima else { return }
        ultima = i
        i.guardar()
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func instantanea(_ almacen: Almacen, ahora: Date = Reloj.ahora) -> InstantaneaWidget {
        let datos = almacen.datos
        let cal = calendarioActual
        let proxima = datos.pruebas.filter { $0.diasQueFaltan(desde: ahora, cal: cal) >= 0 }.min { $0.fecha < $1.fecha }
        let prueba = proxima.map { p in
            let a = datos.asignatura(p.asignaturaID)
            return InstantaneaWidget.PruebaW(id: p.id, asignatura: a?.nombre ?? p.tipo.nombre, simbolo: a?.simbolo ?? "moonphase.first.quarter",
                                             tipo: p.tipo.nombre, dia: p.fecha, lunas: p.temas.map { $0.luna(cal: cal).fraccion })
        }
        let plan = datos.planRepaso(ajustes: almacen.ajustes, ahora: ahora)
        let hoy = plan.sesiones(en: ahora, cal: cal)
        var repaso: InstantaneaWidget.RepasoW?
        if let primera = hoy.first {
            let ids = hoy.flatMap(\.temaIDs).reduce(into: [UUID]()) { if !$0.contains($1) { $0.append($1) } }
            repaso = InstantaneaWidget.RepasoW(hora: primera.hora, minutos: hoy.reduce(0) { $0 + $1.minutos },
                                               temas: ids.compactMap { datos.tema($0) }.map { .init(nombre: $0.nombre, luna: $0.luna(cal: cal).fraccion) },
                                               simulacro: hoy.contains(where: \.simulacro))
        }
        return InstantaneaWidget(prueba: prueba, repaso: repaso, idioma: idiomaActual.rawValue)
    }
}

@MainActor
final class ActividadEnDirecto {
    static let compartida = ActividadEnDirecto()
    private var actividad: Activity<ActividadRepaso>?

    func empezar(titulo: String, simulacro: Bool, total: Int, luna: Double, fin: Date?) {
        guard !ModoCapturas.activo, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        terminar()
        let atributos = ActividadRepaso(titulo: titulo, simulacro: simulacro, idioma: idiomaActual.rawValue)
        let estado = ActividadRepaso.ContentState(pregunta: 1, total: max(total, 1), luna: luna, fin: fin)
        actividad = try? Activity.request(attributes: atributos, content: .init(state: estado, staleDate: nil))
    }

    func actualizar(pregunta: Int, total: Int, luna: Double, fin: Date?) {
        guard let a = actividad else { return }
        let estado = ActividadRepaso.ContentState(pregunta: pregunta, total: max(total, 1), luna: luna, fin: fin)
        let caja = CajaActividad(a: a)
        Task.detached { await caja.a.update(.init(state: estado, staleDate: nil)) }
    }

    func terminar() {
        guard let a = actividad else { return }
        actividad = nil
        let caja = CajaActividad(a: a)
        Task.detached { await caja.a.end(nil, dismissalPolicy: .immediate) }
    }
}

nonisolated private struct CajaActividad: @unchecked Sendable {
    let a: Activity<ActividadRepaso>
}
