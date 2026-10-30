import SwiftUI

struct AppEstudiante: View {
    @State private var reproductor = ReproductorHoot.compartido
    @State private var viendoReproductor = false
    @State private var salas = Salas.compartidas
    @Environment(Almacen.self) private var almacen
    @Environment(\.scenePhase) private var fase

    var body: some View {

        if ModoCapturas.activo, ModoCapturas.pantalla == "horario" {
            NavigationStack { HorarioCielo(editando: ModoCapturas.valor("-editar") != nil) }
        } else if ModoCapturas.activo, ModoCapturas.pantalla == "lobos" {
            CatalogoLobos()
        } else {
            pestanas
        }
    }

    private var pestanas: some View {
        @Bindable var almacen = almacen
        return TabView(selection: $almacen.pestana) {

            Tab(L("Hoy", "Today", "Oggi"), systemImage: "house.fill", value: Pestana.hoy) {
                InicioVista()
                    .environment(\.pestanaVisible, almacen.pestana == .hoy)
            }
            Tab(L("Pruebas", "Tests", "Verifiche"), systemImage: "moonphase.first.quarter", value: Pestana.pruebas) {
                PruebasVista()
                    .environment(\.pestanaVisible, almacen.pestana == .pruebas)
            }
            Tab(L("Agenda", "Planner", "Diario"), systemImage: "list.bullet.clipboard.fill", value: Pestana.tareas) {
                AgendaCielo()
                    .environment(\.pestanaVisible, almacen.pestana == .tareas)
            }
            .badge(urgentes)
            Tab(L("Mochila", "Backpack", "Zaino"), systemImage: "backpack.fill", value: Pestana.mochila) {
                MochilaVista()
                    .environment(\.pestanaVisible, almacen.pestana == .mochila)
            }
            Tab(L("Estudio", "Study", "Studio"), systemImage: "graduationcap.fill", value: Pestana.estudio) {
                EstudioVista()
                    .environment(\.pestanaVisible, almacen.pestana == .estudio)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)

        .overlay {
            CapaDelanteDeLaVida()
                .ignoresSafeArea()
        }

        .task(id: TareaTiempo(fase: fase, real: almacen.ajustes.tiempoFondo == TiempoFijo.real.rawValue)) {
            guard fase == .active, almacen.ajustes.tiempoFondo == TiempoFijo.real.rawValue else { return }
            while !Task.isCancelled {
                TiempoReal.compartido.pedir()
                try? await Task.sleep(for: .seconds(30 * 60))
            }
        }

        .task(id: fase) {
            guard fase == .active else { return }
            while !Task.isCancelled {
                await FamiliaNube.compartida.sincronizar(almacen)
                try? await Task.sleep(for: .seconds(5 * 60))
            }
        }

        .task {
            let pestanas: [String: Pestana] = ["hoy": .hoy, "pruebas": .pruebas, "tareas": .tareas, "mochila": .mochila, "estudio": .estudio]
            if ModoCapturas.activo, let p = ModoCapturas.valor("-pasar").flatMap({ pestanas[$0] }) {
                try? await Task.sleep(for: .seconds(3))
                almacen.pestana = p
            }
        }

        .modifier(AccesorioOpcional(activo: reproductor.activo || (almacen.pestana != .hoy && hayClaseHoy)) {
            if reproductor.activo {
                MiniReproductor { viendoReproductor = true }
            } else {
                AccesorioClase()
            }
        })
        .sheet(isPresented: $viendoReproductor) { EscuchaloVista() }
        .sheet(item: $almacen.temaRecibido) { t in
            RecibirTemaVista(tema: t) { almacen.temaRecibido = nil }
        }
        .sheet(isPresented: $almacen.mostrandoCuenta, onDismiss: { Desarrollo.compartido.alCerrarCuenta(almacen) }) {
            CuentaVista()
        }
        .sheet(isPresented: $almacen.mostrandoCalendario) {
            CalendarioVista(enHoja: true)
                .environment(\.pestanaVisible, false)
        }

        .sheet(isPresented: $salas.entrando) { EntrarSala(codigoInicial: salas.codigoPendiente) }
        .fullScreenCover(item: $salas.abierta) { s in
            SalaVista(sala: s) { salas.abierta = nil }
        }
        .task(id: fase) {
            guard fase == .active else { salas.dejarDeMirar(); return }
            salas.empezarAMirar()
            await Salas.limpiarViejas()
        }
    }

    private var hayClaseHoy: Bool {
        let (actual, siguiente) = almacen.datos.claseAhora(Reloj.ahora)
        return actual != nil || siguiente != nil
    }

    private var urgentes: Int {
        let fin = calendarioActual.date(byAdding: .day, value: 1, to: calendarioActual.startOfDay(for: Reloj.ahora)) ?? Reloj.ahora
        return almacen.datos.recordatorios.filter { !$0.hecho && $0.fecha < fin }.count
    }
}

struct AccesorioClase: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.tabViewBottomAccessoryPlacement) private var colocacion

    var body: some View {
        TimelineView(.everyMinute) { contexto in
            let datos = almacen.datos
            let (actual, siguiente) = datos.claseAhora(Reloj.desde(contexto.date))
            let clase = actual ?? siguiente
            let asig = datos.asignatura(clase?.asignaturaID)
            Button {
                almacen.mostrandoCalendario = true
            } label: {
                HStack(spacing: 10) {
                    if let clase, let asig {
                        if actual != nil {
                            let total = Double(clase.fin - clase.inicio)
                            let hecho = Double(DatosEscolares.minutos(Reloj.desde(contexto.date)) - clase.inicio)
                            Anillo(progreso: max(0, min(1, hecho / max(total, 1))), color: asig.color.color, grosor: 3.5)
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: asig.simbolo)
                                .foregroundStyle(asig.color.color)
                                .frame(width: 24)
                        }
                        Text(asig.nombre)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if colocacion != .inline {
                            Spacer(minLength: 4)
                            Text(actual != nil
                                 ? L("hasta las \(Formato.hora(clase.fin))", "until \(Formato.hora(clase.fin))", "fino alle \(Formato.hora(clase.fin))")
                                 : L("a las \(Formato.hora(clase.inicio))", "at \(Formato.hora(clase.inicio))", "alle \(Formato.hora(clase.inicio))"))
                                .font(.subheadline.monospacedDigit())
                                .textoSecundario()
                                .lineLimit(1)
                        }
                    } else {
                        Image(systemName: "moon.stars.fill").foregroundStyle(Color.acento)
                        Text(L("Clases terminadas", "Classes are over", "Lezioni finite"))
                            .font(.subheadline.weight(.semibold))
                        if colocacion != .inline { Spacer(minLength: 0) }
                    }
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accesibilidad(actual: actual, clase: clase, asig: asig))
        }
    }

    private func accesibilidad(actual: Clase?, clase: Clase?, asig: Asignatura?) -> String {
        guard let clase, let asig else { return L("Clases terminadas", "Classes are over", "Lezioni finite") }
        if actual != nil {
            return L("Ahora: \(asig.nombre), hasta las \(Formato.hora(clase.fin))", "Now: \(asig.nombre), until \(Formato.hora(clase.fin))", "Ora: \(asig.nombre), fino alle \(Formato.hora(clase.fin))")
        }
        return L("Siguiente: \(asig.nombre), a las \(Formato.hora(clase.inicio))", "Next: \(asig.nombre), at \(Formato.hora(clase.inicio))", "Prossima: \(asig.nombre), alle \(Formato.hora(clase.inicio))")
    }
}

struct AccesorioOpcional<Contenido: View>: ViewModifier {
    var activo: Bool
    @ViewBuilder var contenido: () -> Contenido

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: activo, content: contenido)
        } else {
            content.tabViewBottomAccessory(content: contenido)
        }
    }
}

private struct TareaTiempo: Equatable {
    var fase: ScenePhase
    var real: Bool
}
