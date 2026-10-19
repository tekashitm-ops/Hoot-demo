import SwiftUI

struct TuCielo: View {
    @Environment(Almacen.self) private var almacen
    @State private var elegida: UUID??

    var body: some View {
        let cielo = CieloDelCurso(datos: almacen.datos, cal: calendarioActual)
        let seleccion = elegida.map { id in cielo.constelaciones.first { $0.id == id } } ?? cielo.constelaciones.first
        ZStack(alignment: .top) {
            CieloDeNoche()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(L("Tu cielo", "Your sky", "Il tuo cielo"))
                        .font(.largeTitle.weight(.heavy))
                        .fontDesign(.rounded)
                        .foregroundStyle(.white)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, -12)
                    Text(cielo.encendidas == 1 ? L("1 estrella este curso", "1 star this year", "1 stella quest'anno")
                                               : L("\(cielo.encendidas) estrellas este curso", "\(cielo.encendidas) stars this year",
                                                   "\(cielo.encendidas) stelle quest'anno"))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.86))
                    if cielo.constelaciones.isEmpty {
                        HootDice(frase: L("Aquí saldrá cada tema que sepas. De momento, cielo despejado.",
                                          "Every topic you know will show up here. Clear skies for now.",
                                          "Qui comparirà ogni argomento che sai. Per ora, cielo sereno."),
                                 gesto: .aullando, tamano: 120, paraguasSiLlueve: false)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 22) {
                        ForEach(cielo.constelaciones) { c in
                            Button {
                                conMuelle { elegida = .some(c.id) }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    ConstelacionTemas(cuantas: max(c.estrellas.count, 1), encendidas: c.encendidas)
                                        .frame(height: 90)
                                        .opacity(seleccion?.id == c.id ? 1 : 0.75)
                                    Text((c.asignatura?.nombre ?? L("Sin asignatura", "No subject", "Senza materia")).uppercased(with: localeActual))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(seleccion?.id == c.id ? Color.ambar : .white.opacity(0.8))
                                        .lineLimit(1)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(EstiloPulsar())
                            .accessibilityLabel(L("\(c.asignatura?.nombre ?? ""): \(c.encendidas) de \(c.estrellas.count) temas",
                                                  "\(c.asignatura?.nombre ?? ""): \(c.encendidas) of \(c.estrellas.count) topics",
                                                  "\(c.asignatura?.nombre ?? ""): \(c.encendidas) di \(c.estrellas.count) argomenti"))
                        }
                    }
                    if let c = seleccion {
                        TarjetaCielo(titulo: c.asignatura?.nombre ?? L("Sin asignatura", "No subject", "Senza materia"),
                                     simbolo: c.asignatura?.simbolo ?? "sparkles") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 7)], alignment: .leading, spacing: 7) {
                                ForEach(c.estrellas) { t in
                                    let sabe = t.luna(cal: calendarioActual) == .llena
                                    Label(t.nombre, systemImage: sabe ? "star.fill" : "star")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(sabe ? AnyShapeStyle(Color.white) : AnyShapeStyle(EstiloSecundario()))
                                        .labelStyle(EstrellaEtiqueta(sabe: sabe))
                                        .lineLimit(2)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(.white.opacity(sabe ? 0.14 : 0.07), in: Capsule())
                                }
                            }
                            .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.horizontal, Diseno.margen)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .environment(\.colorScheme, .dark)
        .environment(\.sobreCielo, true)
        .environment(\.pestanaVisible, false)

        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EstrellaEtiqueta: LabelStyle {
    var sabe: Bool
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.foregroundStyle(sabe ? Color.ambar : .white.opacity(0.5)).font(.caption)
            configuration.title
        }
    }
}

struct TarjetaSorpresa: View {
    var prueba: Prueba
    var asignatura: Asignatura?

    var body: some View {
        TarjetaCielo(titulo: asignatura?.nombre ?? L("La última prueba", "The last test", "L'ultima verifica"), simbolo: "questionmark.bubble") {
            VStack(alignment: .leading, spacing: 10) {
                Text(FrasesHoot.despuesPrueba())
                    .font(.headline)
                    .foregroundStyle(.white)
                SorpresaChips(prueba: prueba)
            }
            .padding(.vertical, 12)
        }
    }
}
