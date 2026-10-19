import SwiftUI
import AuthenticationServices

struct AjusteTeams: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.webAuthenticationSession) private var sesionWeb
    @Environment(\.openURL) private var abrirURL
    @State private var conexion = ConexionTeams.compartida
    @State private var desvinculando = false

    private var vinculado: Bool { almacen.teams.activo }

    private var pasos: [String] {
        [L("Entra con la cuenta del colegio, la misma de Teams.", "Sign in with your school account, the one you use for Teams.", "Accedi con l'account della scuola, lo stesso di Teams."),
         L("Acepta los permisos que pide Hoot.", "Accept the permissions Hoot asks for.", "Accetta i permessi che chiede Hoot."),
         L("Hoot comprueba si tu colegio deja leer Teams.", "Hoot checks whether your school allows reading Teams.", "Hoot controlla se la scuola permette di leggere Teams.")]
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    IconoAjustes(simbolo: AjusteCuenta.teams.simbolo, color: AjusteCuenta.teams.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vinculado ? L("Vinculado", "Linked", "Collegato") : L("Sin vincular", "Not linked", "Non collegato"))
                            .font(.headline)

                        Text(vinculado && !almacen.teams.cuentaColegio.isEmpty
                             ? almacen.teams.cuentaColegio.replacingOccurrences(of: "@", with: "@\u{200B}")
                             : L("Los comunicados de tus equipos y las citas de su calendario.", "Your teams' announcements and their calendar events.", "Le comunicazioni dei tuoi team e gli appuntamenti del loro calendario."))
                            .font(.subheadline)
                            .textoSecundario()
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                }
                if vinculado, let ultima = almacen.teams.ultimaSincronizacion {
                    LabeledContent(L("Última vez", "Last updated", "Ultimo aggiornamento"), value: Formato.diaRelativo(ultima) + " · " + Formato.hora(ultima))
                }
            }

            if vinculado {
                if conexion.hayQueEntrar {
                    Section {
                        Button(L("Volver a entrar", "Sign In Again", "Accedi di nuovo")) { vincular() }
                    } footer: {
                        Text(L("La sesión de Teams ha caducado: no llegan comunicados nuevos.", "Your Teams session expired: no new announcements are coming in.", "La sessione di Teams è scaduta: non arrivano nuove comunicazioni."))
                    }
                }
                Section {
                    if conexion.comunicados.isEmpty {
                        Text(L("Sin comunicados", "No announcements", "Nessuna comunicazione"))
                            .textoSecundario()
                    } else {
                        ForEach(conexion.comunicados.prefix(20)) { c in

                            if let e = c.enlace, let url = URL(string: e) {
                                Button { abrirURL(url) } label: { FilaComunicado(comunicado: c) }
                                    .buttonStyle(.plain)
                            } else {
                                FilaComunicado(comunicado: c)
                            }
                        }
                    }
                } header: {
                    Text(L("Comunicados", "Announcements", "Comunicazioni"))
                }
                Section {
                    Button {
                        Task { await conexion.actualizar(almacen) }
                    } label: {
                        HStack {
                            Label(L("Traer lo nuevo ahora", "Update Now", "Aggiorna ora"), systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            if conexion.actualizando { ProgressView() }
                        }
                    }
                    .disabled(conexion.actualizando)
                    Button(L("Desvincular", "Unlink", "Scollega"), role: .destructive) { desvinculando = true }
                }
            } else {
                Section {
                    PasosNumerados(pasos: pasos, color: AjusteCuenta.teams.color)
                } header: {
                    Text(L("Cómo se vincula", "How to link it", "Come si collega"))
                }
                Section {
                    Button(L("Vincular con Teams", "Link with Teams", "Collega con Teams")) { vincular() }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(AjusteCuenta.teams.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: Binding(get: { conexion.paso != nil }, set: { if !$0 { conexion.paso = nil } })) {
            ComprobandoTeams { conexion.paso = nil }
        }
        .confirmationDialog(L("¿Desvincular Teams?", "Unlink Teams?", "Scollegare Teams?"), isPresented: $desvinculando, titleVisibility: .visible) {
            Button(L("Desvincular", "Unlink", "Scollega"), role: .destructive) {
                conMuelle { conexion.desvincular(almacen) }
            }
        } message: {
            Text(L("Dejarán de llegar los comunicados y las citas de Teams.", "Teams announcements and events will stop coming in.", "Non arriveranno più le comunicazioni e gli appuntamenti di Teams."))
        }
        .task {
            if let paso = ModoCapturas.pasoTeams { conexion.paso = paso }
            if vinculado { await conexion.actualizar(almacen) }
        }
    }

    private func vincular() {
        Task {
            await conexion.vincular(almacen) { url in
                try await sesionWeb.authenticate(using: url, callbackURLScheme: Teams.esquema, preferredBrowserSession: .ephemeral)
            }
        }
    }
}

struct FilaComunicado: View {
    var comunicado: Comunicado

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(comunicado.equipo)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: Diseno.hueco)
                Text(Formato.diaRelativo(comunicado.fecha))
                    .font(.footnote)
                    .textoSecundario()
            }
            if !comunicado.asunto.isEmpty {
                Text(comunicado.asunto)
                    .font(.body.weight(.semibold))
            }
            Text(comunicado.texto)
                .font(.subheadline)
                .lineLimit(4)
            if !comunicado.autor.isEmpty {
                Text(comunicado.autor)
                    .font(.footnote)
                    .textoSecundario()
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct ComprobandoTeams: View {
    var cerrar: () -> Void
    @State private var conexion = ConexionTeams.compartida
    @ScaledMetric(relativeTo: .largeTitle) private var lado = 64.0

    var body: some View {
        let paso = conexion.paso ?? .comprobando
        VStack(spacing: 20) {
            Spacer()
            Group {
                switch paso {
                case .comprobando:
                    ProgressView()
                        .controlSize(.large)
                case .vinculado:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: lado))
                        .foregroundStyle(.white, ColorHoot.verde.color)
                        .symbolEffect(.bounce, value: paso)
                case .bloqueado:
                    Image(systemName: "lock.fill")
                        .font(.system(size: lado * 0.85))
                        .foregroundStyle(.secondary)
                case .sinConexion:
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: lado * 0.85))
                        .foregroundStyle(.secondary)
                case .fallo:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: lado * 0.85))
                        .foregroundStyle(ColorHoot.naranja.color)
                }
            }
            .frame(height: lado * 1.1)
            .accessibilityHidden(true)
            Text(titulo(paso))
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
            if let detalle = detalle(paso) {
                Text(detalle)
                    .font(.body)
                    .textoSecundario()
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if paso != .comprobando {
                Button(action: cerrar) {
                    Text(paso.esVinculado ? L("Hecho", "Done", "Fine") : L("Salir", "Exit", "Esci"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .transition(.opacity)
            }
        }
        .animation(Diseno.muelle, value: paso)
        .sensoryFeedback(trigger: paso) { _, nuevo in
            switch nuevo {
            case .vinculado: .success
            case .bloqueado, .sinConexion, .fallo: .error
            case .comprobando: nil
            }
        }
        .interactiveDismissDisabled()
    }

    private func titulo(_ p: ConexionTeams.Paso) -> String {
        switch p {
        case .comprobando: L("Comprobando los permisos de tu organización", "Checking your organization's permissions", "Controllo dei permessi della tua organizzazione")
        case .vinculado: L("Teams vinculado correctamente", "Teams linked successfully", "Teams collegato correttamente")
        case .bloqueado: L("Tu organización ha bloqueado los permisos de lectura de Microsoft Teams", "Your organization has blocked read access to Microsoft Teams", "La tua organizzazione ha bloccato i permessi di lettura di Microsoft Teams")
        case .sinConexion: L("No se ha podido comprobar", "Couldn't check", "Impossibile controllare")
        case .fallo: L("No se ha podido vincular", "Couldn't link", "Impossibile collegare")
        }
    }

    private func detalle(_ p: ConexionTeams.Paso) -> String? {
        switch p {
        case .vinculado(let correo): correo.isEmpty ? nil : correo.replacingOccurrences(of: "@", with: "@\u{200B}")
        case .sinConexion: L("Sin conexión a internet.", "No internet connection.", "Nessuna connessione a internet.")
        case .fallo(let texto): texto
        default: nil
        }
    }
}

extension ConexionTeams.Paso {
    var esVinculado: Bool {
        if case .vinculado = self { return true }
        return false
    }
}
