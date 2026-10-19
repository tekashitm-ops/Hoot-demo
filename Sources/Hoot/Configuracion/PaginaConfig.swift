import SwiftUI

struct PaginaConfig<Contenido: View>: View {
    var simbolo: String?
    var colorSimbolo: Color = .azulConfig
    var titulo: String
    var subtitulo: String?
    var principal: String?
    var principalActivo = true
    var accionPrincipal: () -> Void = {}
    var secundario: String?
    var accionSecundaria: () -> Void = {}

    var terciario: String?
    var accionTerciaria: () -> Void = {}

    var esperando = false
    @ViewBuilder var contenido: Contenido

    @ScaledMetric(relativeTo: .largeTitle) private var lado = Diseno.iconoCabecera
    @Environment(\.dynamicTypeSize) private var tamanoLetra

    var body: some View {
        List {
            Section {
                VStack(spacing: 0) {
                    if let simbolo {
                        Image(systemName: simbolo)
                            .font(.system(size: lado, weight: .regular))
                            .foregroundStyle(colorSimbolo)
                            .symbolRenderingMode(.hierarchical)
                            .frame(height: lado * 1.15)
                            .padding(.bottom, 18)
                            .accessibilityHidden(true)
                    }
                    Text(titulo)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitulo {
                        Text(subtitulo.conMarkdown)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 12)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 12, trailing: 12))
                .listRowSeparator(.hidden)
            }

            contenido

            if tamanoLetra.isAccessibilitySize && (principal != nil || secundario != nil || terciario != nil) {
                Section {
                    botones
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.fondo)
        .environment(\.defaultMinListRowHeight, 52)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaBar(edge: .bottom) {
            if !tamanoLetra.isAccessibilitySize && (principal != nil || secundario != nil || terciario != nil) {
                botones
                    .padding(.horizontal, Diseno.margen + 8)
                    .padding(.bottom, 8)
            }
        }
    }

    private var botones: some View {
                VStack(spacing: 6) {
                    if let principal {
                        Button(action: accionPrincipal) {
                            ZStack {
                                Text(principal).opacity(esperando ? 0 : 1)
                                if esperando { ProgressView().tint(.white) }
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.extraLarge)
                        .tint(Color.azulConfigRelleno)
                        .disabled(!principalActivo || esperando)
                        .accessibilityValue(esperando ? L("Esperando", "Waiting", "In attesa") : "")
                    }
                    if let secundario {
                        Button(secundario, action: accionSecundaria)
                            .buttonStyle(.borderless)
                            .font(.body)
                            .foregroundStyle(Color.azulConfig)
                            .frame(minHeight: 44)
                            .disabled(esperando)
                    }
                    if let terciario {
                        Button(terciario, action: accionTerciaria)
                            .buttonStyle(.borderless)
                            .font(.subheadline)
                            .foregroundStyle(Color.azulConfig)
                            .frame(minHeight: 44)
                            .disabled(esperando)
                    }
                }
    }
}

struct SeccionLibre<Contenido: View>: View {
    @ViewBuilder var contenido: Contenido

    var body: some View {
        Section {
            contenido
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
        }
    }
}

struct CampoConfig: View {
    var etiqueta: String
    var sugerencia: String = ""
    @Binding var texto: String
    var tipo: UITextContentType?
    var teclado: UIKeyboardType = .default
    var seguro = false
    var mayusculas: TextInputAutocapitalization = .words

    @ScaledMetric(relativeTo: .body) private var anchoEtiqueta = 104
    @Environment(\.dynamicTypeSize) private var tamanoLetra

    var body: some View {
        let apilado = tamanoLetra.isAccessibilitySize
        let disposicion = apilado ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 12))
        disposicion {
            Text(etiqueta)
                .frame(width: apilado ? nil : min(anchoEtiqueta, 150), alignment: .leading)
                .lineLimit(apilado ? nil : 2)
                .minimumScaleFactor(apilado ? 1 : 0.8)
                .accessibilityHidden(true)
            Group {
                if seguro {
                    SecureField(sugerencia, text: $texto)
                } else {
                    TextField(sugerencia, text: $texto)
                }
            }
            .textContentType(tipo)
            .keyboardType(teclado)
            .textInputAutocapitalization(mayusculas)
            .autocorrectionDisabled(tipo != nil)
            .accessibilityLabel(etiqueta)
        }
        .padding(.vertical, apilado ? 6 : 0)
    }
}

struct FilaEleccion: View {
    var titulo: String
    var detalle: String?
    var simbolo: String?
    var color: ColorHoot?
    var elegida: Bool
    var conFlecha = false
    var accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack(spacing: 14) {
                if let simbolo, let color {
                    IconoAjustes(simbolo: simbolo, color: color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo).foregroundStyle(Color.primary)
                    if let detalle {
                        Text(detalle).font(.subheadline).foregroundStyle(Color.texto2)
                    }
                }
                Spacer(minLength: 8)
                if elegida {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.azulConfig)
                        .transition(.scale.combined(with: .opacity))
                } else if conFlecha {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.texto2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(elegida ? .isSelected : [])
    }
}
