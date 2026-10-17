import SwiftUI

struct AjusteCalendarios: View {
    @State private var calendarios = Calendarios.compartido
    @Environment(\.scenePhase) private var fase
    @Environment(\.openURL) private var abrirURL

    @State private var pasosCapturas = ModoCapturas.activo ? ModoCapturas.valor("-pasos") : nil

    var body: some View {
        List {
            switch calendarios.permiso {
            case .sinPreguntar:
                Section {
                    cabecera(L("Lo que tengas en el Calendario del iPhone sale en Hoot: el del colegio, el de Google, el tuyo.",
                               "What's in your iPhone's Calendar shows up in Hoot: your school's, Google's, your own.",
                               "Quello che hai nel Calendario dell'iPhone compare in Hoot: quello della scuola, di Google, il tuo."))
                }
                Section {
                    Button(L("Permitir el acceso al Calendario", "Allow Access to Calendar", "Consenti l'accesso al Calendario")) {
                        Task { await calendarios.pedirPermiso() }
                    }
                }
            case .denegado:
                Section {
                    cabecera(L("Hoot no tiene permiso para ver el Calendario.", "Hoot isn't allowed to see your Calendar.", "Hoot non ha il permesso di vedere il Calendario."))
                } footer: {
                    Text(L("En Ajustes, toca Calendarios y elige «Acceso total».", "In Settings, tap Calendars and choose “Full Access”.", "In Impostazioni, tocca Calendari e scegli «Accesso completo»."))
                }
                Section {
                    Button(L("Abrir Ajustes", "Open Settings", "Apri Impostazioni")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) { abrirURL(url) }
                    }
                }
            case .concedido:
                SeccionesCalendarios()
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(AjusteCuenta.calendarios.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { calendarios.arrancar() }
        .navigationDestination(isPresented: Binding(get: { pasosCapturas != nil }, set: { if !$0 { pasosCapturas = nil } })) {
            if let t = pasosCapturas.flatMap(PasosCalendario.Tipo.init(rawValue:)) {
                PasosCalendario(tipo: t)
            } else {
                AnadirCalendario()
            }
        }

        .onChange(of: fase) { _, nueva in if nueva == .active { calendarios.recargar() } }
    }

    private func cabecera(_ texto: String) -> some View {
        HStack(spacing: 14) {
            IconoAjustes(simbolo: AjusteCuenta.calendarios.simbolo, color: AjusteCuenta.calendarios.color)
            Text(texto)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

struct SeccionesCalendarios: View {
    @State private var calendarios = Calendarios.compartido
    @Environment(\.dynamicTypeSize) private var letra

    var enConfiguracion = false

    var body: some View {
        Group { cuentas }
            .listRowBackground(enConfiguracion ? Color(uiColor: .secondarySystemBackground) : nil)
    }

    @ViewBuilder
    private var cuentas: some View {
        let delColegio = calendarios.cuentas.filter(\.delColegio)
        let otras = calendarios.cuentas.filter { !$0.delColegio }
        Section {
            if delColegio.isEmpty {
                if calendarios.leido {
                    NavigationLink {
                        PasosCalendario(tipo: .colegio)
                    } label: {
                        FilaAjuste(simbolo: "building.columns.fill", color: .gris,
                                   titulo: L("Añadir el del colegio", "Add Your School's", "Aggiungi quello della scuola"))
                    }
                }
            } else {
                ForEach(delColegio) { c in fila(c) }
            }
        } header: {
            Text(L("Del colegio", "School", "Della scuola"))
        } footer: {
            if !delColegio.isEmpty {
                Text(delColegio.count == 1
                     ? L("Ya tienes un calendario del colegio vinculado.", "You already have a school calendar linked.", "Hai già collegato un calendario della scuola.")
                     : L("Ya tienes \(delColegio.count) calendarios del colegio vinculados.", "You already have \(delColegio.count) school calendars linked.", "Hai già collegato \(delColegio.count) calendari della scuola."))
            }
        }

        if !otras.isEmpty {
            Section {
                ForEach(otras) { c in fila(c) }
            } header: {
                Text(L("Otras cuentas", "Other Accounts", "Altri account"))
            }
        }

        Section {
            NavigationLink {
                AnadirCalendario()
            } label: {
                Label(L("Vincular otro calendario", "Link Another Calendar", "Collega un altro calendario"), systemImage: "plus")
            }
        } footer: {
            Text(L("Hoot solo lee los calendarios: no cambia nada en ellos.", "Hoot only reads your calendars: it never changes them.", "Hoot legge soltanto i calendari: non li modifica."))
        }
    }

    private func fila(_ c: CuentaCalendario) -> some View {
        let oculta = !c.calendarios.contains { calendarios.visible($0.id, tipo: c.tipo) }

        let debajo = c.clase == c.titulo ? c.calendarios.map(\.titulo).joined(separator: " · ") : c.clase
        let grande = letra.isAccessibilitySize
        let textos = VStack(alignment: .leading, spacing: 2) {

            Text(grande ? c.titulo.replacingOccurrences(of: "@", with: "@\u{200B}") : c.titulo)
                .lineLimit(grande ? 2 : 1)
                .minimumScaleFactor(0.5)
            Text(debajo)
                .font(.subheadline)
                .textoSecundario()
        }
        let marca = Text(L("Oculta", "Hidden", "Nascosto")).textoSecundario()
        return NavigationLink {
            AjusteCuentaCalendario(cuenta: c)
        } label: {
            if grande {

                VStack(alignment: .leading, spacing: 6) {
                    IconoAjustes(simbolo: c.simbolo, color: c.colorIcono)
                    textos
                    if oculta { marca }
                }
            } else {
                HStack(spacing: 14) {
                    IconoAjustes(simbolo: c.simbolo, color: c.colorIcono)
                    textos
                    Spacer(minLength: Diseno.hueco)
                    if oculta { marca }
                }
            }
        }
        .accessibilityValue(oculta ? L("Oculta en Hoot", "Hidden in Hoot", "Nascosto in Hoot") : "")
    }

}

struct AjusteCuentaCalendario: View {
    var cuenta: CuentaCalendario
    @State private var calendarios = Calendarios.compartido

    var body: some View {
        List {
            Section {
                ForEach(cuenta.calendarios) { c in
                    Toggle(isOn: Binding(get: { calendarios.visible(c.id, tipo: cuenta.tipo) },
                                         set: { calendarios.mostrar(c.id, $0) })) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(c.color.color)
                                .frame(width: 12, height: 12)
                                .accessibilityHidden(true)
                            Text(c.titulo)
                                .lineLimit(2)
                        }
                    }
                }
            } header: {
                Text(L("En Hoot", "In Hoot", "In Hoot"))
            } footer: {
                if cuenta.tipo == .cumpleanos {
                    Text(L("Los cumpleaños no salen hasta que los enciendas.", "Birthdays don't show until you turn them on.", "I compleanni non compaiono finché non li attivi."))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(cuenta.titulo)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AnadirCalendario: View {
    var body: some View {
        List {
            Section {
                ForEach(PasosCalendario.Tipo.allCases) { t in
                    NavigationLink {
                        PasosCalendario(tipo: t)
                    } label: {
                        HStack(spacing: 14) {
                            IconoAjustes(simbolo: t.simbolo, color: t.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.titulo)
                                Text(t.detalle)
                                    .font(.subheadline)
                                    .textoSecundario()
                            }
                        }
                    }
                }
            } footer: {
                Text(L("Las cuentas se añaden en los Ajustes del iPhone. Al volver, salen aquí solas.",
                       "Accounts are added in iPhone Settings. When you come back, they show up here.",
                       "Gli account si aggiungono nelle Impostazioni dell'iPhone. Quando torni, compaiono qui."))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L("Vincular otro calendario", "Link Another Calendar", "Collega un altro calendario"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PasosCalendario: View {
    enum Tipo: String, CaseIterable, Identifiable {
        case colegio, google, otra
        var id: String { rawValue }

        var titulo: String {
            switch self {
            case .colegio: L("Del colegio (Microsoft)", "School (Microsoft)", "Della scuola (Microsoft)")
            case .google: "Google"
            case .otra: L("Otra cuenta", "Another Account", "Un altro account")
            }
        }

        var detalle: String {
            switch self {
            case .colegio: L("La cuenta con la que entras en Teams", "The account you use for Teams", "L'account con cui entri in Teams")
            case .google: L("Gmail o la cuenta de Google del colegio", "Gmail or your school's Google account", "Gmail o l'account Google della scuola")
            case .otra: "Yahoo, Outlook.com…"
            }
        }

        var simbolo: String {
            switch self {
            case .colegio: "building.columns.fill"
            case .google: "envelope.fill"
            case .otra: "calendar.badge.plus"
            }
        }

        var color: ColorHoot {
            switch self {
            case .colegio: .azul
            case .google: .verde
            case .otra: .naranja
            }
        }
    }

    var tipo: Tipo
    @State private var calendarios = Calendarios.compartido
    @State private var antes: Set<String>?
    @Environment(\.scenePhase) private var fase

    private var pasos: [String] {
        let inicio = [
            L("Abre **Ajustes** en el iPhone.", "Open **Settings** on your iPhone.", "Apri **Impostazioni** sull'iPhone."),
            L("Toca **Apps** y luego **Calendario**.", "Tap **Apps**, then **Calendar**.", "Tocca **App** e poi **Calendario**."),
            L("Toca **Cuentas de Calendario** y luego **Añadir cuenta**.", "Tap **Calendar Accounts**, then **Add Account**.", "Tocca **Account Calendario** e poi **Aggiungi account**."),
        ]
        switch tipo {
        case .colegio:
            return inicio + [
                L("Elige **Microsoft Exchange**.", "Choose **Microsoft Exchange**.", "Scegli **Microsoft Exchange**."),
                L("Escribe el correo del colegio (el de Teams) y toca **Siguiente**.", "Enter your school email (your Teams one) and tap **Next**.", "Scrivi l'email della scuola (quella di Teams) e tocca **Avanti**."),
                L("Toca **Iniciar sesión** y entra con la contraseña del colegio.", "Tap **Sign In** and use your school password.", "Tocca **Accedi** ed entra con la password della scuola."),
                L("Deja encendido **Calendarios** y toca **Guardar**.", "Leave **Calendars** on and tap **Save**.", "Lascia attivo **Calendari** e tocca **Salva**."),
            ]
        case .google:
            return inicio + [
                L("Elige **Google**.", "Choose **Google**.", "Scegli **Google**."),
                L("Entra con tu cuenta de Google.", "Sign in with your Google account.", "Accedi con il tuo account Google."),
                L("Deja encendido **Calendarios** y toca **Guardar**.", "Leave **Calendars** on and tap **Save**.", "Lascia attivo **Calendari** e tocca **Salva**."),
            ]
        case .otra:
            return inicio + [
                L("Elige tu cuenta. Si no sale, toca **Otra** y luego **Añadir cuenta CalDAV**.", "Choose your account. If it isn't listed, tap **Other**, then **Add CalDAV Account**.", "Scegli il tuo account. Se non c'è, tocca **Altro** e poi **Aggiungi account CalDAV**."),
                L("Entra con tu correo y tu contraseña.", "Sign in with your email and password.", "Accedi con la tua email e la password."),
                L("Deja encendido **Calendarios** y toca **Guardar**.", "Leave **Calendars** on and tap **Save**.", "Lascia attivo **Calendari** e tocca **Salva**."),
            ]
        }
    }

    private var nueva: CuentaCalendario? {
        guard let antes else { return nil }
        return calendarios.cuentas.first { !antes.contains($0.id) }
    }

    var body: some View {
        List {
            if let nueva {
                Section {
                    HStack(spacing: 14) {
                        IconoAjustes(simbolo: "checkmark", color: .verde)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("Vinculado", "Linked", "Collegato")).font(.headline)
                            Text(nueva.titulo).font(.subheadline).textoSecundario()
                        }
                    }
                }
            }
            Section {
                PasosNumerados(pasos: pasos, color: tipo.color)
            } footer: {
                if tipo == .colegio {
                    Text(L("Si el iPhone dice que no se puede, tu colegio no deja añadir su cuenta.", "If your iPhone says it can't, your school doesn't allow adding its account.", "Se l'iPhone dice che non si può, la scuola non permette di aggiungere il suo account."))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(tipo.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: nueva?.id)
        .onAppear { if antes == nil { antes = Set(calendarios.cuentas.map(\.id)) } }
        .onChange(of: fase) { _, f in if f == .active { calendarios.recargar() } }
    }
}

struct PasosNumerados: View {
    var pasos: [String]
    var color: ColorHoot = .indigo

    var body: some View {
        ForEach(Array(pasos.enumerated()), id: \.offset) { i, paso in
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(i + 1)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(color.sobre)
                    .frame(width: 24, height: 24)
                    .background(color.color, in: Circle())
                    .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 7 }
                    .accessibilityHidden(true)
                Text(paso.conMarkdown)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }
}
