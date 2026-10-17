import SwiftUI

enum Cursos {
    static var lista: [String] {
        switch idiomaActual {
        case .es:
            ["5.º Primaria", "6.º Primaria", "1.º ESO", "2.º ESO", "3.º ESO", "4.º ESO", "1.º Bachillerato", "2.º Bachillerato", "Formación Profesional"]
        case .it:
            ["4ª elementare", "5ª elementare", "1ª media", "2ª media", "3ª media", "1ª superiore", "2ª superiore", "3ª superiore", "4ª superiore", "5ª superiore"]
        case .en:
            (4...12).map { "Grade \($0)" }
        }
    }

    static func probable(edad: Int) -> String {
        let indice: Int
        switch idiomaActual {
        case .es: indice = edad - 10
        case .it: indice = edad - 9
        case .en: indice = edad - 9
        }
        guard lista.indices.contains(indice) else { return "" }
        return lista[indice]
    }
}

struct PasoAsignaturas: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo
    @State private var opciones: [Asignatura] = []
    @State private var elegidas: Set<UUID> = []
    @State private var pidiendoNombre = false
    @State private var nombreNueva = ""

    var body: some View {
        PaginaConfig(
            simbolo: "books.vertical.fill",
            colorSimbolo: ColorHoot.naranja.color,
            titulo: L("Tus asignaturas", "Your subjects", "Le tue materie"),
            subtitulo: L("Toca las que tienes este curso.", "Tap the ones you take this year.", "Tocca quelle che hai quest'anno."),
            principal: L("Continuar", "Continue", "Continua"),
            principalActivo: !elegidas.isEmpty,
            accionPrincipal: guardar,
            secundario: L("Más tarde", "Later", "Più tardi"),
            accionSecundaria: { saltar() }
        ) {
            Section {
                ForEach(opciones) { a in
                    FilaEleccion(titulo: a.nombre, detalle: a.profesor.isEmpty ? nil : a.profesor,
                                 simbolo: a.simbolo, color: a.color, elegida: elegidas.contains(a.id)) {
                        conMuelle(Diseno.muelleRapido) {
                            if elegidas.contains(a.id) { elegidas.remove(a.id) } else { elegidas.insert(a.id) }
                        }
                    }
                }
                Button {
                    nombreNueva = ""
                    pidiendoNombre = true
                } label: {
                    Label(L("Añadir otra", "Add another", "Aggiungine un'altra"), systemImage: "plus")
                        .foregroundStyle(Color.azulConfig)
                }
            }
            .filaConfig()
        }
        .sensoryFeedback(.selection, trigger: elegidas)
        .alert(L("Nueva asignatura", "New subject", "Nuova materia"), isPresented: $pidiendoNombre) {
            TextField(L("Nombre", "Name", "Nome"), text: $nombreNueva)
            Button(L("Añadir", "Add", "Aggiungi")) { anadir() }
            Button(L("Cancelar", "Cancel", "Annulla"), role: .cancel) {}
        }
        .onAppear {
            guard opciones.isEmpty else { return }
            opciones = almacen.datos.asignaturas.isEmpty ? Demo.asignaturas(completas: false) : almacen.datos.asignaturas
            elegidas = Set(almacen.datos.asignaturas.map(\.id))
        }
    }

    private func anadir() {
        let nombre = nombreNueva.trimmingCharacters(in: .whitespaces)
        guard !nombre.isEmpty else { return }
        let usados = Set(opciones.map(\.color))
        let color = ColorHoot.allCases.first { !usados.contains($0) } ?? .gris
        let nueva = Asignatura(nombre: nombre, color: color, simbolo: "book.closed.fill")
        conMuelle {
            opciones.append(nueva)
            elegidas.insert(nueva.id)
        }
    }

    private func guardar() {
        let quedan = opciones.filter { elegidas.contains($0.id) }
        let ids = Set(quedan.map(\.id))
        almacen.datos.asignaturas = quedan
        almacen.datos.horario.removeAll { !ids.contains($0.asignaturaID) }
        almacen.datos.tareas.removeAll { t in t.asignaturaID.map { !ids.contains($0) } ?? false }
        almacen.datos.notas.removeAll { !ids.contains($0.asignaturaID) }
        flujo.avanzar(desde: .asignaturas, rol: almacen.perfil.rol)
    }

    private func saltar() {

        flujo.avanzar(desde: .horario, rol: almacen.perfil.rol)
    }
}

struct PasoHorario: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo

    var body: some View {
        HorarioCielo(enConfiguracion: true, alContinuar: { flujo.avanzar(desde: .horario, rol: almacen.perfil.rol) }, editando: true)
    }
}

struct PasoMateriales: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo

    var body: some View {
        @Bindable var almacen = almacen
        PaginaConfig(
            simbolo: "backpack.fill",
            colorSimbolo: ColorHoot.marron.color,
            titulo: L("Qué llevas a cada una", "What you bring to each", "Cosa porti per ognuna"),
            subtitulo: L("Entra en la mochila los días que tienes esa asignatura.", "It goes in your backpack on the days you have that subject.", "Entra nello zaino i giorni in cui hai quella materia."),
            principal: L("Continuar", "Continue", "Continua"),
            accionPrincipal: { flujo.avanzar(desde: .materiales, rol: almacen.perfil.rol) }
        ) {
            ForEach($almacen.datos.asignaturas) { $a in
                Section {
                    MaterialesAsignatura(asignatura: $a)
                } header: {
                    Label(a.nombre, systemImage: a.simbolo)
                        .foregroundStyle(a.color.color)
                        .font(.subheadline.weight(.semibold))
                        .textCase(nil)
                }
                .filaConfig()
            }
        }
    }
}

struct PasoCalendarios: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo
    @Environment(\.scenePhase) private var fase
    @Environment(\.openURL) private var abrirURL
    @State private var calendarios = Calendarios.compartido

    var body: some View {
        let preguntar = calendarios.permiso == .sinPreguntar
        PaginaConfig(
            simbolo: "calendar",
            colorSimbolo: ColorHoot.rojo.color,
            titulo: L("Tus calendarios", "Your calendars", "I tuoi calendari"),
            subtitulo: L("Lo que tengas en el Calendario del iPhone sale en Hoot: el del colegio, el de Google, el tuyo.",
                         "What's in your iPhone's Calendar shows up in Hoot: your school's, Google's, your own.",
                         "Quello che hai nel Calendario dell'iPhone compare in Hoot: quello della scuola, di Google, il tuo."),
            principal: preguntar ? L("Permitir el acceso", "Allow Access", "Consenti l'accesso") : L("Continuar", "Continue", "Continua"),
            accionPrincipal: {
                if preguntar { Task { await calendarios.pedirPermiso() } } else { seguir() }
            },
            secundario: preguntar ? L("Ahora no", "Not Now", "Non ora") : nil,
            accionSecundaria: seguir
        ) {
            switch calendarios.permiso {
            case .concedido:
                SeccionesCalendarios(enConfiguracion: true)
            case .denegado:
                Section {
                    Button(L("Abrir Ajustes", "Open Settings", "Apri Impostazioni")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { abrirURL(url) }
                    }
                    .foregroundStyle(Color.azulConfig)
                } footer: {
                    Text(L("En Ajustes, toca Calendarios y elige «Acceso total».", "In Settings, tap Calendars and choose “Full Access”.", "In Impostazioni, tocca Calendari e scegli «Accesso completo»."))
                }
                .filaConfig()
            case .sinPreguntar:
                EmptyView()
            }
        }
        .onAppear { calendarios.arrancar() }
        .onChange(of: fase) { _, f in if f == .active { calendarios.recargar() } }
    }

    private func seguir() { flujo.avanzar(desde: .calendarios, rol: almacen.perfil.rol) }
}

struct PasoServicios: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo

    var body: some View {
        PaginaConfig(
            simbolo: "link",
            colorSimbolo: ColorHoot.indigo.color,
            titulo: L("Conecta tus servicios", "Connect your services", "Collega i tuoi servizi"),
            subtitulo: L("Si tu colegio usa Teams, sus comunicados y citas pueden llegar solos a Hoot.",
                         "If your school uses Teams, its announcements and events can come into Hoot on their own.",
                         "Se la tua scuola usa Teams, le sue comunicazioni e i suoi appuntamenti possono arrivare da soli in Hoot."),
            principal: L("Continuar", "Continue", "Continua"),
            accionPrincipal: { flujo.avanzar(desde: .servicios, rol: almacen.perfil.rol) }
        ) {
            Section {
                NavigationLink {
                    AjusteTeams()
                } label: {
                    FilaAjuste(simbolo: AjusteCuenta.teams.simbolo, color: AjusteCuenta.teams.color, titulo: AjusteCuenta.teams.titulo,
                               valor: almacen.teams.activo ? L("Vinculado", "Linked", "Collegato") : nil)
                }
            } footer: {
                Text(L("Tu colegio tiene que dejar que Hoot lea Teams.", "Your school has to allow Hoot to read Teams.", "La tua scuola deve permettere a Hoot di leggere Teams."))
            }
            .filaConfig()
        }
    }
}
