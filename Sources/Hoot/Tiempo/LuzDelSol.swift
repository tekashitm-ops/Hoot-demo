import SwiftUI

struct LuzDelSol: View {
    @State private var ancho: CGFloat = 0
    @State private var imagen: CGImage?

    var body: some View {
        Color.clear
            .overlay(alignment: .top) {
                if let imagen {
                    Image(decorative: imagen, scale: 1)
                        .resizable()
                        .frame(width: ancho, height: ancho * CGFloat(SolDeTiempo.alcance))
                        .transition(.opacity)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { ancho = $0 }
            .task(id: Int(ancho.rounded())) {
                let w = Int(ancho.rounded())
                guard w > 0 else { return }
                if let hecha = Self.hechas[w] {
                    imagen = hecha
                    return
                }
                let (alto, datos) = await Task.detached(priority: .userInitiated) { SolDeTiempo.pixeles(ancho: w) }.value
                guard !Task.isCancelled, let nueva = Self.imagen(ancho: w, alto: alto, datos: datos) else { return }
                Self.hechas[w] = nueva
                withAnimation(.easeOut(duration: 0.4)) { imagen = nueva }
            }
            .blendMode(.screen)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private static var hechas: [Int: CGImage] = [:]

    private static func imagen(ancho: Int, alto: Int, datos: [UInt8]) -> CGImage? {
        guard let espacio = CGColorSpace(name: CGColorSpace.sRGB),
              let proveedor = CGDataProvider(data: Data(datos) as CFData) else { return nil }
        return CGImage(width: ancho, height: alto, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: ancho * 4,
                       space: espacio, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: proveedor, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
