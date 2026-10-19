import SwiftUI

struct NuevoTema: Identifiable {
    let id = UUID()
    var nombre = ""
    var asignaturaID: UUID?
}

struct ApuntarTema: View {
    var asignaturaInicial: UUID?

    var nombreInicial = ""

    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var nombre = ""
    @State private var asignaturaID: UUID?
    @State private var temaID = UUID()
    @State private var material: ControlMaterial
    @State private var descartando = false
    @FocusState private var escribiendo: Bool

    init(asignaturaInicial: UUID? = nil, nombreInicial: String = "") {
        self.asignaturaInicial = asignaturaInicial
        self.nombreInicial = nombreInicial
        _nombre = State(initialValue: nombreInicial)
        let id = UUID()
        _temaID = State(initialValue: id)
        _material = State(initialValue: ControlMaterial(temaID: id))
    }

    private var creado: Bool { almacen.datos.tema(temaID) != nil }
    private var valeNombre: Bool { !nombre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $asignaturaID) {
                        ForEach(almacen.datos.asignaturas) { a in
                            Label(a.nombre, systemImage: a.simbolo).tag(Optional(a.id))
                        }
                    } label: {
                        Text(L("Asignatura", "Subject", "Materia"))
                    }
                    .pickerStyle(.menu)
                    TextField(text: $nombre, prompt: Indicacion.texto(L("Por ejemplo, Egipto", "For example, Ancient Egypt", "Per esempio, gli Egizi"))) {
                        Text(L("Nombre del tema", "Topic name", "Nome dell'argomento"))
                    }
                    .textInputAutocapitalization(.sentences)
                    .focused($escribiendo)
                    .submitLabel(.done)
                }
                .filaTenida()
                if almacen.datos.asignaturas.isEmpty {

                    Section {
                        Text(L("Primero añade tus asignaturas en Cuenta › Asignaturas.", "First add your subjects in Account › Subjects.",
                               "Prima aggiungi le tue materie in Account › Materie."))
                            .foregroundStyle(EstiloSecundario())
                        Button(L("Abrir Cuenta", "Open Account", "Apri Account")) {
                            cerrar()

                            Task {
                                try? await Task.sleep(for: .milliseconds(500))
                                almacen.mostrandoCuenta = true
                            }
                        }
                    }
                    .filaTenida()
                } else if valeNombre && asignaturaID != nil {
                    SeccionMaterial(control: material, alAnadir: crearSiFalta)
                } else {
                    Section {
                        Text(L("Elige la asignatura y ponle nombre para añadir las fotos.", "Pick the subject and name it to add photos.",
                               "Scegli la materia e dagli un nome per aggiungere le foto."))
                            .foregroundStyle(EstiloSecundario())
                            .filaTenida()
                    }
                }
            }
            .presentacionesMaterial(material)
            .tenidaDelCielo(hoja: true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle(L("Nuevo tema", "New Topic", "Nuovo argomento"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BotonCerrar { salir() }
                }
            }
            .safeAreaBar(edge: .bottom) {
                Button {
                    guardar()
                } label: {
                    Text(L("Guardar", "Save", "Salva")).frame(maxWidth: .infinity)
                }
                .botonAmbar()
                .controlSize(.large)
                .disabled(!valeNombre || asignaturaID == nil || material.leyendo)
                .padding(.horizontal, Diseno.margen)
                .padding(.bottom, 8)
            }
            .confirmationDialog(L("¿Tirar este tema?", "Discard this topic?", "Buttare questo argomento?"), isPresented: $descartando,
                                titleVisibility: .visible) {
                Button(L("Tirar el tema", "Discard Topic", "Butta l'argomento"), role: .destructive) {
                    almacen.datos.borrarTema(temaID)
                    cerrar()
                }
                Button(L("Guardarlo", "Keep It", "Tienilo")) { guardar() }
            } message: {
                Text(L("Se pierden las fotos que ya ha leído Hoot.", "The photos Hoot already read will be lost.",
                       "Si perdono le foto che Hoot ha già letto."))
            }
        }
        .presentationDetents([.large])
        .presentationBackground { FondoHojaTenida() }
        .interactiveDismissDisabled(creado)
        .onAppear {
            if asignaturaID == nil { asignaturaID = asignaturaInicial ?? Self.asignaturaDeAhora(almacen.datos) }
            if !ModoCapturas.activo { escribiendo = true }
        }
        .onChange(of: nombre) { _, n in
            guard creado, valeNombre else { return }
            almacen.datos.cambiarTema(temaID) { $0.nombre = n.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        .onChange(of: asignaturaID) { _, a in
            if creado { almacen.datos.cambiarAsignatura(deTema: temaID, a: a) }
        }
    }

    private func crearSiFalta() {
        guard !creado, valeNombre, let asignaturaID else { return }
        almacen.datos.apuntarTemaSuelto(id: temaID, nombre: nombre, asignaturaID: asignaturaID)
    }

    private func guardar() {
        crearSiFalta()
        cerrar()
    }

    private func salir() {

        if creado && (material.leyendo || almacen.datos.tema(temaID).map({ !$0.fuentes.isEmpty }) == true) {
            descartando = true
        } else {
            if creado { almacen.datos.borrarTema(temaID) }
            cerrar()
        }
    }

    static func asignaturaDeAhora(_ datos: DatosEscolares, ahora: Date = Reloj.ahora) -> UUID? {
        let m = DatosEscolares.minutos(ahora)
        let clases = datos.clases(en: ahora)
        return (clases.last { $0.inicio <= m } ?? clases.first)?.asignaturaID ?? datos.asignaturas.first?.id
    }
}
