import sqlite3
import sys
from pathlib import Path

import pytest

PROJECT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_DIR))

from migrate import apply_migrations, MIGRATIONS_DIR  # noqa: E402

EXPECTED_TABLES = {
    "clients", "individual_clients", "legal_clients", "sim_cards", "services",
    "sim_card_services", "payments", "knowledge_base_articles", "article_services",
    "migration_history",
}
EXPECTED_INDEXES = {
    "idx_clients_status", "idx_sim_cards_client_status", "idx_services_type_status",
    "uq_active_sim_card_service", "idx_sim_card_services_service_status",
    "idx_payments_client_status_created", "idx_payments_sim_card_id",
    "idx_articles_category_status", "idx_article_services_service_id",
    "uq_sim_cards_eid",
}


@pytest.fixture()
def empty_db(tmp_path):
    """Пустая БД БЕЗ schema.sql — миграции должны построить её сами."""
    conn = sqlite3.connect(tmp_path / "telecom.db")
    conn.execute("PRAGMA foreign_keys = ON")
    yield conn
    conn.close()


def _tables(conn):
    return {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}


def _indexes(conn):
    return {
        r[0] for r in conn.execute(
            "SELECT name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%'"
        )
    }


def _columns(conn, table):
    return {r[1] for r in conn.execute(f"PRAGMA table_info({table})")}


def _history(conn):
    return {r[0] for r in conn.execute("SELECT version FROM migration_history")}


def test_migrations_build_empty_db(empty_db):
    applied = apply_migrations(empty_db, MIGRATIONS_DIR)
    assert applied == [
        "001_create_tables",
        "002_add_indexes",
        "003_add_esim_support",
        "004_add_preferred_channel",
    ]

    assert EXPECTED_TABLES <= _tables(empty_db)
    assert EXPECTED_INDEXES <= _indexes(empty_db)

    # 003: поддержка eSIM — новые поля в sim_cards.
    assert {"sim_type", "eid"} <= _columns(empty_db, "sim_cards")

    # 004: предпочтительный канал уведомлений у клиента.
    assert "preferred_channel" in _columns(empty_db, "clients")
    empty_db.execute(
        """
        INSERT INTO clients (type, name, phone, email)
        VALUES ('individual', 'Тест Канал', '+79991112233', 'channel-default@example.test')
        """
    )
    assert empty_db.execute(
        "SELECT preferred_channel FROM clients WHERE email = 'channel-default@example.test'"
    ).fetchone()[0] == "email"

    # Миграции создают пустую таблицу services; наполнение — сидами (Блок 4).
    assert _columns(empty_db, "services")
    assert empty_db.execute("SELECT COUNT(*) FROM services").fetchone()[0] == 0


def test_migrations_are_idempotent(empty_db):
    apply_migrations(empty_db, MIGRATIONS_DIR)
    services_before = empty_db.execute("SELECT COUNT(*) FROM services").fetchone()[0]
    history_before = _history(empty_db)

    second = apply_migrations(empty_db, MIGRATIONS_DIR)  # не должно падать
    assert second == []  # нет pending

    assert empty_db.execute("SELECT COUNT(*) FROM services").fetchone()[0] == services_before
    assert _history(empty_db) == history_before  # без дублей


def test_failed_migration_rolls_back(tmp_path, empty_db):
    apply_migrations(empty_db, MIGRATIONS_DIR)
    tables_before = _tables(empty_db)
    history_before = _history(empty_db)

    bad_dir = tmp_path / "bad"
    bad_dir.mkdir()
    # Первый стейтмент валиден, второй падает -> вся миграция откатывается.
    (bad_dir / "999_bad.sql").write_text(
        "CREATE TABLE temp_rollback_marker (id INTEGER);\n"
        "INSERT INTO definitely_missing_table VALUES (1);\n",
        encoding="utf-8",
    )

    with pytest.raises(sqlite3.Error):
        apply_migrations(empty_db, bad_dir)

    assert "temp_rollback_marker" not in _tables(empty_db)
    assert "999_bad" not in _history(empty_db)
    assert _tables(empty_db) == tables_before
    assert _history(empty_db) == history_before
