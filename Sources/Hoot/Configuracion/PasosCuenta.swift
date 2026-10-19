import SwiftUI

struct PasoIdioma: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo

    var body: some View {
        PaginaConfig(simbolo: "globe", titulo: L("Idioma", "Language", "Lingua")) {
            Section {
                ForEach(Idioma.allCases) { idioma in
                    FilaEleccion(
                        titulo: idioma.nombrePropio,
                        detalle: idioma == almacen.ajustes.idioma || idioma.nombreTraducido == idioma.nombrePropio ? nil : idioma.nombreTraducido,
                        elegida: almacen.ajustes.idioma == idioma
                    ) {
                        almacen.ajustes.idioma = idioma
                        flujo.avanzar(desde: nil, rol: almacen.perfil.rol)
                    }
                }
            }
            .filaConfig()
        }
        .navigationBarBackButtonHidden()
    }
}

struct PasoRegion: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo
    @State private var busqueda = ""

    private struct Region: Identifiable, Hashable {
        let id: String
        let nombre: String
    }

    private var regiones: [Region] {
        let loc = localeActual
        return Locale.Region.isoRegions
            .map(\.identifier)
            .filter { $0.count == 2 && $0.allSatisfy(\.isLetter) }
            .compactMap { codigo in loc.localizedString(forRegionCode: codigo).map { Region(id: codigo, nombre: $0) } }
            .sorted { $0.nombre.compare($1.nombre, locale: loc) == .orderedAscending }
    }

    private var sugerida: Region? {
        let codigo = Locale.current.region?.identifier ?? "ES"
        return regiones.first { $0.id == codigo }
    }

    var body: some View {
        let filtradas = busqueda.isEmpty
            ? regiones
            : regiones.filter { $0.nombre.localizedStandardContains(busqueda) }
        PaginaConfig(simbolo: "mappin.and.ellipse", titulo: L("País o región", "Country or Region", "Paese o regione")) {
            if busqueda.isEmpty, let sugerida {
                Section {
                    fila(sugerida)
                }
                .filaConfig()
            }
            Section {
                ForEach(filtradas) { fila($0) }
            }
            .filaConfig()
        }
        .searchable(text: $busqueda, placement: .navigationBarDrawer(displayMode: .automatic), prompt: L("Buscar", "Search", "Cerca"))
    }

    private func fila(_ r: Region) -> some View {
        FilaEleccion(titulo: r.nombre, elegida: almacen.ajustes.region == r.id) {
            almacen.ajustes.region = r.id
            almacen.ajustes.escala = .para(region: r.id)
            flujo.avanzar(desde: .region, rol: almacen.perfil.rol)
        }
    }
}

struct PasoRol: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo

    var body: some View {
        PaginaConfig(simbolo: "person.2.fill", titulo: L("¿Quién va a usar Hoot?", "Who's using Hoot?", "Chi userà Hoot?")) {
            Section {
                FilaEleccion(
                    titulo: L("Soy estudiante", "I'm a student", "Sono uno studente"),
                    detalle: L("Mis pruebas, mis clases y mi mochila", "My tests, classes and backpack", "Le mie verifiche, le lezioni e lo zaino"),
                    simbolo: "backpack.fill", color: .indigo,
                    elegida: false, conFlecha: true
                ) {
                    almacen.perfil.rol = .estudiante
                    flujo.avanzar(desde: .rol, rol: .estudiante)
                }
                FilaEleccion(
                    titulo: L("Soy madre, padre o tutor", "I'm a parent or guardian", "Sono un genitore o tutore"),
                    detalle: L("Lo que tienen mis hijos", "What my children have", "Quello che hanno i miei figli"),
                    simbolo: "figure.and.child.holdinghands", color: .naranja,
                    elegida: false, conFlecha: true
                ) {
                    almacen.perfil.rol = .familia
                    flujo.avanzar(desde: .rol, rol: .familia)
                }
            }
            .filaConfig()
        }
    }
}

struct PasoNombre: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo
    @FocusState private var foco: Bool

    var body: some View {
        @Bindable var almacen = almacen
        PaginaConfig(
            simbolo: "person.crop.circle.fill",
            titulo: L("¿Cómo te llamas?", "What's your name?", "Come ti chiami?"),
            principal: L("Continuar", "Continue", "Continua"),
            principalActivo: !almacen.perfil.nombre.trimmingCharacters(in: .whitespaces).isEmpty,
            accionPrincipal: seguir
        ) {
            Section {
                CampoConfig(etiqueta: L("Nombre", "First name", "Nome"), sugerencia: L("Obligatorio", "Required", "Obbligatorio"),
                            texto: $almacen.perfil.nombre, tipo: .givenName)
                    .focused($foco)
                    .submitLabel(.next)
                CampoConfig(etiqueta: L("Apellidos", "Last name", "Cognome"), sugerencia: L("Opcional", "Optional", "Facoltativo"),
                            texto: $almacen.perfil.apellidos, tipo: .familyName)
                    .submitLabel(.continue)
                    .onSubmit(seguir)
            }
            .filaConfig()
        }
        .onAppear { foco = true }
    }

    private func seguir() {
        almacen.perfil.nombre = almacen.perfil.nombre.trimmingCharacters(in: .whitespaces)
        almacen.perfil.apellidos = almacen.perfil.apellidos.trimmingCharacters(in: .whitespaces)
        guard !almacen.perfil.nombre.isEmpty else { return }
        flujo.avanzar(desde: .nombre, rol: almacen.perfil.rol)
    }
}

struct PasoNacimiento: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo
    @State private var fecha = Calendar.current.date(byAdding: .year, value: -13, to: Reloj.ahora) ?? Reloj.ahora

    private var rango: ClosedRange<Date> {
        let cal = Calendar.current
        let desde = cal.date(byAdding: .year, value: -30, to: Reloj.ahora) ?? Reloj.ahora
        let hasta = cal.date(byAdding: .year, value: -4, to: Reloj.ahora) ?? Reloj.ahora
        return desde...hasta
    }

    var body: some View {
        PaginaConfig(
            simbolo: "birthday.cake.fill",
            colorSimbolo: Color(uiColor: .systemPink),
            titulo: L("Fecha de nacimiento", "Date of birth", "Data di nascita"),
            subtitulo: L("Las explicaciones se adaptan a tu edad.", "Explanations adapt to your age.", "Le spiegazioni si adattano alla tua età."),
            principal: L("Continuar", "Continue", "Continua"),
            accionPrincipal: {
                almacen.perfil.nacimiento = fecha

                if almacen.perfil.curso.isEmpty, let edad = almacen.perfil.edad { almacen.perfil.curso = Cursos.probable(edad: edad) }

                if EdadIA.hacePermiso(perfil: almacen.perfil, region: almacen.ajustes.region) && !almacen.ajustes.permisoIA {
                    flujo.ir(.permisoIA)
                } else {
                    flujo.avanzar(desde: .nacimiento, rol: almacen.perfil.rol)
                }
            }
        ) {
            SeccionLibre {
                DatePicker(L("Fecha de nacimiento", "Date of birth", "Data di nascita"), selection: $fecha, in: rango, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .environment(\.locale, localeActual)
            }
        }
        .onAppear {
            if let n = almacen.perfil.nacimiento { fecha = n }
        }
    }
}

struct PasoCorreo: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo
    @FocusState private var foco: Bool
    @State private var sinCuenta = false

    var body: some View {
        @Bindable var flujo = flujo
        PaginaConfig(
            simbolo: "person.crop.circle.badge.checkmark",
            titulo: L("Crea tu cuenta", "Create your account", "Crea il tuo account"),
            subtitulo: L("Con ella tendrás todo en cualquier iPhone en el que entres.", "With it, you'll have everything on any iPhone you sign in to.",
                         "Così avrai tutto su qualsiasi iPhone in cui accedi."),
            principal: L("Continuar", "Continue", "Continua"),
            principalActivo: Cuentas.correoValido(flujo.correo),
            accionPrincipal: seguir,
            secundario: L("Ya tengo una cuenta", "I already have an account", "Ho già un account"),
            accionSecundaria: { flujo.ir(.iniciarSesion) },
            terciario: flujo.alTerminar == nil ? L("Ahora no", "Not now", "Non ora") : nil,
            accionTerciaria: { sinCuenta = true }
        ) {
            Section {
                CampoConfig(etiqueta: L("Correo", "Email", "Email"), sugerencia: "nombre@ejemplo.com",
                            texto: $flujo.correo, tipo: .emailAddress, teclado: .emailAddress, mayusculas: .never)
                    .focused($foco)
                    .submitLabel(.continue)
                    .onSubmit(seguir)
            }
            .filaConfig()
        }
        .onAppear { foco = true }
        .confirmationDialog(L("¿Seguir sin cuenta?", "Continue without an account?", "Continuare senza account?"), isPresented: $sinCuenta,
                            titleVisibility: .visible) {
            Button(L("Seguir sin cuenta", "Continue Without Account", "Continua senza account")) {
                flujo.despuesDeLaCuenta(rol: almacen.perfil.rol)
            }
            Button(L("Cancelar", "Cancel", "Annulla"), role: .cancel) {}
        } message: {
            Text(L("Todo se quedará solo en este iPhone. Puedes crearla después en Cuenta.",
                   "Everything will stay on this iPhone only. You can create one later in Account.",
                   "Tutto resterà solo su questo iPhone. Puoi crearlo più tardi in Account."))
        }
    }

    private func seguir() {
        flujo.correo = flujo.correo.trimmingCharacters(in: .whitespaces).lowercased()
        guard Cuentas.correoValido(flujo.correo) else { return }
        flujo.avanzar(desde: .correo, rol: almacen.perfil.rol)
    }
}

struct PasoContrasena: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo
    @FocusState private var foco: Int?
    @State private var esperando = false
    @State private var error: String?
    @State private var yaExiste = false
    @State private var fallos = 0

    var body: some View {
        @Bindable var flujo = flujo
        let req = Cuentas.Requisitos(flujo.contrasena)
        let iguales = !flujo.repetir.isEmpty && flujo.repetir == flujo.contrasena
        PaginaConfig(
            simbolo: "lock.fill",
            titulo: L("Crea una contraseña", "Create a password", "Crea una password"),
            principal: L("Crear la cuenta", "Create Account", "Crea l'account"),
            principalActivo: req.cumple && iguales,
            accionPrincipal: crear,
            esperando: esperando
        ) {

            Section {
                requisito(L("8 caracteres o más", "8 or more characters", "8 caratteri o più"), req.largo)
                requisito(L("Un número", "One number", "Un numero"), req.numero)
                requisito(L("Una mayúscula", "One uppercase letter", "Una lettera maiuscola"), req.mayuscula)
                requisito(L("Las dos son iguales", "Both match", "Coincidono"), iguales)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
            .environment(\.defaultMinListRowHeight, 26)
            Section {
                CampoConfig(etiqueta: L("Contraseña", "Password", "Password"), sugerencia: L("Obligatoria", "Required", "Obbligatoria"),
                            texto: $flujo.contrasena, tipo: .newPassword, seguro: true, mayusculas: .never)
                    .focused($foco, equals: 0)
                CampoConfig(etiqueta: L("Repetir", "Verify", "Ripeti"), sugerencia: L("Repítela", "Type it again", "Ripetila"),
                            texto: $flujo.repetir, tipo: .newPassword, seguro: true, mayusculas: .never)
                    .focused($foco, equals: 1)
            } footer: {
                if let error { MensajeError(texto: error) }
            }
            .filaConfig()
        }
        .onAppear { foco = 0 }
        .sensoryFeedback(.error, trigger: fallos)
        .alert(L("Ya hay una cuenta con este correo", "There's already an account with this email", "Esiste già un account con questa email"), isPresented: $yaExiste) {
            Button(L("Iniciar sesión", "Sign In", "Accedi")) { flujo.ir(.iniciarSesion) }
            Button(L("Cancelar", "Cancel", "Annulla"), role: .cancel) {}
        }
    }

    private func requisito(_ texto: String, _ ok: Bool) -> some View {
        Label {
            Text(texto).foregroundStyle(ok ? Color.primary : Color.texto2)
        } icon: {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(ok ? Color.hecho : Color.texto2)
                .contentTransition(.symbolEffect(.replace))
        }
        .font(.subheadline)
        .animation(Diseno.muelleRapido, value: ok)
        .accessibilityValue(ok ? L("Cumplido", "Met", "Soddisfatto") : L("Pendiente", "Not met", "Mancante"))
    }

    private func crear() {
        guard !esperando else { return }
        error = nil
        let correo = flujo.correo
        guard Sincronizacion.compartida.activa else {

            let sal = Cuentas.nuevaSal()
            almacen.cuenta.sal = sal
            almacen.cuenta.hash = Cuentas.hash(flujo.contrasena, sal: sal)
            terminar(correo)
            return
        }
        esperando = true
        let contrasena = flujo.contrasena
        Task {
            defer { esperando = false }
            do {
                let sesion = try await Nube.compartida.crearCuenta(correo: correo, contrasena: contrasena, idioma: idiomaActual.rawValue)
                Sincronizacion.compartida.entro(sesion)
                terminar(correo)
            } catch FalloNube.correoEnUso {
                fallos += 1
                yaExiste = true
            } catch {
                fallos += 1
                self.error = Sincronizacion.texto(error)
            }
        }
    }

    private func terminar(_ correo: String) {
        almacen.cuenta.correo = correo
        almacen.cuenta.creada = Reloj.ahora
        almacen.perfil.correo = correo
        flujo.contrasena = ""
        flujo.repetir = ""
        flujo.entrando = false
        flujo.avanzar(desde: .contrasena, rol: almacen.perfil.rol)
    }
}

struct PasoVerificar: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo
    @Environment(\.scenePhase) private var fase
    @State private var esperando = false
    @State private var error: String?
    @State private var reenviado = false
    @State private var confirmado = false
    @State private var fallos = 0

    var body: some View {
        PaginaConfig(
            simbolo: "envelope.badge.fill",
            titulo: L("Confirma tu correo", "Confirm your email", "Conferma la tua email"),
            subtitulo: L("Te hemos mandado un enlace a **\(flujo.correo)**. Tócalo y vuelve aquí.",
                         "We sent a link to **\(flujo.correo)**. Tap it and come back here.",
                         "Abbiamo inviato un link a **\(flujo.correo)**. Toccalo e torna qui."),
            principal: L("Ya lo he confirmado", "I've Confirmed It", "L'ho confermata"),
            accionPrincipal: { comprobar(avisando: true) },
            secundario: reenviado ? L("Enviado de nuevo", "Sent Again", "Inviato di nuovo") : L("Reenviar el correo", "Resend Email", "Invia di nuovo l'email"),
            accionSecundaria: reenviar,
            esperando: esperando
        ) {
            if let error {
                Section {} footer: { MensajeError(texto: error) }
            }
        }
        .sensoryFeedback(.success, trigger: confirmado)
        .sensoryFeedback(.error, trigger: fallos)

        .onChange(of: fase) { _, nueva in
            if nueva == .active { comprobar(avisando: false) }
        }
    }

    private func comprobar(avisando: Bool) {
        guard !esperando, !confirmado else { return }

        guard Sincronizacion.compartida.activa else {
            if avisando { listo() }
            return
        }
        if avisando { esperando = true }
        Task {
            defer { esperando = false }
            do {
                if try await Nube.compartida.comprobarConfirmacion() {
                    await Sincronizacion.compartida.confirmado()
                    listo()
                } else if avisando {
                    fallos += 1
                    error = L("Todavía no está confirmado. Mira también en el correo no deseado.",
                              "It's not confirmed yet. Check your junk mail too.", "Non è ancora confermata. Guarda anche nella posta indesiderata.")
                }
            } catch {
                if avisando {
                    fallos += 1
                    self.error = Sincronizacion.texto(error)
                }
            }
        }
    }

    private func listo() {
        confirmado = true
        almacen.cuenta.verificada = true
        error = nil
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            if flujo.entrando {
                await entrarConLoGuardado(flujo: flujo, almacen: almacen)
            } else {
                flujo.despuesDeLaCuenta(rol: almacen.perfil.rol)
            }
        }
    }

    private func reenviar() {
        guard Sincronizacion.compartida.activa, !reenviado else { return }
        Task {
            do {
                try await Nube.compartida.mandarConfirmacion(idioma: idiomaActual.rawValue)
                reenviado = true
                error = nil
                try? await Task.sleep(for: .seconds(30))
                reenviado = false
            } catch {
                self.error = Sincronizacion.texto(error)
            }
        }
    }
}

@MainActor
func entrarConLoGuardado(flujo: FlujoConfig, almacen: Almacen) async {

    if let alTerminar = flujo.alTerminar {
        alTerminar(true)
        return
    }
    if let guardado = try? await Sincronizacion.compartida.bajarParaEntrar(),
       let e = try? CompatibilidadDatos.decodificar(guardado.estado), e.configurado {
        FlujoConfig.olvidar()
        conMuelle(Diseno.muelleLento) {
            Sincronizacion.compartida.aplicar(guardado)
        }
    } else {
        almacen.cuenta.correo = flujo.correo
        almacen.perfil.correo = flujo.correo
        almacen.cuenta.verificada = true
        flujo.despuesDeLaCuenta(rol: almacen.perfil.rol)
    }
}

struct MensajeError: View {
    var texto: String

    var body: some View {
        Label(texto, systemImage: "exclamationmark.circle.fill")
            .foregroundStyle(Color.urgente)
            .font(.footnote)
    }
}

struct PasoIniciarSesion: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo
    @State private var contrasena = ""
    @State private var error: String?
    @State private var fallos = 0
    @State private var esperando = false
    @State private var cambiandoContrasena = false

    var body: some View {
        @Bindable var flujo = flujo
        PaginaConfig(
            simbolo: "person.crop.circle.fill",
            titulo: L("Iniciar sesión", "Sign In", "Accedi"),
            subtitulo: L("Se bajará todo lo que tengas guardado.", "Everything you have saved will be downloaded.", "Verrà scaricato tutto ciò che hai salvato."),
            principal: L("Iniciar sesión", "Sign In", "Accedi"),
            principalActivo: Cuentas.correoValido(flujo.correo) && !contrasena.isEmpty,
            accionPrincipal: entrar,
            secundario: L("He olvidado la contraseña", "Forgot Password", "Password dimenticata"),
            accionSecundaria: olvidada,
            esperando: esperando
        ) {
            Section {
                CampoConfig(etiqueta: L("Correo", "Email", "Email"), sugerencia: "nombre@ejemplo.com",
                            texto: $flujo.correo, tipo: .username, teclado: .emailAddress, mayusculas: .never)
                CampoConfig(etiqueta: L("Contraseña", "Password", "Password"), sugerencia: L("Obligatoria", "Required", "Obbligatoria"),
                            texto: $contrasena, tipo: .password, seguro: true, mayusculas: .never)
                    .onSubmit(entrar)
            } footer: {
                if let error { MensajeError(texto: error) }
            }
            .filaConfig()
        }
        .sensoryFeedback(.error, trigger: fallos)
        .alert(L("Te hemos mandado un correo", "We sent you an email", "Ti abbiamo inviato un'email"), isPresented: $cambiandoContrasena) {
            Button(L("Aceptar", "OK", "OK"), role: .cancel) {}
        } message: {
            Text(L("Toca el enlace del correo para poner una contraseña nueva y vuelve a entrar.",
                   "Tap the link in the email to set a new password, then sign in again.",
                   "Tocca il link nell'email per impostare una nuova password e accedi di nuovo."))
        }
    }

    private func entrar() {
        guard !esperando else { return }
        let correo = flujo.correo.trimmingCharacters(in: .whitespaces).lowercased()
        flujo.correo = correo
        error = nil
        guard Sincronizacion.compartida.activa else {

            switch Cuentas.iniciarSesion(correo: correo, contrasena: contrasena) {
            case .success(let (estado, foto)):
                FlujoConfig.olvidar()
                conMuelle(Diseno.muelleLento) { almacen.restaurar(estado, foto: foto) }
            case .failure:
                fallos += 1
                error = L("El correo o la contraseña no son correctos.", "The email or password is incorrect.", "L'email o la password non sono corrette.")
            }
            return
        }
        esperando = true
        let clave = contrasena
        flujo.entrando = true
        Task {
            defer { esperando = false }
            do {
                let sesion = try await Nube.compartida.iniciarSesion(correo: correo, contrasena: clave)
                Sincronizacion.compartida.entro(sesion)
                contrasena = ""
                if sesion.verificada {
                    await entrarConLoGuardado(flujo: flujo, almacen: almacen)
                } else {

                    try? await Nube.compartida.mandarConfirmacion(idioma: idiomaActual.rawValue)
                    flujo.ir(.verificar)
                }
            } catch {
                fallos += 1
                self.error = Sincronizacion.texto(error)
            }
        }
    }

    private func olvidada() {
        let correo = flujo.correo.trimmingCharacters(in: .whitespaces).lowercased()
        guard Cuentas.correoValido(correo) else {
            error = L("Escribe tu correo arriba y vuelve a tocar «He olvidado la contraseña».",
                      "Type your email above and tap “Forgot Password” again.", "Scrivi la tua email qui sopra e tocca di nuovo «Password dimenticata».")
            return
        }
        guard Sincronizacion.compartida.activa else { cambiandoContrasena = true; return }
        Task {
            do {
                try await Nube.compartida.restablecerContrasena(correo: correo, idioma: idiomaActual.rawValue)
                cambiandoContrasena = true
            } catch {
                self.error = Sincronizacion.texto(error)
            }
        }
    }
}
