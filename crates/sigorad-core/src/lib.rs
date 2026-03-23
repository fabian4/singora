use std::collections::HashMap;

use anyhow::Result;
use sigora_proto::{
    ApprovalDecisionRequest, ApprovalKind, PairApprovalDetails, PairRequest, PairResponse,
    PendingApproval, RiskLevel, TokenApprovalDetails, TokenRequest, TokenResponse,
};
use time::{Duration, OffsetDateTime};
use uuid::Uuid;

pub struct RuntimeState {
    pending: Vec<PendingApproval>,
    sessions: HashMap<Uuid, SessionState>,
    pending_pair_requests: HashMap<Uuid, PairRequest>,
    pending_token_requests: HashMap<Uuid, TokenRequest>,
    pair_outcomes: HashMap<Uuid, ApprovalOutcome>,
    token_outcomes: HashMap<Uuid, ApprovalOutcome>,
    session_ttl: Duration,
}

#[derive(Debug, Clone)]
struct SessionClient {
    client_id: String,
    client_name: String,
    device_name: Option<String>,
}

#[derive(Debug, Clone)]
struct SessionState {
    client: SessionClient,
    expire_at: OffsetDateTime,
}

#[derive(Debug, Clone)]
struct EvaluatedPolicy {
    decision: PolicyDecision,
    risk_level: RiskLevel,
    summary: String,
}

#[derive(Debug, Clone, Copy)]
enum PolicyDecision {
    Allow,
    Challenge,
    Deny,
}

#[derive(Debug)]
pub enum TokenRequestDisposition {
    Issued(TokenResponse),
    Pending(Uuid),
    Denied(String),
}

#[derive(Debug, Clone, Copy)]
pub enum ApprovalOutcome {
    Approved,
    Denied,
}

impl Default for RuntimeState {
    fn default() -> Self {
        Self {
            pending: Vec::new(),
            sessions: HashMap::new(),
            pending_pair_requests: HashMap::new(),
            pending_token_requests: HashMap::new(),
            pair_outcomes: HashMap::new(),
            token_outcomes: HashMap::new(),
            session_ttl: Duration::minutes(10),
        }
    }
}

impl RuntimeState {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn with_session_ttl(session_ttl: Duration) -> Self {
        Self {
            session_ttl,
            ..Self::default()
        }
    }

    pub fn enqueue_pairing(&mut self, request: PairRequest) -> Uuid {
        let approval_id = Uuid::new_v4();
        let approval = PendingApproval {
            id: approval_id,
            request_kind: ApprovalKind::Pair,
            summary: format!("Pair request from {} ({})", request.client_name, request.client_id),
            risk_level: RiskLevel::Low,
            created_at: OffsetDateTime::now_utc(),
            pair_details: Some(PairApprovalDetails {
                client_name: request.client_name.clone(),
                client_id: request.client_id.clone(),
                device_name: request.device_name.clone(),
                user_hint: request.user_hint.clone(),
                fingerprint: request.client_pubkey_fingerprint.clone(),
                origin: request.request_origin.clone(),
                ttl: "10 Minutes".to_string(),
                countdown: format!("{}:00", request.pair_timeout_sec.unwrap_or(60) / 60),
            }),
            token_details: None,
        };
        self.pending.push(approval);
        self.pending_pair_requests.insert(approval_id, request);
        approval_id
    }

    pub fn complete_pairing(&mut self, approval_id: Uuid) -> Result<PairResponse> {
        let request = self
            .pending_pair_requests
            .remove(&approval_id)
            .ok_or_else(|| anyhow::anyhow!("pair request is missing"))?;

        self.pair_outcomes.remove(&approval_id);
        let session_id = Uuid::new_v4();
        let expire_at = OffsetDateTime::now_utc() + self.session_ttl;
        self.sessions.insert(
            session_id,
            SessionState {
                client: SessionClient {
                client_id: request.client_id.clone(),
                client_name: request.client_name.clone(),
                device_name: request.device_name.clone(),
            },
                expire_at,
            },
        );

        Ok(PairResponse {
            session_id,
            session_key: "development-session-key".to_string(),
            expire_at,
            client_id: request.client_id,
            client_name: request.client_name,
            device_name: request.device_name,
        })
    }

    pub fn pending_approvals(&self) -> &[PendingApproval] {
        &self.pending
    }

    pub fn record_approval_decision(&mut self, request: ApprovalDecisionRequest) {
        self.pending.retain(|item| item.id != request.approval_id);
        if self.pending_pair_requests.contains_key(&request.approval_id) {
            let outcome = if request.approved {
                ApprovalOutcome::Approved
            } else {
                ApprovalOutcome::Denied
            };
            self.pair_outcomes.insert(request.approval_id, outcome);
        }
        if self.pending_token_requests.contains_key(&request.approval_id) {
            let outcome = if request.approved {
                ApprovalOutcome::Approved
            } else {
                ApprovalOutcome::Denied
            };
            self.token_outcomes.insert(request.approval_id, outcome);
        }
    }

    pub fn take_pair_outcome(&mut self, approval_id: Uuid) -> Option<ApprovalOutcome> {
        self.pair_outcomes.remove(&approval_id)
    }

    pub fn expire_pairing(&mut self, approval_id: Uuid) {
        self.pending.retain(|item| item.id != approval_id);
        self.pending_pair_requests.remove(&approval_id);
        self.pair_outcomes.remove(&approval_id);
    }

    pub fn enqueue_token_request(&mut self, request: TokenRequest) -> Result<TokenRequestDisposition> {
        let session_client = self.active_session_client(request.session_id)?;
        let alias = request.alias.clone().unwrap_or_else(|| "default".to_string());
        let credential_type = request
            .credential_type
            .clone()
            .unwrap_or_else(|| "auto".to_string());
        let policy = evaluate_token_policy(&session_client, &request, &alias);

        match policy.decision {
            PolicyDecision::Allow => Ok(TokenRequestDisposition::Issued(issued_token_response(
                &request.provider,
                alias,
            ))),
            PolicyDecision::Deny => Ok(TokenRequestDisposition::Denied(policy.summary)),
            PolicyDecision::Challenge => {
                let approval_id = Uuid::new_v4();
                let approval = PendingApproval {
                    id: approval_id,
                    request_kind: ApprovalKind::Token,
                    summary: format!(
                        "{} wants {} on {}",
                        session_client.client_name, request.action, request.resource
                    ),
                    risk_level: policy.risk_level,
                    created_at: OffsetDateTime::now_utc(),
                    pair_details: None,
                    token_details: Some(TokenApprovalDetails {
                        provider: request.provider.clone(),
                        action: request.action.clone(),
                        resource: request.resource.clone(),
                        credential_type,
                        alias: alias.clone(),
                        requesting_client: format!(
                            "{} ({})",
                            session_client.client_name, session_client.client_id
                        ),
                        resource_context: format!(
                            "{} on {} via {} alias={} device={}",
                            request.action,
                            request.resource,
                            request.provider,
                            alias,
                            session_client
                                .device_name
                                .clone()
                                .unwrap_or_else(|| "unknown".to_string())
                        ),
                        policy_summary: policy.summary,
                        audit_placeholder: "Add approval note for audit trail".to_string(),
                    }),
                };
                self.pending.push(approval);
                self.pending_token_requests.insert(approval_id, request);
                Ok(TokenRequestDisposition::Pending(approval_id))
            }
        }
    }

    pub fn take_token_outcome(&mut self, approval_id: Uuid) -> Option<ApprovalOutcome> {
        self.token_outcomes.remove(&approval_id)
    }

    pub fn complete_token_request(&mut self, approval_id: Uuid) -> Result<TokenResponse> {
        let request = self
            .pending_token_requests
            .remove(&approval_id)
            .ok_or_else(|| anyhow::anyhow!("token request is missing"))?;
        self.token_outcomes.remove(&approval_id);
        self.active_session_client(request.session_id)?;

        Ok(TokenResponse {
            value: issued_token_response(
                &request.provider,
                request.alias.unwrap_or_else(|| "default".to_string()),
            )
            .value,
        })
    }

    pub fn expire_token_request(&mut self, approval_id: Uuid) {
        self.pending.retain(|item| item.id != approval_id);
        self.pending_token_requests.remove(&approval_id);
        self.token_outcomes.remove(&approval_id);
    }

    pub fn revoke_session(&mut self, session_id: Uuid) -> bool {
        let revoked = self.sessions.remove(&session_id).is_some();
        if revoked {
            let revoked_pending_ids: Vec<Uuid> = self
                .pending_token_requests
                .iter()
                .filter_map(|(approval_id, request)| {
                    if request.session_id == session_id {
                        Some(*approval_id)
                    } else {
                        None
                    }
                })
                .collect();

            for approval_id in revoked_pending_ids {
                self.expire_token_request(approval_id);
            }
        }
        revoked
    }

    fn active_session_client(&mut self, session_id: Uuid) -> Result<SessionClient> {
        let session_state = self
            .sessions
            .get(&session_id)
            .cloned()
            .ok_or_else(|| anyhow::anyhow!("unknown session"))?;
        if session_state.expire_at <= OffsetDateTime::now_utc() {
            self.sessions.remove(&session_id);
            anyhow::bail!("expired session");
        }

        Ok(session_state.client)
    }
}

fn issued_token_response(provider: &str, alias: String) -> TokenResponse {
    TokenResponse {
        value: format!("sigora-dev-token:{}:{}", provider, alias),
    }
}

fn evaluate_token_policy(
    session_client: &SessionClient,
    request: &TokenRequest,
    alias: &str,
) -> EvaluatedPolicy {
    let provider = request.provider.to_ascii_lowercase();
    let action = request.action.to_ascii_lowercase();
    let resource = request.resource.to_ascii_lowercase();
    let alias_lower = alias.to_ascii_lowercase();

    if !matches!(
        provider.as_str(),
        "github" | "linear" | "openai" | "anthropic" | "aws"
    ) {
        return EvaluatedPolicy {
            decision: PolicyDecision::Deny,
            risk_level: RiskLevel::High,
            summary: format!(
                "Denied by policy: provider {} is not allowlisted for client {}.",
                request.provider, session_client.client_id
            ),
        };
    }

    if resource == "*" || resource.contains("production") || resource.contains("/prod") {
        if is_privileged_action(&action) {
            return EvaluatedPolicy {
                decision: PolicyDecision::Deny,
                risk_level: RiskLevel::High,
                summary: format!(
                    "Denied by policy: {} on {} requires an explicit scoped grant and cannot target production or wildcard resources.",
                    request.action, request.resource
                ),
            };
        }
    }

    if alias_lower == "root" || alias_lower == "admin" {
        return EvaluatedPolicy {
            decision: PolicyDecision::Challenge,
            risk_level: RiskLevel::High,
            summary: format!(
                "Challenge by policy: alias {} is privileged, so {} must be approved interactively for {}.",
                alias, request.action, session_client.client_id
            ),
        };
    }

    if is_read_only_action(&action) && is_scoped_resource(&resource) {
        return EvaluatedPolicy {
            decision: PolicyDecision::Allow,
            risk_level: RiskLevel::Low,
            summary: format!(
                "Allowed by policy: read-only action {} on scoped resource {} for client {}.",
                request.action, request.resource, session_client.client_id
            ),
        };
    }

    if is_privileged_action(&action) || resource.contains("admin") || resource.contains("secret") {
        return EvaluatedPolicy {
            decision: PolicyDecision::Challenge,
            risk_level: RiskLevel::High,
            summary: format!(
                "Challenge by policy: {} on {} is sensitive and requires user approval for client {}.",
                request.action, request.resource, session_client.client_id
            ),
        };
    }

    EvaluatedPolicy {
        decision: PolicyDecision::Challenge,
        risk_level: RiskLevel::Medium,
        summary: format!(
            "Challenge by policy: {} may access {} via {} after interactive approval.",
            session_client.client_id, request.resource, request.provider
        ),
    }
}

fn is_read_only_action(action: &str) -> bool {
    matches!(
        action,
        "read" | "list" | "get" | "view" | "metadata.read" | "repo.read"
    ) || action.ends_with(".read")
}

fn is_privileged_action(action: &str) -> bool {
    matches!(
        action,
        "write" | "delete" | "admin" | "rotate" | "publish" | "deploy"
    ) || action.ends_with(".write")
        || action.ends_with(".delete")
        || action.ends_with(".admin")
}

fn is_scoped_resource(resource: &str) -> bool {
    !resource.is_empty() && resource != "*" && !resource.ends_with("/*")
}

#[cfg(test)]
mod tests {
    use super::*;
    use time::OffsetDateTime;

    fn session_client() -> SessionClient {
        SessionClient {
            client_id: "agent.dev".to_string(),
            client_name: "Dev Agent".to_string(),
            device_name: Some("Fabian MBP".to_string()),
        }
    }

    fn token_request(provider: &str, action: &str, resource: &str) -> TokenRequest {
        TokenRequest {
            session_id: Uuid::new_v4(),
            provider: provider.to_string(),
            action: action.to_string(),
            resource: resource.to_string(),
            credential_type: Some("bearer_token".to_string()),
            alias: Some("default".to_string()),
            ts: OffsetDateTime::now_utc(),
            nonce: "nonce".to_string(),
            mac: "dev-mac".to_string(),
        }
    }

    #[test]
    fn allows_scoped_read_only_requests() {
        let policy = evaluate_token_policy(
            &session_client(),
            &token_request("github", "repo.read", "sigora/core"),
            "default",
        );

        assert!(matches!(policy.decision, PolicyDecision::Allow));
        assert!(matches!(policy.risk_level, RiskLevel::Low));
    }

    #[test]
    fn denies_production_privileged_requests() {
        let policy = evaluate_token_policy(
            &session_client(),
            &token_request("github", "deploy", "production/api"),
            "default",
        );

        assert!(matches!(policy.decision, PolicyDecision::Deny));
        assert!(matches!(policy.risk_level, RiskLevel::High));
    }

    #[test]
    fn challenges_sensitive_but_known_requests() {
        let policy = evaluate_token_policy(
            &session_client(),
            &token_request("aws", "secrets.read", "team/backend"),
            "admin",
        );

        assert!(matches!(policy.decision, PolicyDecision::Challenge));
        assert!(matches!(policy.risk_level, RiskLevel::High));
    }

    #[test]
    fn rejects_expired_sessions() {
        let mut runtime = RuntimeState::with_session_ttl(Duration::seconds(-1));
        let approval_id = runtime.enqueue_pairing(PairRequest {
            client_id: "agent.dev".to_string(),
            client_name: "Dev Agent".to_string(),
            device_name: Some("Fabian MBP".to_string()),
            user_hint: Some("fabian".to_string()),
            client_pubkey_fingerprint: "dev-fingerprint".to_string(),
            request_origin: "127.0.0.1".to_string(),
            pair_timeout_sec: Some(60),
        });
        let response = runtime.complete_pairing(approval_id).expect("pair succeeds");

        let error = runtime
            .enqueue_token_request(TokenRequest {
                session_id: response.session_id,
                provider: "github".to_string(),
                action: "repo.read".to_string(),
                resource: "sigora/core".to_string(),
                credential_type: Some("bearer_token".to_string()),
                alias: Some("default".to_string()),
                ts: OffsetDateTime::now_utc(),
                nonce: "nonce".to_string(),
                mac: "dev-mac".to_string(),
            })
            .expect_err("session should be expired");

        assert!(error.to_string().contains("expired session"));
    }

    #[test]
    fn revoked_sessions_can_no_longer_fetch_tokens() {
        let mut runtime = RuntimeState::new();
        let approval_id = runtime.enqueue_pairing(PairRequest {
            client_id: "agent.dev".to_string(),
            client_name: "Dev Agent".to_string(),
            device_name: Some("Fabian MBP".to_string()),
            user_hint: Some("fabian".to_string()),
            client_pubkey_fingerprint: "dev-fingerprint".to_string(),
            request_origin: "127.0.0.1".to_string(),
            pair_timeout_sec: Some(60),
        });
        let response = runtime.complete_pairing(approval_id).expect("pair succeeds");
        assert!(runtime.revoke_session(response.session_id));

        let error = runtime
            .enqueue_token_request(TokenRequest {
                session_id: response.session_id,
                provider: "github".to_string(),
                action: "repo.read".to_string(),
                resource: "sigora/core".to_string(),
                credential_type: Some("bearer_token".to_string()),
                alias: Some("default".to_string()),
                ts: OffsetDateTime::now_utc(),
                nonce: "nonce".to_string(),
                mac: "dev-mac".to_string(),
            })
            .expect_err("revoked session should be rejected");

        assert!(error.to_string().contains("unknown session"));
    }
}
