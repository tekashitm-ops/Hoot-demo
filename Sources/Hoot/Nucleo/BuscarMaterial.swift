import Foundation

nonisolated struct TrozoMaterial: Sendable, Equatable {
    var etiqueta: String
    var texto: String
}

nonisolated enum BuscarMaterial {

    static func trozos(_ texto: String, etiqueta general: String, tamano: Int = 700) -> [TrozoMaterial] {
        var resultado: [TrozoMaterial] = []
        var etiqueta = general
        var actual = ""
        func cerrar() {
            let t = actual.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { resultado.append(TrozoMaterial(etiqueta: etiqueta, texto: t)) }
            actual = ""
        }
        for linea in texto.components(separatedBy: "\n") {
            if let marca = marca(linea) {
                cerrar()
                etiqueta = marca
                continue
            }
            if actual.count + linea.count > tamano, !actual.isEmpty { cerrar() }
            if linea.count > tamano {

                for frase in linea.components(separatedBy: ". ") {
                    if actual.count + frase.count > tamano, !actual.isEmpty { cerrar() }
                    actual += frase + ". "
                }
            } else {
                actual += linea + "\n"
            }
        }
        cerrar()
        return resultado
    }

    static func marca(_ linea: String) -> String? {
        let l = linea.trimmingCharacters(in: .whitespaces)
        guard l.count <= 24 else { return nil }
        var cuerpo = l
        if l.hasPrefix("["), l.hasSuffix("]") { cuerpo = String(l.dropFirst().dropLast()) }
        let partes = cuerpo.split(separator: " ")
        guard partes.count == 2, Int(partes[1]) != nil else { return nil }
        let palabras: Set<String> = ["foto", "photo", "página", "pagina", "page", "diapositiva", "slide"]
        guard palabras.contains(partes[0].lowercased()) else { return nil }

        if !l.hasPrefix("["), !["diapositiva", "slide"].contains(partes[0].lowercased()) { return nil }
        return cuerpo
    }

    static func relevantes(_ pregunta: String, en trozos: [TrozoMaterial], maximo: Int = 2400) -> (trozos: [TrozoMaterial], encontrado: Bool) {
        guard !trozos.isEmpty else { return ([], false) }
        let consulta = Set(palabras(pregunta))
        let porTrozo = trozos.map { Set(palabras($0.texto)) }

        var df: [String: Int] = [:]
        for p in porTrozo { for w in p where consulta.contains(w) { df[w, default: 0] += 1 } }
        let n = Double(trozos.count)
        let puntos = porTrozo.map { p in consulta.intersection(p).reduce(0.0) { $0 + log(1 + n / Double(1 + (df[$1] ?? 0))) } }
        let orden = trozos.indices.sorted { puntos[$0] > puntos[$1] }
        let encontrado = (puntos[orden[0]]) >= 0.5
        var elegidos: [Int] = []
        var total = 0
        for i in (encontrado ? orden.filter { puntos[$0] > 0 } : Array(trozos.indices)) {
            let largo = trozos[i].texto.count
            if total + largo > maximo, !elegidos.isEmpty { break }
            elegidos.append(i)
            total += largo
        }
        return (elegidos.sorted().map { trozos[$0] }, encontrado)
    }

    static func palabras(_ s: String) -> [String] {
        let plano = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        return plano.split { !$0.isLetter && !$0.isNumber }.compactMap { trozo in
            let w = String(trozo)
            let numero = w.allSatisfy(\.isNumber)
            guard numero ? w.count >= 2 : w.count >= 4, !vacias.contains(w) else { return nil }
            return numero || w.count < 6 ? w : String(w.prefix(5))
        }
    }

    private static let vacias: Set<String> = [

        "para", "como", "pero", "sobre", "entre", "tiene", "tienen", "esta", "este", "esto", "estos", "estas", "porque",
        "donde", "cuando", "cual", "cuales", "quien", "quienes", "hace", "hacer", "fueron", "eran", "eres", "esos", "esas",
        "todo", "todos", "toda", "todas", "algo", "explica", "explicame", "dime", "pasa", "paso", "sirve", "significa",

        "what", "when", "where", "which", "does", "with", "that", "this", "from", "have", "were", "about", "explain", "tell",

        "cosa", "come", "perche", "quale", "quando", "dove", "sono", "della", "delle", "degli", "nella", "questo",
        "questa", "anche", "spiega", "spiegami", "dimmi",
    ]
}
