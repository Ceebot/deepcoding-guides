from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]
SEED_PATH = PROJECT_DIR / "seeds" / "seed.sql"
QUERY_PATH = PROJECT_DIR / "queries" / "sim-cards-without-active-services.sql"
REVENUE_BY_TARIFFS_PATH = (
    PROJECT_DIR / "queries" / "reports" / "revenue-by-tariffs.sql"
)


def _load_seed(db):
    db.executescript(SEED_PATH.read_text(encoding="utf-8"))


def test_sim_cards_without_active_services(db):
    _load_seed(db)
    query = QUERY_PATH.read_text(encoding="utf-8")
    rows = db.execute(query).fetchall()
    ids = {row[0] for row in rows}
    assert ids == {3, 4, 5, 6, 8, 9}


def test_revenue_by_tariffs_groups_by_current_client_type(db):
    _load_seed(db)
    query = REVENUE_BY_TARIFFS_PATH.read_text(encoding="utf-8")
    rows = db.execute(query).fetchall()
    assert rows == [
        ("2026-01", 3, "Бизнес", "legal", 1, 1350),
        ("2026-01", 2, "Онлайн", "individual", 1, 750),
        ("2026-01", 1, "Старт", "individual", 1, 500),
        ("2026-01", 1, "Старт", "legal", 1, 500),
    ]
