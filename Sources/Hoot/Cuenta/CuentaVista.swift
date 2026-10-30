import SwiftUI
import PhotosUI

struct CuentaVista: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var cerrandoSesion = false
    @State private var sinGuardar = false
    @State private var ruta: [AjusteCuenta] = ModoCapturas.ajusteInicial
    @State private var nube = Sincronizacion.compartida

    private var puedeCerrarSesion: Bool { !(nube.activa || nube.deMuestra) || nube.sesion != nil }

    var body: some View {
        NavigationStack(path: $ruta) {
            List {
                Section {
                    CabeceraCuenta()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 16, trailing: 0))
                }

                SeccionNube()

                Section {
                    enlace(.personal)
                    enlace(.seguridad)
                    enlace(.familia)
                }

                if !almacen.esFamilia {
                    Section {
                        enlace(.asignaturas)
                        enlace(.horario)
                        enlace(.calendarios)
                        enlace(.teams)
                        enlace(.notas)
                    }
                }

                Section {
                    enlace(.avisos)
                    if !almacen.esFamilia {
                        enlace(.mochila)
                        enlace(.estudio)
                        enlace(.fondo)
                    }
                    enlace(.idioma)
                }

                if !almacen.esFamilia {
                    Section {
                        enlace(.uso)
                    }
                }

                Section {
                    enlace(.datos)
                }

                Section {
                    enlace(.desarrollador)
                }

                if puedeCerrarSesion {
                    Section {
                        Button(role: .destructive) {
                            cerrandoSesion = true
                        } label: {
                            Text(L("Cerrar sesión", "Sign Out", "Esci"))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            .environment(\.defaultMinListRowHeight, Diseno.filaCuenta)
            .navigationTitle(L("Cuenta", "Account", "Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BotonCerrar { cerrar() }
                }
            }
            .navigationDestination(for: AjusteCuenta.self) { a in
                a.destino
            }
            .confirmationDialog(L("¿Cerrar sesión?", "Sign out?", "Uscire?"), isPresented: $cerrandoSesion, titleVisibility: .visible) {
                Button(L("Cerrar sesión", "Sign Out", "Esci"), role: .destructive) { salir(aunqueFalte: false) }
            } message: {
                Text(L("Tus datos se quedan guardados en la cuenta: al volver a entrar, estará todo.",
                       "Your data stays saved in your account: when you sign back in, it'll all be there.",
                       "I tuoi dati restano salvati nell'account: quando rientri, ci sarà tutto."))
            }
            .alert(L("No se ha guardado lo último", "The latest changes weren't saved", "Le ultime modifiche non sono state salvate"), isPresented: $sinGuardar) {
                Button(L("Cerrar sesión igualmente", "Sign Out Anyway", "Esci comunque"), role: .destructive) { salir(aunqueFalte: true) }
                Button(L("Cancelar", "Cancel", "Annulla"), role: .cancel) {}
            } message: {
                Text(L("Sin conexión no se ha podido guardar en tu cuenta lo último que cambiaste. Si cierras sesión, se perderá.",
                       "Without a connection, your latest changes couldn't be saved to your account. If you sign out, they'll be lost.",
                       "Senza connessione non è stato possibile salvare nell'account le ultime modifiche. Se esci, andranno perse."))
            }
        }
    }

    private func salir(aunqueFalte: Bool) {
        Task {
            if nube.activa && nube.sesion != nil {
                if !aunqueFalte, !(await nube.subirYa()) {
                    sinGuardar = true
                    return
                }
                await nube.cerrarSesion()
                cerrar()
                try? await Task.sleep(for: .milliseconds(400))
                conMuelle(Diseno.muelleLento) { almacen.borrarTodo() }
            } else {
                cerrar()
                try? await Task.sleep(for: .milliseconds(400))
                conMuelle(Diseno.muelleLento) { almacen.cerrarSesion() }
            }
        }
    }

    private func enlace(_ a: AjusteCuenta) -> some View {
        NavigationLink(value: a) {
            FilaAjuste(simbolo: a.simbolo, color: a.color, titulo: a.titulo, valor: valor(a))
        }
    }

    private func valor(_ a: AjusteCuenta) -> String? {
        switch a {
        case .teams:
            switch almacen.teams.estado {
            case .sinVincular: L("No", "Off", "No")
            case .prueba: L("Prueba", "Test", "Prova")
            case .vinculado: L("Sí", "On", "Sì")
            }
        case .calendarios:
            Calendarios.compartido.permiso == .concedido
                ? (Calendarios.compartido.cuentas.isEmpty ? nil : "\(Calendarios.compartido.cuentas.count)")
                : L("No", "Off", "No")
        case .idioma: almacen.ajustes.idioma.nombrePropio
        case .uso: ClaudeIA.activa ? "\(Int((ClaudeIA.compartida.fraccion * 100).rounded())) %" : L("Gratis", "Free", "Gratis")
        case .avisos: almacen.ajustes.avisos.activados ? L("Sí", "On", "Sì") : L("No", "Off", "No")
        case .familia: almacen.esFamilia ? (almacen.hijos.isEmpty ? nil : "\(almacen.hijos.count)") : (almacen.vinculos.isEmpty ? nil : "\(almacen.vinculos.count)")
        case .asignaturas: almacen.datos.asignaturas.isEmpty ? nil : "\(almacen.datos.asignaturas.count)"
        default: nil
        }
    }
}

struct CabeceraCuenta: View {
    @Environment(Almacen.self) private var almacen
    @State private var eligiendo = false
    @State private var fototeca: PhotosPickerItem?
    @State private var camara = false
    @State private var mostrandoFototeca = false
    @ScaledMetric(relativeTo: .largeTitle) private var lado = Diseno.avatarCuenta

    var body: some View {
        VStack(spacing: 14) {
            Menu {
                Button(L("Elegir una foto", "Choose a Photo", "Scegli una foto"), systemImage: "photo.on.rectangle") { mostrandoFototeca = true }
                if CamaraFoto.disponible {
                    Button(L("Hacer una foto", "Take a Photo", "Scatta una foto"), systemImage: "camera") { camara = true }
                }
                Button(L("Usar el lobo", "Use the Wolf", "Usa il lupo"), systemImage: "pawprint.fill") {
                    conMuelle { almacen.perfil.avatar = .lobo }
                }
                Button(L("Usar mis iniciales", "Use My Initials", "Usa le mie iniziali"), systemImage: "textformat") {
                    conMuelle { almacen.perfil.avatar = .iniciales }
                }
                Divider()
                Picker(L("Color", "Color", "Colore"), selection: Binding(get: { almacen.perfil.colorAvatar }, set: { c in conMuelle { almacen.perfil.colorAvatar = c } })) {
                    ForEach([ColorHoot.indigo, .azul, .turquesa, .verde, .naranja, .rosa, .morado], id: \.self) { c in
                        Text(c.nombre).tag(c)
                    }
                }
            } label: {
                almacen.avatar(lado)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: lado * 0.13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: lado * 0.28, height: lado * 0.28)
                            .background(Color(uiColor: .systemBlue), in: Circle())
                            .overlay(Circle().stroke(Color(uiColor: .systemGroupedBackground), lineWidth: 3))
                            .offset(x: -lado * 0.02, y: -lado * 0.02)
                    }
            }
            .accessibilityLabel(L("Cambiar la foto de perfil", "Change profile picture", "Cambia la foto del profilo"))

            VStack(spacing: 3) {
                Text(almacen.perfil.nombreCompleto.isEmpty ? L("Sin nombre", "No name", "Senza nome") : almacen.perfil.nombreCompleto)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                if !almacen.perfil.correo.isEmpty {
                    Text(almacen.perfil.correo)
                        .font(.subheadline)
                        .textoSecundario()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                if !subtitulo.isEmpty {
                    Text(subtitulo)
                        .font(.subheadline)
                        .textoSecundario()
                }
            }
        }
        .photosPicker(isPresented: $mostrandoFototeca, selection: $fototeca, matching: .images)
        .onChange(of: fototeca) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    conMuelle { almacen.ponerFoto(img) }
                }
                fototeca = nil
            }
        }
        .fullScreenCover(isPresented: $camara) {
            CamaraFoto { foto in
                camara = false
                if let foto { conMuelle { almacen.ponerFoto(foto) } }
            }
            .ignoresSafeArea()
        }
    }

    private var subtitulo: String {
        var partes: [String] = []
        if almacen.esFamilia {
            partes.append(L("Familia", "Family", "Famiglia"))
        } else if !almacen.perfil.curso.isEmpty {
            partes.append(almacen.perfil.curso)
        }
        return partes.joined(separator: " · ")
    }
}

enum AjusteCuenta: Hashable {
    case personal, seguridad, familia
    case asignaturas, horario, calendarios, teams, notas
    case avisos, mochila, estudio, fondo, idioma
    case uso
    case datos
    case desarrollador

    var titulo: String {
        switch self {
        case .personal: L("Información personal", "Personal Information", "Informazioni personali")
        case .seguridad: L("Contraseña y Face ID", "Password & Face ID", "Password e Face ID")
        case .familia: L("Control parental", "Parental Controls", "Controllo parentale")
        case .asignaturas: L("Asignaturas", "Subjects", "Materie")
        case .horario: L("Horario", "Timetable", "Orario")
        case .calendarios: L("Calendarios", "Calendars", "Calendari")
        case .teams: "Microsoft Teams"
        case .notas: L("Curso escolar", "School Year", "Anno scolastico")
        case .avisos: L("Avisos", "Notifications", "Notifiche")
        case .mochila: L("Mochila", "Backpack", "Zaino")
        case .estudio: L("Ayuda de estudio", "Study Help", "Aiuto allo studio")
        case .fondo: L("Fondo", "Background", "Sfondo")
        case .idioma: L("Idioma y región", "Language & Region", "Lingua e regione")
        case .uso: L("Uso de la IA", "AI Usage", "Utilizzo dell'IA")
        case .datos: L("Datos y privacidad", "Data & Privacy", "Dati e privacy")
        case .desarrollador: L("Modo desarrollador", "Developer Mode", "Modalità sviluppatore")
        }
    }

    var simbolo: String {
        switch self {
        case .personal: "person.text.rectangle.fill"
        case .seguridad: "key.fill"
        case .familia: "figure.and.child.holdinghands"
        case .asignaturas: "books.vertical.fill"
        case .horario: "calendar.day.timeline.left"
        case .calendarios: "calendar"
        case .teams: "person.3.fill"
        case .notas: "calendar.badge.clock"
        case .avisos: "bell.badge.fill"
        case .mochila: "backpack.fill"
        case .estudio: "sparkles"
        case .fondo: "cloud.sun.fill"
        case .idioma: "globe"
        case .uso: "gauge.with.dots.needle.50percent"
        case .datos: "hand.raised.fill"
        case .desarrollador: "hammer.fill"
        }
    }

    var color: ColorHoot {
        switch self {
        case .personal, .seguridad: .gris
        case .familia: .verde
        case .asignaturas: .naranja
        case .horario: .azul
        case .calendarios: .rojo
        case .teams: .indigo
        case .notas: .rosa
        case .avisos: .rojo
        case .mochila: .marron
        case .estudio: .morado
        case .fondo: .turquesa
        case .idioma: .cian
        case .uso: .indigo
        case .datos: .gris
        case .desarrollador: .gris
        }
    }

    @ViewBuilder
    var destino: some View {
        switch self {
        case .personal: AjustePersonal()
        case .seguridad: AjusteSeguridad()
        case .familia: AjusteFamilia()
        case .asignaturas: AsignaturasVista()
        case .horario: AjusteHorario()
        case .calendarios: AjusteCalendarios()
        case .teams: AjusteTeams()
        case .notas: AjusteNotas()
        case .avisos: AjusteAvisos()
        case .mochila: AjusteMochila()
        case .estudio: AjusteEstudio()
        case .fondo: AjusteFondo()
        case .idioma: AjusteIdioma()
        case .uso: UsoVista()
        case .datos: AjusteDatos()
        case .desarrollador: AjusteDesarrollador()
        }
    }
}
