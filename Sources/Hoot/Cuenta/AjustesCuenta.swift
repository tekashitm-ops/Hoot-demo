import SwiftUI
import CoreLocation
import LocalAuthentication
import UserNotifications

struct AjustePersonal: View {
    @Environment(Almacen.self) private var almacen

    var body: some View {
        @Bindable var almacen = almacen
        Form {
            Section {
                CampoConfig(etiqueta: L("Nombre", "First name", "Nome"), texto: $almacen.perfil.nombre, tipo: .givenName)
                CampoConfig(etiqueta: L("Apellidos", "Last name", "Cognome"), texto: $almacen.perfil.apellidos, tipo: .familyName)
                if !almacen.esFamilia {
                    DatePicker(L("Nacimiento", "Birthday", "Nascita"), selection: Binding(
                        get: { almacen.perfil.nacimiento ?? Calendar.current.date(byAdding: .year, value: -13, to: Reloj.ahora)! },
                        set: { almacen.perfil.nacimiento = $0 }
                    ), displayedComponents: .date)
                }
            }
            Section {
                LabeledContent(L("Correo", "Email", "Email"), value: almacen.perfil.correo.isEmpty ? "–" : almacen.perfil.correo)
            } footer: {
                Text(L("Es el correo con el que entras en Hoot.", "It's the email you sign in to Hoot with.", "È l'email con cui accedi a Hoot."))
            }
            if !almacen.esFamilia {
                Section {
                    CampoConfig(etiqueta: L("Colegio", "School", "Scuola"), texto: $almacen.perfil.colegio, tipo: .organizationName)
                    Picker(L("Curso", "Grade", "Classe"), selection: $almacen.perfil.curso) {
                        Text(L("Sin elegir", "Not set", "Non scelto")).tag("")
                        ForEach(Cursos.lista, id: \.self) { Text($0).tag($0) }
                        if !almacen.perfil.curso.isEmpty && !Cursos.lista.contains(almacen.perfil.curso) {
                            Text(almacen.perfil.curso).tag(almacen.perfil.curso)
                        }
                    }
                }
            }
        }
        .navigationTitle(AjusteCuenta.personal.titulo)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AjusteSeguridad: View {
    @Environment(Almacen.self) private var almacen
    @State private var faceIDDisponible = true

    var body: some View {
        @Bindable var almacen = almacen
        Form {
            Section {
                NavigationLink(L("Cambiar la contraseña", "Change Password", "Cambia password")) {
                    CambiarContrasena()
                }
                .disabled(almacen.cuenta.hash.isEmpty)
            }
            Section {
                Toggle(isOn: $almacen.ajustes.bloqueoFaceID) {
                    Label(L("Bloquear Hoot con Face ID", "Lock Hoot with Face ID", "Blocca Hoot con Face ID"), systemImage: "faceid")
                }
                .interruptorApple()
                .disabled(!faceIDDisponible)
            } footer: {
                Text(faceIDDisponible
                     ? L("Al abrir Hoot, pide tu cara o el código del iPhone.", "When Hoot opens, it asks for your face or iPhone passcode.", "All'apertura, Hoot chiede il tuo volto o il codice dell'iPhone.")
                     : L("Activa Face ID o un código en Ajustes del iPhone.", "Set up Face ID or a passcode in iPhone Settings.", "Configura Face ID o un codice nelle Impostazioni dell'iPhone."))
            }
        }
        .navigationTitle(AjusteCuenta.seguridad.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            var error: NSError?
            faceIDDisponible = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        }
    }
}

struct CambiarContrasena: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var volver
    @State private var actual = ""
    @State private var nueva = ""
    @State private var repetir = ""
    @State private var error = false
    @State private var hecho = 0

    var body: some View {
        let req = Cuentas.Requisitos(nueva)
        Form {
            Section {
                CampoConfig(etiqueta: L("Actual", "Current", "Attuale"), texto: $actual, tipo: .password, seguro: true, mayusculas: .never)
            } footer: {
                if error {
                    Text(L("La contraseña actual no es correcta.", "The current password is incorrect.", "La password attuale non è corretta."))
                        .foregroundStyle(Color.urgente)
                }
            }
            Section {
                CampoConfig(etiqueta: L("Nueva", "New", "Nuova"), texto: $nueva, tipo: .newPassword, seguro: true, mayusculas: .never)
                CampoConfig(etiqueta: L("Repetir", "Verify", "Ripeti"), texto: $repetir, tipo: .newPassword, seguro: true, mayusculas: .never)
            } footer: {
                Text(L("8 caracteres o más, con un número y una mayúscula.", "8 or more characters, with a number and an uppercase letter.", "8 caratteri o più, con un numero e una maiuscola."))
            }
        }
        .navigationTitle(L("Contraseña", "Password", "Password"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) { cambiar() }
                    .disabled(!req.cumple || nueva != repetir || actual.isEmpty)
            }
        }
        .sensoryFeedback(.error, trigger: error) { _, e in e }
        .sensoryFeedback(.success, trigger: hecho)
    }

    private func cambiar() {
        guard Cuentas.hash(actual, sal: almacen.cuenta.sal) == almacen.cuenta.hash else {
            error = true
            return
        }
        let sal = Cuentas.nuevaSal()
        almacen.cuenta.sal = sal
        almacen.cuenta.hash = Cuentas.hash(nueva, sal: sal)
        hecho += 1
        volver()
    }
}

struct AjusteFamilia: View {
    @Environment(Almacen.self) private var almacen
    @State private var renovando = false
    @State private var quitando: Hijo?
    @State private var quitandoFamiliar: Vinculo?
    @State private var conCuenta = true

    var body: some View {
        List {
            if almacen.esFamilia {
                OpcionesVincular()
                if !almacen.hijos.isEmpty {
                    Section {
                        ForEach(almacen.hijos) { h in
                            Text(h.nombre)
                                .swipeActions {
                                    Button(role: .destructive) { quitando = h } label: {
                                        Label(L("Dejar de seguir", "Unlink", "Scollega"), systemImage: "person.badge.minus")
                                    }
                                }
                        }
                    } header: {
                        Text(L("Hijos vinculados", "Linked children", "Figli collegati"))
                    }
                }
            } else {
                let pidiendo = almacen.vinculos.filter { !$0.aceptado }
                let aceptados = almacen.vinculos.filter(\.aceptado)
                if !pidiendo.isEmpty {
                    Section {
                        ForEach(pidiendo) { v in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(L("\(v.nombre) quiere ver tus pruebas, tu calendario y tu mochila.",
                                       "\(v.nombre) wants to see your tests, calendar and backpack.",
                                       "\(v.nombre) vuole vedere verifiche, calendario e zaino."))
                                HStack {
                                    Button(L("Rechazar", "Decline", "Rifiuta")) { Task { await FamiliaNube.compartida.quitar(v, almacen: almacen) } }
                                        .buttonStyle(.bordered)
                                    Button(L("Aceptar", "Accept", "Accetta")) { Task { await FamiliaNube.compartida.aceptar(v, almacen: almacen) } }
                                        .buttonStyle(.borderedProminent)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text(L("Quieren verte", "Want to see you", "Vogliono vederti"))
                    }
                }
                Section {
                    TarjetaQR(contenido: almacen.contenidoQR, codigo: almacen.codigoVinculo)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } footer: {
                    Text(conCuenta
                         ? L("Tu familia lo escanea con Hoot y, cuando lo aceptes aquí, ve tus pruebas, tu calendario y tu mochila. Lo que marques «Solo para mí» no lo ve.",
                             "Your family scans it with Hoot and, once you accept here, sees your tests, calendar and backpack. Anything marked “Just for me” stays hidden.",
                             "La tua famiglia lo scansiona con Hoot e, quando accetti qui, vede verifiche, calendario e zaino. Quello che segni «Solo per me» non lo vede.")
                         : L("Para que tu familia te vea, entra en tu cuenta (Cuenta, arriba) y confirma el correo.",
                             "For your family to see you, sign in to your account (Account, at the top) and confirm your email.",
                             "Perché la tua famiglia ti veda, accedi al tuo account (Account, in alto) e conferma l'email."))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                if !aceptados.isEmpty {
                    Section(L("Pueden verte", "Can see you", "Possono vederti")) {
                        ForEach(aceptados) { v in
                            LabeledContent(v.nombre, value: Formato.diaCorto(v.fecha))
                                .swipeActions {
                                    Button(role: .destructive) { quitandoFamiliar = v } label: {
                                        Label(L("Quitar", "Remove", "Rimuovi"), systemImage: "person.badge.minus")
                                    }
                                }
                        }
                    }
                }
                Section {
                    Button(L("Crear un código nuevo", "Create a New Code", "Crea un nuovo codice"), role: .destructive) { renovando = true }
                }
            }
        }
        .navigationTitle(AjusteCuenta.familia.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            conCuenta = ModoCapturas.activo || !FamiliaNube.compartida.disponible ? true : await FamiliaNube.compartida.conCuenta()
            await FamiliaNube.compartida.sincronizar(almacen)
        }
        .refreshable { await FamiliaNube.compartida.sincronizar(almacen) }
        .confirmationDialog(L("¿Crear un código nuevo?", "Create a new code?", "Creare un nuovo codice?"), isPresented: $renovando, titleVisibility: .visible) {
            Button(L("Crear código nuevo", "Create New Code", "Crea nuovo codice"), role: .destructive) {
                Task { await FamiliaNube.compartida.renovarCodigo(almacen) }
            }
        } message: {
            Text(L("Quien te tenga vinculado dejará de ver tus cosas.", "Anyone linked to you will stop seeing your info.", "Chi ti ha collegato smetterà di vedere le tue cose."))
        }
        .confirmationDialog(L("¿Quitar a \(quitandoFamiliar?.nombre ?? "")?", "Remove \(quitandoFamiliar?.nombre ?? "")?", "Rimuovere \(quitandoFamiliar?.nombre ?? "")?"),
                            isPresented: Binding(get: { quitandoFamiliar != nil }, set: { if !$0 { quitandoFamiliar = nil } }),
                            titleVisibility: .visible, presenting: quitandoFamiliar) { v in
            Button(L("Quitar", "Remove", "Rimuovi"), role: .destructive) {
                Task { await FamiliaNube.compartida.quitar(v, almacen: almacen) }
            }
        } message: { _ in
            Text(L("Dejará de ver tus pruebas, tu calendario y tu mochila.", "They'll stop seeing your tests, calendar and backpack.", "Smetterà di vedere verifiche, calendario e zaino."))
        }
        .confirmationDialog(L("¿Dejar de seguir a \(quitando?.nombre ?? "")?", "Unlink \(quitando?.nombre ?? "")?", "Scollegare \(quitando?.nombre ?? "")?"),
                            isPresented: Binding(get: { quitando != nil }, set: { if !$0 { quitando = nil } }),
                            titleVisibility: .visible, presenting: quitando) { h in
            Button(L("Dejar de seguir", "Unlink", "Scollega"), role: .destructive) {
                Task { await FamiliaNube.compartida.dejarDeSeguir(h, almacen: almacen) }
            }
        } message: { _ in
            Text(L("Para volver a verlo, tendrás que escanear su código otra vez.", "To see it again, you'll need to scan their code again.", "Per rivederlo dovrai scansionare di nuovo il suo codice."))
        }
    }
}

struct AjusteHorario: View {
    @Environment(Almacen.self) private var almacen

    var body: some View {
        if almacen.datos.asignaturas.isEmpty {
            ContentUnavailableView(
                L("Primero, tus asignaturas", "First, your subjects", "Prima, le tue materie"),
                systemImage: "books.vertical",
                description: Text(L("Añádelas en Asignaturas.", "Add them in Subjects.", "Aggiungile in Materie."))
            )
            .navigationTitle(AjusteCuenta.horario.titulo)
        } else {
            HorarioCielo()
        }
    }
}

struct AjusteNotas: View {
    @Environment(Almacen.self) private var almacen
    @State private var editando: Vacaciones?

    var body: some View {
        @Bindable var almacen = almacen
        Form {
            Section {
                DatePicker(L("Empieza", "Starts", "Inizia"), selection: $almacen.ajustes.inicioCurso, displayedComponents: .date)
                DatePicker(L("Termina", "Ends", "Finisce"), selection: $almacen.ajustes.finCurso, in: almacen.ajustes.inicioCurso..., displayedComponents: .date)
            }
            Section {
                ForEach(almacen.datos.vacaciones.sorted { $0.desde < $1.desde }) { v in
                    Button { editando = v } label: {
                        LabeledContent(v.nombre.isEmpty ? L("Vacaciones", "Holidays", "Vacanze") : v.nombre,
                                       value: "\(Formato.diaCorto(v.desde)) – \(Formato.diaCorto(v.hasta))")
                    }
                    .foregroundStyle(Color.primary)
                }
                .onDelete { idx in
                    let orden = almacen.datos.vacaciones.sorted { $0.desde < $1.desde }
                    let ids = Set(idx.map { orden[$0].id })
                    conMuelle { almacen.datos.vacaciones.removeAll { ids.contains($0.id) } }
                }
                Button(L("Añadir vacaciones", "Add holidays", "Aggiungi vacanze"), systemImage: "plus") {
                    let hoy = calendarioActual.startOfDay(for: Reloj.ahora)
                    editando = Vacaciones(nombre: "", desde: hoy, hasta: calendarioActual.date(byAdding: .day, value: 7, to: hoy) ?? hoy)
                }
            } header: {
                Text(L("Vacaciones", "Holidays", "Vacanze"))
            } footer: {
                Text(L("Esos días no hay clases, ni mochila, ni repasos.", "No classes, backpack or reviews on those days.",
                       "In quei giorni niente lezioni, zaino o ripassi."))
            }
        }
        .sheet(item: $editando) { v in EditorVacaciones(vacaciones: v) }
        .navigationTitle(AjusteCuenta.notas.titulo)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AjusteAvisos: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.openURL) private var abrir
    @State private var estado: UNAuthorizationStatus = .notDetermined

    var body: some View {
        @Bindable var almacen = almacen
        Form {
            if estado == .denied {
                Section {
                    Button(L("Permitir avisos en Ajustes", "Allow in Settings", "Consenti in Impostazioni")) {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { abrir(url) }
                    }
                } footer: {
                    Text(L("Los avisos de Hoot están desactivados en Ajustes del iPhone.", "Hoot notifications are turned off in iPhone Settings.", "Le notifiche di Hoot sono disattivate nelle Impostazioni dell'iPhone."))
                }
            } else {
                Section {
                    Toggle(L("Avisos", "Notifications", "Notifiche"), isOn: Binding(
                        get: { almacen.ajustes.avisos.activados },
                        set: { on in
                            if on {
                                Task {
                                    let ok = await Avisos.pedirPermiso()
                                    almacen.ajustes.avisos.activados = ok
                                    estado = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
                                }
                            } else {
                                almacen.ajustes.avisos.activados = false
                            }
                        }
                    ))
                    .interruptorApple()
                }
            }
            if almacen.ajustes.avisos.activados {
                AjustesAvisosLista(avisos: $almacen.ajustes.avisos, familia: almacen.esFamilia)
            }
        }
        .navigationTitle(AjusteCuenta.avisos.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            estado = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }
    }
}

struct AjusteMochila: View {
    var body: some View {
        ListaMateriales()
            .navigationTitle(AjusteCuenta.mochila.titulo)
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct AjusteEstudio: View {
    @Environment(Almacen.self) private var almacen
    @State private var borrando = false

    var body: some View {
        @Bindable var almacen = almacen
        let disponible = DisponibilidadIA.actual
        Form {
            Section {
                Label {
                    Text(disponible != .lista ? disponible.mensaje
                         : (ClaudeIA.activa ? L("Claude listo", "Claude ready", "Claude pronto") : L("Apple Intelligence lista", "Apple Intelligence ready", "Apple Intelligence pronta")))
                } icon: {
                    Image(systemName: disponible == .lista ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(disponible == .lista ? Color.hecho : Color.pronto)
                }
            } footer: {

                Text(ClaudeIA.activa
                     ? L("Tus preguntas y fotos se mandan a Claude (Anthropic) para contestarte. No se usan para entrenar su IA.",
                         "Your questions and photos are sent to Claude (Anthropic) to answer you. They aren't used to train its AI.",
                         "Le tue domande e foto vengono inviate a Claude (Anthropic) per risponderti. Non vengono usate per addestrare la sua IA.")
                     : L("Todo se hace en el propio iPhone: tus fotos no salen de él.", "Everything happens on your iPhone: your photos never leave it.", "Tutto avviene sull'iPhone: le tue foto non escono mai."))
            }
            Section {
                Stepper(value: $almacen.ajustes.minutosRato, in: 10...45, step: 5) {
                    LabeledContent(L("Cada rato de repaso", "Each review session", "Ogni ripasso"),
                                   value: L("\(almacen.ajustes.minutosRato) min", "\(almacen.ajustes.minutosRato) min", "\(almacen.ajustes.minutosRato) min"))
                }
            } footer: {
                Text(L("Hoot reparte los temas de cada prueba en ratos así de largos.", "Hoot splits each test's topics into sessions this long.",
                       "Hoot divide gli argomenti di ogni verifica in momenti lunghi così."))
            }
            if EdadIA.hacePermiso(perfil: almacen.perfil, region: almacen.ajustes.region) {
                SeccionPermisoIA()
            }
            Section {
                Picker(L("Al revisar", "When checking", "Quando controlli"), selection: $almacen.ajustes.modoRevision) {
                    ForEach(ModoRevision.allCases) { Text($0.nombre).tag($0) }
                }
                Picker(L("Resúmenes", "Summaries", "Riassunti"), selection: $almacen.ajustes.longitudResumen) {
                    ForEach(Longitud.allCases) { Text($0.nombre).tag($0) }
                }
            }
            if !almacen.estudios.isEmpty {
                Section {
                    Button(L("Borrar lo guardado (\(almacen.estudios.count))", "Delete saved (\(almacen.estudios.count))", "Elimina i salvati (\(almacen.estudios.count))"), role: .destructive) {
                        borrando = true
                    }
                }
            }
        }
        .navigationTitle(AjusteCuenta.estudio.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(L("¿Borrar los resúmenes, esquemas y revisiones?", "Delete summaries, outlines and reviews?", "Eliminare riassunti, schemi e revisioni?"), isPresented: $borrando, titleVisibility: .visible) {
            Button(L("Borrar", "Delete", "Elimina"), role: .destructive) { conMuelle { almacen.estudios.removeAll() } }
        } message: {
            Text(L("No se puede deshacer.", "This can't be undone.", "Non si può annullare."))
        }
    }
}

struct AjusteFondo: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.openURL) private var abrir

    var body: some View {
        @Bindable var almacen = almacen
        let real = almacen.ajustes.tiempoFondo == TiempoFijo.real.rawValue
        let permiso = TiempoReal.compartido.permiso
        let sinPermiso = real && (permiso == .denied || permiso == .restricted)
        Form {
            Section {
                Picker(selection: $almacen.ajustes.tiempoFondo) {
                    ForEach(TiempoFijo.allCases, id: \.self) { t in
                        Label(t.nombre, systemImage: t.simbolo).tag(t.rawValue)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.inline)
            } footer: {
                if sinPermiso {
                    Text(L("Sin permiso de ubicación, el cielo va según la hora.", "Without location access, the sky follows the time of day.", "Senza accesso alla posizione, il cielo segue l'ora."))
                } else if real {
                    Text(L("Usa la ubicación aproximada del iPhone y no la guarda.", "Uses your iPhone's approximate location and doesn't store it.", "Usa la posizione approssimativa dell'iPhone e non la salva."))
                }
            }
            if sinPermiso {
                Section {
                    Button(L("Abrir Ajustes", "Open Settings", "Apri Impostazioni")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { abrir(url) }
                    }
                }
            }
        }
        .navigationTitle(AjusteCuenta.fondo.titulo)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AjusteIdioma: View {
    @Environment(Almacen.self) private var almacen

    var body: some View {
        List {
            Section {
                Picker(L("Idioma", "Language", "Lingua"), selection: Binding(
                    get: { almacen.ajustes.idioma },
                    set: { idioma in
                        guard idioma != almacen.ajustes.idioma else { return }

                        almacen.mostrandoCuenta = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(450))
                            conMuelle { almacen.ajustes.idioma = idioma }
                        }
                    }
                )) {
                    ForEach(Idioma.allCases) { idioma in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(idioma.nombrePropio)
                            if idioma != almacen.ajustes.idioma {
                                Text(idioma.nombreTraducido).font(.subheadline).textoSecundario()
                            }
                        }
                        .tag(idioma)
                    }
                }
                .pickerStyle(.inline)
            }
            Section {
                NavigationLink {
                    SelectorRegion()
                } label: {
                    LabeledContent(L("País o región", "Country or Region", "Paese o regione"),
                                   value: localeActual.localizedString(forRegionCode: almacen.ajustes.region) ?? almacen.ajustes.region)
                }
            } footer: {
                Text(L("Cambia el primer día de la semana, los formatos y la edad para usar la IA.", "Changes the first day of the week, formats and the age to use AI.", "Cambia il primo giorno della settimana, i formati e l'età per usare l'IA."))
            }
        }
        .navigationTitle(AjusteCuenta.idioma.titulo)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SelectorRegion: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var volver
    @State private var busqueda = ""

    var body: some View {
        let loc = localeActual
        let regiones = Locale.Region.isoRegions
            .map(\.identifier)
            .filter { $0.count == 2 && $0.allSatisfy(\.isLetter) }
            .compactMap { c in loc.localizedString(forRegionCode: c).map { (c, $0) } }
            .filter { busqueda.isEmpty || $0.1.localizedStandardContains(busqueda) }
            .sorted { $0.1.compare($1.1, locale: loc) == .orderedAscending }
        List(regiones, id: \.0) { r in
            Button {
                guard r.0 != almacen.ajustes.region else { volver(); return }

                almacen.mostrandoCuenta = false
                let codigo = r.0
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    conMuelle {
                        almacen.ajustes.region = codigo
                        almacen.ajustes.escala = .para(region: codigo)
                    }
                }
            } label: {
                HStack {
                    Text(r.1).foregroundStyle(Color.primary)
                    Spacer()
                    if r.0 == almacen.ajustes.region {
                        Image(systemName: "checkmark").foregroundStyle(Color.acento).fontWeight(.semibold)
                    }
                }
            }
        }
        .searchable(text: $busqueda, prompt: L("Buscar", "Search", "Cerca"))
        .navigationTitle(L("País o región", "Country or Region", "Paese o regione"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AjusteDatos: View {
    @Environment(Almacen.self) private var almacen
    @State private var borrando = false
    @State private var borrandoCuenta = false
    @State private var errorCuenta: String?
    @State private var archivo: URL?
    @State private var nube = Sincronizacion.compartida
    @Bindable private var registro = Registro.compartido

    var body: some View {
        Form {
            Section {
                if let archivo {
                    ShareLink(item: archivo) {
                        Label(L("Exportar mis datos", "Export My Data", "Esporta i miei dati"), systemImage: "square.and.arrow.up")
                    }
                }
            } footer: {
                Text(L("Un archivo con tus pruebas, tu horario, tus recordatorios y tus ajustes.", "A file with your tests, timetable, reminders and settings.", "Un file con verifiche, orario, promemoria e impostazioni."))
            }
            if nube.activa || nube.deMuestra, nube.sesion != nil {

                Section {
                    Button(L("Borrar la cuenta", "Delete Account", "Elimina l'account"), role: .destructive) { borrandoCuenta = true }
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("Tus datos se guardan en tu cuenta de Hoot, en Google Firebase (servidores en Europa). Solo tu cuenta puede leerlos.",
                               "Your data is saved in your Hoot account, on Google Firebase (servers in Europe). Only your account can read it.",
                               "I tuoi dati sono salvati nel tuo account Hoot, su Google Firebase (server in Europa). Solo il tuo account può leggerli."))
                        if let errorCuenta { MensajeError(texto: errorCuenta) }
                    }
                }
            } else {
                Section {
                    Button(L("Borrar todos los datos", "Delete All Data", "Elimina tutti i dati"), role: .destructive) { borrando = true }
                }
            }
            Section {
                Toggle(L("Compartir errores", "Share Errors", "Condividi errori"), isOn: $registro.compartir)
                    .interruptorApple()
            } footer: {
                Text(L("Si algo falla, se manda qué ha fallado, la versión de Hoot y el modelo de iPhone, para arreglarlo. Nunca textos, fotos ni tu nombre.",
                       "If something goes wrong, what failed, the Hoot version and the iPhone model are sent so it can be fixed. Never texts, photos or your name.",
                       "Se qualcosa non va, si inviano cosa non ha funzionato, la versione di Hoot e il modello di iPhone, per sistemarlo. Mai testi, foto o il tuo nome."))
            }
            Section {
                LabeledContent(L("Versión", "Version", "Versione"), value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
            }
        }
        .navigationTitle(AjusteCuenta.datos.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .task { archivo = exportar() }
        .confirmationDialog(L("¿Borrar todos los datos?", "Delete all data?", "Eliminare tutti i dati?"), isPresented: $borrando, titleVisibility: .visible) {
            Button(L("Borrar todo", "Delete Everything", "Elimina tutto"), role: .destructive) {
                almacen.mostrandoCuenta = false
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    conMuelle(Diseno.muelleLento) { almacen.borrarTodo() }
                }
            }
        } message: {
            Text(L("Se borran tu cuenta, tus pruebas, tus lunas y tus ajustes de este iPhone, y vuelves a la configuración inicial. No se puede deshacer.",
                   "Your account, tests, moons and settings are deleted from this iPhone, and you go back to setup. This can't be undone.",
                   "Vengono eliminati account, verifiche, lune e impostazioni da questo iPhone e torni alla configurazione iniziale. Non si può annullare."))
        }
        .confirmationDialog(L("¿Borrar la cuenta?", "Delete account?", "Eliminare l'account?"), isPresented: $borrandoCuenta, titleVisibility: .visible) {
            Button(L("Borrar la cuenta", "Delete Account", "Elimina l'account"), role: .destructive) { borrarCuenta() }
        } message: {
            Text(L("Se borran tu cuenta y todo lo guardado en ella, también en este iPhone, y vuelves a la configuración inicial. No se puede deshacer.",
                   "Your account and everything saved in it are deleted, also on this iPhone, and you go back to setup. This can't be undone.",
                   "Vengono eliminati l'account e tutto ciò che contiene, anche su questo iPhone, e torni alla configurazione iniziale. Non si può annullare."))
        }
    }

    private func borrarCuenta() {
        errorCuenta = nil
        Task {
            do {
                try await Nube.compartida.borrarCuenta()
                await nube.cerrarSesion()
                almacen.mostrandoCuenta = false
                try? await Task.sleep(for: .milliseconds(400))
                conMuelle(Diseno.muelleLento) { almacen.borrarTodo() }
            } catch FalloNube.sinSesion {

                errorCuenta = L("Por seguridad, cierra sesión, vuelve a entrar y bórrala enseguida.",
                                "For security, sign out, sign back in and delete it right away.",
                                "Per sicurezza, esci, accedi di nuovo ed eliminalo subito.")
            } catch {
                errorCuenta = Sincronizacion.texto(error)
            }
        }
    }

    private func exportar() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Hoot.json")
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.prettyPrinted, .sortedKeys]
        codificador.dateEncodingStrategy = .iso8601
        struct Exportacion: Encodable {
            let perfil: Perfil
            let datos: DatosEscolares
            let estudios: [EstudioGuardado]
        }
        var perfil = almacen.perfil
        perfil.correo = almacen.perfil.correo
        guard let data = try? codificador.encode(Exportacion(perfil: perfil, datos: almacen.datos, estudios: almacen.estudios.map { var e = $0; e.miniaturas = []; return e })) else { return nil }
        try? data.write(to: url, options: .atomic)
        return url
    }
}

struct EditorVacaciones: View {
    @State var vacaciones: Vacaciones
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            Form {
                TextField(L("Nombre", "Name", "Nome"), text: $vacaciones.nombre, prompt: Text(L("Navidad", "Winter break", "Natale")))
                DatePicker(L("Desde", "From", "Dal"), selection: $vacaciones.desde, displayedComponents: .date)
                DatePicker(L("Hasta", "To", "Al"), selection: $vacaciones.hasta, in: vacaciones.desde..., displayedComponents: .date)
            }
            .navigationTitle(L("Vacaciones", "Holidays", "Vacanze"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        conMuelle {
                            if let i = almacen.datos.vacaciones.firstIndex(where: { $0.id == vacaciones.id }) {
                                almacen.datos.vacaciones[i] = vacaciones
                            } else {
                                almacen.datos.vacaciones.append(vacaciones)
                            }
                        }
                        cerrar()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct SeccionPermisoIA: View {
    @Environment(Almacen.self) private var almacen
    @State private var pidiendo = false
    @State private var confirmado = false

    var body: some View {
        Section {
            if almacen.ajustes.permisoIA {
                LabeledContent(L("Permiso de tu familia", "Family permission", "Permesso della famiglia"),
                               value: almacen.ajustes.permisoIAFecha.map { Formato.diaCorto($0) } ?? L("Dado", "Given", "Dato"))
                Button(L("Quitar el permiso", "Remove permission", "Togli il permesso"), role: .destructive) {
                    almacen.ajustes.permisoIA = false
                    almacen.ajustes.permisoIAFecha = nil
                }
            } else {
                Toggle(isOn: $confirmado) {
                    Text(L("Soy su madre, su padre o su tutor y doy permiso", "I'm their parent or guardian and I give permission",
                           "Sono sua madre, suo padre o il tutore e do il permesso"))
                }
                .interruptorApple()
                Button(L("Dar permiso", "Give permission", "Dai il permesso")) {
                    almacen.ajustes.permisoIA = true
                    almacen.ajustes.permisoIAFecha = Reloj.ahora
                    confirmado = false
                }
                .disabled(!confirmado)
            }
        } header: {
            Text(L("Permiso para la IA", "AI permission", "Permesso per l'IA"))
        } footer: {
            Text(L("Por debajo de \(EdadIA.minima(region: almacen.ajustes.region)) años, la ayuda con IA necesita el permiso de su madre, su padre o su tutor.",
                   "Under \(EdadIA.minima(region: almacen.ajustes.region)), AI help needs a parent's or guardian's permission.",
                   "Sotto i \(EdadIA.minima(region: almacen.ajustes.region)) anni, l'aiuto con l'IA richiede il permesso di un genitore o del tutore."))
        }
    }
}
