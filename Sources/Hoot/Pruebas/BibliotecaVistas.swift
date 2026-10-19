import SwiftUI

struct FilaTemaBiblioteca: View {
    var entrada: Biblioteca.Entrada
    var conAsignatura = false
    @Environment(Almacen.self) private var almacen

    var body: some View {
        let cal = calendarioActual
        let datos = almacen.datos
        let prueba = entrada.pruebaID.flatMap { id in datos.pruebas.first { $0.id == id } }
        let partes: [String?] = [
            conAsignatura ? datos.asignatura(entrada.asignaturaID)?.nombre : nil,
            EstadoLuna.texto(entrada.tema, cal: cal),
            prueba.map { p in
                p.diasQueFaltan(desde: Reloj.ahora, cal: cal) >= 0
                    ? L("\(p.tipo.nombre) \(Formato.diaEnFrase(p.fecha))", "\(p.tipo.nombre) \(Formato.diaEnFrase(p.fecha))", "\(p.tipo.nombre) \(Formato.diaEnFrase(p.fecha))")
                    : nil
            } ?? nil,
        ]
        HStack(spacing: 12) {
            Luna(parte: entrada.tema.luna(cal: cal).fraccion, tamano: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(entrada.tema.nombre).font(.headline).foregroundStyle(.white)
                Text(partes.compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(EstiloSecundario())
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(EstiloSecundario())
                .accessibilityHidden(true)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct FilaAsignaturaBiblioteca: View {
    var asignatura: Asignatura?
    var temas: [Biblioteca.Entrada]

    var body: some View {
        let cal = calendarioActual
        let llenas = temas.filter { $0.tema.luna(cal: cal) == .llena }.count
        HStack(spacing: 12) {
            IconoAsignatura(asignatura: asignatura, lado: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(asignatura?.nombre ?? L("Sin asignatura", "No subject", "Senza materia")).font(.headline).foregroundStyle(.white)
                Text(temas.count == 1 ? L("1 tema · \(llenas) llena", "1 topic · \(llenas) full", "1 argomento · \(llenas) piena")
                                      : L("\(temas.count) temas · \(llenas) llenas", "\(temas.count) topics · \(llenas) full", "\(temas.count) argomenti · \(llenas) piene"))
                    .font(.subheadline)
                    .foregroundStyle(EstiloSecundario())
            }
            Spacer(minLength: 8)
            FilaLunas(partes: temas.prefix(5).map { $0.tema.luna(cal: cal).fraccion }, tamano: 14, hueco: 2)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(EstiloSecundario())
                .accessibilityHidden(true)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct AsignaturaTemasVista: View {
    var asignaturaID: UUID?

    @Environment(Almacen.self) private var almacen
    @State private var temaAbierto: UUIDIdentificable?
    @State private var apuntando = false
    @State private var examen = false
    @State private var pendiente: PeticionRepaso?
    @State private var repaso: PeticionRepaso?
    @State private var borrando: Biblioteca.Entrada?

    var body: some View {
        let datos = almacen.datos
        let asig = datos.asignatura(asignaturaID)
        let temas = datos.biblioteca().filter { $0.asignaturaID == asignaturaID }
        let cal = calendarioActual
        List {
            Section {
                HStack(spacing: 14) {
                    IconoAsignatura(asignatura: asig, lado: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        let llenas = temas.filter { $0.tema.luna(cal: cal) == .llena }.count
                        Text(temas.count == 1 ? L("1 tema", "1 topic", "1 argomento") : L("\(temas.count) temas", "\(temas.count) topics", "\(temas.count) argomenti"))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text(llenas == 1 ? L("1 en luna llena", "1 at full moon", "1 in luna piena")
                                         : L("\(llenas) en luna llena", "\(llenas) at full moon", "\(llenas) in luna piena"))
                            .font(.subheadline)
                            .foregroundStyle(EstiloSecundario())
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
            }
            if temas.isEmpty {
                Section {
                    Text(L("Aún no hay temas. Apunta el primero con «+».", "No topics yet. Add the first one with “+”.",
                           "Ancora nessun argomento. Aggiungi il primo con «+»."))
                        .foregroundStyle(EstiloSecundario())
                }
                .filaTenida()
            } else {
                Section {
                    ForEach(temas) { e in
                        Button { temaAbierto = UUIDIdentificable(id: e.id) } label: { FilaTemaBiblioteca(entrada: e) }
                            .buttonStyle(.plain)
                            .swipeActions {

                                Button { borrando = e } label: {
                                    Label(L("Borrar", "Delete", "Elimina"), systemImage: "trash")
                                }
                                .tint(.red)
                            }
                            .contextMenu {
                                if !e.tema.textoLeido.isEmpty {
                                    Button { repaso = PeticionRepaso(temaIDs: [e.id], mezclado: false) } label: {
                                        Label(L("Repasar", "Review", "Ripassa"), systemImage: "play.fill")
                                    }
                                }
                                Button(role: .destructive) { borrando = e } label: { Label(L("Borrar", "Delete", "Elimina"), systemImage: "trash") }
                            }
                    }
                } header: {
                    Text(L("Temas", "Topics", "Argomenti")).foregroundStyle(EstiloSecundario())
                }
                .filaTenida()
            }
        }
        .tenidaDelCielo()
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle(asig?.nombre ?? L("Sin asignatura", "No subject", "Senza materia"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { apuntando = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel(L("Apuntar un tema", "Add a topic", "Aggiungi un argomento"))
            }
        }
        .safeAreaBar(edge: .bottom) {
            if temas.contains(where: { !$0.tema.textoLeido.isEmpty }) {
                Button { examen = true } label: {
                    Label(L("Hazme un examen", "Quiz Me", "Fammi un compito"), systemImage: "sparkles").font(.headline).frame(maxWidth: .infinity)
                }
                .botonAmbar()
                .controlSize(.large)
                .padding(.horizontal, Diseno.margen)
                .padding(.bottom, 8)
            }
        }
        .sheet(item: $temaAbierto) { t in
            TemaHoja(temaID: t.id) { ids in
                temaAbierto = nil
                repaso = PeticionRepaso(temaIDs: ids, mezclado: false)
            }
        }
        .sheet(isPresented: $apuntando) { ApuntarTema(asignaturaInicial: asignaturaID) }
        .sheet(isPresented: $examen, onDismiss: { if let p = pendiente { pendiente = nil; repaso = p } }) {
            ElegirTemas(para: .examen, asignaturaInicial: asignaturaID) { pendiente = $0 }
        }
        .fullScreenCover(item: $repaso) { r in
            RepasoTemas(peticion: r) { repaso = nil }
        }
        .confirmationDialog(L("¿Borrar «\(borrando?.tema.nombre ?? "")»?", "Delete “\(borrando?.tema.nombre ?? "")”?", "Eliminare «\(borrando?.tema.nombre ?? "")»?"),
                            isPresented: Binding(get: { borrando != nil }, set: { if !$0 { borrando = nil } }),
                            titleVisibility: .visible, presenting: borrando) { e in
            Button(L("Borrar el tema", "Delete Topic", "Elimina l'argomento"), role: .destructive) {
                conMuelle { almacen.datos.borrarTema(e.id) }
            }
        } message: { _ in
            Text(L("Se borran sus fotos y su luna. No se puede deshacer.", "Its photos and its moon are deleted. This can't be undone.",
                   "Si cancellano le sue foto e la sua luna. Non si può annullare."))
        }
    }
}
