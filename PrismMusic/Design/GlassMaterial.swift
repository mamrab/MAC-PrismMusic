//
//  GlassMaterial.swift
//  PrismMusic
//
//  Native iOS 26 Liquid Glass implementation. Uses the real `.glassEffect()`
//  modifier for the frosted / refractive glass material that defines the
//  iOS 26 design language.
//

import SwiftUI

extension View {
    /// Applies iOS 26 Liquid Glass (`.glassEffect()`).
    ///
    /// - Parameters:
    ///   - cornerRadius: Corner radius of the glass surface. Pass `nil` to
    ///                   use a plain rectangle.
    ///   - tint:         Subtle colour overlay (typically the dominant
    ///                   cover colour).
    @ViewBuilder
    func prismGlass(cornerRadius: CGFloat? = nil, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            if let radius = cornerRadius {
                self.glassEffect(.regular.tint(tint ?? .clear),
                                 in: .rect(cornerRadius: radius))
            } else {
                self.glassEffect(.regular.tint(tint ?? .clear),
                                 in: .rect)
            }
        } else {
            if let radius = cornerRadius {
                self.background(.thinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            } else {
                self.background(.thinMaterial)
            }
        }
    }

    /// Applies Liquid Glass with a circular shape — for round buttons, avatars, etc.
    @ViewBuilder
    func prismGlassCircle(tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint ?? .clear), in: .circle)
        } else {
            self.background(.thinMaterial, in: Circle())
        }
    }

    /// Applies Liquid Glass with a capsule shape — for pills, chips, search fields.
    @ViewBuilder
    func prismGlassCapsule(tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint ?? .clear), in: .capsule)
        } else {
            self.background(.thinMaterial, in: Capsule())
        }
    }
}
