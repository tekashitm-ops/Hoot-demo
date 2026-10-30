import SwiftUI

struct SeccionNube: View {
    @Environment(Almacen.self) private var almacen
    @State private var nube = Sincronizacion.compartida
    @State private var creando = false
    @State private var reenviado = false

    var body: some View {
        if nube.activa || nube.deMuestra {
            Section {
                if let sesion = nube.sesion {
                    estado(sesion)
                } else {
                    Button {
                        creando = true
                    } label: {
                        FilaAjuste(simbolo: "person.crop.circle.badge.plus", color: .azul,
                                   titulo: L("Crear cuenta o iniciar sesión", "Create Account or Sign In", "Crea un account o accedi"))
                    }
                    .foregroundStyle(Color.primary)
                }
            } footer: {
                if nube.sesion == nil {
                    Text(L("Sin cuenta, todo está solo en este iPhone. Con ella, lo tendrás en cualquier iPhone en el que entres.",
                           "Without an account, everything is only on this iPhone. With one, you'll have it on any iPhone you sign in to.",
                           "Senza account, tutto è solo su questo iPhone. Con un account, lo avrai su qualsiasi iPhone in cui accedi."))
                }
            }
            .sheet(isPresented: $creando) { HojaCuenta() }
        }
    }

    @ViewBuilder
    private func estado(_ sesion: SesionNube) -> some View {
        switch nube.estado {
        case .sinConfirmar:
            Button {
                Task {
                    if (try? await Nube.compartida.comprobarConfirmacion()) == true {
                        await nube.confirmado()
                        await nube.subirTodo()
                    } else {
                        try? await Nube.compartida.mandarConfirmacion(idioma: idiomaActual.rawValue)
                        reenviado = true
                    }
                }
            } label: {
                FilaAjuste(simbolo: "envelope.badge.fill", color: .naranja,
                           titulo: L("Confirma tu correo", "Confirm Your Email", "Conferma la tua email"),
                           valor: reenviado ? L("Enviado", "Sent", "Inviata") : L("Reenviar", "Resend", "Reinvia"))
            }
            .foregroundStyle(Color.primary)
        case .guardando:
            FilaAjuste(simbolo: "arrow.triangle.2.circlepath.icloud.fill", color: .azul,
                       titulo: L("Guardando en tu cuenta", "Saving to Your Account", "Salvataggio nell'account"))
        case .alDia(let cuando):
            TimelineView(.everyMinute) { contexto in
                FilaAjuste(simbolo: "checkmark.icloud.fill", color: .azul,
                           titulo: L("Guardado en tu cuenta", "Saved to Your Account", "Salvato nell'account"),
                           valor: Self.hace(cuando, ahora: contexto.date))
            }
        case .sinRed:
            FilaAjuste(simbolo: "icloud.slash.fill", color: .gris,
                       titulo: L("Sin conexión", "No Connection", "Nessuna connessione"),
                       valor: L("Se guardará al volver", "Will save when back", "Si salverà al ritorno"))
        case .fallo(let texto):
            FilaAjuste(simbolo: "exclamationmark.icloud.fill", color: .rojo, titulo: texto)
        case .sinCuenta:
            EmptyView()
        }
    }
}

extension SeccionNube {

    static func hace(_ fecha: Date, ahora: Date) -> String {
        if ahora.timeIntervalSince(fecha) < 60 { return L("Ahora", "Now", "Ora") }
        return fecha.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
    }
}

struct HojaCuenta: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var flujo = FlujoConfig()
    @State private var guardado: GuardadoNube?
    @State private var eligiendo = false

    var body: some View {
        @Bindable var flujo = flujo
        NavigationStack(path: $flujo.ruta) {
            PasoCorreo()
                .navigationDestination(for: PasoConfig.self) { paso in
                    switch paso {
                    case .contrasena: PasoContrasena()
                    case .verificar: PasoVerificar()
                    case .iniciarSesion: PasoIniciarSesion()
                    default: EmptyView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L("Cancelar", "Cancel", "Annulla"), role: .cancel) { cancelar() }
                    }
                }
        }
        .environment(flujo)
        .interactiveDismissDisabled(!flujo.ruta.isEmpty)
        .onAppear {
            flujo.correo = almacen.perfil.correo
            flujo.alTerminar = { entrando in terminar(entrando) }
        }
        .confirmationDialog(L("Tu cuenta ya tiene datos", "Your account already has data", "Il tuo account ha già dei dati"), isPresented: $eligiendo,
                            titleVisibility: .visible) {
            Button(L("Usar los de la cuenta", "Use the Account's", "Usa quelli dell'account")) {
                if let guardado { Sincronizacion.compartida.aplicar(guardado) }
                cerrar()
            }
            Button(L("Usar los de este iPhone", "Use This iPhone's", "Usa quelli di questo iPhone"), role: .destructive) {
                Task {
                    await Sincronizacion.compartida.subirTodo()
                    cerrar()
                }
            }
            Button(L("Cancelar", "Cancel", "Annulla"), role: .cancel) { cancelar() }
        } message: {
            Text(L("Los de la cuenta sustituyen a los de este iPhone; los de este iPhone, a los de la cuenta.",
                   "The account's replace this iPhone's; this iPhone's replace the account's.",
                   "Quelli dell'account sostituiscono quelli di questo iPhone; quelli di questo iPhone, quelli dell'account."))
        }
    }

    private func terminar(_ entrando: Bool) {
        almacen.cuenta.correo = flujo.correo
        almacen.perfil.correo = flujo.correo
        almacen.cuenta.verificada = true
        Task {
            if entrando, let remoto = try? await Sincronizacion.compartida.bajarParaEntrar() {
                guardado = remoto
                eligiendo = true
            } else {
                await Sincronizacion.compartida.subirTodo()
                cerrar()
            }
        }
    }

    private func cancelar() {
        Task {
            if flujo.entrando && Sincronizacion.compartida.sesion != nil {
                await Sincronizacion.compartida.cerrarSesion()
            }
            cerrar()
        }
    }
}
