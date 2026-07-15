# База данных

Описание по `schema.sql` и миграциям `001`–`005`.

## Таблицы

### clients
| Поле | Ограничения |
|------|-------------|
| id | PK |
| type | `individual` / `legal` |
| phone, email | UNIQUE |
| status | `active`, `blocked`, `archived` |
| preferred_channel | `email`, `sms`, `push` (default `email`, 004) |

### individual_clients / legal_clients
- PK/FK: `client_id` → `clients.id` ON DELETE CASCADE
- `legal_clients.inn` UNIQUE; CHECK длины ИНН (10/12), КПП (9)
- **Demo only**: `passport_data` — не хранить реальные паспорта

### tariffs (005)
| Поле | Ограничения |
|------|-------------|
| name | UNIQUE |
| monthly_fee | `>= 0` |
| status | `active`, `archived` |

### sim_cards
| Поле | Ограничения |
|------|-------------|
| iccid, phone_number | UNIQUE |
| sim_type | `physical` / `esim` (003) |
| eid | 32 цифры, NULL у physical; partial UNIQUE |
| status | `available`, `reserved`, `active`, `blocked`, `lost`, `qr_generated` |
| client_id | FK → clients, ON DELETE SET NULL |
| tariff_id | nullable FK → tariffs, ON DELETE SET NULL (005) |

### tariff_services (005)
- PK: (`tariff_id`, `service_id`); M:N тариф ↔ услуга
- FK: `tariff_id` → tariffs ON DELETE CASCADE; `service_id` → services ON DELETE RESTRICT

### services
- `name` UNIQUE; `cost >= 0`; тип и billing_period через CHECK
- `status`: `active`, `deprecated`, `archived`

### sim_card_services
- FK на sim_cards и services
- `status`: `active`, `suspended`, `disconnected`
- partial UNIQUE: одна активная пара (sim_card_id, service_id)

### payments
- `amount > 0`; валюта 3 заглавные буквы
- `status`: `pending`, `paid`, `failed`, `refunded`
- триггеры: SIM принадлежит client_id платежа

### charges (005)
- помесячный снимок абонплаты: `billing_period` (`YYYY-MM`), `tariff_name`, `amount`
- FK: `sim_card_id`, `tariff_id`; UNIQUE (`sim_card_id`, `billing_period`)
- **immutable** — UPDATE/DELETE запрещены триггерами; связи с `payments` нет
- отчёт `revenue-by-tariffs.sql` считает **начисленную** выручку, не оплаченную

### knowledge_base_articles / article_services
- `slug` UNIQUE; M:N статья ↔ услуга

### migration_history
- версии применённых миграций

## Индексы (002 + schema)

- `idx_clients_status`
- `idx_sim_cards_client_status`, `idx_sim_cards_tariff_id` (005)
- `uq_sim_cards_eid` (WHERE eid IS NOT NULL)
- `idx_services_type_status`
- `idx_tariff_services_service_id` (005)
- `uq_active_sim_card_service` (partial)
- `idx_sim_card_services_service_status`
- `idx_payments_client_status_created`, `idx_payments_sim_card_id`
- `idx_charges_period_tariff` (005)
- `idx_articles_category_status`, `idx_article_services_service_id`

## Триггеры

- `trg_individual_clients_type`, `trg_legal_clients_type` — тип клиента
- `trg_payments_sim_card_client` (+ update) — владелец SIM
- `trg_sim_cards_client_update` — нельзя сменить владельца при чужих платежах
- `trg_sim_cards_tariff_insert`, `trg_sim_cards_tariff_update` (005) — назначить можно только `active` тариф; архивный нельзя назначить заново, существующее назначение при архивации сохраняется
- `trg_charges_immutable_update`, `trg_charges_immutable_delete` (005) — начисления неизменяемы
