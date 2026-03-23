use anyhow::Result;
use clap::{Parser, Subcommand};
use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};
use sigora_proto::{PairRequest, PairResponse, TokenRequest, TokenResponse};
use std::{
    env, fs,
    path::{Path, PathBuf},
};
use time::OffsetDateTime;
use uuid::Uuid;

#[derive(Debug, Parser)]
#[command(name = "sigora")]
#[command(about = "Sigora client CLI", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    Pair,
    Token {
        #[arg(long)]
        provider: String,
        #[arg(long)]
        action: String,
        #[arg(long)]
        resource: String,
        #[arg(long = "type")]
        credential_type: Option<String>,
        #[arg(long)]
        alias: Option<String>,
    },
}

#[derive(Debug, Serialize, Deserialize)]
struct SessionConfig {
    session_id: Uuid,
    session_key: String,
    expire_at: OffsetDateTime,
    client_id: String,
    client_name: String,
    device_name: Option<String>,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let base_url = env::var("SIGORA_BASE_URL").unwrap_or_else(|_| "http://127.0.0.1:8611".to_string());
    match cli.command {
        Command::Pair => {
            let client = Client::new();
            let client_id = "local-cli".to_string();
            let client_name = "sigora".to_string();
            let device_name = Some("development-machine".to_string());
            let response = client
                .post(format!("{base_url}/pair"))
                .json(&PairRequest {
                    client_id: client_id.clone(),
                    client_name: client_name.clone(),
                    device_name: device_name.clone(),
                    user_hint: env::var("USER").ok(),
                    client_pubkey_fingerprint: "dev-fingerprint".to_string(),
                    request_origin: "127.0.0.1".to_string(),
                    pair_timeout_sec: Some(60),
                })
                .send()?
                .error_for_status()?
                .json::<PairResponse>()?;

            persist_session(&SessionConfig {
                session_id: response.session_id,
                session_key: response.session_key.clone(),
                expire_at: response.expire_at,
                client_id: response.client_id,
                client_name: response.client_name,
                device_name: response.device_name,
            })?;

            println!("paired");
            println!("session_id={}", response.session_id);
            println!("expire_at={}", response.expire_at);
        }
        Command::Token {
            provider,
            action,
            resource,
            credential_type,
            alias,
        } => {
            let session = load_session()?;
            let alias = alias.unwrap_or_else(|| "default".to_string());
            let payload = format!(
                "{}|{}|{}|{}|{}|{}|{}|{}",
                session.session_id,
                provider,
                action,
                resource,
                credential_type.clone().unwrap_or_default(),
                alias,
                OffsetDateTime::now_utc().unix_timestamp(),
                "dev-nonce"
            );

            let client = Client::new();
            let response = client
                .post(format!("{base_url}/token"))
                .json(&TokenRequest {
                    session_id: session.session_id,
                    provider,
                    action,
                    resource,
                    credential_type,
                    alias: Some(alias),
                    ts: OffsetDateTime::now_utc(),
                    nonce: "dev-nonce".to_string(),
                    mac: payload,
                })
                .send()?
                .error_for_status()?
                .json::<TokenResponse>()?;

            println!("{}", response.value);
        }
    }
    Ok(())
}

fn persist_session(session: &SessionConfig) -> Result<()> {
    let path = session_path()?;
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, serde_json::to_vec_pretty(session)?)?;
    Ok(())
}

fn load_session() -> Result<SessionConfig> {
    let data = fs::read(session_path()?)?;
    Ok(serde_json::from_slice(&data)?)
}

fn session_path() -> Result<PathBuf> {
    let home = env::var("HOME")?;
    Ok(Path::new(&home).join(".sigora").join("session.json"))
}
