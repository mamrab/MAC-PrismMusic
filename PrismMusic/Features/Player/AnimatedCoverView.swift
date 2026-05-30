//
//  AnimatedCoverView.swift
//  PrismMusic
//
//  Clean and high-performance album cover representation for the Prism player:
//   - Centered square cover with rounded corners and high-quality rendering.
//   - Subtle shadow and dominant-color glow effects behind the cover.
//   - Smooth spring scale animation (1.0 when playing, 0.82 when paused) for visual feedback.
//

import SwiftUI

struct AnimatedCoverView: View {
    let track: Track?
    let isPlaying: Bool
    /// Side length in points. Square aspect enforced.
    let size: CGFloat

    @State private var dominantColor: Color = .white

    var body: some View {
        ZStack {
            // Radiant glow tinted with the cover's dominant colour
            RoundedRectangle(cornerRadius: size * 0.07, style: .continuous)
                .fill(dominantColor.opacity(0.4))
                .blur(radius: size * 0.20)
                .offset(y: size * 0.04)
                .scaleEffect(0.92)

            // Actual artwork
            artwork
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.06, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(
                    color: .black.opacity(isPlaying ? 0.45 : 0.15),
                    radius: isPlaying ? 30 : 15,
                    y: isPlaying ? 16 : 8
                )
                .scaleEffect(isPlaying ? 1.0 : 0.82)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isPlaying)
        }
        .frame(width: size, height: size)
        .task(id: track?.artworkURL) {
            await refreshDominantColor()
        }
    }

    // MARK: - Artwork loader

    @ViewBuilder
    private var artwork: some View {
        if let url = track?.artworkURL {
            AsyncImage(url: url) { phase in
                ZStack {
                    if let image = phase.image {
                        image
                            .resizable()
                            .interpolation(.high)
                            .scaledToFill()
                            .transition(.opacity)
                    } else {
                        fallback
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: phase.image != nil)
            }
            .id(url)
        } else {
            fallback
        }
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: size * 0.3, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func refreshDominantColor() async {
        guard let url = track?.artworkURL else { dominantColor = .white; return }
        if let color = await ColorExtractor.dominantColor(from: url) {
            withAnimation(.easeInOut(duration: 0.6)) { dominantColor = color }
        }
    }
}
