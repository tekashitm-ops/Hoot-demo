import Foundation
import FoundationModels

enum TareaIA: String, Codable, CaseIterable, Identifiable {
    case charla, voz, revisar, resumen, esquema, preguntas, corregir, simulacro, escuchalo, reto, diario, apuntes

    var id: String { rawValue }

    var grupo: GrupoUso {
        switch self {
        case .charla: .charla
        case .voz: .voz
        case .revisar: .revisar
        case .resumen, .esquema, .apuntes: .temas
        case .preguntas, .corregir, .simulacro: .examenes
        case .escuchalo, .reto, .diario: .otros
        }
    }

    var puedeSubir: Bool { [.charla, .voz, .revisar, .corregir].contains(self) }

    var sencilla: Bool { [.escuchalo, .reto, .diario, .apuntes].contains(self) }

    var esfuerzo: ClaudeIA.Esfuerzo {
        switch self {
        case .voz, .reto, .diario, .apuntes, .escuchalo: .low
        case .resumen, .esquema, .preguntas, .simulacro: .medium

        case .charla, .revisar, .corregir: .high
        }
    }
}

enum GrupoUso: String, CaseIterable, Identifiable {
    case charla, voz, revisar, temas, examenes, otros

    var id: String { rawValue }

    var nombre: String {
        switch self {
        case .charla: L("Pregúntale a Hoot", "Ask Hoot", "Chiedi a Hoot")
        case .voz: L("Hablar con Hoot", "Talk to Hoot", "Parla con Hoot")
        case .revisar: L("Revisar deberes", "Check homework", "Controlla i compiti")
        case .temas: L("Resúmenes y esquemas", "Summaries & outlines", "Riassunti e schemi")
        case .examenes: L("Exámenes y simulacros", "Quizzes & mock tests", "Verifiche e simulazioni")
        case .otros: L("Escúchalo y retos", "Listen & challenges", "Ascolta e sfide")
        }
    }

    var simbolo: String {
        switch self {
        case .charla: "bubble.left.and.text.bubble.right.fill"
        case .voz: "waveform"
        case .revisar: "checkmark.seal.fill"
        case .temas: "point.3.connected.trianglepath.dotted"
        case .examenes: "questionmark.bubble.fill"
        case .otros: "headphones"
        }
    }

    var color: ColorHoot {
        switch self {
        case .charla: .amarillo
        case .voz: .naranja
        case .revisar: .verde
        case .temas: .azul
        case .examenes: .morado
        case .otros: .turquesa
        }
    }
}

enum MotorIA {

    enum Quien { case apple, claude }

    static func quien(_ tarea: TareaIA) -> Quien {
        guard ClaudeIA.activa else { return .apple }
        let ia = ClaudeIA.compartida
        let hayApple = DisponibilidadIA.apple == .lista
        if ia.llegoAlTope { return hayApple ? .apple : .claude }
        if tarea.sencilla && ia.ahorro >= 2 && hayApple { return .apple }
        return .claude
    }

    static func puedeSubir(_ tarea: TareaIA, conFotos: Bool) -> Bool {
        tarea.puedeSubir && (ClaudeIA.compartida.ahorro == 0 || conFotos)
    }

    static func esfuerzo(_ tarea: TareaIA) -> ClaudeIA.Esfuerzo {
        ClaudeIA.compartida.ahorro >= 2 && tarea.esfuerzo == .high ? .medium : tarea.esfuerzo
    }

    static func texto(_ tarea: TareaIA, instrucciones: String, prompt: String, fotos: [Data] = [], maximo: Int,
                      temperatura: Double = 0.4, permisivo: Bool = true,
                      alEscribir: ((String) -> Void)? = nil) async throws -> String {
        switch quien(tarea) {
        case .claude:
            let ia = ClaudeIA.compartida
            let (t, _) = try await ia.responderBien(tarea: tarea, sistema: instrucciones + "\n\n" + Pedagogia.reglas(tarea),
                                                    mensajes: [ClaudeIA.Mensaje(deHoot: false, texto: prompt, fotos: fotos)],
                                                    maximo: max(maximo * 3, 3000), esfuerzo: esfuerzo(tarea),
                                                    puedeSubir: puedeSubir(tarea, conFotos: !fotos.isEmpty)) { alEscribir?($0) }
            return t
        case .apple:
            try comprobarApple()
            let sesion = LanguageModelSession(model: permisivo ? SystemLanguageModel(guardrails: .permissiveContentTransformations) : .default,
                                              instructions: instrucciones)
            let opciones = GenerationOptions(temperature: temperatura, maximumResponseTokens: maximo)
            var final = ""
            if let alEscribir {
                for try await parcial in sesion.streamResponse(to: prompt, options: opciones) {
                    try Task.checkCancellation()
                    final = parcial.content
                    alEscribir(final)
                }
            } else {
                final = try await sesion.respond(to: prompt, options: opciones).content
            }
            ClaudeIA.compartida.apuntarApple(tarea)
            return final
        }
    }

    static func conForma(_ tarea: TareaIA, instrucciones: String, prompt: String, esquema: GenerationSchema, fotos: [Data] = [],
                         maximo: Int, temperatura: Double = 0.4) async throws -> GeneratedContent {
        switch quien(tarea) {
        case .claude:
            let ia = ClaudeIA.compartida
            let json = try await ia.responderJSON(modelo: .haiku, tarea: tarea,
                                                  sistema: instrucciones + "\n\n" + Pedagogia.reglas(tarea),
                                                  mensajes: [ClaudeIA.Mensaje(deHoot: false, texto: prompt, fotos: fotos)],
                                                  esquema: jsonSchema(esquema), maximo: max(maximo * 4, 4000), esfuerzo: esfuerzo(tarea))
            return try GeneratedContent(json: json)
        case .apple:
            try comprobarApple()
            let sesion = LanguageModelSession(model: SystemLanguageModel(guardrails: .permissiveContentTransformations), instructions: instrucciones)
            let r = try await sesion.respond(to: prompt, schema: esquema, options: GenerationOptions(temperature: temperatura, maximumResponseTokens: maximo))
            ClaudeIA.compartida.apuntarApple(tarea)
            return r.content
        }
    }

    private static func comprobarApple() throws {
        if DisponibilidadIA.apple != .lista {
            if ClaudeIA.activa && ClaudeIA.compartida.llegoAlTope { throw ClaudeIA.Fallo.tope }
            throw ErrorIA.noDisponible(DisponibilidadIA.apple)
        }
    }

    enum ErrorIA: Error {
        case noDisponible(DisponibilidadIA)
    }

    static func jsonSchema(_ esquema: GenerationSchema) -> Any {
        guard let datos = try? JSONEncoder().encode(esquema), let json = try? JSONSerialization.jsonObject(with: datos) else {
            return ["type": "object"]
        }
        return limpiar(json)
    }

    static func limpiar(_ v: Any) -> Any {
        if var d = v as? [String: Any] {
            for k in ["x-order", "minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum", "multipleOf", "minLength", "maxLength",
                      "maxItems", "pattern", "$schema"] {
                d.removeValue(forKey: k)
            }
            if let mi = d["minItems"] as? Int, mi > 1 { d["minItems"] = 1 }
            if d["type"] as? String == "object" {
                d["additionalProperties"] = false
                if let props = d["properties"] as? [String: Any] { d["required"] = Array(props.keys).sorted() }
            }
            for (k, x) in d where k != "required" && k != "enum" { d[k] = limpiar(x) }
            return d
        }
        if let a = v as? [Any] { return a.map(limpiar) }
        return v
    }

    @MainActor static func mensaje(_ error: Error, siNo: String? = nil) -> String {
        switch error {
        case let f as ClaudeIA.Fallo: return f.mensaje
        case let e as LanguageModelSession.GenerationError: return TrabajoIA.mensaje(e)
        case let ErrorIA.noDisponible(d): return d.mensaje
        default: return siNo ?? L("No se ha podido terminar. Inténtalo otra vez.", "Couldn't finish. Please try again.", "Non è stato possibile finire. Riprova.")
        }
    }
}
