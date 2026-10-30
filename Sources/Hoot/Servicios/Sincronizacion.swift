import SwiftUI
import UIKit
import CryptoKit

@MainActor
@Observable
final class Sincronizacion {
    static let compartida = Sincronizacion()

    enum Estado: Equatable {
        case sinCuenta, sinConfirmar, guardando, alDia(Date), sinRed, fallo(String)
    }

    private(set) var sesion: SesionNube?
    private(set) var estado: Estado = .sinCuenta

    @ObservationIgnored private weak var almacen: Almacen?
    @ObservationIgnored private var tareaSubida: Task<Void, Never>?

    @ObservationIgnored private var pendiente = false

    @ObservationIgnored private var ultimoCambio = Date.distantPast

    @ObservationIgnored private(set) var aplicando = false

    @ObservationIgnored private var ultimaHuella = ""

    var activa: Bool { ConfigNube.lista && !ModoCapturas.activo }

    private(set) var deMuestra = false

    func conectar(_ almacen: Almacen) {
        self.almacen = almacen
        if ModoCapturas.activo, let m = ModoCapturas.valor("-nube") {
            deMuestra = true
            if m != "sincuenta" {
                sesion = SesionNube(uid: "muestra", correo: almacen.perfil.correo, idToken: "", refresco: "", caduca: .distantFuture,
                                    verificada: m != "sinconfirmar")
                estado = m == "sinconfirmar" ? .sinConfirmar : .alDia(Date().addingTimeInterval(-40))
            }
            return
        }
        guard activa else { return }
        Task {
            sesion = await Nube.compartida.sesionActual
            actualizarEstado()
            await alActivarse()
        }
    }

    private var claveVersion: String { "hoot.nube.\(sesion?.uid ?? "").version" }
    private var version: String? {
        get { UserDefaults.standard.string(forKey: claveVersion) }
        set { UserDefaults.standard.set(newValue, forKey: claveVersion) }
    }

    private var enlazada: Bool {
        get { UserDefaults.standard.bool(forKey: "hoot.nube.\(sesion?.uid ?? "").enlazada") }
        set { UserDefaults.standard.set(newValue, forKey: "hoot.nube.\(sesion?.uid ?? "").enlazada") }
    }

    private func actualizarEstado() {
        guard let sesion else { estado = .sinCuenta; return }
        if !sesion.verificada { estado = .sinConfirmar }
        else if case .alDia = estado {} else if !pendiente { estado = .alDia(Date()) }
    }

    func entro(_ s: SesionNube) {
        sesion = s
        actualizarEstado()
    }

    func cerrarSesion() async {
        await Nube.compartida.cerrarSesion()
        tareaSubida?.cancel()
        pendiente = false
        sesion = nil
        estado = .sinCuenta
    }

    func confirmado() async {
        sesion = await Nube.compartida.sesionActual
        actualizarEstado()
    }

    func cambioLocal() {
        guard activa, let sesion, sesion.verificada, enlazada, !aplicando, almacen?.configurado == true else { return }
        pendiente = true
        ultimoCambio = Date()
        tareaSubida?.cancel()
        tareaSubida = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await self?.subir()
        }
    }

    @discardableResult
    func subirYa() async -> Bool {
        tareaSubida?.cancel()
        guard pendiente else { return true }
        await subir()
        return !pendiente
    }

    func subirTodo() async {
        guard activa, sesion?.verificada == true else { return }
        pendiente = true
        ultimoCambio = Date()
        await subir(pisando: true)
        if !pendiente { enlazada = true }
    }

    func alTerminarConfiguracion() async {
        guard activa, sesion?.verificada == true, !enlazada else { return }
        await subirTodo()
    }

    private func subir(pisando: Bool = false) async {
        guard let almacen, let sesion, sesion.verificada else { return }
        let datos = almacen.datosParaNube()
        let foto = try? Data(contentsOf: Almacen.archivoAvatar)
        let huella = Self.huella(datos, foto)
        if !pisando && huella == ultimaHuella {
            pendiente = false
            actualizarEstado()
            return
        }
        estado = .guardando
        do {
            let nueva = try await Nube.compartida.subir(datos, foto: foto, modificado: ultimoCambio, aparato: UIDevice.current.name,
                                                         encimaDe: pisando ? nil : version)
            version = nueva
            ultimaHuella = huella
            pendiente = false
            estado = .alDia(Date())
        } catch FalloNube.conflicto {

            await resolverConflicto()
        } catch FalloNube.sinRed {
            estado = .sinRed
        } catch FalloNube.sinVerificar {
            estado = .sinConfirmar
        } catch {
            estado = .fallo(Self.texto(error))
        }
    }

    func alActivarse() async {
        guard activa, let sesion else { return }
        if !sesion.verificada {

            if (try? await Nube.compartida.comprobarConfirmacion()) == true { await confirmado() } else { return }
        }

        guard enlazada else { return }
        do {
            guard let remoto = try await Nube.compartida.bajar() else {

                if almacen?.configurado == true { await subirTodo() }
                return
            }
            guard remoto.version != version else { actualizarEstado(); return }
            if pendiente { await resolverConflicto(remoto) } else { aplicar(remoto) }
        } catch FalloNube.sinRed {
            estado = .sinRed
        } catch {
            estado = .fallo(Self.texto(error))
        }
    }

    func bajarParaEntrar() async throws -> GuardadoNube? {
        try await Nube.compartida.bajar()
    }

    private func resolverConflicto(_ conocido: GuardadoNube? = nil) async {
        var remoto = conocido
        if remoto == nil { remoto = try? await Nube.compartida.bajar() }
        guard let remoto else {
            await subir(pisando: true)
            return
        }
        if remoto.modificado > ultimoCambio {
            aplicar(remoto)
        } else {
            version = remoto.version
            await subir()
        }
    }

    func aplicar(_ remoto: GuardadoNube) {
        guard let almacen, let e = try? CompatibilidadDatos.decodificar(remoto.estado) else {
            estado = .fallo(L("No se pudo leer lo guardado en la cuenta", "Couldn't read what's saved in the account", "Impossibile leggere i dati dell'account"))
            return
        }
        aplicando = true
        almacen.ponerDeLaNube(e, foto: remoto.foto.flatMap(UIImage.init(data:)))
        aplicando = false
        version = remoto.version
        enlazada = true
        ultimaHuella = Self.huella(almacen.datosParaNube(), try? Data(contentsOf: Almacen.archivoAvatar))
        pendiente = false
        estado = .alDia(Date())
    }

    private static func huella(_ datos: Data, _ foto: Data?) -> String {
        var h = SHA256()
        h.update(data: datos)
        if let foto { h.update(data: foto) }
        return h.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func texto(_ error: Error) -> String {
        switch error as? FalloNube {
        case .correoEnUso: L("Ya hay una cuenta con este correo.", "There's already an account with this email.", "Esiste già un account con questa email.")
        case .credenciales: L("El correo o la contraseña no son correctos.", "The email or password is incorrect.", "L'email o la password non sono corrette.")
        case .contrasenaDebil: L("La contraseña es demasiado corta.", "The password is too short.", "La password è troppo corta.")
        case .correoNoValido: L("Ese correo no parece válido.", "That email doesn't look valid.", "Quell'email non sembra valida.")
        case .demasiadosIntentos: L("Demasiados intentos. Prueba dentro de un rato.", "Too many attempts. Try again later.", "Troppi tentativi. Riprova più tardi.")
        case .sinRed: L("Sin conexión. Inténtalo de nuevo.", "No connection. Try again.", "Nessuna connessione. Riprova.")
        case .sinSesion: L("Vuelve a iniciar sesión.", "Sign in again.", "Accedi di nuovo.")
        case .sinVerificar: L("Confirma tu correo para guardar en la cuenta.", "Confirm your email to save to your account.", "Conferma la tua email per salvare nell'account.")
        case .desactivada: L("Esta cuenta está desactivada.", "This account is disabled.", "Questo account è disattivato.")
        case .conflicto: L("Otro aparato ha guardado a la vez. Vuelve a intentarlo.", "Another device saved at the same time. Try again.", "Un altro dispositivo ha salvato nello stesso momento. Riprova.")
        case .otro(let m): L("No se pudo (\(m)).", "It didn't work (\(m)).", "Non è stato possibile (\(m)).")
        case nil: error.localizedDescription
        }
    }
}
