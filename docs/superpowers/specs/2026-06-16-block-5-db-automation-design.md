# Блок 5: Скрипты автоматизации — спецификация

## Цель

Реализовать учебный CLI для управления локальной SQLite-БД SIM-карт и заменить временные команды `Makefile` на вызовы этого CLI.

## Область работ

- `project/scripts/manage_db.py` предоставляет команды `migrate`, `rollback`, `seed`, `reset`, `check`.
- `project/Makefile` вызывает CLI через `$(PYTHON) scripts/manage_db.py <command>`.
- `project/tests/test_manage_db.py` проверяет команды через временную БД.
- `project/migrations/down/` хранит явные down-миграции для rollback.
- `todo.md` и `task_logs.md` фиксируют завершение блока.

## CLI

Скрипт запускается из `project/`:

```bash
python scripts/manage_db.py <command>
```

Путь к БД задается так:

- `--db <path>` — приоритетный вариант для тестов;
- переменная окружения `DB`;
- по умолчанию `data/telecom.db`.

Команды:

- `migrate` создает файл БД при необходимости и применяет pending-миграции из `project/migrations/*.sql` по числовому префиксу.
- `rollback` откатывает последнюю примененную миграцию через matching-файл `project/migrations/down/<version>.sql` и удаляет запись из `migration_history`.
- `seed` применяет `project/seeds/seed.sql`; повторный запуск остается идемпотентным.
- `reset` удаляет файл БД, затем выполняет `migrate` и `seed`.
- `check` проверяет обязательные таблицы, примененные миграции, наличие seed-записей и базовую работу ограничений.

## Rollback

SQLite не умеет автоматически откатывать произвольные SQL-миграции. Поэтому rollback поддерживается только через явные down-файлы.

Для текущего блока нужен down-файл для `003_add_esim_support`. Он возвращает `sim_cards` к структуре до eSIM:

- удаляет поля `sim_type`, `eid`;
- убирает статус `qr_generated`;
- пересоздает связанные индексы/триггеры в состоянии до миграции.

Ограничение: это учебный локальный rollback. Если в данных есть eSIM-специфичные значения, они будут потеряны или нормализованы.

## Makefile

Цели:

- `db-create` создает директорию и файл БД.
- `db-migrate` вызывает `manage_db.py migrate`.
- `db-seed` вызывает `manage_db.py seed`.
- `db-rollback` вызывает `manage_db.py rollback`.
- `db-reset` вызывает `manage_db.py reset`.
- `db-check` вызывает `manage_db.py check`.
- `test` запускает `pytest`.

## Тесты

Тесты должны работать только с временной БД из `tmp_path`, не трогая `project/data/telecom.db`.

Покрыть:

- `migrate` строит схему и повторно не применяет миграции;
- `rollback` откатывает последнюю миграцию и обновляет `migration_history`;
- `seed` загружает ожидаемые записи и повторно не создает дубли;
- `reset` пересоздает БД со схемой и seed-данными;
- `check` возвращает `0` для валидной БД и non-zero для пустой/битой БД;
- `make test` доступен как цель.

## Критерии приемки

- Все пункты блока 5 в `todo.md` выполнены.
- `make test` внутри `project/` проходит.
- `make db-reset && make db-check` внутри `project/` проходит.
- В `task_logs.md` есть короткая запись за `2026-06-16`.

## Самопроверка спеки

- Placeholder-ов нет.
- `rollback` не противоречит выбранной политике: только down-миграции.
- Scope ограничен блоком 5, документация блока 6 не включена.
- Риски SQLite rollback описаны явно.
