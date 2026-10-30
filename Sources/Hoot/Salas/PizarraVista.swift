import PencilKit
import SwiftUI

@Observable
final class ControlPizarra {
    @ObservationIgnored fileprivate weak var lienzo: LienzoSala?

    var visible: (centro: CGPoint, ancho: CGFloat) {
        guard let c = lienzo else { return (CGPoint(x: 300, y: 400), 360) }
        let z = max(c.zoomScale, 0.01)
        return (CGPoint(x: (c.contentOffset.x + c.bounds.width / 2) / z, y: (c.contentOffset.y + c.bounds.height / 2) / z), c.bounds.width / z)
    }
}

enum PedidoPizarra: Hashable, Identifiable {
    case foto, camara, escanear
    var id: Self { self }
}

struct PizarraVista: UIViewRepresentable {
    var pizarra: PizarraCompartida
    var control: ControlPizarra
    var nombreAmigo: String

    var activa: Bool
    var alPedir: (PedidoPizarra) -> Void

    func makeCoordinator() -> Coordinador { Coordinador(pizarra: pizarra) }

    func makeUIView(context: Context) -> ContenedorPizarra {
        let v = ContenedorPizarra(coordinador: context.coordinator)
        control.lienzo = v.lienzo
        context.coordinator.alPedir = alPedir
        return v
    }

    func updateUIView(_ v: ContenedorPizarra, context: Context) {
        context.coordinator.alPedir = alPedir
        context.coordinator.pizarra = pizarra

        let version = pizarra.versionTrazos
        v.ponerPapel(pizarra.papel)
        v.ponerObjetos(pizarra.objetosOrdenados, imagenes: pizarra.imagenes)
        v.ponerFantasma(pizarra.fantasma, nombre: nombreAmigo)
        context.coordinator.aplicarTrazos(version: version)
        v.mostrarPaleta(activa)
    }

    static func dismantleUIView(_ v: ContenedorPizarra, coordinator: Coordinador) {
        v.mostrarPaleta(false)
    }

    final class Coordinador: NSObject, PKCanvasViewDelegate, PKToolPickerObserver, UIGestureRecognizerDelegate {
        var pizarra: PizarraCompartida
        var alPedir: (PedidoPizarra) -> Void = { _ in }
        weak var contenedor: ContenedorPizarra?

        private var conocidos: [ClaveTrazo: String] = [:]
        private var versionPuesta = -1
        private var aplicando = false
        private var dibujando = false
        private var pendiente = false
        private var puntosFantasma: [CGPoint] = []

        init(pizarra: PizarraCompartida) { self.pizarra = pizarra }

        var lienzo: LienzoSala? { contenedor?.lienzo }

        func aplicarTrazos(version: Int) {
            guard version != versionPuesta, let lienzo else { return }
            if dibujando { pendiente = true; return }
            versionPuesta = version
            let ordenados = pizarra.ordenados
            var nuevos: [ClaveTrazo: String] = [:]
            for t in ordenados { nuevos[ClaveTrazo(t.trazo)] = t.id }

            let actuales = lienzo.drawing.strokes.map(ClaveTrazo.init)
            if Set(actuales) == Set(nuevos.keys) && actuales.count == ordenados.count {
                conocidos = nuevos
                return
            }
            aplicando = true
            lienzo.drawing = PKDrawing(strokes: ordenados.map(\.trazo))
            aplicando = false
            conocidos = nuevos
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !aplicando else { return }
            let trazos = canvasView.drawing.strokes
            var vistos: Set<ClaveTrazo> = []
            var puestos: [PKStroke] = []
            var clavesPuestas: [ClaveTrazo] = []
            for s in trazos {
                let k = ClaveTrazo(s)
                vistos.insert(k)
                if conocidos[k] == nil { puestos.append(s); clavesPuestas.append(k) }
            }
            let quitados = conocidos.filter { !vistos.contains($0.key) }
            guard !puestos.isEmpty || !quitados.isEmpty else { return }
            for k in quitados.keys { conocidos[k] = nil }
            let ids = pizarra.cambiosPropios(puestos: puestos, quitados: Array(quitados.values))
            for (k, id) in zip(clavesPuestas, ids) { conocidos[k] = id }
            versionPuesta = pizarra.versionTrazos
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            dibujando = true
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            dibujando = false
            if pendiente {
                pendiente = false
                versionPuesta = -1
                aplicarTrazos(version: pizarra.versionTrazos)
            }
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) { contenedor?.recolocar() }
        func scrollViewDidScroll(_ scrollView: UIScrollView) { contenedor?.recolocarDedo() }

        @objc func toqueFantasma(_ g: UIGestureRecognizer) {
            guard let lienzo else { return }
            let z = max(lienzo.zoomScale, 0.01)
            let p = g.location(in: lienzo)
            let punto = CGPoint(x: p.x / z, y: p.y / z)
            switch g.state {
            case .began:
                puntosFantasma = [punto]
            case .changed:
                puntosFantasma.append(punto)
                if let tinta = lienzo.tool as? PKInkingTool {
                    pizarra.dibujando(puntosFantasma, color: tinta.color, ancho: tinta.width)
                }
            default:
                puntosFantasma = []
                pizarra.dejarDeDibujar()
            }
        }

        @objc func toqueLaser(_ g: UIPanGestureRecognizer) {
            guard let lienzo else { return }
            let z = max(lienzo.zoomScale, 0.01)
            let p = g.location(in: lienzo)
            let punto = CGPoint(x: p.x / z, y: p.y / z)
            switch g.state {
            case .began:
                puntosFantasma = [punto]
            case .changed:
                puntosFantasma.append(punto)
            default:
                contenedor?.laserPropio(puntosFantasma, terminar: true)
                puntosFantasma = []
                pizarra.dejarDeDibujar()
                return
            }
            contenedor?.laserPropio(puntosFantasma, terminar: false)
            pizarra.dibujando(puntosFantasma, color: .systemRed, ancho: 6, laser: true)
        }

        private var moviendo: (o: ObjetoPizarra, inicio: ObjetoPizarra)?

        private func foto(en g: UIGestureRecognizer) -> ObjetoPizarra? {
            guard let lienzo else { return nil }
            let z = max(lienzo.zoomScale, 0.01)
            let p = g.location(in: lienzo)
            let punto = CGPoint(x: p.x / z, y: p.y / z)
            return pizarra.objetosOrdenados.reversed().first { o in
                let local = punto.applying(CGAffineTransform(translationX: -o.centro.x, y: -o.centro.y).concatenating(CGAffineTransform(rotationAngle: -o.giro)))
                return abs(local.x) <= o.ancho / 2 && abs(local.y) <= o.alto / 2
            }
        }

        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            let h = contenedor?.herramienta ?? ""
            if g.name == "fantasma" { return h != "mover" && h != "laser" && lienzo?.tool is PKInkingTool }
            guard h == "mover" else { return false }
            if g is UIPinchGestureRecognizer || g is UIRotationGestureRecognizer { return moviendo != nil || foto(en: g) != nil }
            return foto(en: g) != nil
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otro: UIGestureRecognizer) -> Bool {

            (g.view === otro.view && !(g is UIPanGestureRecognizer && otro is UIPanGestureRecognizer)) || g.name == "fantasma" || otro.name == "fantasma"
        }

        @objc func moverFoto(_ g: UIGestureRecognizer) {
            guard let lienzo else { return }
            let z = max(lienzo.zoomScale, 0.01)
            if g.state == .began, moviendo == nil, let o = foto(en: g) { moviendo = (o, o) }
            guard var actual = moviendo?.o, let inicio = moviendo?.inicio else { return }
            switch g {
            case let pan as UIPanGestureRecognizer:
                let d = pan.translation(in: lienzo)
                actual.centro = CGPoint(x: actual.centro.x + d.x / z, y: actual.centro.y + d.y / z)
                pan.setTranslation(.zero, in: lienzo)
            case let pinch as UIPinchGestureRecognizer:
                let f = max(0.2, min(pinch.scale, 5))
                actual.ancho = max(60, min(actual.ancho * f, 2400))
                actual.alto = actual.ancho * inicio.alto / max(inicio.ancho, 1)
                pinch.scale = 1
            case let giro as UIRotationGestureRecognizer:
                actual.giro += giro.rotation
                giro.rotation = 0
            default: break
            }
            let terminado = g.state == .ended || g.state == .cancelled
            moviendo = (actual, inicio)
            pizarra.moverObjeto(actual, guardar: terminado, antes: terminado ? inicio : nil)
            if terminado {
                let otrosActivos = (g.view?.gestureRecognizers ?? []).contains { $0 !== g && $0.name == "foto" && ($0.state == .began || $0.state == .changed) }
                if !otrosActivos { moviendo = nil }
            }
        }

        func toolPickerSelectedToolItemDidChange(_ toolPicker: PKToolPicker) {
            contenedor?.herramienta = toolPicker.selectedToolItem.identifier
        }
    }
}

struct ClaveTrazo: Hashable {
    let fecha: Double
    let semilla: UInt32
    let puntos: Int
    let t: [Double]
    let mascara: [Double]
    let tinta: String

    init(_ s: PKStroke) {
        fecha = s.path.creationDate.timeIntervalSinceReferenceDate
        semilla = s.randomSeed
        puntos = s.path.count
        let m = s.transform
        t = [m.a, m.b, m.c, m.d, m.tx, m.ty].map { (Double($0) * 100).rounded() / 100 }
        let b = s.mask?.bounds ?? .zero
        mascara = [b.minX, b.minY, b.width, b.height].map { (Double($0) * 10).rounded() / 10 }
        tinta = s.ink.inkType.rawValue + s.ink.color.hex
    }
}

final class LienzoSala: PKCanvasView {
    var pizarra: PizarraCompartida?
    private lazy var deshacerPropio = DeshacerPizarra(lienzo: self)

    override var undoManager: UndoManager? { deshacerPropio }
}

final class DeshacerPizarra: UndoManager {
    private weak var lienzo: LienzoSala?

    init(lienzo: LienzoSala) {
        self.lienzo = lienzo
        super.init()
        groupsByEvent = false
    }

    override func registerUndo(withTarget target: Any, selector: Selector, object anObject: Any?) {}
    override func prepare(withInvocationTarget target: Any) -> Any { self }
    override var canUndo: Bool { lienzo?.pizarra?.puedeDeshacer ?? false }
    override var canRedo: Bool { lienzo?.pizarra?.puedeRehacer ?? false }

    override func undo() {
        lienzo?.pizarra?.deshacer()
        NotificationCenter.default.post(name: .NSUndoManagerDidUndoChange, object: self)
    }

    override func redo() {
        lienzo?.pizarra?.rehacer()
        NotificationCenter.default.post(name: .NSUndoManagerDidRedoChange, object: self)
    }
}

final class ContenedorPizarra: UIView {
    let lienzo = LienzoSala()
    private let papel = UIView()
    private let fotos = UIView()
    private let fantasma = UIView()
    private let trazoFantasma = CAShapeLayer()
    private let laser = CAShapeLayer()
    private let dedo = UIView()
    private let etiqueta = UILabel()
    private let selector: PKToolPicker
    private weak var coordinador: PizarraVista.Coordinador?
    private var vistasFotos: [String: UIImageView] = [:]
    private var papelPuesto: PapelPizarra?
    private var ultimoPuntoAmigo: CGPoint?
    private var desvanecer: DispatchWorkItem?
    private let laserGesto = UIPanGestureRecognizer()

    static let tamano = CGSize(width: 2400, height: 3600)
    static let colorAmigo = UIColor(red: 0.76, green: 0.25, blue: 0.05, alpha: 1)

    var herramienta = "" {
        didSet {
            let especial = herramienta == "mover" || herramienta == "laser"
            lienzo.isScrollEnabled = herramienta != "laser"
            laserGesto.isEnabled = herramienta == "laser"
            if !especial { laser.path = nil }
        }
    }

    init(coordinador: PizarraVista.Coordinador) {
        let mover = PKToolPickerCustomItem(configuration: {
            var c = PKToolPickerCustomItem.Configuration(identifier: "mover", name: L("Mover", "Move", "Sposta"))
            c.imageProvider = { _ in UIImage(systemName: "hand.point.up.left.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold))! }
            c.allowsColorSelection = false
            c.toolAttributeControls = []
            return c
        }())
        let puntero = PKToolPickerCustomItem(configuration: {
            var c = PKToolPickerCustomItem.Configuration(identifier: "laser", name: L("Láser", "Laser", "Laser"))
            c.imageProvider = { _ in UIImage(systemName: "light.max", withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold))! }
            c.allowsColorSelection = false
            c.toolAttributeControls = []
            return c
        }())
        selector = PKToolPicker(toolItems: PKToolPicker.defaultToolItems + [mover, puntero])
        self.coordinador = coordinador
        super.init(frame: .zero)
        coordinador.contenedor = self
        lienzo.pizarra = coordinador.pizarra
        lienzo.delegate = coordinador
        lienzo.drawingPolicy = .anyInput
        lienzo.backgroundColor = .clear
        lienzo.isOpaque = false
        lienzo.minimumZoomScale = 0.4
        lienzo.maximumZoomScale = 4
        lienzo.contentSize = Self.tamano
        lienzo.contentInsetAdjustmentBehavior = .never
        lienzo.alwaysBounceVertical = true
        lienzo.alwaysBounceHorizontal = true
        addSubview(lienzo)
        backgroundColor = .systemBackground

        for capa in [papel, fotos, fantasma] {
            capa.isUserInteractionEnabled = false
            capa.layer.anchorPoint = .zero
            capa.bounds = CGRect(origin: .zero, size: Self.tamano)
            capa.layer.position = .zero
        }
        lienzo.insertSubview(fotos, at: 0)
        lienzo.insertSubview(papel, at: 0)
        lienzo.addSubview(fantasma)
        trazoFantasma.fillColor = nil
        trazoFantasma.lineCap = .round
        trazoFantasma.lineJoin = .round
        fantasma.layer.addSublayer(trazoFantasma)
        laser.fillColor = nil
        laser.lineCap = .round
        laser.lineJoin = .round
        laser.strokeColor = UIColor.systemRed.cgColor
        laser.lineWidth = 6
        laser.shadowColor = UIColor.systemRed.cgColor
        laser.shadowRadius = 8
        laser.shadowOpacity = 0.9
        laser.shadowOffset = .zero
        fantasma.layer.addSublayer(laser)

        dedo.backgroundColor = Self.colorAmigo
        dedo.layer.cornerRadius = 11
        dedo.layer.borderColor = UIColor.white.cgColor
        dedo.layer.borderWidth = 3
        dedo.layer.shadowColor = UIColor.black.cgColor
        dedo.layer.shadowOpacity = 0.25
        dedo.layer.shadowRadius = 5
        dedo.layer.shadowOffset = CGSize(width: 0, height: 3)
        dedo.frame = CGRect(x: 0, y: 0, width: 22, height: 22)
        dedo.isHidden = true
        dedo.isUserInteractionEnabled = false

        etiqueta.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 13, weight: .semibold), maximumPointSize: 20)
        etiqueta.adjustsFontForContentSizeCategory = true
        etiqueta.textColor = .white
        etiqueta.backgroundColor = Self.colorAmigo
        etiqueta.layer.cornerRadius = 8
        etiqueta.layer.masksToBounds = true
        etiqueta.textAlignment = .center
        etiqueta.isHidden = true
        addSubview(dedo)
        addSubview(etiqueta)

        let fantasmaGesto = GestoFantasma(target: coordinador, action: #selector(PizarraVista.Coordinador.toqueFantasma(_:)))
        fantasmaGesto.name = "fantasma"
        fantasmaGesto.delegate = coordinador
        fantasmaGesto.cancelsTouchesInView = false
        fantasmaGesto.delaysTouchesBegan = false
        fantasmaGesto.delaysTouchesEnded = false
        lienzo.addGestureRecognizer(fantasmaGesto)

        laserGesto.addTarget(coordinador, action: #selector(PizarraVista.Coordinador.toqueLaser(_:)))
        laserGesto.maximumNumberOfTouches = 1
        laserGesto.isEnabled = false
        lienzo.addGestureRecognizer(laserGesto)

        let gestos: [UIGestureRecognizer] = [UIPanGestureRecognizer(), UIPinchGestureRecognizer(), UIRotationGestureRecognizer()]
        for g in gestos {
            g.addTarget(coordinador, action: #selector(PizarraVista.Coordinador.moverFoto(_:)))
            g.name = "foto"
            g.delegate = coordinador
            lienzo.addGestureRecognizer(g)
        }
        lienzo.panGestureRecognizer.require(toFail: gestos[0])
        lienzo.pinchGestureRecognizer?.require(toFail: gestos[1])

        selector.addObserver(lienzo)
        selector.addObserver(coordinador)
        selector.showsDrawingPolicyControls = false
        let mas = UIBarButtonItem(image: UIImage(systemName: "plus.circle"), menu: menuMas())
        mas.accessibilityLabel = L("Añadir", "Add", "Aggiungi")
        selector.accessoryItem = mas
        herramienta = selector.selectedToolItem.identifier
        recolocar()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func menuMas() -> UIMenu {
        let pedir: (PedidoPizarra) -> Void = { [weak self] p in self?.coordinador?.alPedir(p) }
        let papeles = PapelPizarra.allCases.map { p in
            UIAction(title: p.nombre, image: UIImage(systemName: p.simbolo)) { [weak self] _ in self?.coordinador?.pizarra.cambiarPapel(p) }
        }
        return UIMenu(children: [
            UIAction(title: L("Foto", "Photo", "Foto"), image: UIImage(systemName: "photo")) { _ in pedir(.foto) },
            UIAction(title: L("Hacer una foto", "Take a Photo", "Scatta una foto"), image: UIImage(systemName: "camera")) { _ in pedir(.camara) },
            UIAction(title: L("Escanear", "Scan", "Scansiona"), image: UIImage(systemName: "doc.viewfinder")) { _ in pedir(.escanear) },
            UIMenu(title: L("Papel", "Paper", "Carta"), image: UIImage(systemName: "squareshape.split.3x3"), children: papeles),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        lienzo.frame = bounds
        recolocarDedo()
    }

    func mostrarPaleta(_ si: Bool) {
        lienzo.pencilKitResponderState.activeToolPicker = selector
        lienzo.pencilKitResponderState.toolPickerVisibility = si ? .visible : .hidden
        if si { lienzo.becomeFirstResponder() }
    }

    func recolocar() {
        let z = lienzo.zoomScale
        for capa in [papel, fotos, fantasma] { capa.transform = CGAffineTransform(scaleX: z, y: z) }
        recolocarDedo()
    }

    func recolocarDedo() {
        guard let p = ultimoPuntoAmigo else { dedo.isHidden = true; etiqueta.isHidden = true; return }
        let z = lienzo.zoomScale
        let enVista = CGPoint(x: p.x * z - lienzo.contentOffset.x, y: p.y * z - lienzo.contentOffset.y)
        dedo.center = enVista
        etiqueta.sizeToFit()
        let tam = CGSize(width: etiqueta.bounds.width + 16, height: max(etiqueta.bounds.height + 6, 22))

        let tapado = selector.isVisible ? selector.frameObscured(in: self) : .null
        let limite = bounds.insetBy(dx: 8, dy: 8)
        var origen = CGPoint(x: enVista.x + 12, y: enVista.y + 14)
        if origen.x + tam.width > limite.maxX { origen.x = enVista.x - 12 - tam.width }
        let caja = CGRect(origin: origen, size: tam)
        if caja.maxY > limite.maxY || (!tapado.isNull && caja.intersects(tapado)) { origen.y = enVista.y - 14 - tam.height }
        origen.x = min(max(origen.x, limite.minX), limite.maxX - tam.width)

        if !tapado.isNull, CGRect(origin: origen, size: tam).intersects(tapado) { origen.y = tapado.minY - tam.height - 6 }
        origen.y = max(origen.y, limite.minY)
        etiqueta.frame = CGRect(origin: origen, size: tam)
        dedo.isHidden = false
        etiqueta.isHidden = false
    }

    func ponerPapel(_ p: PapelPizarra) {
        guard p != papelPuesto else { return }
        papelPuesto = p
        papel.backgroundColor = UIColor { rasgos in
            let oscuro = rasgos.userInterfaceStyle == .dark
            return UIColor(patternImage: ContenedorPizarra.baldosa(p, oscuro: oscuro))
        }
    }

    static func baldosa(_ p: PapelPizarra, oscuro: Bool) -> UIImage {
        let lado: CGFloat = p == .rayas ? 32 : 22
        let fondo = oscuro ? UIColor(white: 0.07, alpha: 1) : UIColor(red: 0.988, green: 0.992, blue: 1, alpha: 1)
        let linea = oscuro ? UIColor(white: 1, alpha: 0.13) : UIColor(red: 0.84, green: 0.88, blue: 0.94, alpha: 1)
        return UIGraphicsImageRenderer(size: CGSize(width: lado, height: lado)).image { ctx in
            fondo.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: lado, height: lado))
            linea.setFill()
            switch p {
            case .cuadricula:
                ctx.fill(CGRect(x: 0, y: lado - 1, width: lado, height: 1))
                ctx.fill(CGRect(x: lado - 1, y: 0, width: 1, height: lado))
            case .rayas:
                ctx.fill(CGRect(x: 0, y: lado - 1, width: lado, height: 1))
            case .puntos:
                ctx.cgContext.fillEllipse(in: CGRect(x: lado / 2 - 1.2, y: lado / 2 - 1.2, width: 2.4, height: 2.4))
            case .liso:
                break
            }
        }
    }

    func ponerObjetos(_ objetos: [ObjetoPizarra], imagenes: [String: UIImage]) {
        let ids = Set(objetos.map(\.id))
        for (id, v) in vistasFotos where !ids.contains(id) { v.removeFromSuperview(); vistasFotos[id] = nil }
        for o in objetos {
            let v = vistasFotos[o.id] ?? {
                let nueva = UIImageView()
                nueva.contentMode = .scaleAspectFill
                nueva.clipsToBounds = true
                nueva.layer.cornerRadius = 4
                nueva.layer.borderColor = UIColor.black.withAlphaComponent(0.08).cgColor
                nueva.layer.borderWidth = 0.5
                nueva.isAccessibilityElement = true
                nueva.accessibilityLabel = L("Foto", "Photo", "Foto")
                vistasFotos[o.id] = nueva
                return nueva
            }()
            if v.superview == nil { fotos.addSubview(v) } else { fotos.bringSubviewToFront(v) }
            v.image = imagenes[o.archivo]
            v.backgroundColor = v.image == nil ? .secondarySystemFill : .clear
            v.transform = .identity
            v.bounds = CGRect(x: 0, y: 0, width: o.ancho, height: o.alto)
            v.center = o.centro
            v.transform = CGAffineTransform(rotationAngle: o.giro)
        }
    }

    func ponerFantasma(_ f: Fantasma?, nombre: String) {
        etiqueta.text = nombre
        guard let f, let ultimo = f.puntos.last else {
            trazoFantasma.path = nil
            ultimoPuntoAmigo = nil
            recolocarDedo()
            return
        }
        let camino = UIBezierPath()
        camino.move(to: f.puntos[0])
        for p in f.puntos.dropFirst() { camino.addLine(to: p) }
        trazoFantasma.path = camino.cgPath
        trazoFantasma.lineWidth = f.ancho
        trazoFantasma.strokeColor = (f.laser ? UIColor.systemRed : f.color).withAlphaComponent(f.laser ? 0.9 : 0.6).cgColor
        trazoFantasma.shadowColor = f.laser ? UIColor.systemRed.cgColor : nil
        trazoFantasma.shadowRadius = f.laser ? 8 : 0
        trazoFantasma.shadowOpacity = f.laser ? 0.9 : 0
        ultimoPuntoAmigo = ultimo
        recolocarDedo()
    }

    func laserPropio(_ puntos: [CGPoint], terminar: Bool) {
        desvanecer?.cancel()
        guard let primero = puntos.first else { laser.path = nil; return }
        let camino = UIBezierPath()
        camino.move(to: primero)
        for p in puntos.dropFirst() { camino.addLine(to: p) }
        laser.opacity = 1
        laser.path = camino.cgPath
        guard terminar else { return }
        let trabajo = DispatchWorkItem { [weak self] in
            guard let self else { return }
            CATransaction.begin()
            CATransaction.setAnimationDuration(UIAccessibility.isReduceMotionEnabled ? 0 : 0.6)
            self.laser.opacity = 0
            CATransaction.commit()
        }
        desvanecer = trabajo
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: trabajo)
    }
}

final class GestoFantasma: UIGestureRecognizer {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard touches.count == 1, event.allTouches?.count == 1 else { state = .failed; return }
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard event.allTouches?.count == 1 else { state = .cancelled; return }
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { state = .ended }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { state = .cancelled }
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}

extension UIFont {
    func conPeso(_ peso: UIFont.Weight) -> UIFont {
        let d = fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: peso]])
        return UIFont(descriptor: d, size: 0)
    }
}
