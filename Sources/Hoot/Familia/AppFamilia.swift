import SwiftUI

struct AppFamilia: View {
    @Environment(Almacen.self) private var almacen

    var body: some View {
        @Bindable var almacen = almacen
        TabView(selection: $almacen.pestana) {
            Tab(L("Hoy", "Today", "Oggi"), systemImage: "house.fill", value: Pestana.hoy) {
                InicioFamilia()
            }
            Tab(L("Calendario", "Calendar", "Calendario"), systemImage: "calendar", value: Pestana.calendario) {
                CalendarioFamilia()
            }
            Tab(L("Tareas", "Tasks", "Compiti"), systemImage: "checklist", value: Pestana.tareas) {
                TareasFamilia()
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
                if let hijo = almacen.hijoActivo {
                    contenido(hijo)
                } else {
                    ScrollView {
                        EstadoVacio(
                            texto: L("Vincula a tu hijo o hija para ver sus tareas, su calendario y sus notas.",
                                     "Link your child to see their homework, calendar and grades.",
                                     "Collega tuo figlio o tua figlia per vedere compiti, calendario e voti."),
                            gesto: .normal,
                            accion: (L("Vincular", "Link", "Collega"), { vinculando = true })
                        )
                        .padding(.top, 80)
                    }
                }
            }
            .navigationTitle(titulo)

            .navigationSubtitle(almacen.hijoActivo == nil ? "" : L("Datos de ejemplo", "Sample data", "Dati di esempio"))
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

                    ResumenSemana(datos: hijo.datos)
                    SeccionClases(datos: hijo.datos, alPonerHorario: nil)
                    SeccionExamen(datos: hijo.datos, alEstudiar: nil)
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
        }
    }
}

struct ResumenSemana: View {
    var datos: DatosEscolares
    @ScaledMetric(relativeTo: .title3) private var ladoAnillo: CGFloat = 84

    var body: some View {
        let cal = calendarioActual
        let semana = cal.dateInterval(of: .weekOfYear, for: Reloj.ahora)

        let deLaSemana = datos.tareas.filter { t in semana.map { $0.contains(t.entrega) } ?? false }
        let hechas = deLaSemana.filter(\.hecha).count
        let atrasadas = deLaSemana.filter { !$0.hecha && $0.entrega < Reloj.ahora }.count
        VStack(alignment: .leading, spacing: 0) {
            EncabezadoSeccion(titulo: L("Esta semana", "This week", "Questa settimana"))
            HStack(spacing: 18) {
                ZStack {
                    Anillo(progreso: deLaSemana.isEmpty ? 0 : Double(hechas) / Double(deLaSemana.count), color: Color.hecho, grosor: 10)
                    Text("\(hechas)/\(deLaSemana.count)")
                        .font(.title3.bold().monospacedDigit())
                        .fontDesign(.rounded)
                        .minimumScaleFactor(0.5)
                        .padding(12)
                }
                .frame(width: min(ladoAnillo, 140), height: min(ladoAnillo, 140))
                VStack(alignment: .leading, spacing: 6) {
                    if hechas > 0 {
                        Label(Plural.tareas(hechas, hechas: true), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.hecho)
                    }
                    if atrasadas > 0 {
                        Label(Plural.atrasadas(atrasadas), systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(Color.urgente)
                    }
                    let quedan = deLaSemana.count - hechas - atrasadas
                    if quedan > 0 {
                        Label(Plural.porHacer(quedan), systemImage: "hourglass")
                            .foregroundStyle(Color.texto2)
                    }
                }
                .font(.subheadline.weight(.medium))
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
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

struct TareasFamilia: View {
    @State private var verHechas = false

    var body: some View {
        PantallaFamilia(titulo: L("Tareas", "Tasks", "Compiti")) { hijo in
            let datos = hijo.datos
            let pendientes = datos.pendientes
            let hechas = datos.tareas.filter(\.hecha).sorted { ($0.hechaEl ?? $0.entrega) > ($1.hechaEl ?? $1.entrega) }
            List {
                Section {
                    Picker(L("Mostrar", "Show", "Mostra"), selection: $verHechas.animation(Diseno.muelle)) {
                        Text(L("Por hacer · \(pendientes.count)", "To do · \(pendientes.count)", "Da fare · \(pendientes.count)")).tag(false)
                        Text(L("Hechas · \(hechas.count)", "Done · \(hechas.count)", "Fatti · \(hechas.count)")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                if verHechas {
                    ForEach(hechas) { t in
                        NavigationLink(value: RutaTarea(id: t.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                FilaTarea(tarea: t, asignatura: datos.asignatura(t.asignaturaID), soloLectura: true)
                                if let el = t.hechaEl {
                                    Text(L("Hecha \(Formato.diaRelativo(el).lowercased()) a las \(Formato.hora(el))", "Done \(Formato.diaRelativo(el).lowercased()) at \(Formato.hora(el))", "Fatto \(Formato.diaRelativo(el).lowercased()) alle \(Formato.hora(el))"))
                                        .font(.footnote)
                                        .foregroundStyle(Color.hecho)
                                        .padding(.leading, 56)
                                }
                            }
                        }
                    }
                } else {
                    ForEach(GrupoFecha.allCases) { grupo in
                        let deGrupo = pendientes.filter { GrupoFecha.de($0.entrega) == grupo }
                        if !deGrupo.isEmpty {
                            Section {
                                ForEach(deGrupo) { t in
                                    NavigationLink(value: RutaTarea(id: t.id)) {
                                        FilaTarea(tarea: t, asignatura: datos.asignatura(t.asignaturaID), soloLectura: true,
                                                  mostrarVence: grupo == .semana || grupo == .despues)
                                    }
                                }
                            } header: {
                                Text(grupo.nombre)
                                    .font(.headline)
                                    .foregroundStyle(grupo == .atrasadas ? Color.urgente : Color.primary)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationDestination(for: RutaTarea.self) { r in
                TareaDetalle(id: r.id, soloLectura: true, datosFamilia: datos)
            }
        }
    }
}

struct NotasFamilia: View {
    var body: some View {
        PantallaFamilia(titulo: L("Notas", "Grades", "Voti")) { hijo in
            List {
                NotasLista(datosFamilia: hijo.datos)
            }
            .listStyle(.plain)
            .navigationDestination(for: RutaNotas.self) { r in
                NotasAsignatura(asignaturaID: r.id, datosFamilia: hijo.datos)
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

enum Plural {
    static func tareas(_ n: Int, hechas: Bool) -> String {
        n == 1 ? L("1 tarea hecha", "1 task done", "1 compito fatto")
               : L("\(n) tareas hechas", "\(n) tasks done", "\(n) compiti fatti")
    }

    static func atrasadas(_ n: Int) -> String {
        n == 1 ? L("1 atrasada", "1 late", "1 in ritardo") : L("\(n) atrasadas", "\(n) late", "\(n) in ritardo")
    }

    static func porHacer(_ n: Int) -> String {
        L("\(n) por hacer", "\(n) to do", "\(n) da fare")
    }
}
