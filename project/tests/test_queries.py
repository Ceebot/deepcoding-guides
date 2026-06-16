from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]
SEED_PATH = PROJECT_DIR / "seeds" / "seed.sql"
QUERY_PATH = PROJECT_DIR / "queries" / "sim-cards-without-active-services.sql"


def _load_seed(db):
    db.executescript(SEED_PATH.read_text(encoding="utf-8"))


def test_sim_cards_without_active_services(db):
    _load_seed(db)
    query = QUERY_PATH.read_text(encoding="utf-8")
    rows = db.execute(query).fetchall()
    ids = {row[0] for row in rows}
    assert ids == {3, 4, 5, 6, 8, 9}
