import SwiftUI

struct HojaActividad: View {
    var actividad: Actividad

    var body: some View {
        if let cita = Calendarios.compartido.citaDe[actividad.id] {
            DetalleCita(cita: cita, actividad: actividad)
        } else {
            EditorActividad(actividad: actividad, esNueva: false)
        }
    }
}

struct DetalleCita: View {
    var cita: EventoExterno
    var actividad: Actividad
    @Environment(\.dismiss) private var cerrar
    @Environment(\.openURL) private var abrirURL

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: actividad.simbolo)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(actividad.color.sobre)
                            .frame(width: 40, height: 40)
                            .background(actividad.color.color.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityHidden(true)
                        Text(actividad.titulo)
                            .font(.title3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    LabeledContent(L("Cuándo", "When", "Quando")) {
                        Text(cuando).multilineTextAlignment(.trailing).foregroundStyle(EstiloSecundario())
                    }
                    if !cita.lugar.isEmpty {
                        LabeledContent(L("Lugar", "Location", "Luogo")) {
                            Text(cita.lugar).multilineTextAlignment(.trailing).foregroundStyle(EstiloSecundario())
                        }
                    }
                    LabeledContent(L("Calendario", "Calendar", "Calendario")) {
                        Text(deDonde).multilineTextAlignment(.trailing).foregroundStyle(EstiloSecundario())
                    }
                }
                .filaTenida()

                let notas = cita.notas.trimmingCharacters(in: .whitespacesAndNewlines)
                if !notas.isEmpty {
                    Section {
                        Text(notas)
                            .font(.subheadline)
                            .lineLimit(12)
                            .textSelection(.enabled)
                    } header: {
                        Text(L("Notas", "Notes", "Note")).foregroundStyle(EstiloSecundario())
                    }
                    .filaTenida()
                }

                if let destino {
                    Section {
                        Button {
                            abrirURL(destino.url)
                        } label: {
                            FilaAjuste(simbolo: destino.simbolo, color: destino.color, titulo: destino.titulo)
                        }
                    } footer: {
                        Text(cita.origen == .teams
                             ? L("Se cambia en Teams o en Outlook.", "You can change it in Teams or Outlook.", "Si modifica in Teams o in Outlook.")
                             : L("Se cambia en la app Calendario.", "You can change it in the Calendar app.", "Si modifica nell'app Calendario."))
                            .foregroundStyle(EstiloSecundario())
                    }
                    .filaTenida()
                }
            }
            .tenidaDelCielo(hoja: true)
            .toolbarColorScheme(.dark, for: .navigationBar)

            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BotonCerrar { cerrar() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground { FondoHojaTenida() }
    }

    private var cuando: String {
        let dia = "\(Formato.diaSemana(actividad.fecha).conMayuscula), \(Formato.diaMes(actividad.fecha))"
        guard let i = actividad.inicio else { return "\(dia) · " + L("Todo el día", "All day", "Tutto il giorno") }
        let horas = actividad.fin.map { "\(Formato.hora(i))–\(Formato.hora($0))" } ?? Formato.hora(i)
        return "\(dia) · \(horas)"
    }

    private var deDonde: String {
        if cita.origen == .teams { return "Microsoft Teams" }
        let generico = ["calendario", "calendar", "calendari"].contains(FusionCalendarios.normalizar(cita.calendario))
        return [generico ? "" : cita.calendario, cita.cuenta].filter { !$0.isEmpty }.reduce(into: [String]()) { r, t in
            if !r.contains(t) { r.append(t) }
        }.joined(separator: " · ")
    }

    private var destino: (url: URL, titulo: String, simbolo: String, color: ColorHoot)? {
        if cita.origen == .teams {
            guard let e = cita.enlace, let url = URL(string: e) else { return nil }
            return (url, L("Abrir en Outlook", "Open in Outlook", "Apri in Outlook"), "arrow.up.forward.app.fill", .azul)
        }

        guard let url = URL(string: "calshow:\(Int(cita.inicio.timeIntervalSinceReferenceDate))") else { return nil }
        return (url, L("Abrir en Calendario", "Open in Calendar", "Apri in Calendario"), "calendar", .rojo)
    }
}
