import Foundation

enum Reloj {
    nonisolated(unsafe) static var desfase: TimeInterval = 0

    nonisolated(unsafe) static var parado: Date?

    nonisolated static var ahora: Date { parado ?? Date().addingTimeInterval(desfase) }

    nonisolated static func desde(_ fecha: Date) -> Date { parado ?? fecha.addingTimeInterval(desfase) }
}
