import SwiftUI
import UIKit
import VisionKit
import CoreImage.CIFilterBuiltins

struct CamaraFoto: UIViewControllerRepresentable {
    var alTerminar: (UIImage?) -> Void

    static var disponible: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = .camera
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinador { Coordinador(alTerminar: alTerminar) }

    final class Coordinador: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let alTerminar: (UIImage?) -> Void
        init(alTerminar: @escaping (UIImage?) -> Void) { self.alTerminar = alTerminar }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            alTerminar(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            alTerminar(nil)
        }
    }
}

struct EscanerDocumentos: UIViewControllerRepresentable {
    var alTerminar: ([UIImage]) -> Void

    static var disponible: Bool { VNDocumentCameraViewController.isSupported }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let c = VNDocumentCameraViewController()
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinador { Coordinador(alTerminar: alTerminar) }

    final class Coordinador: NSObject, VNDocumentCameraViewControllerDelegate {
        let alTerminar: ([UIImage]) -> Void
        init(alTerminar: @escaping ([UIImage]) -> Void) { self.alTerminar = alTerminar }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            alTerminar((0..<scan.pageCount).map { scan.imageOfPage(at: $0) })
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            alTerminar([])
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            alTerminar([])
        }
    }
}

struct LectorQR: UIViewControllerRepresentable {
    var alLeer: (String) -> Void

    static var disponible: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let c = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        c.delegate = context.coordinator
        try? c.startScanning()
        return c
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinador) {
        uiViewController.stopScanning()
    }

    func makeCoordinator() -> Coordinador { Coordinador(alLeer: alLeer) }

    final class Coordinador: NSObject, DataScannerViewControllerDelegate {
        let alLeer: (String) -> Void
        private var leido = false
        init(alLeer: @escaping (String) -> Void) { self.alLeer = alLeer }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !leido else { return }
            for item in addedItems {
                if case .barcode(let codigo) = item, let texto = codigo.payloadStringValue {
                    leido = true
                    alLeer(texto)
                    return
                }
            }
        }
    }
}

struct CodigoQR: View {
    var contenido: String

    var body: some View {
        if let imagen = Self.generar(contenido) {
            Image(uiImage: imagen)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .accessibilityLabel(L("Código QR para vincular", "QR code to link", "Codice QR per collegare"))
        }
    }

    static func generar(_ texto: String) -> UIImage? {
        let filtro = CIFilter.qrCodeGenerator()
        filtro.message = Data(texto.utf8)
        filtro.correctionLevel = "M"
        guard let salida = filtro.outputImage else { return nil }
        let grande = salida.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let contexto = CIContext()
        guard let cg = contexto.createCGImage(grande, from: grande.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

enum CodigoVinculo {
    struct Leido {
        var codigo: String
        var nombre: String
    }

    static func interpretar(_ texto: String) -> Leido? {
        if let c = URLComponents(string: texto), c.scheme == "hoot", c.host == "vincular",
           let codigo = c.queryItems?.first(where: { $0.name == "codigo" })?.value {
            let nombre = c.queryItems?.first(where: { $0.name == "nombre" })?.value ?? ""
            return Leido(codigo: codigo, nombre: nombre)
        }
        let limpio = texto.uppercased().replacingOccurrences(of: " ", with: "")
        let patron = #"^HOOT-[A-Z0-9]{4}-[A-Z0-9]{4}$"#
        if limpio.range(of: patron, options: .regularExpression) != nil {
            return Leido(codigo: limpio, nombre: "")
        }
        return nil
    }
}
