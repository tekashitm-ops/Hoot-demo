import SwiftUI
import UserNotifications
import AVFoundation
import Photos
import Speech
import LocalAuthentication
import CoreLocation

struct AjusteDesarrollador: View {
    @Environment(Almacen.self) private var almacen
    @State private var desarrollo = Desarrollo.compartido
    @State private var pagina: PaginaDesarrollo? = ModoCapturas.paginaDesarrollo

    var body: some View {
        Form {
            SeccionRevision()

            Section {
                TimelineView(.everyMinute) { _ in
                    LabeledContent(L("Hora de la app", "App time", "Ora dell'app"), value: Self.texto(Reloj.ahora))
                }
                LabeledContent(L("Cuenta", "Account", "Account"),
                               value: almacen.esFamilia ? L("Familia", "Family", "Famiglia") : L("Estudiante", "Student", "Studente"))
            } footer: {
                if desarrollo.horaSimulada {
                    Text(L("Hora simulada: al cerrar Cuenta, la app se pone en ella.", "Simulated time: when you close Account, the app switches to it.", "Ora simulata: chiudendo Account, l'app passa a quell'ora."))
                }
            }

            Section {
                Button { desarrollo.volverAConfiguracion(almacen) } label: {
                    FilaAjuste(simbolo: "arrow.counterclockwise", color: .azul,
                               titulo: L("Volver a configuración", "Back to Setup", "Torna alla configurazione"))
                }
                .revisable("principal.configuracion", L("Volver a configuración", "Back to Setup", "Torna alla configurazione"))
                Button { desarrollo.cambiarCuenta(almacen) } label: {
                    FilaAjuste(simbolo: "person.2.fill", color: .verde,
                               titulo: almacen.esFamilia ? L("Cambiar a cuenta de estudiante", "Switch to Student Account", "Passa all'account studente")
                                                         : L("Cambiar a cuenta de familia", "Switch to Family Account", "Passa all'account famiglia"))
                }
                .revisable("principal.cuenta", L("Cambiar de cuenta (estudiante o familia)", "Switch account (student or family)", "Cambia account (studente o famiglia)"))
                Button { almacen.bloqueado = true } label: {
                    FilaAjuste(simbolo: "faceid", color: .gris, titulo: L("Bloquear con Face ID", "Lock with Face ID", "Blocca con Face ID"))
                }
                .revisable("principal.faceid", L("Bloquear con Face ID", "Lock with Face ID", "Blocca con Face ID"))
            } footer: {
                Text(L("Al salir de la configuración, todo vuelve a como estaba.", "When you exit setup, everything goes back to how it was.", "Uscendo dalla configurazione, tutto torna com'era."))
            }

            if !almacen.esFamilia {
                SeccionNovedades()
            }

            Section {
                ForEach(PaginaDesarrollo.allCases) { p in
                    NavigationLink { p.vista } label: {
                        FilaAjuste(simbolo: p.simbolo, color: p.color, titulo: p.titulo, valor: p.valor(almacen, desarrollo))
                    }
                }
            }
        }
        .navigationTitle(AjusteCuenta.desarrollador.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $pagina) { p in p.vista }
    }

    static func texto(_ f: Date) -> String {
        "\(Formato.diaSemana(f).conMayuscula), \(Formato.diaMes(f)) · \(Formato.hora(f))"
    }
}

private struct SeccionNovedades: View {
    @Environment(Almacen.self) private var almacen
    @State private var desarrollo = Desarrollo.compartido
    @State private var celebrando = false

    var body: some View {
        Section {
            ir(.hoy, "nuevo.cieloTemas", L("1.3 · Inicio: tus temas como constelaciones de lunas (mantén una: repasar o borrar)",
                                           "1.3 · Home: your topics as moon constellations (hold one: review or delete)",
                                           "1.3 · Inizio: i tuoi argomenti come costellazioni di lune (tienine premuta una: ripassa o elimina)"),
               "moon.stars.fill", .amarillo)
            ir(.hoy, "nuevo.apuntarTema", L("1.3 · «Tema»: apuntar lo que habéis dado, con su asignatura y todas las fotos",
                                            "1.3 · “Topic”: add what you covered, with its subject and all the photos",
                                            "1.3 · «Argomento»: segna quello che avete fatto, con materia e tutte le foto"),
               "plus.viewfinder", .naranja)
            ir(.hoy, "nuevo.repasito", L("1.3 · «Repasito» de 5 minutos y «Seguir» (sin obligar: Hoot solo propone)",
                                         "1.3 · 5-minute “Quick review” and “Continue” (nothing forced: Hoot only suggests)",
                                         "1.3 · «Ripassino» di 5 minuti e «Continua» (senza obblighi: Hoot propone e basta)"),
               "bolt.fill", .indigo)
            ir(.pruebas, "nuevo.buscarTemas", L("1.3 · Pruebas: buscar un tema y las asignaturas con sus temas (deslizar para borrar)",
                                                "1.3 · Tests: search a topic and subjects with their topics (swipe to delete)",
                                                "1.3 · Verifiche: cerca un argomento e le materie con i loro argomenti (scorri per eliminare)"),
               "magnifyingglass", .azul)
            ir(.pruebas, "nuevo.examen", L("1.3 · «Hazme un examen»: escrito, oral o tarjetas, con los temas que elijas",
                                           "1.3 · “Quiz Me”: written, oral or cards, with the topics you pick",
                                           "1.3 · «Fammi un compito»: scritto, orale o schede, con gli argomenti che scegli"),
               "sparkles", .morado)
            ir(.pruebas, "nuevo.adjuntarTemas", L("1.3 · Al apuntar una prueba, adjuntarle temas que ya tienes",
                                                  "1.3 · When adding a test, attach topics you already have",
                                                  "1.3 · Aggiungendo una verifica, allegare argomenti che hai già"),
               "link", .verde)
            Button {
                desarrollo.cerrarCuentaY(almacen) {
                    almacen.pestana = .hoy
                    almacen.mostrandoCalendario = true
                }
            } label: {
                FilaAjuste(simbolo: "point.topleft.down.to.point.bottomright.curvepath.fill", color: .rojo, titulo: Self.camino)
            }
            .revisable("nuevo.camino", Self.camino)
            Button {
                desarrollo.cerrarCuentaY(almacen) {
                    almacen.pestana = .estudio
                    Salas.compartidas.codigoPendiente = ""
                    Salas.compartidas.entrando = true
                }
            } label: {
                FilaAjuste(simbolo: "person.2.fill", color: .azul, titulo: Self.salas)
            }
            .revisable("nuevo.salas", Self.salas)
            Button {
                desarrollo.cerrarCuentaY(almacen) { Salas.compartidas.abierta = SalaEnVivo.ejemplo(conLlamada: false).local() }
            } label: {
                FilaAjuste(simbolo: "rectangle.on.rectangle.angled", color: .indigo, titulo: Self.salaEjemplo)
            }
            .revisable("nuevo.salaEjemplo", Self.salaEjemplo)
            ir(.pruebas, "nuevo.retoDistancia", L("1.2 · Retos a distancia: en una prueba, «…» › «Retar a un amigo» (en su casa o cuando pueda)",
                                                  "1.2 · Remote challenges: in a test, “…” › “Challenge a Friend” (at home or whenever)",
                                                  "1.2 · Sfide a distanza: in una verifica, «…» › «Sfida un amico» (a casa o quando può)"),
               "person.2.wave.2.fill", .verde)
            ir(.pruebas, "nuevo.material", L("1.1 · El material de un tema: PDF, diapositivas, texto pegado y fotos (toca un tema)",
                                             "1.1 · A topic's material: PDF, slides, pasted text and photos (tap a topic)",
                                             "1.1 · Il materiale di un argomento: PDF, diapositive, testo incollato e foto (tocca un argomento)"),
               "doc.richtext", .rojo)
            ir(.estudio, "nuevo.charla", L("1.1 · Pregúntale a Hoot: en cada tema, en Estudio y con «¿Por qué?» al fallar; también hablando",
                                           "1.1 · Ask Hoot: in each topic, in Study and with “Why?” when you miss; also by voice",
                                           "1.1 · Chiedi a Hoot: in ogni argomento, in Studio e con «Perché?» quando sbagli; anche a voce"),
               "bubble.left.and.text.bubble.right.fill", .azul)
            ir(.pruebas, "nuevo.escuchalo", L("1.1 · Escúchalo: el resumen y preguntas con pausa, con la pantalla bloqueada (en un tema)",
                                              "1.1 · Listen: the summary and questions with a pause, even when locked (in a topic)",
                                              "1.1 · Ascoltalo: il riassunto e domande con pausa, anche a schermo bloccato (in un argomento)"),
               "headphones", .morado)
            NavigationLink { PaginaSituaciones() } label: {
                FilaAjuste(simbolo: "checklist", color: .amarillo, titulo: Self.simulacro)
            }
            .revisable("nuevo.simulacro", Self.simulacro)
            ir(.pruebas, "nuevo.clase", L("1.1 · Estudiar con la clase: pasar un tema (en su hoja) y retar a un amigo (en una prueba, «…»)",
                                          "1.1 · Study with your class: send a topic (from its sheet) and challenge a friend (in a test, “…”)",
                                          "1.1 · Studiare con la classe: passare un argomento (dal suo foglio) e sfidare un amico (in una verifica, «…»)"),
               "person.2.wave.2.fill", .verde)
            NavigationLink { PaginaDesarrollo.widgets.vista } label: {
                FilaAjuste(simbolo: "square.grid.2x2.fill", color: .azul, titulo: Self.widgets)
            }
            .revisable("nuevo.widgets", Self.widgets)
            ir(.pruebas, "nuevo.fallado", L("1.1 · Repasar lo fallado y «¿Qué tema te costó más?» tras una prueba",
                                            "1.1 · Review what you missed and “Which topic was hardest?” after a test",
                                            "1.1 · Ripassare gli errori e «Quale argomento è stato più difficile?» dopo una verifica"),
               "arrow.uturn.backward.circle.fill", .rojo)
            NavigationLink { AjusteFamilia() } label: {
                FilaAjuste(simbolo: "figure.and.child.holdinghands", color: .naranja, titulo: Self.familia)
            }
            .revisable("nuevo.familia", Self.familia)
            ir(.pruebas, "nuevo.pruebas", L("Pruebas: las lunas de cada tema, temas de ahora y las que ya pasaron",
                                            "Tests: each topic's moon, current topics and past tests",
                                            "Verifiche: la luna di ogni argomento, argomenti di adesso e quelle passate"),
               "moonphase.first.quarter", .amarillo)
            ir(.pruebas, "nuevo.apuntar", L("Apuntar una prueba: foto del diario, dictarla o a mano (con «+»)",
                                            "Add a test: planner photo, dictate or type (with “+”)",
                                            "Aggiungere una verifica: foto del diario, dettarla o a mano (con «+»)"),
               "camera.fill", .naranja)
            ir(.pruebas, "nuevo.repaso", L("Evalúame por temas: «¿cuánto de seguro estás?», la luna crece y aúlla al llenarse",
                                           "Quiz by topic: “how sure are you?”, the moon grows and howls when full",
                                           "Interrogami per argomenti: «quanto sei sicuro?», la luna cresce e ulula quando è piena"),
               "sparkles", .indigo)
            Button { celebrando = true } label: {
                FilaAjuste(simbolo: "moon.fill", color: .amarillo, titulo: Self.lunaLlena)
            }
            .revisable("nuevo.lunaLlena", Self.lunaLlena)

            .fullScreenCover(isPresented: $celebrando) {
                NocheDeLunaLlena(asignatura: L("Historia", "History", "Storia"),
                                 temas: [L("Roma", "Rome", "Roma"), L("Cartago", "Carthage", "Cartagine"), L("Augusto", "Augustus", "Augusto")],
                                 dia: L("el jueves", "on Thursday", "giovedì")) { celebrando = false }
            }
            NavigationLink { TuCielo() } label: {
                FilaAjuste(simbolo: "star.fill", color: .indigo, titulo: Self.cielo)
            }
            .revisable("nuevo.tuCielo", Self.cielo)
            ir(.hoy, "nuevo.hoy", L("Hoy nuevo: cambia con la hora; el calendario, en el botón redondo",
                                    "New Today: changes with the time; the calendar, in the round button",
                                    "Oggi nuovo: cambia con l'ora; il calendario, nel pulsante tondo"),
               "house.fill", .azul)
            ir(.tareas, "nuevo.sinDeberes", L("Agenda y calendario sin deberes: ratos de repaso y pruebas",
                                              "Planner and calendar without homework: review sessions and tests",
                                              "Diario e calendario senza compiti: ripassi e verifiche"),
               "list.bullet.clipboard.fill", .verde)
            NavigationLink { AjusteEstudio() } label: {
                FilaAjuste(simbolo: "figure.and.child.holdinghands", color: .naranja, titulo: Self.permiso)
            }
            .revisable("nuevo.permisoIA", Self.permiso)
            NavigationLink { AjusteNotas() } label: {
                FilaAjuste(simbolo: "calendar.badge.clock", color: .rojo, titulo: Self.vacaciones)
            }
            .revisable("nuevo.vacaciones", Self.vacaciones)
            Button { desarrollo.volverAConfiguracion(almacen) } label: {
                FilaAjuste(simbolo: "arrow.counterclockwise", color: .azul, titulo: Self.configuracion)
            }
            .revisable("nuevo.configPermiso", Self.configuracion)
        } header: {
            Text(L("Lo nuevo", "What's New", "Novità"))
        } footer: {
            Text(L("Cada una te lleva a su sitio: pruébala y vuelve a marcarla.",
                   "Each one takes you there: try it and come back to mark it.",
                   "Ognuna ti porta lì: provala e torna a segnarla."))
        }
    }

    private static var camino: String { L("1.3 · El calendario nuevo, «el camino»: las pruebas que vienen y cuándo repasar", "1.3 · The new calendar, “the path”: tests coming up and when to review", "1.3 · Il nuovo calendario, «il cammino»: le verifiche in arrivo e quando ripassare") }
    private static var salas: String { L("1.2 · Estudiar con un amigo: crear una sala con código, entrar, invitar y el permiso de la familia", "1.2 · Study with a friend: create a room with a code, join, invite and family permission", "1.2 · Studiare con un amico: crea una stanza con codice, entra, invita e il permesso della famiglia") }
    private static var salaEjemplo: String { L("1.2 · La sala de ejemplo (sin red): pizarra con las herramientas de Notas, apuntes, chat y llamada", "1.2 · The sample room (offline): board with Notes tools, notes, chat and call", "1.2 · La stanza di esempio (offline): lavagna con gli strumenti di Note, appunti, chat e chiamata") }
    private static var simulacro: String { L("1.1 · El simulacro: dos días antes en el plan (prueba «Simulacro hoy» en Situaciones) o desde una prueba", "1.1 · The mock test: two days before in the plan (try “Mock test today” in Situations) or from a test", "1.1 · La simulazione: due giorni prima nel piano (prova «Simulazione oggi» in Situazioni) o da una verifica") }
    private static var widgets: String { L("1.1 · Widgets, pantalla de bloqueo e Isla dinámica (cómo se ven y cómo añadirlos)", "1.1 · Widgets, Lock Screen and Dynamic Island (how they look and how to add them)", "1.1 · Widget, schermata di blocco e Dynamic Island (come appaiono e come aggiungerli)") }
    private static var familia: String { L("1.1 · La familia de verdad: pide verte con tu código y tú lo aceptas (hace falta cuenta en los dos iPhone)", "1.1 · Real family: they ask with your code and you accept (both iPhones need an account)", "1.1 · La famiglia vera: chiede con il tuo codice e tu accetti (serve un account su entrambi gli iPhone)") }
    private static var lunaLlena: String { L("La noche de luna llena (con el aullido: sube el volumen)", "The full-moon night (with the howl: turn up the volume)", "La notte di luna piena (con l'ululato: alza il volume)") }
    private static var cielo: String { L("Tu cielo: una estrella por cada tema que sabes", "Your sky: a star for every topic you know", "Il tuo cielo: una stella per ogni argomento che sai") }
    private static var permiso: String { L("Ayuda de estudio: minutos de cada rato y permiso de la familia para la IA", "Study Help: session length and family AI permission", "Aiuto allo studio: durata e permesso della famiglia per l'IA") }
    private static var vacaciones: String { L("Curso escolar: las vacaciones (sin repasos ni mochila)", "School Year: holidays (no reviews or backpack)", "Anno scolastico: le vacanze (senza ripassi né zaino)") }
    private static var configuracion: String { L("La configuración: el permiso para la IA (menos de 14) y la primera prueba al final", "Setup: AI permission (under 14) and the first test at the end", "La configurazione: il permesso per l'IA (meno di 14) e la prima verifica alla fine") }

    private func ir(_ pestana: Pestana, _ id: String, _ titulo: String, _ simbolo: String, _ color: ColorHoot) -> some View {
        Button {
            desarrollo.cerrarCuentaY(almacen) { almacen.pestana = pestana }
        } label: {
            FilaAjuste(simbolo: simbolo, color: color, titulo: titulo)
        }
        .revisable(id, titulo)
    }
}

private struct PaginaConexiones: View {
    @Environment(Almacen.self) private var almacen
    @State private var d = Desarrollo.compartido
    @State private var calendarios = Calendarios.compartido

    static var sinRepetir: String {
        L("Sin repetir: la reunión con la tutora (calendario del colegio y Teams) sale una vez",
          "No repeats: the tutor meeting (school calendar and Teams) shows once",
          "Senza ripetizioni: il colloquio (calendario della scuola e Teams) compare una volta")
    }

    var body: some View {
        @Bindable var d = d
        Form {
            Section {
                Toggle(L("Calendarios de ejemplo", "Sample calendars", "Calendari di esempio"), isOn: $d.calendariosDeEjemplo)
                    .revisable("conexiones.ejemplo", L("Calendarios de ejemplo", "Sample calendars", "Calendari di esempio"), en: .conexiones)
                NavigationLink { AjusteCalendarios() } label: {
                    FilaAjuste(simbolo: "calendar", color: .rojo, titulo: AjusteCuenta.calendarios.titulo,
                               valor: calendarios.permiso == .concedido ? "\(calendarios.cuentas.count)" : L("Sin permiso", "No access", "Senza permesso"))
                }
                .revisable("conexiones.calendarios", L("Calendarios: cuentas, «Del colegio», ocultar uno y los pasos", "Calendars: accounts, “School”, hiding one and the steps", "Calendari: account, «Della scuola», nasconderne uno e i passi"), en: .conexiones)
                LabeledContent(L("Citas leídas", "Events read", "Appuntamenti letti"), value: "\(calendarios.eventosIPhone.count)")
            } footer: {
                Text(L("Con los de ejemplo: una cuenta del colegio, iCloud, Google y los cumpleaños, con citas esta semana. Apagado: los de tu iPhone.",
                       "With the samples: a school account, iCloud, Google and birthdays, with events this week. Off: your iPhone's.",
                       "Con quelli di esempio: un account della scuola, iCloud, Google e i compleanni, con appuntamenti questa settimana. Spento: quelli del tuo iPhone."))
            }

            Section {
                Picker(L("Vincular Teams", "Link Teams", "Collega Teams"), selection: $d.teamsSimulado) {
                    Text(L("De verdad (Microsoft)", "For real (Microsoft)", "Davvero (Microsoft)")).tag(Desarrollo.SimulacionTeams?.none)
                    Text(L("El colegio lo deja", "School allows it", "La scuola lo permette")).tag(Desarrollo.SimulacionTeams?.some(.permitido))
                    Text(L("El colegio lo bloquea", "School blocks it", "La scuola lo blocca")).tag(Desarrollo.SimulacionTeams?.some(.bloqueado))
                }
                .revisable("conexiones.simulacion", L("Vincular Teams de prueba (lo deja o lo bloquea)", "Test Teams linking (allowed or blocked)", "Collegamento di prova a Teams (permesso o bloccato)"), en: .conexiones)
                NavigationLink { AjusteTeams() } label: {
                    FilaAjuste(simbolo: AjusteCuenta.teams.simbolo, color: AjusteCuenta.teams.color, titulo: AjusteCuenta.teams.titulo, valor: PaginaInformacion.texto(almacen.teams.estado))
                }
                .revisable("conexiones.teams", L("Teams: los pasos, «Comprobando…» y lo que sale", "Teams: the steps, “Checking…” and the result", "Teams: i passi, «Controllo…» e il risultato"), en: .conexiones)
            } footer: {
                if !Teams.disponible {
                    Text(L("Hoot aún no está registrada en Microsoft: «De verdad» dice que falta registrarla.",
                           "Hoot isn't registered with Microsoft yet: “For real” says so.",
                           "Hoot non è ancora registrata su Microsoft: «Davvero» dice che manca la registrazione."))
                }
            }

            Section {
                Button { Self.probarSinRepetir(almacen) } label: {
                    FilaAjuste(simbolo: "square.on.square", color: .verde, titulo: Self.sinRepetir)
                }
                .revisable("conexiones.sinRepetir", Self.sinRepetir, en: .conexiones)
            } footer: {
                Text(L("Pone los calendarios de ejemplo y Teams de prueba y te lleva al Calendario: mañana a las 17:00, una sola reunión.",
                       "Turns on the sample calendars and test Teams and takes you to Calendar: tomorrow at 17:00, a single meeting.",
                       "Attiva i calendari di esempio e Teams di prova e ti porta al Calendario: domani alle 17:00, un solo colloquio."))
            }
        }
        .navigationTitle(PaginaDesarrollo.conexiones.titulo)
        .navigationBarTitleDisplayMode(.inline)
    }

    static func probarSinRepetir(_ almacen: Almacen) {
        let d = Desarrollo.compartido
        d.calendariosDeEjemplo = true
        almacen.teams.estado = .prueba
        almacen.teams.cuentaColegio = "lucia.garcia@iesejemplo.edu"
        Task { await ConexionTeams.compartida.actualizar(almacen) }
        d.cerrarCuentaY(almacen) { almacen.pestana = .calendario }
    }
}

enum PaginaDesarrollo: String, CaseIterable, Identifiable, Hashable {
    case hora, situaciones, avisos, familia, conexiones, tiempo, pantalla, estudio, lobo, widgets, datos, informacion

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .hora: L("Hora y fecha", "Date & Time", "Data e ora")
        case .situaciones: L("Situaciones", "Situations", "Situazioni")
        case .avisos: L("Avisos", "Notifications", "Notifiche")
        case .familia: L("Familia y control parental", "Family & Parental Controls", "Famiglia e controllo parentale")
        case .conexiones: L("Calendarios y Teams", "Calendars & Teams", "Calendari e Teams")
        case .tiempo: L("Tiempo del fondo", "Background Weather", "Meteo dello sfondo")
        case .pantalla: L("Letra y apariencia", "Text & Appearance", "Testo e aspetto")
        case .estudio: L("Apple Intelligence y estudio", "Apple Intelligence & Study", "Apple Intelligence e studio")
        case .lobo: L("El lobo", "The Wolf", "Il lupo")
        case .widgets: L("Widgets e Isla dinámica", "Widgets & Dynamic Island", "Widget e Dynamic Island")
        case .datos: L("Datos y copias", "Data & Copies", "Dati e copie")
        case .informacion: L("Información", "Information", "Informazioni")
        }
    }

    var simbolo: String {
        switch self {
        case .hora: "clock.fill"
        case .situaciones: "theatermasks.fill"
        case .avisos: "bell.badge.fill"
        case .familia: "figure.and.child.holdinghands"
        case .conexiones: "calendar"
        case .tiempo: "cloud.sun.rain.fill"
        case .pantalla: "textformat.size"
        case .estudio: "sparkles"
        case .lobo: "pawprint.fill"
        case .widgets: "square.grid.2x2.fill"
        case .datos: "externaldrive.fill"
        case .informacion: "info.circle.fill"
        }
    }

    var color: ColorHoot {
        switch self {
        case .hora: .azul
        case .situaciones: .morado
        case .avisos: .rojo
        case .familia: .verde
        case .conexiones: .rojo
        case .tiempo: .turquesa
        case .pantalla: .azul
        case .estudio: .indigo
        case .lobo: .gris
        case .widgets: .azul
        case .datos: .marron
        case .informacion: .gris
        }
    }

    func valor(_ almacen: Almacen, _ d: Desarrollo) -> String? {
        switch self {
        case .hora: d.horaSimulada ? (d.parada != nil ? L("Parada", "Stopped", "Ferma") : L("Simulada", "Simulated", "Simulata")) : nil
        case .tiempo: d.tiempoForzado?.nombre
        case .pantalla: d.letraForzada != nil || d.aparienciaForzada != nil || d.negrita ? L("Forzada", "Forced", "Forzata") : nil
        case .estudio: d.iaForzada.map(Self.nombreIA)
        case .lobo: d.gestoForzado?.nombre
        case .datos: d.fecha(.datos) != nil ? L("Copia", "Copy", "Copia") : nil
        default: nil
        }
    }

    static func nombreIA(_ c: DisponibilidadIA) -> String {
        switch c {
        case .lista: L("Lista", "Ready", "Pronta")
        case .noCompatible: L("No compatible", "Not supported", "Non compatibile")
        case .desactivada: L("Desactivada", "Turned off", "Disattivata")
        case .preparando: L("Preparándose", "Getting ready", "In preparazione")
        case .idiomaNoDisponible: L("Sin el idioma", "Language unavailable", "Lingua non disponibile")
        case .sinPermiso: L("Sin permiso de la familia", "No parental permission", "Senza permesso della famiglia")
        }
    }

    @ViewBuilder
    var vista: some View {
        switch self {
        case .hora: PaginaHora()
        case .situaciones: PaginaSituaciones()
        case .avisos: PaginaAvisos()
        case .familia: PaginaFamilia()
        case .conexiones: PaginaConexiones()
        case .tiempo: PaginaTiempo()
        case .pantalla: PaginaPantalla()
        case .estudio: PaginaEstudio()
        case .lobo: PaginaLobo()
        case .widgets: PaginaWidgets()
        case .datos: PaginaDatos()
        case .informacion: PaginaInformacion()
        }
    }
}

private struct PaginaHora: View {
    @Environment(Almacen.self) private var almacen
    @State private var d = Desarrollo.compartido
    @State private var fecha = Reloj.ahora
    @State private var simulada = Desarrollo.compartido.horaSimulada
    @State private var parada = Desarrollo.compartido.parada != nil

    var body: some View {
        Form {
            Section {
                Toggle(L("Hora simulada", "Simulated Time", "Ora simulata"), isOn: $simulada)
                    .revisable("hora.simulada", L("Hora simulada", "Simulated Time", "Ora simulata"), en: .hora)
                if simulada {
                    DatePicker(L("Día y hora", "Date & Time", "Giorno e ora"), selection: $fecha)
                        .revisable("hora.fecha", L("Día y hora a mano", "Date & time by hand", "Giorno e ora a mano"), en: .hora)
                    Toggle(L("Reloj parado", "Clock Stopped", "Orologio fermo"), isOn: $parada)
                        .revisable("hora.parada", L("Reloj parado", "Clock Stopped", "Orologio fermo"), en: .hora)
                }
            } footer: {
                Text(simulada
                     ? L("Al cerrar Cuenta, la app se pone en esta hora.", "When you close Account, the app switches to this time.", "Chiudendo Account, l'app passa a quest'ora.")
                     : L("La app va con la hora de verdad.", "The app follows the real time.", "L'app segue l'ora vera."))
            }
            .onChange(of: simulada) { _, si in
                if si { d.ponerHora(fecha, parada: parada) } else { d.horaDeVerdad(); fecha = Date() }
            }
            .onChange(of: fecha) { _, f in if simulada { d.ponerHora(f, parada: parada) } }
            .onChange(of: parada) { _, p in if simulada { d.ponerHora(fecha, parada: p) } }

            Section(L("Ir a…", "Go to…", "Vai a…")) {
                ForEach(momentos, id: \.clave) { m in
                    Button { ir(m.fecha) } label: {
                        LabeledContent {
                            Text("\(Formato.diaSemanaCorto(m.fecha)) \(Formato.hora(m.fecha))").monospacedDigit()
                        } label: {
                            Text(m.nombre).foregroundStyle(Color.primary)
                        }
                    }
                    .revisable("hora.\(m.clave)", m.nombre, en: .hora)
                }
            }

            Section {
                Button(L("Una hora más", "One Hour Later", "Un'ora dopo")) { mover(3600) }
                    .revisable("hora.masHora", L("Una hora más", "One Hour Later", "Un'ora dopo"), en: .hora)
                Button(L("Un día más", "One Day Later", "Un giorno dopo")) { mover(86400) }
                    .revisable("hora.masDia", L("Un día más", "One Day Later", "Un giorno dopo"), en: .hora)
                Button(L("Un día menos", "One Day Earlier", "Un giorno prima")) { mover(-86400) }
                    .revisable("hora.menosDia", L("Un día menos", "One Day Earlier", "Un giorno prima"), en: .hora)
            }

            Section {
                Button(L("Volver a la hora de verdad", "Back to Real Time", "Torna all'ora vera")) {
                    simulada = false
                }
                .disabled(!simulada)
                .revisable("hora.real", L("Volver a la hora de verdad", "Back to Real Time", "Torna all'ora vera"), en: .hora)
            } footer: {
                Text(L("Los avisos se programan para las fechas de la hora simulada: para verlos ya, lánzalos desde Avisos.",
                       "Notifications are scheduled for the simulated dates: to see them now, send them from Notifications.",
                       "Le notifiche si programmano per le date simulate: per vederle subito, inviale da Notifiche."))
            }
        }
        .navigationTitle(PaginaDesarrollo.hora.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: fecha)
    }

    static let claves = ["antes", "clase", "recreo", "salida", "tarde", "mochila", "noche", "madrugada", "sabado", "domingo"]

    private var momentos: [(clave: String, nombre: String, fecha: Date)] {
        let dat = almacen.datosActivos
        let franjas = dat.franjas.filter { !$0.esRecreo }
        let recreo = dat.franjas.first { $0.esRecreo }
        let clase = franjas.count > 1 ? franjas[1].inicio + 15 : 10 * 60
        let salida = (franjas.last?.fin ?? 14 * 60 + 30) + 10
        let mochila = almacen.ajustes.avisos.horaMochila
        func m(_ minutos: Int, clase: Bool = true) -> Date {
            Desarrollo.momento(dat, hora: minutos / 60, minuto: minutos % 60, conClase: clase)
        }
        return [
            ("antes", L("Antes de clase", "Before school", "Prima della scuola"), m(7 * 60 + 45)),
            ("clase", L("En clase", "In class", "In classe"), m(clase)),
            ("recreo", L("En el recreo", "At break", "All'intervallo"), m((recreo?.inicio ?? 11 * 60 + 15) + 5)),
            ("salida", L("Al salir del colegio", "After school", "All'uscita"), m(salida)),
            ("tarde", L("Por la tarde", "In the afternoon", "Nel pomeriggio"), m(17 * 60 + 10)),
            ("mochila", L("Hora de la mochila", "Backpack time", "Ora dello zaino"), m(mochila)),
            ("noche", L("Por la noche", "At night", "Di sera"), m(22 * 60 + 30)),
            ("madrugada", L("De madrugada", "Middle of the night", "Nel cuore della notte"), m(3 * 60, clase: false)),
            ("sabado", L("Sábado por la mañana", "Saturday morning", "Sabato mattina"), Desarrollo.proximo(diaISO: 6, hora: 11, minuto: 0)),
            ("domingo", L("Domingo por la noche", "Sunday night", "Domenica sera"), Desarrollo.proximo(diaISO: 7, hora: 21, minuto: 0)),
        ]
    }

    private func ir(_ f: Date) {
        simulada = true
        fecha = f
        d.ponerHora(f, parada: parada)
    }

    private func mover(_ s: TimeInterval) {
        ir((simulada ? Reloj.ahora : Date()).addingTimeInterval(s))
    }
}

private struct PaginaSituaciones: View {
    @Environment(Almacen.self) private var almacen
    @State private var d = Desarrollo.compartido
    @State private var ultima: Situacion?

    var body: some View {
        let lista = Situacion.allCases.filter { $0.deFamilia == almacen.esFamilia }
        Form {
            Section {
                ForEach(lista) { s in
                    Button { aplicar(s) } label: {
                        FilaAjuste(simbolo: s.simbolo, color: s.color, titulo: s.nombre)
                    }
                    .revisable("situacion.\(s.rawValue)", s.nombre, en: .situaciones)
                }
            } footer: {
                Text(L("Antes de la primera se guarda una copia de tus datos: está en Datos y copias.",
                       "Before the first one, a copy of your data is saved: it's in Data & Copies.",
                       "Prima della prima si salva una copia dei tuoi dati: è in Dati e copie."))
            }
            if !almacen.esFamilia {
                Section(L("Con su hora", "With its time", "Con la sua ora")) {
                    Button { conHora(.examenManana, 21 * 60 + 30, hoy: true) } label: {
                        FilaAjuste(simbolo: "moon.stars.fill", color: .indigo, titulo: L("Noche antes de una prueba", "Night before a test", "Sera prima di una verifica"))
                    }
                    .revisable("situacion.nocheExamen", L("Noche antes de una prueba", "Night before a test", "Sera prima di una verifica"), en: .situaciones)
                    Button { conHora(.examenHoy, 7 * 60 + 50, hoy: true) } label: {
                        FilaAjuste(simbolo: "sunrise.fill", color: .naranja, titulo: L("Mañana de prueba", "Test day morning", "Mattina della verifica"))
                    }
                    .revisable("situacion.mananaExamen", L("Mañana de prueba", "Test day morning", "Mattina della verifica"), en: .situaciones)
                    Button { conHora(.mochilaSinHacer, almacen.ajustes.avisos.horaMochila + 30, hoy: true) } label: {
                        FilaAjuste(simbolo: "backpack.fill", color: .marron, titulo: L("Mochila sin preparar por la noche", "Unpacked backpack at night", "Zaino non pronto la sera"))
                    }
                    .revisable("situacion.mochilaNoche", L("Mochila sin preparar por la noche", "Unpacked backpack at night", "Zaino non pronto la sera"), en: .situaciones)
                }
            }
        }
        .navigationTitle(PaginaDesarrollo.situaciones.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: ultima)
    }

    private func aplicar(_ s: Situacion) {
        conMuelle { d.aplicar(s, en: almacen) }
        ultima = s
    }

    private func conHora(_ s: Situacion, _ minutos: Int, hoy: Bool) {
        d.ponerHora(Desarrollo.momento(almacen.datosActivos, hora: minutos / 60, minuto: minutos % 60, conClase: false), parada: false)
        aplicar(s)
    }
}

private struct PaginaAvisos: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.openURL) private var abrir
    @State private var permiso: UNAuthorizationStatus = .notDetermined
    @State private var programados: [Desarrollo.Programado] = []
    @State private var lanzados = 0
    @State private var borrando = false

    var body: some View {
        Form {
            Section {
                LabeledContent(L("Permiso", "Permission", "Permesso"), value: PaginaInformacion.texto(permiso))
                if permiso == .notDetermined {
                    Button(L("Pedir permiso", "Ask for Permission", "Chiedi il permesso")) {
                        Task { _ = await Avisos.pedirPermiso(); await cargar() }
                    }
                }
                if permiso == .denied {
                    Button(L("Abrir Ajustes", "Open Settings", "Apri Impostazioni")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { abrir(url) }
                    }
                }
                NavigationLink { AjusteAvisos() } label: {
                    LabeledContent(L("Avisos de Hoot", "Hoot Notifications", "Notifiche di Hoot"),
                                   value: almacen.ajustes.avisos.activados ? L("Sí", "On", "Sì") : L("No", "Off", "No"))
                }
            }

            Section {
                Button(L("Ver el aviso del correo", "Show the Email Notice", "Mostra l'avviso dell'email")) {
                    almacen.avisoPrueba = L("Tu código de Hoot: \(Int.random(in: 100000...999999))", "Your Hoot code: \(Int.random(in: 100000...999999))", "Il tuo codice di Hoot: \(Int.random(in: 100000...999999))")
                }
                .revisable("avisos.correo", L("Ver el aviso del correo", "Show the Email Notice", "Mostra l'avviso dell'email"), en: .avisos)
                Button(L("Probar un aviso", "Send a Test Notification", "Prova una notifica")) {
                    lanzar(L("Hoot", "Hoot", "Hoot"), L("Así salen los avisos de Hoot.", "This is how Hoot notifications look.", "Ecco come appaiono le notifiche di Hoot."), en: 3)
                }
                .revisable("avisos.probar", L("Probar un aviso", "Send a Test Notification", "Prova una notifica"), en: .avisos)
                Button(L("Lanzar todos los programados", "Send All Scheduled", "Invia tutte le programmate")) {
                    for (i, p) in programados.prefix(20).enumerated() { lanzar(p.titulo, p.cuerpo, en: 3 + Double(i) * 5) }
                }
                .disabled(programados.isEmpty)
                .revisable("avisos.lanzarTodos", L("Lanzar todos los programados", "Send All Scheduled", "Invia tutte le programmate"), en: .avisos)
                Button(L("Volver a programarlos", "Reschedule Them", "Riprogrammale")) {
                    Task { await Avisos.reprogramar(almacen); await cargar() }
                }
                .revisable("avisos.reprogramar", L("Volver a programarlos", "Reschedule Them", "Riprogrammale"), en: .avisos)
                Button(L("Borrar los programados", "Delete Scheduled", "Elimina le programmate"), role: .destructive) { borrando = true }
                    .disabled(programados.isEmpty)
                    .revisable("avisos.borrar", L("Borrar los programados", "Delete Scheduled", "Elimina le programmate"), en: .avisos)
            } footer: {
                Text(L("Salen a los pocos segundos, también con la app abierta; «Lanzar todos» saca uno cada 5 s.",
                       "They appear a few seconds later, even with the app open; “Send All” sends one every 5 s.",
                       "Arrivano dopo pochi secondi, anche con l'app aperta; «Invia tutte» ne manda una ogni 5 s."))
            }

            Section {
                if programados.isEmpty {
                    Text(motivo).textoSecundario()
                }
                ForEach(programados) { p in
                    Button { lanzar(p.titulo, p.cuerpo, en: 3) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.titulo).font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary)
                            Text(p.cuerpo).font(.subheadline).foregroundStyle(Color.primary)
                            if let f = p.fecha {
                                Text("\(Formato.diaRelativo(f)) · \(Formato.hora(f))").font(.caption.monospacedDigit()).textoSecundario()
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text(L("Programados (\(programados.count))", "Scheduled (\(programados.count))", "Programmate (\(programados.count))"))
            } footer: {
                if !programados.isEmpty {
                    Text(L("Toca uno para verlo dentro de 3 s.", "Tap one to see it in 3 s.", "Toccane una per vederla tra 3 s."))
                }
            }
        }
        .navigationTitle(PaginaDesarrollo.avisos.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
        .refreshable { await cargar() }
        .sensoryFeedback(.success, trigger: lanzados)
        .confirmationDialog(L("¿Borrar los avisos programados?", "Delete the scheduled notifications?", "Eliminare le notifiche programmate?"), isPresented: $borrando, titleVisibility: .visible) {
            Button(L("Borrar", "Delete", "Elimina"), role: .destructive) {
                Task { await Desarrollo.borrarProgramados(); await cargar() }
            }
        } message: {
            Text(L("Vuelven a programarse en cuanto cambie algo.", "They're scheduled again as soon as something changes.", "Si riprogrammano appena cambia qualcosa."))
        }
    }

    private var motivo: String {
        if permiso != .authorized && permiso != .provisional { return L("Sin permiso para avisar.", "No permission to notify.", "Nessun permesso per le notifiche.") }
        if !almacen.ajustes.avisos.activados { return L("Los avisos de Hoot están apagados.", "Hoot notifications are off.", "Le notifiche di Hoot sono spente.") }
        return L("Nada que avisar en las próximas dos semanas.", "Nothing to notify in the next two weeks.", "Niente da notificare nelle prossime due settimane.")
    }

    private func cargar() async {
        permiso = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        programados = await Desarrollo.programados()
    }

    private func lanzar(_ titulo: String, _ cuerpo: String, en s: TimeInterval) {
        Task {
            await Desarrollo.lanzar(titulo: titulo, cuerpo: cuerpo, en: s)
            lanzados += 1
        }
    }
}

private struct PaginaFamilia: View {
    @Environment(Almacen.self) private var almacen
    @State private var d = Desarrollo.compartido
    @State private var ultima: Situacion?

    var body: some View {
        @Bindable var almacen = almacen
        Form {
            Section {
                Button { d.cambiarCuenta(almacen) } label: {
                    FilaAjuste(simbolo: "person.2.fill", color: .verde,
                               titulo: almacen.esFamilia ? L("Cambiar a cuenta de estudiante", "Switch to Student Account", "Passa all'account studente")
                                                         : L("Cambiar a cuenta de familia", "Switch to Family Account", "Passa all'account famiglia"))
                }
                .revisable("principal.cuenta", L("Cambiar de cuenta (estudiante o familia)", "Switch account (student or family)", "Cambia account (studente o famiglia)"))
            } footer: {
                Text(L("Tus datos de estudiante se quedan; la familia ve a sus hijos (de ejemplo si no hay).",
                       "Your student data stays; the family sees its children (sample ones if there are none).",
                       "I tuoi dati da studente restano; la famiglia vede i suoi figli (di esempio se non ce ne sono)."))
            }
            if almacen.esFamilia {
                Section {
                    LabeledContent(L("Hijos vinculados", "Linked children", "Figli collegati"), value: "\(almacen.hijos.count)")
                    ForEach(Situacion.allCases.filter(\.deFamilia)) { s in
                        Button { aplicar(s) } label: {
                            FilaAjuste(simbolo: s.simbolo, color: s.color, titulo: s.nombre)
                        }
                        .revisable("situacion.\(s.rawValue)", s.nombre, en: .situaciones)
                    }
                }
            } else {
                Section {
                    Toggle(L("Tu familia te ve", "Your family can see you", "La tua famiglia ti vede"), isOn: Binding(
                        get: { !almacen.vinculos.isEmpty },
                        set: { si in
                            conMuelle {
                                if si { almacen.vinculos = [Vinculo(nombre: L("Marta", "Sarah", "Marta"), fecha: Reloj.ahora)] } else { almacen.vinculos = [] }
                            }
                        }))
                    .revisable("familia.teVen", L("Tu familia te ve", "Your family can see you", "La tua famiglia ti vede"), en: .familia)
                    Button { aplicar(.recordatorioFamilia) } label: {
                        FilaAjuste(simbolo: Situacion.recordatorioFamilia.simbolo, color: Situacion.recordatorioFamilia.color, titulo: Situacion.recordatorioFamilia.nombre)
                    }
                    .revisable("situacion.recordatorioFamilia", Situacion.recordatorioFamilia.nombre, en: .situaciones)
                    Button { aplicar(.familiaPide) } label: {
                        FilaAjuste(simbolo: Situacion.familiaPide.simbolo, color: Situacion.familiaPide.color, titulo: Situacion.familiaPide.nombre)
                    }
                    .revisable("situacion.familiaPide", Situacion.familiaPide.nombre, en: .situaciones)
                    LabeledContent {
                        Text(almacen.codigoVinculo).monospaced()
                    } label: {
                        Text(L("Código de vínculo", "Link code", "Codice di collegamento"))
                    }
                    Button(L("Código nuevo", "New Code", "Nuovo codice")) {
                        conMuelle {
                            almacen.codigoVinculo = Almacen.nuevoCodigo()
                            almacen.vinculos.removeAll()
                        }
                    }
                    .revisable("familia.codigo", L("Código de vínculo nuevo", "New link code", "Nuovo codice di collegamento"), en: .familia)
                } header: {
                    Text(L("Lo que ve tu familia", "What your family sees", "Cosa vede la tua famiglia"))
                }
            }
            Section {
                NavigationLink { AjusteFamilia() } label: {
                    FilaAjuste(simbolo: AjusteCuenta.familia.simbolo, color: AjusteCuenta.familia.color, titulo: AjusteCuenta.familia.titulo)
                }
            }
        }
        .navigationTitle(PaginaDesarrollo.familia.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: ultima)
    }

    private func aplicar(_ s: Situacion) {
        conMuelle { d.aplicar(s, en: almacen) }
        ultima = s
    }
}

private struct PaginaTiempo: View {
    @Environment(Almacen.self) private var almacen
    @Bindable private var d = Desarrollo.compartido
    @State private var tiempo = TiempoReal.compartido
    @State private var rayos = 0

    var body: some View {
        let escena = tiempo.escena(fijado: TiempoFijo(rawValue: almacen.ajustes.tiempoFondo) ?? .real)
        Form {
            Section {
                Picker(L("Tiempo", "Weather", "Meteo"), selection: $d.tiempoForzado) {
                    Text(L("El de Ajustes > Fondo", "The one in Settings > Background", "Quello di Impostazioni > Sfondo")).tag(Tiempo?.none)
                    ForEach(Tiempo.allCases, id: \.self) { t in
                        Label(t.nombre, systemImage: t.simbolo).tag(Tiempo?.some(t))
                    }
                }
                .revisable("tiempo.forzado", L("Forzar el tiempo", "Force the weather", "Forza il meteo"), en: .tiempo)
                Picker(L("Día o noche", "Day or Night", "Giorno o notte"), selection: $d.nocheForzada) {
                    Text(L("Según la hora", "By the time", "Secondo l'ora")).tag(Bool?.none)
                    Text(L("Día", "Day", "Giorno")).tag(Bool?.some(false))
                    Text(L("Noche", "Night", "Notte")).tag(Bool?.some(true))
                }
                .revisable("tiempo.diaNoche", L("Día o noche", "Day or Night", "Giorno o notte"), en: .tiempo)
                if escena.vida == .tormenta || escena.vida == .tormentaGranizo {
                    Button(L("Que caiga un rayo", "Strike Lightning", "Fai cadere un fulmine")) {
                        d.rayoPedido = true
                        rayos += 1
                    }
                    .revisable("tiempo.rayo", L("Que caiga un rayo", "Strike Lightning", "Fai cadere un fulmine"), en: .tiempo)
                }
            } footer: {
                if escena.vida == .tormenta || escena.vida == .tormentaGranizo {
                    Text(L("El rayo cae al cerrar Cuenta.", "The lightning strikes when you close Account.", "Il fulmine cade chiudendo Account."))
                }
            }

            Section {
                Toggle(L("Reducir movimiento", "Reduce Motion", "Riduci movimento"), isOn: $d.vidaQuieta)
                    .revisable("tiempo.quieto", L("Como con «Reducir movimiento»", "As with Reduce Motion", "Come con «Riduci movimento»"), en: .tiempo)
                Toggle(L("Modo de ahorro", "Low Power Mode", "Risparmio energetico"), isOn: $d.vidaAhorro)
                    .revisable("tiempo.ahorro", L("Como con el modo de ahorro", "As with Low Power Mode", "Come con il risparmio energetico"), en: .tiempo)
                Toggle(L("Atenuar destellos", "Dim Flashing Lights", "Attenua luci lampeggianti"), isOn: $d.vidaTenue)
                    .revisable("tiempo.tenue", L("Como con «Atenuar destellos»", "As with Dim Flashing Lights", "Come con «Attenua luci lampeggianti»"), en: .tiempo)
            } header: {
                Text(L("Como con…", "As with…", "Come con…"))
            } footer: {
                Text(L("Solo en el tiempo del fondo, para ver lo que hace sin cambiar los ajustes del iPhone.",
                       "Only for the background weather, to see what it does without changing the iPhone's settings.",
                       "Solo per il meteo dello sfondo, per vedere cosa fa senza cambiare le impostazioni dell'iPhone."))
            }

            Section {
                LabeledContent(L("Último", "Latest", "Ultimo"), value: textoUltimo)
                LabeledContent(L("Ubicación", "Location", "Posizione"), value: PaginaInformacion.texto(tiempo.permiso))
                Button(L("Pedirlo ahora", "Get It Now", "Richiedilo ora")) { tiempo.pedir() }
                    .disabled(almacen.ajustes.tiempoFondo != TiempoFijo.real.rawValue)
                    .revisable("tiempo.pedir", L("Pedir el tiempo de verdad", "Get the real weather", "Richiedi il meteo vero"), en: .tiempo)
                Button(L("Olvidar el último", "Forget the Latest", "Dimentica l'ultimo"), role: .destructive) { tiempo.olvidar() }
                    .disabled(tiempo.ultimo == nil)
                    .revisable("tiempo.olvidar", L("Olvidar el último tiempo", "Forget the latest weather", "Dimentica l'ultimo meteo"), en: .tiempo)
            } header: {
                Text(L("El tiempo de verdad", "The real weather", "Il meteo vero"))
            } footer: {
                if almacen.ajustes.tiempoFondo != TiempoFijo.real.rawValue {
                    Text(L("En Ajustes > Fondo hay un tiempo fijo: no se pide el de verdad.", "Settings > Background has a fixed weather: the real one isn't requested.", "In Impostazioni > Sfondo c'è un meteo fisso: quello vero non viene richiesto."))
                }
            }
        }
        .navigationTitle(PaginaDesarrollo.tiempo.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .heavy), trigger: rayos)
    }

    private var textoUltimo: String {
        guard let u = tiempo.ultimo else { return L("Ninguno", "None", "Nessuno") }
        let cuando = Formato.hora(u.cuando)
        return "\(u.tiempo.nombre), \(u.deDia ? L("de día", "day", "di giorno") : L("de noche", "night", "di notte")) · \(cuando)"
    }
}

extension Tiempo {
    var nombre: String {
        switch self {
        case .despejado: L("Despejado", "Clear", "Sereno")
        case .algunasNubes: L("Algunas nubes", "Partly cloudy", "Poco nuvoloso")
        case .nubes: L("Nubes", "Cloudy", "Nuvoloso")
        case .niebla: L("Niebla", "Fog", "Nebbia")
        case .lluvia: L("Lluvia", "Rain", "Pioggia")
        case .lluviaFuerte: L("Lluvia fuerte", "Heavy rain", "Pioggia forte")
        case .tormenta: L("Tormenta", "Thunderstorm", "Temporale")
        case .tormentaGranizo: L("Tormenta con granizo", "Thunderstorm with hail", "Temporale con grandine")
        case .nieve: L("Nieve", "Snow", "Neve")
        case .granizo: L("Granizo", "Hail", "Grandine")
        }
    }

    var simbolo: String {
        switch self {
        case .despejado: "sun.max.fill"
        case .algunasNubes: "cloud.sun.fill"
        case .nubes: "cloud.fill"
        case .niebla: "cloud.fog.fill"
        case .lluvia: "cloud.rain.fill"
        case .lluviaFuerte: "cloud.heavyrain.fill"
        case .tormenta: "cloud.bolt.rain.fill"
        case .tormentaGranizo: "cloud.bolt.fill"
        case .nieve: "cloud.snow.fill"
        case .granizo: "cloud.hail.fill"
        }
    }
}

private struct PaginaPantalla: View {
    @Bindable private var d = Desarrollo.compartido

    var body: some View {
        Form {
            Section {
                Picker(L("Letra", "Text Size", "Testo"), selection: $d.letraForzada) {
                    Text(L("La del iPhone", "The iPhone's", "Quello dell'iPhone")).tag(DynamicTypeSize?.none)
                    Text(L("La más pequeña", "Smallest", "Il più piccolo")).tag(DynamicTypeSize?.some(.xSmall))
                    Text(L("Normal", "Default", "Normale")).tag(DynamicTypeSize?.some(.large))
                    Text(L("Grande", "Large", "Grande")).tag(DynamicTypeSize?.some(.xxxLarge))
                    Text(L("Accesibilidad", "Accessibility", "Accessibilità")).tag(DynamicTypeSize?.some(.accessibility3))
                    Text(L("La más grande", "Largest", "Il più grande")).tag(DynamicTypeSize?.some(.accessibility5))
                }
                .revisable("pantalla.letra", L("Letra", "Text Size", "Testo"), en: .pantalla)
                Picker(L("Apariencia", "Appearance", "Aspetto"), selection: $d.aparienciaForzada) {
                    Text(L("La del iPhone", "The iPhone's", "Quello dell'iPhone")).tag(ColorScheme?.none)
                    Text(L("Clara", "Light", "Chiaro")).tag(ColorScheme?.some(.light))
                    Text(L("Oscura", "Dark", "Scuro")).tag(ColorScheme?.some(.dark))
                }
                .revisable("pantalla.apariencia", L("Apariencia", "Appearance", "Aspetto"), en: .pantalla)
                Toggle(L("Texto en negrita", "Bold Text", "Testo in grassetto"), isOn: $d.negrita)
                    .revisable("pantalla.negrita", L("Texto en negrita", "Bold Text", "Testo in grassetto"), en: .pantalla)
            } footer: {
                Text(L("Solo en Hoot y sin tocar los ajustes del iPhone.", "Only in Hoot, without changing the iPhone's settings.", "Solo in Hoot, senza toccare le impostazioni dell'iPhone."))
            }
        }
        .navigationTitle(PaginaDesarrollo.pantalla.titulo)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PaginaEstudio: View {
    @Environment(Almacen.self) private var almacen
    @Bindable private var d = Desarrollo.compartido
    @State private var modo: ModoPrueba = .oral
    @State private var momento = "pregunta"
    @State private var prueba: PruebaIA?
    @State private var esquema = false

    var body: some View {
        Form {
            Section {
                LabeledContent(L("En este iPhone", "On this iPhone", "Su questo iPhone"), value: PaginaDesarrollo.nombreIA(DisponibilidadIA.real))
                Picker(L("Hacer como si", "Pretend", "Fai finta che"), selection: $d.iaForzada) {
                    Text(L("Como esté", "As it is", "Com'è")).tag(DisponibilidadIA?.none)
                    ForEach(Desarrollo.casosIA, id: \.clave) { c in
                        Text(PaginaDesarrollo.nombreIA(c.caso)).tag(DisponibilidadIA?.some(c.caso))
                    }
                }
                .revisable("estudio.ia", L("Forzar Apple Intelligence", "Force Apple Intelligence", "Forza Apple Intelligence"), en: .estudio)
            } footer: {
                Text(L("Forzarla no la hace funcionar: enseña lo que sale en cada caso (el lobo, los mensajes).",
                       "Forcing it doesn't make it work: it shows what appears in each case (the wolf, the messages).",
                       "Forzarla non la fa funzionare: mostra cosa appare in ogni caso (il lupo, i messaggi)."))
            }

            Section {
                Picker(L("Evalúame", "Quiz Me", "Interrogami"), selection: $modo) {
                    ForEach(ModoPrueba.allCases) { m in Text(m.nombre).tag(m) }
                }
                Picker(L("Momento", "Moment", "Momento"), selection: $momento) {
                    Text(L("Pregunta", "Question", "Domanda")).tag("pregunta")
                    Text(L("Corrección", "Correction", "Correzione")).tag("correccion")
                    Text(L("Final", "End", "Fine")).tag("final")
                    Text(L("Leyendo las fotos", "Reading the photos", "Lettura delle foto")).tag("preparando")
                }
                Button(L("Abrir Evalúame de ejemplo", "Open Sample Quiz", "Apri Interrogami di esempio")) {
                    prueba = ModoCapturas.pruebaEjemplo(modo: modo, estado: momento)
                }
                .revisable("estudio.evaluame", L("Evalúame de ejemplo", "Sample quiz", "Interrogami di esempio"), en: .estudio)
                Button(L("Abrir el esquema de ejemplo", "Open Sample Outline", "Apri lo schema di esempio")) { esquema = true }
                    .revisable("estudio.esquema", L("Esquema de ejemplo", "Sample outline", "Schema di esempio"), en: .estudio)
            } header: {
                Text(L("De ejemplo", "Samples", "Esempi"))
            }

            if !almacen.esFamilia {
                Section {
                    ForEach(TipoAyuda.allCases) { t in
                        Button(t.nombre) {
                            Desarrollo.compartido.cerrarCuentaY(almacen) {
                                almacen.ayudaPendiente = (t, nil)
                                almacen.pestana = .estudio
                            }
                        }
                        .revisable("estudio.ayuda.\(t.rawValue)", t.nombre, en: .estudio)
                    }
                } header: {
                    Text(L("Abrir de verdad", "Open for real", "Apri davvero"))
                } footer: {
                    Text(L("Con fotos de la cámara o de la fototeca, y Apple Intelligence de verdad.", "With photos from the camera or library, and real Apple Intelligence.", "Con foto dalla fotocamera o dalla libreria, e Apple Intelligence vera."))
                }
            }
        }
        .navigationTitle(PaginaDesarrollo.estudio.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $prueba) { p in
            NavigationStack { VistaPrueba(prueba: p, alTerminar: { prueba = nil }) }
        }
        .fullScreenCover(isPresented: $esquema) {
            NavigationStack {
                ResultadoEsquema(trabajo: nil, guardado: ModoCapturas.esquemaDemo, titulo: "La célula") { esquema = false }
            }
        }
    }
}

private struct PaginaLobo: View {
    @Bindable private var d = Desarrollo.compartido

    var body: some View {
        Form {
            Section {
                Picker(L("Gesto en Hoy", "Face on Today", "Espressione in Oggi"), selection: $d.gestoForzado) {
                    Text(L("Según lo que pase", "Depending on the day", "Secondo la giornata")).tag(GestoLobo?.none)
                    ForEach(GestoLobo.allCases, id: \.self) { g in Text(g.nombre).tag(GestoLobo?.some(g)) }
                }
                .revisable("lobo.gesto", L("Gesto en Hoy", "Face on Today", "Espressione in Oggi"), en: .lobo)
            } footer: {
                Text(L("Tócalo en Hoy: salta y vibra.", "Tap it on Today: it jumps and vibrates.", "Toccalo in Oggi: salta e vibra."))
            }
            Section {
                NavigationLink(L("Todos los gestos", "All Faces", "Tutte le espressioni")) {
                    CatalogoLobos()
                        .navigationTitle(L("Todos los gestos", "All Faces", "Tutte le espressioni"))
                        .navigationBarTitleDisplayMode(.inline)
                }
                .revisable("lobo.catalogo", L("Todos los gestos", "All Faces", "Tutte le espressioni"), en: .lobo)
            }
        }
        .navigationTitle(PaginaDesarrollo.lobo.titulo)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension GestoLobo {
    var nombre: String {
        switch self {
        case .normal: L("Normal", "Normal", "Normale")
        case .feliz: L("Contento", "Happy", "Contento")
        case .pensando: L("Pensando", "Thinking", "Pensieroso")
        case .dormido: L("Dormido", "Asleep", "Addormentato")
        case .sorprendido: L("Sorprendido", "Surprised", "Sorpreso")
        case .preocupado: L("Preocupado", "Worried", "Preoccupato")
        case .enfadado: L("Enfadado", "Angry", "Arrabbiato")
        case .escribiendo: L("Escribiendo", "Writing", "Scrive")
        case .saltando: L("Saltando", "Jumping", "Salta")
        case .aullando: L("Aullando", "Howling", "Ulula")
        case .hablando: L("Hablando", "Talking", "Parla")
        case .atascado: L("Atascado", "Stuck", "Bloccato")
        }
    }
}

private struct PaginaDatos: View {
    @Environment(Almacen.self) private var almacen
    @State private var d = Desarrollo.compartido
    @State private var exportado: URL?
    @State private var recuperando: Desarrollo.Copia?
    @State private var borrandoTodo = false

    var body: some View {
        Form {
            Section {
                if let f = d.fecha(.datos) {
                    LabeledContent(L("Guardada", "Saved", "Salvata"), value: "\(Formato.diaRelativo(f)) · \(Formato.hora(f))")
                    Button(L("Volver a esta copia", "Restore This Copy", "Ripristina questa copia")) { recuperando = .datos }
                        .revisable("datos.recuperar", L("Volver a la copia", "Restore the copy", "Ripristina la copia"), en: .datos)
                }
                Button(d.fecha(.datos) == nil ? L("Guardar una copia", "Save a Copy", "Salva una copia")
                                              : L("Guardar una nueva (sustituye a esta)", "Save a New One (replaces this)", "Salvane una nuova (sostituisce questa)")) {
                    conMuelle { d.guardarCopia(.datos, de: almacen) }
                }
                .revisable("datos.guardar", L("Guardar una copia", "Save a copy", "Salva una copia"), en: .datos)
                if d.fecha(.datos) != nil {
                    Button(L("Borrar la copia", "Delete the Copy", "Elimina la copia"), role: .destructive) { conMuelle { d.borrar(.datos) } }
                }
            } header: {
                Text(L("Copia de tus datos", "Copy of your data", "Copia dei tuoi dati"))
            } footer: {
                Text(L("Se guarda sola antes de la primera situación.", "It's saved automatically before the first situation.", "Si salva da sola prima della prima situazione."))
            }

            if let f = d.fecha(.antesDeConfigurar) {
                Section {
                    LabeledContent(L("Guardado", "Saved", "Salvato"), value: "\(Formato.diaRelativo(f)) · \(Formato.hora(f))")
                    Button(L("Volver a como estaba", "Go Back to How It Was", "Torna com'era")) { recuperando = .antesDeConfigurar }
                        .revisable("datos.antesDeConfigurar", L("Volver a como estaba antes de configurar", "Go back to before setup", "Torna a prima della configurazione"), en: .datos)
                } header: {
                    Text(L("Antes de configurar", "Before setup", "Prima della configurazione"))
                }
            }

            Section {
                if let exportado {
                    ShareLink(item: exportado) {
                        Label(L("Exportar los datos (JSON)", "Export Data (JSON)", "Esporta i dati (JSON)"), systemImage: "square.and.arrow.up")
                    }
                    .revisable("datos.exportar", L("Exportar los datos", "Export data", "Esporta i dati"), en: .datos)
                }
                Button(L("Cargar datos de ejemplo", "Load Sample Data", "Carica dati di esempio")) {
                    conMuelle { d.aplicar(almacen.esFamilia ? .unHijo : .ejemplo, en: almacen) }
                }
                .revisable("datos.ejemplo", L("Cargar datos de ejemplo", "Load sample data", "Carica dati di esempio"), en: .datos)
            }

            Section {
                Button(L("Empezar de cero", "Start Over", "Ricomincia da zero"), role: .destructive) { borrandoTodo = true }
                    .revisable("datos.cero", L("Empezar de cero", "Start over", "Ricomincia da zero"), en: .datos)
            } footer: {
                Text(L("Borra todo lo de este iPhone y vuelve a la configuración.", "Erases everything on this iPhone and goes back to setup.", "Cancella tutto su questo iPhone e torna alla configurazione."))
            }
        }
        .navigationTitle(PaginaDesarrollo.datos.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .task { exportado = exportar() }
        .confirmationDialog(L("¿Volver a la copia?", "Restore the copy?", "Ripristinare la copia?"), isPresented: Binding(get: { recuperando != nil }, set: { if !$0 { recuperando = nil } }), titleVisibility: .visible) {
            Button(L("Volver a la copia", "Restore", "Ripristina")) {
                guard let c = recuperando else { return }
                d.cerrarCuentaY(almacen) { d.recuperar(c, en: almacen) }
            }
        } message: {
            Text(L("Lo de ahora se sustituye por lo de la copia.", "What's here now is replaced by the copy.", "Quello che c'è ora viene sostituito dalla copia."))
        }
        .confirmationDialog(L("¿Empezar de cero?", "Start over?", "Ricominciare da zero?"), isPresented: $borrandoTodo, titleVisibility: .visible) {
            Button(L("Borrar todo", "Erase Everything", "Cancella tutto"), role: .destructive) {
                d.cerrarCuentaY(almacen) { conMuelle(Diseno.muelleLento) { almacen.borrarTodo() } }
            }
        } message: {
            Text(L("No se puede deshacer (salvo con una copia guardada).", "This can't be undone (except with a saved copy).", "Non si può annullare (salvo con una copia salvata)."))
        }
    }

    private func exportar() -> URL? {
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.prettyPrinted, .sortedKeys]
        codificador.dateEncodingStrategy = .iso8601
        guard let data = try? codificador.encode(almacen.copiaDeTodo) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Hoot-datos.json")
        try? data.write(to: url, options: .atomic)
        return url
    }
}

private struct PaginaInformacion: View {
    @Environment(Almacen.self) private var almacen
    @State private var avisos: UNAuthorizationStatus = .notDetermined

    var body: some View {
        let dat = almacen.datosActivos
        let info = Bundle.main.infoDictionary ?? [:]
        Form {
            Section(L("App", "App", "App")) {
                LabeledContent(L("Versión", "Version", "Versione"),
                               value: "\(info["CFBundleShortVersionString"] as? String ?? "?") (\(info["CFBundleVersion"] as? String ?? "?"))")
                LabeledContent("iOS", value: UIDevice.current.systemVersion)
                LabeledContent(L("Modelo", "Model", "Modello"), value: Self.modelo)
                LabeledContent(L("Idioma", "Language", "Lingua"), value: almacen.ajustes.idioma.nombrePropio)
                LabeledContent(L("Región", "Region", "Regione"), value: almacen.ajustes.region)
            }
            SeccionNubeDesarrollo()
            Section(L("Hora", "Time", "Ora")) {
                TimelineView(.everyMinute) { _ in
                    LabeledContent(L("De verdad", "Real", "Vera"), value: AjusteDesarrollador.texto(Date()))
                }
                TimelineView(.everyMinute) { _ in
                    LabeledContent(L("De la app", "In the app", "Nell'app"), value: AjusteDesarrollador.texto(Reloj.ahora))
                }
            }
            Section(L("Permisos", "Permissions", "Permessi")) {
                LabeledContent(L("Avisos", "Notifications", "Notifiche"), value: Self.texto(avisos))
                LabeledContent(L("Ubicación", "Location", "Posizione"), value: Self.texto(TiempoReal.compartido.permiso))
                LabeledContent(L("Cámara", "Camera", "Fotocamera"), value: Self.texto(AVCaptureDevice.authorizationStatus(for: .video)))
                LabeledContent(L("Micrófono", "Microphone", "Microfono"), value: Self.textoMicro)
                LabeledContent(L("Fotos", "Photos", "Foto"), value: Self.texto(PHPhotoLibrary.authorizationStatus(for: .readWrite)))
                LabeledContent(L("Reconocimiento de voz", "Speech Recognition", "Riconoscimento vocale"), value: Self.texto(SFSpeechRecognizer.authorizationStatus()))
                LabeledContent("Face ID", value: Self.textoFaceID)
                LabeledContent("Apple Intelligence", value: PaginaDesarrollo.nombreIA(DisponibilidadIA.real))
            }
            Section(L("Datos", "Data", "Dati")) {
                LabeledContent(L("Asignaturas", "Subjects", "Materie"), value: "\(dat.asignaturas.count)")
                LabeledContent(L("Clases a la semana", "Classes a week", "Lezioni a settimana"), value: "\(dat.horario.count)")
                LabeledContent(L("Tareas pendientes", "Pending assignments", "Compiti da fare"), value: "\(dat.tareas.filter { !$0.hecha && $0.tipo != .examen }.count)")
                LabeledContent(L("Exámenes", "Tests", "Verifiche"), value: "\(dat.tareas.filter { $0.tipo == .examen && !$0.hecha }.count)")
                LabeledContent(L("Actividades", "Activities", "Attività"), value: "\(dat.actividades.count)")
                LabeledContent(L("Recordatorios", "Reminders", "Promemoria"), value: "\(dat.recordatorios.count)")
                LabeledContent(L("Notas", "Grades", "Voti"), value: "\(dat.notas.count)")
                LabeledContent(L("Estudios guardados", "Saved study items", "Studi salvati"), value: "\(almacen.estudios.count)")
                LabeledContent(L("Hijos", "Children", "Figli"), value: "\(almacen.hijos.count)")
                LabeledContent(L("Te ven", "Can see you", "Ti vedono"), value: "\(almacen.vinculos.count)")
                LabeledContent("Teams", value: Self.texto(almacen.teams.estado))
                LabeledContent(L("Tamaño de lo guardado", "Saved data size", "Dimensione dei dati"), value: Self.tamano(almacen))
            }
        }
        .navigationTitle(PaginaDesarrollo.informacion.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .task { avisos = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus }
    }

    static var modelo: String {
        var u = utsname()
        uname(&u)
        return withUnsafeBytes(of: &u.machine) { b in String(decoding: b.prefix { $0 != 0 }, as: UTF8.self) }
    }

    static func tamano(_ almacen: Almacen) -> String {
        let bytes = (try? JSONEncoder().encode(almacen.copiaDeTodo).count) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private static var si: String { L("Permitido", "Allowed", "Consentito") }
    private static var no: String { L("Denegado", "Denied", "Negato") }
    private static var sinPreguntar: String { L("Sin preguntar", "Not asked", "Non richiesto") }
    private static var restringido: String { L("Restringido", "Restricted", "Limitato") }

    static func texto(_ s: UNAuthorizationStatus) -> String {
        switch s {
        case .authorized: si
        case .denied: no
        case .notDetermined: sinPreguntar
        case .provisional: L("Provisional", "Provisional", "Provvisorio")
        case .ephemeral: L("Temporal", "Temporary", "Temporaneo")
        @unknown default: "?"
        }
    }

    static func texto(_ s: CLAuthorizationStatus) -> String {
        switch s {
        case .authorizedWhenInUse: L("Al usar la app", "While using the app", "Mentre usi l'app")
        case .authorizedAlways: L("Siempre", "Always", "Sempre")
        case .denied: no
        case .restricted: restringido
        case .notDetermined: sinPreguntar
        @unknown default: "?"
        }
    }

    static func texto(_ s: AVAuthorizationStatus) -> String {
        switch s {
        case .authorized: si
        case .denied: no
        case .restricted: restringido
        case .notDetermined: sinPreguntar
        @unknown default: "?"
        }
    }

    static func texto(_ s: PHAuthorizationStatus) -> String {
        switch s {
        case .authorized: si
        case .limited: L("Algunas", "Limited", "Alcune")
        case .denied: no
        case .restricted: restringido
        case .notDetermined: sinPreguntar
        @unknown default: "?"
        }
    }

    static func texto(_ s: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch s {
        case .authorized: si
        case .denied: no
        case .restricted: restringido
        case .notDetermined: sinPreguntar
        @unknown default: "?"
        }
    }

    static func texto(_ e: EstadoTeams.Estado) -> String {
        switch e {
        case .sinVincular: L("Sin vincular", "Not linked", "Non collegato")
        case .prueba: L("Prueba", "Test", "Prova")
        case .vinculado: L("Vinculado", "Linked", "Collegato")
        }
    }

    static var textoMicro: String {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: si
        case .denied: no
        case .undetermined: sinPreguntar
        @unknown default: "?"
        }
    }

    static var textoFaceID: String {
        let c = LAContext()
        var error: NSError?
        guard c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return L("No disponible", "Not available", "Non disponibile")
        }
        return c.biometryType == .faceID ? L("Disponible", "Available", "Disponibile") : L("Otro (Touch ID)", "Other (Touch ID)", "Altro (Touch ID)")
    }
}

struct BotonSalirConfiguracion: View {
    @Environment(Almacen.self) private var almacen

    var body: some View {
        Button {
            Desarrollo.compartido.salirDeConfiguracion(almacen)
        } label: {
            Label(L("Salir de configuración", "Exit Setup", "Esci dalla configurazione"), systemImage: "xmark")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.glass)

        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }
}

enum CatalogoRevision {
    static func ids(esFamilia: Bool) -> Set<String> {
        var ids: Set<String> = [
            "principal.configuracion", "principal.cuenta", "principal.faceid",
            "hora.simulada", "hora.fecha", "hora.parada", "hora.masHora", "hora.masDia", "hora.menosDia", "hora.real",
            "avisos.correo", "avisos.probar", "avisos.lanzarTodos", "avisos.reprogramar", "avisos.borrar",
            "tiempo.forzado", "tiempo.diaNoche", "tiempo.rayo", "tiempo.quieto", "tiempo.ahorro", "tiempo.tenue",
            "tiempo.pedir", "tiempo.olvidar",
            "pantalla.letra", "pantalla.apariencia", "pantalla.negrita",
            "estudio.ia", "estudio.evaluame", "estudio.esquema",
            "lobo.gesto", "lobo.catalogo",
            "datos.guardar", "datos.recuperar", "datos.antesDeConfigurar", "datos.exportar", "datos.ejemplo", "datos.cero",
        ]
        ids.formUnion(PaginaHora.claves.map { "hora.\($0)" })
        ids.formUnion(Situacion.allCases.filter { $0.deFamilia == esFamilia }.map { "situacion.\($0.rawValue)" })
        if !esFamilia {
            ids.formUnion(["situacion.nocheExamen", "situacion.mananaExamen", "situacion.mochilaNoche", "familia.teVen", "familia.codigo"])
            ids.formUnion(["nuevo.salas", "nuevo.salaEjemplo", "nuevo.retoDistancia"])
            ids.formUnion(["nuevo.cieloTemas", "nuevo.apuntarTema", "nuevo.repasito", "nuevo.buscarTemas", "nuevo.examen",
                           "nuevo.adjuntarTemas", "nuevo.camino"])
            ids.formUnion(["nuevo.material", "nuevo.charla", "nuevo.escuchalo", "nuevo.simulacro", "nuevo.clase", "nuevo.widgets", "widgets.inicio"])
            ids.formUnion(["nuevo.fallado", "nuevo.familia", "nuevo.pruebas", "nuevo.apuntar", "nuevo.repaso", "nuevo.lunaLlena", "nuevo.tuCielo", "nuevo.hoy",
                           "nuevo.sinDeberes", "nuevo.permisoIA", "nuevo.vacaciones", "nuevo.configPermiso"])
            ids.formUnion(["conexiones.ejemplo", "conexiones.calendarios", "conexiones.simulacion", "conexiones.teams", "conexiones.sinRepetir"])
            ids.formUnion(TipoAyuda.allCases.map { "estudio.ayuda.\($0.rawValue)" })
        }
        return ids
    }
}

private struct SeccionNubeDesarrollo: View {
    @State private var nube = Sincronizacion.compartida
    @State private var bajando = false

    var body: some View {
        Section {
            LabeledContent("Firebase", value: ConfigNube.lista ? ConfigNube.proyecto : L("Sin proyecto (prueba)", "No project (test)", "Nessun progetto (prova)"))
            LabeledContent(L("Cuenta", "Account", "Account"), value: nube.sesion?.correo ?? L("Sin cuenta", "No account", "Nessun account"))
            if let s = nube.sesion {
                LabeledContent(L("Correo confirmado", "Email confirmed", "Email confermata"), value: s.verificada ? L("Sí", "Yes", "Sì") : L("No", "No", "No"))
            }
            LabeledContent(L("Guardado", "Saved", "Salvataggio"), value: texto)
            if nube.activa, nube.sesion?.verificada == true {
                Button(L("Subir ahora lo de este iPhone", "Upload This iPhone's Data Now", "Carica ora i dati di questo iPhone")) {
                    Task { await nube.subirTodo() }
                }
                Button(L("Poner lo de la cuenta en este iPhone", "Put the Account's Data on This iPhone", "Metti i dati dell'account su questo iPhone"), role: .destructive) {
                    bajando = true
                }
                .confirmationDialog(L("¿Sustituir lo de este iPhone?", "Replace this iPhone's data?", "Sostituire i dati di questo iPhone?"), isPresented: $bajando, titleVisibility: .visible) {
                    Button(L("Sustituir", "Replace", "Sostituisci"), role: .destructive) {
                        Task { if let g = try? await nube.bajarParaEntrar() { nube.aplicar(g) } }
                    }
                }
            }
        } header: {
            Text(L("Cuenta en la nube", "Cloud Account", "Account nel cloud"))
        }
    }

    private var texto: String {
        switch nube.estado {
        case .sinCuenta: "–"
        case .sinConfirmar: L("Falta confirmar el correo", "Email not confirmed", "Email da confermare")
        case .guardando: L("Guardando…", "Saving…", "Salvataggio…")
        case .alDia(let f): f.formatted(date: .omitted, time: .standard)
        case .sinRed: L("Sin conexión", "No connection", "Nessuna connessione")
        case .fallo(let t): t
        }
    }
}

private struct PaginaWidgets: View {
    @Environment(Almacen.self) private var almacen

    var body: some View {
        let i = ModoCapturas.activo ? InstantaneaWidget.ejemplo : DatosWidget.instantanea(almacen)
        List {
            Section {

                VStack(alignment: .leading, spacing: 16) {
                    marco(VistaProximaPrueba(i: i), ancho: 158, alto: 158)
                    marco(VistaRepasoHoy(i: i), ancho: 338, alto: 158)
                }
                .padding(.vertical, 6)
                .revisable("widgets.inicio", L("Widgets de la pantalla de inicio", "Home Screen widgets", "Widget della schermata Home"), en: .informacion)
            } header: {
                Text(L("Pantalla de inicio", "Home Screen", "Schermata Home"))
            } footer: {
                Text(L("Mantén pulsado el fondo de la pantalla de inicio, toca «Editar» y «Añadir widget», y busca Hoot.",
                       "Touch and hold the Home Screen background, tap Edit, then Add Widget, and look for Hoot.",
                       "Tieni premuto lo sfondo della schermata Home, tocca «Modifica» e «Aggiungi widget», e cerca Hoot."))
            }
            Section {
                HStack(spacing: 14) {
                    VistaCircular(i: i)
                        .frame(width: 64, height: 64)
                        .background(.white.opacity(0.14), in: Circle())
                    VistaRectangular(i: i)
                        .frame(width: 170, height: 66, alignment: .leading)
                        .padding(.horizontal, 8)
                        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(LinearGradient(colors: [Color(red: 0.13, green: 0.15, blue: 0.37), Color(red: 0.66, green: 0.36, blue: 0.51)], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .environment(\.colorScheme, .dark)
                .listRowBackground(Color.clear)
            } header: {
                Text(L("Pantalla de bloqueo", "Lock Screen", "Schermata di blocco"))
            }
            Section {
                VistaActividadBloqueo(atributos: ActividadRepaso(titulo: L("Repaso · Cartago y Augusto", "Review · Carthage and Augustus", "Ripasso · Cartagine e Augusto"),
                                                                 simulacro: false, idioma: idiomaActual.rawValue),
                                      estado: .init(pregunta: 4, total: 6, luna: 0.5, fin: nil))
                    .background(Color(red: 0.07, green: 0.08, blue: 0.13), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .environment(\.colorScheme, .dark)
                    .listRowBackground(Color.clear)
            } header: {
                Text(L("Mientras repasas (pantalla bloqueada e Isla dinámica)", "While reviewing (Lock Screen and Dynamic Island)", "Mentre ripassi (schermata di blocco e Dynamic Island)"))
            }
        }
        .navigationTitle(PaginaDesarrollo.widgets.titulo)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func marco<V: View>(_ v: V, ancho: CGFloat, alto: CGFloat) -> some View {
        v.padding(16)
            .frame(width: ancho, height: alto)
            .environment(\.colorScheme, .dark)
            .background(Color(red: 0.11, green: 0.11, blue: 0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}
