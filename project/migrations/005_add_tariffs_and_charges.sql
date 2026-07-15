CREATE TABLE tariffs (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    monthly_fee NUMERIC NOT NULL CHECK (monthly_fee >= 0),
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'archived')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE tariff_services (
    tariff_id INTEGER NOT NULL,
    service_id INTEGER NOT NULL,
    PRIMARY KEY (tariff_id, service_id),
    FOREIGN KEY (tariff_id) REFERENCES tariffs(id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE RESTRICT
);

ALTER TABLE sim_cards
ADD COLUMN tariff_id INTEGER REFERENCES tariffs(id) ON DELETE SET NULL;

CREATE TABLE charges (
    id INTEGER PRIMARY KEY,
    sim_card_id INTEGER NOT NULL,
    tariff_id INTEGER NOT NULL,
    billing_period TEXT NOT NULL
        CHECK (
            billing_period GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]'
            AND substr(billing_period, 6, 2) BETWEEN '01' AND '12'
        ),
    tariff_name TEXT NOT NULL,
    amount NUMERIC NOT NULL CHECK (amount >= 0),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE (sim_card_id, billing_period),
    FOREIGN KEY (sim_card_id) REFERENCES sim_cards(id) ON DELETE RESTRICT,
    FOREIGN KEY (tariff_id) REFERENCES tariffs(id) ON DELETE RESTRICT
);

CREATE INDEX idx_sim_cards_tariff_id ON sim_cards(tariff_id);
CREATE INDEX idx_tariff_services_service_id ON tariff_services(service_id);
CREATE INDEX idx_charges_period_tariff
    ON charges(billing_period, tariff_id);

CREATE TRIGGER trg_sim_cards_tariff_insert
BEFORE INSERT ON sim_cards
FOR EACH ROW
WHEN NEW.tariff_id IS NOT NULL
BEGIN
    SELECT RAISE(ABORT, 'only active tariff can be assigned')
    WHERE NOT EXISTS (
        SELECT 1 FROM tariffs
        WHERE id = NEW.tariff_id AND status = 'active'
    );
END;

CREATE TRIGGER trg_sim_cards_tariff_update
BEFORE UPDATE OF tariff_id ON sim_cards
FOR EACH ROW
WHEN NEW.tariff_id IS NOT NULL
BEGIN
    SELECT RAISE(ABORT, 'only active tariff can be assigned')
    WHERE NOT EXISTS (
        SELECT 1 FROM tariffs
        WHERE id = NEW.tariff_id AND status = 'active'
    );
END;

CREATE TRIGGER trg_charges_immutable_update
BEFORE UPDATE ON charges
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'charges are immutable');
END;

CREATE TRIGGER trg_charges_immutable_delete
BEFORE DELETE ON charges
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'charges are immutable');
END;
