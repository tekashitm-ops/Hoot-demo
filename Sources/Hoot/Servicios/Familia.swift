import Foundation

@MainActor
@Observable
final class FamiliaNube {
    static let compartida = FamiliaNube()

    enum Estado: Equatable {
        case sinCuenta, alDia(Date), sinRed, fallo(String)
    }

    enum ResultadoVinculo: Equatable {
        case pedido(String), noExiste, sinCuenta, fallo(String)
    }

    private(set) var estado: Estado = .sinCuenta
    @ObservationIgnored private var trabajando = false
    @ObservationIgnored private let clavePublicado = "hoot.familia.codigoPublicado"

    var disponible: Bool { ConfigNube.lista && !ModoCapturas.activo }

    func conCuenta() async -> Bool {
        guard disponible, let s = await Nube.compartida.sesionActual else { return false }
        return s.verificada
    }

    func sincronizar(_ almacen: Almacen) async {
        guard !trabajando else { return }
        guard await conCuenta() else {
            estado = .sinCuenta
            return
        }
        trabajando = true
        defer { trabajando = false }
        do {
            if almacen.esFamilia { try await bajarHijos(almacen) } else { try await alDiaEstudiante(almacen) }
            estado = .alDia(Date())
        } catch FalloNube.sinRed {
            estado = .sinRed
        } catch {
            estado = .fallo(Sincronizacion.texto(error))
        }
    }

    private func alDiaEstudiante(_ almacen: Almacen) async throws {
        let codigo = almacen.codigoVinculo
        if UserDefaults.standard.string(forKey: clavePublicado) != codigo {
            try await Nube.compartida.publicarVinculo(codigo: codigo, nombre: almacen.perfil.nombre)
            UserDefaults.standard.set(codigo, forKey: clavePublicado)
        }
        let lista = try await Nube.compartida.familiares()
        let deVerdad = lista.map { f in
            Vinculo(id: almacen.vinculos.first { $0.uid == f.uid }?.id ?? UUID(), nombre: f.nombre, fecha: f.creado, uid: f.uid,
                    aceptado: f.aceptado)
        }.sorted { $0.fecha < $1.fecha }
        let nuevos = almacen.vinculos.filter { $0.uid.isEmpty } + deVerdad
        if nuevos != almacen.vinculos { almacen.vinculos = nuevos }
        for cosa in try await Nube.compartida.buzon() {
            recoger(tipo: cosa.tipo, json: cosa.json, en: almacen)
            try await Nube.compartida.borrarDelBuzon(cosa.id)
        }
    }

    private func recoger(tipo: String, json: String, en almacen: Almacen) {
        let datos = Data(json.utf8)
        switch tipo {
        case "prueba":
            guard var p = try? JSONDecoder().decode(Prueba.self, from: datos), !almacen.datos.pruebas.contains(where: { $0.id == p.id }) else { return }
            p.deFamilia = true
            almacen.datos.pruebas.append(p)
        case "recordatorio":
            guard var r = try? JSONDecoder().decode(Recordatorio.self, from: datos),
                  !almacen.datos.recordatorios.contains(where: { $0.id == r.id }) else { return }
            r.origen = .familia
            almacen.datos.recordatorios.append(r)
        case "permisoSalas":

            almacen.ajustes.permisoSalas = true
            almacen.ajustes.permisoSalasFecha = Reloj.ahora
            almacen.ajustes.permisoSalasPedido = nil
        case "permisoSalasNo":
            almacen.ajustes.permisoSalasPedido = nil
        default: break
        }
    }

    func aceptar(_ v: Vinculo, almacen: Almacen) async {
        do {
            try await Nube.compartida.aceptar(v.uid)
            if let i = almacen.vinculos.firstIndex(where: { $0.id == v.id }) { almacen.vinculos[i].aceptado = true }
        } catch {
            estado = .fallo(Sincronizacion.texto(error))
        }
    }

    func quitar(_ v: Vinculo, almacen: Almacen) async {
        if !v.uid.isEmpty {
            do { try await Nube.compartida.quitarFamiliar(v.uid) } catch {
                estado = .fallo(Sincronizacion.texto(error))
                return
            }
        }
        almacen.vinculos.removeAll { $0.id == v.id }
    }

    func renovarCodigo(_ almacen: Almacen) async {
        let viejo = almacen.codigoVinculo
        almacen.codigoVinculo = Almacen.nuevoCodigo()
        let quitar = almacen.vinculos
        almacen.vinculos.removeAll()
        guard await conCuenta() else { return }
        try? await Nube.compartida.borrarVinculo(codigo: viejo)
        for v in quitar where !v.uid.isEmpty { try? await Nube.compartida.quitarFamiliar(v.uid) }
        UserDefaults.standard.removeObject(forKey: clavePublicado)
        await sincronizar(almacen)
    }

    func vincular(codigo: String, almacen: Almacen) async -> ResultadoVinculo {
        guard await conCuenta() else { return .sinCuenta }
        do {
            guard let v = try await Nube.compartida.buscarVinculo(codigo: codigo) else { return .noExiste }
            do {
                try await Nube.compartida.pedirSeguir(uidHijo: v.uid, nombre: almacen.perfil.nombre)
            } catch FalloNube.conflicto {

            }
            if let i = almacen.hijos.firstIndex(where: { $0.uid == v.uid }) {
                almacen.hijoActivoID = almacen.hijos[i].id
            } else {
                let hijo = Hijo(nombre: v.nombre.isEmpty ? L("Tu hijo", "Your child", "Tuo figlio") : v.nombre, uid: v.uid, esperando: true)
                almacen.hijos.append(hijo)
                almacen.hijoActivoID = hijo.id
            }
            await sincronizar(almacen)
            return .pedido(v.nombre)
        } catch {
            return .fallo(Sincronizacion.texto(error))
        }
    }

    func dejarDeSeguir(_ hijo: Hijo, almacen: Almacen) async {
        if !hijo.uid.isEmpty, await conCuenta() { try? await Nube.compartida.dejarDeSeguir(uidHijo: hijo.uid) }
        almacen.hijos.removeAll { $0.id == hijo.id }
        if almacen.hijoActivoID == hijo.id { almacen.hijoActivoID = almacen.hijos.first?.id }
    }

    func mandar<T: Encodable & Identifiable>(_ cosa: T, tipo: String, almacen: Almacen) async where T.ID == UUID {
        guard let id = almacen.hijoActivo?.id, let i = almacen.hijos.firstIndex(where: { $0.id == id }), !almacen.hijos[i].uid.isEmpty,
              let datos = try? JSONEncoder().encode(cosa), let json = String(data: datos, encoding: .utf8) else { return }
        almacen.hijos[i].pendientes.removeAll { $0.id == cosa.id }
        almacen.hijos[i].pendientes.append(EnvioFamilia(id: cosa.id, tipo: tipo, json: json))
        await mandarPendientes(almacen)
    }

    private func mandarPendientes(_ almacen: Almacen) async {
        guard await conCuenta() else { return }
        for hijo in almacen.hijos where !hijo.uid.isEmpty {
            for envio in hijo.pendientes where !envio.mandado {
                do {
                    try await Nube.compartida.mandarAlBuzon(uidHijo: hijo.uid, tipo: envio.tipo, json: envio.json, de: almacen.perfil.nombre)
                    if let i = almacen.hijos.firstIndex(where: { $0.id == hijo.id }),
                       let j = almacen.hijos[i].pendientes.firstIndex(where: { $0.id == envio.id }) {
                        almacen.hijos[i].pendientes[j].mandado = true
                    }
                } catch {
                    estado = .fallo(Sincronizacion.texto(error))
                }
            }
        }
    }

    private func bajarHijos(_ almacen: Almacen) async throws {
        await mandarPendientes(almacen)
        for hijo in almacen.hijos where !hijo.uid.isEmpty {
            do {
                let guardado = try await Nube.compartida.bajarHijo(hijo.uid)
                guard let i = almacen.hijos.firstIndex(where: { $0.id == hijo.id }) else { continue }
                guard let g = guardado, let e = try? CompatibilidadDatos.decodificar(g.estado) else {

                    almacen.hijos[i].esperando = false
                    continue
                }
                var datos = e.datos

                datos.pruebas.removeAll(where: \.privada)
                datos.recordatorios.removeAll(where: \.privada)
                var h = almacen.hijos[i]
                let nombre = e.perfil.nombre.isEmpty ? h.nombre : e.perfil.nombre
                let nuevos = h.actualizado == nil ? [] : Self.avisos(antes: h.datos, despues: datos, nombre: nombre)
                h.pendientes.removeAll { p in datos.pruebas.contains { $0.id == p.id } || datos.recordatorios.contains { $0.id == p.id } }
                for p in h.pendientes { Self.anadir(p, a: &datos) }
                h.datos = datos
                h.nombre = nombre
                h.pideSalas = e.ajustes.permisoSalasPedido != nil && !e.ajustes.permisoSalas
                if !e.perfil.curso.isEmpty { h.curso = e.perfil.curso }
                h.avisos = Array((nuevos + h.avisos).prefix(60))
                h.esperando = false
                h.actualizado = Date()
                if h != almacen.hijos[i] { almacen.hijos[i] = h }
                await Avisos.contarYa(nuevos, de: nombre, almacen: almacen)
            } catch FalloNube.sinVerificar {

                if let i = almacen.hijos.firstIndex(where: { $0.id == hijo.id }), !almacen.hijos[i].esperando { almacen.hijos[i].esperando = true }
            }
        }
    }

    private static func anadir(_ envio: EnvioFamilia, a datos: inout DatosEscolares) {
        let d = Data(envio.json.utf8)
        if envio.tipo == "prueba", var p = try? JSONDecoder().decode(Prueba.self, from: d) {
            p.deFamilia = true
            datos.pruebas.append(p)
        } else if envio.tipo == "recordatorio", var r = try? JSONDecoder().decode(Recordatorio.self, from: d) {
            r.origen = .familia
            datos.recordatorios.append(r)
        }
    }

    static func avisos(antes: DatosEscolares, despues: DatosEscolares, nombre: String, ahora: Date = Reloj.ahora) -> [Aviso] {
        let cal = calendarioActual
        var r: [Aviso] = []
        let temasAntes = Dictionary(antes.pruebas.flatMap(\.temas).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for p in despues.pruebas {
            for t in p.temas where t.luna(cal: cal) == .llena && temasAntes[t.id].map({ $0.luna(cal: cal) != .llena }) ?? true {
                r.append(Aviso(tipo: .luna, fecha: ahora, texto: L("\(nombre) ha llenado la luna de \(t.nombre)", "\(nombre) filled the moon for \(t.nombre)",
                                                                   "\(nombre) ha riempito la luna di \(t.nombre)")))
            }
            if !p.deFamilia, !antes.pruebas.contains(where: { $0.id == p.id }) {
                let asig = despues.asignatura(p.asignaturaID)?.nombre ?? p.tipo.nombre
                r.append(Aviso(tipo: .prueba, fecha: ahora, texto: L("\(nombre) ha apuntado \(asig) · \(Formato.diaRelativo(p.fecha, desde: ahora))",
                                                                     "\(nombre) added \(asig) · \(Formato.diaRelativo(p.fecha, desde: ahora))",
                                                                     "\(nombre) ha segnato \(asig) · \(Formato.diaRelativo(p.fecha, desde: ahora))")))
            }
        }
        for rec in despues.recordatorios where rec.origen != .familia && !antes.recordatorios.contains(where: { $0.id == rec.id }) {
            r.append(Aviso(tipo: .recordatorio, fecha: ahora, texto: L("\(nombre) ha apuntado: \(rec.titulo)", "\(nombre) noted: \(rec.titulo)",
                                                                       "\(nombre) ha segnato: \(rec.titulo)")))
        }
        if let dia = despues.diaMochila(ahora: ahora) {
            let items = despues.itemsMochila(para: dia)
            let lista = !items.isEmpty && items.allSatisfy { despues.marcadas(dia).contains($0.id) }
            let antesLista = !items.isEmpty && items.allSatisfy { antes.marcadas(dia).contains($0.id) }
            if lista && !antesLista {
                r.append(Aviso(tipo: .mochila, fecha: ahora, texto: L("\(nombre) ha preparado la mochila", "\(nombre) packed the backpack",
                                                                      "\(nombre) ha preparato lo zaino")))
            }
        }
        return r
    }
}
