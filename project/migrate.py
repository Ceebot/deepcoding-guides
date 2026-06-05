"""Минимальный применятель миграций (только для тестов Блока 3).

Полноценный CLI manage_db.py — задача Блока 5. Здесь только то, что нужно
тестам: учёт применённых миграций в migration_history, применение pending по
порядку номера в имени, атомарность каждой миграции и идемпотентность.
"""
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent
MIGRATIONS_DIR = PROJECT_DIR / "migrations"


def _sorted_migrations(migrations_dir):
    paths = Path(migrations_dir).glob("*.sql")
    return sorted(paths, key=lambda p: int(p.name.split("_", 1)[0]))


def _apply_one(conn, path):
    # Оборачиваем файл в BEGIN/COMMIT и в той же транзакции пишем историю —
    # миграция и отметка о ней применяются атомарно. При ошибке откатываем всё.
    sql = path.read_text(encoding="utf-8")
    script = (
        "BEGIN;\n"
        + sql
        + "\nINSERT INTO migration_history (version, applied_at) "
        + "VALUES ('{}', datetime('now'));\nCOMMIT;".format(path.stem)
    )
    try:
        conn.executescript(script)
    except Exception:
        conn.execute("ROLLBACK")
        raise


def apply_migrations(conn, migrations_dir=MIGRATIONS_DIR):
    """Применяет pending-миграции по порядку. Возвращает список применённых версий."""
    conn.isolation_level = None  # ручное управление транзакциями
    conn.execute(
        "CREATE TABLE IF NOT EXISTS migration_history "
        "(version TEXT PRIMARY KEY, applied_at TEXT)"
    )
    applied = {row[0] for row in conn.execute("SELECT version FROM migration_history")}
    pending = [p for p in _sorted_migrations(migrations_dir) if p.stem not in applied]
    if not pending:
        return []

    # FK отключаем на время батча: нужно для миграций с перестроением таблиц
    # (DROP/RENAME) и заодно глушит проверки FK при seed.
    conn.execute("PRAGMA foreign_keys=OFF")
    try:
        for path in pending:
            _apply_one(conn, path)
    finally:
        conn.execute("PRAGMA foreign_keys=ON")
    return [p.stem for p in pending]


if __name__ == "__main__":
    # Тонкая точка входа для `make db-migrate`. Полноценный CLI (rollback/seed/
    # reset) — Блок 5. Аргумент: путь к БД (по умолчанию data/telecom.db).
    import sqlite3
    import sys

    db_path = sys.argv[1] if len(sys.argv) > 1 else PROJECT_DIR / "data" / "telecom.db"
    conn = sqlite3.connect(db_path)
    try:
        applied = apply_migrations(conn)
    finally:
        conn.close()
    print("Применены миграции:", ", ".join(applied) if applied else "нет новых")
