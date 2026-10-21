import SwiftUI

/// Applies the app's glass surface, or frosted material, to a view in the given shape.
struct GlassSurface<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool

    @AppStorage(SettingsStore.glassStyleKey) private var styleRaw = GlassStyle.liquid.rawValue

    private var style: GlassStyle { GlassStyle(rawValue: styleRaw) ?? .liquid }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), style != .frosted {
            content.glassEffect(Glass.clear.interactive(interactive), in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(shape.stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
        }
    }
}

/// A plain frosted card (no glass effect): for large working areas such as the editor, where glass everywhere looks busy.
struct FrostedCard<S: Shape>: ViewModifier {
    let shape: S
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: shape)
            .overlay(shape.stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
    }
}

extension View {
    func frostedCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(FrostedCard(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
    }

    /// Liquid Glass (the clear variant) on macOS 26+ unless the style setting is Frosted; frosted material before. All Shapeshift glass goes through here.
    func glassSurface<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(GlassSurface(shape: shape, interactive: interactive))
    }

    func glassSurface(cornerRadius: CGFloat = 18, interactive: Bool = false) -> some View {
        glassSurface(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), interactive: interactive)
    }
}
