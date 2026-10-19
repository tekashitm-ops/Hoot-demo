import SwiftUI
import UIKit

struct EditorApuntesVista: UIViewRepresentable {
    var apuntes: ApuntesCompartidos
    var nombreAmigo: String
    @Binding var estiloEscritura: EstiloLetra
    @Binding var seleccion: Range<Int>

    func makeCoordinator() -> Coordinador { Coordinador(apuntes: apuntes) }

    func makeUIView(context: Context) -> TextoApuntes {
        let t = TextoApuntes(usingTextLayoutManager: true)
        t.delegate = context.coordinator
        t.backgroundColor = .systemBackground
        t.textContainerInset = UIEdgeInsets(top: 16, left: 18, bottom: 120, right: 18)
        t.adjustsFontForContentSizeCategory = true
        t.alwaysBounceVertical = true
        t.keyboardDismissMode = .interactive
        t.allowsEditingTextAttributes = false
        t.coordinador = context.coordinator
        context.coordinator.vista = t
        let toque = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinador.tocar(_:)))
        toque.delegate = context.coordinator
        t.addGestureRecognizer(toque)
        t.inputAccessoryView = context.coordinator.barra
        context.coordinator.pintar()
        return t
    }

    func updateUIView(_ t: TextoApuntes, context: Context) {
        let c = context.coordinator
        c.padre = self
        c.apuntes = apuntes
        if c.versionPintada != apuntes.versionFuera { c.pintar() }
        _ = apuntes.cursorAmigo.map { $0 }
        c.colocarCursorAmigo()
        c.barra.actualizar(estilo: estiloEscritura)
    }

    final class Coordinador: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var apuntes: ApuntesCompartidos
        var padre: EditorApuntesVista?
        weak var vista: TextoApuntes?
        var versionPintada = -1
        lazy var barra = BarraFormatoApuntes(alCambiar: { [weak self] c in self?.aplicarFormato(c) })

        private var inicios: [Int] = []
        private var marcas: Set<Int> = []
        private var textoPintado = ""
        private var pintando = false
        private let cursorOtro = UIView()
        private let banderaOtro = UILabel()
        private var ultimoCursor: String?
        private var ocultarBandera: DispatchWorkItem?
        private var resaltesOtro: [UIView] = []

        init(apuntes: ApuntesCompartidos) {
            self.apuntes = apuntes
            super.init()
            cursorOtro.backgroundColor = ContenedorPizarra.colorAmigo
            cursorOtro.isUserInteractionEnabled = false
            banderaOtro.font = .preferredFont(forTextStyle: .caption2).conPeso(.semibold)
            banderaOtro.textColor = .white
            banderaOtro.backgroundColor = ContenedorPizarra.colorAmigo
            banderaOtro.layer.cornerRadius = 5
            banderaOtro.layer.masksToBounds = true
            banderaOtro.textAlignment = .center
        }

        func pintar() {
            guard let t = vista else { return }
            let vis = apuntes.visibles

            let sel = t.selectedRange
            let desde = indiceDocumento(sel.location), hasta = indiceDocumento(sel.location + sel.length)
            let (texto, inicios, marcas) = RenderApuntes.componer(vis, oscuro: t.traitCollection.userInterfaceStyle == .dark)
            self.inicios = inicios
            self.marcas = marcas
            pintando = true
            t.attributedText = texto
            textoPintado = texto.string
            pintando = false
            let a = posicionVista(desde), b = posicionVista(hasta)
            t.selectedRange = NSRange(location: a, length: max(0, b - a))
            versionPintada = apuntes.versionFuera
            t.typingAttributes = RenderApuntes.atributos(padre?.estiloEscritura ?? .normal, oscuro: t.traitCollection.userInterfaceStyle == .dark)
            colocarCursorAmigo()
        }

        func indiceDocumento(_ u: Int) -> Int {
            var lo = 0, hi = inicios.count
            while lo < hi {
                let m = (lo + hi) / 2
                if inicios[m] < u { lo = m + 1 } else { hi = m }
            }
            return lo
        }

        func posicionVista(_ i: Int) -> Int {
            if i < inicios.count { return inicios[i] }
            return (textoPintado as NSString).length
        }

        func textView(_ t: UITextView, shouldChangeTextIn r: NSRange, replacementText texto: String) -> Bool {
            guard t.markedTextRange == nil else { return true }
            let vis = apuntes.visibles

            if texto.isEmpty, r.length == 1, marcas.contains(r.location) {
                let i = indiceDocumento(r.location + 1)
                apuntes.cambiar(i..<i, .lista(nil))
                pintar()
                return false
            }

            if texto == "\n", r.length == 0 {
                let i = indiceDocumento(r.location)
                let enPunto = (i < vis.count ? vis[i].estilo.lista : (i > 0 ? vis[i - 1].estilo.lista : nil)) != nil
                let antesVacio = i == 0 || vis[i - 1].c == "\n"
                let despuesVacio = i >= vis.count || vis[i].c == "\n"
                if enPunto && antesVacio && despuesVacio {
                    apuntes.cambiar(i..<i, .lista(nil))
                    pintar()
                    return false
                }
            }
            let desde = indiceDocumento(r.location), hasta = indiceDocumento(r.location + r.length)
            var estilo = padre?.estiloEscritura ?? .normal

            let ref = desde < vis.count ? vis[desde] : (desde > 0 ? vis[desde - 1] : nil)
            if let ref { estilo = estilo.conParrafo(de: ref.estilo) }
            if texto == "\n", let ref, ref.estilo.lista == .hecha { estilo.lista = .casilla }
            apuntes.editar(desde..<max(desde, hasta), por: texto, estilo: estilo)
            pintar()
            let nueva = posicionVista(desde + texto.count)
            t.selectedRange = NSRange(location: nueva, length: 0)
            seleccionCambiada(t)
            return false
        }

        func textViewDidChange(_ t: UITextView) {
            guard !pintando, t.markedTextRange == nil else { return }
            let nuevo = t.textStorage.string as NSString
            let viejo = textoPintado as NSString
            guard nuevo != viejo else { return }
            var p = 0
            while p < min(nuevo.length, viejo.length) && nuevo.character(at: p) == viejo.character(at: p) { p += 1 }
            var s = 0
            while s < min(nuevo.length, viejo.length) - p && nuevo.character(at: nuevo.length - 1 - s) == viejo.character(at: viejo.length - 1 - s) { s += 1 }
            let insertado = nuevo.substring(with: NSRange(location: p, length: nuevo.length - p - s)).replacingOccurrences(of: "\u{FFFC}", with: "")
            let desde = indiceDocumento(p), hasta = indiceDocumento(viejo.length - s)
            var estilo = padre?.estiloEscritura ?? .normal
            let vis = apuntes.visibles
            if let ref = desde < vis.count ? vis[desde] : (desde > 0 ? vis[desde - 1] : nil) { estilo = estilo.conParrafo(de: ref.estilo) }
            apuntes.editar(desde..<max(desde, hasta), por: insertado, estilo: estilo)
            pintar()
            t.selectedRange = NSRange(location: posicionVista(desde + insertado.count), length: 0)
        }

        func textViewDidChangeSelection(_ t: UITextView) {
            guard !pintando else { return }
            seleccionCambiada(t)
        }

        private func seleccionCambiada(_ t: UITextView) {
            let r = t.selectedRange
            let desde = indiceDocumento(r.location), hasta = indiceDocumento(r.location + r.length)
            apuntes.moverCursor(desde: desde, hasta: hasta)
            let vis = apuntes.visibles

            if let ref = desde > 0 && desde <= vis.count ? vis[desde - 1] : (vis.first) {
                var e = ref.estilo
                if ref.c == "\n", desde < vis.count { e = vis[desde].estilo }
                if padre?.estiloEscritura != e { padre?.estiloEscritura = e }
            }
            padre?.seleccion = desde..<max(desde, hasta)
        }

        func aplicarFormato(_ c: CambioEstilo) {
            guard let t = vista else { return }
            let r = t.selectedRange
            let desde = indiceDocumento(r.location), hasta = indiceDocumento(r.location + r.length)
            var e = padre?.estiloEscritura ?? .normal
            e.aplicar(c)
            padre?.estiloEscritura = e
            if hasta > desde || c.esDeParrafo {
                apuntes.cambiar(desde..<hasta, c)
                pintar()
            } else {
                t.typingAttributes = RenderApuntes.atributos(e, oscuro: t.traitCollection.userInterfaceStyle == .dark)
            }
            barra.actualizar(estilo: e)
        }

        @objc func tocar(_ g: UITapGestureRecognizer) {
            guard let t = vista else { return }
            let p = g.location(in: t)
            guard let pos = t.closestPosition(to: p) else { return }
            let u = t.offset(from: t.beginningOfDocument, to: pos)
            for m in [u, u - 1] where marcas.contains(m) {
                guard let inicio = t.position(from: t.beginningOfDocument, offset: m), let fin = t.position(from: inicio, offset: 1),
                      let rango = t.textRange(from: inicio, to: fin) else { continue }
                let caja = t.firstRect(for: rango).insetBy(dx: -10, dy: -8)
                guard caja.contains(p) else { continue }
                let i = indiceDocumento(m + 1)
                let vis = apuntes.visibles
                guard i < vis.count || i > 0 else { return }
                let lista = (i < vis.count ? vis[i] : vis[i - 1]).estilo.lista
                if lista == .casilla { apuntes.cambiar(i..<i, .lista(.hecha)); hapticoCasilla() }
                else if lista == .hecha { apuntes.cambiar(i..<i, .lista(.casilla)) }
                pintar()
                return
            }
        }

        private func hapticoCasilla() {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otro: UIGestureRecognizer) -> Bool { true }

        func colocarCursorAmigo() {
            guard let t = vista else { return }
            for v in resaltesOtro { v.removeFromSuperview() }
            resaltesOtro = []
            guard let c = apuntes.cursorAmigo, let i = apuntes.posicion(trasDe: c.antes),
                  let pos = t.position(from: t.beginningOfDocument, offset: posicionVista(i)) else {
                cursorOtro.removeFromSuperview()
                banderaOtro.removeFromSuperview()
                return
            }
            if let hasta = c.hasta, let j = apuntes.posicion(trasDe: hasta), j > i,
               let fin = t.position(from: t.beginningOfDocument, offset: posicionVista(j)), let rango = t.textRange(from: pos, to: fin) {
                for r in t.selectionRects(for: rango) where r.rect.width > 0 {
                    let v = UIView(frame: r.rect)
                    v.backgroundColor = ContenedorPizarra.colorAmigo.withAlphaComponent(0.18)
                    v.isUserInteractionEnabled = false
                    t.insertSubview(v, at: 0)
                    resaltesOtro.append(v)
                }
            }
            let caret = t.caretRect(for: pos)
            cursorOtro.frame = CGRect(x: caret.minX, y: caret.minY, width: 2, height: caret.height)

            let clave = "\(i)-\(c.hasta.map { "\($0.a):\($0.n)" } ?? "")"
            if clave != ultimoCursor {
                ultimoCursor = clave
                banderaOtro.alpha = 1
                ocultarBandera?.cancel()
                if !ModoCapturas.activo {
                    let trabajo = DispatchWorkItem { [weak self] in
                        UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.4) { self?.banderaOtro.alpha = 0 }
                    }
                    ocultarBandera = trabajo
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: trabajo)
                }
            }
            banderaOtro.text = padre?.nombreAmigo ?? ""
            banderaOtro.sizeToFit()
            banderaOtro.frame = CGRect(x: caret.minX, y: caret.minY - banderaOtro.bounds.height - 2, width: banderaOtro.bounds.width + 10,
                                       height: banderaOtro.bounds.height + 2)
            if cursorOtro.superview == nil { t.addSubview(cursorOtro) }
            if banderaOtro.superview == nil { t.addSubview(banderaOtro) }
        }

        func traitsCambiados() {
            versionPintada = -1
            pintar()
        }
    }
}

final class TextoApuntes: UITextView {
    weak var coordinador: EditorApuntesVista.Coordinador?

    override func traitCollectionDidChange(_ previo: UITraitCollection?) {
        super.traitCollectionDidChange(previo)
        if previo?.userInterfaceStyle != traitCollection.userInterfaceStyle || previo?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            coordinador?.traitsCambiados()
        }
    }
}

enum ColorApuntes: String, CaseIterable {
    case rojo, naranja, verde, azul, morado, rosa

    var nombre: String {
        switch self {
        case .rojo: L("Rojo", "Red", "Rosso")
        case .naranja: L("Naranja", "Orange", "Arancione")
        case .verde: L("Verde", "Green", "Verde")
        case .azul: L("Azul", "Blue", "Blu")
        case .morado: L("Morado", "Purple", "Viola")
        case .rosa: L("Rosa", "Pink", "Rosa")
        }
    }

    var letra: UIColor {
        switch self {
        case .rojo: .systemRed
        case .naranja: UIColor { $0.userInterfaceStyle == .dark ? .systemOrange : UIColor(red: 0.76, green: 0.25, blue: 0.05, alpha: 1) }
        case .verde: UIColor { $0.userInterfaceStyle == .dark ? .systemGreen : UIColor(red: 0.13, green: 0.5, blue: 0.2, alpha: 1) }
        case .azul: .systemBlue
        case .morado: .systemPurple
        case .rosa: .systemPink
        }
    }

    var resalte: UIColor { letra.withAlphaComponent(0.26) }
}

enum RenderApuntes {

    static func componer(_ letras: [Letra], oscuro: Bool) -> (NSAttributedString, [Int], Set<Int>) {
        let r = NSMutableAttributedString()
        var inicios: [Int] = []
        var marcas: Set<Int> = []
        var u = 0
        var principio = true
        var numero = 0
        var i = 0
        while i <= letras.count {
            if principio {
                principio = false

                let est = i < letras.count ? letras[i].estilo : (letras.last?.c == "\n" ? letras.last!.estilo : .normal)
                if est.lista == .numero { numero += 1 } else { numero = 0 }
                if let lista = est.lista, i < letras.count || letras.last?.c == "\n" || letras.isEmpty {
                    r.append(marca(lista, numero: numero, estilo: est, oscuro: oscuro))
                    marcas.insert(u)
                    u += 1
                }
            }
            guard i < letras.count else { break }
            let l = letras[i]
            inicios.append(u)
            let s = String(l.c)
            r.append(NSAttributedString(string: s, attributes: atributos(l.estilo, oscuro: oscuro)))
            u += (s as NSString).length
            if l.c == "\n" { principio = true }
            i += 1
        }
        return (r, inicios, marcas)
    }

    static func fuente(_ e: EstiloLetra) -> UIFont {
        let estiloTexto: UIFont.TextStyle
        var peso: UIFont.Weight = .regular
        switch e.parrafo {
        case .titulo: estiloTexto = .title1; peso = .bold
        case .encabezado: estiloTexto = .title2; peso = .bold
        case .subencabezado: estiloTexto = .title3; peso = .semibold
        case .cuerpo, .mono: estiloTexto = .body
        }
        if e.negrita { peso = peso == .regular ? .bold : .heavy }
        let base = UIFont.preferredFont(forTextStyle: estiloTexto)
        let factor: CGFloat = switch e.tamano {
        case .pequeno: 0.85
        case .normal: 1
        case .grande: 1.25
        case .enorme: 1.6
        }
        let tam = base.pointSize * factor
        var f: UIFont
        if e.fuente == .mano {
            f = UIFont(name: e.negrita ? "Noteworthy-Bold" : "Noteworthy-Light", size: tam * 1.08) ?? UIFont.systemFont(ofSize: tam, weight: peso)
        } else {
            f = UIFont.systemFont(ofSize: tam, weight: peso)
            let diseno: UIFontDescriptor.SystemDesign? = switch e.parrafo == .mono ? FuenteApuntes.mono : e.fuente {
            case .redondeada: .rounded
            case .serif: .serif
            case .mono: .monospaced
            default: nil
            }
            if let diseno, let d = f.fontDescriptor.withDesign(diseno) { f = UIFont(descriptor: d, size: tam) }
        }
        if e.cursiva, let d = f.fontDescriptor.withSymbolicTraits(f.fontDescriptor.symbolicTraits.union(.traitItalic)) {
            f = UIFont(descriptor: d, size: f.pointSize)
        }
        return f
    }

    static func atributos(_ e: EstiloLetra, oscuro: Bool) -> [NSAttributedString.Key: Any] {
        var a: [NSAttributedString.Key: Any] = [.font: fuente(e)]
        a[.foregroundColor] = e.color.flatMap(ColorApuntes.init(rawValue:))?.letra ?? UIColor.label
        if let h = e.resalte.flatMap(ColorApuntes.init(rawValue:)) { a[.backgroundColor] = h.resalte }
        if e.subrayado { a[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if e.tachado { a[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if e.lista == .hecha { a[.foregroundColor] = UIColor.secondaryLabel; a[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        let p = NSMutableParagraphStyle()
        let sangria = CGFloat(e.sangria) * 24
        p.firstLineHeadIndent = sangria
        p.headIndent = sangria + (e.lista != nil ? 30 : 0)
        p.paragraphSpacingBefore = e.parrafo == .cuerpo || e.parrafo == .mono ? 0 : 6
        p.lineHeightMultiple = 1.05
        a[.paragraphStyle] = p
        return a
    }

    private static func marca(_ lista: TipoLista, numero: Int, estilo: EstiloLetra, oscuro: Bool) -> NSAttributedString {
        let f = fuente(estilo)
        let alto = f.capHeight
        let ancho: CGFloat = 30
        let imagen = UIGraphicsImageRenderer(size: CGSize(width: ancho, height: f.lineHeight)).image { _ in
            let medio = f.lineHeight / 2 + (f.ascender - f.lineHeight / 2 - alto / 2) * 0
            switch lista {
            case .vineta:
                UIColor.label.setFill()
                UIBezierPath(ovalIn: CGRect(x: 6, y: medio - 3, width: 6, height: 6)).fill()
            case .guion:
                UIColor.label.setFill()
                UIBezierPath(roundedRect: CGRect(x: 4, y: medio - 1, width: 11, height: 2), cornerRadius: 1).fill()
            case .numero:
                let t = NSAttributedString(string: "\(numero).", attributes: [.font: f.withSize(f.pointSize * 0.95), .foregroundColor: UIColor.label])
                let tam = t.size()
                t.draw(at: CGPoint(x: max(0, 22 - tam.width), y: (f.lineHeight - tam.height) / 2))
            case .casilla, .hecha:
                let lado = min(22, f.lineHeight - 2)
                let caja = CGRect(x: 2, y: (f.lineHeight - lado) / 2, width: lado, height: lado)
                if lista == .hecha {
                    UIColor(Color.acentoRelleno).setFill()
                    UIBezierPath(ovalIn: caja).fill()
                    let c = UIBezierPath()
                    c.move(to: CGPoint(x: caja.minX + lado * 0.28, y: caja.midY))
                    c.addLine(to: CGPoint(x: caja.minX + lado * 0.44, y: caja.minY + lado * 0.66))
                    c.addLine(to: CGPoint(x: caja.minX + lado * 0.74, y: caja.minY + lado * 0.34))
                    UIColor.white.setStroke()
                    c.lineWidth = 2
                    c.lineCapStyle = .round
                    c.lineJoinStyle = .round
                    c.stroke()
                } else {
                    UIColor.tertiaryLabel.setStroke()
                    let c = UIBezierPath(ovalIn: caja.insetBy(dx: 0.8, dy: 0.8))
                    c.lineWidth = 1.6
                    c.stroke()
                }
            }
        }
        let adjunto = NSTextAttachment(image: imagen.withRenderingMode(.alwaysOriginal))
        adjunto.bounds = CGRect(x: 0, y: f.descender, width: ancho, height: f.lineHeight)
        let s = NSMutableAttributedString(attachment: adjunto)
        var at = atributos(estilo, oscuro: oscuro)
        at[.strikethroughStyle] = nil
        s.addAttributes(at, range: NSRange(location: 0, length: s.length))
        if lista == .casilla || lista == .hecha {
            s.addAttribute(.accessibilityTextCustom, value: [lista == .hecha ? L("Hecho", "Done", "Fatto") : L("Sin hacer", "Not done", "Da fare")],
                           range: NSRange(location: 0, length: s.length))
        }
        return s
    }

    static func pdf(_ letras: [Letra], titulo: String) -> Data {
        let (texto, _, _) = componer(letras, oscuro: false)
        let formateador = UISimpleTextPrintFormatter(attributedText: texto)
        let render = UIPrintPageRenderer()
        render.addPrintFormatter(formateador, startingAtPageAt: 0)
        let pagina = CGRect(x: 0, y: 0, width: 595, height: 842)
        render.setValue(NSValue(cgRect: pagina), forKey: "paperRect")
        render.setValue(NSValue(cgRect: pagina.insetBy(dx: 48, dy: 56)), forKey: "printableRect")
        let datos = NSMutableData()
        UIGraphicsBeginPDFContextToData(datos, pagina, [kCGPDFContextTitle as String: titulo])
        for i in 0..<max(render.numberOfPages, 1) {
            UIGraphicsBeginPDFPage()
            render.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        return datos as Data
    }
}

final class BarraFormatoApuntes: UIInputView {
    private let alCambiar: (CambioEstilo) -> Void
    private var anfitrion: UIHostingController<BarraFormato>?
    private let estado = EstadoBarra()

    init(alCambiar: @escaping (CambioEstilo) -> Void) {
        self.alCambiar = alCambiar
        super.init(frame: CGRect(x: 0, y: 0, width: 400, height: 58), inputViewStyle: .keyboard)
        allowsSelfSizing = true
        let h = UIHostingController(rootView: BarraFormato(estado: estado, alCambiar: alCambiar))
        h.view.backgroundColor = .clear
        h.sizingOptions = .intrinsicContentSize
        h.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(h.view)
        NSLayoutConstraint.activate([
            h.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            h.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            h.view.topAnchor.constraint(equalTo: topAnchor),
            h.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        anfitrion = h
    }

    required init?(coder: NSCoder) { fatalError() }

    func actualizar(estilo: EstiloLetra) {
        if estado.estilo != estilo { estado.estilo = estilo }
    }
}

@Observable
final class EstadoBarra {
    var estilo = EstiloLetra.normal
}

struct BarraFormato: View {
    var estado: EstadoBarra
    var alCambiar: (CambioEstilo) -> Void

    var body: some View {
        let e = estado.estilo
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Menu {
                    Picker(L("Estilo", "Style", "Stile"), selection: Binding(get: { e.parrafo }, set: { alCambiar(.parrafo($0)) })) {
                        Text(L("Título", "Title", "Titolo")).tag(EstiloParrafo.titulo)
                        Text(L("Encabezado", "Heading", "Intestazione")).tag(EstiloParrafo.encabezado)
                        Text(L("Subencabezado", "Subheading", "Sottotitolo")).tag(EstiloParrafo.subencabezado)
                        Text(L("Cuerpo", "Body", "Corpo")).tag(EstiloParrafo.cuerpo)
                        Text(L("Monoespaciado", "Monostyled", "Monospaziato")).tag(EstiloParrafo.mono)
                    }
                } label: { boton(Image(systemName: "textformat"), activo: e.parrafo != .cuerpo) }
                    .accessibilityLabel(L("Estilo de párrafo", "Paragraph style", "Stile del paragrafo"))
                Menu {
                    Picker(L("Fuente", "Font", "Carattere"), selection: Binding(get: { e.fuente }, set: { alCambiar(.fuente($0)) })) {
                        ForEach(FuenteApuntes.allCases, id: \.self) { f in Text(Self.nombre(f)).tag(f) }
                    }
                } label: { boton(Text(Self.nombre(e.fuente)).font(.subheadline.weight(.semibold)), activo: e.fuente != .sistema) }
                Menu {
                    Picker(L("Tamaño", "Size", "Dimensione"), selection: Binding(get: { e.tamano }, set: { alCambiar(.tamano($0)) })) {
                        Text(L("Pequeño", "Small", "Piccolo")).tag(TamanoApuntes.pequeno)
                        Text(L("Normal", "Normal", "Normale")).tag(TamanoApuntes.normal)
                        Text(L("Grande", "Large", "Grande")).tag(TamanoApuntes.grande)
                        Text(L("Enorme", "Huge", "Enorme")).tag(TamanoApuntes.enorme)
                    }
                } label: { boton(Image(systemName: "textformat.size"), activo: e.tamano != .normal) }
                    .accessibilityLabel(L("Tamaño", "Size", "Dimensione"))
                separador
                Button { alCambiar(.negrita(!e.negrita)) } label: { boton(Image(systemName: "bold"), activo: e.negrita) }
                    .accessibilityLabel(L("Negrita", "Bold", "Grassetto"))
                Button { alCambiar(.cursiva(!e.cursiva)) } label: { boton(Image(systemName: "italic"), activo: e.cursiva) }
                    .accessibilityLabel(L("Cursiva", "Italic", "Corsivo"))
                Button { alCambiar(.subrayado(!e.subrayado)) } label: { boton(Image(systemName: "underline"), activo: e.subrayado) }
                    .accessibilityLabel(L("Subrayado", "Underline", "Sottolineato"))
                Button { alCambiar(.tachado(!e.tachado)) } label: { boton(Image(systemName: "strikethrough"), activo: e.tachado) }
                    .accessibilityLabel(L("Tachado", "Strikethrough", "Barrato"))
                Menu {
                    Section(L("Letra", "Text", "Testo")) {
                        Button(L("Automático", "Automatic", "Automatico")) { alCambiar(.color(nil)) }
                        ForEach(ColorApuntes.allCases, id: \.self) { c in
                            Button { alCambiar(.color(c.rawValue)) } label: { Label(c.nombre, systemImage: "circle.fill").tint(Color(c.letra)) }
                        }
                    }
                    Section(L("Resalte", "Highlight", "Evidenziatore")) {
                        Button(L("Sin resalte", "No highlight", "Nessuno")) { alCambiar(.resalte(nil)) }
                        ForEach(ColorApuntes.allCases, id: \.self) { c in
                            Button { alCambiar(.resalte(c.rawValue)) } label: { Label(c.nombre, systemImage: "highlighter") }
                        }
                    }
                } label: {
                    boton(Image(systemName: "paintpalette"), activo: e.color != nil || e.resalte != nil)
                }
                .accessibilityLabel(L("Color", "Color", "Colore"))
                separador
                Menu {
                    Button(L("Viñetas", "Bulleted", "Puntato"), systemImage: "list.bullet") { alCambiar(.lista(e.lista == .vineta ? nil : .vineta)) }
                    Button(L("Guiones", "Dashed", "Trattini"), systemImage: "list.dash") { alCambiar(.lista(e.lista == .guion ? nil : .guion)) }
                    Button(L("Numerada", "Numbered", "Numerato"), systemImage: "list.number") { alCambiar(.lista(e.lista == .numero ? nil : .numero)) }
                } label: { boton(Image(systemName: "list.bullet"), activo: e.lista == .vineta || e.lista == .guion || e.lista == .numero) }
                    .accessibilityLabel(L("Lista", "List", "Elenco"))
                Button { alCambiar(.lista(e.lista == .casilla || e.lista == .hecha ? nil : .casilla)) } label: {
                    boton(Image(systemName: "checklist"), activo: e.lista == .casilla || e.lista == .hecha)
                }
                .accessibilityLabel(L("Casillas", "Checklist", "Elenco di controllo"))
                Button { alCambiar(.sangria(e.sangria - 1)) } label: { boton(Image(systemName: "decrease.indent"), activo: false) }
                    .disabled(e.sangria == 0)
                    .accessibilityLabel(L("Menos sangría", "Decrease indent", "Riduci rientro"))
                Button { alCambiar(.sangria(e.sangria + 1)) } label: { boton(Image(systemName: "increase.indent"), activo: false) }
                    .accessibilityLabel(L("Más sangría", "Increase indent", "Aumenta rientro"))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .glassEffect(.regular, in: Capsule())
            .padding(.horizontal, 8)
        }
        .scrollClipDisabled()
        .frame(height: 58)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var separador: some View {
        Rectangle().fill(.separator).frame(width: 1, height: 22).padding(.horizontal, 2)
    }

    private func boton(_ contenido: some View, activo: Bool) -> some View {
        contenido
            .font(.body.weight(.semibold))
            .frame(minWidth: 40, minHeight: 40)
            .padding(.horizontal, 2)
            .foregroundStyle(activo ? Color.acento : Color.primary)
            .background(activo ? Color.acento.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
    }

    static func nombre(_ f: FuenteApuntes) -> String {
        switch f {
        case .sistema: L("Sistema", "System", "Sistema")
        case .redondeada: L("Redondeada", "Rounded", "Arrotondato")
        case .serif: "Serif"
        case .mono: L("Mono", "Mono", "Mono")
        case .mano: L("A mano", "Handwritten", "A mano")
        }
    }
}
