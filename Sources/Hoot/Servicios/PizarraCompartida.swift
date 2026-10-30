import PencilKit
import SwiftUI

enum PapelPizarra: String, CaseIterable, Sendable {
    case cuadricula, rayas, puntos, liso

    var nombre: String {
        switch self {
        case .cuadricula: L("Cuadrícula", "Grid", "Quadretti")
        case .rayas: L("Rayas", "Lines", "Righe")
        case .puntos: L("Puntos", "Dots", "Puntini")
        case .liso: L("Liso", "Plain", "Liscio")
        }
    }

    var simbolo: String {
        switch self {
        case .cuadricula: "squareshape.split.3x3"
        case .rayas: "line.3.horizontal"
        case .puntos: "circle.grid.3x3"
        case .liso: "square"
        }
    }
}

struct TrazoSala {
    var id: String
    var de: String
    var trazo: PKStroke
}

struct ObjetoPizarra: Equatable, Identifiable {
    var id: String
    var de: String
    var archivo: String
    var centro: CGPoint
    var ancho: CGFloat
    var alto: CGFloat
    var giro: Double
    var orden: Double
}

struct Fantasma: Equatable {
    var puntos: [CGPoint]
    var color: UIColor
    var ancho: CGFloat
    var laser: Bool
}

@Observable
final class PizarraCompartida: ParteDeSala {
    let nombre = "pizarra"
    weak var sala: SalaEnVivo?
    let yo: String

    private(set) var trazos: [String: TrazoSala] = [:]

    private(set) var versionTrazos = 0
    private(set) var objetos: [String: ObjetoPizarra] = [:]
    private(set) var imagenes: [String: UIImage] = [:]
    private(set) var fantasma: Fantasma?
    private(set) var papel: PapelPizarra = .cuadricula

    private(set) var puedeDeshacer = false
    private(set) var puedeRehacer = false

    @ObservationIgnored private var empuje = IDEmpuje()
    @ObservationIgnored private var bajando: Set<String> = []
    @ObservationIgnored private var pilaDeshacer: [Accion] = []
    @ObservationIgnored private var pilaRehacer: [Accion] = []
    @ObservationIgnored private var ultimoFantasma = Date.distantPast
    @ObservationIgnored private var fantasmaPendiente: Fantasma?
    @ObservationIgnored private var envioFantasma: Task<Void, Never>?

    private enum Accion {
        case trazos(puestos: [TrazoSala], quitados: [TrazoSala])
        case objeto(antes: ObjetoPizarra?, despues: ObjetoPizarra?)
    }

    init(yo: String) { self.yo = yo }

    var ordenados: [TrazoSala] { trazos.values.sorted { $0.id < $1.id } }
    var objetosOrdenados: [ObjetoPizarra] { objetos.values.sorted { ($0.orden, $0.id) < ($1.orden, $1.id) } }

    func actualizar(_ valor: JSONVivo, cambio: [String]) {
        let parte = cambio.first
        if parte == nil || parte == "fantasma" { leerFantasma(valor["fantasma"]) }
        if parte == nil || parte == "papel" { papel = valor["papel"].texto.flatMap(PapelPizarra.init(rawValue:)) ?? .cuadricula }
        if parte == nil || parte == "objetos" { leerObjetos(valor["objetos"]) }
        if parte == nil || parte == "trazos" { leerTrazos(valor["trazos"]) }
    }

    private func leerTrazos(_ j: JSONVivo) {
        let llegados = j.objeto
        var cambiado = false
        for id in trazos.keys where llegados[id] == nil {
            trazos[id] = nil
            cambiado = true
        }
        for (id, t) in llegados where trazos[id] == nil {
            guard let b64 = t["d"].texto, let d = Data(base64Encoded: b64), let dibujo = try? PKDrawing(data: d), let trazo = dibujo.strokes.first else { continue }
            trazos[id] = TrazoSala(id: id, de: t["de"].texto ?? "", trazo: trazo)
            cambiado = true
        }
        if cambiado { versionTrazos += 1 }
    }

    private func leerObjetos(_ j: JSONVivo) {
        var nuevos: [String: ObjetoPizarra] = [:]
        for (id, o) in j.objeto {
            guard let archivo = o["archivo"].texto else { continue }
            nuevos[id] = ObjetoPizarra(id: id, de: o["de"].texto ?? "", archivo: archivo,
                                       centro: CGPoint(x: o["x"].numero ?? 0, y: o["y"].numero ?? 0),
                                       ancho: o["an"].numero ?? 200, alto: o["al"].numero ?? 150, giro: o["g"].numero ?? 0, orden: o["o"].numero ?? 0)
            if imagenes[archivo] == nil { bajar(archivo) }
        }
        if nuevos != objetos { objetos = nuevos }
    }

    private func bajar(_ archivo: String) {
        guard !bajando.contains(archivo) else { return }
        bajando.insert(archivo)
        Task {
            if let d = await sala?.bajarArchivo(archivo), let img = UIImage(data: d) { imagenes[archivo] = img }
            bajando.remove(archivo)
        }
    }

    private func leerFantasma(_ j: JSONVivo) {
        let otro = j.objeto.first { $0.key != yo }?.value ?? .nulo
        guard let p = otro["p"].texto, !p.isEmpty else {
            if fantasma != nil { fantasma = nil }
            return
        }
        let puntos = p.split(separator: ";").compactMap { par -> CGPoint? in
            let xy = par.split(separator: ",")
            guard xy.count == 2, let x = Double(xy[0]), let y = Double(xy[1]) else { return nil }
            return CGPoint(x: x, y: y)
        }
        fantasma = Fantasma(puntos: puntos, color: UIColor(hex: otro["c"].texto ?? "") ?? .label, ancho: otro["a"].numero ?? 4,
                            laser: otro["l"].bool ?? false)
    }

    @discardableResult
    func cambiosPropios(puestos: [PKStroke], quitados: [String]) -> [String] {
        let fuera = quitados.compactMap { trazos[$0] }
        let nuevos = puestos.map { TrazoSala(id: empuje.nuevo(), de: yo, trazo: $0) }
        guard !nuevos.isEmpty || !fuera.isEmpty else { return [] }
        aplicar(puestos: nuevos, quitados: fuera)
        apilar(.trazos(puestos: nuevos, quitados: fuera))
        return nuevos.map(\.id)
    }

    private func aplicar(puestos: [TrazoSala], quitados: [TrazoSala]) {
        var hijos: [String: JSONVivo] = [:]
        for t in quitados {
            trazos[t.id] = nil
            hijos["trazos/\(t.id)"] = .nulo
        }
        for t in puestos {
            trazos[t.id] = t
            hijos["trazos/\(t.id)"] = ["de": .texto(t.de), "d": .texto(PKDrawing(strokes: [t.trazo]).dataRepresentation().base64EncodedString()),
                                       "t": JSONVivo.horaServidor]
        }
        versionTrazos += 1

        sala?.parchear("pizarra", hijos)
    }

    func deshacer() {
        guard let a = pilaDeshacer.popLast() else { return }
        revertir(a)
        pilaRehacer.append(invertida(a))
        refrescarPilas()
    }

    func rehacer() {
        guard let a = pilaRehacer.popLast() else { return }
        revertir(a)
        pilaDeshacer.append(invertida(a))
        refrescarPilas()
    }

    private func revertir(_ a: Accion) {
        switch a {
        case let .trazos(puestos, quitados):
            aplicar(puestos: quitados, quitados: puestos.filter { trazos[$0.id] != nil })
        case let .objeto(antes, despues):
            if let antes { guardarObjeto(antes) } else if let despues { quitarObjeto(despues.id, apilar: false) }
        }
    }

    private func invertida(_ a: Accion) -> Accion {
        switch a {
        case let .trazos(puestos, quitados): .trazos(puestos: quitados, quitados: puestos)
        case let .objeto(antes, despues): .objeto(antes: despues, despues: antes)
        }
    }

    private func apilar(_ a: Accion) {
        pilaDeshacer.append(a)
        if pilaDeshacer.count > 100 { pilaDeshacer.removeFirst() }
        pilaRehacer.removeAll()
        refrescarPilas()
    }

    private func refrescarPilas() {
        puedeDeshacer = !pilaDeshacer.isEmpty
        puedeRehacer = !pilaRehacer.isEmpty
    }

    func ponerFoto(_ imagen: UIImage, en centro: CGPoint, anchoVisible: CGFloat) async {
        let img = imagen.reducida(lado: 1600)
        guard let datos = img.jpegData(compressionQuality: 0.72) else { return }
        let ancho = min(anchoVisible * 0.7, 520)
        let alto = ancho * img.size.height / max(img.size.width, 1)
        let id = empuje.nuevo()

        let archivo = await sala?.subirArchivo(datos) ?? "local-\(id)"
        imagenes[archivo] = img
        let o = ObjetoPizarra(id: id, de: yo, archivo: archivo, centro: centro, ancho: ancho, alto: alto, giro: 0,
                              orden: (objetos.values.map(\.orden).max() ?? 0) + 1)
        guardarObjeto(o)
        apilar(.objeto(antes: nil, despues: o))
    }

    func moverObjeto(_ o: ObjetoPizarra, guardar: Bool, antes: ObjetoPizarra? = nil) {
        objetos[o.id] = o
        if guardar {
            guardarObjeto(o)
            if let antes { apilar(.objeto(antes: antes, despues: o)) }
        }
    }

    func quitarObjeto(_ id: String, apilar conPila: Bool = true) {
        guard let o = objetos[id] else { return }
        objetos[id] = nil
        sala?.borrar("pizarra/objetos/\(id)")
        if conPila { apilar(.objeto(antes: o, despues: nil)) }
    }

    func traerDelante(_ id: String) {
        guard var o = objetos[id] else { return }
        let antes = o
        o.orden = (objetos.values.map(\.orden).max() ?? 0) + 1
        moverObjeto(o, guardar: true, antes: antes)
    }

    private func guardarObjeto(_ o: ObjetoPizarra) {
        objetos[o.id] = o
        sala?.escribir("pizarra/objetos/\(o.id)", [
            "de": .texto(o.de), "archivo": .texto(o.archivo), "x": .numero(Double(o.centro.x)), "y": .numero(Double(o.centro.y)),
            "an": .numero(Double(o.ancho)), "al": .numero(Double(o.alto)), "g": .numero(o.giro), "o": .numero(o.orden),
        ])
    }

    func cambiarPapel(_ p: PapelPizarra) {
        papel = p
        sala?.escribir("pizarra/papel", .texto(p.rawValue))
    }

    func dibujando(_ puntos: [CGPoint], color: UIColor, ancho: CGFloat, laser: Bool = false) {
        fantasmaPendiente = Fantasma(puntos: puntos, color: color, ancho: ancho, laser: laser)
        guard envioFantasma == nil else { return }
        let espera = max(0, 0.1 - Date().timeIntervalSince(ultimoFantasma))
        envioFantasma = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(espera * 1_000_000_000))
            guard let self, let f = self.fantasmaPendiente else { self?.envioFantasma = nil; return }
            self.envioFantasma = nil
            self.ultimoFantasma = Date()

            let p = f.puntos.suffix(120).map { "\(Int($0.x.rounded())),\(Int($0.y.rounded()))" }.joined(separator: ";")
            self.sala?.escribir("pizarra/fantasma/\(self.yo)", ["p": .texto(p), "c": .texto(f.color.hex), "a": .numero(Double(f.ancho)),
                                                                 "l": .bool(f.laser)])
        }
    }

    func dejarDeDibujar() {
        fantasmaPendiente = nil
        envioFantasma?.cancel()
        envioFantasma = nil
        sala?.borrar("pizarra/fantasma/\(yo)")
    }

    func parar() {
        envioFantasma?.cancel()
        envioFantasma = nil
    }

    func imagen(escala: CGFloat = 2, oscuro: Bool = false) -> UIImage? {
        let dibujo = PKDrawing(strokes: ordenados.map(\.trazo))
        var marco = dibujo.bounds
        for o in objetos.values { marco = marco.union(CGRect(x: o.centro.x - o.ancho / 2, y: o.centro.y - o.alto / 2, width: o.ancho, height: o.alto)) }
        guard !marco.isNull, !marco.isEmpty else { return nil }
        marco = marco.insetBy(dx: -32, dy: -32)
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = escala
        let estilo = UITraitCollection(userInterfaceStyle: oscuro ? .dark : .light)
        return UIGraphicsImageRenderer(size: marco.size, format: formato).image { ctx in
            (oscuro ? UIColor.black : UIColor.white).setFill()
            ctx.fill(CGRect(origin: .zero, size: marco.size))
            for o in objetosOrdenados {
                guard let img = imagenes[o.archivo] else { continue }
                ctx.cgContext.saveGState()
                ctx.cgContext.translateBy(x: o.centro.x - marco.minX, y: o.centro.y - marco.minY)
                ctx.cgContext.rotate(by: o.giro)
                img.draw(in: CGRect(x: -o.ancho / 2, y: -o.alto / 2, width: o.ancho, height: o.alto))
                ctx.cgContext.restoreGState()
            }
            var trazos: UIImage?
            estilo.performAsCurrent { trazos = dibujo.image(from: marco, scale: escala) }
            trazos?.draw(in: CGRect(origin: .zero, size: marco.size))
        }
    }

    func ponerEjemplo() {
        let azul = UIColor.systemBlue
        func trazo(_ puntos: [CGPoint], _ color: UIColor, _ ancho: CGFloat = 4) -> PKStroke {
            let pts = puntos.enumerated().map { i, p in
                PKStrokePoint(location: p, timeOffset: Double(i) * 0.02, size: CGSize(width: ancho, height: ancho), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
            }
            return PKStroke(ink: PKInk(.pen, color: color), path: PKStrokePath(controlPoints: pts, creationDate: Date()))
        }
        func linea(_ a: CGPoint, _ b: CGPoint) -> [CGPoint] { (0...24).map { i in CGPoint(x: a.x + (b.x - a.x) * Double(i) / 24, y: a.y + (b.y - a.y) * Double(i) / 24) } }
        let triangulo: [[CGPoint]] = [linea(CGPoint(x: 60, y: 520), CGPoint(x: 60, y: 330)), linea(CGPoint(x: 60, y: 520), CGPoint(x: 300, y: 520)),
                                     linea(CGPoint(x: 60, y: 330), CGPoint(x: 300, y: 520)), linea(CGPoint(x: 60, y: 494), CGPoint(x: 86, y: 494)),
                                     linea(CGPoint(x: 86, y: 494), CGPoint(x: 86, y: 520))]
        var n = 0
        for t in triangulo {
            n += 1
            let id = "ejemplo-\(String(format: "%03d", n))"
            trazos[id] = TrazoSala(id: id, de: yo, trazo: trazo(t, azul))
        }
        versionTrazos += 1
        papel = .cuadricula
        fantasma = Fantasma(puntos: (0...30).map { i in
            let a = Double(i) / 30 * .pi * 1.4
            return CGPoint(x: 320 + 34 * cos(a), y: 600 + 26 * sin(a))
        }, color: .systemOrange, ancho: 5, laser: false)
        let libro = UIImage.paginaDeLibro
        imagenes["ejemplo-libro"] = libro
        objetos["ejemplo-foto"] = ObjetoPizarra(id: "ejemplo-foto", de: "ana", archivo: "ejemplo-libro", centro: CGPoint(x: 290, y: 190),
                                                ancho: 190, alto: 190 * libro.size.height / libro.size.width, giro: -0.05, orden: 1)
    }
}

extension UIColor {

    var hex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(max(0, min(1, r)) * 255), Int(max(0, min(1, g)) * 255), Int(max(0, min(1, b)) * 255))
    }

    convenience init?(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}

extension UIImage {

    func reducida(lado: CGFloat) -> UIImage {
        let mayor = max(size.width, size.height) * scale
        guard mayor > lado else { return self }
        let f = lado / mayor
        let nuevo = CGSize(width: size.width * scale * f, height: size.height * scale * f)
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        return UIGraphicsImageRenderer(size: nuevo, format: formato).image { _ in draw(in: CGRect(origin: .zero, size: nuevo)) }
    }

    static var paginaDeLibro: UIImage {
        let tam = CGSize(width: 380, height: 300)
        return UIGraphicsImageRenderer(size: tam).image { ctx in
            UIColor(white: 0.985, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: tam))
            let titulo = NSAttributedString(string: L("Ejercicio 3", "Exercise 3", "Esercizio 3"),
                                            attributes: [.font: UIFont.systemFont(ofSize: 24, weight: .bold), .foregroundColor: UIColor(white: 0.22, alpha: 1)])
            titulo.draw(at: CGPoint(x: 22, y: 18))
            UIColor(white: 0.78, alpha: 1).setFill()
            for (i, w) in [0.9, 0.84, 0.92, 0.66].enumerated() {
                ctx.fill(CGRect(x: 22, y: 64 + i * 20, width: Int(Double(tam.width - 44) * w), height: 9))
            }
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 40, y: 270)); p.addLine(to: CGPoint(x: 40, y: 160)); p.addLine(to: CGPoint(x: 200, y: 270)); p.close()
            UIColor(white: 0.35, alpha: 1).setStroke()
            p.lineWidth = 3
            p.stroke()
            for (t, x, y) in [("6", 18.0, 210.0), ("8", 112.0, 274.0), ("?", 128.0, 196.0)] {
                NSAttributedString(string: t, attributes: [.font: UIFont.systemFont(ofSize: 20, weight: .semibold), .foregroundColor: UIColor(white: 0.3, alpha: 1)])
                    .draw(at: CGPoint(x: x, y: y))
            }
        }
    }
}
