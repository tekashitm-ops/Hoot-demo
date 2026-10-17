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
                ? L("Cada tarde, un resumen de lo que tienen tus hijos.", "Every evening, a summary of what your children have.", "Ogni sera, un riepilogo di quello che hanno i tuoi figli.")
                : L("Hoot te avisa antes de cada entrega, examen y mochila.", "Hoot reminds you before every assignment, test and backpack.", "Hoot ti avvisa prima di ogni consegna, verifica e zaino."),
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
                    Label(L("Resumen diario", "Daily summary", "Riepilogo giornaliero"), systemImage: "text.bubble.fill")
                }
                .interruptorApple()
                if avisos.resumenFamilia {
                    SelectorHora(titulo: L("Hora", "Time", "Ora"), minutos: $avisos.horaResumenFamilia)
                }
            }
        } else {
            Section {
                Toggle(isOn: $avisos.entregas) {
                    Label(L("Entregas", "Assignments", "Consegne"), systemImage: "tray.full.fill")
                }
                .interruptorApple()
                Toggle(isOn: $avisos.examenes) {
                    Label(L("Exámenes", "Tests", "Verifiche"), systemImage: "doc.text.magnifyingglass")
                }
                .interruptorApple()
                if avisos.entregas || avisos.examenes {
                    SelectorHora(titulo: L("La tarde antes, a las", "The evening before, at", "La sera prima, alle"), minutos: $avisos.horaEntregas)
                }
            }
            Section {
                Toggle(isOn: $avisos.cuandoEmpezar) {
                    Label(L("Cuándo empezar", "When to start", "Quando iniziare"), systemImage: "calendar.badge.clock")
                }
                .interruptorApple()
            } footer: {
                Text(L("El día en que conviene empezar a estudiar un examen o a hacer un trabajo, según tus tardes libres y tus actividades.",
                       "The day you should start studying for a test or working on a project, based on your free afternoons and activities.",
                       "Il giorno in cui conviene iniziare a studiare per una verifica o a fare un lavoro, secondo i tuoi pomeriggi liberi e le attività."))
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
            subtitulo: L("Si tu familia escanea este código con Hoot, verá tus tareas y tu calendario.",
                         "If your family scans this code with Hoot, they'll see your homework and calendar.",
                         "Se la tua famiglia scansiona questo codice con Hoot, vedrà i tuoi compiti e il calendario."),
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
    @State private var error = false
    @State private var vinculados = 0

    var body: some View {
        if !almacen.hijos.isEmpty {
            Section {
                ForEach(almacen.hijos) { hijo in
                    HStack(spacing: 14) {
                        Avatar(tamano: 40, estilo: .iniciales, color: hijo.colorAvatar, iniciales: String(hijo.nombre.prefix(1)), foto: nil)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hijo.nombre)
                            Text(L("Vinculado", "Linked", "Collegato")).font(.subheadline).foregroundStyle(Color.hecho)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.hecho)
                    }
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
            Button {
                vincular(nombre: nil)
            } label: {
                Label(L("Ya vinculado", "Already linked", "Già collegato"), systemImage: "checkmark.circle")
            }
        } footer: {
            if error {
                Text(L("Ese código no es de Hoot. Revisa que empiece por HOOT-.", "That isn't a Hoot code. Check that it starts with HOOT-.", "Questo non è un codice Hoot. Controlla che inizi con HOOT-."))
                    .foregroundStyle(Color.urgente)
            }
        }
        .sensoryFeedback(.success, trigger: vinculados)
        .sheet(isPresented: $escaneando) {
            HojaEscanear { texto in
                escaneando = false
                if let leido = CodigoVinculo.interpretar(texto) {
                    vincular(nombre: leido.nombre)
                } else {
                    error = true
                }
            }
        }
        .alert(L("Código de vinculación", "Link code", "Codice di collegamento"), isPresented: $escribiendo) {
            TextField("HOOT-XXXX-XXXX", text: $codigoEscrito)
                .textInputAutocapitalization(.characters)
            Button(L("Vincular", "Link", "Collega")) {
                if CodigoVinculo.interpretar(codigoEscrito) != nil {
                    vincular(nombre: nil)
                } else {
                    error = true
                }
            }
            Button(L("Cancelar", "Cancel", "Annulla"), role: .cancel) {}
        }
    }

    private func vincular(nombre: String?) {
        error = false
        conMuelle {
            let hijo = Demo.hijo(nombre: nombre, escala: almacen.ajustes.escala)
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
