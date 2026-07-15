# Telecom SIM Cards — учебный проект

Локальная SQLite-БД оператора связи: клиенты, SIM-карты (physical/eSIM), тарифы, услуги, помесячные начисления, платежи и база знаний. Проект демонстрирует deepcoding — схему, миграции, seed, автоматизацию и проверки целостности с участием ИИ-агентов.

## Быстрый старт

```bash
cd project
make db-reset    # миграции + seed
make db-check    # smoke-проверка
make db-audit    # аудит целостности
make db-charge MONTH=2026-02   # начислить абонплату за месяц
make test        # pytest
```

Требуется Python 3 и `pytest` (см. `make test`).

## Структура

| Каталог / файл | Назначение |
|----------------|------------|
| `schema.sql` | эталонная схема |
| `migrations/` | версионированные изменения |
| `seeds/seed.sql` | демо-данные |
| `scripts/` | CLI (`manage_db.py`, `audit_db.py`) |
| `queries/` | бизнес-запросы, аудит, отчёты |
| `tests/` | pytest |
| `docs/` | документация |

Подробнее: [docs/architecture.md](docs/architecture.md), [docs/commands.md](docs/commands.md).
