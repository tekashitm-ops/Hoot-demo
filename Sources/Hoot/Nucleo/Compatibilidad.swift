import Foundation

enum CompatibilidadDatos {
    static func decodificar(_ data: Data) throws -> EstadoGuardado {
        do {
            return try JSONDecoder().decode(EstadoGuardado.self, from: data)
        } catch {
            guard let guardado = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let base = try JSONSerialization.jsonObject(with: JSONEncoder().encode(EstadoGuardado())) as? [String: Any]
            else { throw error }
            let completo = try JSONSerialization.data(withJSONObject: mezclar(base, guardado))
            return try JSONDecoder().decode(EstadoGuardado.self, from: completo)
        }
    }

    private static var plantillas: [String: [String: Any]] {
        let hoy = Reloj.ahora
        let id = UUID()
        func dic<T: Encodable>(_ v: T) -> [String: Any] {
            guard let d = try? JSONEncoder().encode(v),
                  let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
            return o
        }
        return [
            "asignaturas": dic(Asignatura(nombre: "", color: .gris, simbolo: "book.closed.fill")),
            "materiales": dic(Material(nombre: "")),
            "franjas": dic(Franja(inicio: 0, fin: 0)),
            "horario": dic(Clase(dia: 1, inicio: 0, fin: 0, asignaturaID: id)),
            "actividades": dic(Actividad(titulo: "", fecha: hoy)),
            "tareas": dic(Tarea(titulo: "", entrega: hoy)),
            "recordatorios": dic(Recordatorio(titulo: "", fecha: hoy)),
            "notas": dic(Nota(asignaturaID: id, valor: 0, titulo: "", fecha: hoy)),
            "estudios": dic(EstudioGuardado(tipo: .resumen, titulo: "", fecha: hoy, resultado: "", textoLeido: "")),
            "hijos": dic(Hijo(nombre: "")),
            "avisos": dic(Aviso(tipo: .tareaNueva, fecha: hoy, texto: "")),
            "vinculos": dic(Vinculo(nombre: "", fecha: hoy)),
            "pendientes": dic(EnvioFamilia(id: id, tipo: "", json: "")),
            "pruebas": dic(Prueba(fecha: hoy)),
            "temas": dic(Tema(nombre: "")),
            "intentos": dic(Intento(fecha: hoy)),
            "respuestas": dic(Respuesta(acierto: false)),
            "falladas": dic(PreguntaFallada(pregunta: "", esperada: "", fecha: hoy)),
            "fuentes": dic(FuenteTema(tipo: .texto, nombre: "", fecha: hoy)),
            "charla": dic(MensajeCharla(quien: .yo, texto: "", fecha: hoy)),
            "preguntas": dic(PreguntaAudio(pregunta: "", respuesta: "")),
            "pruebasAntiguas": dic(PruebaAntigua(texto: "", fecha: hoy)),
            "temasDeAhora": dic(TemaDeAhora(tema: Tema(nombre: ""))),
            "vacaciones": dic(Vacaciones(nombre: "", desde: hoy, hasta: hoy)),
        ]
    }

    private static func mezclar(_ base: [String: Any], _ encima: [String: Any]) -> [String: Any] {
        var r = base
        let moldes = plantillas
        for (clave, valor) in encima {
            if let objeto = valor as? [String: Any], let objetoBase = base[clave] as? [String: Any],
               !pareceEnum(objetoBase, objeto) {
                r[clave] = mezclar(objetoBase, objeto)
            } else if let lista = valor as? [Any], let molde = moldes[clave] {
                r[clave] = lista.map { e in (e as? [String: Any]).map { mezclar(molde, $0) } ?? e }
            } else {
                r[clave] = valor
            }
        }
        return r
    }

    private static func pareceEnum(_ a: [String: Any], _ b: [String: Any]) -> Bool {
        a.count == 1 && b.count == 1 && a.keys.first != b.keys.first
    }
}
