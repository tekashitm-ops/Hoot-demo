import SwiftUI

struct MochilaVista: View {
    @Environment(Almacen.self) private var almacen
    @State private var dia: Date = Reloj.ahora
    @State private var ultima: Lanzamiento?
    @State private var contador = 0

    @State private var iconos: [String: CGPoint] = [:]
    @State private var marcoEscena: CGRect = .zero
    @State private var verDentro = false
    @ScaledMetric(relativeTo: .largeTitle) private var anchoMochila: CGFloat = 112
    @State private var anadiendo = false
    @State private var textoExtra = ""
    @State private var editando = false
    @State private var poniendoHorario = false
    @State private var elegido = false

    private var dias: [Date] {
        let datos = almacen.datos
        guard let primero = datos.diaMochila() else { return [] }
        var lista = [primero]
        var d = primero
        while lista.count < datos.diasConClase.count, let s = datos.siguienteDiaConClase(despuesDe: d) {
            lista.append(s)
            d = s
        }
        let orden = DatosEscolares.ordenSemana
        return lista.sorted {
            (orden.firstIndex(of: DatosEscolares.diaISO($0)) ?? 0) < (orden.firstIndex(of: DatosEscolares.diaISO($1)) ?? 0)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if almacen.datos.horario.isEmpty {

                    ScrollView {
                        VStack(spacing: 18) {
                            HootDice(frase: L("Aún no hay horario.", "No timetable yet.", "Ancora nessun orario."), gesto: .normal, tamano: 104,
                                     loboALaDerecha: true)
                            Button(L("Poner el horario", "Add timetable", "Aggiungi l'orario")) { poniendoHorario = true }
                                .buttonStyle(.glass)
                                .controlSize(.large)
                                .chocable(.capsula, reacciona: true)
                        }
                        .padding(.horizontal, Diseno.margen)
                        .padding(.top, 40)
                    }
                } else {
                    contenido
                }
            }

            .sobreElCielo(sinVelo: true)

            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editando = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel(L("Qué llevar", "What to pack", "Cosa portare"))
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) {
                    BotonCuenta()
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .sheet(isPresented: $editando) {
                HojaMateriales().hojaQueChoca()
            }
            .sheet(isPresented: $poniendoHorario) {
                HojaHorario().hojaQueChoca()
            }
            .alert(L("Algo más para este día", "Something else for this day", "Qualcos'altro per questo giorno"), isPresented: $anadiendo) {
                TextField(L("Por ejemplo, la autorización", "For example, the permission slip", "Per esempio, l'autorizzazione"), text: $textoExtra)
                Button(L("Añadir", "Add", "Aggiungi")) { anadirExtra() }
                Button(L("Cancelar", "Cancel", "Annulla"), role: .cancel) {}
            }
            .onAppear { elegirDia() }
            .onChange(of: almacen.pestana) { _, p in if p == .mochila { elegirDia() } }
        }
    }

    private func elegirDia() {
        guard !elegido || !dias.contains(where: { calendarioActual.isDate($0, inSameDayAs: dia) }) else { return }
        if let toca = almacen.datos.diaMochila() { dia = toca }
        elegido = true
    }

    static func esMomentoDeComprobar(_ dia: Date, _ datos: DatosEscolares, ahora: Date) -> Bool {
        guard calendarioActual.isDate(dia, inSameDayAs: ahora) else { return false }
        let primera = datos.clases(en: ahora).first?.inicio ?? 9 * 60
        return DatosEscolares.minutos(ahora) < primera
    }

    private var contenido: some View {
        let datos = almacen.datos
        let items = datos.itemsMochila(para: dia)
        let marcadas = datos.marcadas(dia)
        let faltan = items.filter { !marcadas.contains($0.id) }
        let dentro = items.filter { marcadas.contains($0.id) }
        let comprobar = Self.esMomentoDeComprobar(dia, datos, ahora: Reloj.ahora)
        return ScrollViewReader { desplazar in

            VStack(spacing: 0) {
                cabecera(items: items, faltan: faltan, dentro: dentro, comprobar: comprobar)
                ScrollView {
                    VStack(spacing: Diseno.huecoTarjetas) {
                        HootDice(frase: fraseHoot(items: items, faltan: faltan, comprobar: comprobar),
                                 gesto: faltan.isEmpty ? .feliz : .normal, tamano: 92, loboALaDerecha: true)
                        if comprobar {
                            comprobando(faltan: faltan, dentro: dentro)
                        } else {
                            preparando(faltan: faltan, dentro: dentro)
                        }
                        Button {
                            textoExtra = ""
                            anadiendo = true
                        } label: {
                            Label(L("Algo más para este día", "Something else for this day", "Qualcos'altro per questo giorno"), systemImage: "plus")
                        }
                        .buttonStyle(.glass)
                        .chocable(.capsula, reacciona: true)
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, Diseno.margen)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)

                .contentMargins(.top, Diseno.desvanecer, for: .scrollContent)
                .mask { DesvanecerArriba() }
                .onAppear {

                    if ModoCapturas.activo, let n = ModoCapturas.valor("-ir") { desplazar.scrollTo("grupo-\(n)", anchor: .top) }
                }
            }

            .coordinateSpace(.named("mochila"))
            .sensoryFeedback(.selection, trigger: dia)
        }
    }

    private func fraseHoot(items: [ItemMochila], faltan: [ItemMochila], comprobar: Bool) -> String {
        if let falta = faltan.first {
            return comprobar ? FrasesHoot.mananaFalta(cosa: falta.nombre, asignatura: falta.grupo.titulo) : FrasesHoot.nocheMochila()
        }
        return comprobar ? FrasesHoot.mananaLista() : FrasesHoot.nocheLista()
    }

    private func cabecera(items: [ItemMochila], faltan: [ItemMochila], dentro: [ItemMochila], comprobar: Bool) -> some View {
        let estado: String = {
            if items.isEmpty { return L("Nada que llevar", "Nothing to bring", "Niente da portare") }
            if faltan.isEmpty { return comprobar ? L("Todo dentro", "All packed", "Tutto dentro") : L("Lista", "Ready", "Pronto") }
            if faltan.count == 1 { return L("Falta 1", "1 to go", "Manca 1") }
            return L("Faltan \(faltan.count)", "\(faltan.count) to go", "Mancano \(faltan.count)")
        }()
        let detalle = items.isEmpty ? "" : L("\(Formato.diaRelativo(dia).conMayuscula) · \(items.count) cosas",
                                             "\(Formato.diaRelativo(dia).conMayuscula) · \(items.count) items",
                                             "\(Formato.diaRelativo(dia).conMayuscula) · \(items.count) cose")
        return VStack(spacing: 10) {
            if dias.count > 1 {
                Picker(L("Día", "Day", "Giorno"), selection: $dia) {
                    ForEach(dias, id: \.self) { d in
                        Text(Formato.nombreDia(iso: DatosEscolares.diaISO(d)).conMayuscula).tag(d)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            HStack(alignment: .bottom, spacing: 18) {
                EscenaMochila(
                    dentro: dentro.count,
                    total: items.count,
                    colores: dentro.compactMap { $0.colores.first },
                    ultima: ultima,
                    ancho: min(anchoMochila, 150)
                )
                .id(DatosEscolares.clave(dia))
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("mochila")) } action: { marcoEscena = $0 }
                VStack(alignment: .leading, spacing: 4) {
                    Text(estado)
                        .font(.largeTitle.bold().monospacedDigit())
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animando(Diseno.muelle, valor: faltan.count)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    if !detalle.isEmpty {
                        Text(detalle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(EstiloSecundario())
                    }
                }
                .padding(.bottom, 8)
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Diseno.margenTarjeta)
            .padding(.vertical, 10)
            .fondoModulo()
        }
        .padding(.horizontal, Diseno.margen)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func preparando(faltan: [ItemMochila], dentro: [ItemMochila]) -> some View {
        let grupos = Self.agrupar(faltan)
        ForEach(Array(grupos.enumerated()), id: \.element.grupo.id) { i, g in
            TarjetaCielo(titulo: g.grupo.titulo, simbolo: g.grupo.simbolo) {
                VStack(spacing: 0) {
                    ForEach(Array(g.items.enumerated()), id: \.element.id) { j, item in
                        fila(item, metida: false)
                        if j < g.items.count - 1 { separador }
                    }
                }
            }
            .id("grupo-\(i)")
        }
        if !dentro.isEmpty {
            TarjetaCielo(titulo: L("Dentro · \(dentro.count)", "Packed · \(dentro.count)", "Dentro · \(dentro.count)"), simbolo: "backpack.fill") {
                DisclosureGroup(isExpanded: $verDentro) {
                    VStack(spacing: 0) {
                        ForEach(Array(dentro.enumerated()), id: \.element.id) { j, item in
                            fila(item, metida: true)
                            if j < dentro.count - 1 { separador }
                        }
                    }
                } label: {
                    Text(verDentro ? L("Ocultar", "Hide", "Nascondi") : L("Ver lo que ya está dentro", "See what's packed", "Vedi cosa c'è dentro"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .tint(.white)
                .padding(.vertical, 6)
            }
        }
    }

    @ViewBuilder
    private func comprobando(faltan: [ItemMochila], dentro: [ItemMochila]) -> some View {
        if !faltan.isEmpty {

            TarjetaCielo(titulo: L("Antes de salir", "Before you leave", "Prima di uscire"), simbolo: "exclamationmark.circle.fill") {
                VStack(spacing: 0) {
                    ForEach(Array(faltan.enumerated()), id: \.element.id) { j, item in
                        fila(item, metida: false)
                        if j < faltan.count - 1 { separador }
                    }
                }
            }
        }
        if !dentro.isEmpty {
            TarjetaCielo(titulo: L("Dentro · \(dentro.count)", "Packed · \(dentro.count)", "Dentro · \(dentro.count)"), simbolo: "checkmark.circle.fill") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(dentro) { item in
                        Button { meter(item, yaDentro: true) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: item.simbolo)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle((item.colores.first ?? .indigo).color)
                                    .frame(width: 20)
                                Text(item.nombre)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .background(.white.opacity(Diseno.resalteHoy), in: RoundedRectangle(cornerRadius: Diseno.radioResalte, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(EstiloPulsar())
                        .accessibilityLabel(item.nombre)
                        .accessibilityValue(L("Dentro", "Packed", "Dentro"))
                        .accessibilityHint(L("Toca para sacarlo", "Tap to take it out", "Tocca per toglierlo"))
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var separador: some View {
        Rectangle().fill(.white.opacity(0.14)).frame(height: 0.5).padding(.leading, 56)
    }

    private func fila(_ item: ItemMochila, metida: Bool) -> some View {
        FilaMochila(item: item, metida: metida) {
            meter(item, yaDentro: metida)
        }
        .onGeometryChange(for: CGPoint.self) { geo in
            let f = geo.frame(in: .named("mochila"))

            return CGPoint(x: f.minX + 44 + 12 + 14, y: f.midY)
        } action: { iconos[item.id] = $0 }
        .contextMenu {
            if esExtra(item) {
                Button(L("Quitar", "Remove", "Togli"), systemImage: "trash", role: .destructive) { quitarExtra(item) }
            }
        }
    }

    static func agrupar(_ items: [ItemMochila]) -> [(grupo: GrupoMochila, items: [ItemMochila])] {
        var orden: [GrupoMochila] = []
        var por: [String: [ItemMochila]] = [:]
        for it in items {
            if por[it.grupo.id] == nil { orden.append(it.grupo) }
            por[it.grupo.id, default: []].append(it)
        }
        return orden.map { ($0, por[$0.id] ?? []) }
    }

    private func meter(_ item: ItemMochila, yaDentro: Bool) {
        if !yaDentro {
            contador += 1

            let ancho = min(anchoMochila, 150)
            let desde = iconos[item.id].map {
                CGPoint(x: $0.x - marcoEscena.minX, y: $0.y - marcoEscena.minY - ancho * 1.12 * 0.3)
            }
            ultima = Lanzamiento(id: contador, simbolo: item.simbolo, color: item.colores.first, desde: desde)
        }
        conMuelle(Diseno.muelleRebote) {
            almacen.alternarMochila(item.id, dia: dia)
        }
    }

    private func esExtra(_ item: ItemMochila) -> Bool {
        (almacen.datos.mochilaExtra[DatosEscolares.clave(dia)] ?? []).contains { DatosEscolares.normalizar($0) == item.id }
    }

    private func anadirExtra() {
        let texto = textoExtra.trimmingCharacters(in: .whitespaces)
        guard !texto.isEmpty else { return }
        let k = DatosEscolares.clave(dia)
        conMuelle {
            almacen.datos.mochilaExtra[k, default: []].append(texto)
        }
    }

    private func quitarExtra(_ item: ItemMochila) {
        let k = DatosEscolares.clave(dia)
        conMuelle {
            almacen.datos.mochilaExtra[k]?.removeAll { DatosEscolares.normalizar($0) == item.id }
            almacen.datos.mochilaMarcada[k]?.remove(item.id)
        }
    }
}

struct FilaMochila: View {
    var item: ItemMochila
    var metida: Bool
    var soloLectura = false
    var alAlternar: () -> Void = {}

    @ScaledMetric(relativeTo: .body) private var anchoIcono: CGFloat = 28

    var body: some View {
        HStack(spacing: 12) {
            if soloLectura {
                Image(systemName: metida ? "checkmark.circle.fill" : "hourglass")
                    .font(.title3)
                    .foregroundStyle(metida ? AnyShapeStyle(Color.hecho) : AnyShapeStyle(EstiloSecundario()))
                    .frame(width: 44, height: 44)
            } else {
                Casilla(marcada: metida, color: item.colores.first ?? .indigo, etiqueta: item.nombre, accion: alAlternar)
            }
            Image(systemName: item.simbolo)
                .font(.body.weight(.semibold))
                .foregroundStyle((item.colores.first ?? .indigo).color)
                .frame(width: anchoIcono)
                .accessibilityHidden(true)
            Text(item.nombre)
                .foregroundStyle(metida ? AnyShapeStyle(EstiloSecundario()) : AnyShapeStyle(Color.primary))
                .strikethrough(metida)
                .accessibilityHint(item.deDonde.joined(separator: ", "))
            Spacer(minLength: 0)
            if item.colores.count > 1 {
                HStack(spacing: -4) {
                    ForEach(item.colores, id: \.self) { c in
                        Circle().fill(c.color).frame(width: 10, height: 10)
                            .overlay(Circle().stroke(.black.opacity(0.35), lineWidth: 1.5))
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !soloLectura { alAlternar() } }
    }
}

struct HojaMateriales: View {
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        NavigationStack {
            ListaMateriales()
                .navigationTitle(L("Qué llevar", "What to pack", "Cosa portare"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(role: .confirm) { cerrar() }
                    }
                }
        }
    }
}

struct ListaMateriales: View {
    @Environment(Almacen.self) private var almacen
    @State private var nuevo = ""

    var body: some View {
        @Bindable var almacen = almacen
        List {
            Section {
                ForEach(almacen.datos.siempre, id: \.self) { cosa in
                    Label(cosa, systemImage: "star.fill")
                }
                .onDelete { almacen.datos.siempre.remove(atOffsets: $0) }
                HStack {
                    TextField(L("Añadir algo de siempre", "Add an everyday item", "Aggiungi qualcosa di sempre"), text: $nuevo)
                        .onSubmit(anadir)
                    Button(L("Añadir", "Add", "Aggiungi"), action: anadir)
                        .buttonStyle(.borderless)
                        .disabled(nuevo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text(L("Todos los días con clase", "Every school day", "Tutti i giorni di scuola"))
            }

            if !almacen.datos.asignaturas.isEmpty {
                Section {
                    ForEach($almacen.datos.asignaturas) { $a in
                        NavigationLink {
                            EditorAsignatura(asignatura: $a)
                        } label: {
                            HStack(spacing: 14) {
                                IconoAjustes(simbolo: a.simbolo, color: a.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(a.nombre)
                                    Text(a.materiales.isEmpty ? L("Sin materiales", "No supplies", "Nessun materiale") : a.materiales.map(\.nombre).joined(separator: ", "))
                                        .font(.subheadline)
                                        .textoSecundario()
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                } header: {
                    Text(L("Por asignatura", "By subject", "Per materia"))
                }
            }
        }
    }

    private func anadir() {
        let t = nuevo.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        conMuelle { almacen.datos.siempre.append(t) }
        nuevo = ""
    }
}
