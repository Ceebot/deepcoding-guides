import argparse
import os
import re
import sqlite3
import sys
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_DIR))

from migrate import MIGRATIONS_DIR, apply_migrations  # noqa: E402


DEFAULT_DB = PROJECT_DIR / "data" / "telecom.db"
SEED_PATH = PROJECT_DIR / "seeds" / "seed.sql"
DOWN_DIR = MIGRATIONS_DIR / "down"
REQUIRED_TABLES = {
    "clients",
    "individual_clients",
    "legal_clients",
    "sim_cards",
    "services",
    "sim_card_services",
    "payments",
    "knowledge_base_articles",
    "article_services",
    "migration_history",
    "tariffs",
    "tariff_services",
    "charges",
}
SEEDED_TABLES = ("clients", "services", "sim_cards", "tariffs")
MONTH_RE = re.compile(r"^\d{4}-(0[1-9]|1[0-2])$")


def _connect(db_path):
    Path(db_path).parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def _migration_versions():
    return [path.stem for path in sorted(MIGRATIONS_DIR.glob("*.sql"))]


def migrate(db_path):
    with _connect(db_path) as conn:
        apply_migrations(conn)


def rollback(db_path):
    with _connect(db_path) as conn:
        row = conn.execute(
            "SELECT version FROM migration_history ORDER BY version DESC LIMIT 1"
        ).fetchone()
        if row is None:
            return

        version = row[0]
        down_path = DOWN_DIR / f"{version}.sql"
        if not down_path.exists():
            raise RuntimeError(f"Нет down-миграции для {version}")

        conn.isolation_level = None
        conn.execute("PRAGMA foreign_keys=OFF")
        try:
            conn.executescript(
                "BEGIN;\n"
                + down_path.read_text(encoding="utf-8")
                + "\nDELETE FROM migration_history WHERE version = '{}';\nCOMMIT;".format(
                    version
                )
            )
        except Exception:
            conn.execute("ROLLBACK")
            raise
        finally:
            conn.execute("PRAGMA foreign_keys=ON")


def seed(db_path):
    with _connect(db_path) as conn:
        conn.executescript(SEED_PATH.read_text(encoding="utf-8"))


def reset(db_path):
    path = Path(db_path)
    if path.exists():
        path.unlink()
    migrate(path)
    seed(path)


def _tables(conn):
    return {
        row[0]
        for row in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")
    }


def _history(conn):
    return [
        row[0]
        for row in conn.execute("SELECT version FROM migration_history ORDER BY version")
    ]


def _constraints_work(conn):
    conn.execute("SAVEPOINT check_constraints")
    try:
        conn.execute(
            "INSERT INTO clients (id, type, name, phone, email, status) "
            "VALUES (-1, 'bad', 'Bad', '+000', 'bad@example.test', 'active')"
        )
    except sqlite3.IntegrityError:
        return True
    finally:
        conn.execute("ROLLBACK TO check_constraints")
        conn.execute("RELEASE check_constraints")
    return False


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


def check(db_path):
    with _connect(db_path) as conn:
        if not REQUIRED_TABLES <= _tables(conn):
            return 1
        if _history(conn) != _migration_versions():
            return 1
        if any(
            conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0] == 0
            for table in SEEDED_TABLES
        ):
            return 1
        if conn.execute("PRAGMA foreign_key_check").fetchone() is not None:
            return 1
        if not _constraints_work(conn):
            return 1
    return 0


def _db_path(value):
    return Path(value or os.environ.get("DB") or DEFAULT_DB)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Manage Telecom SQLite database")
    parser.add_argument("--db", default=None, help="Path to SQLite database")
    parser.add_argument(
        "command",
        choices=("migrate", "rollback", "seed", "reset", "check", "charge"),
    )
    parser.add_argument("--month", default=None, help="Billing month in YYYY-MM format")
    args = parser.parse_args(argv)
    db_path = _db_path(args.db)

    try:
        if args.command == "migrate":
            migrate(db_path)
        elif args.command == "rollback":
            rollback(db_path)
        elif args.command == "seed":
            seed(db_path)
        elif args.command == "reset":
            reset(db_path)
        elif args.command == "check":
            return check(db_path)
        elif args.command == "charge":
            charge(db_path, args.month)
    except Exception as exc:
        print(exc, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
