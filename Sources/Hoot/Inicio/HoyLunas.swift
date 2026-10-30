import SwiftUI

enum MomentoHoy {

    case manana

    case tarde

    case noche

    static let empiezaNoche = 20 * 60 + 30

    static func de(_ ahora: Date, datos: DatosEscolares) -> MomentoHoy {
        let m = DatosEscolares.minutos(ahora)
        if m >= empiezaNoche || m < 5 * 60 { return .noche }
        if let ultima = datos.clases(en: ahora).last { return m < ultima.fin ? .manana : .tarde }
        return m < 12 * 60 ? .manana : .tarde
    }
}

struct HoyLunas: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dynamicTypeSize) private var letra
    @State private var repaso: PeticionRepaso?
    @State private var temaAbierto: UUIDIdentificable?
    @State private var escuchando = false
    @State private var simulacroDe: UUID?

    @State private var apuntando = ModoCapturas.activo && ModoCapturas.pantalla == "apuntar-tema"
    @State private var eligiendoRepasito = ModoCapturas.activo && ModoCapturas.pantalla == "repasito"
    @State private var pendiente: PeticionRepaso?
    @State private var borrandoTema: Biblioteca.Entrada?

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { contexto in
                let ahora = Reloj.desde(contexto.date)
                let datos = almacen.datosConCalendario
                let momento = MomentoHoy.de(ahora, datos: datos)
                let plan = almacen.datos.planRepaso(ajustes: almacen.ajustes, ahora: ahora)
                let enMarcha = almacen.datos.biblioteca(ahora: ahora, conPasadas: false)
                let grupos = Biblioteca.porAsignatura(enMarcha)
                ScrollView {
                    VStack(alignment: .leading, spacing: Diseno.huecoTarjetas) {

                        if !grupos.isEmpty {
                            CieloDeTemas(grupos: grupos.prefix(CieloDeTemas.maximoAsignaturas).map { g in
                                             (almacen.datos.asignatura(g.asignaturaID), Array(g.temas.prefix(CieloDeTemas.maximoTemas)))
                                         },
                                         hayMas: grupos.count > CieloDeTemas.maximoAsignaturas || grupos.contains { $0.temas.count > CieloDeTemas.maximoTemas },
                                         abrir: { temaAbierto = UUIDIdentificable(id: $0) },
                                         repasar: { repaso = PeticionRepaso(temaIDs: [$0], mezclado: false) },
                                         borrar: { borrandoTema = $0 },
                                         verTodos: { almacen.pestana = .pruebas })
                        }
                        cabecera(momento, datos: datos, plan: plan, ahora: ahora, enMarcha: enMarcha)
                            .padding(.bottom, 2)
                        botones(seguir: paraSeguir(plan: plan, enMarcha: enMarcha, ahora: ahora))
                            .padding(.bottom, 2)
                        ForEach(almacen.vinculos.filter { !$0.aceptado }) { v in
                            TarjetaFamiliaPide(vinculo: v)
                        }
                        TarjetaAvisosAmigos()
                        switch momento {
                        case .manana:
                            if let p = pruebaDeHoy(datos, ahora: ahora) {
                                TarjetaPruebaHoy(prueba: p, datos: datos) {
                                    ReproductorHoot.compartido.reproducir(temas: p.temas.filter { !$0.textoLeido.isEmpty }.map(\.id), almacen: almacen)
                                    escuchando = true
                                }
                            }
                            if let dia = datos.diaMochila(ahora: ahora) {
                                TarjetaMochilaDia(dia: dia, datos: datos, ahora: ahora)
                            }
                            TarjetaClasesHoy(datos: datos, ahora: ahora)
                            TarjetaAcordarse(datos: datos, ahora: ahora, titulo: L("Hoy", "Today", "Oggi"))
                        case .tarde:
                            let simulacroHoy = plan.sesiones(en: ahora, cal: calendarioActual).first(where: \.simulacro)
                            let proximaHoy = proximaPrueba(datos, ahora: ahora)
                            if let s = simulacroHoy, s.pruebaID != proximaHoy?.id,
                               let p = almacen.datos.pruebas.first(where: { $0.id == s.pruebaID }) {
                                TarjetaSimulacroHoy(prueba: p, sesion: s, datos: datos) { simulacroDe = p.id }
                            }

                            let simulacroDeLaProxima = simulacroHoy.flatMap { $0.pruebaID == proximaHoy?.id ? $0 : nil }
                            if let p = proximaHoy, let s = simulacroDeLaProxima {
                                TarjetaProximaPrueba(prueba: p, plan: plan, datos: datos, ahora: ahora, simulacro: s) { simulacroDe = p.id }
                            }

                            TarjetaRepasoHoy(plan: plan, datos: almacen.datos, ahora: ahora,
                                             secundario: true,
                                             empezar: { repaso = $0 }, fotos: { temaAbierto = UUIDIdentificable(id: $0) })
                            if let p = proximaHoy, simulacroDeLaProxima == nil {
                                TarjetaProximaPrueba(prueba: p, plan: plan, datos: datos, ahora: ahora)
                            }
                            TarjetaAcordarse(datos: datos, ahora: ahora, titulo: L("Para acordarse", "Don't forget", "Da ricordare"))
                        case .noche:
                            if let dia = datos.diaMochila(ahora: ahora) {
                                TarjetaMochilaDia(dia: dia, datos: datos, ahora: ahora)
                            }
                            if let tema = temaDeLaNoche(almacen.datos, ahora: ahora) {
                                TarjetaPreguntaNoche(tema: tema, datos: almacen.datos) {
                                    repaso = PeticionRepaso(temaIDs: [tema.id], mezclado: true, porTema: 1)
                                }
                            }
                            if let p = proximaPrueba(datos, ahora: ahora), p.diasQueFaltan(desde: ahora, cal: calendarioActual) == 1 {
                                TarjetaProximaPrueba(prueba: p, plan: plan, datos: datos, ahora: ahora)
                            }
                        }
                    }
                    .padding(.horizontal, Diseno.margenTarjeta)
                    .padding(.bottom, 30)
                    .environment(\.colorScheme, .dark)
                    .environment(\.sobreCielo, true)
                    .environment(\.cieloSinVelo, true)
                }
                .scrollIndicators(.hidden)
                .background { FondoTiempo(sinVelo: true) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { BotonCalendario() }
                ToolbarItem(placement: .principal) {
                    Text(Formato.diaLargo(Reloj.ahora).uppercased(with: localeActual))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.22), radius: 7)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .conBotonCuenta()
            .navigationDestination(for: RutaPruebas.self) { r in
                switch r {
                case .cielo: TuCielo()
                case .prueba(let id): PruebaDetalle(id: id)
                case .asignatura(let id): AsignaturaTemasVista(asignaturaID: id)
                }
            }
            .fullScreenCover(item: $repaso) { r in
                RepasoTemas(peticion: r) { repaso = nil }
            }
            .sheet(isPresented: $escuchando) { EscuchaloVista() }
            .simulacro(de: $simulacroDe)
            .onChange(of: almacen.empezarRepasoHoy, initial: true) { _, si in
                guard si else { return }
                almacen.empezarRepasoHoy = false
                empezarDesdeWidget()
            }
            .sheet(item: $temaAbierto) { t in
                TemaHoja(temaID: t.id) { ids in
                    temaAbierto = nil
                    repaso = PeticionRepaso(temaIDs: ids, mezclado: false)
                }
            }
            .sheet(isPresented: $apuntando) { ApuntarTema() }
            .sheet(isPresented: $eligiendoRepasito, onDismiss: {
                if let p = pendiente { pendiente = nil; repaso = p }
            }) {
                ElegirTemas(para: .repasito, asignaturaInicial: nil) { pendiente = $0 }
            }
            .confirmationDialog(L("¿Borrar «\(borrandoTema?.tema.nombre ?? "")»?", "Delete “\(borrandoTema?.tema.nombre ?? "")”?",
                                  "Eliminare «\(borrandoTema?.tema.nombre ?? "")»?"),
                                isPresented: Binding(get: { borrandoTema != nil }, set: { if !$0 { borrandoTema = nil } }),
                                titleVisibility: .visible, presenting: borrandoTema) { e in
                Button(L("Borrar el tema", "Delete Topic", "Elimina l'argomento"), role: .destructive) {
                    conMuelle { almacen.datos.borrarTema(e.id) }
                }
            } message: { _ in
                Text(L("Se borran sus fotos y su luna. No se puede deshacer.", "Its photos and its moon are deleted. This can't be undone.",
                       "Si cancellano le sue foto e la sua luna. Non si può annullare."))
            }
        }
    }

    private func botones(seguir: (titulo: String, peticion: PeticionRepaso)?) -> some View {
        let disposicion = letra.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return disposicion {
            Button { apuntando = true } label: {
                BaldosaInicio(titulo: L("Tema", "Topic", "Argomento"), simbolo: "plus.viewfinder")
            }
            .botonAmbar()
            .buttonBorderShape(.roundedRectangle(radius: Diseno.radioModulo))
            .accessibilityLabel(L("Apuntar un tema", "Add a topic", "Aggiungi un argomento"))
            Button { eligiendoRepasito = true } label: {
                BaldosaInicio(titulo: L("Repasito", "Quick Review", "Ripassino"), simbolo: "bolt.fill", detalle: "5 min")
                    .foregroundStyle(.white)
            }
            .botonTenido()
            Button { if let s = seguir { repaso = s.peticion } } label: {
                BaldosaInicio(titulo: L("Seguir", "Continue", "Continua"), simbolo: "play.fill", detalle: seguir?.titulo)
                    .foregroundStyle(.white)
            }
            .botonTenido()
            .disabled(seguir == nil)
        }
        .environment(\.tonoCielo, TonoCielo.actual(almacen))
        .chocable(.caja(radio: Diseno.radioModulo), reacciona: true)
    }

    private func paraSeguir(plan: PlanRepaso, enMarcha: [Biblioteca.Entrada], ahora: Date) -> (titulo: String, peticion: PeticionRepaso)? {
        let cal = calendarioActual
        let datos = almacen.datos
        for s in plan.sesiones(en: ahora, cal: cal) where !s.simulacro {
            let ids = s.temaIDs.filter { id in datos.tema(id).map { !$0.textoLeido.isEmpty && !$0.practicado(ahora, cal: cal) } ?? false }
            if let primero = ids.first.flatMap({ datos.tema($0) }) {
                return (primero.nombre, PeticionRepaso(temaIDs: ids, mezclado: s.mezclada))
            }
        }
        if let e = Biblioteca.paraSeguir(enMarcha, cal: cal) {
            return (e.tema.nombre, PeticionRepaso(temaIDs: [e.id], mezclado: false))
        }
        return nil
    }

    private func empezarDesdeWidget() {
        let cal = calendarioActual
        let plan = almacen.datos.planRepaso(ajustes: almacen.ajustes, ahora: Reloj.ahora)
        let hoy = plan.sesiones(en: Reloj.ahora, cal: cal)
        if let s = hoy.first(where: \.simulacro), let id = s.pruebaID {
            simulacroDe = id
            return
        }
        for s in hoy {
            let ids = s.temaIDs.filter { almacen.datos.tema($0).map { !$0.textoLeido.isEmpty } ?? false }
            if !ids.isEmpty {
                repaso = PeticionRepaso(temaIDs: ids, mezclado: s.mezclada)
                return
            }
        }
    }

    private func cabecera(_ momento: MomentoHoy, datos: DatosEscolares, plan: PlanRepaso, ahora: Date,
                          enMarcha: [Biblioteca.Entrada]) -> some View {
        let cal = calendarioActual
        let (frase, gesto, saludo) = loQueDice(momento, datos: datos, plan: plan, ahora: ahora, cal: cal, enMarcha: enMarcha)
        let cielo = CieloDelCurso(datos: almacen.datos, cal: cal)
        return VStack(alignment: .trailing, spacing: 0) {

            if momento == .noche, let c = cielo.constelaciones.first, c.encendidas > 0 {
                NavigationLink(value: RutaPruebas.cielo) {
                    VStack(alignment: .trailing, spacing: 2) {
                        ConstelacionTemas(cuantas: max(c.estrellas.count, 2), encendidas: c.encendidas)
                            .frame(width: 170, height: 58)
                        Text(cielo.encendidas == 1 ? L("1 estrella", "1 star", "1 stella")
                                                   : L("\(cielo.encendidas) estrellas", "\(cielo.encendidas) stars", "\(cielo.encendidas) stelle"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(EstiloPulsar())
                .accessibilityLabel(L("Tu cielo: \(cielo.encendidas) estrellas", "Your sky: \(cielo.encendidas) stars", "Il tuo cielo: \(cielo.encendidas) stelle"))
            }
            HootDice(frase: frase, gesto: gesto, tamano: 104, loboALaDerecha: true, saludo: saludo)
        }
    }

    private func loQueDice(_ momento: MomentoHoy, datos: DatosEscolares, plan: PlanRepaso, ahora: Date,
                           cal: Calendar, enMarcha: [Biblioteca.Entrada]) -> (String, GestoLobo, GestoLobo?) {

        if enMarcha.isEmpty && pruebaDeHoy(datos, ahora: ahora) == nil { return (FrasesHoot.sinTemas(), .normal, nil) }
        if momento == .tarde, proximaPrueba(datos, ahora: ahora) == nil {
            if let e = Biblioteca.paraSeguir(enMarcha, cal: cal) { return (FrasesHoot.temaParaSeguir(tema: e.tema.nombre), .pensando, nil) }
            if !enMarcha.isEmpty && enMarcha.allSatisfy({ $0.tema.luna(cal: cal) == .llena }) { return (FrasesHoot.todoLleno(), .feliz, nil) }
        }
        switch momento {
        case .manana:
            if let p = pruebaDeHoy(datos, ahora: ahora) {
                let asig = datos.asignatura(p.asignaturaID)?.nombre ?? p.tipo.nombre
                let falta = p.temas.first { $0.luna(cal: cal) < .llena }
                return (FrasesHoot.pruebaHoy(asignatura: asig, lista: !p.temas.isEmpty && falta == nil, tema: falta?.nombre), .feliz, .saltando)
            }
            if let dia = datos.diaMochila(ahora: ahora), cal.isDate(dia, inSameDayAs: ahora) {
                let marcadas = datos.marcadas(dia)
                if let falta = datos.itemsMochila(para: dia).first(where: { !marcadas.contains($0.id) }) {
                    return (FrasesHoot.mananaFalta(cosa: falta.nombre, asignatura: falta.grupo.titulo), .normal, .saltando)
                }
                return (FrasesHoot.mananaLista(), .feliz, .saltando)
            }
            return (FrasesHoot.mananaLista(), .feliz, nil)
        case .tarde:
            guard let p = proximaPrueba(datos, ahora: ahora) else { return (FrasesHoot.sinPruebas(), .pensando, nil) }
            let asig = datos.asignatura(p.asignaturaID)?.nombre ?? p.tipo.nombre
            let dia = Formato.diaEnFrase(p.fecha, desde: ahora)
            if p.temas.allSatisfy({ $0.luna(cal: cal) == .llena }) { return (FrasesHoot.pruebaLista(asignatura: asig, dia: dia), .feliz, nil) }
            if plan.sesiones(en: ahora, cal: cal).isEmpty { return (FrasesHoot.sinRepasoHoy(), .normal, nil) }
            if let nueva = p.temas.first(where: { $0.luna(cal: cal) == .nueva }) {
                return (FrasesHoot.repasoPendiente(asignatura: asig, dia: dia, tema: nueva.nombre), .preocupado, nil)
            }
            let vacia = p.temas.min { $0.luna(cal: cal) < $1.luna(cal: cal) }
            return (FrasesHoot.repasoEnMarcha(tema: vacia?.nombre ?? asig), .normal, nil)
        case .noche:
            if let dia = datos.diaMochila(ahora: ahora) {
                let marcadas = datos.marcadas(dia)
                if datos.itemsMochila(para: dia).contains(where: { !marcadas.contains($0.id) }) {
                    return (FrasesHoot.nocheMochila(), .normal, .aullando)
                }
            }
            if temaDeLaNoche(almacen.datos, ahora: ahora) != nil { return (FrasesHoot.preguntaNoche(), .normal, .aullando) }
            return (FrasesHoot.nocheLista(), .dormido, nil)
        }
    }

    private func pruebaDeHoy(_ datos: DatosEscolares, ahora: Date) -> Prueba? {
        let cal = calendarioActual
        return datos.pruebas.filter { $0.diasQueFaltan(desde: ahora, cal: cal) == 0 }.min { $0.fecha < $1.fecha }
    }

    private func proximaPrueba(_ datos: DatosEscolares, ahora: Date) -> Prueba? {
        let cal = calendarioActual
        return datos.pruebas.filter { $0.diasQueFaltan(desde: ahora, cal: cal) > 0 && !$0.temas.isEmpty }.min { $0.fecha < $1.fecha }
    }

    private func temaDeLaNoche(_ datos: DatosEscolares, ahora: Date) -> Tema? {
        let cal = calendarioActual
        let futuras = datos.pruebas.filter { $0.diasQueFaltan(desde: ahora, cal: cal) > 0 }.flatMap(\.temas)
        let candidatos = (futuras + datos.temasDeAhora.filter(\.activo).map(\.tema))
            .filter { !$0.textoLeido.isEmpty && !$0.practicado(ahora, cal: cal) }
        let mejores = candidatos.filter { (.cuarto ... .gibosa).contains($0.luna(cal: cal)) }
        let lista = (mejores.isEmpty ? candidatos.filter { $0.luna(cal: cal) < .llena } : mejores).sorted { $0.nombre < $1.nombre }
        guard !lista.isEmpty else { return nil }
        return lista[FrasesHoot.hoy % lista.count]
    }
}

private struct TarjetaFamiliaPide: View {
    var vinculo: Vinculo
    @Environment(Almacen.self) private var almacen
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        TarjetaCielo(titulo: L("Tu familia", "Your family", "La tua famiglia"), simbolo: "figure.and.child.holdinghands") {
            VStack(alignment: .leading, spacing: 12) {
                Text(L("\(vinculo.nombre) quiere ver tus pruebas, tu calendario y tu mochila.",
                       "\(vinculo.nombre) wants to see your tests, calendar and backpack.",
                       "\(vinculo.nombre) vuole vedere verifiche, calendario e zaino."))
                    .font(.body)
                let disposicion = letra.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
                disposicion {
                    Button {
                        Task { await FamiliaNube.compartida.quitar(vinculo, almacen: almacen) }
                    } label: {
                        Text(L("Rechazar", "Decline", "Rifiuta")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    Button {
                        Task { await FamiliaNube.compartida.aceptar(vinculo, almacen: almacen) }
                    } label: {
                        Text(L("Aceptar", "Accept", "Accetta")).frame(maxWidth: .infinity)
                    }
                    .botonAmbar()
                }
                .controlSize(.large)
            }
            .padding(.vertical, 12)
        }
    }
}

private struct TarjetaSimulacroHoy: View {
    var prueba: Prueba
    var sesion: SesionRepaso
    var datos: DatosEscolares
    var empezar: () -> Void
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        let cal = calendarioActual
        let asig = datos.asignatura(prueba.asignaturaID)
        TarjetaCielo(titulo: L("Simulacro", "Mock test", "Simulazione"), simbolo: "checklist") {
            let disposicion = letra.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
            disposicion {
                IconoAsignatura(asignatura: asig, lado: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(asig?.nombre ?? prueba.tipo.nombre).font(.headline)
                    Text(L("La prueba del \(Formato.diaSemana(prueba.fecha)), entera", "\(Formato.diaSemana(prueba.fecha).conMayuscula)'s test, all of it",
                           "La verifica di \(Formato.diaSemana(prueba.fecha)), intera"))
                        .font(.subheadline)
                        .foregroundStyle(EstiloSecundario())
                }
                if !letra.isAccessibilitySize { Spacer(minLength: 8) }
                FilaLunas(partes: prueba.temas.prefix(6).map { $0.luna(cal: cal).fraccion }, tamano: 18, hueco: 3)
            }
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
            Button(action: empezar) {
                HStack {
                    Text(L("Empezar el simulacro", "Start the mock test", "Inizia la simulazione"))
                    Spacer()
                    Text(L("\(sesion.minutos) min", "\(sesion.minutos) min", "\(sesion.minutos) min")).monospacedDigit()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
            }
            .botonAmbar()
            .controlSize(.large)
            .chocable(.capsula, reacciona: true)
            .padding(.bottom, 12)
        }
    }
}

private struct TarjetaPruebaHoy: View {
    var prueba: Prueba
    var datos: DatosEscolares

    var escuchar: () -> Void
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        let cal = calendarioActual
        let asig = datos.asignatura(prueba.asignaturaID)
        TarjetaCielo(titulo: L("Hoy hay prueba", "Test today", "Oggi c'è verifica"), simbolo: "moonphase.first.quarter") {
            let disposicion = letra.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
            disposicion {
                IconoAsignatura(asignatura: asig, lado: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(asig?.nombre ?? prueba.tipo.nombre).font(.headline)
                    Text("\(prueba.tipo.nombre) · \(Formato.hora(prueba.fecha))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(EstiloSecundario())
                }
                if !letra.isAccessibilitySize { Spacer(minLength: 8) }
                FilaLunas(partes: prueba.temas.prefix(6).map { $0.luna(cal: cal).fraccion }, tamano: 18, hueco: 3)
            }
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
            if prueba.temas.contains(where: { !$0.textoLeido.isEmpty }) {
                Button(action: escuchar) {
                    Label(L("Escúchalo de camino", "Listen on the way", "Ascoltalo per strada"), systemImage: "headphones")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(.white.opacity(0.6))
                .foregroundStyle(.white)
                .chocable(.capsula, reacciona: true)
                .padding(.bottom, 12)
            }
        }
    }
}

private struct TarjetaMochilaDia: View {
    var dia: Date
    var datos: DatosEscolares
    var ahora: Date
    @Environment(Almacen.self) private var almacen

    var body: some View {
        let cal = calendarioActual
        let items = datos.itemsMochila(para: dia)
        let marcadas = datos.marcadas(dia)
        let faltan = items.filter { !marcadas.contains($0.id) }
        let esHoy = cal.isDate(dia, inSameDayAs: ahora)
        let titulo = esHoy ? L("Hoy llevas", "Today you need", "Oggi porti")
                           : L("\(Formato.diaRelativo(dia, desde: ahora)) llevas", "\(Formato.diaRelativo(dia, desde: ahora)) you need",
                               "\(Formato.diaRelativo(dia, desde: ahora)) porti")
        TarjetaCielo(titulo: titulo, simbolo: "backpack.fill",
                     accion: (faltan.isEmpty ? L("Lista", "Ready", "Pronto") : L("Faltan \(faltan.count)", "\(faltan.count) left", "Mancano \(faltan.count)"),
                              { almacen.pestana = .mochila })) {
            if faltan.isEmpty {
                Label(L("Todo dentro", "Everything's in", "Tutto dentro"), systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(faltan.prefix(4).enumerated()), id: \.element.id) { n, item in
                    if n > 0 { Separador() }
                    Button {
                        conMuelle { almacen.alternarMochila(item.id, dia: dia) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.simbolo)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(item.colores.first?.color ?? .white)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.nombre).font(.headline).foregroundStyle(.white)
                                Text(item.grupo.titulo).font(.subheadline).foregroundStyle(EstiloSecundario())
                            }
                            Spacer(minLength: 8)
                            Circle().strokeBorder(.white.opacity(0.7), lineWidth: 2).frame(width: 26, height: 26)
                        }
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(EstiloFilaCielo())
                    .accessibilityLabel(L("Meter \(item.nombre)", "Pack \(item.nombre)", "Metti \(item.nombre)"))
                }
                if faltan.count > 4 {
                    Text(L("y \(faltan.count - 4) más", "and \(faltan.count - 4) more", "e altri \(faltan.count - 4)"))
                        .font(.subheadline)
                        .foregroundStyle(EstiloSecundario())
                        .padding(.vertical, 8)
                } else if !marcadas.isEmpty {
                    Label(L("Lo demás ya está dentro", "The rest is already in", "Il resto è già dentro"), systemImage: "checkmark")
                        .font(.subheadline)
                        .foregroundStyle(EstiloSecundario())
                        .padding(.vertical, 8)
                }
            }
        }
    }
}

private struct TarjetaClasesHoy: View {
    var datos: DatosEscolares
    var ahora: Date

    var body: some View {
        let clases = datos.clases(en: ahora)
        let ahoraMin = DatosEscolares.minutos(ahora)
        if !clases.isEmpty {
            TarjetaCielo(titulo: L("Clases de hoy", "Today's classes", "Lezioni di oggi"), simbolo: "clock") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(clases) { c in
                            let asig = datos.asignatura(c.asignaturaID)
                            let ya = ahoraMin >= c.fin
                            let ahoraEs = ahoraMin >= c.inicio && ahoraMin < c.fin
                            VStack(spacing: 6) {
                                Text(Formato.hora(c.inicio)).font(.footnote.weight(.semibold).monospacedDigit())
                                IconoAsignatura(asignatura: asig, lado: 36).opacity(ya ? 0.5 : 1)

                                let nombre = asig?.nombre ?? ""
                                Text(nombre)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(nombre.contains(" ") ? 2 : 1)
                                    .minimumScaleFactor(0.6)
                                    .allowsTightening(true)
                                    .foregroundStyle(EstiloSecundario())
                            }
                            .frame(width: 70)
                            .padding(.vertical, 8)
                            .background(ahoraEs ? .white.opacity(Diseno.resalteHoy) : .clear,
                                        in: RoundedRectangle(cornerRadius: Diseno.radioResalte, style: .continuous))
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }
}

private struct TarjetaAcordarse: View {
    var datos: DatosEscolares
    var ahora: Date
    var titulo: String
    @Environment(Almacen.self) private var almacen

    var body: some View {
        let cal = calendarioActual
        let recordatorios = datos.recordatorios.filter { !$0.hecho && cal.isDate($0.fecha, inSameDayAs: ahora) }.sorted { $0.fecha < $1.fecha }
        let ahoraMin = DatosEscolares.minutos(ahora)
        let actividades = datos.actividades(en: ahora).filter { ($0.fin ?? 24 * 60) > ahoraMin }
        if !recordatorios.isEmpty || !actividades.isEmpty {
            TarjetaCielo(titulo: titulo, simbolo: "bell.fill") {
                ForEach(Array(actividades.enumerated()), id: \.element.id) { n, a in
                    if n > 0 { Separador() }
                    HStack(spacing: 12) {
                        Image(systemName: a.simbolo)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(a.color.color)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(a.titulo).font(.headline)
                            Text(cuando(a, ahoraMin: ahoraMin)).font(.subheadline.monospacedDigit()).foregroundStyle(EstiloSecundario())
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 9)
                    .accessibilityElement(children: .combine)
                }
                ForEach(Array(recordatorios.enumerated()), id: \.element.id) { n, r in
                    if n > 0 || !actividades.isEmpty { Separador() }
                    Button {
                        conMuelle { almacen.alternarRecordatorio(r.id) }
                    } label: {
                        HStack(spacing: 12) {
                            Circle().strokeBorder(.white.opacity(0.7), lineWidth: 2).frame(width: 26, height: 26).frame(width: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(r.titulo).font(.headline).foregroundStyle(.white)
                                if r.conHora {
                                    Text(Formato.hora(r.fecha)).font(.subheadline.monospacedDigit()).foregroundStyle(EstiloSecundario())
                                }
                            }
                            Spacer(minLength: 8)
                            if r.origen == .familia {
                                Label(L("De tu familia", "From family", "Dalla famiglia"), systemImage: "person.2.fill")
                                    .font(.caption.weight(.semibold))
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 9)
                                    .background(.white.opacity(0.16), in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(EstiloFilaCielo())
                }
            }
        }
    }

    private func cuando(_ a: Actividad, ahoraMin: Int) -> String {
        guard let inicio = a.inicio else { return L("Todo el día", "All day", "Tutto il giorno") }
        if inicio <= ahoraMin { return L("Ahora", "Now", "Adesso") }
        return L("\(Formato.hora(inicio)) · en \(Formato.duracionCorta(minutos: inicio - ahoraMin))",
                 "\(Formato.hora(inicio)) · in \(Formato.duracionCorta(minutos: inicio - ahoraMin))",
                 "\(Formato.hora(inicio)) · tra \(Formato.duracionCorta(minutos: inicio - ahoraMin))")
    }
}

private struct TarjetaRepasoHoy: View {
    var plan: PlanRepaso
    var datos: DatosEscolares
    var ahora: Date

    var secundario = false
    var empezar: (PeticionRepaso) -> Void
    var fotos: (UUID) -> Void

    var body: some View {
        let cal = calendarioActual
        let sesiones = plan.sesiones(en: ahora, cal: cal).filter { !$0.simulacro }
        let temas = sesiones.flatMap(\.temaIDs).reduce(into: [UUID]()) { if !$0.contains($1) { $0.append($1) } }.compactMap { datos.tema($0) }
        let minutos = sesiones.reduce(0) { $0 + $1.minutos }
        if !sesiones.isEmpty {
            TarjetaCielo(titulo: L("Repaso de hoy", "Today's review", "Ripasso di oggi"), simbolo: "moonphase.first.quarter",
                         accion: nil) {
                ForEach(Array(temas.prefix(4).enumerated()), id: \.element.id) { n, t in
                    if n > 0 { Separador() }
                    let asig = datos.prueba(deTema: t.id).flatMap { datos.asignatura($0.asignaturaID) }
                        ?? datos.temasDeAhora.first { $0.tema.id == t.id }.flatMap { datos.asignatura($0.asignaturaID) }
                    HStack(spacing: 12) {
                        Luna(parte: t.luna(cal: cal).fraccion, tamano: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.nombre).font(.headline)
                            Text([asig?.nombre, EstadoLuna.texto(t, cal: cal)].compactMap { $0 }.joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundStyle(EstiloSecundario())
                        }
                        Spacer(minLength: 8)
                        if t.textoLeido.isEmpty {
                            Button { fotos(t.id) } label: { Image(systemName: "camera.fill").foregroundStyle(.white) }
                                .buttonStyle(.glass)
                                .buttonBorderShape(.circle)
                                .accessibilityLabel(L("Fotos de \(t.nombre)", "Photos for \(t.nombre)", "Foto di \(t.nombre)"))
                        }
                    }
                    .padding(.vertical, 9)
                }
                Button {
                    let primera = sesiones.first { s in s.temaIDs.contains { id in datos.tema(id).map { !$0.textoLeido.isEmpty } ?? false } }
                    if let s = primera {
                        empezar(PeticionRepaso(temaIDs: s.temaIDs.filter { id in datos.tema(id).map { !$0.textoLeido.isEmpty } ?? false },
                                               mezclado: s.mezclada))
                    } else if let t = temas.first {
                        fotos(t.id)
                    }
                } label: {
                    HStack {
                        Text(L("Empezar", "Start", "Inizia"))
                        Spacer()
                        Text(L("\(minutos) min", "\(minutos) min", "\(minutos) min")).monospacedDigit()
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .modifier(BotonDeTarjeta(principal: !secundario))
                .controlSize(.large)
                .chocable(.capsula, reacciona: true)
                .padding(.vertical, 12)
            }
        }
    }
}

private struct BotonDeTarjeta: ViewModifier {
    var principal: Bool

    func body(content: Content) -> some View {
        if principal {
            content.botonAmbar()
        } else {
            content
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(.white.opacity(0.6))
                .foregroundStyle(.white)
        }
    }
}

private struct TarjetaProximaPrueba: View {
    var prueba: Prueba
    var plan: PlanRepaso
    var datos: DatosEscolares
    var ahora: Date

    var simulacro: SesionRepaso? = nil
    var empezarSimulacro: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var letra

    var body: some View {
        let cal = calendarioActual
        let asig = datos.asignatura(prueba.asignaturaID)
        let faltan = prueba.diasQueFaltan(desde: ahora, cal: cal)
        let hoy = cal.startOfDay(for: ahora)
        let dias = (0...min(max(faltan, 0), 6)).compactMap { cal.date(byAdding: .day, value: $0, to: hoy) }
        TarjetaCielo(titulo: L("Próxima prueba", "Next test", "Prossima verifica"), simbolo: "calendar") {
            let disposicion = letra.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
            disposicion {
                IconoAsignatura(asignatura: asig, lado: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(asig?.nombre ?? prueba.tipo.nombre) · \(prueba.tipo.nombre)").font(.headline)
                    Text(faltan == 1 ? L("Mañana", "Tomorrow", "Domani")
                                     : L("\(Formato.diaRelativo(prueba.fecha, desde: ahora)) · faltan \(faltan) días",
                                         "\(Formato.diaRelativo(prueba.fecha, desde: ahora)) · \(faltan) days to go",
                                         "\(Formato.diaRelativo(prueba.fecha, desde: ahora)) · mancano \(faltan) giorni"))
                        .font(.subheadline)
                        .foregroundStyle(EstiloSecundario())
                }
                if !letra.isAccessibilitySize { Spacer(minLength: 8) }
                FilaLunas(partes: prueba.temas.prefix(6).map { $0.luna(cal: cal).fraccion }, tamano: 17, hueco: 3)
            }
            .padding(.vertical, 10)
            if faltan <= 6 && !letra.isAccessibilitySize {
                HStack(spacing: 4) {
                    ForEach(dias, id: \.self) { d in
                        let esLaPrueba = cal.isDate(d, inSameDayAs: prueba.fecha)
                        let sesiones = plan.sesiones(en: d, cal: cal).filter { s in s.pruebaID == prueba.id || prueba.temas.contains { s.temaIDs.contains($0.id) } }
                        VStack(spacing: 3) {
                            Text(Formato.nombreDia(iso: DatosEscolares.diaISO(d), estilo: .narrow)).font(.caption.weight(.semibold)).foregroundStyle(EstiloSecundario())
                            Text("\(cal.component(.day, from: d))").font(.headline.monospacedDigit())
                            ZStack {
                                if esLaPrueba {
                                    Luna(parte: prueba.progreso(cal: cal), tamano: 18)
                                        .overlay(Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.4, dash: [3, 2])).foregroundStyle(Color.ambar).padding(-3))
                                } else if let s = sesiones.first {
                                    Circle().fill(Color.ambar).frame(width: s.ligera ? 7 : 11, height: s.ligera ? 7 : 11)
                                        .shadow(color: Color.ambar.opacity(0.6), radius: 4)
                                }
                            }
                            .frame(height: 22)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(cal.isDate(d, inSameDayAs: ahora) ? .white.opacity(Diseno.resalteHoy) : .clear,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.bottom, 10)
                .accessibilityHidden(true)
            }
            if let s = simulacro {
                Button(action: empezarSimulacro) {
                    HStack {
                        Label(L("Empezar el simulacro", "Start the mock test", "Inizia la simulazione"), systemImage: "checklist")
                        Spacer()
                        Text(L("\(s.minutos) min", "\(s.minutos) min", "\(s.minutos) min")).monospacedDigit()
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .botonAmbar()
                .controlSize(.large)
                .chocable(.capsula, reacciona: true)
                .padding(.bottom, 12)
            }
        }
    }
}

private struct TarjetaPreguntaNoche: View {
    var tema: Tema
    var datos: DatosEscolares
    var responder: () -> Void

    var body: some View {
        let cal = calendarioActual
        let asig = datos.prueba(deTema: tema.id).flatMap { datos.asignatura($0.asignaturaID) }
            ?? datos.temasDeAhora.first { $0.tema.id == tema.id }.flatMap { datos.asignatura($0.asignaturaID) }
        TarjetaCielo(titulo: L("La pregunta de la noche", "Tonight's question", "La domanda della sera"), simbolo: "sparkles") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Luna(parte: tema.luna(cal: cal).fraccion, tamano: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tema.nombre)
                            .font(.title3.weight(.bold))
                            .fontDesign(.rounded)
                        Text([asig?.nombre, L("una pregunta, mezclada", "one question, mixed", "una domanda, mescolata")].compactMap { $0 }
                            .joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(EstiloSecundario())
                    }
                }
                Button(action: responder) {
                    HStack {
                        Text(L("Responder", "Answer", "Rispondi"))
                        Spacer()
                        Text(L("1 min", "1 min", "1 min"))
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .botonAmbar()
                .controlSize(.large)
                .chocable(.capsula, reacciona: true)
            }
            .padding(.vertical, 12)
        }
    }
}

private struct BaldosaInicio: View {
    var titulo: String
    var simbolo: String
    var detalle: String? = nil
    @ScaledMetric(relativeTo: .subheadline) private var alto: CGFloat = 78

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: simbolo).font(.title2.weight(.semibold))
            VStack(spacing: 1) {
                Text(titulo).font(.subheadline.weight(.semibold))
                if let detalle { Text(detalle).font(.caption.weight(.medium)).opacity(0.86) }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: alto)
    }
}
