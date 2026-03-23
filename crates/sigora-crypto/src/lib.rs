use hmac::{Hmac, Mac};
use sha2::Sha256;
use thiserror::Error;

type HmacSha256 = Hmac<Sha256>;

#[derive(Debug, Error)]
pub enum CryptoError {
    #[error("invalid mac")]
    InvalidMac,
    #[error("malformed mac")]
    MalformedMac,
}

pub fn sign_hex(secret: &[u8], payload: &str) -> String {
    let mut mac = HmacSha256::new_from_slice(secret).expect("valid hmac key");
    mac.update(payload.as_bytes());
    hex::encode(mac.finalize().into_bytes())
}

pub fn verify_hex(secret: &[u8], payload: &str, expected_hex: &str) -> Result<(), CryptoError> {
    let expected = hex::decode(expected_hex).map_err(|_| CryptoError::MalformedMac)?;
    let mut mac = HmacSha256::new_from_slice(secret).expect("valid hmac key");
    mac.update(payload.as_bytes());
    mac.verify_slice(&expected).map_err(|_| CryptoError::InvalidMac)
}
