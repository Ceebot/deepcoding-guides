-- 001: создание базовых таблиц и триггеров (без индексов — они в 002).
-- Воспроизводит CREATE TABLE/TRIGGER из schema.sql один-в-один.

-- clients — клиенты оператора (физические и юридические лица).
CREATE TABLE clients (
    id INTEGER PRIMARY KEY,                                  -- уникальный идентификатор клиента
    type TEXT NOT NULL CHECK (type IN ('individual', 'legal')), -- тип клиента: физлицо/юрлицо
    name TEXT NOT NULL,                                      -- имя физлица или название компании
    phone TEXT NOT NULL UNIQUE,                              -- контактный телефон
    email TEXT NOT NULL UNIQUE,                              -- email
    registered_at TEXT NOT NULL DEFAULT (datetime('now')),  -- дата и время регистрации
    status TEXT NOT NULL DEFAULT 'active'                    -- статус клиента
        CHECK (status IN ('active', 'blocked', 'archived'))
);

-- individual_clients — данные физических лиц (расширение clients).
CREATE TABLE individual_clients (
    client_id INTEGER PRIMARY KEY,                          -- ссылка на clients.id (он же PK)
    last_name TEXT NOT NULL,                                -- фамилия
    first_name TEXT NOT NULL,                               -- имя
    middle_name TEXT,                                       -- отчество
    birth_date TEXT NOT NULL,                               -- дата рождения
    -- Demo only: never store real passport data in this training database.
    passport_data TEXT NOT NULL,                            -- паспортные данные (только пример модели)
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
    CHECK (date(birth_date) IS NOT NULL)
);

-- legal_clients — данные юридических лиц (расширение clients).
CREATE TABLE legal_clients (
    client_id INTEGER PRIMARY KEY,                          -- ссылка на clients.id (он же PK)
    inn TEXT NOT NULL UNIQUE,                               -- ИНН
    kpp TEXT,                                               -- КПП
    legal_address TEXT NOT NULL,                            -- юридический адрес
    contact_person TEXT NOT NULL,                           -- контактное лицо
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
    CHECK (length(inn) IN (10, 12)),
    CHECK (kpp IS NULL OR length(kpp) = 9)
);

-- sim_cards — SIM-карты оператора.
CREATE TABLE sim_cards (
    id INTEGER PRIMARY KEY,                                 -- уникальный идентификатор SIM-карты
    iccid TEXT NOT NULL UNIQUE,                             -- ICCID (идентификатор чипа)
    phone_number TEXT NOT NULL UNIQUE,                      -- номер телефона
    status TEXT NOT NULL DEFAULT 'available'               -- текущий статус карты
        CHECK (status IN ('available', 'reserved', 'active', 'blocked', 'lost')),
    issued_at TEXT NOT NULL DEFAULT (date('now')),          -- дата выпуска
    activated_at TEXT,                                      -- дата активации (NULL, если не активирована)
    client_id INTEGER,                                      -- клиент-владелец (NULL, если карта свободна)
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL,
    CHECK (date(issued_at) IS NOT NULL),
    CHECK (activated_at IS NULL OR date(activated_at) IS NOT NULL),
    CHECK (activated_at IS NULL OR activated_at >= issued_at)
);

-- services — справочник услуг оператора.
CREATE TABLE services (
    id INTEGER PRIMARY KEY,                                 -- уникальный идентификатор услуги
    name TEXT NOT NULL UNIQUE,                              -- название
    description TEXT NOT NULL,                              -- описание
    type TEXT NOT NULL                                      -- тип услуги
        CHECK (type IN ('internet', 'minutes', 'sms', 'roaming', 'static_ip', 'corporate')),
    cost NUMERIC NOT NULL CHECK (cost >= 0),                -- стоимость
    billing_period TEXT NOT NULL                            -- период списания
        CHECK (billing_period IN ('one_time', 'daily', 'monthly', 'yearly')),
    status TEXT NOT NULL DEFAULT 'active'                   -- статус услуги
        CHECK (status IN ('active', 'deprecated', 'archived'))
);

-- sim_card_services — подключения услуг к SIM-картам (связь многие-ко-многим).
CREATE TABLE sim_card_services (
    id INTEGER PRIMARY KEY,                                 -- уникальный идентификатор подключения
    sim_card_id INTEGER NOT NULL,                          -- ссылка на SIM-карту
    service_id INTEGER NOT NULL,                            -- ссылка на услугу
    connected_at TEXT NOT NULL DEFAULT (datetime('now')),  -- дата подключения
    disconnected_at TEXT,                                   -- дата отключения (NULL, если активно)
    status TEXT NOT NULL DEFAULT 'active'                   -- статус подключения
        CHECK (status IN ('active', 'suspended', 'disconnected')),
    price_at_connection NUMERIC NOT NULL CHECK (price_at_connection >= 0), -- цена на момент подключения
    FOREIGN KEY (sim_card_id) REFERENCES sim_cards(id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE RESTRICT,
    CHECK (disconnected_at IS NULL OR disconnected_at >= connected_at)
);

-- payments — платежи клиентов.
CREATE TABLE payments (
    id INTEGER PRIMARY KEY,                                 -- уникальный идентификатор платежа
    client_id INTEGER NOT NULL,                            -- клиент-плательщик
    sim_card_id INTEGER,                                   -- SIM-карта платежа (NULL, если не привязан)
    amount NUMERIC NOT NULL CHECK (amount > 0),            -- сумма
    currency TEXT NOT NULL DEFAULT 'RUB'                   -- валюта (ISO 4217, верхний регистр)
        CHECK (length(currency) = 3 AND currency = upper(currency)),
    payment_method TEXT NOT NULL                           -- способ оплаты
        CHECK (payment_method IN ('card', 'cash', 'bank_transfer', 'sbp')),
    status TEXT NOT NULL DEFAULT 'pending'                 -- статус платежа
        CHECK (status IN ('pending', 'paid', 'failed', 'refunded')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),    -- дата создания
    confirmed_at TEXT,                                     -- дата подтверждения (NULL, если не подтверждён)
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE RESTRICT,
    FOREIGN KEY (sim_card_id) REFERENCES sim_cards(id) ON DELETE SET NULL,
    CHECK (confirmed_at IS NULL OR confirmed_at >= created_at)
);

-- knowledge_base_articles — статьи учебной базы знаний по услугам.
CREATE TABLE knowledge_base_articles (
    id INTEGER PRIMARY KEY,                                -- уникальный идентификатор статьи
    title TEXT NOT NULL,                                   -- заголовок
    slug TEXT NOT NULL UNIQUE,                             -- slug (ЧПУ-идентификатор)
    category TEXT NOT NULL,                                -- категория
    content TEXT NOT NULL,                                 -- содержимое
    published_status TEXT NOT NULL DEFAULT 'draft'         -- статус публикации
        CHECK (published_status IN ('draft', 'published', 'archived')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),    -- дата создания
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),    -- дата обновления
    CHECK (updated_at >= created_at)
);

-- article_services — связь статей базы знаний с услугами (многие-ко-многим).
CREATE TABLE article_services (
    article_id INTEGER NOT NULL,                           -- ссылка на статью
    service_id INTEGER NOT NULL,                           -- ссылка на услугу
    PRIMARY KEY (article_id, service_id),
    FOREIGN KEY (article_id) REFERENCES knowledge_base_articles(id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE
);

-- trg_individual_clients_type — гарантирует, что физлицо привязано к клиенту типа individual
-- и у клиента ещё нет реквизитов юрлица.
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

-- trg_legal_clients_type — гарантирует, что юрлицо привязано к клиенту типа legal
-- и у клиента ещё нет реквизитов физлица.
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

-- trg_payments_sim_card_client — при вставке платежа проверяет, что SIM-карта принадлежит плательщику.
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

-- trg_payments_sim_card_client_update — та же проверка при смене клиента/SIM-карты в платеже.
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

-- trg_sim_cards_client_update — запрещает сменить владельца SIM-карты, если по ней есть платежи другого клиента.
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
