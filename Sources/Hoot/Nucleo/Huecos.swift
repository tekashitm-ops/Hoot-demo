import Foundation

nonisolated struct Hueco: Hashable, Sendable {
    var inicio: Int
    var fin: Int
    var duracion: Int { fin - inicio }
}
