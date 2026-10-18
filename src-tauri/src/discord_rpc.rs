use serde::{Deserialize, Serialize};
use std::io::{Read, Write};
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};

const DEFAULT_CLIENT_ID: &str = "1542995971783532644";
const FALLBACK_COVER: &str = "https://prismmusic.onrender.com/api/logo";
const APP_LOGO: &str = "https://prismmusic.onrender.com/api/logo";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiscordTimestamps {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub start: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub end: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiscordAssets {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub large_image: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub large_text: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub small_image: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub small_text: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiscordButton {
    pub label: String,
    pub url: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiscordParty {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub size: Option<[u32; 2]>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiscordActivity {
    #[serde(rename = "type", skip_serializing_if = "Option::is_none")]
    pub activity_type: Option<u8>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub details: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub state: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub timestamps: Option<DiscordTimestamps>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub assets: Option<DiscordAssets>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub party: Option<DiscordParty>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub buttons: Option<Vec<DiscordButton>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiscordActivityPayload {
    pub title: String,
    pub artist: String,
    pub album: Option<String>,
    pub source: Option<String>,
    pub cover_url: Option<String>,
    pub current_time: f64,
    pub duration: f64,
    pub is_playing: bool,
    pub track_url: Option<String>,
}

enum IpcStream {
    #[cfg(windows)]
    Windows(std::fs::File),
    #[cfg(unix)]
    Unix(std::os::unix::net::UnixStream),
}

impl Read for IpcStream {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        match self {
            #[cfg(windows)]
            IpcStream::Windows(f) => f.read(buf),
            #[cfg(unix)]
            IpcStream::Unix(s) => s.read(buf),
        }
    }
}

impl Write for IpcStream {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        match self {
            #[cfg(windows)]
            IpcStream::Windows(f) => f.write(buf),
            #[cfg(unix)]
            IpcStream::Unix(s) => s.write(buf),
        }
    }

    fn flush(&mut self) -> std::io::Result<()> {
        match self {
            #[cfg(windows)]
            IpcStream::Windows(f) => f.flush(),
            #[cfg(unix)]
            IpcStream::Unix(s) => s.flush(),
        }
    }
}

pub struct DiscordRpcClient {
    stream: Option<IpcStream>,
    client_id: String,
    nonce: usize,
    pub is_enabled: bool,
}

impl DiscordRpcClient {
    pub fn new() -> Self {
        Self {
            stream: None,
            client_id: DEFAULT_CLIENT_ID.to_string(),
            nonce: 0,
            is_enabled: true,
        }
    }

    fn connect(&mut self) -> Result<(), String> {
        if self.stream.is_some() {
            return Ok(());
        }

        #[cfg(windows)]
        {
            for i in 0..10 {
                let pipe_name = format!(r"\\.\pipe\discord-ipc-{}", i);
                if let Ok(file) = std::fs::OpenOptions::new()
                    .read(true)
                    .write(true)
                    .open(&pipe_name)
                {
                    self.stream = Some(IpcStream::Windows(file));
                    break;
                }
            }
        }

        #[cfg(unix)]
        {
            let runtime_dir = std::env::var("XDG_RUNTIME_DIR")
                .or_else(|_| std::env::var("TMPDIR"))
                .or_else(|_| std::env::var("TMP"))
                .unwrap_or_else(|_| "/tmp".to_string());

            for i in 0..10 {
                let socket_path = format!("{}/discord-ipc-{}", runtime_dir, i);
                if let Ok(stream) = std::os::unix::net::UnixStream::connect(&socket_path) {
                    self.stream = Some(IpcStream::Unix(stream));
                    break;
                }
            }
        }

        if let Some(stream) = &mut self.stream {
            // Send Handshake (Opcode 0)
            let handshake_json = serde_json::json!({
                "v": 1,
                "client_id": self.client_id
            })
            .to_string();

            let mut packet = Vec::new();
            packet.extend_from_slice(&(0u32).to_le_bytes()); // Opcode 0 = Handshake
            packet.extend_from_slice(&(handshake_json.len() as u32).to_le_bytes());
            packet.extend_from_slice(handshake_json.as_bytes());

            if stream.write_all(&packet).is_err() || stream.flush().is_err() {
                self.stream = None;
                return Err("Failed to write Discord handshake".to_string());
            }

            Ok(())
        } else {
            Err("Discord is not running on this machine".to_string())
        }
    }

    pub fn set_activity(&mut self, activity: Option<DiscordActivity>) -> Result<(), String> {
        if !self.is_enabled {
            return Ok(());
        }

        if self.stream.is_none() {
            let _ = self.connect();
        }

        if self.stream.is_none() {
            return Ok(());
        }

        self.nonce += 1;
        let payload_json = serde_json::json!({
            "cmd": "SET_ACTIVITY",
            "args": {
                "pid": std::process::id(),
                "activity": activity
            },
            "nonce": self.nonce.to_string()
        })
        .to_string();

        let mut packet = Vec::new();
        packet.extend_from_slice(&(1u32).to_le_bytes()); // Opcode 1 = Frame
        packet.extend_from_slice(&(payload_json.len() as u32).to_le_bytes());
        packet.extend_from_slice(payload_json.as_bytes());

        let write_failed = if let Some(stream) = &mut self.stream {
            stream.write_all(&packet).is_err() || stream.flush().is_err()
        } else {
            true
        };

        if write_failed {
            // Broken connection - attempt immediate reconnection and re-transmission
            self.stream = None;
            if self.connect().is_ok() {
                if let Some(stream) = &mut self.stream {
                    let _ = stream.write_all(&packet);
                    let _ = stream.flush();
                }
            }
        }

        Ok(())
    }

    pub fn clear_activity(&mut self) -> Result<(), String> {
        self.set_activity(None)
    }
}

pub type DiscordRpcState = Arc<Mutex<DiscordRpcClient>>;

#[tauri::command]
pub fn update_discord_presence(
    state: tauri::State<'_, DiscordRpcState>,
    payload: DiscordActivityPayload,
) -> Result<(), String> {
    let mut client = state.lock().map_err(|e| e.to_string())?;

    if !client.is_enabled {
        return Ok(());
    }

    let now_ms = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64;

    let (timestamps, state_text) = if payload.is_playing {
        let cur_ms = (payload.current_time.max(0.0) * 1000.0).round() as u64;
        let dur_ms = (payload.duration.max(0.0) * 1000.0).round() as u64;

        let start = now_ms.saturating_sub(cur_ms);
        let end = if dur_ms > cur_ms {
            Some(start + dur_ms)
        } else {
            None
        };

        let artist_str = if let Some(ref alb) = payload.album {
            if !alb.trim().is_empty() && alb != &payload.title {
                format!("{} • {}", payload.artist, alb)
            } else {
                format!("by {}", payload.artist)
            }
        } else {
            format!("by {}", payload.artist)
        };

        (
            Some(DiscordTimestamps {
                start: Some(start),
                end,
            }),
            artist_str,
        )
    } else {
        (
            None,
            format!("by {}", payload.artist),
        )
    };

    let cover = payload
        .cover_url
        .filter(|u| u.starts_with("http://") || u.starts_with("https://"))
        .unwrap_or_else(|| FALLBACK_COVER.to_string());

    let listen_url = payload
        .track_url
        .filter(|u| u.starts_with("http://") || u.starts_with("https://"))
        .unwrap_or_else(|| "https://prismmusic.onrender.com".to_string());

    let source_name = payload
        .source
        .as_deref()
        .filter(|s| !s.trim().is_empty())
        .unwrap_or("PrismMusic");

    let large_text = if payload.is_playing {
        if let Some(ref alb) = payload.album {
            if !alb.trim().is_empty() && alb != &payload.title && alb != "PrismMusic" {
                format!("{} • {}", alb, source_name)
            } else {
                source_name.to_string()
            }
        } else {
            source_name.to_string()
        }
    } else {
        if let Some(ref alb) = payload.album {
            if !alb.trim().is_empty() && alb != &payload.title && alb != "PrismMusic" {
                format!("{} • {} (Пауза)", alb, source_name)
            } else {
                format!("{} (Пауза)", source_name)
            }
        } else {
            format!("{} (Пауза)", source_name)
        }
    };

    let small_text = if payload.is_playing {
        format!("PrismMusic • {}", source_name)
    } else {
        format!("На паузе • {}", source_name)
    };

    let activity = DiscordActivity {
        activity_type: Some(2), // 2 = Listening ("Слушает")
        details: Some(payload.title),
        state: Some(state_text),
        timestamps,
        assets: Some(DiscordAssets {
            large_image: Some(cover),
            large_text: Some(large_text),
            small_image: Some(APP_LOGO.to_string()),
            small_text: Some(small_text),
        }),
        party: Some(DiscordParty {
            id: Some("prism_music_session".to_string()),
            size: Some([1, 10]),
        }),
        buttons: Some(vec![
            DiscordButton {
                label: "Слушать вместе".to_string(),
                url: listen_url,
            },
        ]),
    };

    client.set_activity(Some(activity))
}

#[tauri::command]
pub fn clear_discord_presence(state: tauri::State<'_, DiscordRpcState>) -> Result<(), String> {
    let mut client = state.lock().map_err(|e| e.to_string())?;
    client.clear_activity()
}

#[tauri::command]
pub fn set_discord_rpc_enabled(
    state: tauri::State<'_, DiscordRpcState>,
    enabled: bool,
) -> Result<(), String> {
    let mut client = state.lock().map_err(|e| e.to_string())?;
    client.is_enabled = enabled;
    if !enabled {
        let _ = client.clear_activity();
    }
    Ok(())
}

pub type LaunchUrlState = Arc<Mutex<Option<String>>>;

#[tauri::command]
pub fn get_launch_url(state: tauri::State<'_, LaunchUrlState>) -> Option<String> {
    let mut lock = state.lock().ok()?;
    lock.take()
}
