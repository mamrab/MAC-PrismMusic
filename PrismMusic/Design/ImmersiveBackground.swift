//
//  ImmersiveBackground.swift
//  PrismMusic
//
//  Subtle blurred cover that fills the entire screen behind everything.
//  When immersive mode is off, falls back to a flat dark gradient.
//

import SwiftUI

struct ImmersiveBackground: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ZStack {
            // Base canvas — always present so transitions don't flash.
            Theme.Palette.background

            if app.settings.immersiveMode, let url = app.audio.currentTrack?.artworkURL {
                AsyncImage(url: url) { phase in
                    ZStack {
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                                .blur(radius: 60, opaque: true)
                                .opacity(0.55)
                                .saturation(1.2)
                                // Subtle slow drift so the background feels alive.
                                .scaleEffect(1.15)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.4), value: phase.image != nil)
                }
                .id(url)
                .transition(.opacity)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                
                // Vignette + dark gradient overlay to keep foreground readable.
                LinearGradient(
                    colors: [.black.opacity(0.55), .black.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .transition(.opacity)
            } else {
                LinearGradient(
                    colors: [
                        Theme.Palette.background,
                        Color(red: 0.07, green: 0.07, blue: 0.10),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: app.audio.currentTrack?.artworkURL)
        .animation(.easeInOut(duration: 0.8), value: app.settings.immersiveMode)
    }
}
