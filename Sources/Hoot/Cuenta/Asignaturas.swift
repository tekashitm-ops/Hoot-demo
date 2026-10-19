import SwiftUI

enum SimbolosHoot {
    static let asignaturas = [
        "book.closed.fill", "x.squareroot", "function", "sum", "percent", "character.book.closed.fill",
        "text.book.closed.fill", "globe.europe.africa.fill", "globe.americas.fill", "building.columns.fill",
        "leaf.fill", "atom", "flask.fill", "testtube.2", "map.fill", "figure.run", "sportscourt.fill", "music.note",
        "paintpalette.fill", "pencil.and.ruler.fill", "gearshape.2.fill", "desktopcomputer", "cross.case.fill",
        "brain.head.profile", "person.2.fill", "scroll.fill", "theatermasks.fill", "camera.fill", "hammer.fill",
        "bubble.left.and.bubble.right.fill", "star.fill",
    ]

    static let actividades = [
        "soccerball", "basketball.fill", "tennis.racket", "figure.swim", "figure.run", "figure.martial.arts",
        "figure.dance", "pianokeys", "guitars.fill", "music.mic", "paintbrush.fill", "theatermasks.fill",
        "book.fill", "globe.europe.africa.fill", "laptopcomputer", "bicycle", "figure.equestrian.sports",
        "graduationcap.fill", "heart.fill", "star.fill",
    ]
}

struct AsignaturasVista: View {
    @Environment(Almacen.self) private var almacen
    @State private var borrando: Asignatura?
    @State private var nueva: Asignatura?

    var body: some View {
        @Bindable var almacen = almacen
        List {
            Section {
                ForEach($almacen.datos.asignaturas) { $a in
                    NavigationLink {
                        EditorAsignatura(asignatura: $a)
                    } label: {
                        HStack(spacing: 14) {
                            IconoAjustes(simbolo: a.simbolo, color: a.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(a.nombre)
                                if !a.profesor.isEmpty {
                                    Text(a.profesor).font(.subheadline).textoSecundario()
                                }
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) { borrando = a } label: {
                            Label(L("Borrar", "Delete", "Elimina"), systemImage: "trash")
                        }
                    }
                }
                .onMove { almacen.datos.asignaturas.move(fromOffsets: $0, toOffset: $1) }
            }
        }
        .navigationTitle(L("Asignaturas", "Subjects", "Materie"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let usados = Set(almacen.datos.asignaturas.map(\.color))
                    nueva = Asignatura(nombre: "", color: ColorHoot.allCases.first { !usados.contains($0) } ?? .azul, simbolo: "book.closed.fill")
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(L("Nueva asignatura", "New subject", "Nuova materia"))
            }
        }
        .sheet(item: $nueva) { a in
            NavigationStack {
                EditorAsignaturaNueva(asignatura: a)
            }
        }
        .confirmationDialog(
            L("¿Borrar \(borrando?.nombre ?? "")?", "Delete \(borrando?.nombre ?? "")?", "Eliminare \(borrando?.nombre ?? "")?"),
            isPresented: Binding(get: { borrando != nil }, set: { if !$0 { borrando = nil } }),
            titleVisibility: .visible,
            presenting: borrando
        ) { a in
            Button(L("Borrar", "Delete", "Elimina"), role: .destructive) {
                conMuelle {
                    almacen.datos.asignaturas.removeAll { $0.id == a.id }
                    almacen.datos.horario.removeAll { $0.asignaturaID == a.id }
                    almacen.datos.notas.removeAll { $0.asignaturaID == a.id }
                    for i in almacen.datos.tareas.indices where almacen.datos.tareas[i].asignaturaID == a.id {
                        almacen.datos.tareas[i].asignaturaID = nil
                    }
                }
            }
        } message: { _ in
            Text(L("También se quitan sus horas del horario y sus pruebas.", "Its timetable slots and tests are removed too.", "Si tolgono anche le sue ore dall'orario e le sue verifiche."))
        }
    }
}

struct EditorAsignaturaNueva: View {
    @State var asignatura: Asignatura
    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        EditorAsignatura(asignatura: $asignatura)
            .navigationTitle(L("Nueva asignatura", "New subject", "Nuova materia"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BotonCerrar { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        asignatura.nombre = asignatura.nombre.trimmingCharacters(in: .whitespaces)
                        conMuelle { almacen.datos.asignaturas.append(asignatura) }
                        cerrar()
                    }
                    .disabled(asignatura.nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
    }
}

struct EditorAsignatura: View {
    @Binding var asignatura: Asignatura
    @ScaledMetric(relativeTo: .largeTitle) private var ladoIcono = 72

    var body: some View {
        Form {
            Section {
                VStack(spacing: 14) {
                    IconoAsignatura(asignatura: asignatura, lado: ladoIcono)
                        .animation(Diseno.muelleRebote, value: asignatura.color)
                        .animation(Diseno.muelleRebote, value: asignatura.simbolo)
                    TextField(L("Nombre", "Name", "Nome"), text: $asignatura.nombre)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 10)
                        .background(Color.relleno, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.vertical, 8)
            }

            Section(L("Color", "Color", "Colore")) {
                SelectorColor(color: $asignatura.color)
            }

            Section(L("Símbolo", "Symbol", "Simbolo")) {
                SelectorSimbolo(simbolo: $asignatura.simbolo, opciones: SimbolosHoot.asignaturas, color: asignatura.color)
            }

            Section {
                TextField(L("Profesor o profesora", "Teacher", "Insegnante"), text: $asignatura.profesor)
                TextField(L("Aula", "Room", "Aula"), text: $asignatura.aula)
            }

            Section {
                MaterialesAsignatura(asignatura: $asignatura)
            } header: {
                Text(L("Para la mochila", "For the backpack", "Per lo zaino"))
            } footer: {
                Text(L("Entra en la mochila los días que hay esta asignatura.", "It goes in the backpack on days with this subject.", "Entra nello zaino i giorni in cui c'è questa materia."))
            }
        }
        .navigationTitle(asignatura.nombre.isEmpty ? L("Asignatura", "Subject", "Materia") : asignatura.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: asignatura.color)
        .sensoryFeedback(.selection, trigger: asignatura.simbolo)
    }
}

struct MaterialesAsignatura: View {
    @Binding var asignatura: Asignatura
    @State private var nuevoMaterial = ""
    @State private var tipoNuevo: TipoMaterial = .libro

    var body: some View {
        ForEach($asignatura.materiales) { $m in
            NavigationLink {
                EditorMaterial(material: $m)
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.nombre)
                        if !m.dias.isEmpty {
                            Text(m.dias.sorted().map { Formato.nombreDia(iso: $0) }.joined(separator: ", "))
                                .font(.subheadline)
                                .textoSecundario()
                        }
                    }
                } icon: {
                    Image(systemName: m.tipo.simbolo).foregroundStyle(asignatura.color.color)
                }
            }
        }
        .onDelete { asignatura.materiales.remove(atOffsets: $0) }
        HStack {
            Menu {
                Picker(L("Tipo", "Type", "Tipo"), selection: $tipoNuevo) {
                    ForEach(TipoMaterial.allCases) { Label($0.nombre, systemImage: $0.simbolo).tag($0) }
                }
            } label: {
                Image(systemName: tipoNuevo.simbolo)
                    .foregroundStyle(asignatura.color.color)
                    .zonaTactil()
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(L("Tipo de material", "Supply type", "Tipo di materiale"))
            .accessibilityValue(tipoNuevo.nombre)
            TextField(L("Añadir material", "Add supply", "Aggiungi materiale"), text: $nuevoMaterial)
                .onSubmit(anadirMaterial)
            Button(L("Añadir", "Add", "Aggiungi"), action: anadirMaterial)
                .buttonStyle(.borderless)
                .disabled(nuevoMaterial.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func anadirMaterial() {
        let t = nuevoMaterial.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        conMuelle { asignatura.materiales.append(Material(nombre: t, tipo: tipoNuevo)) }
        nuevoMaterial = ""
    }
}

struct EditorMaterial: View {
    @Binding var material: Material

    var body: some View {
        Form {
            Section {
                TextField(L("Nombre", "Name", "Nome"), text: $material.nombre)
                Picker(L("Tipo", "Type", "Tipo"), selection: $material.tipo) {
                    ForEach(TipoMaterial.allCases) { Label($0.nombre, systemImage: $0.simbolo).tag($0) }
                }
            }
            Section {
                ForEach(1...5, id: \.self) { d in
                    Toggle(Formato.nombreDia(iso: d, estilo: .wide).conMayuscula, isOn: Binding(
                        get: { material.dias.contains(d) },
                        set: { on in if on { material.dias.insert(d) } else { material.dias.remove(d) } }
                    ))
                }
            } header: {
                Text(L("Solo algunos días", "Only some days", "Solo alcuni giorni"))
            } footer: {
                Text(L("Sin marcar ninguno, se lleva todos los días que hay clase de la asignatura.",
                       "With none selected, it's packed every day the subject has class.",
                       "Se non ne scegli nessuno, si porta tutti i giorni in cui c'è lezione."))
            }
        }
        .navigationTitle(material.nombre)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SelectorColor: View {
    @Binding var color: ColorHoot
    @ScaledMetric(relativeTo: .body) private var lado = 34

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: lado + 10), spacing: 10)], spacing: 12) {
            ForEach(ColorHoot.allCases) { c in
                Button {
                    conMuelle(Diseno.muelleRapido) { color = c }
                } label: {
                    Circle()
                        .fill(c.color.gradient)
                        .frame(width: lado, height: lado)
                        .overlay {
                            if c == color {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(c.sobre)
                            }
                        }
                        .padding(3)
                        .overlay(Circle().strokeBorder(c == color ? c.color : .clear, lineWidth: 2))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(c.nombre)
                .accessibilityAddTraits(c == color ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
    }
}

struct SelectorSimbolo: View {
    @Binding var simbolo: String
    var opciones: [String]
    var color: ColorHoot
    @ScaledMetric(relativeTo: .body) private var lado = 40

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: lado + 6), spacing: 6)], spacing: 8) {
            ForEach(Array(opciones.enumerated()), id: \.element) { i, s in
                Button {
                    conMuelle(Diseno.muelleRapido) { simbolo = s }
                } label: {
                    Image(systemName: s)
                        .font(.title3)
                        .foregroundStyle(s == simbolo ? AnyShapeStyle(color.sobre) : AnyShapeStyle(EstiloSecundario()))
                        .frame(width: lado, height: lado)
                        .background(s == simbolo ? AnyShapeStyle(color.color.gradient) : AnyShapeStyle(Color.relleno), in: Circle())
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(L("Símbolo \(i + 1) de \(opciones.count)", "Symbol \(i + 1) of \(opciones.count)", "Simbolo \(i + 1) di \(opciones.count)"))
                .accessibilityAddTraits(s == simbolo ? .isSelected : [])
            }
        }
        .padding(.vertical, 6)
    }
}
