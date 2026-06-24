# Архитектура

## Модель данных

Учебная БД оператора мобильной связи. Центральная сущность — **клиент** (`clients`), который может быть физическим или юридическим лицом. Детали хранятся в `individual_clients` или `legal_clients`.

**SIM-карты** (`sim_cards`) привязаны к клиенту (или свободны). Поддерживаются physical и eSIM (`sim_type`, `eid` с миграции 003).

**Услуги** (`services`) подключаются к SIM через `sim_card_services` с историей и ценой на момент подключения.

**Платежи** (`payments`) относятся к клиенту; опционально к SIM-карте. Триггеры гарантируют, что SIM в платеже принадлежит тому же клиенту.

**База знаний**: `knowledge_base_articles` связана с услугами через `article_services`.

## ERD

Актуальная диаграмма (включая `sim_type` и `eid`):

```mermaid
erDiagram
    clients ||--o| individual_clients : details
    clients ||--o| legal_clients : details
    clients ||--o{ sim_cards : owns
    clients ||--o{ payments : makes
    sim_cards ||--o{ payments : relates_to
    sim_cards ||--o{ sim_card_services : has
    services ||--o{ sim_card_services : connected_as
    services ||--o{ article_services : described_by
    knowledge_base_articles ||--o{ article_services : links

    sim_cards {
        text sim_type
        text eid
    }
```

Полная версия: [erd.md](erd.md) (при расхождении ориентируйтесь на `schema.sql`).

## Ключевые решения

- **SQLite** — один файл, без сервера; подходит для учебного проекта и локальных проверок.
- **Миграции** — нумерованные SQL в `migrations/`, журнал в `migration_history`; откат через `migrations/down/`.
- **schema.sql** — эталон «как должно быть»; миграции воспроизводят эволюцию.
- **Триггеры** — тип клиента в detail-таблицах, согласованность платежей и SIM.
- **Seed** — идемпотентный `INSERT OR IGNORE`; повторная загрузка безопасна.
- **Аудит** — read-only SQL в `queries/integrity/`; схему не меняет, ловит логические нарушения, которые FK не покрывают.
