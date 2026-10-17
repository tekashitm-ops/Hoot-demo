import SwiftUI

struct DeslizarParaEmpezar: ViewModifier {
    var alEmpezar: () -> Void
    @Binding var arrastre: CGFloat

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { v in
                        let y = v.translation.height

                        arrastre = y < 0 ? y : y * 120 / (120 + y)
                    }
                    .onEnded { v in
                        if v.translation.height < -110 || v.predictedEndTranslation.height < -280 {
                            alEmpezar()
                        } else {
                            withAnimation(Diseno.muelleGesto) { arrastre = 0 }
                        }
                    }
            )
            .onTapGesture { alEmpezar() }
            .accessibilityAction(named: L("Empezar", "Start", "Inizia")) { alEmpezar() }
    }
}

struct IndicacionDeslizar: View {

    var sobreColor = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "chevron.compact.up")
                .font(.title2.weight(.semibold))
                .symbolEffect(.bounce.up, options: .repeat(.periodic(delay: 1.8)))
            Text(L("Desliza hacia arriba para empezar", "Swipe up to get started", "Scorri verso l'alto per iniziare"))
                .font(.subheadline.weight(sobreColor ? .medium : .regular))
        }
        .foregroundStyle(sobreColor ? Color.white : Color.texto2)
        .padding(.bottom, 12)
        .accessibilityHidden(true)
    }
}

struct PantallaHola: View {
    var alEmpezar: () -> Void

    @State private var inicio = Date()
    @State private var escrito = false
    @State private var visible = false
    @State private var arrastre: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    private let duracion: Double = 3.2
    private let espera: Double = 0.5

    var body: some View {
        ZStack {
            FondoHola()
                .opacity(visible ? 1 : 0)

            Group {
                if escrito || reducirMovimiento {
                    HolaDeCristal(progreso: 1)
                } else {
                    TimelineView(.animation) { contexto in
                        let t = (contexto.date.timeIntervalSince(inicio) - espera) / duracion
                        HolaDeCristal(progreso: Self.trazo(t))
                    }
                }
            }
            .aspectRatio(TrazoHola.proporcion, contentMode: .fit)
            .padding(.horizontal, 34)
            .offset(y: arrastre * 0.7)
            .opacity(1 + Double(arrastre) / 400)
            .accessibilityElement()
            .accessibilityLabel("hello")

            VStack {
                Spacer()
                IndicacionDeslizar(sobreColor: true)
                    .opacity(escrito || reducirMovimiento ? 1 + Double(arrastre) / 200 : 0)
                    .offset(y: arrastre * 0.3)
            }
        }
        .modifier(DeslizarParaEmpezar(alEmpezar: alEmpezar, arrastre: $arrastre))
        .onAppear {
            inicio = Date()
            withAnimation(Diseno.muelleLento) { visible = true }
        }
        .task {
            try? await Task.sleep(for: .seconds(espera + duracion))
            withAnimation(Diseno.muelle) { escrito = true }
        }
    }

    static func trazo(_ t: Double) -> CGFloat {
        let x = max(0, min(1, t))
        let y = x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
        return CGFloat(y)
    }
}

struct HolaDeCristal: View {
    var progreso: CGFloat

    var body: some View {
        Color.clear
            .glassEffect(.regular, in: TrazoHola(progreso: progreso))

            .environment(\.colorScheme, .light)
    }
}

struct FondoHola: View {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    private static let colores: [Color] = [
        Color(red: 0.06, green: 0.10, blue: 0.36), Color(red: 0.17, green: 0.12, blue: 0.56), Color(red: 0.07, green: 0.19, blue: 0.48),
        Color(red: 0.30, green: 0.17, blue: 0.71), Color(red: 0.18, green: 0.44, blue: 0.89), Color(red: 0.06, green: 0.56, blue: 0.66),
        Color(red: 0.17, green: 0.10, blue: 0.47), Color(red: 0.23, green: 0.18, blue: 0.66), Color(red: 0.09, green: 0.14, blue: 0.43),
    ]

    var body: some View {
        TimelineView(.animation(paused: reducirMovimiento)) { contexto in
            let t = reducirMovimiento ? 0 : contexto.date.timeIntervalSinceReferenceDate

            let a = Float(sin(t * 2 * .pi / 17)) * 0.10
            let b = Float(cos(t * 2 * .pi / 23)) * 0.10
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5 + b], [0.5 + a, 0.45 + b], [1, 0.5 - a],
                    [0, 1], [0.5 - b, 1], [1, 1],
                ],
                colors: Self.colores
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct PantallaBienvenida: View {
    @Environment(Almacen.self) private var almacen
    @State private var arrastre: CGFloat = 0
    @State private var aparecido = false
    @State private var gesto: GestoLobo = .normal
    @ScaledMetric(relativeTo: .largeTitle) private var lado = 150
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        ZStack {
            Color.fondo.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Lobo(tamano: lado, gesto: gesto)
                    .scaleEffect(aparecido || reducirMovimiento ? 1 : 0.6)
                    .opacity(aparecido || reducirMovimiento ? 1 : 0)
                Text(almacen.perfil.nombre.isEmpty
                     ? L("Te damos la bienvenida a Hoot", "Welcome to Hoot", "Benvenuto in Hoot")
                     : L("Te damos la bienvenida a Hoot, \(almacen.perfil.nombre)", "Welcome to Hoot, \(almacen.perfil.nombre)", "Benvenuto in Hoot, \(almacen.perfil.nombre)"))
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Diseno.margen + 8)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                IndicacionDeslizar()
                    .opacity(1 + Double(arrastre) / 200)
            }
            .offset(y: arrastre * 0.7)
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .modifier(DeslizarParaEmpezar(alEmpezar: terminar, arrastre: $arrastre))
        .sensoryFeedback(.success, trigger: aparecido)
        .task {
            guard !reducirMovimiento else { aparecido = true; gesto = .feliz; return }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(Diseno.muelleRebote) { aparecido = true }

            gesto = .saltando
            try? await Task.sleep(for: .milliseconds(1250))
            gesto = .feliz
        }
    }

    private func terminar() {
        FlujoConfig.olvidar()
        conMuelle(Diseno.muelleLento) {
            almacen.configurado = true
        }
        almacen.guardarYa()
        Task { await Avisos.reprogramar(almacen) }
    }
}
