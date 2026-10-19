import SwiftUI

struct PasoPermisoIA: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo
    @State private var confirmado = false

    var body: some View {
        let edad = EdadIA.minima(region: almacen.ajustes.region)
        PaginaConfig(
            simbolo: "figure.and.child.holdinghands",
            colorSimbolo: ColorHoot.naranja.color,
            titulo: L("Pásale el iPhone a tu madre o a tu padre", "Hand the iPhone to your parent", "Passa l'iPhone a tua madre o a tuo padre"),
            subtitulo: L("Para ayudarte a estudiar, Hoot usa la inteligencia artificial de este iPhone, sin internet. Por debajo de \(edad) años hace falta su permiso.",
                         "To help with studying, Hoot uses this iPhone's artificial intelligence, offline. Under \(edad), a parent's permission is needed.",
                         "Per aiutarti a studiare, Hoot usa l'intelligenza artificiale di questo iPhone, senza internet. Sotto i \(edad) anni serve il loro permesso."),
            principal: L("Doy permiso", "I give permission", "Do il permesso"),
            principalActivo: confirmado,
            accionPrincipal: {
                almacen.ajustes.permisoIA = true
                almacen.ajustes.permisoIAFecha = Reloj.ahora
                flujo.avanzar(desde: .permisoIA, rol: almacen.perfil.rol)
            },
            secundario: L("Ahora no", "Not now", "Non ora"),
            accionSecundaria: { flujo.avanzar(desde: .permisoIA, rol: almacen.perfil.rol) }
        ) {
            Section {
                Toggle(isOn: $confirmado) {
                    Text(L("Soy su madre, su padre o su tutor", "I'm their parent or guardian", "Sono sua madre, suo padre o il tutore"))
                }
                .interruptorApple()
            } footer: {
                Text(L("Explica, resume, hace esquemas y le pregunta los temas. Lo que lee de las fotos no sale del iPhone. Se puede quitar en Cuenta.",
                       "It explains, summarizes, makes outlines and quizzes them. What it reads from photos stays on the iPhone. You can turn it off in Account.",
                       "Spiega, riassume, fa schemi e lo interroga. Quello che legge dalle foto resta sull'iPhone. Si può togliere in Account."))
            }
            .filaConfig()
        }
    }
}

struct PasoPrimeraPrueba: View {
    @Environment(Almacen.self) private var almacen
    @Environment(FlujoConfig.self) private var flujo
    @State private var nueva: ComoApuntar?

    var body: some View {
        let cal = calendarioActual
        let apuntadas = almacen.datos.pruebas.filter { $0.diasQueFaltan(desde: Reloj.ahora, cal: cal) >= 0 }
        PaginaConfig(
            simbolo: "moonphase.first.quarter",
            colorSimbolo: Color.ambar,
            titulo: L("¿Tienes alguna prueba pronto?", "Any tests coming up?", "Hai qualche verifica a breve?"),
            subtitulo: L("Cada tema tendrá su luna: se llena cuando Hoot comprueba que lo sabes.",
                         "Each topic gets a moon: it fills up when Hoot checks you know it.",
                         "Ogni argomento avrà la sua luna: si riempie quando Hoot controlla che lo sai."),
            principal: apuntadas.isEmpty ? nil : L("Continuar", "Continue", "Continua"),
            accionPrincipal: { flujo.avanzar(desde: .primeraPrueba, rol: almacen.perfil.rol) },
            secundario: apuntadas.isEmpty ? L("No tengo ninguna", "None for now", "Nessuna per ora") : nil,
            accionSecundaria: { flujo.avanzar(desde: .primeraPrueba, rol: almacen.perfil.rol) }
        ) {
            if apuntadas.isEmpty {
                Section {
                    BotonesApuntar(tinte: .azulConfig, letra: .azulConfig) { nueva = $0 }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            } else {
                Section {
                    ForEach(apuntadas) { p in
                        let asig = almacen.datos.asignatura(p.asignaturaID)
                        HStack(spacing: 12) {
                            IconoAsignatura(asignatura: asig, lado: 32)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(asig?.nombre ?? p.tipo.nombre).font(.headline)
                                Text("\(p.tipo.nombre) · \(Formato.diaRelativo(p.fecha)) · \(p.temas.count) " + L("temas", "topics", "argomenti"))
                                    .font(.subheadline)
                                    .foregroundStyle(Color.texto2)
                            }
                            Spacer(minLength: 8)
                            FilaLunas(partes: p.temas.prefix(6).map { _ in 0 }, tamano: 16, hueco: 3)
                        }
                    }
                    Button(L("Apuntar otra", "Add another", "Aggiungine un'altra"), systemImage: "plus") { nueva = .foto }
                }
                .filaConfig()
            }
        }
        .sheet(item: $nueva) { c in
            NuevaPrueba(empezarCon: c) { _ in }
        }
    }
}
