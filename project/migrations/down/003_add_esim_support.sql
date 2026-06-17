-- Down для 003_add_esim_support: возвращает sim_cards к схеме из 001/002.
-- Данные eSIM-колонок теряются, статус qr_generated нормализуется в reserved.

DROP INDEX IF EXISTS uq_sim_cards_eid;
DROP INDEX IF EXISTS idx_sim_cards_client_status;
DROP TRIGGER IF EXISTS trg_sim_cards_client_update;

CREATE TABLE sim_cards_old (
    id INTEGER PRIMARY KEY,
    iccid TEXT NOT NULL UNIQUE,
    phone_number TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'available'
        CHECK (status IN ('available', 'reserved', 'active', 'blocked', 'lost')),
    issued_at TEXT NOT NULL DEFAULT (date('now')),
    activated_at TEXT,
    client_id INTEGER,
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL,
    CHECK (date(issued_at) IS NOT NULL),
    CHECK (activated_at IS NULL OR date(activated_at) IS NOT NULL),
    CHECK (activated_at IS NULL OR activated_at >= issued_at)
);

INSERT INTO sim_cards_old (
    id,
    iccid,
    phone_number,
    status,
    issued_at,
    activated_at,
    client_id
)
SELECT
    id,
    iccid,
    phone_number,
    CASE WHEN status = 'qr_generated' THEN 'reserved' ELSE status END,
    issued_at,
    activated_at,
    client_id
FROM sim_cards;

PRAGMA legacy_alter_table=ON;
DROP TABLE sim_cards;
ALTER TABLE sim_cards_old RENAME TO sim_cards;
PRAGMA legacy_alter_table=OFF;

CREATE INDEX idx_sim_cards_client_status ON sim_cards(client_id, status);

CREATE TRIGGER trg_sim_cards_client_update
BEFORE UPDATE OF client_id ON sim_cards
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'sim card has payments for another client')
    WHERE EXISTS (
        SELECT 1 FROM payments
        WHERE sim_card_id = NEW.id AND client_id IS NOT NEW.client_id
    );
END;
