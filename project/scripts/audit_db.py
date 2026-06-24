import argparse
import os
import sqlite3
import sys
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]
DEFAULT_DB = PROJECT_DIR / "data" / "telecom.db"
INTEGRITY_DIR = PROJECT_DIR / "queries" / "integrity"
SAMPLE_ROWS = 3


def _connect(db_path):
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def _integrity_checks():
    if not INTEGRITY_DIR.is_dir():
        raise FileNotFoundError(f"Нет каталога проверок: {INTEGRITY_DIR}")
    return sorted(INTEGRITY_DIR.glob("*.sql"))


def run_audit(db_path, sample_rows=SAMPLE_ROWS):
    checks = _integrity_checks()
    if not checks:
        raise FileNotFoundError(f"Нет SQL-файлов в {INTEGRITY_DIR}")

    violations = 0
    with _connect(db_path) as conn:
        for path in checks:
            name = path.stem
            try:
                sql = path.read_text(encoding="utf-8")
                rows = conn.execute(sql).fetchall()
            except (OSError, sqlite3.Error) as exc:
                print(f"[ERROR] {name}: {exc}", file=sys.stderr)
                violations += 1
                continue

            count = len(rows)
            status = "OK" if count == 0 else "FAIL"
            print(f"[{status}] {name}: {count} row(s)")
            if count:
                violations += 1
                for row in rows[:sample_rows]:
                    print(f"  - {dict(row)}")
                if count > sample_rows:
                    print(f"  ... and {count - sample_rows} more")

    print(f"\nSummary: {len(checks) - violations}/{len(checks)} checks passed")
    return 0 if violations == 0 else 1


def _db_path(value):
    return Path(value or os.environ.get("DB") or DEFAULT_DB)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Run integrity checks on Telecom DB")
    parser.add_argument("--db", default=None, help="Path to SQLite database")
    args = parser.parse_args(argv)
    db_path = _db_path(args.db)

    if not db_path.exists():
        print(f"Database not found: {db_path}", file=sys.stderr)
        return 1

    try:
        return run_audit(db_path)
    except Exception as exc:
        print(exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
