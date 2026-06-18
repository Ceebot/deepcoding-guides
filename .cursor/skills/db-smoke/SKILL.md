---
name: db-smoke
description: >
  Быстрая read-only проверка SQLite-БД учебного проекта SIM-карт после пересборки.
  Использовать, когда нужно вывести count по clients, sim_cards, services и payments
  без изменения данных или схемы.
---

# DB Smoke

## Назначение

Быстро проверить наполнение учебной SQLite-БД после пересборки проекта.

## Правила

- Не менять данные и схему.
- Не запускать `migrate`, `seed`, `reset`, `rollback` и `make db-reset`.
- Открывать БД только в read-only режиме.
- Проверять только таблицы `clients`, `sim_cards`, `services`, `payments`.

## Команда

Запускать из `project/`:

```bash
python3 - <<'PY'
import os
import sqlite3

db_path = os.environ.get("DB", "data/telecom.db")
tables = ("clients", "sim_cards", "services", "payments")

with sqlite3.connect(f"file:{db_path}?mode=ro", uri=True) as conn:
    rows = [
        (table, conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0])
        for table in tables
    ]

print("| table | count |")
print("|---|---:|")
for table, count in rows:
    print(f"| {table} | {count} |")
PY
```

## Формат ответа

Вывести пользователю одну таблицу:

```markdown
| table | count |
|---|---:|
| clients | N |
| sim_cards | N |
| services | N |
| payments | N |
```
