import SwiftUI

struct HorarioCielo: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dynamicTypeSize) private var letra
    @Environment(\.dismiss) private var cerrar

    var enHoja = false

    var enConfiguracion = false
    var alContinuar: () -> Void = {}
    @State var editando = false
    @State private var pincel: Pincel?
    @State private var historial: [[Clase]] = []
    @State private var eligiendoDias = false
    @State private var cambiandoHoras = false
    @State private var pendiente: Cambio?

    enum Pincel: Hashable { case asignatura(UUID), goma }

    struct Cambio: Identifiable {
        var id = UUID()
        var origen: Int
        var destinos: [Int]
        var vaciar = false
    }

    var body: some View {
        @Bindable var almacen = almacen
        TimelineView(.everyMinute) { contexto in
            let ahora = Reloj.desde(contexto.date)
            let datos = almacen.datos
            VStack(alignment: .leading, spacing: 0) {
                cabecera(datos, ahora: ahora)
                Group {
                    if letra.isAccessibilitySize {
                        ListaHorario(datos: $almacen.datos, editando: editando) { guardarHistorial() }
                    } else {
                        RejillaSemana(datos: datos, ahora: ahora, editando: editando, pincel: pincel) { dia, franja in
                            pintar(dia: dia, franja: franja)
                        } alEmpezarTrazo: {
                            guardarHistorial()
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 14)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }

            .environment(\.colorScheme, .dark)
            .environment(\.sobreCielo, true)
            .background { FondoTiempo(vidaEnHoja: true) }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                if editando && !letra.isAccessibilitySize {
                    Paleta(asignaturas: almacen.datos.asignaturas, pincel: $pincel)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if enConfiguracion {

                    Button(action: alContinuar) {
                        Text(L("Continuar", "Continue", "Continua"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.extraLarge)
                    .tint(Color.azulConfigRelleno)
                    .padding(.horizontal, Diseno.margen + 8)
                    .padding(.bottom, 8)
                    .chocable(.capsula)
                }
            }
        }

        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { barra }
        .sheet(isPresented: $eligiendoDias) {
            NavigationStack {
                Form {
                    Section {
                        SelectorDias(seleccion: $almacen.datos.diasLectivos, color: .indigo, minimo: 1)
                    } footer: {
                        Text(L("Los días sin clase no salen en el horario ni en la mochila.", "Days without school don't show in the timetable or the backpack.", "I giorni senza scuola non compaiono nell'orario né nello zaino."))
                    }
                }
                .navigationTitle(L("Días con clase", "School days", "Giorni di scuola"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button(role: .confirm) { eligiendoDias = false } }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $cambiandoHoras) { EditorFranjas(datos: $almacen.datos) }
        .confirmationDialog(pendiente.map(tituloCambio) ?? "", isPresented: Binding(get: { pendiente != nil }, set: { if !$0 { pendiente = nil } }),
                            titleVisibility: .visible, presenting: pendiente) { c in
            Button(c.vaciar ? L("Vaciar", "Clear", "Svuota") : L("Copiar", "Copy", "Copia"), role: .destructive) { aplicar(c) }
        } message: { c in
            Text(mensajeCambio(c))
        }
        .sensoryFeedback(.selection, trigger: pincel)
        .animando(Diseno.muelle, valor: editando)
        .onAppear {
            if editando, pincel == nil, let n = ModoCapturas.valor("-pincel").flatMap(Int.init), almacen.datos.asignaturas.indices.contains(n) {
                pincel = .asignatura(almacen.datos.asignaturas[n].id)
            }
        }
    }

    @ViewBuilder
    private func cabecera(_ datos: DatosEscolares, ahora: Date) -> some View {
        let (actual, siguiente) = datos.claseAhora(ahora)
        let m = DatosEscolares.minutos(ahora)
        VStack(alignment: .leading, spacing: 4) {
            if enConfiguracion {
                Text(L("Tu horario", "Your timetable", "Il tuo orario"))
                    .font(.largeTitle.bold())
                Text(L("Elige una asignatura abajo y toca o arrastra por sus horas.", "Pick a subject below, then tap or drag across its classes.", "Scegli una materia qui sotto e tocca o trascina sulle sue ore."))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(editando ? L("Toca o arrastra para poner la asignatura", "Tap or drag to set the subject", "Tocca o trascina per mettere la materia") : L("Horario", "Timetable", "Orario"))
                    .font(editando ? .title3.weight(.semibold) : .largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !editando {
                Group {
                    if let c = actual, let a = datos.asignatura(c.asignaturaID) {
                        Text(L("Ahora \(a.nombre) · quedan \(c.fin - m) min", "Now \(a.nombre) · \(c.fin - m) min left", "Ora \(a.nombre) · mancano \(c.fin - m) min"))
                    } else if let s = siguiente, let a = datos.asignatura(s.asignaturaID) {
                        Text(L("A las \(Formato.hora(s.inicio)), \(a.nombre)", "At \(Formato.hora(s.inicio)), \(a.nombre)", "Alle \(Formato.hora(s.inicio)), \(a.nombre)"))
                    } else if let d = datos.siguienteDiaConClase(despuesDe: ahora), let p = datos.clases(en: d).first,
                              let a = datos.asignatura(p.asignaturaID) {
                        Text(L("\(Formato.diaRelativo(d, desde: ahora)), a las \(Formato.hora(p.inicio)): \(a.nombre)",
                               "\(Formato.diaRelativo(d, desde: ahora)) at \(Formato.hora(p.inicio)): \(a.nombre)",
                               "\(Formato.diaRelativo(d, desde: ahora)) alle \(Formato.hora(p.inicio)): \(a.nombre)"))
                    }
                }
                .font(.headline)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.15), radius: 6, y: 1)
        .padding(.horizontal, Diseno.margen)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .accessibilityElement(children: .combine)
    }

    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        if editando {

            if !enConfiguracion {
            ToolbarItem(placement: .topBarLeading) {
                BotonCerrar {
                    if enHoja {
                        cerrar()
                    } else {
                        conMuelle { editando = false; pincel = nil }
                    }
                }
            }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(L("Deshacer", "Undo", "Annulla"), systemImage: "arrow.uturn.backward") { deshacerUltimo() }
                    .disabled(historial.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Menu(L("Copiar un día", "Copy a day", "Copia un giorno")) {
                        ForEach(almacen.datos.diasLectivosOrdenados, id: \.self) { d in
                            Menu(Formato.nombreDia(iso: d, estilo: .wide).conMayuscula) {
                                let otros = almacen.datos.diasLectivosOrdenados.filter { $0 != d }
                                Button(L("A todos los demás", "To all the others", "A tutti gli altri")) { pendiente = Cambio(origen: d, destinos: otros) }
                                ForEach(otros, id: \.self) { o in
                                    Button(L("Al \(Formato.nombreDia(iso: o, estilo: .wide))", "To \(Formato.nombreDia(iso: o, estilo: .wide))", "A \(Formato.nombreDia(iso: o, estilo: .wide))")) {
                                        pendiente = Cambio(origen: d, destinos: [o])
                                    }
                                }
                            }
                        }
                    }
                    Menu(L("Vaciar un día", "Clear a day", "Svuota un giorno")) {
                        ForEach(almacen.datos.diasLectivosOrdenados, id: \.self) { d in
                            Button(Formato.nombreDia(iso: d, estilo: .wide).conMayuscula, role: .destructive) {
                                pendiente = Cambio(origen: d, destinos: [], vaciar: true)
                            }
                        }
                    }
                    Divider()
                    Button(L("Días con clase", "School days", "Giorni di scuola"), systemImage: "calendar") { eligiendoDias = true }
                    Button(L("Horas de las clases", "Class times", "Orari delle lezioni"), systemImage: "clock") { cambiandoHoras = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel(L("Más", "More", "Altro"))
            }
            if !enConfiguracion {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        conMuelle { editando = false; pincel = nil }
                    }
                }
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L("Editar", "Edit", "Modifica")) {
                    conMuelle { editando = true }
                }
                .chocable(.capsula, reacciona: true)
            }
            if enHoja {
                ToolbarItem(placement: .topBarLeading) {
                    BotonCerrar { cerrar() }
                }
            }
        }
    }

    private func guardarHistorial() {
        historial.append(almacen.datos.horario)
        if historial.count > 40 { historial.removeFirst() }
    }

    private func deshacerUltimo() {
        guard let previo = historial.popLast() else { return }
        conMuelle(Diseno.muelleRapido) { almacen.datos.horario = previo }
    }

    private func pintar(dia: Int, franja: Franja) {
        guard let pincel else { return }
        let actual = almacen.datos.horario.first { $0.dia == dia && $0.inicio == franja.inicio }
        conMuelle(Diseno.muelleRapido) {
            switch pincel {
            case .goma:
                almacen.datos.horario.removeAll { $0.dia == dia && $0.inicio == franja.inicio }
            case .asignatura(let id):
                guard actual?.asignaturaID != id else { return }
                almacen.datos.horario.removeAll { $0.dia == dia && $0.inicio == franja.inicio }
                let aula = almacen.datos.asignatura(id)?.aula ?? ""
                almacen.datos.horario.append(Clase(dia: dia, inicio: franja.inicio, fin: franja.fin, asignaturaID: id, aula: aula))
            }
        }
    }

    private func aplicar(_ c: Cambio) {
        guardarHistorial()
        conMuelle {
            if c.vaciar {
                almacen.datos.horario.removeAll { $0.dia == c.origen }
            } else {
                let clases = almacen.datos.horario.filter { $0.dia == c.origen }
                almacen.datos.horario.removeAll { c.destinos.contains($0.dia) }
                for d in c.destinos {
                    almacen.datos.horario += clases.map { Clase(dia: d, inicio: $0.inicio, fin: $0.fin, asignaturaID: $0.asignaturaID, aula: $0.aula) }
                }
            }
        }
    }

    private func tituloCambio(_ c: Cambio) -> String {
        let origen = Formato.nombreDia(iso: c.origen, estilo: .wide)
        if c.vaciar { return L("¿Vaciar el \(origen)?", "Clear \(origen)?", "Svuotare \(origen)?") }
        return L("¿Copiar el \(origen)?", "Copy \(origen)?", "Copiare \(origen)?")
    }

    private func mensajeCambio(_ c: Cambio) -> String {
        if c.vaciar { return L("Se quitan sus clases. Se puede deshacer.", "Its classes are removed. You can undo it.", "Si tolgono le sue lezioni. Si può annullare.") }
        let destinos = c.destinos.map { Formato.nombreDia(iso: $0, estilo: .wide) }.joined(separator: ", ")
        return L("Se sustituyen las clases de: \(destinos). Se puede deshacer.", "The classes of \(destinos) are replaced. You can undo it.",
                 "Si sostituiscono le lezioni di: \(destinos). Si può annullare.")
    }
}

private struct Paleta: View {
    var asignaturas: [Asignatura]
    @Binding var pincel: HorarioCielo.Pincel?

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(asignaturas) { a in
                        let elegida = pincel == .asignatura(a.id)
                        boton(a.nombre, simbolo: a.simbolo, color: a.color, elegida: elegida) {
                            conMuelle(Diseno.muelleRapido) { pincel = elegida ? nil : .asignatura(a.id) }
                        }
                    }
                    let goma = pincel == .goma
                    boton(L("Goma", "Eraser", "Gomma"), simbolo: "eraser", color: .gris, elegida: goma) {
                        conMuelle(Diseno.muelleRapido) { pincel = goma ? nil : .goma }
                    }
                }
                .padding(.horizontal, Diseno.margen)
                .padding(.vertical, 8)
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func boton(_ titulo: String, simbolo: String, color: ColorHoot, elegida: Bool, accion: @escaping () -> Void) -> some View {
        if elegida {
            Button(titulo, systemImage: simbolo, action: accion)
                .buttonStyle(.glassProminent)
                .tint(color.color)
                .accessibilityAddTraits(.isSelected)
        } else {
            Button(action: accion) {
                Label(titulo, systemImage: simbolo)
                    .foregroundStyle(Color.primary)
                    .labelStyle(PaletaEtiqueta(color: color))
            }
            .buttonStyle(.glass)
        }
    }
}

private struct PaletaEtiqueta: LabelStyle {
    var color: ColorHoot

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.foregroundStyle(color.color)
            configuration.title
        }
    }
}

struct MedidasRejilla {
    var dias: [Int]
    var franjas: [Franja]
    var inicio: Int
    var fin: Int
    var anchoHora: CGFloat
    var anchoDia: CGFloat
    var escala: CGFloat
    var cabecera: CGFloat = 32
    var ancho: CGFloat

    func x(_ columna: Int) -> CGFloat { anchoHora + CGFloat(columna) * anchoDia }
    func y(_ minuto: Int) -> CGFloat { cabecera + CGFloat(minuto - inicio) * escala }
    func alto(_ minutos: Int) -> CGFloat { CGFloat(minutos) * escala }

    func celda(_ p: CGPoint) -> (Int, Franja)? {
        let col = Int((p.x - anchoHora) / anchoDia)
        let minuto = inicio + Int((p.y - cabecera) / escala)
        guard p.x >= anchoHora, dias.indices.contains(col),
              let f = franjas.first(where: { !$0.esRecreo && $0.inicio <= minuto && minuto < $0.fin }) else { return nil }
        return (dias[col], f)
    }
}

struct RejillaSemana: View {
    var datos: DatosEscolares
    var ahora: Date
    var editando = false
    var pincel: HorarioCielo.Pincel?
    var alPintar: (Int, Franja) -> Void = { _, _ in }
    var alEmpezarTrazo: () -> Void = {}
    @ScaledMetric(relativeTo: .caption) private var anchoHora: CGFloat = 42
    @State private var lente: (clase: Clase, punto: CGPoint)?
    @State private var ultimaCelda: String?
    @State private var golpes = 0
    @GestureState private var manteniendo = false

    @ScaledMetric(relativeTo: .caption2) private var letraNombres: CGFloat = 11

    private var hoy: Int { DatosEscolares.diaISO(ahora) }
    private var minuto: Int { DatosEscolares.minutos(ahora) }

    var body: some View {
        GeometryReader { geo in
            let m = medidas(geo.size)
            ZStack(alignment: .topLeading) {
                fondoHoy(m)
                cabeceras(m)
                horas(m)
                if editando { huecos(m) }

                aguja(m)
                bloques(m)
                lenteVista(m)
            }

            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(editando ? pintar(m) : nil)
            .simultaneousGesture(editando ? nil : mirar(m))
        }
        .sensoryFeedback(.selection, trigger: lente?.clase.id)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: golpes)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Horario de la semana", "Weekly timetable", "Orario della settimana"))
        .accessibilityValue(Self.resumenAccesible(datos))
    }

    private func medidas(_ tam: CGSize) -> MedidasRejilla {
        let dias = datos.diasLectivosOrdenados
        let franjas = datos.franjas.sorted { $0.inicio < $1.inicio }
        let inicio = franjas.map(\.inicio).min() ?? 8 * 60
        let fin = franjas.map(\.fin).max() ?? 15 * 60
        let escala = (tam.height - 32 - 24) / CGFloat(max(1, fin - inicio))
        return MedidasRejilla(dias: dias, franjas: franjas, inicio: inicio, fin: fin, anchoHora: anchoHora,
                              anchoDia: (tam.width - anchoHora) / CGFloat(max(1, dias.count)), escala: escala, ancho: tam.width)
    }

    @ViewBuilder
    private func fondoHoy(_ m: MedidasRejilla) -> some View {
        if let i = m.dias.firstIndex(of: hoy), !editando {

            Color.clear
                .frame(width: m.anchoDia, height: m.cabecera + m.alto(m.fin - m.inicio) + 8)
                .glassEffect(.clear.tint(Color.acento.opacity(0.18)), in: RoundedRectangle(cornerRadius: Diseno.radioResalte, style: .continuous))
                .offset(x: m.x(i), y: -4)
        }
    }

    private func cabeceras(_ m: MedidasRejilla) -> some View {
        ForEach(Array(m.dias.enumerated()), id: \.element) { i, d in
            let esHoy = d == hoy && !editando
            Text(Formato.nombreDia(iso: d).conMayuscula)
                .font(.subheadline.weight(esHoy ? .bold : .semibold))
                .foregroundStyle(esHoy ? AnyShapeStyle(Color.white) : AnyShapeStyle(EstiloSecundario()))
                .frame(width: m.anchoDia, height: m.cabecera)
                .offset(x: m.x(i))
        }
    }

    private func horas(_ m: MedidasRejilla) -> some View {
        ForEach(m.franjas) { f in
            Text(f.esRecreo ? L("Recreo", "Break", "Ricreaz.") : Formato.hora(f.inicio))
                .font(.caption2.weight(f.esRecreo ? .regular : .medium).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(EstiloSecundario())
                .frame(width: m.anchoHora - 4, alignment: .leading)
                .offset(y: m.y(f.inicio))
        }
    }

    private func huecos(_ m: MedidasRejilla) -> some View {
        let libres: [(id: String, i: Int, f: Franja)] = m.franjas.filter { !$0.esRecreo }.flatMap { f in
            m.dias.indices.compactMap { i in
                datos.horario.contains { $0.dia == m.dias[i] && $0.inicio == f.inicio } ? nil : ("\(m.dias[i])-\(f.inicio)", i, f)
            }
        }
        return ForEach(libres, id: \.id) { _, i, f in
            RoundedRectangle(cornerRadius: Diseno.radioBloque, style: .continuous)
                .strokeBorder(.white.opacity(0.45), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                .frame(width: m.anchoDia - 5, height: m.alto(f.fin - f.inicio) - 4)
                .offset(x: m.x(i) + 2.5, y: m.y(f.inicio) + 2)
        }
    }

    private func bloques(_ m: MedidasRejilla) -> some View {
        let letra = letraComun(m)

        return ForEach(datos.horario.filter { m.dias.contains($0.dia) }) { c in
            BloqueClase(clase: c, asignatura: datos.asignatura(c.asignaturaID), esHoy: c.dia == hoy && !editando,
                        minuto: minuto, elegida: lente?.clase.id == c.id, letra: letra)
                .frame(width: m.anchoDia - 5, height: m.alto(c.fin - c.inicio) - 4)
                .offset(x: m.x(m.dias.firstIndex(of: c.dia) ?? 0) + 2.5, y: m.y(c.inicio) + 2)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
    }

    private func letraComun(_ m: MedidasRejilla) -> CGFloat {
        let fuente = UIFont.systemFont(ofSize: letraNombres, weight: .semibold)
        var masLarga: CGFloat = 0
        for c in datos.horario {
            for linea in NombreClase.lineas(datos.asignatura(c.asignaturaID)?.nombre ?? "") {
                masLarga = max(masLarga, (linea as NSString).size(withAttributes: [.font: fuente]).width)
            }
        }
        let cabe = m.anchoDia - 5 - 8
        return masLarga > cabe ? max(letraNombres * 0.68, letraNombres * cabe / masLarga) : letraNombres
    }

    @ViewBuilder
    private func aguja(_ m: MedidasRejilla) -> some View {

        let enClase = datos.horario.contains { $0.dia == hoy && $0.inicio <= minuto && minuto < $0.fin }
        if let i = m.dias.firstIndex(of: hoy), minuto >= m.inicio, minuto <= m.fin, !editando, !enClase {

            Capsule().fill(.white)
                .frame(width: m.anchoDia - 4, height: 3)
                .offset(x: m.x(i) + 2, y: m.y(minuto) - 1.5)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func lenteVista(_ m: MedidasRejilla) -> some View {
        if let lente {
            LenteClaseHorario(clase: lente.clase, asignatura: datos.asignatura(lente.clase.asignaturaID))
                .fixedSize()
                .position(x: min(max(lente.punto.x, 110), m.ancho - 110), y: max(28, lente.punto.y - 64))
                .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }

    private func pintar(_ m: MedidasRejilla) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if ultimaCelda == nil { alEmpezarTrazo() }
                guard pincel != nil, let (d, f) = m.celda(v.location) else { return }
                let clave = "\(d)-\(f.inicio)"
                guard clave != ultimaCelda else { return }
                ultimaCelda = clave
                golpes += 1
                alPintar(d, f)
            }
            .onEnded { _ in ultimaCelda = nil }
    }

    private func mirar(_ m: MedidasRejilla) -> some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($manteniendo) { _, estado, _ in estado = true }
            .onChanged { valor in
                guard case .second(true, let arrastre?) = valor else { return }
                guard let (d, f) = m.celda(arrastre.location),
                      let c = datos.horario.first(where: { $0.dia == d && $0.inicio == f.inicio }) else { return }
                if lente?.clase.id != c.id {
                    conMuelle(Diseno.muelleRapido) { lente = (c, arrastre.location) }
                } else {
                    lente = (c, arrastre.location)
                }
            }
            .onEnded { _ in conMuelle { lente = nil } }
    }

    static func resumenAccesible(_ datos: DatosEscolares) -> String {
        datos.diasLectivosOrdenados.map { d in
            let clases = datos.horario.filter { $0.dia == d }.sorted { $0.inicio < $1.inicio }
                .compactMap { c in datos.asignatura(c.asignaturaID).map { "\(Formato.hora(c.inicio)) \($0.nombre)" } }
            return Formato.nombreDia(iso: d, estilo: .wide) + ": " + (clases.isEmpty ? L("libre", "free", "libero") : clases.joined(separator: ", "))
        }.joined(separator: ". ")
    }
}

private struct BloqueClase: View {
    var clase: Clase
    var asignatura: Asignatura?
    var esHoy: Bool
    var minuto: Int
    var elegida: Bool
    var letra: CGFloat

    var body: some View {
        let color = asignatura?.color ?? .gris
        let ahoraMismo = esHoy && clase.inicio <= minuto && minuto < clase.fin

        let pasada = esHoy && minuto >= clase.fin
        VStack(spacing: 2) {
            Image(systemName: asignatura?.simbolo ?? "book.closed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(color.color)
                .opacity(pasada ? 0.5 : 1)
            NombreClase(nombre: asignatura?.nombre ?? "", letra: letra)
        }
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {

            ZStack(alignment: .top) {
                Color.clear
                    .glassEffect(.regular.tint(color.color.opacity(pasada ? 0.1 : (esHoy || elegida ? 0.5 : 0.32))),
                                 in: RoundedRectangle(cornerRadius: Diseno.radioBloque, style: .continuous))
                if ahoraMismo {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(color.color.opacity(0.3))
                            .frame(height: geo.size.height * CGFloat(minuto - clase.inicio) / CGFloat(max(1, clase.fin - clase.inicio)))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Diseno.radioBloque, style: .continuous))
                    .allowsHitTesting(false)
                }
            }
        }
        .overlay {
            if ahoraMismo {
                RoundedRectangle(cornerRadius: Diseno.radioBloque, style: .continuous).strokeBorder(color.color, lineWidth: 2)
            }
        }
        .scaleEffect(elegida ? 1.06 : 1)
    }
}

private struct NombreClase: View {
    var nombre: String

    var letra: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(Self.lineas(nombre).enumerated()), id: \.offset) { _, linea in
                Text(linea)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .font(.system(size: letra, weight: .semibold))
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nombre)
    }

    static func lineas(_ nombre: String) -> [String] {
        let palabras: [String] = nombre.split(separator: " ").map(String.init)
        guard palabras.count > 1, nombre.count > 9 else { return [nombre] }
        var mejor: [String] = [nombre]
        var peorMejor = Int.max
        for corte in 1..<palabras.count {
            let primera: String = palabras[0..<corte].joined(separator: " ")
            let segunda: String = palabras[corte..<palabras.count].joined(separator: " ")
            let peor = max(primera.count, segunda.count)

            if peor <= peorMejor {
                peorMejor = peor
                mejor = [primera, segunda]
            }
        }
        return mejor
    }
}

private struct LenteClaseHorario: View {
    var clase: Clase
    var asignatura: Asignatura?

    var body: some View {
        let aula = clase.aula.isEmpty ? (asignatura?.aula ?? "") : clase.aula
        HStack(spacing: 8) {
            Image(systemName: asignatura?.simbolo ?? "book.closed")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(asignatura?.color.color ?? .gray)
            VStack(alignment: .leading, spacing: 0) {
                Text(asignatura?.nombre ?? "")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text([ "\(Formato.hora(clase.inicio))–\(Formato.hora(clase.fin))", aula.isEmpty ? nil : L("Aula \(aula)", "Room \(aula)", "Aula \(aula)"),
                       (asignatura?.profesor).flatMap { $0.isEmpty ? nil : $0 } ].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(EstiloSecundario())
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: Capsule())
        .allowsHitTesting(false)
    }
}

private struct ListaHorario: View {
    @Binding var datos: DatosEscolares
    var editando: Bool
    var alCambiar: () -> Void

    var body: some View {
        List {
            ForEach(datos.diasLectivosOrdenados, id: \.self) { d in
                Section(Formato.nombreDia(iso: d, estilo: .wide).conMayuscula) {
                    ForEach(datos.franjas.sorted { $0.inicio < $1.inicio }.filter { !$0.esRecreo }) { f in
                        let c = datos.horario.first { $0.dia == d && $0.inicio == f.inicio }
                        let a = datos.asignatura(c?.asignaturaID)
                        if editando {

                            Menu {
                                Picker(selection: Binding(
                                    get: { c?.asignaturaID },
                                    set: { nueva in
                                        alCambiar()
                                        datos.horario.removeAll { $0.dia == d && $0.inicio == f.inicio }
                                        if let nueva {
                                            datos.horario.append(Clase(dia: d, inicio: f.inicio, fin: f.fin, asignaturaID: nueva,
                                                                       aula: datos.asignatura(nueva)?.aula ?? ""))
                                        }
                                    })) {
                                    Text(L("Libre", "Free", "Libero")).tag(UUID?.none)
                                    ForEach(datos.asignaturas) { x in Label(x.nombre, systemImage: x.simbolo).tag(UUID?.some(x.id)) }
                                } label: {
                                    Text(Formato.hora(f.inicio))
                                }
                                .pickerStyle(.inline)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(Formato.hora(f.inicio))
                                        .monospacedDigit()
                                        .foregroundStyle(Color.primary)

                                    Text(a?.nombre ?? L("Libre", "Free", "Libero"))
                                        .foregroundStyle(a?.color.color ?? Color.acento)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            LabeledContent {
                                Text(a?.nombre ?? L("Libre", "Free", "Libero"))
                            } label: {
                                Label(Formato.hora(f.inicio), systemImage: a?.simbolo ?? "minus")
                                    .foregroundStyle(a?.color.color ?? Color.texto2)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}
