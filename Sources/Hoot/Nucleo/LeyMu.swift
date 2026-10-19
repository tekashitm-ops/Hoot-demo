import Foundation

nonisolated enum LeyMu {
    static func codificar(_ muestra: Int16) -> UInt8 {
        let sesgo: Int32 = 0x84, tope: Int32 = 32_635
        var s = Int32(muestra)
        let signo: Int32 = s < 0 ? 0x80 : 0
        if s < 0 { s = -s }
        s = min(s, tope) + sesgo
        var exponente: Int32 = 7
        var mascara: Int32 = 0x4000
        while exponente > 0 && (s & mascara) == 0 { exponente -= 1; mascara >>= 1 }
        let mantisa = (s >> (exponente + 3)) & 0x0F
        return UInt8(truncatingIfNeeded: ~(signo | (exponente << 4) | mantisa))
    }

    static func decodificar(_ byte: UInt8) -> Int16 {
        let u = Int32(~byte & 0xFF)
        let signo = u & 0x80, exponente = (u >> 4) & 0x07, mantisa = u & 0x0F
        var s = ((mantisa << 3) + 0x84) << exponente
        s -= 0x84
        return Int16(truncatingIfNeeded: signo != 0 ? -s : s)
    }
}
