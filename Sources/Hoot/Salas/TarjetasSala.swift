import SwiftUI

struct TarjetaAvisosAmigos: View {
    @Environment(Almacen.self) private var almacen
    @Environment(\.dynamicTypeSize) private var letra
    @State private var salas = Salas.compartidas
    @State private var jugando: RetoDiferido?

    var body: some View {
        let lista = Array(salas.invitaciones.prefix(2)) + Array(salas.retosPendientes.prefix(2)) + Array(salas.resultados.prefix(2))
        if !lista.isEmpty {
            TarjetaCielo(titulo: L("Con un amigo", "With a friend", "Con un amico"), simbolo: "person.2.fill") {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lista.enumerated()), id: \.element.id) { i, a in
                        if i > 0 { Separador() }
                        fila(a).padding(.vertical, 12)
                    }
                }
            }
            .fullScreenCover(item: Binding(get: { jugando.map(RetoDiferidoAbierto.init) }, set: { if $0 == nil { jugando = nil } })) { r in
                RetoDiferidoVista(reto: r.reto) { jugando = nil }
            }
        }
    }

    @ViewBuilder
    private func fila(_ a: AvisoSala) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(String(a.nombre.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color(ContenedorPizarra.colorAmigo), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo(a)).font(.headline)
                    Text(detalle(a)).font(.subheadline).foregroundStyle(EstiloSecundario())
                }
            }
            let disposicion = letra.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
            disposicion {
                if a.tipo == "resultadoReto" {
                    Button { salas.quitar(a) } label: { Text(L("Vale", "OK", "Ok")).frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered)
                        .tint(.white)
                } else {
                    Button { salas.quitar(a) } label: { Text(L("Ahora no", "Not Now", "Non ora")).frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    Button { abrir(a) } label: { Text(a.tipo == "reto" ? L("Jugar", "Play", "Gioca") : L("Entrar", "Join", "Entra")).frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                        .tint(.white)
                        .foregroundStyle(Color.tintaBocadillo)
                }
            }
            .controlSize(.large)
        }
    }

    private func titulo(_ a: AvisoSala) -> String {
        switch a.tipo {
        case "reto": L("\(a.nombre) te ha dejado un reto", "\(a.nombre) left you a challenge", "\(a.nombre) ti ha lasciato una sfida")
        case "resultadoReto": L("\(a.nombre) ha hecho tu reto", "\(a.nombre) played your challenge", "\(a.nombre) ha fatto la tua sfida")
        default: L("\(a.nombre) te invita a estudiar", "\(a.nombre) invites you to study", "\(a.nombre) ti invita a studiare")
        }
    }

    private func detalle(_ a: AvisoSala) -> String {
        let d = try? JSONDecoder().decode(DatosRetoDiferido.self, from: Data(a.datos.utf8))
        switch a.tipo {
        case "reto":
            return d?.tema ?? ""
        case "resultadoReto":
            guard let d else { return "" }
            let suyo = d.aciertos.filter { $0 }.count, mio = d.rival.filter { $0 }.count
            return L("\(d.tema): \(suyo) de \(max(d.aciertos.count, 1)) · tú, \(mio)", "\(d.tema): \(suyo) of \(max(d.aciertos.count, 1)) · you, \(mio)",
                     "\(d.tema): \(suyo) su \(max(d.aciertos.count, 1)) · tu, \(mio)")
        default:
            return Formato.diaRelativo(a.fecha) + " · " + Formato.hora(a.fecha)
        }
    }

    private func abrir(_ a: AvisoSala) {
        if a.tipo == "reto" {
            let d = try? JSONDecoder().decode(DatosRetoDiferido.self, from: Data(a.datos.utf8))
            let nombre = (d?.tema ?? "").lowercased()
            let temas = almacen.datos.pruebas.flatMap(\.temas).filter { !nombre.isEmpty && $0.nombre.lowercased() == nombre }
            jugando = RetoDiferido(aviso: a, temas: temas, curso: almacen.perfil.curso, nombreYo: almacen.perfil.nombre)
        } else {
            salas.quitar(a)
            salas.codigoPendiente = a.codigo
            salas.entrando = true
        }
    }
}

struct TarjetaEstudiarConAmigo: View {
    @State private var salas = Salas.compartidas

    var body: some View {
        TarjetaCielo(titulo: L("Con un amigo", "With a friend", "Con un amico"), simbolo: "person.2.fill") {
            Button {
                salas.codigoPendiente = ""
                salas.entrando = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Color.acentoRelleno.opacity(0.6)))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Estudiar con un amigo", "Study with a friend", "Studiare con un amico"))
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                        if let inv = salas.invitaciones.first {
                            Text(L("\(inv.nombre) te invita", "\(inv.nombre) invites you", "\(inv.nombre) ti invita"))
                                .font(.subheadline)
                                .foregroundStyle(EstiloUrgente())
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(EstiloSecundario())
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(EstiloFilaCielo())
            .padding(.horizontal, -6)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: Diseno.margen, bottom: 6, trailing: Diseno.margen))
    }
}
