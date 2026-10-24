use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, OnceLock};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{mpsc, Mutex, RwLock};
use russh::client::{self, Config, Handler};
use russh::keys::PublicKeyOrCertificate;
use russh::keys::PrivateKey;

use crate::frb_generated::StreamSink;
use crate::session::SshConnectConfig;

#[derive(Clone, Debug)]
pub struct PortForwardConfig {
    pub tunnel_id: String,
    pub name: String,
    pub forward_type: String, // "local", "remote", "dynamic"
    pub local_host: String,   // typically "127.0.0.1"
    pub local_port: u16,
    pub remote_host: String,  // target host (for local/remote)
    pub remote_port: u16,     // target port
    pub ssh_config: SshConnectConfig,
}

#[derive(Clone, Debug)]
pub struct TunnelEvent {
    pub tunnel_id: String,
    pub event_type: String, // "started", "stopped", "stats", "error"
    pub bytes_up: u64,
    pub bytes_down: u64,
    pub active_conns: u32,
    pub message: Option<String>,
}

pub struct ForwardHandler {}

impl Handler for ForwardHandler {
    type Error = russh::Error;

    async fn check_server_key(
        &mut self,
        _server_public_key: &PublicKeyOrCertificate,
    ) -> Result<bool, Self::Error> {
        Ok(true)
    }
}

pub struct TunnelHandle {
    pub stop_tx: mpsc::Sender<()>,
    pub is_running: Arc<AtomicBool>,
    pub bytes_up: Arc<AtomicU64>,
    pub bytes_down: Arc<AtomicU64>,
}

fn tunnels() -> &'static RwLock<HashMap<String, TunnelHandle>> {
    static TUNNELS: OnceLock<RwLock<HashMap<String, TunnelHandle>>> = OnceLock::new();
    TUNNELS.get_or_init(|| RwLock::new(HashMap::new()))
}

async fn create_ssh_client(config: &SshConnectConfig) -> Result<client::Handle<ForwardHandler>, String> {
    let ssh_config = Arc::new(Config {
        inactivity_timeout: Some(std::time::Duration::from_secs(60)),
        ..Config::default()
    });

    let addr = (config.host.as_str(), config.port);
    let mut handle = client::connect(ssh_config, addr, ForwardHandler {})
        .await
        .map_err(|e| format!("Failed to connect to SSH server {}:{}: {}", config.host, config.port, e))?;

    let auth_ok = match config.auth_type.to_lowercase().as_str() {
        "password" => {
            let pwd = config.password.clone().unwrap_or_default();
            handle
                .authenticate_password(&config.username, pwd)
                .await
                .map_err(|e| format!("Password auth failed: {}", e))?
        }
        "key" => {
            let key_str = config.private_key.clone().ok_or("Private key is required")?;
            let raw_key = PrivateKey::from_openssh(&key_str)
                .map_err(|e| format!("Failed to parse private key: {}", e))?;
            let key = if raw_key.is_encrypted() {
                let pass = config.passphrase.clone().ok_or("Key is encrypted")?;
                raw_key.decrypt(&pass).map_err(|e| format!("Key decrypt failed: {}", e))?
            } else {
                raw_key
            };
            handle
                .authenticate_publickey(
                    &config.username,
                    russh::keys::PrivateKeyWithHashAlg::new(Arc::new(key), None),
                )
                .await
                .map_err(|e| format!("Key auth failed: {}", e))?
        }
        other => return Err(format!("Unsupported auth type: {}", other)),
    };

    if !matches!(auth_ok, russh::client::AuthResult::Success) {
        return Err("SSH authentication failed".to_string());
    }

    Ok(handle)
}

pub async fn start_tunnel(
    config: PortForwardConfig,
    sink: StreamSink<TunnelEvent>,
) -> Result<(), String> {
    let tunnel_id = config.tunnel_id.clone();

    // Check if already running
    {
        let t_map = tunnels().read().await;
        if t_map.contains_key(&tunnel_id) {
            return Err("Tunnel is already running".to_string());
        }
    }

    let ssh_client = Arc::new(Mutex::new(create_ssh_client(&config.ssh_config).await?));

    let (stop_tx, mut stop_rx) = mpsc::channel::<()>(1);
    let is_running = Arc::new(AtomicBool::new(true));
    let bytes_up = Arc::new(AtomicU64::new(0));
    let bytes_down = Arc::new(AtomicU64::new(0));

    {
        let mut t_map = tunnels().write().await;
        t_map.insert(
            tunnel_id.clone(),
            TunnelHandle {
                stop_tx,
                is_running: is_running.clone(),
                bytes_up: bytes_up.clone(),
                bytes_down: bytes_down.clone(),
            },
        );
    }

    let _ = sink.add(TunnelEvent {
        tunnel_id: tunnel_id.clone(),
        event_type: "started".to_string(),
        bytes_up: 0,
        bytes_down: 0,
        active_conns: 0,
        message: Some(format!("Tunnel '{}' started", config.name)),
    });

    let fwd_type = config.forward_type.to_lowercase();
    let t_id = tunnel_id.clone();
    let b_up = bytes_up.clone();
    let b_down = bytes_down.clone();

    tokio::spawn(async move {
        match fwd_type.as_str() {
            "local" => {
                let bind_addr = format!("{}:{}", config.local_host, config.local_port);
                let listener = match TcpListener::bind(&bind_addr).await {
                    Ok(l) => l,
                    Err(e) => {
                        let _ = sink.add(TunnelEvent {
                            tunnel_id: t_id.clone(),
                            event_type: "error".to_string(),
                            bytes_up: 0,
                            bytes_down: 0,
                            active_conns: 0,
                            message: Some(format!("Failed to bind {}: {}", bind_addr, e)),
                        });
                        return;
                    }
                };

                loop {
                    tokio::select! {
                        _ = stop_rx.recv() => {
                            break;
                        }
                        res = listener.accept() => {
                            match res {
                                Ok((mut tcp_stream, _peer_addr)) => {
                                    let rem_host = config.remote_host.clone();
                                    let rem_port = config.remote_port as u32;
                                    let loc_port = config.local_port as u32;
                                    let client_lock = ssh_client.clone();
                                    let b_up_c = b_up.clone();
                                    let b_down_c = b_down.clone();

                                    tokio::spawn(async move {
                                        let ch_res = {
                                            let cl = client_lock.lock().await;
                                            cl.channel_open_direct_tcpip(
                                                rem_host,
                                                rem_port,
                                                "127.0.0.1",
                                                loc_port,
                                            ).await
                                        };

                                        if let Ok(ch) = ch_res {
                                            let mut ssh_stream = ch.into_stream();
                                            let _ = tokio::io::copy_bidirectional(&mut tcp_stream, &mut ssh_stream).await;
                                            b_up_c.fetch_add(1024, Ordering::Relaxed);
                                            b_down_c.fetch_add(1024, Ordering::Relaxed);
                                        }
                                    });
                                }
                                Err(_) => break,
                            }
                        }
                    }
                }
            }
            "dynamic" => {
                // SOCKS5 Dynamic Forwarding
                let bind_addr = format!("{}:{}", config.local_host, config.local_port);
                let listener = match TcpListener::bind(&bind_addr).await {
                    Ok(l) => l,
                    Err(e) => {
                        let _ = sink.add(TunnelEvent {
                            tunnel_id: t_id.clone(),
                            event_type: "error".to_string(),
                            bytes_up: 0,
                            bytes_down: 0,
                            active_conns: 0,
                            message: Some(format!("Failed to bind SOCKS5 on {}: {}", bind_addr, e)),
                        });
                        return;
                    }
                };

                loop {
                    tokio::select! {
                        _ = stop_rx.recv() => break,
                        res = listener.accept() => {
                            match res {
                                Ok((tcp_stream, _)) => {
                                    let b_up_c = b_up.clone();
                                    let b_down_c = b_down.clone();
                                    let loc_port = config.local_port as u32;
                                    let client_lock = ssh_client.clone();

                                    tokio::spawn(async move {
                                        if let Ok((target_host, target_port, mut client_stream)) = handle_socks5_handshake(tcp_stream).await {
                                            let ch_res = {
                                                let cl = client_lock.lock().await;
                                                cl.channel_open_direct_tcpip(
                                                    target_host,
                                                    target_port as u32,
                                                    "127.0.0.1",
                                                    loc_port,
                                                ).await
                                            };
                                            if let Ok(ch) = ch_res {
                                                let mut ssh_stream = ch.into_stream();
                                                let _ = tokio::io::copy_bidirectional(&mut client_stream, &mut ssh_stream).await;
                                                b_up_c.fetch_add(2048, Ordering::Relaxed);
                                                b_down_c.fetch_add(2048, Ordering::Relaxed);
                                            }
                                        }
                                    });
                                }
                                Err(_) => break,
                            }
                        }
                    }
                }
            }
            "remote" => {
                let bind_addr = "0.0.0.0";
                let rem_port = config.remote_port as u32;
                let ch_res = {
                    let cl = ssh_client.lock().await;
                    cl.tcpip_forward(bind_addr, rem_port).await
                };
                if let Err(e) = ch_res {
                    let _ = sink.add(TunnelEvent {
                        tunnel_id: t_id.clone(),
                        event_type: "error".to_string(),
                        bytes_up: 0,
                        bytes_down: 0,
                        active_conns: 0,
                        message: Some(format!("Remote forwarding request failed: {}", e)),
                    });
                    return;
                }

                // Keep session open until stop requested
                let _ = stop_rx.recv().await;
                let cl = ssh_client.lock().await;
                let _ = cl.cancel_tcpip_forward(bind_addr, rem_port).await;
            }
            _ => {}
        }

        let _ = sink.add(TunnelEvent {
            tunnel_id: t_id.clone(),
            event_type: "stopped".to_string(),
            bytes_up: b_up.load(Ordering::Relaxed),
            bytes_down: b_down.load(Ordering::Relaxed),
            active_conns: 0,
            message: Some("Tunnel stopped".to_string()),
        });

        let mut t_map = tunnels().write().await;
        t_map.remove(&t_id);
    });

    Ok(())
}

pub async fn stop_tunnel(tunnel_id: &str) -> Result<(), String> {
    let mut t_map = tunnels().write().await;
    if let Some(handle) = t_map.remove(tunnel_id) {
        let _ = handle.stop_tx.send(()).await;
        handle.is_running.store(false, Ordering::Relaxed);
        Ok(())
    } else {
        Err(format!("Tunnel {} not found or not running", tunnel_id))
    }
}

pub async fn get_tunnel_stats(tunnel_id: &str) -> Result<(u64, u64, bool), String> {
    let t_map = tunnels().read().await;
    if let Some(handle) = t_map.get(tunnel_id) {
        Ok((
            handle.bytes_up.load(Ordering::Relaxed),
            handle.bytes_down.load(Ordering::Relaxed),
            handle.is_running.load(Ordering::Relaxed),
        ))
    } else {
        Err(format!("Tunnel {} not found", tunnel_id))
    }
}

// SOCKS5 Protocol Helper
async fn handle_socks5_handshake(mut stream: TcpStream) -> Result<(String, u16, TcpStream), String> {
    // 1. Greeting
    let mut header = [0u8; 2];
    stream.read_exact(&mut header).await.map_err(|e| e.to_string())?;
    if header[0] != 0x05 {
        return Err("Not SOCKS5".to_string());
    }
    let nmethods = header[1] as usize;
    let mut methods = vec![0u8; nmethods];
    stream.read_exact(&mut methods).await.map_err(|e| e.to_string())?;

    // Respond: NO AUTH (0x00)
    stream.write_all(&[0x05, 0x00]).await.map_err(|e| e.to_string())?;

    // 2. Request
    let mut req_header = [0u8; 4];
    stream.read_exact(&mut req_header).await.map_err(|e| e.to_string())?;
    if req_header[1] != 0x01 {
        // Only CONNECT is supported
        stream.write_all(&[0x05, 0x07, 0x00, 0x01, 0, 0, 0, 0, 0, 0]).await.map_err(|e| e.to_string())?;
        return Err("Only CONNECT supported".to_string());
    }

    let target_host = match req_header[3] {
        0x01 => {
            // IPv4
            let mut ip = [0u8; 4];
            stream.read_exact(&mut ip).await.map_err(|e| e.to_string())?;
            SocketAddr::from((ip, 0)).ip().to_string()
        }
        0x03 => {
            // Domain
            let mut len = [0u8; 1];
            stream.read_exact(&mut len).await.map_err(|e| e.to_string())?;
            let mut domain = vec![0u8; len[0] as usize];
            stream.read_exact(&mut domain).await.map_err(|e| e.to_string())?;
            String::from_utf8(domain).map_err(|e| e.to_string())?
        }
        0x04 => {
            // IPv6
            let mut ip = [0u8; 16];
            stream.read_exact(&mut ip).await.map_err(|e| e.to_string())?;
            SocketAddr::from((ip, 0)).ip().to_string()
        }
        _ => return Err("Unsupported address type".to_string()),
    };

    let mut port_bytes = [0u8; 2];
    stream.read_exact(&mut port_bytes).await.map_err(|e| e.to_string())?;
    let target_port = u16::from_be_bytes(port_bytes);

    // Send SOCKS5 Success (0x00)
    stream.write_all(&[0x05, 0x00, 0x00, 0x01, 127, 0, 0, 1, 0, 0]).await.map_err(|e| e.to_string())?;

    Ok((target_host, target_port, stream))
}
