import SwiftUI

struct EntrarSala: View {
    var codigoInicial = ""

    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var salas = Salas.compartidas
    @State private var codigo = ""
    @State private var conCuenta: Bool?
    @State private var trabajando = false
    @State private var error: String?
    @State private var escaneando = false
    @State private var sinFamilia = false
    @FocusState private var enCodigo: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HootDice(frase: frase, gesto: .feliz, tamano: 96, paraguasSiLlueve: false)
                        .listRowBackground(Color.clear)
                }
                if conCuenta == false {
                    sinCuenta
                } else if Salas.faltaPermiso(almacen) {
                    permiso
                } else if conCuenta == true {
                    crear
                    entrar
                    invitaciones
                    recientes
                }
                if let error {
                    Section { Text(error).foregroundStyle(EstiloAviso(color: .avisoCielo)) }
                        .filaTenida()
                }
            }
            .tenidaDelCielo(hoja: true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle(L("Estudiar con un amigo", "Study with a Friend", "Studiare con un amico"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar() } } }
            .disabled(trabajando)
            .overlay { if trabajando { ProgressView().controlSize(.large) } }
        }
        .presentationDetents([.large])
        .presentationBackground { FondoHojaTenida() }
        .task {
            codigo = CodigoSala.limpio(codigoInicial)
            if ModoCapturas.activo { conCuenta = true; return }
            conCuenta = await Salas.conCuenta()
            await salas.mirarBuzon()
            if codigo.count == 6, conCuenta == true, !Salas.faltaPermiso(almacen) { entrarCon(codigo) }
        }
        .sheet(isPresented: $escaneando) {
            LectorQR { texto in
                escaneando = false
                let c = texto.hasPrefix("hoot://sala/") ? String(texto.dropFirst("hoot://sala/".count)) : texto
                codigo = CodigoSala.limpio(c)
                if codigo.count == 6 { entrarCon(codigo) }
            }
            .ignoresSafeArea()
        }
    }

    private var frase: String {
        if conCuenta == false { return L("Para estudiar con un amigo, primero tu cuenta. Prometo no pedir nada más.", "To study with a friend, first your account. I promise that's all.",
                                          "Per studiare con un amico, prima il tuo account. Prometto che è tutto.") }
        if Salas.faltaPermiso(almacen) { return L("Para entrar en salas y chatear, tu familia tiene que decir que sí. Normas de la casa.",
                                                  "To join rooms and chat, your family has to say yes. House rules.",
                                                  "Per entrare nelle stanze e chattare, la tua famiglia deve dire di sì. Regole di casa.") }
        return L("¿Con quién estudiamos hoy? Yo pongo la pizarra.", "Who are we studying with today? I'll bring the board.", "Con chi studiamo oggi? Io porto la lavagna.")
    }

    private var sinCuenta: some View {
        Section {
            Text(L("Las salas van con tu cuenta de Hoot, con el correo confirmado.", "Rooms use your Hoot account, with a confirmed email.",
                   "Le stanze usano il tuo account Hoot, con l'email confermata."))
                .foregroundStyle(EstiloSecundario())
            Button(L("Crear mi cuenta o entrar", "Create My Account or Sign In", "Crea il mio account o accedi")) {
                cerrar()
                almacen.mostrandoCuenta = true
            }
            .foregroundStyle(.white)
        }
        .filaTenida()
    }

    @ViewBuilder
    private var permiso: some View {
        let vinculada = almacen.vinculos.contains { $0.aceptado && !$0.uid.isEmpty }
        let pedido = almacen.ajustes.permisoSalasPedido != nil
        Section {
            if pedido && vinculada {
                Label(L("Se lo has pedido. Le sale en su Hoot.", "You've asked. It shows up in their Hoot.", "Gliel'hai chiesto. Lo vede nel suo Hoot."),
                      systemImage: "clock")
                    .foregroundStyle(.white)
                    .listRowBackground(Color.clear)
            } else {
                Button {
                    if vinculada {
                        conMuelle { almacen.ajustes.permisoSalasPedido = Reloj.ahora }
                    } else {
                        sinFamilia = true
                    }
                } label: {
                    Text(L("Pedir permiso", "Ask for Permission", "Chiedi il permesso")).frame(maxWidth: .infinity)
                }
                .botonAmbar()
                .controlSize(.large)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        } footer: {
            Text(vinculada
                 ? L("Le llegará a tu familia en su Hoot. Hasta que diga que sí, puedes retar a un amigo que esté a tu lado (con el radar).",
                     "It goes to your family's Hoot. Until they say yes, you can challenge a friend next to you (with the radar).",
                     "Arriva alla tua famiglia nel suo Hoot. Finché non dice di sì, puoi sfidare un amico accanto a te (con il radar).")
                 : L("Tu familia lo verá en su Hoot. Antes tiene que vincularse contigo: Cuenta › Control parental.",
                     "Your family will see it in their Hoot. First they need to link with you: Account › Parental Controls.",
                     "La tua famiglia lo vedrà nel suo Hoot. Prima deve collegarsi con te: Account › Controllo parentale."))
                .foregroundStyle(EstiloSecundario())
        }
        .alert(L("Primero, tu familia", "First, your family", "Prima, la tua famiglia"), isPresented: $sinFamilia) {
            Button(L("Abrir Control parental", "Open Parental Controls", "Apri Controllo parentale")) {
                cerrar()
                almacen.mostrandoCuenta = true
            }
            Button(L("Ahora no", "Not Now", "Non ora"), role: .cancel) {}
        } message: {
            Text(L("Para pedirle permiso, tu familia tiene que tener Hoot y vincularse contigo con tu código (Cuenta › Control parental).",
                   "To ask for permission, your family needs Hoot and to link with you using your code (Account › Parental Controls).",
                   "Per chiedere il permesso, la tua famiglia deve avere Hoot e collegarsi con te con il tuo codice (Account › Controllo parentale)."))
        }
    }

    private var crear: some View {
        Section {
            Button { crearSala() } label: {
                Label(L("Crear una sala", "Create a Room", "Crea una stanza"), systemImage: "plus").frame(maxWidth: .infinity)
            }
            .botonAmbar()
            .controlSize(.large)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } footer: {
            Text(L("Te sale un código para tu amigo. Solo entra quien tú dejes pasar.", "You get a code for your friend. Only those you let in can join.",
                   "Ti esce un codice per il tuo amico. Entra solo chi fai entrare tu."))
                .foregroundStyle(EstiloSecundario())
        }
    }

    private var entrar: some View {
        Section {
            HStack(spacing: 10) {
                TextField("", text: Binding(get: { Self.conGuion(codigo) }, set: { codigo = CodigoSala.limpio($0) }),
                          prompt: Indicacion.texto(L("Código de 6 letras", "6-character code", "Codice di 6 caratteri")))

                    .font(codigo.isEmpty ? .title3 : .title2.weight(.semibold).monospaced())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .focused($enCodigo)
                    .foregroundStyle(.white)
                    .submitLabel(.go)
                    .onSubmit { entrarCon(codigo) }
                    .accessibilityLabel(L("Código de la sala", "Room code", "Codice della stanza"))
                Button(L("Entrar", "Join", "Entra")) { entrarCon(codigo) }
                    .buttonStyle(.glass)
                    .disabled(codigo.count != 6)
            }
            if LectorQR.disponible {
                Button { escaneando = true } label: {
                    Label(L("Escanear su QR", "Scan Their QR", "Scansiona il suo QR"), systemImage: "qrcode.viewfinder")
                }
                .foregroundStyle(.white)
            }
        } header: {
            Text(L("Entrar con un código", "Join with a Code", "Entra con un codice")).foregroundStyle(EstiloSecundario())
        }
        .filaTenida()
    }

    @ViewBuilder
    private var invitaciones: some View {
        if !salas.invitaciones.isEmpty {
            Section {
                ForEach(salas.invitaciones) { inv in
                    HStack(spacing: 12) {
                        Text(String(inv.nombre.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color(ContenedorPizarra.colorAmigo), in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L("\(inv.nombre) te invita", "\(inv.nombre) invites you", "\(inv.nombre) ti invita")).foregroundStyle(.white)
                            Text(inv.fecha, style: .relative).font(.subheadline).foregroundStyle(EstiloSecundario())
                        }
                        Spacer()
                        Button(L("Entrar", "Join", "Entra")) {
                            salas.quitar(inv)
                            entrarCon(inv.codigo)
                        }
                        .buttonStyle(.glass)
                    }
                    .swipeActions { Button(L("Quitar", "Remove", "Rimuovi"), role: .destructive) { salas.quitar(inv) } }
                }
            } header: {
                Text(L("Te han invitado", "You're Invited", "Sei stato invitato")).foregroundStyle(EstiloSecundario())
            }
            .filaTenida()
        }
    }

    @ViewBuilder
    private var recientes: some View {
        let lista = SalasGuardadas.recientes.filter { !$0.amigo.isEmpty || $0.soyAnfitrion }
        if !lista.isEmpty {
            Section {
                ForEach(lista.prefix(5)) { r in
                    Button { volver(r) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.on.rectangle.angled")
                                .font(.body.weight(.semibold))
                                .frame(width: 36, height: 36)
                                .foregroundStyle(.white)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(r.amigo.isEmpty ? L("Tu sala", "Your room", "La tua stanza") : L("Con \(r.amigo)", "With \(r.amigo)", "Con \(r.amigo)"))
                                    .foregroundStyle(.white)
                                Text(Formato.diaRelativo(r.ultimaVez)).font(.subheadline).foregroundStyle(EstiloSecundario())
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(EstiloSecundario())
                        }
                    }
                }
            } header: {
                Text(L("Salas recientes", "Recent Rooms", "Stanze recenti")).foregroundStyle(EstiloSecundario())
            }
            .filaTenida()
        }
    }

    static func conGuion(_ c: String) -> String {
        c.count > 3 ? "\(c.prefix(3))–\(c.dropFirst(3))" : c
    }

    private func crearSala() {
        trabajar { try await Salas.crear(almacen: almacen) }
    }

    private func entrarCon(_ c: String) {
        let limpio = CodigoSala.limpio(c)
        guard limpio.count == 6 else { return }
        trabajar { try await Salas.pedirEntrar(codigo: limpio, almacen: almacen) }
    }

    private func volver(_ r: SalaReciente) {
        trabajar { try await Salas.volver(a: r, almacen: almacen) }
    }

    private func trabajar(_ hacer: @escaping () async throws -> SalaEnVivo) {
        error = nil
        trabajando = true
        Task {
            do {
                let s = try await hacer()
                trabajando = false
                cerrar()
                salas.abierta = s
            } catch let f as Salas.FalloSala {
                trabajando = false
                error = switch f {
                case .noExiste: L("Ese código no existe. Mira que esté bien escrito.", "That code doesn't exist. Check it's written correctly.",
                                  "Quel codice non esiste. Controlla che sia scritto bene.")
                case .caducado: L("Ese código ha caducado. Pídele uno nuevo.", "That code has expired. Ask for a new one.", "Quel codice è scaduto. Chiedine uno nuovo.")
                case .sinRed: L("Sin conexión. Prueba otra vez.", "No connection. Try again.", "Nessuna connessione. Riprova.")
                case .sinCuenta: L("Hace falta tu cuenta con el correo confirmado.", "You need your account with a confirmed email.",
                                   "Serve il tuo account con l'email confermata.")
                case .llena: L("Esa sala ya está completa (es para dos).", "That room is full (it's for two).", "Quella stanza è già piena (è per due).")
                case .otro: L("No se ha podido. Prueba otra vez.", "That didn't work. Try again.", "Non è stato possibile. Riprova.")
                }
            } catch {
                trabajando = false
                self.error = L("No se ha podido. Prueba otra vez.", "That didn't work. Try again.", "Non è stato possibile. Riprova.")
            }
        }
    }
}
