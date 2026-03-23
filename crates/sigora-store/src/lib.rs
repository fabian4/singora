use anyhow::Result;
use rusqlite::Connection;

pub struct SqliteStore {
    conn: Connection,
}

impl SqliteStore {
    pub fn open(path: &str) -> Result<Self> {
        let conn = Connection::open(path)?;
        let store = Self { conn };
        store.migrate()?;
        Ok(store)
    }

    fn migrate(&self) -> Result<()> {
        self.conn.execute_batch(
            "
            CREATE TABLE IF NOT EXISTS pairings (
              client_id TEXT PRIMARY KEY,
              device_name TEXT,
              paired_at INTEGER NOT NULL,
              revoked_at INTEGER
            );

            CREATE TABLE IF NOT EXISTS sessions (
              session_id TEXT PRIMARY KEY,
              client_id TEXT NOT NULL,
              session_key_hash TEXT NOT NULL,
              expire_at INTEGER NOT NULL,
              last_nonce TEXT,
              created_at INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS credential_store (
              provider TEXT NOT NULL,
              type TEXT NOT NULL,
              alias TEXT NOT NULL DEFAULT 'default',
              ref TEXT NOT NULL,
              updated INTEGER NOT NULL,
              expire INTEGER,
              PRIMARY KEY (provider, type, alias)
            );

            CREATE TABLE IF NOT EXISTS audit_events (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              event_type TEXT NOT NULL,
              actor TEXT NOT NULL,
              decision TEXT,
              reason TEXT,
              created_at INTEGER NOT NULL
            );
            ",
        )?;
        Ok(())
    }
}
