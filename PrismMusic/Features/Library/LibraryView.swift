//
//  LibraryView.swift
//  PrismMusic
//
//  Liked tracks. Empty state when nothing is liked yet. Tapping a track
//  starts playback with the entire library as the queue.
//
import SwiftUI

struct LibraryView: View {
    @Environment(AppState.self) private var app

    private var tracksToDisplay: [Track] {
        if !app.networkMonitor.isConnected {
            return app.library.likedTracks.filter { app.downloadStore.isDownloaded($0.id) }
        } else {
            return app.library.likedTracks
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ImmersiveBackground()
                    .ignoresSafeArea()

                Group {
                    if tracksToDisplay.isEmpty {
                        emptyState
                    } else {
                        list
                    }
                }
            }
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                LazyVStack(spacing: 0) {
                    ForEach(tracksToDisplay) { track in
                        TrackRowView(
                            track: track,
                            isPlaying: app.audio.currentTrack?.id == track.id && app.audio.isPlaying,
                            onTap: {
                                if let idx = tracksToDisplay.firstIndex(of: track) {
                                    app.audio.play(queue: tracksToDisplay, startAt: idx)
                                }
                            },
                            onLikeToggle: { app.library.toggleLike(track) },
                            liked: true
                        )
                    }
                }
                .padding(.horizontal, Theme.Layout.screenInset)
            }
            .padding(.bottom, 140)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Медиатека")
                .font(Theme.Typography.largeTitle)
                .foregroundStyle(.white)
            
            if !app.networkMonitor.isConnected {
                Text("Скачано \(tracksToDisplay.count) треков (офлайн)")
                    .font(Theme.Typography.secondary)
                    .foregroundStyle(Theme.Palette.textSecondary)
            } else {
                Text("\(app.library.likedTracks.count) понравившихся")
                    .font(Theme.Typography.secondary)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .padding(.horizontal, Theme.Layout.screenInset)
        .padding(.top, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: !app.networkMonitor.isConnected ? "wifi.slash" : "heart.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Theme.Palette.textTertiary)
            Text(!app.networkMonitor.isConnected ? "Нет скачанных треков" : "Пока пусто")
                .font(Theme.Typography.title)
                .foregroundStyle(.white)
            Text(!app.networkMonitor.isConnected ? "Скачайте треки в настройках, чтобы слушать их офлайн" : "Лайкни треки, и они появятся здесь")
                .font(Theme.Typography.secondary)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
