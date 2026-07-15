# Тарифы и помесячные начисления — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Добавить тарифы, назначение текущего тарифа SIM-карте, неизменяемые ежемесячные начисления, аудит и отчёт по начисленной выручке.

**Architecture:** `sim_cards.tariff_id` хранит только текущий nullable-тариф. `charges` хранит неизменяемый снимок тарифа и суммы за календарный месяц; история назначений и связь с платежами не вводятся. Начисление выполняет существующий CLI через одну идемпотентную SQL-вставку.

**Tech Stack:** SQLite, Python 3 standard library (`argparse`, `datetime`, `sqlite3`), pytest, Make.

## Global Constraints

- Все изменения реализации выполняются только внутри `project/`; этот план и утверждённая спека остаются в `docs/superpowers/`.
- Денежные поля используют `NUMERIC`; время создания задаётся `datetime('now')`.
- `sim_cards.tariff_id` остаётся nullable; активную SIM без тарифа ловит бизнес-аудит.
- Период начисления хранится строго как `YYYY-MM`.
- Одно начисление на SIM за месяц обеспечивается `UNIQUE (sim_card_id, billing_period)` и `INSERT OR IGNORE`.
- `charges` нельзя изменять или удалять обычными DML-операциями; оба внешних ключа используют `ON DELETE RESTRICT`.
- Архивный тариф нельзя назначить карте, но уже назначенный тариф продолжает начисляться после архивирования.
- Биллинг проверяет статус SIM, наличие тарифа и дату активации, но не статус тарифа.
- Не добавлять историю тарифов, prorating, валюту начисления или связь `charges` с `payments`.
- После изменений в `project/` обновить корневой `task_logs.md`.
- Не затрагивать существующий untracked-файл `.github/workflows/ci.yml`.
- Шаги с `git commit` выполнять только при отдельном явном разрешении пользователя.

## Карта файлов

**Создать:**

- `project/migrations/005_add_tariffs_and_charges.sql` — применяемое изменение схемы.
- `project/migrations/down/005_add_tariffs_and_charges.sql` — откат миграции 005.
- `project/queries/integrity/active-sim-cards-without-tariff.sql` — нарушение бизнес-инварианта.
- `project/queries/reports/revenue-by-tariffs.sql` — начисленная выручка по месяцу и тарифу.

**Изменить:**

- `project/schema.sql` — эталонная итоговая схема.
- `project/seeds/seed.sql` — тарифы, составы, назначения и демонстрационные начисления.
- `project/scripts/manage_db.py` — функция `charge()` и CLI-аргумент `--month`.
- `project/Makefile` — цель `db-charge`.
- `project/tests/test_schema.py` — ограничения, триггеры и неизменяемость.
- `project/tests/test_migrations.py` — миграция 005 и её объекты.
- `project/tests/test_manage_db.py` — расчёт начислений и CLI-валидация.
- `project/tests/test_seed.py` — новые ожидаемые данные и повторяемость.
- `project/tests/test_audit.py` — шестая integrity-проверка.
- `project/tests/test_queries.py` — результат отчёта.
- `project/README.md`, `project/docs/architecture.md`, `project/docs/database.md`, `project/docs/erd.md`, `project/docs/commands.md`, `project/docs/examples.md` — описание модели и запуска.
- `task_logs.md` — короткая запись о завершённой фиче.

---

### Task 1: Схема тарифов и начислений

**Files:**
- Create: `project/migrations/005_add_tariffs_and_charges.sql`
- Create: `project/migrations/down/005_add_tariffs_and_charges.sql`
- Modify: `project/schema.sql`
- Modify: `project/tests/test_schema.py`
- Modify: `project/tests/test_migrations.py`

**Interfaces:**
- Produces: таблицы `tariffs`, `tariff_services`, `charges`; nullable `sim_cards.tariff_id`; триггеры `trg_sim_cards_tariff_insert`, `trg_sim_cards_tariff_update`, `trg_charges_immutable_update`, `trg_charges_immutable_delete`.
- Produces: индексы `idx_sim_cards_tariff_id`, `idx_tariff_services_service_id`, `idx_charges_period_tariff`.

- [ ] **Step 1: Добавить падающие schema-тесты**

В `project/tests/test_schema.py` добавить helper и отдельные тесты:

```python
def insert_tariff(db, name="Учебный", fee=500, status="active"):
    cursor = db.execute(
        """
        INSERT INTO tariffs (name, description, monthly_fee, status)
        VALUES (?, 'Описание тарифа', ?, ?)
        """,
        (name, fee, status),
    )
    return cursor.lastrowid


def test_tariff_tables_and_nullable_sim_assignment(db):
    tables = {
        row[0]
        for row in db.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table'"
        )
    }
    assert {"tariffs", "tariff_services", "charges"} <= tables

    sim_card_id = insert_sim_card(db)
    assert db.execute(
        "SELECT tariff_id FROM sim_cards WHERE id = ?", (sim_card_id,)
    ).fetchone()[0] is None


def test_archived_tariff_cannot_be_assigned_but_existing_assignment_survives(db):
    active_id = insert_tariff(db)
    archived_id = insert_tariff(db, name="Архивный", status="archived")
    sim_card_id = insert_sim_card(db)

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO sim_cards
                (iccid, phone_number, status, tariff_id)
            VALUES ('8970100000000000099', '+79990000099', 'active', ?)
            """,
            (archived_id,),
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            "UPDATE sim_cards SET tariff_id = ? WHERE id = ?",
            (archived_id, sim_card_id),
        )

    db.execute(
        "UPDATE sim_cards SET tariff_id = ? WHERE id = ?",
        (active_id, sim_card_id),
    )
    db.execute("UPDATE tariffs SET status = 'archived' WHERE id = ?", (active_id,))
    assert db.execute(
        "SELECT tariff_id FROM sim_cards WHERE id = ?", (sim_card_id,)
    ).fetchone()[0] == active_id


def test_charge_is_validated_immutable_and_restricts_parent_deletion(db):
    tariff_id = insert_tariff(db)
    sim_card_id = insert_sim_card(db)
    db.execute(
        """
        INSERT INTO charges
            (sim_card_id, tariff_id, billing_period, tariff_name, amount)
        VALUES (?, ?, '2026-02', 'Учебный', 500)
        """,
        (sim_card_id, tariff_id),
    )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute("UPDATE charges SET amount = 600")
    with pytest.raises(sqlite3.IntegrityError):
        db.execute("DELETE FROM charges")
    with pytest.raises(sqlite3.IntegrityError):
        db.execute("DELETE FROM sim_cards WHERE id = ?", (sim_card_id,))
    with pytest.raises(sqlite3.IntegrityError):
        db.execute("DELETE FROM tariffs WHERE id = ?", (tariff_id,))
    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO charges
                (sim_card_id, tariff_id, billing_period, tariff_name, amount)
            VALUES (?, ?, '2026-13', 'Учебный', 500)
            """,
            (sim_card_id, tariff_id),
        )
    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO charges
                (sim_card_id, tariff_id, billing_period, tariff_name, amount)
            VALUES (?, ?, '2026-02', 'Учебный', 500)
            """,
            (sim_card_id, tariff_id),
        )
    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO charges
                (sim_card_id, tariff_id, billing_period, tariff_name, amount)
            VALUES (?, ?, '2026-03', 'Учебный', -1)
            """,
            (sim_card_id, tariff_id),
        )
```

Расширить `test_schema_creates_expected_tables` новыми таблицами. В `test_check_constraints_are_enforced` проверить тариф:

```python
with pytest.raises(sqlite3.IntegrityError):
    insert_tariff(db, name="Минус", fee=-1)
with pytest.raises(sqlite3.IntegrityError):
    insert_tariff(db, name="Неизвестный", status="deprecated")
```

- [ ] **Step 2: Запустить schema-тесты и подтвердить RED**

Run: `cd project && python3 -m pytest tests/test_schema.py -q`

Expected: FAIL с `no such table: tariffs` или отсутствием новых таблиц.

- [ ] **Step 3: Добавить миграцию 005**

В `project/migrations/005_add_tariffs_and_charges.sql` использовать следующий DDL:

```sql
CREATE TABLE tariffs (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    monthly_fee NUMERIC NOT NULL CHECK (monthly_fee >= 0),
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'archived')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE tariff_services (
    tariff_id INTEGER NOT NULL,
    service_id INTEGER NOT NULL,
    PRIMARY KEY (tariff_id, service_id),
    FOREIGN KEY (tariff_id) REFERENCES tariffs(id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE RESTRICT
);

ALTER TABLE sim_cards
ADD COLUMN tariff_id INTEGER REFERENCES tariffs(id) ON DELETE SET NULL;

CREATE TABLE charges (
    id INTEGER PRIMARY KEY,
    sim_card_id INTEGER NOT NULL,
    tariff_id INTEGER NOT NULL,
    billing_period TEXT NOT NULL
        CHECK (
            billing_period GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]'
            AND substr(billing_period, 6, 2) BETWEEN '01' AND '12'
        ),
    tariff_name TEXT NOT NULL,
    amount NUMERIC NOT NULL CHECK (amount >= 0),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE (sim_card_id, billing_period),
    FOREIGN KEY (sim_card_id) REFERENCES sim_cards(id) ON DELETE RESTRICT,
    FOREIGN KEY (tariff_id) REFERENCES tariffs(id) ON DELETE RESTRICT
);

CREATE INDEX idx_sim_cards_tariff_id ON sim_cards(tariff_id);
CREATE INDEX idx_tariff_services_service_id ON tariff_services(service_id);
CREATE INDEX idx_charges_period_tariff
    ON charges(billing_period, tariff_id);

CREATE TRIGGER trg_sim_cards_tariff_insert
BEFORE INSERT ON sim_cards
FOR EACH ROW
WHEN NEW.tariff_id IS NOT NULL
BEGIN
    SELECT RAISE(ABORT, 'only active tariff can be assigned')
    WHERE NOT EXISTS (
        SELECT 1 FROM tariffs
        WHERE id = NEW.tariff_id AND status = 'active'
    );
END;

CREATE TRIGGER trg_sim_cards_tariff_update
BEFORE UPDATE OF tariff_id ON sim_cards
FOR EACH ROW
WHEN NEW.tariff_id IS NOT NULL
BEGIN
    SELECT RAISE(ABORT, 'only active tariff can be assigned')
    WHERE NOT EXISTS (
        SELECT 1 FROM tariffs
        WHERE id = NEW.tariff_id AND status = 'active'
    );
END;

CREATE TRIGGER trg_charges_immutable_update
BEFORE UPDATE ON charges
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'charges are immutable');
END;

CREATE TRIGGER trg_charges_immutable_delete
BEFORE DELETE ON charges
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'charges are immutable');
END;
```

- [ ] **Step 4: Синхронизировать эталонную схему**

В `project/schema.sql` разместить `tariffs` до `sim_cards`, добавить `tariff_id` в `sim_cards`, а `tariff_services` и `charges` — после определения `services` и `sim_cards`. Добавить те же ограничения, индексы и четыре триггера, что в миграции 005. Не менять существующие enum и триггеры.

- [ ] **Step 5: Добавить down-миграцию**

Создать `project/migrations/down/005_add_tariffs_and_charges.sql`:

```sql
DROP TRIGGER IF EXISTS trg_sim_cards_tariff_insert;
DROP TRIGGER IF EXISTS trg_sim_cards_tariff_update;
DROP INDEX IF EXISTS idx_sim_cards_tariff_id;
DROP TABLE IF EXISTS charges;
DROP TABLE IF EXISTS tariff_services;
ALTER TABLE sim_cards DROP COLUMN tariff_id;
DROP TABLE IF EXISTS tariffs;
```

Триггеры и индекс `charges` удалятся вместе с таблицей. Порядок сохраняет внешнюю целостность.

- [ ] **Step 6: Расширить тест миграций**

В `project/tests/test_migrations.py` добавить новые таблицы и индексы в `EXPECTED_TABLES`/`EXPECTED_INDEXES`, версию `"005_add_tariffs_and_charges"` в ожидаемый список и проверки:

```python
assert "tariff_id" in _columns(empty_db, "sim_cards")
assert {"id", "name", "monthly_fee", "status"} <= _columns(empty_db, "tariffs")
assert {
    "sim_card_id", "tariff_id", "billing_period", "tariff_name", "amount"
} <= _columns(empty_db, "charges")
```

В `project/tests/test_manage_db.py::test_rollback_reverts_last_migration` изменить ожидаемую историю: до rollback она содержит 005, после rollback — версии 001–004; проверить отсутствие `tariff_id`, `tariffs`, `tariff_services`, `charges`.

- [ ] **Step 7: Запустить тесты схемы и миграций**

Run: `cd project && python3 -m pytest tests/test_schema.py tests/test_migrations.py tests/test_manage_db.py::test_rollback_reverts_last_migration -q`

Expected: PASS.

- [ ] **Step 8: Commit gate**

При явном разрешении:

```bash
git add project/schema.sql project/migrations/005_add_tariffs_and_charges.sql project/migrations/down/005_add_tariffs_and_charges.sql project/tests/test_schema.py project/tests/test_migrations.py project/tests/test_manage_db.py
git commit -m "Добавлены тарифы и неизменяемые начисления"
```

---

### Task 2: Повторяемые тарифные seed-данные

**Files:**
- Modify: `project/seeds/seed.sql`
- Modify: `project/tests/test_seed.py`
- Modify: `project/tests/test_manage_db.py`

**Interfaces:**
- Consumes: таблицы и ограничения Task 1.
- Produces: четыре тарифа, связи с услугами, тарифы у всех active SIM и четыре начисления за `2026-01`.

- [ ] **Step 1: Написать падающие seed-тесты**

В `EXPECTED_COUNTS` добавить:

```python
"tariffs": 4,
"tariff_services": 8,
"charges": 4,
```

Добавить:

```python
def test_seed_assigns_tariffs_and_keeps_integrity_clean(db):
    _load_seed(db)
    active_without_tariff = db.execute(
        """
        SELECT COUNT(*)
        FROM sim_cards
        WHERE status = 'active' AND tariff_id IS NULL
        """
    ).fetchone()[0]
    statuses = {
        row[0] for row in db.execute("SELECT DISTINCT status FROM tariffs")
    }
    assert active_without_tariff == 0
    assert statuses == {"active", "archived"}


def test_seed_charges_are_snapshots_for_one_period(db):
    _load_seed(db)
    rows = db.execute(
        """
        SELECT billing_period, COUNT(*), SUM(amount)
        FROM charges
        GROUP BY billing_period
        """
    ).fetchall()
    assert rows == [("2026-01", 4, 3100)]
```

Выбрать тарифные суммы так, чтобы четыре активные SIM дали итог `3100`; если используются другие конкретные суммы, одновременно зафиксировать их в тесте.

- [ ] **Step 2: Запустить seed-тест и подтвердить RED**

Run: `cd project && python3 -m pytest tests/test_seed.py -q`

Expected: FAIL из-за отсутствующих строк в новых таблицах.

- [ ] **Step 3: Добавить seed-данные**

В `project/seeds/seed.sql`:

1. До `sim_cards` вставить четыре тарифа через `INSERT OR IGNORE`.
2. После `services` вставить восемь пар `tariff_services`.
3. Добавить `tariff_id` в список колонок и значения SIM-карт; карты 1, 2, 7, 10 со статусом `active` обязаны получить активные тарифы.
4. После SIM-карт вставить четыре снимка `charges` за `2026-01`.

Использовать форму:

```sql
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

INSERT OR IGNORE INTO charges
    (id, sim_card_id, tariff_id, billing_period, tariff_name, amount, created_at)
VALUES
    (1, 1, 1, '2026-01', 'Старт', 500, '2026-01-31 23:00:00'),
    (2, 2, 2, '2026-01', 'Онлайн', 750, '2026-01-31 23:00:00'),
    (3, 7, 3, '2026-01', 'Бизнес', 1350, '2026-01-31 23:00:00'),
    (4, 10, 1, '2026-01', 'Старт', 500, '2026-01-31 23:00:00');
```

- [ ] **Step 4: Обновить smoke-ожидания CLI**

В `project/scripts/manage_db.py` позже будут добавлены таблицы в `REQUIRED_TABLES`; уже сейчас расширить `project/tests/test_manage_db.py` проверками count после `seed`/`reset`:

```python
assert count_rows(db_path, "tariffs") == 4
assert count_rows(db_path, "charges") == 4
```

- [ ] **Step 5: Запустить seed и reset-тесты**

Run: `cd project && python3 -m pytest tests/test_seed.py tests/test_manage_db.py -q`

Expected: PASS.

- [ ] **Step 6: Commit gate**

При явном разрешении:

```bash
git add project/seeds/seed.sql project/tests/test_seed.py project/tests/test_manage_db.py
git commit -m "Добавлены демонстрационные тарифы и начисления"
```

---

### Task 3: CLI помесячного начисления

**Files:**
- Modify: `project/scripts/manage_db.py`
- Modify: `project/Makefile`
- Modify: `project/tests/test_manage_db.py`

**Interfaces:**
- Produces: `_month_bounds(value: str) -> tuple[str, str]`.
- Produces: `charge(db_path: Path, billing_period: str) -> int`, где результат — число вставленных строк.
- Produces: CLI `charge --month YYYY-MM` и `make db-charge MONTH=YYYY-MM`.

- [ ] **Step 1: Добавить падающие CLI-тесты**

Расширить helper:

```python
def run_cli(db_path, command, *extra_args):
    return subprocess.run(
        [sys.executable, str(CLI), "--db", str(db_path), command, *extra_args],
        cwd=PROJECT_DIR,
        text=True,
        capture_output=True,
    )
```

Добавить тесты:

```python
def test_charge_creates_full_monthly_snapshots_and_is_idempotent(tmp_path):
    db_path = tmp_path / "telecom.db"
    assert run_cli(db_path, "reset").returncode == 0

    first = run_cli(db_path, "charge", "--month", "2026-02")
    with sqlite3.connect(db_path) as conn:
        conn.execute(
            """
            UPDATE tariffs
            SET name = 'Старт Новый', monthly_fee = 600
            WHERE id = 1
            """
        )
        conn.commit()
    second = run_cli(db_path, "charge", "--month", "2026-02")

    assert first.returncode == 0, first.stderr
    assert second.returncode == 0, second.stderr
    assert "2026-02: 4 charge(s) created" in first.stdout
    assert "2026-02: 0 charge(s) created" in second.stdout
    assert count_rows(db_path, "charges") == 8
    with sqlite3.connect(db_path) as conn:
        snapshot = conn.execute(
            """
            SELECT tariff_name, amount
            FROM charges
            WHERE sim_card_id = 1 AND billing_period = '2026-02'
            """
        ).fetchone()
    assert snapshot == ("Старт", 500)


def test_charge_uses_sim_status_and_activation_date_not_tariff_status(tmp_path):
    db_path = tmp_path / "telecom.db"
    assert run_cli(db_path, "reset").returncode == 0
    with sqlite3.connect(db_path) as conn:
        conn.execute("UPDATE tariffs SET status = 'archived' WHERE id = 1")
        conn.execute(
            "UPDATE sim_cards SET activated_at = '2026-03-01' WHERE id = 2"
        )
        conn.commit()

    result = run_cli(db_path, "charge", "--month", "2026-02")

    assert result.returncode == 0, result.stderr
    with sqlite3.connect(db_path) as conn:
        charged_ids = {
            row[0]
            for row in conn.execute(
                """
                SELECT sim_card_id
                FROM charges
                WHERE billing_period = '2026-02'
                """
            )
        }
    assert 1 in charged_ids
    assert 2 not in charged_ids


def test_charge_rejects_invalid_or_missing_month(tmp_path):
    db_path = tmp_path / "telecom.db"
    assert run_cli(db_path, "reset").returncode == 0
    invalid = run_cli(db_path, "charge", "--month", "2026-13")
    missing = run_cli(db_path, "charge")
    assert invalid.returncode != 0
    assert missing.returncode != 0
```

- [ ] **Step 2: Запустить CLI-тесты и подтвердить RED**

Run: `cd project && python3 -m pytest tests/test_manage_db.py -q`

Expected: FAIL, команда `charge` отсутствует.

- [ ] **Step 3: Реализовать разбор периода и начисление**

В `project/scripts/manage_db.py` добавить `import re` и:

```python
MONTH_RE = re.compile(r"^\d{4}-(0[1-9]|1[0-2])$")


def _month_bounds(value):
    if not value or MONTH_RE.fullmatch(value) is None:
        raise ValueError("Month must use YYYY-MM format")
    year, month = map(int, value.split("-"))
    if month == 12:
        next_period = f"{year + 1:04d}-01-01"
    else:
        next_period = f"{year:04d}-{month + 1:02d}-01"
    return f"{value}-01", next_period


def charge(db_path, billing_period):
    _, next_period = _month_bounds(billing_period)
    with _connect(db_path) as conn:
        cursor = conn.execute(
            """
            INSERT OR IGNORE INTO charges
                (sim_card_id, tariff_id, billing_period, tariff_name, amount)
            SELECT
                sc.id,
                t.id,
                ?,
                t.name,
                t.monthly_fee
            FROM sim_cards sc
            JOIN tariffs t ON t.id = sc.tariff_id
            WHERE sc.status = 'active'
              AND sc.activated_at IS NOT NULL
              AND datetime(sc.activated_at) < datetime(?)
            """,
            (billing_period, next_period),
        )
        created = cursor.rowcount
    print(f"{billing_period}: {created} charge(s) created")
    return created
```

Не добавлять `t.status = 'active'`: это нарушит требование об уже назначенных архивных тарифах.

- [ ] **Step 4: Подключить команду к argparse**

Расширить choices значением `charge`, добавить:

```python
parser.add_argument("--month", default=None, help="Billing month in YYYY-MM format")
```

В dispatch:

```python
elif args.command == "charge":
    charge(db_path, args.month)
```

Добавить `tariffs`, `tariff_services`, `charges` в `REQUIRED_TABLES` и `tariffs` в `SEEDED_TABLES`.

- [ ] **Step 5: Добавить Makefile-цель**

Изменить `.PHONY` и добавить:

```make
db-charge: ## Начислить абонплату за MONTH=YYYY-MM
	@test -n "$(MONTH)" || (echo "MONTH is required (YYYY-MM)" >&2; exit 2)
	$(PYTHON) $(CLI) --db $(DB) charge --month $(MONTH)
```

- [ ] **Step 6: Запустить CLI-тесты**

Run: `cd project && python3 -m pytest tests/test_manage_db.py -q`

Expected: PASS.

- [ ] **Step 7: Commit gate**

При явном разрешении:

```bash
git add project/scripts/manage_db.py project/Makefile project/tests/test_manage_db.py
git commit -m "Добавлено идемпотентное начисление абонплаты"
```

---

### Task 4: Integrity-проверка и отчёт по выручке

**Files:**
- Create: `project/queries/integrity/active-sim-cards-without-tariff.sql`
- Create: `project/queries/reports/revenue-by-tariffs.sql`
- Modify: `project/tests/test_audit.py`
- Modify: `project/tests/test_queries.py`

**Interfaces:**
- Produces: read-only integrity SQL, где ноль строк означает успех.
- Produces: отчёт с колонками `billing_period`, `tariff_id`, `tariff_name`, `charge_count`, `revenue`.

- [ ] **Step 1: Добавить падающий audit-тест**

В `INTEGRITY_NAMES` добавить `"active-sim-cards-without-tariff"`, ожидаемый clean summary заменить на `6/6`.

В corruption setup добавить:

```python
conn.execute("UPDATE sim_cards SET tariff_id = NULL WHERE id = 1")
```

Ожидаемый broken summary заменить на `0/6`.

- [ ] **Step 2: Добавить падающий тест отчёта**

В `project/tests/test_queries.py` добавить путь и тест:

```python
REVENUE_BY_TARIFFS_PATH = (
    PROJECT_DIR / "queries" / "reports" / "revenue-by-tariffs.sql"
)


def test_revenue_by_tariffs_uses_charge_snapshots(db):
    _load_seed(db)
    query = REVENUE_BY_TARIFFS_PATH.read_text(encoding="utf-8")
    rows = db.execute(query).fetchall()
    assert rows == [
        ("2026-01", 3, "Бизнес", 1, 1350),
        ("2026-01", 1, "Старт", 2, 1000),
        ("2026-01", 2, "Онлайн", 1, 750),
    ]
```

- [ ] **Step 3: Запустить query-тесты и подтвердить RED**

Run: `cd project && python3 -m pytest tests/test_audit.py tests/test_queries.py -q`

Expected: FAIL из-за отсутствующих SQL-файлов/шестой проверки.

- [ ] **Step 4: Создать integrity SQL**

`project/queries/integrity/active-sim-cards-without-tariff.sql`:

```sql
-- Активные SIM-карты, которым не назначен текущий тариф.

SELECT
    id,
    phone_number,
    client_id
FROM sim_cards
WHERE status = 'active'
  AND tariff_id IS NULL;
```

- [ ] **Step 5: Создать отчёт**

`project/queries/reports/revenue-by-tariffs.sql`:

```sql
-- Начисленная абонплата по месяцам и снимкам тарифов.
-- Это начисления из charges, а не сумма фактически оплаченных payments.

SELECT
    billing_period,
    tariff_id,
    tariff_name,
    COUNT(*) AS charge_count,
    ROUND(SUM(amount), 2) AS revenue
FROM charges
GROUP BY billing_period, tariff_id, tariff_name
ORDER BY billing_period, revenue DESC, tariff_id;
```

- [ ] **Step 6: Запустить audit/query-тесты**

Run: `cd project && python3 -m pytest tests/test_audit.py tests/test_queries.py -q`

Expected: PASS, включая read-only проверку всех integrity SQL.

- [ ] **Step 7: Commit gate**

При явном разрешении:

```bash
git add project/queries/integrity/active-sim-cards-without-tariff.sql project/queries/reports/revenue-by-tariffs.sql project/tests/test_audit.py project/tests/test_queries.py
git commit -m "Добавлены аудит тарифов и отчёт по выручке"
```

---

### Task 5: Документация, журнал и итоговая проверка

**Files:**
- Modify: `project/README.md`
- Modify: `project/docs/architecture.md`
- Modify: `project/docs/database.md`
- Modify: `project/docs/erd.md`
- Modify: `project/docs/commands.md`
- Modify: `project/docs/examples.md`
- Modify: `task_logs.md`

**Interfaces:**
- Consumes: завершённые schema, CLI и SQL из Tasks 1–4.
- Produces: документацию, по которой новый пользователь может сбросить БД, начислить месяц, запустить аудит и прочитать отчёт.

- [ ] **Step 1: Обновить документацию модели**

В `project/docs/architecture.md`, `project/docs/database.md` и `project/docs/erd.md` описать:

```text
tariffs 1:N sim_cards
tariffs M:N services через tariff_services
sim_cards 1:N charges
tariffs 1:N charges
```

Явно указать:

- `tariff_id` nullable;
- архивный тариф нельзя назначить, но существующее назначение сохраняется;
- `charges` — неизменяемый снимок без связи с `payments`;
- новая версия схемы включает миграцию 005.

- [ ] **Step 2: Обновить команды и примеры**

В `project/README.md` и `project/docs/commands.md` добавить:

```bash
make db-charge MONTH=2026-02
make db-audit
```

В `project/docs/examples.md` добавить запуск/назначение двух новых SQL-файлов и пояснить, что revenue — начисленная, а не оплаченная сумма.

- [ ] **Step 3: Обновить task log**

В начало `task_logs.md` под `## 2026-07-15` добавить один компактный пункт:

```markdown
- Добавлены тарифы и их состав, nullable-привязка тарифа к SIM-карте, неизменяемые помесячные начисления, команда `db-charge`, integrity-проверка активных SIM без тарифа и отчёт по начисленной выручке; архивный тариф нельзя назначить заново, но существующие назначения продолжают начисляться.
```

- [ ] **Step 4: Запустить целевые тесты**

Run: `cd project && python3 -m pytest tests/test_schema.py tests/test_migrations.py tests/test_seed.py tests/test_manage_db.py tests/test_audit.py tests/test_queries.py -q`

Expected: PASS.

- [ ] **Step 5: Пересобрать и проверить учебную БД**

Run:

```bash
cd project
make db-reset
make db-check
make db-audit
make db-charge MONTH=2026-02
make db-charge MONTH=2026-02
```

Expected:

- reset/check/audit завершаются с кодом 0;
- audit сообщает `6/6 checks passed`;
- первый `db-charge` сообщает `4 charge(s) created`;
- второй сообщает `0 charge(s) created`.

- [ ] **Step 6: Запустить полный набор тестов**

Run: `cd project && make test`

Expected: PASS без новых предупреждений и ошибок.

- [ ] **Step 7: Проверить итоговый diff**

Run: `git status --short && git diff --check && git diff -- project/ task_logs.md docs/superpowers/specs/2026-07-15-tariffs-monthly-charges-design.md docs/superpowers/plans/2026-07-15-tariffs-monthly-charges.md`

Expected: `git diff --check` не выводит ошибок; `.github/workflows/ci.yml` остаётся нетронутым.

- [ ] **Step 8: Commit gate**

При явном разрешении:

```bash
git add project/README.md project/docs/architecture.md project/docs/database.md project/docs/erd.md project/docs/commands.md project/docs/examples.md task_logs.md
git commit -m "Документированы тарифы и помесячный биллинг"
```
