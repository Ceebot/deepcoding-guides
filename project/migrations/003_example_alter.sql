-- 003: поддержка eSIM (запрос CR-2026-014).
-- Добавляем sim_type, eid и статус 'qr_generated' в sim_cards.
-- SQLite не умеет менять CHECK через ALTER, поэтому используем официальную
-- безопасную процедуру перестроения таблицы (sqlite.org/lang_altertable.html, п.7):
-- foreign_keys OFF -> новая таблица -> перенос данных -> drop/rename ->
-- пересоздать индексы/триггеры -> foreign_key_check -> foreign_keys ON.
-- Применятель миграций отключает foreign_keys на время батча, поэтому PRAGMA
-- ниже документируют процедуру (внутри транзакции это no-op). Данные и UNIQUE
-- на iccid/phone_number сохраняются.

PRAGMA foreign_keys=OFF;
-- legacy_alter_table=ON: чтобы RENAME не перепарсивал триггеры payments,
-- которые ссылаются на sim_cards (иначе «no such table» в момент переименования).
PRAGMA legacy_alter_table=ON;

CREATE TABLE sim_cards_new (
    id INTEGER PRIMARY KEY,
    iccid TEXT NOT NULL UNIQUE,
    phone_number TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'available'
        CHECK (status IN ('available', 'reserved', 'active', 'blocked', 'lost', 'qr_generated')),
    issued_at TEXT NOT NULL DEFAULT (date('now')),
    activated_at TEXT,
    client_id INTEGER,
    sim_type TEXT NOT NULL DEFAULT 'physical'
        CHECK (sim_type IN ('physical', 'esim')),
    eid TEXT UNIQUE,
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL,
    CHECK (date(issued_at) IS NOT NULL),
    CHECK (activated_at IS NULL OR date(activated_at) IS NOT NULL),
    CHECK (activated_at IS NULL OR activated_at >= issued_at)
);

-- Существующие карты переносятся как физические (sim_type/eid берут DEFAULT).
INSERT INTO sim_cards_new (id, iccid, phone_number, status, issued_at, activated_at, client_id)
SELECT id, iccid, phone_number, status, issued_at, activated_at, client_id
FROM sim_cards;

DROP TABLE sim_cards;
ALTER TABLE sim_cards_new RENAME TO sim_cards;

-- Пересоздаём индекс и триггер, удалённые вместе со старой таблицей.
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

PRAGMA legacy_alter_table=OFF;
PRAGMA foreign_key_check;
PRAGMA foreign_keys=ON;
