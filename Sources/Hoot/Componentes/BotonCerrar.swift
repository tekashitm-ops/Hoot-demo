import SwiftUI

struct BotonCerrar: View {
    var accion: () -> Void

    var body: some View {
        Button(role: .close, action: accion)
            .tint(Color.primary)
    }
}
