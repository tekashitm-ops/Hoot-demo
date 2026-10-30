import SwiftUI
import Combine
import LocalAuthentication

struct Raiz: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.scenePhase) private var fase

    var body: some View {
        ZStack {
            if almacen.configurado {
                Group {
                    if almacen.esFamilia {
                        AppFamilia()
                    } else {
                        AppEstudiante()
                    }
                }
                .id(almacen.versionIdioma)
                .transition(.asymmetric(
                    insertion: .scale(scale: 1.08).combined(with: .opacity),
                    removal: .opacity
                ))
            } else {
                Configuracion()

                    .safeAreaInset(edge: .top, spacing: 0) {
                        if Desarrollo.compartido.configurando { BotonSalirConfiguracion() }
                    }
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if let texto = almacen.avisoPrueba {
                AvisoPrueba(texto: texto) {
                    conMuelle(Diseno.muelleGesto) { almacen.avisoPrueba = nil }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(3)
            }
        }
        .environment(\.locale, localeActual)
        .tint(Color.acento)

        .onOpenURL { url in
            if url.pathExtension.lowercased() == "hoot", let t = TemaCompartido.leer(url), !almacen.esFamilia { almacen.temaRecibido = t }

            guard url.scheme == "hoot", almacen.configurado, !almacen.esFamilia else { return }
            switch url.host {
            case "repaso":
                almacen.pestana = .hoy
                almacen.empezarRepasoHoy = true
            case "prueba":
                if let id = UUID(uuidString: url.lastPathComponent) {
                    almacen.pestana = .pruebas
                    almacen.abrirPruebaID = id
                }
            case "sala":

                Salas.compartidas.codigoPendiente = CodigoSala.limpio(url.lastPathComponent)
                Salas.compartidas.entrando = true
            default:
                break
            }
        }
        .modifier(PantallaDeDesarrollo())
        .onChange(of: fase) { _, nueva in
            switch nueva {
            case .background:
                almacen.guardarYa()
                if almacen.ajustes.bloqueoFaceID && almacen.configurado { almacen.bloqueado = true }

                let tarea = UIApplication.shared.beginBackgroundTask(withName: "nube")
                Task {
                    await Sincronizacion.compartida.subirYa()
                    UIApplication.shared.endBackgroundTask(tarea)
                }
            case .active:
                almacen.reintentarCarga()
                Task { await Avisos.reprogramar(almacen) }

                if almacen.configurado && !almacen.esFamilia { Task { await Conexiones.actualizar(almacen) } }

                Task { await Sincronizacion.compartida.alActivarse() }
            default:
                break
            }
        }
        .onAppear {
            almacen.reintentarCarga()
            VentanaBloqueo.actualizar(almacen)
            if almacen.configurado && !almacen.esFamilia { Task { await Conexiones.actualizar(almacen) } }
        }
        .onChange(of: almacen.bloqueado) { _, _ in VentanaBloqueo.actualizar(almacen) }
        .onChange(of: almacen.configurado) { _, configurado in

            if configurado { Desarrollo.compartido.configuracionTerminada() }

            if configurado { Task { await Sincronizacion.compartida.alTerminarConfiguracion() } }
        }
    }
}

enum VentanaBloqueo {
    private static var ventana: UIWindow?

    static func actualizar(_ almacen: Almacen) {
        if almacen.bloqueado {
            guard ventana == nil else { return }
            let escenas = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            guard let escena = escenas.first(where: { $0.activationState == .foregroundActive }) ?? escenas.first else { return }
            let v = UIWindow(windowScene: escena)
            v.windowLevel = .alert + 1
            let raiz = PantallaBloqueo()
                .environment(almacen)
                .environment(\.locale, localeActual)
                .tint(Color.acento)
            let host = UIHostingController(rootView: raiz)

            host.view.backgroundColor = .clear
            v.rootViewController = host
            v.isHidden = false
            ventana = v
        } else {
            ventana?.isHidden = true
            ventana = nil
        }
    }
}

struct AvisoPrueba: View {
    var texto: String
    var cerrar: () -> Void
    @State private var arrastre: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color(uiColor: .systemBlue).gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Correo · Modo de prueba", "Mail · Test mode", "Mail · Modalità di prova"))
                    .font(.footnote.weight(.semibold))
                Text(texto)
                    .font(.subheadline)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, 10)
        .offset(y: min(0, arrastre))
        .gesture(
            DragGesture()
                .onChanged { arrastre = $0.translation.height }
                .onEnded { v in
                    if v.translation.height < -30 || v.predictedEndTranslation.height < -80 { cerrar() } else {
                        withAnimation(Diseno.muelleGesto) { arrastre = 0 }
                    }
                }
        )
        .onTapGesture(perform: cerrar)
        .task(id: texto) {
            AccessibilityNotification.Announcement(texto).post()
            try? await Task.sleep(for: .seconds(12))
            cerrar()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

struct PantallaBloqueo: View {
    @Environment(Almacen.self) private var almacen
    @State private var fallos = 0
    @State private var pidiendo = false

    @State private var pedir = true

    @State private var saliendo = false

    var body: some View {
        ZStack {
            Color.fondo.ignoresSafeArea()
            VStack(spacing: 20) {
                Lobo(tamano: 96, gesto: .dormido)
                Text(L("Hoot está bloqueado", "Hoot is locked", "Hoot è bloccato"))
                    .font(.title2.bold())
                Button {
                    desbloquear()
                } label: {
                    Label(L("Usar Face ID", "Use Face ID", "Usa Face ID"), systemImage: "faceid")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color.acentoRelleno)
            }
        }
        .opacity(saliendo ? 0 : 1)
        .sensoryFeedback(.error, trigger: fallos)

        .task {
            if UIApplication.shared.applicationState == .active && pedir {
                pedir = false
                desbloquear()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            pedir = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if pedir {
                pedir = false
                desbloquear()
            }
        }
    }

    private func desbloquear() {
        guard !pidiendo else { return }
        let contexto = LAContext()
        var error: NSError?
        guard contexto.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            conMuelle { almacen.bloqueado = false }
            return
        }
        pidiendo = true
        Task {
            defer { pidiendo = false }
            do {
                let ok = try await contexto.evaluatePolicy(.deviceOwnerAuthentication,
                                                           localizedReason: L("Desbloquear Hoot", "Unlock Hoot", "Sblocca Hoot"))
                if ok {
                    conMuelle { saliendo = true }
                    try? await Task.sleep(for: .milliseconds(250))
                    almacen.bloqueado = false
                    saliendo = false
                }
            } catch let error as LAError where error.code == .authenticationFailed {
                fallos += 1
            } catch {

            }
        }
    }
}

private struct PantallaDeDesarrollo: ViewModifier {
    func body(content: Content) -> some View {
        let d = Desarrollo.compartido
        let letra = d.letraForzada, negrita = d.negrita

        content
            .preferredColorScheme(d.aparienciaForzada)
            .transformEnvironment(\.dynamicTypeSize) { t in if let letra { t = letra } }
            .transformEnvironment(\.legibilityWeight) { w in if negrita { w = .bold } }
    }
}
