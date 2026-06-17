# Block 5 DB Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a tested SQLite automation CLI for block 5 of the Telecom SIM Cards учебный проект.

**Architecture:** Keep `project/migrate.py` as the small migration module and add `project/scripts/manage_db.py` as the CLI layer. Rollback uses explicit down-migrations in `project/migrations/down/`, not destructive table drops.

**Tech Stack:** Python standard library (`argparse`, `sqlite3`, `pathlib`, `subprocess` in tests), SQLite, pytest, Make.

---

## File Structure

- Create `project/scripts/manage_db.py`: CLI commands and thin orchestration.
- Create `project/migrations/down/003_add_esim_support.sql`: explicit down migration.
- Modify `project/migrate.py`: expose safe helpers if needed, keep old tests passing.
- Create `project/tests/test_manage_db.py`: subprocess CLI tests on `tmp_path`.
- Modify `project/Makefile`: route DB targets through CLI and add `test`.
- Modify `todo.md`: mark block 5 complete after checks pass.
- Modify `task_logs.md`: add one compact log entry for `2026-06-16`.

## Task 1: CLI Tests And Commands

**Files:**
- Create: `project/tests/test_manage_db.py`
- Create: `project/scripts/manage_db.py`
- Create: `project/migrations/down/003_add_esim_support.sql`
- Modify: `project/migrate.py`

- [ ] **Step 1: Write failing CLI tests**

Create tests that run:

```python
import sqlite3
import subprocess
import sys

from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]
CLI = PROJECT_DIR / "scripts" / "manage_db.py"


def run_cli(db_path, command):
    return subprocess.run(
        [sys.executable, str(CLI), "--db", str(db_path), command],
        cwd=PROJECT_DIR,
        text=True,
        capture_output=True,
    )


def count_rows(db_path, table):
    with sqlite3.connect(db_path) as conn:
        return conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]


def history(db_path):
    with sqlite3.connect(db_path) as conn:
        return [
            row[0]
            for row in conn.execute("SELECT version FROM migration_history ORDER BY version")
        ]


def columns(db_path, table):
    with sqlite3.connect(db_path) as conn:
        return {row[1] for row in conn.execute(f"PRAGMA table_info({table})")}


def test_migrate_builds_schema_and_is_idempotent(tmp_path):
    db_path = tmp_path / "telecom.db"

    first = run_cli(db_path, "migrate")
    second = run_cli(db_path, "migrate")

    assert first.returncode == 0, first.stderr
    assert second.returncode == 0, second.stderr
    assert history(db_path) == [
        "001_create_tables",
        "002_add_indexes",
        "003_add_esim_support",
    ]
    assert count_rows(db_path, "services") == 0


def test_rollback_reverts_last_migration(tmp_path):
    db_path = tmp_path / "telecom.db"
    assert run_cli(db_path, "migrate").returncode == 0

    result = run_cli(db_path, "rollback")

    assert result.returncode == 0, result.stderr
    assert history(db_path) == ["001_create_tables", "002_add_indexes"]
    assert "sim_type" not in columns(db_path, "sim_cards")
    assert "eid" not in columns(db_path, "sim_cards")


def test_seed_loads_repeatably_after_migrations(tmp_path):
    db_path = tmp_path / "telecom.db"
    assert run_cli(db_path, "migrate").returncode == 0

    first = run_cli(db_path, "seed")
    second = run_cli(db_path, "seed")

    assert first.returncode == 0, first.stderr
    assert second.returncode == 0, second.stderr
    assert count_rows(db_path, "clients") == 8
    assert count_rows(db_path, "services") == 8
    assert count_rows(db_path, "sim_cards") == 10


def test_reset_recreates_database_with_seed_data(tmp_path):
    db_path = tmp_path / "telecom.db"
    db_path.write_text("old database", encoding="utf-8")

    result = run_cli(db_path, "reset")

    assert result.returncode == 0, result.stderr
    assert count_rows(db_path, "clients") == 8
    assert history(db_path) == [
        "001_create_tables",
        "002_add_indexes",
        "003_add_esim_support",
    ]


def test_check_passes_for_valid_database_and_fails_for_empty_database(tmp_path):
    valid_db = tmp_path / "valid.db"
    empty_db = tmp_path / "empty.db"
    empty_db.touch()
    assert run_cli(valid_db, "reset").returncode == 0

    valid = run_cli(valid_db, "check")
    empty = run_cli(empty_db, "check")

    assert valid.returncode == 0, valid.stderr
    assert empty.returncode != 0
```

- [ ] **Step 2: Verify tests fail**

Run:

```bash
pytest project/tests/test_manage_db.py -q
```

Expected: FAIL because `project/scripts/manage_db.py` does not exist.

- [ ] **Step 3: Implement minimal CLI**

Implement `manage_db.py` with these functions:

```python
def migrate(db_path): ...
def rollback(db_path): ...
def seed(db_path): ...
def reset(db_path): ...
def check(db_path): ...
def main(argv=None): ...
```

Keep behavior exactly as specified in `docs/superpowers/specs/2026-06-16-block-5-db-automation-design.md`.

- [ ] **Step 4: Add down migration**

Create `project/migrations/down/003_add_esim_support.sql` that rebuilds `sim_cards` without `sim_type` and `eid`, restores the pre-eSIM status check, recreates `trg_sim_cards_client_update`, and recreates indexes from `002_add_indexes.sql` that target `sim_cards`.

- [ ] **Step 5: Run CLI tests**

Run:

```bash
pytest project/tests/test_manage_db.py -q
```

Expected: PASS.

- [ ] **Step 6: Run existing migration/seed tests**

Run:

```bash
pytest project/tests/test_migrations.py project/tests/test_seed.py -q
```

Expected: PASS.

## Task 2: Makefile And Project Tracking

**Files:**
- Modify: `project/Makefile`
- Modify: `todo.md`
- Modify: `task_logs.md`

- [ ] **Step 1: Write failing Makefile test**

Extend `project/tests/test_manage_db.py` with:

```python
def test_make_test_target_runs_pytest():
    result = subprocess.run(
        ["make", "test"],
        cwd=PROJECT_DIR,
        text=True,
        capture_output=True,
    )

    assert result.returncode == 0, result.stdout + result.stderr
```

- [ ] **Step 2: Verify test fails**

Run:

```bash
pytest project/tests/test_manage_db.py::test_make_test_target_runs_pytest -q
```

Expected: FAIL because `test` target does not exist.

- [ ] **Step 3: Update Makefile**

Use CLI-backed targets:

```make
PYTHON ?= python3
DB     ?= data/telecom.db
CLI    := scripts/manage_db.py

.PHONY: db-create db-migrate db-seed db-clean db-rollback db-reset db-check test help

db-create:
	mkdir -p $(dir $(DB))
	@test -f $(DB) || $(PYTHON) -c "import sqlite3; sqlite3.connect('$(DB)').close()"

db-migrate: ## Применить миграции к БД
	$(PYTHON) $(CLI) --db $(DB) migrate

db-seed: ## Загрузить seed-данные
	$(PYTHON) $(CLI) --db $(DB) seed

db-rollback: ## Откатить последнюю миграцию
	$(PYTHON) $(CLI) --db $(DB) rollback

db-reset: ## Сбросить БД и загрузить seed
	$(PYTHON) $(CLI) --db $(DB) reset

db-check: ## Smoke-проверка БД
	$(PYTHON) $(CLI) --db $(DB) check

test: ## Запустить pytest
	$(PYTHON) -m pytest
```

Preserve useful `help` behavior if possible.

- [ ] **Step 4: Mark block 5 complete**

In `todo.md`, mark all block 5 checkboxes as `[x]` only after tests pass.

- [ ] **Step 5: Update task log**

Add one short bullet under `## 2026-06-16` in `task_logs.md`:

```md
- Реализован блок 5: добавлен CLI управления SQLite-БД с миграциями, rollback через down-файлы, seed/reset/check, Makefile-обвязка и тесты команд.
```

- [ ] **Step 6: Run checks**

Run from `project/`:

```bash
make test
make db-reset
make db-check
```

Expected: all commands exit `0`.

## Self-Review

- Spec coverage: all commands, Makefile, tests, todo and task log are covered.
- Placeholder scan: no `TBD` or unspecified behavior remains.
- Type consistency: commands and paths match the spec.
