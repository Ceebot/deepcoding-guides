import os
import sqlite3
import subprocess
import sys
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]
CLI = PROJECT_DIR / "scripts" / "manage_db.py"


def run_cli(db_path, command, *extra_args):
    return subprocess.run(
        [sys.executable, str(CLI), "--db", str(db_path), command, *extra_args],
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
        "005_add_tariffs_and_charges",
    ]
    assert count_rows(db_path, "services") == 0


def test_rollback_reverts_last_migration(tmp_path):
    db_path = tmp_path / "telecom.db"
    assert run_cli(db_path, "migrate").returncode == 0

    assert history(db_path) == [
        "001_create_tables",
        "002_add_indexes",
        "003_add_esim_support",
        "004_add_preferred_channel",
        "005_add_tariffs_and_charges",
    ]

    result = run_cli(db_path, "rollback")

    assert result.returncode == 0, result.stderr
    assert history(db_path) == [
        "001_create_tables",
        "002_add_indexes",
        "003_add_esim_support",
        "004_add_preferred_channel",
    ]
    assert "preferred_channel" in columns(db_path, "clients")
    assert "tariff_id" not in columns(db_path, "sim_cards")
    assert {"sim_type", "eid"} <= columns(db_path, "sim_cards")
    with sqlite3.connect(db_path) as conn:
        tables = {
            row[0]
            for row in conn.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
        }
    assert "tariffs" not in tables
    assert "tariff_services" not in tables
    assert "charges" not in tables


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
    assert count_rows(db_path, "tariffs") == 4
    assert count_rows(db_path, "charges") == 4


def test_reset_recreates_database_with_seed_data(tmp_path):
    db_path = tmp_path / "telecom.db"
    db_path.write_text("old database", encoding="utf-8")

    result = run_cli(db_path, "reset")

    assert result.returncode == 0, result.stderr
    assert count_rows(db_path, "clients") == 8
    assert count_rows(db_path, "tariffs") == 4
    assert count_rows(db_path, "charges") == 4
    assert history(db_path) == [
        "001_create_tables",
        "002_add_indexes",
        "003_add_esim_support",
        "004_add_preferred_channel",
        "005_add_tariffs_and_charges",
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
    assert "Month must use YYYY-MM format" in invalid.stderr
    assert "Month must use YYYY-MM format" in missing.stderr


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
