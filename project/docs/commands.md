# Команды

Рабочая директория: `project/`. Переменные: `PYTHON` (default `python3`), `DB` (default `data/telecom.db`).

## Makefile

| Цель | Описание |
|------|----------|
| `make help` | список целей |
| `make db-create` | пустой файл БД |
| `make db-migrate` | применить миграции |
| `make db-seed` | загрузить seed |
| `make db-rollback` | откатить последнюю миграцию |
| `make db-reset` | удалить БД, миграции + seed |
| `make db-check` | smoke-проверка (таблицы, seed, FK, CHECK) |
| `make db-audit` | аудит целостности (`audit_db.py`) |
| `make test` | pytest |

## manage_db.py

```bash
python scripts/manage_db.py --db data/telecom.db <command>
```

Команды: `migrate`, `rollback`, `seed`, `reset`, `check`. `check` возвращает exit code 0/1.

## audit_db.py

```bash
python scripts/audit_db.py --db data/telecom.db
```

Выполняет все `queries/integrity/*.sql` по имени файла. Печатает сводку; exit code `0` — нарушений нет, `1` — есть находки или ошибка.

## Отчёты

SQL в `queries/reports/` запускаются вручную, например:

```bash
sqlite3 data/telecom.db < queries/reports/active-sims-by-client.sql
```
