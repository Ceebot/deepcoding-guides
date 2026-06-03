from pathlib import Path
import sqlite3

import pytest


PROJECT_DIR = Path(__file__).resolve().parents[1]
SCHEMA_PATH = PROJECT_DIR / "schema.sql"


@pytest.fixture()
def db(tmp_path):
    db_path = tmp_path / "telecom.db"
    connection = sqlite3.connect(db_path)
    connection.execute("PRAGMA foreign_keys = ON")

    schema_sql = SCHEMA_PATH.read_text(encoding="utf-8")
    connection.executescript(schema_sql)

    yield connection

    connection.close()
