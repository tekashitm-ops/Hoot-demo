import SwiftUI
import UIKit

@Observable
final class Revision {
    static let compartida = Revision()

    struct Marca: Codable, Equatable {
        var bien: Bool
        var nota: String
        var titulo: String
        var pagina: String
        var fecha: Date
    }

    private(set) var marcas: [String: Marca] = [:]
    private static let clave = "hoot.desarrollo.revision"

    private init() {
        if ModoCapturas.activo {

            if ModoCapturas.revisionDeEjemplo { marcas = Self.ejemplo }
            return
        }
        if let data = UserDefaults.standard.data(forKey: Self.clave),
           let m = try? JSONDecoder().decode([String: Marca].self, from: data) {
            marcas = m
        }
    }

    func marcar(_ id: String, bien: Bool, nota: String = "", titulo: String, pagina: String) {
        marcas[id] = Marca(bien: bien, nota: bien ? "" : nota.trimmingCharacters(in: .whitespacesAndNewlines),
                           titulo: titulo, pagina: pagina, fecha: Date())
        guardar()
    }

    func quitar(_ id: String) {
        marcas[id] = nil
        guardar()
    }

    func borrarTodo() {
        marcas = [:]
        guardar()
    }

    private func guardar() {
        guard !ModoCapturas.activo, let data = try? JSONEncoder().encode(marcas) else { return }
        UserDefaults.standard.set(data, forKey: Self.clave)
    }

    func contar(_ ids: Set<String>) -> (bien: Int, mal: Int, faltan: Int) {
        let hechas = marcas.filter { ids.contains($0.key) }
        let bien = hechas.values.filter(\.bien).count
        return (bien, hechas.count - bien, ids.count - hechas.count)
    }

    func texto(_ ids: Set<String>) -> String {
        let c = contar(ids)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let fecha = Date().formatted(date: .numeric, time: .shortened)
        var lineas = [L("Revisión de Hoot \(version) · \(fecha)", "Hoot review \(version) · \(fecha)", "Revisione di Hoot \(version) · \(fecha)"), ""]
        let mal = marcas.filter { ids.contains($0.key) && !$0.value.bien }.values.sorted { ($0.pagina, $0.fecha) < ($1.pagina, $1.fecha) }
        lineas.append(L("❌ Mal (\(mal.count))", "❌ Wrong (\(mal.count))", "❌ Male (\(mal.count))"))
        for m in mal {
            let donde = m.pagina.isEmpty ? m.titulo : "\(m.pagina) › \(m.titulo)"
            lineas.append("• " + (m.nota.isEmpty ? donde : "\(donde): \(m.nota)"))
        }
        lineas.append("")
        lineas.append(L("✅ Bien: \(c.bien) · Sin revisar: \(c.faltan)", "✅ Fine: \(c.bien) · Not reviewed: \(c.faltan)", "✅ Bene: \(c.bien) · Da rivedere: \(c.faltan)"))
        return lineas.joined(separator: "\n")
    }

    private static var ejemplo: [String: Marca] {
        let ahora = Date()
        return [
            "principal.configuracion": Marca(bien: true, nota: "", titulo: L("Volver a configuración", "Back to Setup", "Torna alla configurazione"), pagina: "", fecha: ahora),
            "principal.cuenta": Marca(bien: true, nota: "", titulo: L("Cambiar de cuenta", "Switch account", "Cambia account"), pagina: "", fecha: ahora),
            "principal.faceid": Marca(bien: false, nota: L("No pide la cara", "It doesn't ask for my face", "Non chiede il volto"),
                                      titulo: L("Bloquear con Face ID", "Lock with Face ID", "Blocca con Face ID"), pagina: "", fecha: ahora),
        ]
    }
}

extension View {

    func revisable(_ id: String, _ titulo: String, en pagina: PaginaDesarrollo? = nil) -> some View {
        modifier(Revisable(id: id, titulo: titulo, pagina: pagina?.titulo ?? ""))
    }
}

private struct Revisable: ViewModifier {
    let id: String
    let titulo: String
    let pagina: String
    @State private var revision = Revision.compartida
    @State private var escribiendo = false
    @State private var nota = ""

    func body(content: Content) -> some View {
        let marca = revision.marcas[id]
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 10) {
                content
                if let marca {
                    Image(systemName: marca.bien ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(marca.bien ? Color.hecho : Color.urgente)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                        .accessibilityLabel(marca.bien ? L("Revisado: bien", "Reviewed: fine", "Rivisto: bene") : L("Revisado: mal", "Reviewed: wrong", "Rivisto: male"))
                }
            }
            if let marca, !marca.bien, !marca.nota.isEmpty {
                Text(marca.nota)
                    .font(.footnote)
                    .foregroundStyle(Color.urgente)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { marcar(bien: true) } label: {
                Label(L("Bien", "Fine", "Bene"), systemImage: "checkmark")
            }
            .tint(Color.hecho)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button { pedirNota() } label: {
                Label(L("Mal", "Wrong", "Male"), systemImage: "xmark")
            }
            .tint(Color.urgente)
            if marca != nil {
                Button { quitar() } label: {
                    Label(L("Quitar", "Clear", "Togli"), systemImage: "arrow.uturn.backward")
                }
                .tint(.gray)
            }
        }
        .contextMenu {
            Button(L("Bien", "Fine", "Bene"), systemImage: "checkmark.circle") { marcar(bien: true) }
            Button(L("Mal…", "Wrong…", "Male…"), systemImage: "xmark.circle") { pedirNota() }
            if marca != nil {
                Button(L("Quitar la marca", "Clear the Mark", "Togli il segno"), systemImage: "arrow.uturn.backward") { quitar() }
            }
        }
        .alert(L("¿Qué falla?", "What's wrong?", "Cosa non va?"), isPresented: $escribiendo) {
            TextField(L("Lo que falla", "What's wrong", "Cosa non va"), text: $nota)
            Button(L("Guardar", "Save", "Salva")) { marcar(bien: false, nota: nota) }
            Button(L("Sin nota", "No Note", "Senza nota"), role: .cancel) { marcar(bien: false, nota: "") }
        } message: {
            Text(titulo)
        }
        .sensoryFeedback(trigger: marca) { _, nueva in
            guard let nueva else { return .impact(weight: .light) }
            return nueva.bien ? .success : .error
        }
    }

    private func marcar(bien: Bool, nota: String = "") {
        withAnimation(Diseno.muelleRapido) {
            revision.marcar(id, bien: bien, nota: nota, titulo: titulo, pagina: pagina)
        }
    }

    private func pedirNota() {
        nota = revision.marcas[id].flatMap { $0.bien ? nil : $0.nota } ?? ""
        escribiendo = true
    }

    private func quitar() {
        withAnimation(Diseno.muelleRapido) { revision.quitar(id) }
    }
}

struct SeccionRevision: View {
    @Environment(Almacen.self) private var almacen
    @State private var revision = Revision.compartida
    @State private var borrando = false
    @State private var copiado = false

    var body: some View {
        let ids = CatalogoRevision.ids(esFamilia: almacen.esFamilia)
        let c = revision.contar(ids)
        Section {
            HStack(alignment: .top, spacing: 0) {
                cifra(c.bien, L("Bien", "Fine", "Bene"), "checkmark.circle.fill", Color.hecho)
                cifra(c.mal, L("Mal", "Wrong", "Male"), "xmark.circle.fill", Color.urgente)
                cifra(c.faltan, L("Sin revisar", "Not reviewed", "Da rivedere"), "circle.dashed", Color.texto2)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            Button {
                UIPasteboard.general.string = revision.texto(ids)
                withAnimation(Diseno.muelleRapido) { copiado = true }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation(Diseno.muelleRapido) { copiado = false }
                }
            } label: {
                Label(copiado ? L("Copiado", "Copied", "Copiato") : L("Copiar lo que está mal", "Copy What's Wrong", "Copia cosa non va"),
                      systemImage: copiado ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
            }
            .disabled(c.mal == 0)
            Button(L("Borrar todas las marcas", "Clear All Marks", "Cancella tutti i segni"), role: .destructive) { borrando = true }
                .disabled(c.bien + c.mal == 0)
        } header: {
            Text(L("Revisión", "Review", "Revisione"))
        } footer: {
            Text(L("Desliza cada prueba: a la derecha ✅ bien; a la izquierda ❌ mal, con lo que falla.",
                   "Swipe each test: right for ✅ fine; left for ❌ wrong, with what fails.",
                   "Scorri ogni prova: a destra ✅ bene; a sinistra ❌ male, con cosa non va."))
        }
        .sensoryFeedback(.success, trigger: copiado) { _, nuevo in nuevo }
        .confirmationDialog(L("¿Borrar todas las marcas?", "Clear all marks?", "Cancellare tutti i segni?"), isPresented: $borrando, titleVisibility: .visible) {
            Button(L("Borrar las marcas", "Clear Marks", "Cancella i segni"), role: .destructive) {
                withAnimation(Diseno.muelleRapido) { revision.borrarTodo() }
            }
        } message: {
            Text(L("Todas las pruebas vuelven a estar sin revisar.", "Every test goes back to not reviewed.", "Tutte le prove tornano da rivedere."))
        }
    }

    private func cifra(_ n: Int, _ nombre: String, _ simbolo: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: simbolo)
                .font(.title3)
                .foregroundStyle(color)
            Text("\(n)")
                .font(.title2.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
            Text(nombre)
                .font(.caption)
                .textoSecundario()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
