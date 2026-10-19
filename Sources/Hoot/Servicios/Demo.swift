import Foundation
import UIKit

enum Demo {
    private struct Base {
        let es: String, en: String, it: String
        let color: ColorHoot
        let simbolo: String
        let materiales: [(String, String, String, TipoMaterial, Set<Int>)]
        let profesor: String
        let aula: String

        var nombre: String { L(es, en, it) }
    }

    private static var bases: [Base] { [
        Base(es: "Matemáticas", en: "Math", it: "Matematica", color: .azul, simbolo: "x.squareroot",
             materiales: [("Libro de Matemáticas", "Math textbook", "Libro di matematica", .libro, []),
                          ("Cuaderno de cuadros", "Grid notebook", "Quaderno a quadretti", .cuaderno, []),
                          ("Calculadora", "Calculator", "Calcolatrice", .utiles, [])],
             profesor: "Marta Ruiz", aula: "2.3"),
        Base(es: "Lengua y Literatura", en: "English Language Arts", it: "Italiano", color: .rojo, simbolo: "character.book.closed.fill",
             materiales: [("Libro de Lengua", "Language textbook", "Libro di italiano", .libro, []),
                          ("Cuaderno de Lengua", "Language notebook", "Quaderno di italiano", .cuaderno, []),
                          ("Libro de lectura", "Reading book", "Libro di lettura", .libro, [5])],
             profesor: "Javier Gómez", aula: "2.3"),
        Base(es: "Inglés", en: "Spanish", it: "Inglese", color: .indigo, simbolo: "globe.europe.africa.fill",
             materiales: [("Student's Book", "Spanish textbook", "Student's Book", .libro, []),
                          ("Workbook", "Spanish workbook", "Workbook", .cuaderno, [])],
             profesor: "Laura Smith", aula: "Idiomas 1"),
        Base(es: "Historia", en: "History", it: "Storia", color: .marron, simbolo: "building.columns.fill",
             materiales: [("Libro de Historia", "History textbook", "Libro di storia", .libro, []),
                          ("Cuaderno de Historia", "History notebook", "Quaderno di storia", .cuaderno, [])],
             profesor: "Pedro Navarro", aula: "2.3"),
        Base(es: "Biología y Geología", en: "Biology", it: "Scienze", color: .verde, simbolo: "leaf.fill",
             materiales: [("Libro de Biología", "Biology textbook", "Libro di scienze", .libro, []),
                          ("Bata de laboratorio", "Lab coat", "Camice da laboratorio", .ropa, [3])],
             profesor: "Ana Torres", aula: "Laboratorio"),
        Base(es: "Física", en: "Physics", it: "Fisica", color: .turquesa, simbolo: "atom",
             materiales: [("Libro de Física", "Physics textbook", "Libro di fisica", .libro, []),
                          ("Calculadora", "Calculator", "Calcolatrice", .utiles, [])],
             profesor: "Luis Martín", aula: "Laboratorio"),
        Base(es: "Educación Física", en: "Physical Education", it: "Educazione fisica", color: .naranja, simbolo: "figure.run",
             materiales: [("Ropa de deporte", "Sportswear", "Tuta", .ropa, []),
                          ("Zapatillas", "Sneakers", "Scarpe da ginnastica", .ropa, []),
                          ("Toalla", "Towel", "Asciugamano", .ropa, [])],
             profesor: "Sergio Díaz", aula: L("Gimnasio", "Gym", "Palestra")),
        Base(es: "Música", en: "Music", it: "Musica", color: .rosa, simbolo: "music.note",
             materiales: [("Flauta", "Recorder", "Flauto", .instrumento, []),
                          ("Libro de Música", "Music book", "Libro di musica", .libro, [])],
             profesor: "Elena Vidal", aula: L("Música", "Music room", "Aula di musica")),
        Base(es: "Tecnología", en: "Technology", it: "Tecnologia", color: .gris, simbolo: "gearshape.2.fill",
             materiales: [("Cuaderno de Tecnología", "Technology notebook", "Quaderno di tecnologia", .cuaderno, []),
                          ("Portátil", "Laptop", "Portatile", .dispositivo, [5])],
             profesor: "Raúl Ortega", aula: L("Taller", "Workshop", "Laboratorio")),
        Base(es: "Educación Plástica", en: "Art", it: "Arte", color: .amarillo, simbolo: "paintpalette.fill",
             materiales: [("Bloc de dibujo", "Sketchbook", "Album da disegno", .cuaderno, []),
                          ("Lápices de colores", "Colored pencils", "Matite colorate", .utiles, []),
                          ("Escuadra y cartabón", "Set squares", "Squadrette", .utiles, [])],
             profesor: "Clara Sanz", aula: L("Plástica", "Art room", "Aula di arte")),
        Base(es: "Geografía", en: "Geography", it: "Geografia", color: .menta, simbolo: "map.fill",
             materiales: [("Libro de Geografía", "Geography textbook", "Libro di geografia", .libro, []),
                          ("Atlas", "Atlas", "Atlante", .libro, [3])],
             profesor: "Pedro Navarro", aula: "2.3"),
        Base(es: "Química", en: "Chemistry", it: "Chimica", color: .morado, simbolo: "flask.fill",
             materiales: [("Libro de Química", "Chemistry textbook", "Libro di chimica", .libro, []),
                          ("Tabla periódica", "Periodic table", "Tavola periodica", .utiles, [])],
             profesor: "Luis Martín", aula: "Laboratorio"),
    ] }

    static func asignaturas(completas: Bool) -> [Asignatura] {
        let todas = bases.map { b in
            Asignatura(
                nombre: b.nombre, color: b.color, simbolo: b.simbolo,
                profesor: completas ? b.profesor : "", aula: completas ? b.aula : "",
                materiales: b.materiales.map { Material(nombre: L($0.0, $0.1, $0.2), tipo: $0.3, dias: $0.4) }
            )
        }
        guard !completas, todas.count == 12 else { return todas }
        return [0, 1, 2, 3, 10, 4, 5, 11, 6, 7, 8, 9].map { todas[$0] }
    }

    private static let semana: [[Int]] = [
        [0, 1, 2, -1, 4, 3, 6],
        [5, 0, 1, -1, 7, 2, 8],
        [4, 3, 0, -1, 1, 9, 2],
        [6, 5, 0, -1, 3, 1, 7],
        [2, 8, 4, -1, 0, 9, 1],
    ]

    static func horario(_ asignaturas: [Asignatura], franjas: [Franja]) -> [Clase] {
        var r: [Clase] = []
        for (d, dia) in semana.enumerated() {
            for (i, idx) in dia.enumerated() where idx >= 0 && i < franjas.count && idx < asignaturas.count {
                let f = franjas[i]
                r.append(Clase(dia: d + 1, inicio: f.inicio, fin: f.fin, asignaturaID: asignaturas[idx].id, aula: asignaturas[idx].aula))
            }
        }
        return r
    }

    private static func lectivo(_ n: Int, hora: Int, desde hoy: Date = Reloj.ahora) -> Date {
        let cal = calendarioActual
        var d = cal.startOfDay(for: hoy)
        var restantes = abs(n)
        let paso = n >= 0 ? 1 : -1
        while restantes > 0 {
            d = cal.date(byAdding: .day, value: paso, to: d) ?? d
            if DatosEscolares.diaISO(d) <= 5 { restantes -= 1 }
        }
        return DatosEscolares.fecha(d, minutos: hora)
    }

    static func tareas(_ a: [Asignatura]) -> [Tarea] {
        guard a.count >= 10 else { return [] }
        let tarde = 23 * 60 + 59
        var t: [Tarea] = [
            Tarea(titulo: L("Ejercicios 4 a 9 de la página 52", "Exercises 4–9 on page 52", "Esercizi 4–9 a pagina 52"),
                  asignaturaID: a[0].id, entrega: lectivo(1, hora: tarde)),
            Tarea(titulo: L("Workbook, páginas 30 y 31", "Workbook pages 30–31", "Workbook, pagine 30 e 31"),
                  asignaturaID: a[2].id, entrega: lectivo(2, hora: tarde)),
            Tarea(titulo: L("Comentario de texto: «Platero y yo»", "Text commentary: “The Giver”", "Commento al testo: «I Malavoglia»"),
                  asignaturaID: a[1].id, entrega: lectivo(3, hora: tarde),
                  notas: L("Máximo una página. Sigue el guion del tema 2.", "One page maximum. Follow the unit 2 guide.", "Massimo una pagina. Segui la traccia dell'unità 2.")),
            Tarea(titulo: L("Examen del tema 3: la célula", "Unit 3 test: the cell", "Verifica unità 3: la cellula"),
                  tipo: .examen, asignaturaID: a[4].id, entrega: lectivo(4, hora: 9 * 60 + 25),
                  temas: L("Tema 3, páginas 40 a 58", "Unit 3, pages 40–58", "Unità 3, pagine 40–58")),
            Tarea(titulo: L("Problemas de densidad", "Density problems", "Problemi sulla densità"),
                  asignaturaID: a[5].id, entrega: lectivo(-1, hora: tarde)),
            Tarea(titulo: L("Practicar el «Himno de la alegría» con la flauta", "Practice “Ode to Joy” on the recorder", "Esercitarsi con l'«Inno alla gioia» al flauto"),
                  asignaturaID: a[7].id, entrega: lectivo(5, hora: tarde)),
            Tarea(titulo: L("Trabajo: la Edad Media en la Península", "Project: the Middle Ages", "Ricerca: il Medioevo"),
                  tipo: .trabajo, asignaturaID: a[3].id, entrega: lectivo(8, hora: tarde)),
            Tarea(titulo: L("Examen de ecuaciones", "Equations test", "Verifica sulle equazioni"),
                  tipo: .examen, asignaturaID: a[0].id, entrega: lectivo(9, hora: 8 * 60 + 30),
                  temas: L("Ecuaciones de primer y segundo grado", "Linear and quadratic equations", "Equazioni di primo e secondo grado")),
            Tarea(titulo: L("Proyecto: puente de palillos", "Project: popsicle-stick bridge", "Progetto: ponte di stecchini"),
                  tipo: .trabajo, asignaturaID: a[8].id, entrega: lectivo(12, hora: tarde)),
        ]
        var hecha1 = Tarea(titulo: L("Resumen del tema 2", "Unit 2 summary", "Riassunto dell'unità 2"),
                           asignaturaID: a[3].id, entrega: lectivo(-2, hora: tarde))
        hecha1.hecha = true
        hecha1.hechaEl = lectivo(-2, hora: 18 * 60 + 10)
        var hecha2 = Tarea(titulo: "Listening practice", asignaturaID: a[2].id, entrega: lectivo(-1, hora: tarde))
        hecha2.hecha = true
        hecha2.hechaEl = lectivo(-1, hora: 18 * 60 + 42)
        t += [hecha1, hecha2]
        return t
    }

    private static func intento(hace dias: Int, bien: Int, de n: Int = 3, mezclado: Bool = false) -> Intento {
        let cal = calendarioActual
        let dia = cal.date(byAdding: .day, value: -dias, to: cal.startOfDay(for: Reloj.ahora)) ?? Reloj.ahora
        return Intento(fecha: DatosEscolares.fecha(dia, minutos: 17 * 60 + 40),
                       respuestas: (0..<n).map { Respuesta(acierto: $0 < bien, seguridad: $0 == 0 ? .seguro : .creoQueSi) }, mezclado: mezclado)
    }

    private static func tema(_ es: String, _ en: String, _ it: String, texto: Bool = true, _ intentos: [Intento] = []) -> Tema {
        let nombre = L(es, en, it)
        return Tema(nombre: nombre, textoLeido: texto ? L("Apuntes de \(nombre).", "Notes on \(nombre).", "Appunti su \(nombre).") : "", intentos: intentos)
    }

    private static func conMaterial(_ t: Tema) -> Tema {
        var t = t
        let fotos = (0..<2).compactMap { paginaDeEjemplo($0) }
        t.miniaturas = fotos
        t.fuentes = [FuenteTema(tipo: .fotos, nombre: "", paginas: fotos.count, texto: t.textoLeido),
                     FuenteTema(tipo: .pdf, nombre: L("Tema 3 – Cartago", "Unit 3 – Carthage", "Unità 3 – Cartagine"), paginas: 6,
                                texto: L("Cartago fue una ciudad fenicia del norte de África.", "Carthage was a Phoenician city in North Africa.",
                                         "Cartagine fu una città fenicia del Nord Africa."))]
        return t
    }

    static func paginaDeEjemplo(_ n: Int) -> Data? {
        let lado = CGSize(width: 270, height: 360)
        let formato = UIGraphicsImageRendererFormat.default()
        formato.scale = 1
        let img = UIGraphicsImageRenderer(size: lado, format: formato).image { c in
            UIColor(white: 0.98, alpha: 1).setFill()
            c.fill(CGRect(origin: .zero, size: lado))
            UIColor(red: 0.62, green: 0.40, blue: 0.22, alpha: 1).setFill()
            c.fill(CGRect(x: 24, y: 26, width: n == 0 ? 150 : 120, height: 16))
            UIColor(white: 0.74, alpha: 1).setFill()
            var y: CGFloat = 60
            var i = 0
            while y < 330 {
                if n == 1 && y > 150 && y < 250 {
                    UIColor(red: 0.80, green: 0.86, blue: 0.93, alpha: 1).setFill()
                    c.fill(CGRect(x: 24, y: 150, width: 222, height: 96))
                    UIColor(white: 0.74, alpha: 1).setFill()
                    y = 262
                    continue
                }
                c.fill(CGRect(x: 24, y: y, width: i % 4 == 3 ? 140 : 222, height: 7))
                y += 16
                i += 1
            }
        }
        return img.jpegData(compressionQuality: 0.7)
    }

    private static func conFalladas(_ t: Tema, _ preguntas: [(String, String)]) -> Tema {
        var t = t
        t.falladas = preguntas.map { PreguntaFallada(pregunta: $0.0, esperada: $0.1, fecha: Reloj.ahora.addingTimeInterval(-86_400)) }
        return t
    }

    private static var lleno: [Intento] { [intento(hace: 5, bien: 3), intento(hace: 2, bien: 3, mezclado: true)] }

    static func pruebas(_ a: [Asignatura]) -> [Prueba] {
        guard a.count >= 11 else { return [] }
        return [
            Prueba(asignaturaID: a[3].id, tipo: .escrita, fecha: lectivo(3, hora: 10 * 60 + 15), temas: [
                tema("Roma", "Rome", "Roma", lleno),
                conMaterial(tema("Cartago", "Carthage", "Cartagine", [intento(hace: 1, bien: 3)])),
                conFalladas(tema("El Imperio", "The Empire", "L'Impero", [intento(hace: 1, bien: 2)]), [
                    (L("¿Quién fue el primer emperador de Roma?", "Who was the first Roman emperor?", "Chi fu il primo imperatore di Roma?"),
                     L("Augusto, en el 27 a. C.", "Augustus, in 27 BC.", "Augusto, nel 27 a.C.")),
                ]),
                tema("Augusto", "Augustus", "Augusto", texto: false),
            ]),
            Prueba(asignaturaID: a[2].id, tipo: .oral, fecha: lectivo(6, hora: 9 * 60 + 15), temas: [
                tema("Present perfect", "Present perfect", "Present perfect", [intento(hace: 2, bien: 2)]),
                tema("Verbos irregulares", "Irregular verbs", "Verbi irregolari"),
                tema("Mi ciudad", "My town", "La mia città"),
            ]),
            Prueba(asignaturaID: a[0].id, tipo: .escrita, fecha: lectivo(11, hora: 8 * 60 + 30), temas: [
                tema("Fracciones", "Fractions", "Frazioni", [intento(hace: 3, bien: 2)]),
                tema("Potencias", "Powers", "Potenze"),
                tema("Raíces", "Roots", "Radici"),
            ]),
            Prueba(asignaturaID: a[4].id, tipo: .escrita, fecha: lectivo(-1, hora: 9 * 60 + 25), temas: [
                tema("La célula", "The cell", "La cellula", lleno),
                tema("Los tejidos", "Tissues", "I tessuti", lleno),
                conFalladas(tema("Los órganos", "Organs", "Gli organi", [intento(hace: 4, bien: 3), intento(hace: 2, bien: 3)]), [
                    (L("¿Qué es un órgano?", "What is an organ?", "Che cos'è un organo?"),
                     L("Un conjunto de tejidos que trabajan juntos para una función.", "A group of tissues working together for a function.",
                       "Un insieme di tessuti che lavorano insieme per una funzione.")),
                    (L("Pon un ejemplo de aparato y sus órganos.", "Give an example of a system and its organs.", "Fai un esempio di apparato e i suoi organi."),
                     L("El digestivo: boca, estómago e intestinos.", "The digestive system: mouth, stomach and intestines.", "Il digerente: bocca, stomaco e intestino.")),
                ]),
            ]),
            Prueba(asignaturaID: a[1].id, tipo: .escrita, fecha: lectivo(-8, hora: 11 * 60 + 30), temas: [
                tema("El sustantivo", "Nouns", "Il nome", lleno),
                tema("El adjetivo", "Adjectives", "L'aggettivo", lleno),
                tema("La tilde", "Accents", "L'accento", lleno),
            ], sorpresaTemaID: UUID()),
            Prueba(asignaturaID: a[10].id, tipo: .oral, fecha: lectivo(-12, hora: 12 * 60 + 30), temas: [
                tema("El relieve", "Landforms", "Il rilievo", lleno),
                tema("Los climas", "Climates", "I climi", lleno),
                tema("Los ríos", "Rivers", "I fiumi", [intento(hace: 13, bien: 3)]),
            ], sorpresaTemaID: UUID()),
        ]
    }

    static func vacaciones() -> [Vacaciones] {
        let cal = calendarioActual
        func dia(_ a: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: a, month: m, day: d)) ?? Reloj.ahora }
        return [Vacaciones(nombre: L("Navidad", "Winter break", "Natale"), desde: dia(2026, 12, 23), hasta: dia(2027, 1, 7)),
                Vacaciones(nombre: L("Semana Santa", "Spring break", "Pasqua"), desde: dia(2027, 3, 22), hasta: dia(2027, 3, 29))]
    }

    static func temasDeAhora(_ a: [Asignatura]) -> [TemaDeAhora] {
        guard a.count >= 11 else { return [] }

        return [
            TemaDeAhora(asignaturaID: a[5].id, tema: tema("La densidad", "Density", "La densità", [intento(hace: 2, bien: 3)])),
            TemaDeAhora(asignaturaID: a[10].id, tema: tema("Los ríos de Europa", "European rivers", "I fiumi d'Europa")),
            TemaDeAhora(asignaturaID: a[3].id, tema: conMaterial(tema("Egipto", "Ancient Egypt", "Gli Egizi", [intento(hace: 1, bien: 2)]))),
            TemaDeAhora(asignaturaID: a[3].id, tema: tema("Mesopotamia", "Mesopotamia", "La Mesopotamia", texto: false)),
        ]
    }

    static func notas(_ a: [Asignatura], escala: EscalaNotas) -> [Nota] {
        guard a.count >= 10 else { return [] }

        let lista: [(Int, Double, String, String, String, TipoNota, Int)] = [
            (0, 7.5, "Examen tema 1", "Unit 1 test", "Verifica unità 1", .examen, -30),
            (0, 8.25, "Examen tema 2", "Unit 2 test", "Verifica unità 2", .examen, -12),
            (0, 6.75, "Deberes", "Homework", "Compiti", .deberes, -5),
            (1, 6.5, "Dictado", "Dictation", "Dettato", .examen, -25),
            (1, 7.25, "Examen tema 1", "Unit 1 test", "Verifica unità 1", .examen, -9),
            (2, 9, "Speaking", "Speaking", "Speaking", .oral, -28),
            (2, 8.5, "Unit 1 test", "Unit 1 test", "Unit 1 test", .examen, -14),
            (2, 9.5, "Listening", "Listening", "Listening", .examen, -3),
            (3, 6, "Examen tema 1", "Unit 1 test", "Verifica unità 1", .examen, -20),
            (3, 7, "Mapa político", "Political map", "Cartina politica", .trabajo, -6),
            (4, 8, "Examen tema 1", "Unit 1 test", "Verifica unità 1", .examen, -22),
            (4, 7.5, "Práctica de laboratorio", "Lab report", "Relazione di laboratorio", .trabajo, -8),
            (5, 5.5, "Examen tema 1", "Unit 1 test", "Verifica unità 1", .examen, -18),
            (5, 6.25, "Problemas", "Problem set", "Problemi", .deberes, -4),
            (6, 9, "Resistencia", "Endurance", "Resistenza", .otra, -15),
            (7, 8, "Flauta", "Recorder", "Flauto", .oral, -11),
            (8, 7, "Proyecto", "Project", "Progetto", .trabajo, -16),
            (9, 8.5, "Lámina 1", "Drawing 1", "Tavola 1", .trabajo, -10),
        ]
        let cal = calendarioActual
        return lista.map { (i, v, es, en, it, tipo, dias) in
            let p = v / 10
            let crudo = escala.mayorEsMejor
                ? escala.minimo + p * (escala.maximo - escala.minimo)
                : escala.maximo - p * (escala.maximo - escala.minimo)
            let valor = (crudo / escala.paso).rounded() * escala.paso
            let fecha = cal.date(byAdding: .day, value: dias, to: Reloj.ahora) ?? Reloj.ahora
            return Nota(asignaturaID: a[i].id, valor: valor, titulo: L(es, en, it), fecha: fecha, tipo: tipo)
        }
    }

    static func actividades() -> [Actividad] {
        let cal = calendarioActual
        let hoy = cal.startOfDay(for: Reloj.ahora)
        let lunes = cal.dateInterval(of: .weekOfYear, for: hoy)?.start ?? hoy
        return [
            Actividad(titulo: L("Fútbol", "Soccer", "Calcio"), simbolo: "soccerball", color: .verde,
                      fecha: lunes, inicio: 17 * 60 + 30, fin: 19 * 60, repeticion: .semanal([2, 4]),
                      lugar: L("Polideportivo", "Sports center", "Palazzetto"),
                      llevar: [L("Botas de fútbol", "Soccer cleats", "Scarpe da calcio"),
                               L("Espinilleras", "Shin guards", "Parastinchi")],
                      aviso: 60),
            Actividad(titulo: L("Piano", "Piano", "Pianoforte"), simbolo: "pianokeys", color: .morado,
                      fecha: lunes, inicio: 18 * 60, fin: 19 * 60, repeticion: .semanal([3]),
                      lugar: L("Escuela de música", "Music school", "Scuola di musica"),
                      llevar: [L("Partituras", "Sheet music", "Spartiti")], aviso: 30),
        ]
    }

    static func recordatorios() -> [Recordatorio] {
        [
            Recordatorio(titulo: L("Comprar cartulina para Plástica", "Buy poster board for Art", "Comprare il cartoncino per Arte"),
                         fecha: lectivo(1, hora: 17 * 60)),
            Recordatorio(titulo: L("Autorización de la excursión firmada", "Signed field trip form", "Autorizzazione per la gita firmata"),
                         fecha: lectivo(2, hora: 8 * 60), conHora: false),
            Recordatorio(titulo: L("Devolver el libro a la biblioteca", "Return the library book", "Restituire il libro in biblioteca"),
                         fecha: lectivo(5, hora: 13 * 60 + 35)),
        ]
    }

    static func siempre() -> [String] {
        [L("Estuche", "Pencil case", "Astuccio"), L("Agenda", "Planner", "Diario"),
         L("Almuerzo", "Snack", "Merenda"), L("Botella de agua", "Water bottle", "Borraccia")]
    }

    static func datosCompletos(escala: EscalaNotas, franjas: [Franja] = Franja.porDefecto) -> DatosEscolares {
        let a = asignaturas(completas: true)
        var d = DatosEscolares()
        d.asignaturas = a
        d.franjas = franjas
        d.horario = horario(a, franjas: franjas)

        d.pruebas = pruebas(a)
        d.temasDeAhora = temasDeAhora(a)
        d.examenesEnPruebas = true
        d.vacaciones = vacaciones()
        d.actividades = actividades()
        d.recordatorios = recordatorios()
        d.siempre = siempre()
        return d
    }

    static var nombreHijo: String { L("Lucía", "Emma", "Giulia") }

    static func hijo(nombre: String? = nil, escala: EscalaNotas) -> Hijo {
        var datos = datosCompletos(escala: escala)

        if let dia = datos.diaMochila() {
            datos.mochilaMarcada[DatosEscolares.clave(dia)] = Set(datos.itemsMochila(para: dia).map(\.id))
        }
        let n = (nombre?.isEmpty == false ? nombre : nil) ?? nombreHijo
        let cal = calendarioActual
        func hace(_ horas: Double) -> Date { Reloj.ahora.addingTimeInterval(-horas * 3600) }
        var avisos: [Aviso] = []
        if let p = datos.pruebas.first(where: { $0.fecha > Reloj.ahora && $0.llenos(cal: cal) > 0 }),
           let t = p.temas.first(where: { $0.luna(cal: cal) == .llena }) {
            avisos.append(Aviso(tipo: .luna, fecha: hace(20), texto: L("Luna llena en «\(t.nombre)»", "Full moon on “\(t.nombre)”", "Luna piena su «\(t.nombre)»")))
        }
        if let p = datos.pruebas.filter({ $0.fecha > Reloj.ahora }).min(by: { $0.fecha < $1.fecha }) {
            let materia = datos.asignatura(p.asignaturaID)?.nombre ?? p.tipo.nombre
            avisos.append(Aviso(tipo: .prueba, fecha: hace(26),
                                texto: L("Prueba de \(materia) el \(Formato.diaSemana(p.fecha))", "\(materia) test on \(Formato.diaSemana(p.fecha))", "Verifica di \(materia) \(Formato.diaSemana(p.fecha))")))
        }
        avisos.append(Aviso(tipo: .mochila, fecha: hace(14),
                            texto: L("Ha preparado la mochila", "Packed the backpack", "Ha preparato lo zaino")))
        avisos.sort { $0.fecha > $1.fecha }
        return Hijo(nombre: n, curso: L("2.º ESO", "8th grade", "2ª media"), colorAvatar: .naranja, datos: datos, avisos: avisos)
    }

    static func cargarEjemplo(_ almacen: Almacen) {
        let siempre = almacen.datos.siempre
        almacen.datos = datosCompletos(escala: almacen.ajustes.escala, franjas: almacen.datos.franjas)
        if !siempre.isEmpty { almacen.datos.siempre = siempre }
    }
}
