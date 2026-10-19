import SwiftUI

struct BotonCerrar: View {
    var accion: () -> Void

    var body: some View {
        Button(role: .close, action: accion)
            .tint(Color.primary)
    }
}

struct TituloBarra: ToolbarContent {
    var titulo: String
    var subtitulo: String

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 0) {
                Text(titulo).font(.headline).foregroundStyle(.white).lineLimit(1)
                if !subtitulo.isEmpty {
                    Text(subtitulo).font(.caption).foregroundStyle(.white.opacity(0.86)).lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
        .sharedBackgroundVisibility(.hidden)
    }
}
