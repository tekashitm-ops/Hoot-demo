import SwiftUI

enum ModoCapturas {
    fileprivate static var argumentos: [String] { ProcessInfo.processInfo.arguments }

    static var activo: Bool { argumentos.contains("-capturas") }

    static func valor(_ clave: String) -> String? {
        guard let i = argumentos.firstIndex(of: clave), i + 1 < argumentos.count else { return nil }
        return argumentos[i + 1]
    }

    static var pantalla: String { valor("-pantalla") ?? "hoy" }

    static func sin(_ parte: String) -> Bool {
        activo && (valor("-sin")?.split(separator: ",").contains { $0 == parte } ?? false)
    }

    static var tiempoFijo: TiempoFijo? {
        guard activo else { return nil }
        return valor("-tiempo").flatMap(TiempoFijo.init(rawValue:))
    }

    static var verHorario: Bool { activo && argumentos.contains("-ver-horario") }

    static var rellenar: Bool { activo && argumentos.contains("-rellenar") }

    static var calendariosDeEjemplo: Bool { activo && argumentos.contains("-calendarios") }

    static var pasoTeams: ConexionTeams.Paso? {
        guard activo else { return nil }
        switch valor("-comprobando") {
        case "teams": return .comprobando
        case "bloqueado": return .bloqueado
        case "vinculado": return .vinculado("lucia.garcia@iesejemplo.edu")
        default: return nil
        }
    }

    static var revisionDeEjemplo: Bool { activo && argumentos.contains("-revision") }

    static var salidaConfiguracion: Bool { activo && argumentos.contains("-desarrollo") }

    static var paginaDesarrollo: PaginaDesarrollo? {
        guard activo else { return nil }
        return valor("-pagina").flatMap(PaginaDesarrollo.init(rawValue:))
    }

    static var rayoQuieto: Bool { activo && argumentos.contains("-rayo") }

    static var calentarVida: Double? {
        guard activo else { return nil }
        return valor("-calentar").flatMap(Double.init)
    }

    static func minutos(_ clave: String) -> Int? {
        guard activo, let v = valor(clave) else { return nil }
        let partes = v.split(separator: ":").compactMap { Int($0) }
        return partes.count == 2 ? partes[0] * 60 + partes[1] : nil
    }

    private static func fijarHora() {
        guard let h = valor("-hora") else { return }
        let partes = h.split(separator: ":").compactMap { Int($0) }
        guard partes.count == 2 else { return }
        let cal = Calendar(identifier: .gregorian)
        let real = Date.now
        var dia = cal.startOfDay(for: real)

        while [1, 6, 7].contains(cal.component(.weekday, from: dia)) {
            dia = cal.date(byAdding: .day, value: 1, to: dia) ?? dia
        }
        if let objetivo = cal.date(bySettingHour: partes[0], minute: partes[1], second: 0, of: dia) {
            Reloj.desfase = objetivo.timeIntervalSince(real)
        }
    }

    static var rutaConfiguracion: [PasoConfig]? {
        guard activo, pantalla.hasPrefix("config-") else { return nil }
        let nombre = String(pantalla.dropFirst("config-".count))
        let familia = nombre.hasPrefix("familia-")
        let paso = familia ? String(nombre.dropFirst("familia-".count)) : nombre
        let orden = FlujoConfig().orden(familia ? .familia : .estudiante)
        let todos: [String: PasoConfig] = [
            "region": .region, "rol": .rol, "nombre": .nombre, "nacimiento": .nacimiento, "correo": .correo,
            "verificar": .verificar, "contrasena": .contrasena,
            "asignaturas": .asignaturas, "materiales": .materiales, "horario": .horario, "avisos": .avisos, "familia": .familia,
            "calendarios": .calendarios, "servicios": .servicios, "primera": .primeraPrueba,
            "vincular": .vincularHijo, "final": .final, "sesion": .iniciarSesion,
        ]
        if paso == "idioma" { return [] }

        if paso == "permiso" { return [.region, .rol, .nombre, .nacimiento, .permisoIA] }
        if paso == "sesion" { return [.region, .rol, .nombre, .correo, .iniciarSesion] }
        guard let destino = todos[paso], let i = orden.firstIndex(of: destino) else { return [] }
        return Array(orden[...i])
    }

    static func preparar(_ almacen: Almacen) {
        guard activo else { return }
        fijarHora()
        if let i = valor("-idioma"), let idioma = Idioma(rawValue: i) {
            almacen.ajustes.idioma = idioma
        } else {
            almacen.ajustes.idioma = .es
        }
        almacen.ajustes.region = "ES"
        almacen.ajustes.escala = .espana

        let familia = pantalla.hasPrefix("familia") || pantalla.hasPrefix("config-familia")
        var perfil = Perfil()
        perfil.nombre = familia ? "Marta" : Demo.nombreHijo
        perfil.apellidos = "García"
        perfil.nacimiento = Calendar.current.date(byAdding: .year, value: familia ? -41 : -13, to: Reloj.ahora)
        perfil.correo = familia ? "marta@ejemplo.com" : "lucia@ejemplo.com"
        perfil.rol = familia ? .familia : .estudiante
        perfil.colegio = "IES Ejemplo"
        perfil.curso = Cursos.lista.count > 3 ? Cursos.lista[3] : ""
        almacen.perfil = perfil

        if pantalla.hasPrefix("config") {
            almacen.configurado = false

            if pantalla.contains("horario") || pantalla.contains("materiales") { Demo.cargarEjemplo(almacen) } else { almacen.datos = DatosEscolares() }
            return
        }

        if familia {
            let hijo = Demo.hijo(escala: almacen.ajustes.escala)
            almacen.hijos = [hijo]
            almacen.hijoActivoID = hijo.id
        } else {
            Demo.cargarEjemplo(almacen)

            if valor("-teams") == "vinculado" {
                almacen.teams.estado = .prueba
                almacen.teams.cuentaColegio = "lucia.garcia@iesejemplo.edu"
                almacen.teams.ultimaSincronizacion = Reloj.ahora.addingTimeInterval(-600)
            }

            if let n = valor("-examen").flatMap(Int.init), let i = almacen.datos.tareas.firstIndex(where: { $0.tipo == .examen }) {
                let cal = calendarioActual
                var dia = cal.startOfDay(for: Reloj.ahora)
                var quedan = n
                while quedan > 0 {
                    dia = cal.date(byAdding: .day, value: 1, to: dia) ?? dia
                    if DatosEscolares.diaISO(dia) <= 5 { quedan -= 1 }
                }
                almacen.datos.tareas[i].entrega = DatosEscolares.fecha(dia, minutos: 9 * 60 + 25)
            }

            if let dia = almacen.datos.diaMochila() {
                let items = almacen.datos.itemsMochila(para: dia)
                almacen.datos.mochilaMarcada[DatosEscolares.clave(dia)] = Set(items.prefix(items.count / 2).map(\.id))
            }
            almacen.estudios = [EstudioGuardado(
                tipo: .resumen, titulo: L("La célula", "The cell", "La cellula"),
                asignaturaID: almacen.datos.asignaturas.first { $0.simbolo == "leaf.fill" }?.id, fecha: Reloj.ahora.addingTimeInterval(-7200),
                resultado: L("## Idea principal\nLa **célula** es la unidad más pequeña de los seres vivos.\n## Lo más importante\n- Todas tienen **membrana**, **citoplasma** y **material genético**.\n- Las **procariotas** no tienen núcleo; las **eucariotas**, sí.\n  - Las vegetales tienen **pared celular** y **cloroplastos**.\n## Preguntas de repaso\n1. ¿Qué diferencia una célula procariota de una eucariota?\n2. ¿Para qué sirven los cloroplastos?",
                             "## Main idea\nThe **cell** is the smallest unit of living things.\n## Key points\n- All cells have a **membrane**, **cytoplasm** and **genetic material**.\n- **Prokaryotic** cells have no nucleus; **eukaryotic** cells do.\n  - Plant cells have a **cell wall** and **chloroplasts**.\n## Review questions\n1. How is a prokaryotic cell different from a eukaryotic one?\n2. What are chloroplasts for?",
                             "## Idea principale\nLa **cellula** è l'unità più piccola dei viventi.\n## Le cose più importanti\n- Tutte hanno **membrana**, **citoplasma** e **materiale genetico**.\n- Le **procariote** non hanno nucleo; le **eucariote** sì.\n  - Quelle vegetali hanno **parete cellulare** e **cloroplasti**.\n## Domande di ripasso\n1. Che differenza c'è tra procariote ed eucariote?\n2. A cosa servono i cloroplasti?"),
                textoLeido: ""
            )]
        }

        if let s = valor("-situacion").flatMap(Situacion.init(rawValue:)) { s.aplicar(almacen) }
        almacen.configurado = true
        almacen.ajustes.avisos.activados = false

        almacen.ajustes.permisoIA = true
        almacen.ajustes.permisoSalas = pantalla != "sala-permiso"

        switch pantalla {
        case "familia-calendario": almacen.pestana = .calendario
        case "apuntar-tema", "repasito": almacen.pestana = .hoy
        case "buscar", "examen", "asignatura": almacen.pestana = .pruebas
        case "calendario", "calendario-dia":

            almacen.pestana = .hoy
            almacen.mostrandoCalendario = true
        case "pruebas", "pruebas-abajo", "prueba", "reto-opciones", "tema", "tema-grande", "charla", "charla-fotos", "charla-vacia", "charla-voz", "escuchalo", "escuchalo-pregunta", "simulacro-empezar", "simulacro", "simulacro-papel", "simulacro-oral", "simulacro-corregido", "reto", "reto-radar", "recibir", "escuchando", "prueba-celebra", "nueva-prueba", "nueva-prueba-elegir", "tu-cielo", "luna-llena", "repaso", "repaso-final":
            almacen.pestana = .pruebas
        case "tareas", "familia-tareas", "tarea-examen": almacen.pestana = .tareas
        case "mochila": almacen.pestana = .mochila
        case "estudio", "estudio-abajo", "evaluame", "esquema": almacen.pestana = .estudio
        case _ where pantalla.hasPrefix("ayuda-"):

            almacen.pestana = .estudio
            almacen.ayudaPendiente = (TipoAyuda(rawValue: String(pantalla.dropFirst("ayuda-".count))) ?? .revisar, nil)
        case "familia-avisos": almacen.pestana = .avisos

        case "sala-entrar", "sala-permiso":
            almacen.pestana = .estudio
            Salas.compartidas.entrando = true
        case "hoy-invitacion":
            almacen.pestana = .hoy
            Salas.compartidas.ponerEjemplo()
        case _ where pantalla.hasPrefix("sala-"):
            almacen.pestana = .estudio
            Salas.compartidas.abierta = SalaEnVivo.ejemploPara(pantalla)
        case "cuenta", "familia-cuenta":
            almacen.pestana = .hoy
            almacen.mostrandoCuenta = true
        default: almacen.pestana = .hoy
        }
    }
}

extension ModoCapturas {

    static var ajusteInicial: [AjusteCuenta] {
        guard activo, let a = valor("-ajuste") else { return [] }
        let ajustes: [String: AjusteCuenta] = ["fondo": .fondo, "estudio": .estudio, "avisos": .avisos, "idioma": .idioma,
                                               "desarrollador": .desarrollador, "datos": .datos, "calendarios": .calendarios,
                                               "teams": .teams, "curso": .notas, "familia": .familia]
        return ajustes[a].map { [$0] } ?? []
    }
}

extension ModoCapturas {

    static var notaDiario: String {
        L("Jue 23 — examen de Historia: Roma, Cartago, Augusto y el Imperio\ntraer el atlas",
          "Thu 23 — History test: Rome, Carthage, Augustus and the Empire\nbring the atlas",
          "Gio 23 — verifica di Storia: Roma, Cartagine, Augusto e l'Impero\nportare l'atlante")
    }

    static func repasoEjemplo(_ almacen: Almacen, final: Bool) -> PruebaIA? {
        let cal = calendarioActual
        guard let p = almacen.datos.pruebas.first(where: { $0.tipo == .escrita && $0.diasQueFaltan(desde: Reloj.ahora, cal: cal) > 0 }),
              p.temas.count >= 3 else { return nil }
        let cartago = p.temas[1], imperio = p.temas[2]
        let r = PruebaIA()
        r.modo = .oral
        r.materiales = [cartago.id: cartago.textoLeido, imperio.id: imperio.textoLeido]
        r.nombresTemas = [cartago.id: cartago.nombre, imperio.id: imperio.nombre]
        r.faseInicial = [cartago.id: cartago.luna(cal: cal), imperio.id: imperio.luna(cal: cal)]
        let bien = Intento(fecha: Reloj.ahora, respuestas: Array(repeating: Respuesta(acierto: true, seguridad: nil), count: 3), mezclado: true)
        r.faseSiAprueba = [cartago.id: FaseLuna.de(cartago.intentos + [bien], cal: cal), imperio.id: FaseLuna.de(imperio.intentos + [bien], cal: cal)]
        r.mezclado = true
        r.conSeguridad = true
        r.preguntas = [
            PreguntaPrueba(pregunta: L("¿Quién cruzó los Alpes con elefantes y para qué?", "Who crossed the Alps with elephants, and why?",
                                       "Chi attraversò le Alpi con gli elefanti e perché?"),
                           esperada: L("Aníbal, para atacar Roma por el norte.", "Hannibal, to attack Rome from the north.", "Annibale, per attaccare Roma da nord."),
                           respuesta: L("Aníbal, para atacar Roma por sorpresa.", "Hannibal, to surprise Rome.", "Annibale, per sorprendere Roma."),
                           veredicto: .correcta, nota: 10, comentario: L("Exacto.", "Exactly.", "Esatto."), temaID: cartago.id, seguridad: .seguro),
            PreguntaPrueba(pregunta: L("¿Quién fue el primer emperador de Roma?", "Who was the first Roman emperor?", "Chi fu il primo imperatore di Roma?"),
                           esperada: "Augusto", temaID: imperio.id),
            PreguntaPrueba(pregunta: L("¿Cómo acabó la tercera guerra púnica?", "How did the Third Punic War end?", "Come finì la terza guerra punica?"),
                           esperada: L("Con la destrucción de Cartago en el 146 a. C.", "With the destruction of Carthage in 146 BC.", "Con la distruzione di Cartagine nel 146 a.C."),
                           temaID: cartago.id),
        ]
        r.actual = 1
        r.fase = .preguntando
        if final {

            for i in r.preguntas.indices { r.preguntas[i].veredicto = .correcta; r.preguntas[i].respuesta = "…" }
            r.preguntas.append(PreguntaPrueba(pregunta: "…", esperada: "…", respuesta: "…", veredicto: .correcta, temaID: cartago.id, seguridad: .seguro))
            r.actual = r.preguntas.count - 1
            r.fase = .terminada
        }
        return r
    }
}

extension ModoCapturas {

    static func pruebaDemo() -> PruebaIA? {
        guard activo, pantalla == "evaluame" else { return nil }
        return pruebaEjemplo(modo: valor("-evaluame").flatMap(ModoPrueba.init(rawValue:)) ?? .oral,
                             estado: valor("-estado") ?? "pregunta")
    }

    static func pruebaEjemplo(modo: ModoPrueba, estado: String) -> PruebaIA {
        let p = PruebaIA()
        p.material = "La célula"
        p.modo = modo
        p.preguntas = [
            PreguntaPrueba(pregunta: "¿Qué diferencia hay entre una célula procariota y una eucariota?",
                           esperada: "Las eucariotas tienen núcleo, que guarda el ADN; las procariotas no tienen núcleo y su ADN está suelto en el citoplasma.",
                           respuesta: "Las eucariotas tienen núcleo y las procariotas no.", veredicto: .ampliable, nota: 8,
                           comentario: "Bien: la diferencia principal es el núcleo.",
                           consejo: "Añade dónde está el ADN en las procariotas: suelto en el citoplasma."),
            PreguntaPrueba(pregunta: "¿Para qué sirven los cloroplastos?",
                           esperada: "Hacen la fotosíntesis: con la luz del sol fabrican glucosa y sueltan oxígeno.",
                           respuesta: "Para hacer la fotosíntesis y que la planta tenga energía.", veredicto: .correcta, nota: 10,
                           comentario: "Exacto. Has dicho para qué sirven y por qué importan."),
            PreguntaPrueba(pregunta: "Nombra las tres partes que tienen todas las células.",
                           esperada: "Membrana plasmática, citoplasma y material genético (ADN).",
                           respuesta: "La membrana y el núcleo.", veredicto: .incompleta, nota: 4,
                           comentario: "La membrana está bien, pero no todas las células tienen núcleo.",
                           consejo: "Faltan el citoplasma y el material genético; el núcleo solo lo tienen las eucariotas."),
            PreguntaPrueba(pregunta: "¿Qué dice la teoría celular?",
                           esperada: "Que todos los seres vivos están formados por células, que la célula es la unidad más pequeña de vida y que toda célula viene de otra.",
                           respuesta: "Que todos los seres vivos están hechos de células y que todas vienen de otra célula.", veredicto: .consejo, nota: 8,
                           comentario: "Bien: tienes las ideas clave.",
                           consejo: "En el examen, dilo en tres puntos: todo ser vivo tiene células, es la unidad de vida y toda célula viene de otra."),
            PreguntaPrueba(pregunta: "¿Qué diferencia una célula vegetal de una animal?",
                           esperada: "La vegetal tiene pared celular, cloroplastos y una vacuola grande; la animal no.",
                           respuesta: "La animal tiene pared celular.", veredicto: .incorrecta, nota: 2,
                           comentario: "Es al revés: la pared celular es de la célula vegetal.",
                           consejo: "La vegetal tiene pared celular, cloroplastos y una vacuola grande."),
        ]
        switch estado {
        case "preparando":

            p.fase = .leyendo(1, 2)
        case "final":
            p.actual = 4
            p.fase = .terminada
        case "correccion":
            p.actual = 2
            for i in 3..<5 { p.preguntas[i].respuesta = ""; p.preguntas[i].veredicto = nil; p.preguntas[i].nota = nil }
            p.fase = .preguntando
        default:
            p.actual = 1
            for i in 1..<5 { p.preguntas[i].respuesta = ""; p.preguntas[i].veredicto = nil; p.preguntas[i].nota = nil }
            p.borrador = "Sirven para hacer la fotosíntesis"
            p.fase = .preguntando
        }
        return p
    }

    static var esquemaDemo: EsquemaDatos {
        typealias I = EsquemaDatos.Idea
        return EsquemaDatos(titulo: "La célula", ramas: [
            .init(titulo: "Qué es", ideas: [
                I(texto: "La unidad más pequeña de los seres vivos", detalles: ["Todos los seres vivos tienen células"]),
                I(texto: "Teoría celular", detalles: ["Schleiden y Schwann, 1839"]),
            ]),
            .init(titulo: "Partes", ideas: [
                I(texto: "Membrana plasmática", detalles: ["Separa y protege", "Deja pasar sustancias"]),
                I(texto: "Citoplasma", detalles: ["Líquido con los orgánulos"]),
                I(texto: "Material genético", detalles: ["ADN: las instrucciones"]),
            ]),
            .init(titulo: "Tipos", ideas: [
                I(texto: "Procariotas", detalles: ["Sin núcleo", "Bacterias"]),
                I(texto: "Eucariotas", detalles: ["Con núcleo", "Animales, plantas y hongos"]),
            ]),
            .init(titulo: "Célula vegetal", ideas: [
                I(texto: "Pared celular", detalles: ["Le da rigidez"]),
                I(texto: "Cloroplastos", detalles: ["Hacen la fotosíntesis"]),
                I(texto: "Vacuola grande", detalles: ["Guarda agua"]),
            ]),
            .init(titulo: "Funciones vitales", ideas: [
                I(texto: "Nutrición"),
                I(texto: "Relación"),
                I(texto: "Reproducción", detalles: ["Por mitosis"]),
            ]),
        ])
    }

    static var verEsquema: Bool { activo && pantalla == "esquema" }

    static func guardarPDFDemo() {
        guard verEsquema, argumentos.contains("-pdf"),
              let url = PDFEsquema.crear(esquemaDemo),
              let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let destino = docs.appendingPathComponent("esquema.pdf")
        try? FileManager.default.removeItem(at: destino)
        try? FileManager.default.copyItem(at: url, to: destino)
    }
}

extension ModoCapturas {

    static var mensajesCharla: [MensajeCharla] {

        [MensajeCharla(quien: .yo, texto: L("¿Por qué se llaman guerras púnicas?", "Why are they called the Punic Wars?", "Perché si chiamano guerre puniche?"),
                       foto: Demo.paginaDeEjemplo(0),
                       masFotos: pantalla == "charla-fotos" ? [Demo.paginaDeEjemplo(1), Demo.paginaDeEjemplo(2)].compactMap { $0 } : []),
         MensajeCharla(quien: .hoot, texto: L("Los romanos llamaban «púnicos» a los cartagineses, porque venían de los fenicios.",
                                              "The Romans called the Carthaginians “Punic”, because they came from the Phoenicians.",
                                              "I romani chiamavano «punici» i cartaginesi, perché venivano dai fenici."),
                       fuente: L("Página 2", "Page 2", "Pagina 2")),
         MensajeCharla(quien: .hoot, texto: L("Ahora tú: ¿quién ganó la primera?", "Your turn: who won the first one?", "Ora tu: chi ha vinto la prima?")),
         MensajeCharla(quien: .yo, texto: L("¿Roma?", "Rome?", "Roma?")),
         MensajeCharla(quien: .hoot, texto: L("Bien. Roma ganó y se quedó Sicilia, que es como pillar el mejor sitio del sofá.",
                                              "Right. Rome won and kept Sicily, which is like grabbing the best spot on the sofa.",
                                              "Bene. Roma vinse e si tenne la Sicilia, che è come prendersi il posto migliore sul divano."),
                       fuente: L("Tus fotos", "Your photos", "Le tue foto")),
         MensajeCharla(quien: .hoot, texto: L("Ahora tú: ¿y quién cruzó los Alpes con elefantes?", "Your turn: and who crossed the Alps with elephants?",
                                              "Ora tu: e chi attraversò le Alpi con gli elefanti?"))]
    }
}
