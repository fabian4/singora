use std::{
    env,
    net::SocketAddr,
    sync::{Arc, Mutex},
};

use axum::{
    extract::Path,
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use sigora_proto::{
    ApprovalDecisionRequest, PairRequest, RevokeSessionRequest, RevokeSessionResponse, TokenRequest,
};
use sigorad_core::{ApprovalOutcome, RuntimeState, TokenRequestDisposition};
use time::Duration;
use tracing::info;
use uuid::Uuid;

type SharedState = Arc<Mutex<RuntimeState>>;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt().with_env_filter("info").init();

    let session_ttl_sec = env::var("SIGORAD_SESSION_TTL_SEC")
        .ok()
        .and_then(|value| value.parse::<i64>().ok())
        .unwrap_or(600);
    let state = Arc::new(Mutex::new(RuntimeState::with_session_ttl(
        Duration::seconds(session_ttl_sec),
    )));
    let app = Router::new()
        .route("/health", get(health))
        .route("/pair", post(pair))
        .route("/token", post(token))
        .route("/revoke/session", post(revoke_session))
        .route("/revoke/session/{session_id}", post(revoke_session_path))
        .route("/ui/pending", get(pending))
        .route("/ui/decision", post(record_decision))
        .with_state(state);

    let bind_addr = env::var("SIGORAD_BIND_ADDR").unwrap_or_else(|_| "127.0.0.1:8611".to_string());
    let addr: SocketAddr = bind_addr.parse()?;
    let listener = tokio::net::TcpListener::bind(addr).await?;
    info!("sigorad-server listening on http://{}", addr);
    axum::serve(listener, app).await?;
    Ok(())
}

async fn health() -> &'static str {
    "ok"
}

async fn pair(State(state): State<SharedState>, Json(request): Json<PairRequest>) -> impl IntoResponse {
    let timeout_sec = request.pair_timeout_sec.unwrap_or(60);
    let approval_id = state.lock().expect("runtime state").enqueue_pairing(request);

    let started = tokio::time::Instant::now();
    let deadline = tokio::time::Duration::from_secs(timeout_sec);

    loop {
        let outcome = state
            .lock()
            .expect("runtime state")
            .take_pair_outcome(approval_id);

        match outcome {
            Some(ApprovalOutcome::Approved) => {
                let response = state
                    .lock()
                    .expect("runtime state")
                    .complete_pairing(approval_id)
                    .expect("pairing response");
                return (StatusCode::OK, Json(response)).into_response();
            }
            Some(ApprovalOutcome::Denied) => {
                state.lock().expect("runtime state").expire_pairing(approval_id);
                return (StatusCode::FORBIDDEN, "pair request denied").into_response();
            }
            None => {}
        }

        if started.elapsed() >= deadline {
            state.lock().expect("runtime state").expire_pairing(approval_id);
            return (StatusCode::REQUEST_TIMEOUT, "pair request timed out").into_response();
        }

        tokio::time::sleep(tokio::time::Duration::from_millis(250)).await;
    }
}

async fn pending(State(state): State<SharedState>) -> impl IntoResponse {
    let pending = state.lock().expect("runtime state").pending_approvals().to_vec();
    Json(pending)
}

async fn token(State(state): State<SharedState>, Json(request): Json<TokenRequest>) -> impl IntoResponse {
    let approval_id = match state.lock().expect("runtime state").enqueue_token_request(request) {
        Ok(TokenRequestDisposition::Issued(response)) => {
            return (StatusCode::OK, Json(response)).into_response()
        }
        Ok(TokenRequestDisposition::Denied(reason)) => {
            return (StatusCode::FORBIDDEN, reason).into_response()
        }
        Ok(TokenRequestDisposition::Pending(id)) => id,
        Err(error) => return (StatusCode::UNAUTHORIZED, error.to_string()).into_response(),
    };

    let approval_timeout_sec = env::var("SIGORAD_TOKEN_APPROVAL_TIMEOUT_SEC")
        .ok()
        .and_then(|value| value.parse::<u64>().ok())
        .unwrap_or(60);
    let started = tokio::time::Instant::now();
    let deadline = tokio::time::Duration::from_secs(approval_timeout_sec);

    loop {
        let outcome = state
            .lock()
            .expect("runtime state")
            .take_token_outcome(approval_id);

        match outcome {
            Some(ApprovalOutcome::Approved) => {
                let response = match state
                    .lock()
                    .expect("runtime state")
                    .complete_token_request(approval_id)
                {
                    Ok(response) => response,
                    Err(error) => {
                        state.lock().expect("runtime state").expire_token_request(approval_id);
                        return (StatusCode::UNAUTHORIZED, error.to_string()).into_response();
                    }
                };
                return (StatusCode::OK, Json(response)).into_response();
            }
            Some(ApprovalOutcome::Denied) => {
                state.lock().expect("runtime state").expire_token_request(approval_id);
                return (StatusCode::FORBIDDEN, "token request denied").into_response();
            }
            None => {}
        }

        if started.elapsed() >= deadline {
            state.lock().expect("runtime state").expire_token_request(approval_id);
            return (StatusCode::REQUEST_TIMEOUT, "token request timed out").into_response();
        }

        tokio::time::sleep(tokio::time::Duration::from_millis(250)).await;
    }
}

async fn record_decision(
    State(state): State<SharedState>,
    Json(request): Json<ApprovalDecisionRequest>,
) -> impl IntoResponse {
    state.lock().expect("runtime state").record_approval_decision(request);
    Json(serde_json::json!({ "ok": true }))
}

async fn revoke_session(
    State(state): State<SharedState>,
    Json(request): Json<RevokeSessionRequest>,
) -> impl IntoResponse {
    revoke_session_inner(state, request.session_id)
}

async fn revoke_session_path(
    State(state): State<SharedState>,
    Path(session_id): Path<Uuid>,
) -> impl IntoResponse {
    revoke_session_inner(state, session_id)
}

fn revoke_session_inner(state: SharedState, session_id: Uuid) -> axum::response::Response {
    let revoked = state.lock().expect("runtime state").revoke_session(session_id);
    if revoked {
        (StatusCode::OK, Json(RevokeSessionResponse { revoked: true })).into_response()
    } else {
        (
            StatusCode::NOT_FOUND,
            Json(RevokeSessionResponse { revoked: false }),
        )
            .into_response()
    }
}
