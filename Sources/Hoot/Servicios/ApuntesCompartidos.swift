import Foundation

@Observable
final class ApuntesCompartidos: ParteDeSala {
    let nombre = "apuntes"
    weak var sala: SalaEnVivo?
    let yo: String

    let autor: String

    private(set) var editor: EditorApuntes

    private(set) var versionFuera = 0

    private(set) var cursorAmigo: (antes: IDLetra?, hasta: IDLetra?)?

    @ObservationIgnored private var cargado = false
    @ObservationIgnored private var enviando: String?
    @ObservationIgnored private var envioPendiente: Task<Void, Never>?
    @ObservationIgnored private var cursorPendiente: Task<Void, Never>?
    @ObservationIgnored private var ultimoCursor = ""

    init(yo: String) {
        self.yo = yo
        autor = String(yo.prefix(8))
        editor = EditorApuntes(yo: String(yo.prefix(8)))
    }

    var texto: String { editor.actual.texto }
    var visibles: [Letra] { editor.actual.visibles }

    func actualizar(_ valor: JSONVivo, cambio: [String]) {
        let parte = cambio.first
        if !cargado || parte == nil {
            cargado = true
            let estado = valor["estado"]
            let rev = Int(estado["rev"].numero ?? 0)
            if rev > editor.revision, let foto = estado["foto"].texto {
                editor.empezar(desde: CodigoApuntes.desdeFoto(foto), revision: rev)
                versionFuera += 1
            }
        }
        if parte == nil || parte == "ops" { leerOps(valor["ops"]) }
        if parte == nil || parte == "cursores" { leerCursor(valor["cursores"]) }
    }

    private func leerOps(_ j: JSONVivo) {
        let ops = j.objeto
        var hubo = false
        while let op = ops[String(format: "%09d", editor.revision + 1)] {
            let lote = op["l"].texto ?? ""
            editor.recibir(rev: editor.revision + 1, idLote: lote, ops: CodigoApuntes.decodificar(op["o"].texto ?? ""))
            if lote == enviando { enviando = nil }
            hubo = true
        }
        guard hubo else { return }
        versionFuera += 1
        guardarFotoSiToca(ops)
        mandarSiToca()
    }

    private func leerCursor(_ j: JSONVivo) {
        guard let otro = j.objeto.first(where: { $0.key != yo })?.value else { cursorAmigo = nil; return }
        func id(_ s: String?) -> IDLetra? {
            guard let s, let dos = s.lastIndex(of: ":"), let n = Int(s[s.index(after: dos)...]) else { return nil }
            return IDLetra(a: String(s[..<dos]), n: n)
        }
        let antes = id(otro["p"].texto), hasta = id(otro["f"].texto)
        cursorAmigo = (antes, hasta)
    }

    func editar(_ rango: Range<Int>, por texto: String, estilo: EstiloLetra) {
        editor.editar(rango, por: texto, estilo: estilo)
        programarEnvio()
    }

    func cambiar(_ rango: Range<Int>, _ cambio: CambioEstilo) {
        editor.cambiar(rango, cambio)
        programarEnvio()
    }

    private func programarEnvio() {
        envioPendiente?.cancel()
        envioPendiente = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard let self, !Task.isCancelled else { return }
            self.editor.cerrarLote()
            self.mandarSiToca()
        }
    }

    private func mandarSiToca() {
        guard enviando == nil, let (rev, lote) = editor.paraMandar, let sala else { return }
        if ModoCapturas.activo || sala.esLocal {
            editor.recibir(rev: rev, idLote: lote.id, ops: lote.ops)
            versionFuera += 1
            return
        }
        enviando = lote.id
        let ruta = "apuntes/ops/\(String(format: "%09d", rev))"
        let valor: JSONVivo = ["de": .texto(yo), "l": .texto(lote.id), "o": .texto(CodigoApuntes.codificar(lote.ops))]
        Task { [weak self] in
            do {
                try await sala.escribirYEsperar(ruta, valor)

                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if self?.enviando == lote.id { self?.enviando = nil; self?.mandarSiToca() }
            } catch {

                if self?.enviando == lote.id { self?.enviando = nil }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                self?.mandarSiToca()
            }
        }
    }

    private func guardarFotoSiToca(_ ops: [String: JSONVivo]) {
        guard sala?.soyAnfitrion == true, editor.revision % 200 == 0, editor.revision > 0, !editor.hayPendientes else { return }
        let rev = editor.revision
        sala?.escribir("apuntes/estado", ["rev": .numero(Double(rev)), "foto": .texto(CodigoApuntes.foto(editor.confirmado))])
        var fuera: [String: JSONVivo] = [:]
        for k in ops.keys where (Int(k) ?? .max) <= rev { fuera["ops/\(k)"] = .nulo }
        if !fuera.isEmpty { sala?.parchear("apuntes", fuera) }
    }

    func moverCursor(desde: Int, hasta: Int) {
        let vis = visibles
        func id(_ i: Int) -> String { i > 0 && i <= vis.count ? "\(vis[i - 1].id.a):\(vis[i - 1].id.n)" : "" }
        let p = id(desde), f = hasta > desde ? id(hasta) : ""
        let clave = p + "|" + f
        guard clave != ultimoCursor else { return }
        ultimoCursor = clave
        cursorPendiente?.cancel()
        cursorPendiente = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard let self, !Task.isCancelled else { return }
            self.sala?.escribir("apuntes/cursores/\(self.yo)", ["p": .texto(p), "f": .texto(f)])
        }
    }

    func posicion(trasDe id: IDLetra?) -> Int? {
        guard let id else { return 0 }
        var visiblesAntes = 0
        for l in editor.actual.letras {
            if !l.borrada { visiblesAntes += 1 }
            if l.id == id { return visiblesAntes }
        }
        return nil
    }

    func parar() {
        envioPendiente?.cancel()
        cursorPendiente?.cancel()
        if editor.hayPendientes { editor.cerrarLote(); mandarSiToca() }
    }

    func ponerEjemplo() {
        let ana = "ana"
        var e = EditorApuntes(yo: ana)
        var titulo = EstiloLetra(); titulo.parrafo = .titulo
        var encabezado = EstiloLetra(); encabezado.parrafo = .encabezado
        var vineta = EstiloLetra(); vineta.lista = .vineta
        var hecha = EstiloLetra(); hecha.lista = .hecha
        var casilla = EstiloLetra(); casilla.lista = .casilla
        let trozos: [(String, EstiloLetra)] = [
            ("Pitágoras\n", titulo),
            (L("Lo que hay que saber\n", "What you need to know\n", "Cosa bisogna sapere\n"), encabezado),
            (L("En un triángulo rectángulo: a² + b² = c²\n", "In a right triangle: a² + b² = c²\n", "In un triangolo rettangolo: a² + b² = c²\n"), vineta),
            (L("La hipotenusa es el lado más largo\n", "The hypotenuse is the longest side\n", "L'ipotenusa è il lato più lungo\n"), vineta),
            (L("Deberes\n", "Homework\n", "Compiti\n"), encabezado),
            (L("Ejercicio 1\n", "Exercise 1\n", "Esercizio 1\n"), hecha),
            (L("Ejercicio 3", "Exercise 3", "Esercizio 3"), casilla),
        ]
        for (t, est) in trozos { e.editar(e.actual.visibles.count..<e.actual.visibles.count, por: t, estilo: est) }
        e.cerrarLote()
        if let (rev, lote) = e.paraMandar { e.recibir(rev: rev, idLote: lote.id, ops: lote.ops) }
        editor.empezar(desde: e.confirmado, revision: e.revision)
        let vis = editor.actual.visibles
        if let i = vis.firstIndex(where: { $0.c == "m" && $0.estilo.lista == .vineta }) {
            cursorAmigo = (vis[max(0, i - 1)].id, nil)
        }
        versionFuera += 1
    }
}
