import SwiftUI

struct Avatar: View {
    var tamano: CGFloat
    var estilo: EstiloAvatar
    var color: ColorHoot
    var iniciales: String
    var foto: UIImage?

    var body: some View {
        ZStack {
            switch estilo {
            case .foto where foto != nil:
                Image(uiImage: foto!)
                    .resizable()
                    .scaledToFill()
            case .iniciales:
                color.color
                Text(iniciales)
                    .font(.system(size: tamano * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.sobre)
                    .minimumScaleFactor(0.5)
            default:
                LinearGradient(colors: [color.color.opacity(0.35), color.color.opacity(0.18)], startPoint: .top, endPoint: .bottom)

                Lobo(tamano: tamano * 0.9, anima: tamano > 60)
                    .offset(y: tamano * 0.07)
            }
        }
        .frame(width: tamano, height: tamano)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

extension Almacen {

    func avatar(_ tamano: CGFloat) -> Avatar {
        Avatar(tamano: tamano, estilo: perfil.avatar, color: perfil.colorAvatar, iniciales: perfil.iniciales, foto: fotoAvatar)
    }
}

struct BotonCuenta: View {
    @Environment(Almacen.self) private var almacen

    var body: some View {

        Button {
            almacen.mostrandoCuenta = true
        } label: {

            almacen.avatar(Diseno.avatarBarra)
                .padding(-Diseno.avatarBarra * 0.075)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.mini)
        .chocable(.circulo, reacciona: true)
        .accessibilityLabel(L("Cuenta", "Account", "Account"))
        .accessibilityShowsLargeContentViewer {
            Label(L("Cuenta", "Account", "Account"), systemImage: "person.crop.circle")
        }
    }
}

extension View {

    func conBotonCuenta() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BotonCuenta()
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }
}

struct BotonCalendario: View {
    @Environment(Almacen.self) private var almacen

    var body: some View {
        Button {
            almacen.mostrandoCalendario = true
        } label: {
            Image(systemName: "calendar")
        }
        .chocable(.circulo, reacciona: true)
        .accessibilityLabel(L("Calendario", "Calendar", "Calendario"))
    }
}
