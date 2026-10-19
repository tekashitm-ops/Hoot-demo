import SwiftUI

struct ElegirTemas: View {
    enum Para: Equatable { case repasito, examen }
    var para: Para
    var asignaturaInicial: UUID?

    var empezar: (PeticionRepaso) -> Void

    @Environment(Almacen.self) private var almacen
    @Environment(\.dismiss) private var cerrar
    @State private var elegidos: Set<UUID> = []
    @State private var modo: ModoPrueba = .pagina
    @State private var asignaturaID: UUID?
    @State private var listo = false

    private var temas: [Biblioteca.Entrada] { almacen.datos.biblioteca() }

    private static func conMaterial(_ t: Tema) -> Bool { !t.textoLeido.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        let grupos = Biblioteca.porAsignatura(temas)
        let visibles = para == .examen ? grupos.filter { $0.asignaturaID == asignaturaID } : grupos
        NavigationStack {
            Form {
                if DisponibilidadIA.actual != .lista {

                    Section {
                        Label(DisponibilidadIA.actual.mensaje, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(EstiloAviso(color: .pronto))
                    }
                    .filaTenida()
                }
                if para == .examen {
                    Section {
                        Picker(L("Cómo", "How", "Come"), selection: $modo) {
                            Text(L("Escrito", "Written", "Scritto")).tag(ModoPrueba.pagina)
                            Text(L("Oral", "Oral", "Orale")).tag(ModoPrueba.oral)
                            Text(L("Tarjetas", "Cards", "Schede")).tag(ModoPrueba.tarjetas)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                    Section {
                        Picker(selection: $asignaturaID) {
                            ForEach(grupos.compactMap { g in almacen.datos.asignatura(g.asignaturaID) }) { a in
                                Label(a.nombre, systemImage: a.simbolo).tag(Optional(a.id))
                            }
                        } label: {
                            Text(L("Asignatura", "Subject", "Materia"))
                        }
                        .pickerStyle(.menu)
                    }
                    .filaTenida()
                }
                ForEach(Array(visibles.enumerated()), id: \.offset) { _, g in
                    let asig = almacen.datos.asignatura(g.asignaturaID)
                    let posibles = g.temas.filter { Self.conMaterial($0.tema) }.map(\.id)
                    Section {
                        ForEach(g.temas) { e in fila(e) }
                    } header: {
                        HStack {
                            Text(asig?.nombre ?? L("Sin asignatura", "No subject", "Senza materia")).foregroundStyle(EstiloSecundario())
                            Spacer()
                            if posibles.count > 1 {
                                let todos = Set(posibles).isSubset(of: elegidos)
                                Button(todos ? L("Ninguno", "None", "Nessuno") : L("Todos", "All", "Tutti")) {
                                    conMuelle(Diseno.muelleRapido) {
                                        if todos { elegidos.subtract(posibles) } else { elegidos.formUnion(posibles) }
                                    }
                                }
                                .font(.subheadline.weight(.semibold))
                                .textCase(nil)
                            }
                        }
                    }
                    .filaTenida()
                }
            }
            .tenidaDelCielo(hoja: true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle(para == .examen ? L("Hazme un examen", "Quiz Me", "Fammi un compito") : L("Repasito", "Quick Review", "Ripassino"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { BotonCerrar { cerrar() } }
            }
            .safeAreaBar(edge: .bottom) {
                Button { empezarYa(elegidosVisibles(visibles)) } label: {
                    HStack {
                        Text(L("Empezar", "Start", "Inizia"))
                        Spacer()
                        Text(resumen(elegidosVisibles(visibles).count)).monospacedDigit().contentTransition(.numericText())
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .botonAmbar()
                .controlSize(.large)
                .disabled(elegidosVisibles(visibles).isEmpty || DisponibilidadIA.actual != .lista)
                .padding(.horizontal, Diseno.margen)
                .padding(.bottom, 8)
            }
        }
        .presentationDetents([.large])
        .presentationBackground { FondoHojaTenida() }
        .sensoryFeedback(.selection, trigger: elegidos)
        .onAppear {
            guard !listo else { return }
            listo = true
            modo = almacen.ajustes.modoPrueba
            asignaturaID = asignaturaInicial ?? grupos.first(where: { g in g.temas.contains { Self.conMaterial($0.tema) } })?.asignaturaID
                ?? grupos.first?.asignaturaID

            if ModoCapturas.activo {
                elegidos = Set(visiblesIniciales(grupos).prefix(3))
            }
        }

        .onChange(of: asignaturaID) { antes, _ in if para == .examen && antes != nil { elegidos = [] } }
    }

    private func visiblesIniciales(_ grupos: [(asignaturaID: UUID?, temas: [Biblioteca.Entrada])]) -> [UUID] {
        let g = para == .examen ? grupos.filter { $0.asignaturaID == asignaturaID } : Array(grupos.prefix(1))
        return g.flatMap(\.temas).filter { Self.conMaterial($0.tema) }.map(\.id)
    }

    private func fila(_ e: Biblioteca.Entrada) -> some View {
        let cal = calendarioActual
        let puede = Self.conMaterial(e.tema)
        let si = elegidos.contains(e.id)
        return Button {
            conMuelle(Diseno.muelleRapido) { if si { elegidos.remove(e.id) } else { elegidos.insert(e.id) } }
        } label: {
            HStack(spacing: 12) {
                Luna(parte: e.tema.luna(cal: cal).fraccion, tamano: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(e.tema.nombre).font(.headline).foregroundStyle(.white)
                    Text(puede ? EstadoLuna.texto(e.tema, cal: cal) : L("Sin fotos todavía", "No photos yet", "Ancora senza foto"))
                        .font(.subheadline)
                        .foregroundStyle(EstiloSecundario())
                }
                Spacer(minLength: 8)
                Image(systemName: si ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(si ? AnyShapeStyle(Color.ambar) : AnyShapeStyle(EstiloSecundario()))
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!puede)
        .opacity(puede ? 1 : 0.5)
        .accessibilityAddTraits(si ? .isSelected : [])
    }

    private func elegidosVisibles(_ visibles: [(asignaturaID: UUID?, temas: [Biblioteca.Entrada])]) -> Set<UUID> {
        elegidos.intersection(Set(visibles.flatMap(\.temas).map(\.id)))
    }

    private func porTema(_ n: Int) -> Int {
        para == .repasito ? Biblioteca.porTemaRepasito(n) : FaseLuna.minimoRespuestas
    }

    private func resumen(_ n: Int) -> String {
        let preguntas = n * porTema(n)
        if para == .examen {
            return n == 1 ? L("1 tema · \(preguntas) preguntas", "1 topic · \(preguntas) questions", "1 argomento · \(preguntas) domande")
                          : L("\(n) temas · \(preguntas) preguntas", "\(n) topics · \(preguntas) questions", "\(n) argomenti · \(preguntas) domande")
        }
        return L("\(preguntas) preguntas", "\(preguntas) questions", "\(preguntas) domande")
    }

    private func empezarYa(_ elegidos: Set<UUID>) {

        let ids = temas.map(\.id).filter { elegidos.contains($0) }
        guard !ids.isEmpty else { return }
        empezar(PeticionRepaso(temaIDs: ids, mezclado: ids.count > 1, porTema: porTema(ids.count), modo: para == .examen ? modo : nil))
        cerrar()
    }
}
