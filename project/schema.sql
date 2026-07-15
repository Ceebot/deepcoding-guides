PRAGMA foreign_keys = ON;

CREATE TABLE clients (
    id INTEGER PRIMARY KEY,
    type TEXT NOT NULL CHECK (type IN ('individual', 'legal')),
    name TEXT NOT NULL,
    phone TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    registered_at TEXT NOT NULL DEFAULT (datetime('now')),
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'blocked', 'archived')),
    preferred_channel TEXT NOT NULL DEFAULT 'email'
        CHECK (preferred_channel IN ('email', 'sms', 'push'))
);

CREATE TABLE individual_clients (
    client_id INTEGER PRIMARY KEY,
    last_name TEXT NOT NULL,
    first_name TEXT NOT NULL,
    middle_name TEXT,
    birth_date TEXT NOT NULL,
    -- Demo only: never store real passport data in this training database.
    passport_data TEXT NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
    CHECK (date(birth_date) IS NOT NULL)
);

CREATE TABLE legal_clients (
    client_id INTEGER PRIMARY KEY,
    inn TEXT NOT NULL UNIQUE,
    kpp TEXT,
    legal_address TEXT NOT NULL,
    contact_person TEXT NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
    CHECK (length(inn) IN (10, 12)),
    CHECK (kpp IS NULL OR length(kpp) = 9)
);

CREATE TABLE tariffs (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    monthly_fee NUMERIC NOT NULL CHECK (monthly_fee >= 0),
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'archived')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE sim_cards (
    id INTEGER PRIMARY KEY,
    iccid TEXT NOT NULL UNIQUE,
    phone_number TEXT NOT NULL UNIQUE,
    sim_type TEXT NOT NULL DEFAULT 'physical'
        CHECK (sim_type IN ('physical', 'esim')),
    eid TEXT
        CHECK (eid IS NULL OR (length(eid) = 32 AND eid NOT GLOB '*[^0-9]*')),
    status TEXT NOT NULL DEFAULT 'available'
        CHECK (status IN ('available', 'reserved', 'active', 'blocked', 'lost', 'qr_generated')),
    issued_at TEXT NOT NULL DEFAULT (date('now')),
    activated_at TEXT,
    client_id INTEGER,
    tariff_id INTEGER REFERENCES tariffs(id) ON DELETE SET NULL,
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL,
    CHECK (date(issued_at) IS NOT NULL),
    CHECK (activated_at IS NULL OR date(activated_at) IS NOT NULL),
    CHECK (activated_at IS NULL OR activated_at >= issued_at),
    CHECK (sim_type <> 'physical' OR eid IS NULL)
);

CREATE TABLE services (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    type TEXT NOT NULL
        CHECK (type IN ('internet', 'minutes', 'sms', 'roaming', 'static_ip', 'corporate')),
    cost NUMERIC NOT NULL CHECK (cost >= 0),
    billing_period TEXT NOT NULL
        CHECK (billing_period IN ('one_time', 'daily', 'monthly', 'yearly')),
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'deprecated', 'archived'))
);

CREATE TABLE tariff_services (
    tariff_id INTEGER NOT NULL,
    service_id INTEGER NOT NULL,
    PRIMARY KEY (tariff_id, service_id),
    FOREIGN KEY (tariff_id) REFERENCES tariffs(id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE RESTRICT
);

CREATE TABLE sim_card_services (
    id INTEGER PRIMARY KEY,
    sim_card_id INTEGER NOT NULL,
    service_id INTEGER NOT NULL,
    connected_at TEXT NOT NULL DEFAULT (datetime('now')),
    disconnected_at TEXT,
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'suspended', 'disconnected')),
    price_at_connection NUMERIC NOT NULL CHECK (price_at_connection >= 0),
    FOREIGN KEY (sim_card_id) REFERENCES sim_cards(id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE RESTRICT,
    CHECK (disconnected_at IS NULL OR disconnected_at >= connected_at)
);

CREATE TABLE payments (
    id INTEGER PRIMARY KEY,
    client_id INTEGER NOT NULL,
    sim_card_id INTEGER,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    currency TEXT NOT NULL DEFAULT 'RUB'
        CHECK (length(currency) = 3 AND currency = upper(currency)),
    payment_method TEXT NOT NULL
        CHECK (payment_method IN ('card', 'cash', 'bank_transfer', 'sbp')),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'paid', 'failed', 'refunded')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    confirmed_at TEXT,
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT,
    FOREIGN KEY (sim_card_id) REFERENCES sim_cards(id) ON DELETE SET NULL,
    CHECK (confirmed_at IS NULL OR confirmed_at >= created_at)
);

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

CREATE TABLE knowledge_base_articles (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL,
    content TEXT NOT NULL,
    published_status TEXT NOT NULL DEFAULT 'draft'
        CHECK (published_status IN ('draft', 'published', 'archived')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    CHECK (updated_at >= created_at)
);

CREATE TABLE article_services (
    article_id INTEGER NOT NULL,
    service_id INTEGER NOT NULL,
    PRIMARY KEY (article_id, service_id),
    FOREIGN KEY (article_id) REFERENCES knowledge_base_articles(id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE
);

CREATE TRIGGER trg_individual_clients_type
BEFORE INSERT ON individual_clients
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'client must have individual type')
    WHERE NOT EXISTS (
        SELECT 1 FROM clients
        WHERE id = NEW.client_id AND type = 'individual'
    );

    SELECT RAISE(ABORT, 'client already has legal details')
    WHERE EXISTS (
        SELECT 1 FROM legal_clients
        WHERE client_id = NEW.client_id
    );
END;

CREATE TRIGGER trg_legal_clients_type
BEFORE INSERT ON legal_clients
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'client must have legal type')
    WHERE NOT EXISTS (
        SELECT 1 FROM clients
        WHERE id = NEW.client_id AND type = 'legal'
    );

    SELECT RAISE(ABORT, 'client already has individual details')
    WHERE EXISTS (
        SELECT 1 FROM individual_clients
        WHERE client_id = NEW.client_id
    );
END;

CREATE TRIGGER trg_payments_sim_card_client
BEFORE INSERT ON payments
FOR EACH ROW
WHEN NEW.sim_card_id IS NOT NULL
BEGIN
    SELECT RAISE(ABORT, 'payment client must own sim card')
    WHERE NOT EXISTS (
        SELECT 1 FROM sim_cards
        WHERE id = NEW.sim_card_id AND client_id = NEW.client_id
    );
END;

CREATE TRIGGER trg_payments_sim_card_client_update
BEFORE UPDATE OF client_id, sim_card_id ON payments
FOR EACH ROW
WHEN NEW.sim_card_id IS NOT NULL
BEGIN
    SELECT RAISE(ABORT, 'payment client must own sim card')
    WHERE NOT EXISTS (
        SELECT 1 FROM sim_cards
        WHERE id = NEW.sim_card_id AND client_id = NEW.client_id
    );
END;

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

CREATE INDEX idx_clients_status ON clients(status);
CREATE INDEX idx_sim_cards_client_status ON sim_cards(client_id, status);
CREATE INDEX idx_sim_cards_tariff_id ON sim_cards(tariff_id);
CREATE UNIQUE INDEX uq_sim_cards_eid ON sim_cards(eid) WHERE eid IS NOT NULL;
CREATE INDEX idx_services_type_status ON services(type, status);
CREATE INDEX idx_tariff_services_service_id ON tariff_services(service_id);
CREATE UNIQUE INDEX uq_active_sim_card_service
    ON sim_card_services(sim_card_id, service_id)
    WHERE status = 'active';
CREATE INDEX idx_sim_card_services_service_status ON sim_card_services(service_id, status);
CREATE INDEX idx_payments_client_status_created ON payments(client_id, status, created_at);
CREATE INDEX idx_payments_sim_card_id ON payments(sim_card_id);
CREATE INDEX idx_charges_period_tariff
    ON charges(billing_period, tariff_id);
CREATE INDEX idx_articles_category_status ON knowledge_base_articles(category, published_status);
CREATE INDEX idx_article_services_service_id ON article_services(service_id);
