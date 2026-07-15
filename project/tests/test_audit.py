import re
import sqlite3
import subprocess
import sys
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]
AUDIT_CLI = PROJECT_DIR / "scripts" / "audit_db.py"
MANAGE_CLI = PROJECT_DIR / "scripts" / "manage_db.py"
INTEGRITY_DIR = PROJECT_DIR / "queries" / "integrity"
INTEGRITY_NAMES = [
    "active-sim-cards-without-active-services",
    "active-services-on-inactive-sims",
    "payments-with-foreign-sim",
    "clients-without-type-details",
    "article-services-with-unpublished-services",
    "active-sim-cards-without-tariff",
]
AUDIT_LINE_RE = re.compile(r"\[(OK|FAIL|ERROR)\] ([^:]+): (\d+) row\(s\)")
MUTATING_SQL_RE = re.compile(
    r"\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|REPLACE)\b", re.I
)


def parse_audit_lines(output):
    return {
        match.group(2): {"status": match.group(1), "count": int(match.group(3))}
        for match in AUDIT_LINE_RE.finditer(output)
    }


def run_audit(db_path):
    return subprocess.run(
        [sys.executable, str(AUDIT_CLI), "--db", str(db_path)],
        cwd=PROJECT_DIR,
        text=True,
        capture_output=True,
    )


def run_reset(db_path):
    return subprocess.run(
        [sys.executable, str(MANAGE_CLI), "--db", str(db_path), "reset"],
        cwd=PROJECT_DIR,
        text=True,
        capture_output=True,
    )


def test_audit_passes_on_clean_seed(tmp_path):
    db_path = tmp_path / "telecom.db"
    reset = run_reset(db_path)
    assert reset.returncode == 0, reset.stderr

    result = run_audit(db_path)

    assert result.returncode == 0, result.stdout + result.stderr
    assert "Summary: 6/6 checks passed" in result.stdout
    parsed = parse_audit_lines(result.stdout)
    assert len(parsed) == len(INTEGRITY_NAMES)
    for name in INTEGRITY_NAMES:
        assert parsed[name] == {"status": "OK", "count": 0}


def test_audit_fails_on_corrupted_data(tmp_path):
    db_path = tmp_path / "telecom.db"
    assert run_reset(db_path).returncode == 0

    with sqlite3.connect(db_path) as conn:
        conn.execute("PRAGMA foreign_keys=ON")
        conn.execute("UPDATE sim_card_services SET status = 'disconnected' WHERE sim_card_id = 1")
        conn.execute("UPDATE sim_cards SET tariff_id = NULL WHERE id = 1")
        conn.execute("UPDATE sim_cards SET status = 'lost' WHERE id = 2")
        conn.execute("DELETE FROM individual_clients WHERE client_id = 1")
        conn.execute("UPDATE services SET status = 'deprecated' WHERE id = 1")
        conn.execute("DROP TRIGGER IF EXISTS trg_payments_sim_card_client")
        conn.execute("DROP TRIGGER IF EXISTS trg_payments_sim_card_client_update")
        conn.execute("UPDATE payments SET client_id = 2 WHERE id = 1")
        conn.commit()

    result = run_audit(db_path)

    assert result.returncode == 1, result.stdout + result.stderr
    output = result.stdout
    parsed = parse_audit_lines(output)
    assert len(parsed) == len(INTEGRITY_NAMES)
    for name in INTEGRITY_NAMES:
        assert parsed[name]["status"] == "FAIL"
        assert parsed[name]["count"] > 0
    assert "Summary: 0/6 checks passed" in output


def test_audit_fails_when_db_missing(tmp_path):
    db_path = tmp_path / "missing.db"

    result = run_audit(db_path)

    assert result.returncode == 1
    assert "Database not found" in result.stderr


def test_integrity_queries_are_read_only_select():
    for path in sorted(INTEGRITY_DIR.glob("*.sql")):
        body = re.sub(r"--.*$", "", path.read_text(encoding="utf-8"), flags=re.M)
        assert MUTATING_SQL_RE.search(body) is None, path.name
        assert re.search(r"\bSELECT\b", body, re.I), path.name
