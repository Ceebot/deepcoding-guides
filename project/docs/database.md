# База данных

Описание по `schema.sql` и миграциям `001`–`004`.

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

### sim_cards
| Поле | Ограничения |
|------|-------------|
| iccid, phone_number | UNIQUE |
| sim_type | `physical` / `esim` (003) |
| eid | 32 цифры, NULL у physical; partial UNIQUE |
| status | `available`, `reserved`, `active`, `blocked`, `lost`, `qr_generated` |
| client_id | FK → clients, ON DELETE SET NULL |

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

### knowledge_base_articles / article_services
- `slug` UNIQUE; M:N статья ↔ услуга

### migration_history
- версии применённых миграций

## Индексы (002 + schema)

- `idx_clients_status`
- `idx_sim_cards_client_status`
- `uq_sim_cards_eid` (WHERE eid IS NOT NULL)
- `idx_services_type_status`
- `uq_active_sim_card_service` (partial)
- `idx_sim_card_services_service_status`
- `idx_payments_client_status_created`, `idx_payments_sim_card_id`
- `idx_articles_category_status`, `idx_article_services_service_id`

## Триггеры

- `trg_individual_clients_type`, `trg_legal_clients_type` — тип клиента
- `trg_payments_sim_card_client` (+ update) — владелец SIM
- `trg_sim_cards_client_update` — нельзя сменить владельца при чужих платежах
