-- seed.sql — вымышленные демонстрационные данные для локальной БД.
-- INSERT OR IGNORE делает повторную загрузку безопасной.

INSERT OR IGNORE INTO clients
    (id, type, name, phone, email, registered_at, status, preferred_channel)
VALUES
(1, 'individual', 'Иван Петров', '+79000000001', 'ivan.petrov@example.test', '2026-01-10 10:00:00', 'active', 'email'),
(2, 'individual', 'Мария Соколова', '+79000000002', 'maria.sokolova@example.test', '2026-01-11 10:00:00', 'active', 'sms'),
(3, 'individual', 'Алексей Морозов', '+79000000003', 'alexey.morozov@example.test', '2026-01-12 10:00:00', 'blocked', 'sms'),
(4, 'individual', 'Ольга Кузнецова', '+79000000004', 'olga.kuznetsova@example.test', '2026-01-13 10:00:00', 'active', 'push'),
(5, 'individual', 'Дмитрий Волков', '+79000000005', 'dmitry.volkov@example.test', '2026-01-14 10:00:00', 'archived', 'email'),
(6, 'legal', 'ООО Альфа Связь', '+79000000006', 'office@alpha-svyaz.example.test', '2026-01-15 10:00:00', 'active', 'email'),
(7, 'legal', 'АО Север Телеком', '+79000000007', 'info@sever-telecom.example.test', '2026-01-16 10:00:00', 'active', 'push'),
(8, 'legal', 'ИП Романов Петр', '+79000000008', 'romanov@example.test', '2026-01-17 10:00:00', 'blocked', 'sms');

INSERT OR IGNORE INTO individual_clients
    (client_id, last_name, first_name, middle_name, birth_date, passport_data)
VALUES
(1, 'Петров', 'Иван', 'Сергеевич', '1990-03-15', 'demo-passport-0001'),
(2, 'Соколова', 'Мария', 'Игоревна', '1988-07-20', 'demo-passport-0002'),
(3, 'Морозов', 'Алексей', 'Павлович', '1995-11-02', 'demo-passport-0003'),
(4, 'Кузнецова', 'Ольга', 'Андреевна', '1992-05-08', 'demo-passport-0004'),
(5, 'Волков', 'Дмитрий', 'Олегович', '1985-12-30', 'demo-passport-0005');

INSERT OR IGNORE INTO legal_clients
    (client_id, inn, kpp, legal_address, contact_person)
VALUES
(6, '7701000001', '770101001', 'Москва, ул. Учебная, 1', 'Анна Смирнова'),
(7, '7802000002', '780201001', 'Санкт-Петербург, Невский проспект, 10', 'Игорь Лебедев'),
(8, '590300000003', NULL, 'Пермь, ул. Связистов, 5', 'Петр Романов');

INSERT OR IGNORE INTO services (id, name, description, type, cost, billing_period, status) VALUES
(1, 'Интернет 10 ГБ', 'Пакет мобильного интернета 10 ГБ', 'internet', 350, 'monthly', 'active'),
(2, 'Интернет 30 ГБ', 'Пакет мобильного интернета 30 ГБ', 'internet', 600, 'monthly', 'active'),
(3, 'Пакет 300 минут', '300 минут на все сети РФ', 'minutes', 250, 'monthly', 'active'),
(4, 'Пакет 1000 минут', '1000 минут на все сети РФ', 'minutes', 500, 'monthly', 'active'),
(5, 'SMS 500', '500 SMS в месяц', 'sms', 150, 'monthly', 'active'),
(6, 'Роуминг Европа', 'Пакет роуминга по странам Европы', 'roaming', 1200, 'one_time', 'active'),
(7, 'Статический IP', 'Выделенный статический IP-адрес', 'static_ip', 200, 'monthly', 'active'),
(8, 'Корпоративный VPN', 'Защищенный VPN для бизнеса', 'corporate', 1500, 'monthly', 'active');

INSERT OR IGNORE INTO tariffs
    (id, name, description, monthly_fee, status, created_at)
VALUES
    (1, 'Старт', 'Базовый тариф', 500, 'active', '2026-01-01 09:00:00'),
    (2, 'Онлайн', 'Тариф с увеличенным интернетом', 750, 'active', '2026-01-01 09:00:00'),
    (3, 'Бизнес', 'Тариф для корпоративных клиентов', 1350, 'active', '2026-01-01 09:00:00'),
    (4, 'Классический', 'Архивный тариф', 400, 'archived', '2026-01-01 09:00:00');

INSERT OR IGNORE INTO tariff_services (tariff_id, service_id) VALUES
    (1, 1), (1, 3),
    (2, 2), (2, 5),
    (3, 4), (3, 5), (3, 7), (3, 8);

INSERT OR IGNORE INTO sim_cards
    (id, iccid, phone_number, sim_type, eid, status, issued_at, activated_at, client_id, tariff_id)
VALUES
(1, '8970100000000000001', '+79100000001', 'physical', NULL, 'active', '2026-01-01', '2026-01-10', 1, 1),
(2, '8970100000000000002', '+79100000002', 'esim', '89049032000000000000000000000001', 'active', '2026-01-02', '2026-01-11', 1, 2),
(3, '8970100000000000003', '+79100000003', 'physical', NULL, 'reserved', '2026-01-03', NULL, 2, NULL),
(4, '8970100000000000004', '+79100000004', 'physical', NULL, 'blocked', '2026-01-04', '2026-01-12', 3, NULL),
(5, '8970100000000000005', '+79100000005', 'physical', NULL, 'lost', '2026-01-05', '2026-01-13', 4, NULL),
(6, '8970100000000000006', '+79100000006', 'physical', NULL, 'available', '2026-01-06', NULL, NULL, NULL),
(7, '8970100000000000007', '+79100000007', 'physical', NULL, 'active', '2026-01-07', '2026-01-15', 6, 3),
(8, '8970100000000000008', '+79100000008', 'esim', '89049032000000000000000000000002', 'reserved', '2026-01-08', NULL, 7, NULL),
(9, '8970100000000000009', '+79100000009', 'physical', NULL, 'available', '2026-01-09', NULL, NULL, NULL),
(10, '8970100000000000010', '+79100000010', 'physical', NULL, 'active', '2026-01-10', '2026-01-18', 8, 1);

INSERT OR IGNORE INTO charges
    (id, sim_card_id, tariff_id, billing_period, tariff_name, amount, created_at)
VALUES
    (1, 1, 1, '2026-01', 'Старт', 500, '2026-01-31 23:00:00'),
    (2, 2, 2, '2026-01', 'Онлайн', 750, '2026-01-31 23:00:00'),
    (3, 7, 3, '2026-01', 'Бизнес', 1350, '2026-01-31 23:00:00'),
    (4, 10, 1, '2026-01', 'Старт', 500, '2026-01-31 23:00:00');

INSERT OR IGNORE INTO sim_card_services
    (id, sim_card_id, service_id, connected_at, disconnected_at, status, price_at_connection)
VALUES
(1, 1, 1, '2026-01-10 11:00:00', NULL, 'active', 350),
(2, 1, 3, '2026-01-10 11:05:00', NULL, 'active', 250),
(3, 2, 2, '2026-01-11 11:00:00', NULL, 'active', 600),
(4, 2, 5, '2026-01-11 11:05:00', NULL, 'active', 150),
(5, 4, 1, '2026-01-12 11:00:00', NULL, 'suspended', 350),
(6, 5, 6, '2026-01-13 11:00:00', '2026-02-01 09:00:00', 'disconnected', 1200),
(7, 7, 8, '2026-01-15 11:00:00', NULL, 'active', 1500),
(8, 7, 7, '2026-01-15 11:05:00', NULL, 'active', 200),
(9, 10, 4, '2026-01-18 11:00:00', NULL, 'active', 500),
(10, 10, 5, '2026-01-18 11:05:00', NULL, 'active', 150);

INSERT OR IGNORE INTO payments
    (id, client_id, sim_card_id, amount, currency, payment_method, status, created_at, confirmed_at)
VALUES
(1, 1, 1, 700, 'RUB', 'card', 'paid', '2026-01-10 12:00:00', '2026-01-10 12:01:00'),
(2, 1, 2, 750, 'RUB', 'sbp', 'pending', '2026-01-11 12:00:00', NULL),
(3, 2, 3, 300, 'RUB', 'card', 'failed', '2026-01-12 12:00:00', NULL),
(4, 3, 4, 350, 'RUB', 'cash', 'refunded', '2026-01-13 12:00:00', '2026-01-14 12:00:00'),
(5, 4, 5, 1200, 'RUB', 'card', 'paid', '2026-01-14 12:00:00', '2026-01-14 12:02:00'),
(6, 6, 7, 1700, 'RUB', 'bank_transfer', 'paid', '2026-01-15 12:00:00', '2026-01-16 09:00:00'),
(7, 7, 8, 1500, 'RUB', 'bank_transfer', 'pending', '2026-01-16 12:00:00', NULL),
(8, 8, 10, 650, 'RUB', 'card', 'failed', '2026-01-18 12:00:00', NULL);

INSERT OR IGNORE INTO knowledge_base_articles
    (id, title, slug, category, content, published_status, created_at, updated_at)
VALUES
(1, 'Как подключить интернет-пакет', 'internet-package-connect', 'services', 'Инструкция по подключению интернет-пакета.', 'published', '2026-01-20 10:00:00', '2026-01-20 10:00:00'),
(2, 'Пакеты минут для звонков', 'minutes-packages', 'services', 'Описание пакетов минут и ограничений.', 'published', '2026-01-21 10:00:00', '2026-01-21 10:00:00'),
(3, 'SMS-пакеты', 'sms-packages', 'services', 'Частые вопросы по SMS-пакетам.', 'published', '2026-01-22 10:00:00', '2026-01-22 10:00:00'),
(4, 'Роуминг в Европе', 'europe-roaming', 'roaming', 'Правила подключения роуминга.', 'draft', '2026-01-23 10:00:00', '2026-01-23 10:00:00'),
(5, 'Корпоративные опции', 'corporate-options', 'corporate', 'VPN и статический IP для бизнеса.', 'published', '2026-01-24 10:00:00', '2026-01-24 10:00:00');

INSERT OR IGNORE INTO article_services (article_id, service_id) VALUES
(1, 1),
(1, 2),
(2, 3),
(3, 5),
(4, 6),
(5, 7);
