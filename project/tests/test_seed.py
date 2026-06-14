from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]
SEED_PATH = PROJECT_DIR / "seeds" / "seed.sql"


EXPECTED_COUNTS = {
    "clients": 8,
    "individual_clients": 5,
    "legal_clients": 3,
    "sim_cards": 10,
    "services": 8,
    "sim_card_services": 10,
    "payments": 8,
    "knowledge_base_articles": 5,
    "article_services": 6,
}


def _load_seed(db):
    db.executescript(SEED_PATH.read_text(encoding="utf-8"))


def _count(db, table):
    return db.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]


def test_seed_loads_repeatably_with_expected_counts(db):
    _load_seed(db)
    first_counts = {table: _count(db, table) for table in EXPECTED_COUNTS}

    _load_seed(db)
    second_counts = {table: _count(db, table) for table in EXPECTED_COUNTS}

    assert first_counts == EXPECTED_COUNTS
    assert second_counts == EXPECTED_COUNTS


def test_seed_contains_required_status_examples(db):
    _load_seed(db)

    sim_statuses = {
        row[0] for row in db.execute("SELECT DISTINCT status FROM sim_cards")
    }
    payment_statuses = {
        row[0] for row in db.execute("SELECT DISTINCT status FROM payments")
    }

    assert {"available", "reserved", "active", "blocked", "lost"} <= sim_statuses
    assert {"pending", "paid", "failed", "refunded"} <= payment_statuses
