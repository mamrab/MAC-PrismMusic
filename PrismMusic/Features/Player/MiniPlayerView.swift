//
//  MiniPlayerView.swift
//  PrismMusic
//
//  Compact persistent player above the tab bar. Tap to expand into the
//  full-screen Now Playing view.
//

import SwiftUI

struct MiniPlayerView: View {
    @Environment(AppState.self) private var app
    let onExpand: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: app.audio.currentTrack?.artworkURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Color.white.opacity(0.06)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(app.audio.currentTrack?.title ?? "—")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(app.audio.currentTrack?.artist ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                app.audio.togglePlay()
            } label: {
                Image(systemName: app.audio.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .contentTransition(.symbolEffect(.replace))

            Button {
                app.audio.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background {
            GeometryReader { proxy in
                let frac = app.audio.duration > 0 ? app.audio.progress / app.audio.duration : 0
                ZStack(alignment: .leading) {
                    Color.clear
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: max(0, proxy.size.width * frac))
                        .animation(.linear(duration: 0.25), value: frac)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .prismGlass(cornerRadius: 16)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    let horizontalDistance = value.translation.width
                    let verticalDistance = value.translation.height
                    
                    if verticalDistance < -35 && abs(horizontalDistance) < abs(verticalDistance) {
                        onExpand()
                    } else if abs(horizontalDistance) > 40 && abs(verticalDistance) < abs(horizontalDistance) {
                        if horizontalDistance < 0 {
                            app.audio.next()
                        } else {
                            app.audio.previous()
                        }
                    }
                }
        )
        .onTapGesture {
            onExpand()
        }
    }
}
