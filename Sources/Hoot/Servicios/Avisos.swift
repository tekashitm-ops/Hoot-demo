import Foundation
import UserNotifications

enum Avisos {
    static func pedirPermiso() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func permitidos() async -> Bool {
        let ajustes = await UNUserNotificationCenter.current().notificationSettings()
        return ajustes.authorizationStatus == .authorized || ajustes.authorizationStatus == .provisional
    }

    private struct Pendiente {
        let id: String
        let fecha: Date
        let titulo: String
        let cuerpo: String
    }

    static func reprogramar(_ almacen: Almacen) async {

        guard !almacen.lecturaPendiente else { return }
        let centro = UNUserNotificationCenter.current()
        let pendientes = await centro.pendingNotificationRequests()
        centro.removePendingNotificationRequests(withIdentifiers: pendientes.map(\.identifier).filter { !$0.hasPrefix("prueba-") })
        let a = almacen.ajustes.avisos
        guard almacen.configurado, a.activados, await permitidos() else { return }

        let ahora = Reloj.ahora
        let cal = calendarioActual
        var lista: [Pendiente] = []

        if almacen.esFamilia {

            if a.resumenFamilia {
                for hijo in almacen.hijos {
                    for ex in hijo.datos.tareas where ex.tipo == .examen && !ex.hecha {
                        guard let antes = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: ex.entrega)) else { continue }
                        let materia = hijo.datos.asignatura(ex.asignaturaID)?.nombre ?? ex.titulo
                        lista.append(Pendiente(
                            id: "familia-examen-\(ex.id)",
                            fecha: DatosEscolares.fecha(antes, minutos: a.horaResumenFamilia),
                            titulo: L("\(hijo.nombre) tiene examen mañana", "\(hijo.nombre) has a test tomorrow", "\(hijo.nombre) ha una verifica domani"),
                            cuerpo: ex.temas.isEmpty ? materia : "\(materia) · \(ex.temas)"
                        ))
                    }
                }
            }
            if a.resumenFamilia, let hijo = almacen.hijoActivo {
                for d in 0..<7 {
                    guard let dia = cal.date(byAdding: .day, value: d, to: cal.startOfDay(for: ahora)) else { continue }
                    let fecha = DatosEscolares.fecha(dia, minutos: a.horaResumenFamilia)
                    let pendientes = hijo.datos.tareas.filter { !$0.hecha && $0.entrega <= cal.date(byAdding: .day, value: 2, to: dia)! }.count
                    lista.append(Pendiente(
                        id: "familia-\(DatosEscolares.clave(dia))", fecha: fecha,
                        titulo: L("Resumen de \(hijo.nombre)", "\(hijo.nombre)'s day", "Riepilogo di \(hijo.nombre)"),
                        cuerpo: pendientes == 0
                            ? L("Todo al día.", "All caught up.", "Tutto in ordine.")
                            : L("\(pendientes) tareas para los próximos días.", "\(pendientes) assignments due soon.", "\(pendientes) compiti per i prossimi giorni.")
                    ))
                }
            }
        } else {
            let datos = almacen.datos

            if a.entregas {

                let porDia = Dictionary(grouping: datos.tareas.filter { !$0.hecha && $0.tipo != .examen }) { cal.startOfDay(for: $0.entrega) }
                for (dia, tareas) in porDia {
                    guard let antes = cal.date(byAdding: .day, value: -1, to: dia) else { continue }
                    let fecha = DatosEscolares.fecha(antes, minutos: a.horaEntregas)
                    let titulo = tareas.count == 1
                        ? L("Para mañana", "Due tomorrow", "Per domani")
                        : L("\(tareas.count) entregas para mañana", "\(tareas.count) assignments due tomorrow", "\(tareas.count) consegne per domani")
                    let cuerpo = tareas.map { t in
                        let m = datos.asignatura(t.asignaturaID)?.nombre
                        return m.map { "\($0): \(t.titulo)" } ?? t.titulo
                    }.joined(separator: "\n")
                    lista.append(Pendiente(id: "entrega-\(DatosEscolares.clave(dia))", fecha: fecha, titulo: titulo, cuerpo: cuerpo))
                }
            }

            if a.examenes {
                for ex in datos.tareas where ex.tipo == .examen && !ex.hecha {
                    let materia = datos.asignatura(ex.asignaturaID)?.nombre ?? ex.titulo
                    for dias in [3, 1] {
                        guard let antes = cal.date(byAdding: .day, value: -dias, to: cal.startOfDay(for: ex.entrega)) else { continue }
                        let fecha = DatosEscolares.fecha(antes, minutos: a.horaEntregas)
                        let titulo = dias == 1
                            ? L("Examen de \(materia) mañana", "\(materia) test tomorrow", "Verifica di \(materia) domani")
                            : L("Examen de \(materia) en 3 días", "\(materia) test in 3 days", "Verifica di \(materia) tra 3 giorni")
                        lista.append(Pendiente(id: "examen-\(ex.id)-\(dias)", fecha: fecha, titulo: titulo, cuerpo: ex.temas.isEmpty ? ex.titulo : ex.temas))
                    }
                }
            }

            if a.cuandoEmpezar {

                let plan = datos.plan(ahora: ahora)
                var porDia: [String: [(Tarea, PlanTarea)]] = [:]
                for t in datos.tareas where !t.hecha && t.tipo != .deberes {
                    guard let p = plan.empezar(t.id), !p.sesiones.isEmpty, t.ratosHechos.isEmpty else { continue }
                    porDia[DatosEscolares.clave(p.empezar), default: []].append((t, p))
                }
                for (clave, cosas) in porDia {
                    guard let (t0, p0) = cosas.first, let s0 = p0.sesiones.first else { continue }
                    let fecha = DatosEscolares.fecha(p0.empezar, minutos: max(s0.hora - 10, 15 * 60))
                    let nombre: (Tarea) -> String = { t in
                        let m = datos.asignatura(t.asignaturaID)?.nombre ?? t.titulo
                        return t.tipo == .examen ? L("Examen de \(m)", "\(m) test", "Verifica di \(m)") : t.titulo
                    }
                    let titulo = cosas.count == 1
                        ? L("Hoy conviene empezar: \(nombre(t0))", "Time to start: \(nombre(t0))", "Oggi conviene iniziare: \(nombre(t0))")
                        : L("Hoy conviene empezar \(cosas.count) cosas", "Time to start \(cosas.count) things", "Oggi conviene iniziare \(cosas.count) cose")
                    let cuerpo = cosas.map { t, p in
                        let cuando = Formato.diaRelativo(t.entrega, desde: p.empezar).lowercased(with: localeActual)
                        let ratos = DatosEscolares.esfuerzo(t)
                        let base = L("\(nombre(t)) (\(cuando)): \(ratos.ratos) ratos de \(ratos.minutos) min", "\(nombre(t)) (\(cuando)): \(ratos.ratos) sessions of \(ratos.minutos) min", "\(nombre(t)) (\(cuando)): \(ratos.ratos) sessioni da \(ratos.minutos) min")
                        return p.justa ? base + L(", va justo", ", it's tight", ", è stretto") : base
                    }.joined(separator: "\n")
                    lista.append(Pendiente(id: "empezar-\(clave)", fecha: fecha, titulo: titulo, cuerpo: cuerpo))
                }
            }

            if a.mochila {
                for d in 0..<8 {
                    guard let dia = cal.date(byAdding: .day, value: d, to: cal.startOfDay(for: ahora)),
                          let siguiente = cal.date(byAdding: .day, value: 1, to: dia),
                          datos.hayClase(siguiente) else { continue }
                    let items = datos.itemsMochila(para: siguiente)
                    let faltan = items.filter { !datos.marcadas(siguiente).contains($0.id) }.count
                    guard faltan > 0 else { continue }
                    lista.append(Pendiente(
                        id: "mochila-\(DatosEscolares.clave(siguiente))",
                        fecha: DatosEscolares.fecha(dia, minutos: a.horaMochila),
                        titulo: L("Prepara la mochila", "Pack your backpack", "Prepara lo zaino"),
                        cuerpo: L("\(faltan) cosas para \(Formato.diaSemana(siguiente)).", "\(faltan) things for \(Formato.diaSemana(siguiente)).", "\(faltan) cose per \(Formato.diaSemana(siguiente)).")
                    ))
                }
            }

            if a.recordatorios {
                for r in datos.recordatorios where !r.hecho {
                    let fecha = r.conHora ? r.fecha : DatosEscolares.fecha(r.fecha, minutos: 8 * 60)
                    lista.append(Pendiente(id: "rec-\(r.id)", fecha: fecha, titulo: r.titulo, cuerpo: r.notas))
                }
            }

            if a.actividades {
                for d in 0..<14 {
                    guard let dia = cal.date(byAdding: .day, value: d, to: cal.startOfDay(for: ahora)) else { continue }
                    for act in datos.actividades(en: dia) {
                        guard let antes = act.aviso else { continue }

                        let inicio = act.inicio ?? 8 * 60
                        let fecha = DatosEscolares.fecha(dia, minutos: inicio).addingTimeInterval(TimeInterval(-antes * 60))
                        var cuerpo = act.inicio.map { Formato.hora($0) } ?? L("Todo el día", "All day", "Tutto il giorno")
                        if !act.lugar.isEmpty { cuerpo += " · \(act.lugar)" }
                        if !act.llevar.isEmpty { cuerpo += "\n" + L("Lleva: ", "Bring: ", "Porta: ") + act.llevar.joined(separator: ", ") }
                        lista.append(Pendiente(id: "act-\(act.id)-\(DatosEscolares.clave(dia))", fecha: fecha, titulo: act.titulo, cuerpo: cuerpo))
                    }
                }
            }
        }

        let futuros = lista.filter { $0.fecha > ahora }.sorted { $0.fecha < $1.fecha }.prefix(60)
        for p in futuros {
            let contenido = UNMutableNotificationContent()
            contenido.title = p.titulo
            contenido.body = p.cuerpo
            contenido.sound = .default
            let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: p.fecha)
            let disparador = UNCalendarNotificationTrigger(dateMatching: c, repeats: false)
            try? await centro.add(UNNotificationRequest(identifier: p.id, content: contenido, trigger: disparador))
        }
    }
}

final class DelegadoAvisos: NSObject, UNUserNotificationCenterDelegate {
    static let compartido = DelegadoAvisos()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
