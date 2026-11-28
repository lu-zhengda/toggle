import SwiftUI

extension View {
    func adaptiveGlass<S: InsettableShape>(
        tint: Color? = nil,
        interactive: Bool = false,
        in shape: S
    ) -> some View {
        modifier(AdaptiveGlassModifier(tint: tint, interactive: interactive, shape: shape))
    }
}

struct AdaptiveGlassModifier<S: InsettableShape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var tint: Color?
    var interactive: Bool
    var shape: S

    func body(content: Content) -> some View {
        applied(content)
            .overlay {
                if contrast == .increased {
                    shape.strokeBorder(Color.primary.opacity(0.55), lineWidth: 1)
                }
            }
    }

    @ViewBuilder
    private func applied(_ content: Content) -> some View {
        if reduceTransparency {
            opaque(content)
        } else {
            translucent(content)
        }
    }

    @ViewBuilder
    private func opaque(_ content: Content) -> some View {
        let filled = content.background(Color(nsColor: .windowBackgroundColor), in: shape)
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            filled.glassEffect(.identity, in: shape)
        } else {
            filled
        }
        #else
        filled
        #endif
    }

    @ViewBuilder
    private func translucent(_ content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            content.glassEffect(modernGlass, in: shape)
        } else {
            content.background(.regularMaterial, in: shape)
        }
        #else
        content.background(.regularMaterial, in: shape)
        #endif
    }

    #if compiler(>=6.2)
    @available(macOS 26, *)
    private var modernGlass: Glass {
        var glass: Glass = .regular
        if let tint {
            glass = glass.tint(tint)
        }
        if interactive {
            glass = glass.interactive()
        }
        return glass
    }
    #endif
}

struct AdaptiveGlassContainer<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing, content: content)
        } else {
            content()
        }
        #else
        content()
        #endif
    }
}

struct GlassCircleButtonStyle: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        styled(content)
            .overlay {
                if contrast == .increased {
                    Circle().strokeBorder(Color.primary.opacity(0.7), lineWidth: 1)
                }
            }
    }

    @ViewBuilder
    private func styled(_ content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *), !reduceTransparency {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .background {
                Circle().fill(
                    reduceTransparency
                        ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
                        : AnyShapeStyle(.regularMaterial)
                )
            }
    }
}

struct GlassCircleButton: View {
    var systemName: String
    var help: String
    var disabled = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .modifier(GlassCircleButtonStyle())
        .disabled(disabled)
        .help(help)
        .accessibilityLabel(help)
    }
}
