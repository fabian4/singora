use serde::{Deserialize, Serialize};
use thiserror::Error;
use time::OffsetDateTime;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PairRequest {
    pub client_id: String,
    pub client_name: String,
    pub device_name: Option<String>,
    pub user_hint: Option<String>,
    pub client_pubkey_fingerprint: String,
    pub request_origin: String,
    pub pair_timeout_sec: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PairResponse {
    pub session_id: Uuid,
    pub session_key: String,
    pub expire_at: OffsetDateTime,
    pub client_id: String,
    pub client_name: String,
    pub device_name: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TokenRequest {
    pub session_id: Uuid,
    pub provider: String,
    pub action: String,
    pub resource: String,
    pub credential_type: Option<String>,
    pub alias: Option<String>,
    pub ts: OffsetDateTime,
    pub nonce: String,
    pub mac: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TokenResponse {
    pub value: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PendingApproval {
    pub id: Uuid,
    pub request_kind: ApprovalKind,
    pub summary: String,
    pub risk_level: RiskLevel,
    pub created_at: OffsetDateTime,
    pub pair_details: Option<PairApprovalDetails>,
    pub token_details: Option<TokenApprovalDetails>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PairApprovalDetails {
    pub client_name: String,
    pub client_id: String,
    pub device_name: Option<String>,
    pub user_hint: Option<String>,
    pub fingerprint: String,
    pub origin: String,
    pub ttl: String,
    pub countdown: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TokenApprovalDetails {
    pub provider: String,
    pub action: String,
    pub resource: String,
    pub credential_type: String,
    pub alias: String,
    pub requesting_client: String,
    pub resource_context: String,
    pub policy_summary: String,
    pub audit_placeholder: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ApprovalKind {
    Pair,
    Token,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RiskLevel {
    Low,
    Medium,
    High,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApprovalDecisionRequest {
    pub approval_id: Uuid,
    pub approved: bool,
    pub note: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RevokeSessionRequest {
    pub session_id: Uuid,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RevokeSessionResponse {
    pub revoked: bool,
}

#[derive(Debug, Error)]
pub enum SigoraError {
    #[error("request was denied")]
    Denied,
    #[error("request timed out")]
    Timeout,
    #[error("session is invalid")]
    InvalidSession,
    #[error("type is ambiguous")]
    TypeAmbiguous,
    #[error("internal error: {0}")]
    Internal(String),
}
