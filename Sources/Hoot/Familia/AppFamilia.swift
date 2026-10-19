import SwiftUI

struct AppFamilia: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.scenePhase) private var fase

    var body: some View {
        @Bindable var almacen = almacen
        TabView(selection: $almacen.pestana) {
            Tab(L("Hoy", "Today", "Oggi"), systemImage: "house.fill", value: Pestana.hoy) {
                InicioFamilia()
            }
            Tab(L("Calendario", "Calendar", "Calendario"), systemImage: "calendar", value: Pestana.calendario) {
                CalendarioFamilia()
            }
            Tab(L("Pruebas", "Tests", "Verifiche"), systemImage: "moonphase.first.quarter", value: Pestana.tareas) {
                PruebasFamilia()
            }
            Tab(L("Avisos", "Updates", "Avvisi"), systemImage: "bell.fill", value: Pestana.avisos) {
                AvisosVista()
            }
            .badge(almacen.hijoActivo?.avisos.filter { !$0.leido }.count ?? 0)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .sheet(isPresented: $almacen.mostrandoCuenta, onDismiss: { Desarrollo.compartido.alCerrarCuenta(almacen) }) {
            CuentaVista()
        }

        .task(id: fase) {
            guard fase == .active else { return }
            while !Task.isCancelled {
                await FamiliaNube.compartida.sincronizar(almacen)
                try? await Task.sleep(for: .seconds(5 * 60))
            }
        }
    }
}

struct PantallaFamilia<Contenido: View>: View {
    var titulo: String
    var conRecordatorio = false
    @ViewBuilder var contenido: (Hijo) -> Contenido

    @Environment(Almacen.self) private var almacen
    @State private var vinculando = false
    @State private var enviando = false

    var body: some View {
        NavigationStack {
            Group {
                if let hijo = almacen.hijoActivo, hijo.esperando {
                    ScrollView {
                        EstadoVacio(
                            texto: L("Esperando a que \(hijo.nombre) acepte en su Hoot (Cuenta > Control parental).",
                                     "Waiting for \(hijo.nombre) to accept in their Hoot (Account > Parental Controls).",
                                     "In attesa che \(hijo.nombre) accetti nel suo Hoot (Account > Controllo parentale)."),
                            gesto: .pensando,
                            accion: (L("Comprobar", "Check", "Controlla"), { Task { await FamiliaNube.compartida.sincronizar(almacen) } })
                        )
                        .padding(.top, 80)
                    }
                    .refreshable { await FamiliaNube.compartida.sincronizar(almacen) }
                } else if let hijo = almacen.hijoActivo {
                    contenido(hijo)
                } else {
                    ScrollView {
                        EstadoVacio(
                            texto: L("Vincula a tu hijo o hija para ver sus pruebas, su calendario y su mochila.",
                                     "Link your child to see their tests, calendar and backpack.",
                                     "Collega tuo figlio o tua figlia per vedere verifiche, calendario e zaino."),
                            gesto: .normal,
                            accion: (L("Vincular", "Link", "Collega"), { vinculando = true })
                        )
                        .padding(.top, 80)
                    }
                }
            }
            .navigationTitle(titulo)

            .navigationSubtitle(subtitulo)
            .toolbarTitleMenu {
                if almacen.hijos.count > 1 {
                    ForEach(almacen.hijos) { h in
                        Button {
                            conMuelle { almacen.hijoActivoID = h.id }
                        } label: {
                            if h.id == almacen.hijoActivo?.id {
                                Label(h.nombre, systemImage: "checkmark")
                            } else {
                                Text(h.nombre)
                            }
                        }
                    }
                }
            }
            .toolbar {
                if conRecordatorio, almacen.hijoActivo != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            enviando = true
                        } label: {
                            Image(systemName: "paperplane")
                        }
                        .accessibilityLabel(L("Enviar un recordatorio", "Send a reminder", "Invia un promemoria"))
                    }
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    BotonCuenta()
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .sheet(isPresented: $vinculando) {
                NavigationStack {
                    List { OpcionesVincular() }
                        .navigationTitle(L("Vincular", "Link", "Collega"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(role: .confirm) { vinculando = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $enviando) {
                EditorRecordatorio(recordatorio: Recordatorio(titulo: "", fecha: TareasVista.entregaPorDefecto()), paraHijo: true)
            }
        }
    }

    private var subtitulo: String {
        guard let hijo = almacen.hijoActivo, !hijo.esperando else { return "" }
        if hijo.uid.isEmpty { return L("Datos de ejemplo", "Sample data", "Dati di esempio") }
        guard let a = hijo.actualizado else { return "" }
        return L("Al día · \(Formato.hora(a))", "Updated · \(Formato.hora(a))", "Aggiornato · \(Formato.hora(a))")
    }
}

struct InicioFamilia: View {
    @Environment(Almacen.self) private var almacen

    var body: some View {
        PantallaFamilia(titulo: almacen.hijoActivo?.nombre ?? L("Hoy", "Today", "Oggi"), conRecordatorio: true) { hijo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 14) {
                        Avatar(tamano: 52, estilo: .iniciales, color: hijo.colorAvatar, iniciales: String(hijo.nombre.prefix(1)), foto: nil)
                        VStack(alignment: .leading, spacing: 2) {
                            if !hijo.curso.isEmpty {
                                Text(hijo.curso).font(.headline)
                            }
                            Text(Formato.diaLargo(Reloj.ahora).conMayuscula)
                                .font(.subheadline)
                                .textoSecundario()
                        }
                    }
                    .padding(.top, 8)

                    if hijo.pideSalas { PermisoSalasFamilia(hijo: hijo) }
                    PruebasDeHijo(datos: hijo.datos)
                    SeccionClases(datos: hijo.datos, alPonerHorario: nil)
                    SeccionMochila(datos: hijo.datos, soloLectura: true, alAbrir: nil)

                    if !hijo.avisos.isEmpty {
                        EncabezadoSeccion(titulo: L("Últimos avisos", "Latest updates", "Ultimi avvisi"),
                                          accion: (L("Ver todos", "See all", "Vedi tutti"), { almacen.pestana = .avisos }))
                        ForEach(Array(hijo.avisos.prefix(3).enumerated()), id: \.element.id) { i, a in
                            FilaAviso(aviso: a)
                            if i < min(3, hijo.avisos.count) - 1 { Divider().padding(.leading, 56) }
                        }
                    }
                }
                .padding(.horizontal, Diseno.margen)
                .padding(.bottom, 40)
            }
            .background(alignment: .top) { Cielo() }
            .refreshable { await FamiliaNube.compartida.sincronizar(almacen) }
        }
    }
}

struct PermisoSalasFamilia: View {
    var hijo: Hijo
    @Environment(Almacen.self) private var almacen
    @State private var mandando = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EncabezadoSeccion(titulo: L("\(hijo.nombre) quiere estudiar con amigos", "\(hijo.nombre) wants to study with friends", "\(hijo.nombre) vuole studiare con gli amici"))
            Text(L("Salas para dos con compañeros: pizarra, apuntes, chat, notas de voz y llamadas de voz dentro de Hoot. Solo se entra con un código o una invitación, y quien crea la sala deja pasar a cada uno.",
                   "Two-person rooms with classmates: board, notes, chat, voice messages and voice calls inside Hoot. You can only join with a code or an invitation, and the host lets each person in.",
                   "Stanze per due con i compagni: lavagna, appunti, chat, note vocali e chiamate vocali dentro Hoot. Si entra solo con un codice o un invito, e chi crea la stanza fa entrare ognuno."))
                .font(.subheadline)
                .textoSecundario()
            HStack(spacing: 10) {
                Button(L("Ahora no", "Not Now", "Non ora")) { contestar(false) }
                    .buttonStyle(.bordered)
                Button(L("Permitir", "Allow", "Consenti")) { contestar(true) }
                    .buttonStyle(.borderedProminent)
            }
            .disabled(mandando)
        }
        .padding(.bottom, 8)
    }

    private func contestar(_ si: Bool) {
        mandando = true
        Task {
            try? await Nube.compartida.mandarAlBuzon(uidHijo: hijo.uid, tipo: si ? "permisoSalas" : "permisoSalasNo", json: "{}", de: almacen.perfil.nombre)
            if let i = almacen.hijos.firstIndex(where: { $0.id == hijo.id }) { conMuelle { almacen.hijos[i].pideSalas = false } }
            mandando = false
        }
    }
}

struct PruebasDeHijo: View {
    var datos: DatosEscolares

    var body: some View {
        let cal = calendarioActual
        let ahora = Reloj.ahora
        let proximas = datos.pruebas.filter { $0.diasQueFaltan(desde: ahora, cal: cal) >= 0 }.sorted { $0.fecha < $1.fecha }
        VStack(alignment: .leading, spacing: 0) {
            EncabezadoSeccion(titulo: L("Próximas pruebas", "Upcoming tests", "Prossime verifiche"))
            if proximas.isEmpty {
                Text(L("Ninguna apuntada.", "None added.", "Nessuna segnata.")).textoSecundario()
            }
            ForEach(Array(proximas.prefix(3).enumerated()), id: \.element.id) { n, p in
                if n > 0 { Divider().padding(.leading, 50) }
                HStack(spacing: 12) {
                    IconoAsignatura(asignatura: datos.asignatura(p.asignaturaID), lado: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(datos.asignatura(p.asignaturaID)?.nombre ?? p.tipo.nombre).font(.headline)
                        Text("\(p.tipo.nombre) · \(Formato.diaRelativo(p.fecha, desde: ahora))")
                            .font(.subheadline)
                            .textoSecundario()
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 4) {
                        FilaLunas(partes: p.temas.prefix(6).map { $0.luna(cal: cal).fraccion }, tamano: 16, hueco: 3)
                        Text(L("\(p.llenos(cal: cal)) de \(p.temas.count)", "\(p.llenos(cal: cal)) of \(p.temas.count)", "\(p.llenos(cal: cal)) di \(p.temas.count)"))
                            .font(.caption.monospacedDigit())
                            .textoSecundario()
                    }
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

struct CalendarioFamilia: View {
    var body: some View {
        PantallaFamilia(titulo: L("Calendario", "Calendar", "Calendario"), conRecordatorio: true) { hijo in
            CalendarioContenido(datos: hijo.datos, soloLectura: true)
        }
    }
}

struct PruebasFamilia: View {
    @State private var nueva = false

    var body: some View {
        PantallaFamilia(titulo: L("Pruebas", "Tests", "Verifiche")) { hijo in
            let datos = hijo.datos
            let cal = calendarioActual
            let ahora = Reloj.ahora
            let proximas = datos.pruebas.filter { !$0.privada && $0.diasQueFaltan(desde: ahora, cal: cal) >= 0 }.sorted { $0.fecha < $1.fecha }
            List {
                if proximas.isEmpty {
                    Text(L("Sin pruebas apuntadas. Si ves una en el registro, apúntasela con «+».",
                           "No tests yet. If you see one in the school register, add it with “+”.",
                           "Nessuna verifica. Se ne vedi una sul registro, aggiungila con «+»."))
                        .foregroundStyle(Color.texto2)
                }
                ForEach(proximas) { p in
                    let asig = datos.asignatura(p.asignaturaID)
                    HStack(spacing: 12) {
                        IconoAsignatura(asignatura: asig, lado: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(asig?.nombre ?? p.tipo.nombre).font(.headline)
                            Text("\(p.tipo.nombre) · \(Formato.diaRelativo(p.fecha, desde: ahora))")
                                .font(.subheadline)
                                .foregroundStyle(Color.texto2)
                            Text(p.temas.map(\.nombre).joined(separator: ", "))
                                .font(.footnote)
                                .foregroundStyle(Color.texto2)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 4) {
                            FilaLunas(partes: p.temas.prefix(6).map { $0.luna(cal: cal).fraccion }, tamano: 16, hueco: 3)
                            Text(L("\(p.llenos(cal: cal)) de \(p.temas.count)", "\(p.llenos(cal: cal)) of \(p.temas.count)", "\(p.llenos(cal: cal)) di \(p.temas.count)"))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color.texto2)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
            .listStyle(.insetGrouped)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { nueva = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel(L("Apuntar una prueba", "Add a test", "Aggiungi una verifica"))
                }
            }
            .sheet(isPresented: $nueva) {
                NuevaPrueba(empezarCon: nil) { _ in }
            }
        }
    }
}

struct AvisosVista: View {
    @Environment(Almacen.self) private var almacen

    var body: some View {
        PantallaFamilia(titulo: L("Avisos", "Updates", "Avvisi"), conRecordatorio: true) { hijo in
            let porDia = Dictionary(grouping: hijo.avisos) { calendarioActual.startOfDay(for: $0.fecha) }
            List {
                ForEach(porDia.keys.sorted(by: >), id: \.self) { dia in
                    Section {
                        ForEach(porDia[dia] ?? []) { a in FilaAviso(aviso: a) }
                    } header: {
                        Text(Formato.diaRelativo(dia))
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                    }
                }
            }
            .listStyle(.plain)
            .onAppear {

                Task {
                    try? await Task.sleep(for: .seconds(1))
                    guard let i = almacen.hijos.firstIndex(where: { $0.id == hijo.id }) else { return }
                    for j in almacen.hijos[i].avisos.indices { almacen.hijos[i].avisos[j].leido = true }
                }
            }
        }
    }
}

struct FilaAviso: View {
    var aviso: Aviso

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: aviso.tipo.simbolo)
                .font(.body.weight(.semibold))
                .foregroundStyle(aviso.tipo.color.sobre)
                .frame(width: 36, height: 36)
                .background(aviso.tipo.color.color.gradient, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(aviso.texto)
                    .fontWeight(aviso.leido ? .regular : .semibold)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Formato.hora(aviso.fecha))
                    .font(.subheadline)
                    .textoSecundario()
            }
            Spacer(minLength: 0)
            if !aviso.leido {
                Circle().fill(Color.acento).frame(width: 9, height: 9)
                    .accessibilityLabel(L("Nuevo", "New", "Nuovo"))
            }
        }
        .padding(.vertical, 4)
    }
}
