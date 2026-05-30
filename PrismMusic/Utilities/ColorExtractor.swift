//
//  ColorExtractor.swift
//  PrismMusic
//
//  Extracts a single representative colour from a remote image. Used to
//  tint the cover glow and the immersive background. Implementation is
//  intentionally simple: downsample to 16x16, average the saturated
//  pixels, clamp lightness so the result reads against a dark canvas.
//

import CoreImage
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
enum ColorExtractor {
    private static var cache: [URL: Color] = [:]

    /// Returns the dominant colour, cached per URL. Returns nil if the
    /// image fails to download or decode.
    static func dominantColor(from url: URL) async -> Color? {
        if let cached = cache[url] { return cached }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = PlatformImage(data: data) else { return nil }
            let color = await extract(from: image)
            cache[url] = color
            return color
        } catch {
            return nil
        }
    }

    private static func extract(from image: PlatformImage) async -> Color {
        #if canImport(UIKit)
        guard let cgImage = image.cgImage else { return Color.white }
        #elseif canImport(AppKit)
        var proposedRect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return Color.white
        }
        #endif

        let rgb = await Task.detached(priority: .utility) { () -> (Double, Double, Double) in
            let targetSize = CGSize(width: 16, height: 16)

            guard let context = CGContext(
                data: nil,
                width: Int(targetSize.width),
                height: Int(targetSize.height),
                bitsPerComponent: 8,
                bytesPerRow: 4 * Int(targetSize.width),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return (1.0, 1.0, 1.0)
            }

            context.draw(cgImage, in: CGRect(origin: .zero, size: targetSize))

            guard let data = context.data else { return (1.0, 1.0, 1.0) }
            let buffer = data.assumingMemoryBound(to: UInt8.self)

            return withExtendedLifetime(context) {
                var bestR: Double = 0, bestG: Double = 0, bestB: Double = 0, weight: Double = 0
                for y in 0..<16 {
                    for x in 0..<16 {
                        let offset = (y * 16 + x) * 4
                        let r = Double(buffer[offset]) / 255
                        let g = Double(buffer[offset + 1]) / 255
                        let b = Double(buffer[offset + 2]) / 255

                        // Skip near-black/near-white pixels (they tint poorly).
                        let maxC = max(r, g, b), minC = min(r, g, b)
                        let saturation = maxC == 0 ? 0 : (maxC - minC) / maxC
                        let lightness = (maxC + minC) / 2
                        if saturation < 0.18 { continue }
                        if lightness < 0.1 || lightness > 0.92 { continue }

                        let w = saturation * (1 - abs(lightness - 0.55))
                        bestR += r * w
                        bestG += g * w
                        bestB += b * w
                        weight += w
                    }
                }
                guard weight > 0 else { return (1.0, 1.0, 1.0) }
                // Clamp lightness so the colour pops against a dark canvas.
                var r = bestR / weight, g = bestG / weight, b = bestB / weight
                let lift = 0.78 - max(r, g, b)
                if lift > 0 {
                    r += lift; g += lift; b += lift
                }
                return (r.clamped(), g.clamped(), b.clamped())
            }
        }.value

        return Color(red: rgb.0, green: rgb.1, blue: rgb.2)
    }
}

private extension Double {
    func clamped(_ range: ClosedRange<Double> = 0...1) -> Double {
        Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}
