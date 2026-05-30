use tauri::Manager;

#[cfg(target_os = "windows")]
use window_vibrancy::{apply_mica, apply_acrylic};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            let window = app.get_webview_window("main").unwrap();

            #[cfg(target_os = "windows")]
            {
                // Apply Mica dark theme effect (matching our dark/immersive theme)
                if let Err(_) = apply_mica(&window, Some(true)) {
                    // Fallback to Acrylic if Mica is not supported (e.g., Windows 10)
                    let _ = apply_acrylic(&window, Some((15, 15, 15, 80)));
                }
            }

            #[cfg(target_os = "macos")]
            {
                use window_vibrancy::NSVisualEffectMaterial;
                let _ = window_vibrancy::apply_vibrancy(
                    &window, 
                    NSVisualEffectMaterial::UnderWindowBackground, 
                    None, 
                    None
                );
                let _ = window.set_decorations(true);
                let _ = window.set_title_bar_style(tauri::TitleBarStyle::Overlay);
            }

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
