import SwiftUI
import AVFoundation

struct PasoAvisos: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo

    var body: some View {
        @Bindable var almacen = almacen
        PaginaConfig(
            simbolo: "bell.badge.fill",
            colorSimbolo: ColorHoot.rojo.color,
            titulo: L("Avisos", "Notifications", "Notifiche"),
            subtitulo: almacen.esFamilia
                ? L("La tarde antes de cada prueba de tus hijos, y sus recordatorios.", "The evening before each of your children's tests, and their reminders.", "La sera prima di ogni verifica dei tuoi figli, e i loro promemoria.")
                : L("Hoot te avisa de cada repaso, de cada prueba y de la mochila.", "Hoot reminds you of each review, each test and your backpack.", "Hoot ti avvisa di ogni ripasso, di ogni verifica e dello zaino."),
            principal: L("Activar avisos", "Turn On Notifications", "Attiva le notifiche"),
            accionPrincipal: activar,
            secundario: L("Ahora no", "Not Now", "Non ora"),
            accionSecundaria: {
                almacen.ajustes.avisos.activados = false
                flujo.avanzar(desde: .avisos, rol: almacen.perfil.rol)
            }
        ) {
            AjustesAvisosLista(avisos: $almacen.ajustes.avisos, familia: almacen.esFamilia)
                .filaConfig()
        }
    }

    private func activar() {
        Task {
            let ok = await Avisos.pedirPermiso()
            almacen.ajustes.avisos.activados = ok
            flujo.avanzar(desde: .avisos, rol: almacen.perfil.rol)
        }
    }
}

struct AjustesAvisosLista: View {
    @Binding var avisos: AjustesAvisos
    var familia: Bool

    var body: some View {
        if familia {
            Section {
                Toggle(isOn: $avisos.resumenFamilia) {
                    Label(L("Pruebas de tus hijos", "Your children's tests", "Verifiche dei tuoi figli"), systemImage: "moonphase.first.quarter")
                }
                .interruptorApple()
                if avisos.resumenFamilia {
                    SelectorHora(titulo: L("La tarde antes, a las", "The evening before, at", "La sera prima, alle"), minutos: $avisos.horaResumenFamilia)
                }
            }
            Section {
                Toggle(isOn: $avisos.recordatorios) {
                    Label(L("Recordatorios de tus hijos", "Your children's reminders", "Promemoria dei tuoi figli"), systemImage: "bell.fill")
                }
                .interruptorApple()
            } footer: {
                Text(L("Llegan cuando Hoot se ha puesto al día: al abrirlo y cada 5 minutos con la app abierta.",
                       "They arrive once Hoot has updated: when you open it and every 5 minutes while it's open.",
                       "Arrivano quando Hoot si è aggiornato: all'apertura e ogni 5 minuti con l'app aperta."))
            }
        } else {
            Section {
                Toggle(isOn: $avisos.repasos) {
                    Label(L("Ratos de repaso", "Review sessions", "Momenti di ripasso"), systemImage: "book.fill")
                }
                .interruptorApple()
                Toggle(isOn: $avisos.pruebas) {
                    Label(L("Pruebas", "Tests", "Verifiche"), systemImage: "moonphase.first.quarter")
                }
                .interruptorApple()
                if avisos.pruebas {
                    SelectorHora(titulo: L("La tarde antes, a las", "The evening before, at", "La sera prima, alle"), minutos: $avisos.horaEntregas)
                }
            } footer: {
                Text(L("Hoot te avisa a la hora de cada repaso y la tarde antes de cada prueba.",
                       "Hoot reminds you at each review time and the evening before each test.",
                       "Hoot ti avvisa all'ora di ogni ripasso e la sera prima di ogni verifica."))
            }
            Section {
                Toggle(isOn: $avisos.mochila) {
                    Label(L("Preparar la mochila", "Pack the backpack", "Preparare lo zaino"), systemImage: "backpack.fill")
                }
                .interruptorApple()
                if avisos.mochila {
                    SelectorHora(titulo: L("Hora", "Time", "Ora"), minutos: $avisos.horaMochila)
                }
            }
            Section {
                Toggle(isOn: $avisos.recordatorios) {
                    Label(L("Recordatorios", "Reminders", "Promemoria"), systemImage: "bell.fill")
                }
                .interruptorApple()
                Toggle(isOn: $avisos.actividades) {
                    Label(L("Actividades", "Activities", "Attività"), systemImage: "figure.run")
                }
                .interruptorApple()
            }
        }
    }

}

struct PasoFamiliaEstudiante: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo

    var body: some View {
        PaginaConfig(
            simbolo: "figure.and.child.holdinghands",
            colorSimbolo: ColorHoot.naranja.color,
            titulo: L("Control parental", "Parental controls", "Controllo parentale"),
            subtitulo: L("Si tu familia escanea este código con Hoot y lo aceptas, verá tus pruebas, tu calendario y tu mochila.",
                         "If your family scans this code with Hoot and you accept, they'll see your tests, calendar and backpack.",
                         "Se la tua famiglia scansiona questo codice con Hoot e accetti, vedrà verifiche, calendario e zaino."),
            principal: L("Continuar", "Continue", "Continua"),
            accionPrincipal: { flujo.avanzar(desde: .familia, rol: almacen.perfil.rol) }
        ) {
            SeccionLibre {
                TarjetaQR(contenido: almacen.contenidoQR, codigo: almacen.codigoVinculo)
            }
        }
    }
}

struct TarjetaQR: View {
    var contenido: String
    var codigo: String

    private let lado: CGFloat = 200

    var body: some View {
        VStack(spacing: 14) {
            CodigoQR(contenido: contenido)
                .frame(width: lado, height: lado)
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: Diseno.radioGrande, style: .continuous))
            Text(codigo)
                .font(.title3.monospaced().weight(.semibold))
                .textSelection(.enabled)
                .accessibilityLabel(codigo.map { String($0) }.joined(separator: " "))
            ShareLink(item: codigo) {
                Label(L("Compartir el código", "Share code", "Condividi il codice"), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
    }
}

struct PasoVincularHijo: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo

    var body: some View {
        PaginaConfig(
            simbolo: "qrcode.viewfinder",
            titulo: L("Vincula a tu hijo o hija", "Link your child", "Collega tuo figlio o tua figlia"),
            subtitulo: L("Escanea el código de su Hoot, en Cuenta > Control parental.",
                         "Scan the code in their Hoot, under Account > Parental controls.",
                         "Scansiona il codice nel suo Hoot, in Account > Controllo parentale."),
            principal: L("Continuar", "Continue", "Continua"),
            principalActivo: !almacen.hijos.isEmpty,
            accionPrincipal: { flujo.avanzar(desde: .vincularHijo, rol: almacen.perfil.rol) },
            secundario: almacen.hijos.isEmpty ? L("Continuar sin vincular", "Continue without linking", "Continua senza collegare") : nil,
            accionSecundaria: { flujo.avanzar(desde: .vincularHijo, rol: almacen.perfil.rol) }
        ) {
            OpcionesVincular()
                .filaConfig()
        }
    }
}

struct OpcionesVincular: View {
    @Environment(Almacen.self) private var almacen
    @State private var escaneando = false
    @State private var escribiendo = false
    @State private var codigoEscrito = ""
    @State private var mensaje: Mensaje?
    @State private var buscando = false
    @State private var vinculados = 0

    private struct Mensaje: Equatable {
        var texto: String
        var bien: Bool
    }

    var body: some View {
        if !almacen.hijos.isEmpty {
            Section {
                ForEach(almacen.hijos) { hijo in
                    HStack(spacing: 14) {
                        Avatar(tamano: 40, estilo: .iniciales, color: hijo.colorAvatar, iniciales: String(hijo.nombre.prefix(1)), foto: nil)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hijo.nombre)
                            Text(estado(hijo)).font(.subheadline).foregroundStyle(hijo.esperando ? Color.texto2 : Color.hecho)
                        }
                        Spacer()
                        Image(systemName: hijo.esperando ? "clock" : "checkmark.circle.fill")
                            .foregroundStyle(hijo.esperando ? Color.texto2 : Color.hecho)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        Section {
            Button {
                escaneando = true
            } label: {
                Label(L("Escanear el código", "Scan the code", "Scansiona il codice"), systemImage: "qrcode.viewfinder")
            }
            Button {
                codigoEscrito = ""
                escribiendo = true
            } label: {
                Label(L("Escribir el código", "Enter the code", "Scrivi il codice"), systemImage: "keyboard")
            }
        } footer: {
            if buscando {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(L("Buscando el código…", "Looking up the code…", "Cerco il codice…"))
                }
            } else if let mensaje {
                Text(mensaje.texto).foregroundStyle(mensaje.bien ? Color.texto2 : Color.urgente)
            } else {
                Text(L("Hace falta una cuenta de Hoot en los dos iPhone.", "Both iPhones need a Hoot account.", "Serve un account Hoot su entrambi gli iPhone."))
            }
        }
        .disabled(buscando)
        .sensoryFeedback(.success, trigger: vinculados)
        Section {
            Button {
                ejemplo()
            } label: {
                Label(L("Ver un hijo de ejemplo", "See a sample child", "Vedi un figlio di esempio"), systemImage: "person.crop.circle.badge.questionmark")
            }
        }
        .sheet(isPresented: $escaneando) {
            HojaEscanear { texto in
                escaneando = false
                vincular(texto)
            }
        }
        .alert(L("Código de vinculación", "Link code", "Codice di collegamento"), isPresented: $escribiendo) {
            TextField("HOOT-XXXX-XXXX", text: $codigoEscrito)
                .textInputAutocapitalization(.characters)
            Button(L("Vincular", "Link", "Collega")) { vincular(codigoEscrito) }
            Button(L("Cancelar", "Cancel", "Annulla"), role: .cancel) {}
        }
    }

    private func estado(_ hijo: Hijo) -> String {
        if hijo.esperando { return L("Esperando a que acepte", "Waiting for them to accept", "In attesa che accetti") }
        return hijo.uid.isEmpty ? L("De ejemplo", "Sample", "Di esempio") : L("Vinculado", "Linked", "Collegato")
    }

    private func vincular(_ texto: String) {
        guard let leido = CodigoVinculo.interpretar(texto) else {
            mensaje = Mensaje(texto: L("Ese código no es de Hoot. Revisa que empiece por HOOT-.", "That isn't a Hoot code. Check that it starts with HOOT-.", "Questo non è un codice Hoot. Controlla che inizi con HOOT-."), bien: false)
            return
        }
        mensaje = nil
        buscando = true
        Task {
            let resultado = await FamiliaNube.compartida.vincular(codigo: leido.codigo, almacen: almacen)
            buscando = false
            switch resultado {
            case .pedido(let nombre):
                let quien = nombre.isEmpty ? L("Tu hijo o hija", "Your child", "Tuo figlio o tua figlia") : nombre
                mensaje = Mensaje(texto: L("Listo. \(quien) tiene que aceptarlo en su Hoot, en Cuenta > Control parental.",
                                           "Done. \(quien) needs to accept it in their Hoot, under Account > Parental Controls.",
                                           "Fatto. \(quien) deve accettare nel suo Hoot, in Account > Controllo parentale."), bien: true)
                vinculados += 1
            case .noExiste:
                mensaje = Mensaje(texto: L("No hay ningún Hoot con ese código. Pide que te enseñe el de ahora, en Cuenta > Control parental.",
                                           "No Hoot has that code. Ask them for the current one, under Account > Parental Controls.",
                                           "Nessun Hoot ha questo codice. Chiedi quello attuale, in Account > Controllo parentale."), bien: false)
            case .sinCuenta:
                mensaje = Mensaje(texto: L("Entra en tu cuenta (Cuenta, arriba) y confirma el correo; tu hijo o hija también.",
                                           "Sign in to your account (Account, at the top) and confirm your email; your child too.",
                                           "Accedi al tuo account (Account, in alto) e conferma l'email; anche tuo figlio o tua figlia."), bien: false)
            case .fallo(let texto):
                mensaje = Mensaje(texto: texto, bien: false)
            }
        }
    }

    private func ejemplo() {
        mensaje = nil
        conMuelle {
            let hijo = Demo.hijo(nombre: nil, escala: almacen.ajustes.escala)
            almacen.hijos.append(hijo)
            almacen.hijoActivoID = hijo.id
        }
        vinculados += 1
    }
}

struct HojaEscanear: View {
    var alLeer: (String) -> Void
    @Environment(\.dismiss) private var cerrar
    @Environment(\.openURL) private var abrir
    @State private var permiso = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        NavigationStack {
            Group {
                if permiso == .authorized && LectorQR.disponible {
                    LectorQR(alLeer: alLeer)
                        .ignoresSafeArea()
                } else if permiso == .notDetermined {
                    ProgressView()
                } else {
                    ContentUnavailableView {
                        Label(L("No se puede usar la cámara", "Camera unavailable", "Fotocamera non disponibile"), systemImage: "camera.fill")
                    } description: {
                        Text(L("Permite el acceso a la cámara en Ajustes > Hoot.", "Allow camera access in Settings > Hoot.", "Consenti l'accesso alla fotocamera in Impostazioni > Hoot."))
                    } actions: {
                        if permiso == .denied || permiso == .restricted {
                            Button(L("Abrir Ajustes", "Open Settings", "Apri Impostazioni")) {
                                if let url = URL(string: UIApplication.openSettingsURLString) { abrir(url) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .task {
                if permiso == .notDetermined {
                    _ = await AVCaptureDevice.requestAccess(for: .video)
                    permiso = AVCaptureDevice.authorizationStatus(for: .video)
                }
            }
            .navigationTitle(L("Escanear", "Scan", "Scansiona"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BotonCerrar { cerrar() }
                }
            }
        }
    }
}
