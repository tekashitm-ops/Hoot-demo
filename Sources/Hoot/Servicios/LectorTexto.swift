import UIKit
import Vision
import ImageIO

enum LectorTexto {
    static func leer(_ imagen: UIImage) async throws -> String {
        guard let cg = imagen.cgImage else { return "" }
        var peticion = RecognizeTextRequest()
        peticion.recognitionLevel = .accurate
        peticion.usesLanguageCorrection = true
        peticion.automaticallyDetectsLanguage = true
        peticion.recognitionLanguages = [Locale.Language(identifier: idiomaActual.rawValue)]
        let resultado = try await peticion.perform(on: cg, orientation: imagen.imageOrientation.cgOrientation)

        let lineas = resultado
            .sorted { a, b in
                let ya = a.boundingBox.origin.y, yb = b.boundingBox.origin.y
                if abs(ya - yb) > 0.01 { return ya > yb }
                return a.boundingBox.origin.x < b.boundingBox.origin.x
            }
            .compactMap { $0.topCandidates(1).first?.string }
        return lineas.joined(separator: "\n")
    }
}

extension UIImage.Orientation {
    var cgOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}
