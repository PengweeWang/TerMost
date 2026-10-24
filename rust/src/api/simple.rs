use crate::forwarding::{self, PortForwardConfig, TunnelEvent};
use crate::frb_generated::StreamSink;
use crate::keys::{self, KeyGenResult};
use crate::session::{self, SessionEvent, SshConnectConfig};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TunnelStats {
    pub bytes_up: u64,
    pub bytes_down: u64,
    pub is_running: bool,
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

// ---------------- Key Management API ----------------

#[flutter_rust_bridge::frb(sync)]
pub fn generate_key_pair(
    algorithm: String,
    comment: String,
    passphrase: Option<String>,
) -> Result<KeyGenResult, String> {
    keys::generate_key(&algorithm, &comment, passphrase.as_deref())
}

#[flutter_rust_bridge::frb(sync)]
pub fn parse_key_pair(
    private_key_openssh: String,
    passphrase: Option<String>,
) -> Result<KeyGenResult, String> {
    keys::parse_key(&private_key_openssh, passphrase.as_deref())
}

// ---------------- SSH Terminal Session API ----------------

pub async fn start_session(
    session_id: String,
    config: SshConnectConfig,
    sink: StreamSink<SessionEvent>,
) -> Result<(), String> {
    session::start_ssh_session(session_id, config, sink).await
}

pub async fn write_session_stdin(session_id: String, data: Vec<u8>) -> Result<(), String> {
    session::write_stdin(&session_id, data).await
}

pub async fn resize_session_pty(session_id: String, cols: u32, rows: u32) -> Result<(), String> {
    session::resize_pty(&session_id, cols, rows).await
}

pub async fn close_session_by_id(session_id: String) -> Result<(), String> {
    session::close_session(&session_id).await
}

// ---------------- Port Forwarding API ----------------

pub async fn start_port_forwarding(
    config: PortForwardConfig,
    sink: StreamSink<TunnelEvent>,
) -> Result<(), String> {
    forwarding::start_tunnel(config, sink).await
}

pub async fn stop_port_forwarding(tunnel_id: String) -> Result<(), String> {
    forwarding::stop_tunnel(&tunnel_id).await
}

pub async fn get_forwarding_stats(tunnel_id: String) -> Result<TunnelStats, String> {
    let (up, down, running) = forwarding::get_tunnel_stats(&tunnel_id).await?;
    Ok(TunnelStats {
        bytes_up: up,
        bytes_down: down,
        is_running: running,
    })
}
