---
name: db-schema
description: >
  Схема учебной БД проекта SIM-карт (project/, SQLite). Подключать при написании SQL-запросов,
  миграций и seed-данных, чтобы агент знал таблицы, статусы и ограничения и не выдумывал поля.
---

# DB Schema — Telecom SIM Cards (project/)

Источник истины — `project/schema.sql`. Ниже сжатая карта для быстрого контекста.
При любом расхождении верить `schema.sql`, а не этому файлу.

## Таблицы и ключевые поля

### clients — клиент (общая часть)
- `type`: `individual` | `legal`
- `status`: `active` | `blocked` | `archived`
- `phone`, `email` — UNIQUE

### individual_clients — физлицо, 1→1 `clients`
- `last_name`, `first_name`, `middle_name`, `birth_date`, `passport_data` (только демо-данные)
- триггер: `clients.type` должен быть `individual`; нельзя одновременно иметь legal-детали

### legal_clients — юрлицо, 1→1 `clients`
- `inn` UNIQUE, длина 10 или 12; `kpp` — длина 9 или NULL; `legal_address`, `contact_person`
- триггер: `clients.type` должен быть `legal`

### sim_cards — SIM-карта
- `iccid`, `phone_number` — UNIQUE
- `sim_type`: `physical` | `esim`
- `eid`: NULL или ровно 32 цифры; для `physical` `eid` обязан быть NULL
- `status`: `available` | `reserved` | `active` | `blocked` | `lost` | `qr_generated`
- `client_id` → `clients` (ON DELETE SET NULL)
- `activated_at >= issued_at`

### services — услуга/тариф
- `name` — UNIQUE
- `type`: `internet` | `minutes` | `sms` | `roaming` | `static_ip` | `corporate`
- `cost >= 0`
- `billing_period`: `one_time` | `daily` | `monthly` | `yearly`
- `status`: `active` | `deprecated` | `archived`

### sim_card_services — подключение услуги к SIM (M:N)
- `sim_card_id` → `sim_cards` (CASCADE), `service_id` → `services` (RESTRICT)
- `status`: `active` | `suspended` | `disconnected`
- частичный UNIQUE: одна активная связь `(sim_card_id, service_id)` при `status='active'`
- `disconnected_at >= connected_at`

### payments — платёж
- `client_id` → `clients` (RESTRICT), `sim_card_id` → `sim_cards` (SET NULL)
- `amount > 0`; `currency` — 3 буквы в верхнем регистре (по умолчанию `RUB`)
- `payment_method`: `card` | `cash` | `bank_transfer` | `sbp`
- `status`: `pending` | `paid` | `failed` | `refunded`
- триггер: если указан `sim_card_id`, карта должна принадлежать `client_id` платежа
- `confirmed_at >= created_at`

### knowledge_base_articles — статья базы знаний
- `slug` — UNIQUE; `category`; `published_status`: `draft` | `published` | `archived`
- `updated_at >= created_at`

### article_services — связь статья↔услуга (M:N)
- PK `(article_id, service_id)`, обе FK с CASCADE

## Триггеры целостности
- individual/legal-детали соответствуют `clients.type` и взаимоисключаются;
- платёж по SIM возможен, только если SIM принадлежит клиенту платежа (на INSERT и UPDATE);
- нельзя сменить владельца `sim_cards.client_id`, если по карте есть платежи другого клиента.

## Полезные индексы
- `sim_cards(client_id, status)`, `services(type, status)`, `payments(client_id, status, created_at)`;
- частичный UNIQUE по `eid`; частичный UNIQUE активной связи в `sim_card_services`.

## Как использовать этот skill
1. Перед SQL/миграцией свериться с этой картой и `project/schema.sql`.
2. Не выдумывать поля и статусы — использовать только перечисленные значения enum/CHECK.
3. Новые статусы/типы вводить миграцией с пересборкой таблицы (SQLite не расширяет CHECK напрямую).
