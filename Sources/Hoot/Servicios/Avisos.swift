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

    static func contarYa(_ avisos: [Aviso], de nombre: String, almacen: Almacen) async {
        guard !avisos.isEmpty, almacen.ajustes.avisos.activados, await permitidos() else { return }
        for a in avisos.prefix(3) {
            let c = UNMutableNotificationContent()
            c.title = nombre
            c.body = a.texto
            c.sound = .default
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "familia-ya-\(a.id)", content: c, trigger: nil))
        }
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
                    for p in hijo.datos.pruebas where !p.privada && p.diasQueFaltan(desde: ahora, cal: cal) >= 1 {
                        guard let antes = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: p.fecha)) else { continue }
                        let materia = hijo.datos.asignatura(p.asignaturaID)?.nombre ?? p.tipo.nombre
                        let llenos = p.llenos(cal: cal)
                        lista.append(Pendiente(
                            id: "familia-examen-\(p.id)",
                            fecha: DatosEscolares.fecha(antes, minutos: a.horaResumenFamilia),
                            titulo: L("\(hijo.nombre) tiene \(materia) mañana", "\(hijo.nombre) has \(materia) tomorrow", "\(hijo.nombre) ha \(materia) domani"),
                            cuerpo: L("\(llenos) de \(p.temas.count) temas en luna llena", "\(llenos) of \(p.temas.count) topics at full moon",
                                      "\(llenos) di \(p.temas.count) argomenti in luna piena")
                        ))
                    }
                }
            }

            if a.recordatorios {
                for hijo in almacen.hijos {
                    for r in hijo.datos.recordatorios where !r.hecho && !r.privada {
                        let fecha = r.conHora ? r.fecha : DatosEscolares.fecha(r.fecha, minutos: 8 * 60)
                        lista.append(Pendiente(id: "familia-rec-\(r.id)", fecha: fecha, titulo: "\(hijo.nombre) · \(r.titulo)", cuerpo: r.notas))
                    }
                }
            }
        } else {
            let datos = almacen.datos

            if a.repasos {
                let plan = datos.planRepaso(ajustes: almacen.ajustes, ahora: ahora, dias: 8)
                for s in plan.sesiones where !s.ligera {
                    let fecha = DatosEscolares.fecha(s.dia, minutos: s.hora)
                    guard fecha > ahora else { continue }
                    if s.simulacro, let p = datos.pruebas.first(where: { $0.id == s.pruebaID }) {
                        let materia = datos.asignatura(p.asignaturaID)?.nombre ?? p.tipo.nombre
                        lista.append(Pendiente(id: "simulacro-\(s.id)", fecha: fecha,
                                               titulo: L("Simulacro de \(materia)", "\(materia) mock test", "Simulazione di \(materia)"),
                                               cuerpo: FrasesHoot.simulacro(semilla: p.temas.count)))
                        continue
                    }
                    let temas = s.temaIDs.compactMap { datos.tema($0)?.nombre }
                    lista.append(Pendiente(id: "repaso-\(s.id)", fecha: fecha,
                                           titulo: L("Repaso · \(temas.joined(separator: ", "))", "Review · \(temas.joined(separator: ", "))",
                                                     "Ripasso · \(temas.joined(separator: ", "))"),
                                           cuerpo: FrasesHoot.avisoRato(minutos: s.minutos)))
                }
            }

            if a.pruebas {
                for p in datos.pruebas where p.diasQueFaltan(desde: ahora, cal: cal) >= 1 {
                    let materia = datos.asignatura(p.asignaturaID)?.nombre ?? p.tipo.nombre
                    let dia = cal.startOfDay(for: p.fecha)
                    if let antes = cal.date(byAdding: .day, value: -1, to: dia) {
                        lista.append(Pendiente(id: "examen-manana-\(p.id)", fecha: DatosEscolares.fecha(antes, minutos: a.horaEntregas),
                                               titulo: L("\(materia) mañana", "\(materia) tomorrow", "\(materia) domani"),
                                               cuerpo: FrasesHoot.avisoPruebaManana(asignatura: materia)))
                    }

                    if let tres = cal.date(byAdding: .day, value: -3, to: dia), let tema = p.temas.first(where: { $0.luna(cal: cal) < .cuarto }) {
                        lista.append(Pendiente(id: "examen-3-\(p.id)", fecha: DatosEscolares.fecha(tres, minutos: a.horaEntregas),
                                               titulo: L("\(materia) en 3 días", "\(materia) in 3 days", "\(materia) tra 3 giorni"),
                                               cuerpo: FrasesHoot.avisoSinEstudiar(tema: tema.nombre)))
                    }
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
