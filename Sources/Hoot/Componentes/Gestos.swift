import SwiftUI
import UIKit

struct MantenerYDeslizar: UIGestureRecognizerRepresentable {
    var espera: TimeInterval = 0.15
    var alEmpezar: (CGPoint) -> Void
    var alMover: (CGPoint) -> Void
    var alAcabar: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let r = UILongPressGestureRecognizer()
        r.minimumPressDuration = espera
        r.allowableMovement = 8
        return r
    }

    func updateUIGestureRecognizer(_ r: UILongPressGestureRecognizer, context: Context) {
        r.minimumPressDuration = espera
    }

    func handleUIGestureRecognizerAction(_ r: UILongPressGestureRecognizer, context: Context) {
        let p = context.converter.localLocation
        switch r.state {
        case .began: alEmpezar(p)
        case .changed: alMover(p)
        case .ended, .cancelled, .failed: alAcabar()
        default: break
        }
    }
}

struct ArrastreHorizontal: UIGestureRecognizerRepresentable {

    var alEmpezar: (CGPoint) -> Void
    var alMover: (CGFloat) -> Void
    var alSoltar: (_ movido: CGFloat, _ velocidad: CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinador { Coordinador() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let r = UIPanGestureRecognizer()
        r.delegate = context.coordinator
        return r
    }

    func handleUIGestureRecognizerAction(_ r: UIPanGestureRecognizer, context: Context) {
        let movido = r.translation(in: r.view).x
        switch r.state {
        case .began:

            let p = context.converter.localLocation
            alEmpezar(CGPoint(x: p.x - movido, y: p.y))
            alMover(movido)
        case .changed:
            alMover(movido)
        case .ended, .cancelled, .failed:
            alSoltar(movido, r.velocity(in: r.view).x)
        default:
            break
        }
    }

    final class Coordinador: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let p = g as? UIPanGestureRecognizer else { return true }
            let v = p.velocity(in: p.view)
            return abs(v.x) > abs(v.y)
        }
    }
}

func proyeccion(_ velocidad: CGFloat, frenado: CGFloat = 0.99) -> CGFloat {
    (velocidad / 1000) * frenado / (1 - frenado)
}

func goma(_ pasado: CGFloat, dimension: CGFloat, constante: CGFloat = 0.55) -> CGFloat {
    (pasado * dimension * constante) / (dimension + constante * abs(pasado))
}
