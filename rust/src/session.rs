use std::collections::HashMap;
use std::sync::Arc;
use std::sync::OnceLock;
use tokio::sync::{mpsc, RwLock};
use russh::client::{self, Config, Handler};
use russh::keys::PublicKeyOrCertificate;
use russh::keys::PrivateKey;
use russh::ChannelMsg;

use crate::frb_generated::StreamSink;

#[derive(Clone, Debug)]
pub struct SshConnectConfig {
    pub host: String,
    pub port: u16,
    pub username: String,
    pub auth_type: String, // "password" or "key"
    pub password: Option<String>,
    pub private_key: Option<String>,
    pub passphrase: Option<String>,
    pub cols: u32,
    pub rows: u32,
}

#[derive(Clone, Debug)]
pub struct SessionEvent {
    pub session_id: String,
    pub event_type: String, // "connected", "data", "error", "closed"
    pub data: Vec<u8>,
    pub message: Option<String>,
}

struct ClientHandler {}

impl Handler for ClientHandler {
    type Error = russh::Error;

    async fn check_server_key(
        &mut self,
        _server_public_key: &PublicKeyOrCertificate,
    ) -> Result<bool, Self::Error> {
        // Accept host key (in future can check known_hosts)
        Ok(true)
    }
}

pub struct SessionHandle {
    pub stdin_tx: mpsc::UnboundedSender<Vec<u8>>,
    pub resize_tx: mpsc::UnboundedSender<(u32, u32)>,
    pub close_tx: mpsc::Sender<()>,
}

fn active_sessions() -> &'static RwLock<HashMap<String, SessionHandle>> {
    static SESSIONS: OnceLock<RwLock<HashMap<String, SessionHandle>>> = OnceLock::new();
    SESSIONS.get_or_init(|| RwLock::new(HashMap::new()))
}

pub async fn start_ssh_session(
    session_id: String,
    config: SshConnectConfig,
    sink: StreamSink<SessionEvent>,
) -> Result<(), String> {
    let ssh_config = Arc::new(Config {
        inactivity_timeout: Some(std::time::Duration::from_secs(60)),
        ..Config::default()
    });

    let addr = (config.host.as_str(), config.port);
    let mut session = client::connect(ssh_config, addr, ClientHandler {})
        .await
        .map_err(|e| format!("Connection to {}:{} failed: {}", config.host, config.port, e))?;

    // Authenticate
    let auth_ok = match config.auth_type.to_lowercase().as_str() {
        "password" => {
            let pwd = config.password.unwrap_or_default();
            session
                .authenticate_password(&config.username, &pwd)
                .await
                .map_err(|e| format!("Password authentication failed: {}", e))?
        }
        "key" => {
            let key_str = config.private_key.ok_or("Private key is required for key auth")?;
            let raw_key = PrivateKey::from_openssh(&key_str)
                .map_err(|e| format!("Failed to parse private key: {}", e))?;
            
            let key = if raw_key.is_encrypted() {
                let pass = config.passphrase.ok_or("Private key is encrypted with passphrase")?;
                raw_key.decrypt(&pass).map_err(|e| format!("Key decryption failed: {}", e))?
            } else {
                raw_key
            };

            session
                .authenticate_publickey(
                    &config.username,
                    russh::keys::PrivateKeyWithHashAlg::new(Arc::new(key), None),
                )
                .await
                .map_err(|e| format!("Key authentication failed: {}", e))?
        }
        other => return Err(format!("Unsupported auth type: {}", other)),
    };

    let is_auth_success = matches!(auth_ok, russh::client::AuthResult::Success);
    if !is_auth_success {
        return Err("Authentication failed: Access denied by remote host".to_string());
    }

    // Open channel & request pty + shell
    let mut channel = session
        .channel_open_session()
        .await
        .map_err(|e| format!("Failed to open session channel: {}", e))?;

    channel
        .request_pty(
            false,
            "xterm-256color",
            config.cols.max(10),
            config.rows.max(5),
            0,
            0,
            &[],
        )
        .await
        .map_err(|e| format!("Failed to request PTY: {}", e))?;

    channel
        .request_shell(true)
        .await
        .map_err(|e| format!("Failed to request shell: {}", e))?;

    let (stdin_tx, mut stdin_rx) = mpsc::unbounded_channel::<Vec<u8>>();
    let (resize_tx, mut resize_rx) = mpsc::unbounded_channel::<(u32, u32)>();
    let (close_tx, mut close_rx) = mpsc::channel::<()>(1);

    // Save session handle
    {
        let mut sessions = active_sessions().write().await;
        sessions.insert(
            session_id.clone(),
            SessionHandle {
                stdin_tx,
                resize_tx,
                close_tx,
            },
        );
    }

    // Notify connected
    let _ = sink.add(SessionEvent {
        session_id: session_id.clone(),
        event_type: "connected".to_string(),
        data: Vec::new(),
        message: Some(format!("Connected to {}@{}:{}", config.username, config.host, config.port)),
    });

    let s_id = session_id.clone();
    tokio::spawn(async move {
        loop {
            tokio::select! {
                // Incoming terminal data from SSH server
                msg = channel.wait() => {
                    match msg {
                        Some(ChannelMsg::Data { ref data }) => {
                            if sink.add(SessionEvent {
                                session_id: s_id.clone(),
                                event_type: "data".to_string(),
                                data: data.to_vec(),
                                message: None,
                            }).is_err() {
                                break;
                            }
                        }
                        Some(ChannelMsg::ExtendedData { ref data, .. }) => {
                            if sink.add(SessionEvent {
                                session_id: s_id.clone(),
                                event_type: "data".to_string(),
                                data: data.to_vec(),
                                message: None,
                            }).is_err() {
                                break;
                            }
                        }
                        Some(ChannelMsg::Eof) | Some(ChannelMsg::Close) | None => {
                            let _ = sink.add(SessionEvent {
                                session_id: s_id.clone(),
                                event_type: "closed".to_string(),
                                data: Vec::new(),
                                message: Some("Session closed by remote server".to_string()),
                            });
                            break;
                        }
                        _ => {}
                    }
                }
                // Stdin data from Flutter
                Some(data) = stdin_rx.recv() => {
                    if let Err(e) = channel.data(&data[..]).await {
                        let _ = sink.add(SessionEvent {
                            session_id: s_id.clone(),
                            event_type: "error".to_string(),
                            data: Vec::new(),
                            message: Some(format!("Failed to write stdin: {}", e)),
                        });
                        break;
                    }
                }
                // PTY window resize
                Some((cols, rows)) = resize_rx.recv() => {
                    let _ = channel.window_change(cols, rows, 0, 0).await;
                }
                // Close signal
                _ = close_rx.recv() => {
                    let _ = channel.eof().await;
                    let _ = channel.close().await;
                    break;
                }
            }
        }

        // Cleanup
        let mut sessions = active_sessions().write().await;
        sessions.remove(&s_id);
    });

    Ok(())
}

pub async fn write_stdin(session_id: &str, data: Vec<u8>) -> Result<(), String> {
    let sessions = active_sessions().read().await;
    if let Some(handle) = sessions.get(session_id) {
        handle
            .stdin_tx
            .send(data)
            .map_err(|e| format!("Failed to send to stdin: {}", e))?;
        Ok(())
    } else {
        Err(format!("Session {} not found", session_id))
    }
}

pub async fn resize_pty(session_id: &str, cols: u32, rows: u32) -> Result<(), String> {
    let sessions = active_sessions().read().await;
    if let Some(handle) = sessions.get(session_id) {
        let _ = handle.resize_tx.send((cols, rows));
        Ok(())
    } else {
        Err(format!("Session {} not found", session_id))
    }
}

pub async fn close_session(session_id: &str) -> Result<(), String> {
    let mut sessions = active_sessions().write().await;
    if let Some(handle) = sessions.remove(session_id) {
        let _ = handle.close_tx.send(()).await;
        Ok(())
    } else {
        Err(format!("Session {} not found", session_id))
    }
}
