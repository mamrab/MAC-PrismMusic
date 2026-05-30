//
//  SettingsView.swift
//  PrismMusic
//
//  Backend URL + Yandex token + immersive toggle. Persisted via
//  `SettingsStore`. The Yandex token field is secure (masked).
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @State private var backendDraft: String = ""
    @State private var tokenDraft: String = ""
    @State private var showTokenInfo = false
    @State private var savedFlash = false
    @State private var showDebugLogs = false
    @State private var logsContent = ""
    @State private var isImporting = false
    @State private var showImportAlert = false
    @State private var importAlertMessage = ""
    @State private var isDownloadingAll = false

    var body: some View {
        NavigationStack {
            ZStack {
                ImmersiveBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        

                        // Yandex.Music config card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Yandex.Music")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .padding(.horizontal, 4)
                            
                            VStack(alignment: .leading, spacing: 14) {
                                SecureField("Введи Yandex.Music token", text: $tokenDraft)
                                    .padding(12)
                                    .background(Color.white.opacity(0.04))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                                    )
                                    .foregroundStyle(.white)
                                    .tint(.white)
                                
                                Button {
                                    showTokenInfo = true
                                } label: {
                                    Label("Как получить токен?", systemImage: "questionmark.circle")
                                        .foregroundStyle(.white)
                                        .font(.system(size: 14, weight: .medium))
                                }
                                
                                if !app.settings.yandexToken.isEmpty {
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                    
                                    Button {
                                        importYandexLikes()
                                    } label: {
                                        HStack {
                                            Label("Импортировать любимые треки", systemImage: "arrow.down.circle")
                                                .foregroundStyle(.white)
                                                .font(.system(size: 14, weight: .medium))
                                            Spacer()
                                            if isImporting {
                                                ProgressView()
                                                    .tint(.white)
                                            }
                                        }
                                    }
                                    .disabled(isImporting)
                                }
                            }
                            .padding(14)
                            .prismGlass(cornerRadius: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                            
                            Text("Без токена доступен только SoundCloud и Spotify. Токен хранится в Keychain устройства, бэкенд получает его одноразово в каждом запросе стрима.")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textTertiary)
                                .padding(.horizontal, 4)
                        }
                        
                        // UI config card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Внешний вид")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .padding(.horizontal, 4)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle(isOn: Binding(
                                    get: { app.settings.immersiveMode },
                                    set: { app.settings.immersiveMode = $0 }
                                )) {
                                    Label("Immersive фон", systemImage: "sparkles")
                                        .foregroundStyle(.white)
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .tint(.white)
                            }
                            .padding(14)
                            .prismGlass(cornerRadius: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                            
                            Text("Immersive фон подкрашивает фон приложения цветом текущей обложки.")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textTertiary)
                                .padding(.horizontal, 4)
                        }
                        
                        // Offline mode card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Офлайн-режим")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .padding(.horizontal, 4)
                            
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Скачанные треки")
                                            .foregroundStyle(.white)
                                            .font(.system(size: 14, weight: .medium))
                                        Text("\(app.downloadStore.downloadedTracks.count) треков сохранено локально")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Theme.Palette.textTertiary)
                                    }
                                    Spacer()
                                }
                                
                                if !app.downloadStore.downloadingTrackIDs.isEmpty || isDownloadingAll {
                                    let downloadingCount = app.downloadStore.downloadingTrackIDs.count
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .tint(.white)
                                            .controlSize(.small)
                                        Text(downloadingCount > 0 ? "Скачивание треков (\(downloadingCount) в очереди)..." : "Подготовка к скачиванию...")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                    .padding(.vertical, 2)
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                Button {
                                    downloadAllTracks()
                                } label: {
                                    HStack {
                                        Label("Скачать все треки", systemImage: "arrow.down.to.line.circle")
                                            .foregroundStyle(.white)
                                            .font(.system(size: 14, weight: .medium))
                                        Spacer()
                                    }
                                }
                                .disabled(!app.networkMonitor.isConnected || isDownloadingAll || !app.downloadStore.downloadingTrackIDs.isEmpty)
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                Button {
                                    app.downloadStore.deleteAllTracks()
                                } label: {
                                    HStack {
                                        Label("Удалить все скачанные треки", systemImage: "trash")
                                            .foregroundStyle(.red)
                                            .font(.system(size: 14, weight: .medium))
                                        Spacer()
                                    }
                                }
                                .disabled(app.downloadStore.downloadedTracks.isEmpty || isDownloadingAll || !app.downloadStore.downloadingTrackIDs.isEmpty)
                            }
                            .padding(14)
                            .prismGlass(cornerRadius: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                            
                            Text("Скачанные треки будут доступны для воспроизведения в Медиатеке, даже если отсутствует интернет-подключение.")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Palette.textTertiary)
                                .padding(.horizontal, 4)
                        }
                        
                        // Debug card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Отладка")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .padding(.horizontal, 4)
                            
                            VStack(alignment: .leading, spacing: 14) {
                                Button {
                                    showDebugLogs = true
                                } label: {
                                    Label("Посмотреть логи (Debug)", systemImage: "ladybug")
                                        .foregroundStyle(.white)
                                        .font(.system(size: 14, weight: .medium))
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                Button {
                                    DebugLogger.shared.clearLogs()
                                } label: {
                                    Label("Очистить логи", systemImage: "trash")
                                        .foregroundStyle(.red)
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                            .padding(14)
                            .prismGlass(cornerRadius: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                        }
                        
                        // Save Button
                        Button {
                            save()
                        } label: {
                            HStack {
                                Spacer()
                                if savedFlash {
                                    Label("Сохранено", systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Text("Сохранить настройки")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                            }
                            .padding()
                            .prismGlass(cornerRadius: 16, tint: savedFlash ? Color.green.opacity(0.12) : Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(savedFlash ? Color.green.opacity(0.3) : Color.white.opacity(0.12), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(savedFlash)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, Theme.Layout.screenInset)
                    .padding(.top, 20)
                    .padding(.bottom, 140)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaPadding(.bottom, app.audio.currentTrack != nil ? 100 : 0)
            .alert("Yandex.Music token", isPresented: $showTokenInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("1. Открой music.yandex.ru\n2. DevTools → Application → Cookies → Session_id\n3. Скопируй и вставь сюда. Также можно получить через oauth.yandex.com.")
            }
            .alert("Импорт любимых треков", isPresented: $showImportAlert) {
                Button("OK", role: roleCancelForAlert) {}
            } message: {
                Text(importAlertMessage)
            }
            .sheet(isPresented: $showDebugLogs) {
                NavigationStack {
                    RealTimeLogsView(isPresented: $showDebugLogs)
                }
            }
        }
        .onAppear {
            backendDraft = app.settings.backendURL
            tokenDraft = app.settings.yandexToken
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Настройки")
                .font(Theme.Typography.largeTitle)
                .foregroundStyle(.white)
            Text("Настройки воспроизведения и соединения")
                .font(Theme.Typography.secondary)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.top, 12)
    }

    private var roleCancelForAlert: ButtonRole? {
        #if os(macOS)
        return nil
        #else
        return .cancel
        #endif
    }

    private func importYandexLikes() {
        isImporting = true
        let userId = app.settings.isLoggedIn ? app.settings.userId : nil
        Task {
            do {
                let response = try await app.api.importYandexLikes(userId: userId)
                let importedTracksCount = app.library.importYandexTracks(response.importedLikes)
                importAlertMessage = "Успешно импортировано \(importedTracksCount) новых треков из Яндекс.Музыки!"
                showImportAlert = true
            } catch {
                importAlertMessage = "Ошибка импорта: \(error.localizedDescription)"
                showImportAlert = true
            }
            isImporting = false
        }
    }

    private func downloadAllTracks() {
        guard app.networkMonitor.isConnected else { return }
        isDownloadingAll = true
        Task {
            let tracksToDownload = app.library.likedTracks
            await app.downloadStore.downloadAll(tracks: tracksToDownload)
            isDownloadingAll = false
        }
    }

    private func save() {
        app.settings.backendURL = backendDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        app.settings.yandexToken = tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        withAnimation(Theme.Motion.snap) {
            savedFlash = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation { savedFlash = false }
        }
    }
}

// MARK: - Real Time Logs View
struct RealTimeLogsView: View {
    @Binding var isPresented: Bool
    @State private var logsContent = ""
    @State private var timer: Timer? = nil

    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                Text(logsContent)
                    .font(.system(size: 10, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .id("logsText")
                    .onChange(of: logsContent) {
                        withAnimation {
                            proxy.scrollTo("logsText", anchor: .bottom)
                        }
                    }
            }
        }
        .navigationTitle("Логи")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Закрыть") { isPresented = false }
            }
        }
        .onAppear {
            loadLogs()
            // Refresh logs every second
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                DispatchQueue.main.async {
                    loadLogs()
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func loadLogs() {
        let content = DebugLogger.shared.readLogs()
        if content != logsContent {
            logsContent = content
        }
    }
}
