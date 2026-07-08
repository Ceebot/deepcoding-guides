import os
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
        "004_add_preferred_channel",
    ]
    assert count_rows(db_path, "services") == 0


def test_rollback_reverts_last_migration(tmp_path):
    db_path = tmp_path / "telecom.db"
    assert run_cli(db_path, "migrate").returncode == 0

    result = run_cli(db_path, "rollback")

    assert result.returncode == 0, result.stderr
    assert history(db_path) == [
        "001_create_tables",
        "002_add_indexes",
        "003_add_esim_support",
    ]
    assert "preferred_channel" not in columns(db_path, "clients")
    assert {"sim_type", "eid"} <= columns(db_path, "sim_cards")


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
        "004_add_preferred_channel",
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


def test_make_test_target_runs_pytest():
    env = os.environ.copy()
    env["PYTEST_ADDOPTS"] = "-k 'not test_make_test_target_runs_pytest'"

    result = subprocess.run(
        ["make", "test", f"PYTHON={sys.executable}"],
        cwd=PROJECT_DIR,
        env=env,
        text=True,
        capture_output=True,
    )

    assert result.returncode == 0, result.stdout + result.stderr
