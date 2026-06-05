-- 003: поддержка eSIM (CR-2026-014).
-- Добавляет sim_type, eid и статус 'qr_generated' в sim_cards.
-- В SQLite нельзя изменить CHECK существующего столбца status через ALTER,
-- поэтому таблица пересобирается (create→copy→drop→rename) без потери данных.
-- FK на время батча отключены migrate.py — DROP/RENAME с внешними ссылками безопасен.
-- BEGIN/COMMIT не пишем: их добавляет migrate.py.

-- 1. Новая таблица с расширенной схемой.
CREATE TABLE sim_cards_new (
    id INTEGER PRIMARY KEY,
    iccid TEXT NOT NULL UNIQUE,                             -- ICCID (для eSIM может быть профиль eUICC)
    phone_number TEXT NOT NULL UNIQUE,                      -- номер телефона
    sim_type TEXT NOT NULL DEFAULT 'physical'              -- тип носителя
        CHECK (sim_type IN ('physical', 'esim')),
    eid TEXT                                                -- EID eSIM (32 цифры); NULL для физических
        CHECK (eid IS NULL OR (length(eid) = 32 AND eid NOT GLOB '*[^0-9]*')),
    status TEXT NOT NULL DEFAULT 'available'               -- статус карты (+ qr_generated для eSIM)
        CHECK (status IN ('available', 'reserved', 'active', 'blocked', 'lost', 'qr_generated')),
    issued_at TEXT NOT NULL DEFAULT (date('now')),          -- дата выпуска
    activated_at TEXT,                                      -- дата активации (NULL, если не активирована)
    client_id INTEGER,                                      -- клиент-владелец (NULL, если карта свободна)
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL,
    CHECK (date(issued_at) IS NOT NULL),
    CHECK (activated_at IS NULL OR date(activated_at) IS NOT NULL),
    CHECK (activated_at IS NULL OR activated_at >= issued_at),
    CHECK (sim_type <> 'physical' OR eid IS NULL)           -- у физической карты EID пуст
);

-- 2. Перенос существующих данных: все карты — физические, eid пуст.
INSERT INTO sim_cards_new (id, iccid, phone_number, status, issued_at, activated_at, client_id)
SELECT id, iccid, phone_number, status, issued_at, activated_at, client_id
FROM sim_cards;

-- 3. Замена таблицы.
-- legacy_alter_table=ON: иначе RENAME ревалидирует триггер trg_payments_sim_card_client,
-- который ссылается на уже удалённую sim_cards, и падает. Выключаем после замены.
PRAGMA legacy_alter_table=ON;
DROP TABLE sim_cards;
ALTER TABLE sim_cards_new RENAME TO sim_cards;
PRAGMA legacy_alter_table=OFF;

-- 4. Пересоздаём индекс и добавляем UNIQUE на eid только для eSIM (NULL не уникальны).
CREATE INDEX idx_sim_cards_client_status ON sim_cards(client_id, status);
CREATE UNIQUE INDEX uq_sim_cards_eid ON sim_cards(eid) WHERE eid IS NOT NULL;

-- 5. Пересоздаём триггер, живший на старой таблице.
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
