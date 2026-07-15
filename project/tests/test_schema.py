import sqlite3

import pytest


def insert_client(
    db,
    email="ivan@example.test",
    phone="+79990000001",
    client_type="individual",
):
    cursor = db.execute(
        """
        INSERT INTO clients (type, name, phone, email)
        VALUES (?, 'Иван Иванов', ?, ?)
        """,
        (client_type, phone, email),
    )
    return cursor.lastrowid


def insert_sim_card(
    db,
    iccid="8970100000000000001",
    phone_number="+79990000003",
    client_id=None,
):
    cursor = db.execute(
        """
        INSERT INTO sim_cards (iccid, phone_number, status, client_id)
        VALUES (?, ?, 'available', ?)
        """,
        (iccid, phone_number, client_id),
    )
    return cursor.lastrowid


def insert_tariff(db, name="Учебный", fee=500, status="active"):
    cursor = db.execute(
        """
        INSERT INTO tariffs (name, description, monthly_fee, status)
        VALUES (?, 'Описание тарифа', ?, ?)
        """,
        (name, fee, status),
    )
    return cursor.lastrowid


def insert_service(db, name="Интернет"):
    cursor = db.execute(
        """
        INSERT INTO services (name, description, type, cost, billing_period)
        VALUES (?, 'Описание', 'internet', 500, 'monthly')
        """,
        (name,),
    )
    return cursor.lastrowid


def insert_article(db, slug="internet"):
    cursor = db.execute(
        """
        INSERT INTO knowledge_base_articles (title, slug, category, content)
        VALUES ('Интернет', ?, 'services', 'Описание')
        """,
        (slug,),
    )
    return cursor.lastrowid


def test_schema_creates_expected_tables(db):
    rows = db.execute(
        """
        SELECT name
        FROM sqlite_master
        WHERE type = 'table'
        """
    ).fetchall()

    assert {
        "clients",
        "individual_clients",
        "legal_clients",
        "tariffs",
        "sim_cards",
        "services",
        "tariff_services",
        "sim_card_services",
        "payments",
        "charges",
        "knowledge_base_articles",
        "article_services",
    }.issubset({row[0] for row in rows})


def test_unique_constraints(db):
    client_id = insert_client(db, client_type="legal")
    db.execute(
        """
        INSERT INTO legal_clients (client_id, inn, kpp, legal_address, contact_person)
        VALUES (?, '7700000000', '770001001', 'Москва', 'Анна')
        """,
        (client_id,),
    )
    insert_sim_card(db)
    insert_article(db)

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO clients (type, name, phone, email)
            VALUES ('individual', 'Петр Петров', '+79990000002', 'ivan@example.test')
            """
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO clients (type, name, phone, email)
            VALUES ('individual', 'Сергей Сидоров', '+79990000001', 'sergey@example.test')
            """
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO sim_cards (iccid, phone_number, status)
            VALUES ('8970100000000000001', '+79990000004', 'available')
            """
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO sim_cards (iccid, phone_number, status)
            VALUES ('8970100000000000002', '+79990000003', 'available')
            """
        )

    duplicate_inn_client_id = insert_client(
        db,
        email="company2@example.test",
        phone="+79990000009",
        client_type="legal",
    )
    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO legal_clients (client_id, inn, kpp, legal_address, contact_person)
            VALUES (?, '7700000000', '770002002', 'Санкт-Петербург', 'Олег')
            """,
            (duplicate_inn_client_id,),
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO knowledge_base_articles (title, slug, category, content)
            VALUES ('Роуминг', 'internet', 'services', 'Описание')
            """
        )


def test_foreign_keys_are_enforced(db):
    client_id = insert_client(db)
    sim_card_id = insert_sim_card(db)
    service_id = insert_service(db)
    article_id = insert_article(db)

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO sim_cards (iccid, phone_number, status, client_id)
            VALUES ('8970100000000000099', '+79990000099', 'active', 999)
            """
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO individual_clients
                (client_id, last_name, first_name, birth_date, passport_data)
            VALUES (999, 'Иванов', 'Иван', '1990-01-01', 'demo')
            """
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO legal_clients (client_id, inn, kpp, legal_address, contact_person)
            VALUES (999, '7700000000', '770001001', 'Москва', 'Анна')
            """
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO payments (client_id, amount, currency, payment_method, status)
            VALUES (999, 100, 'RUB', 'card', 'paid')
            """
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO payments (client_id, sim_card_id, amount, currency, payment_method, status)
            VALUES (?, 999, 100, 'RUB', 'card', 'paid')
            """,
            (client_id,),
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO sim_card_services (sim_card_id, service_id, price_at_connection)
            VALUES (999, ?, 500)
            """,
            (service_id,),
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO sim_card_services (sim_card_id, service_id, price_at_connection)
            VALUES (?, 999, 500)
            """,
            (sim_card_id,),
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO article_services (article_id, service_id)
            VALUES (999, ?)
            """,
            (service_id,),
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO article_services (article_id, service_id)
            VALUES (?, 999)
            """,
            (article_id,),
        )


def test_client_detail_tables_match_client_type(db):
    individual_id = insert_client(db)
    legal_id = insert_client(
        db,
        email="legal@example.test",
        phone="+79990000100",
        client_type="legal",
    )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO legal_clients (client_id, inn, kpp, legal_address, contact_person)
            VALUES (?, '7700000000', '770001001', 'Москва', 'Анна')
            """,
            (individual_id,),
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO individual_clients
                (client_id, last_name, first_name, birth_date, passport_data)
            VALUES (?, 'Иванов', 'Иван', '1990-01-01', 'demo')
            """,
            (legal_id,),
        )

    db.execute(
        """
        INSERT INTO individual_clients
            (client_id, last_name, first_name, birth_date, passport_data)
        VALUES (?, 'Иванов', 'Иван', '1990-01-01', 'demo')
        """,
        (individual_id,),
    )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO legal_clients (client_id, inn, kpp, legal_address, contact_person)
            VALUES (?, '7700000000', '770001001', 'Москва', 'Анна')
            """,
            (individual_id,),
        )


def test_payment_sim_card_must_belong_to_same_client(db):
    first_client_id = insert_client(db)
    second_client_id = insert_client(
        db,
        email="second@example.test",
        phone="+79990000101",
    )
    sim_card_id = insert_sim_card(db, client_id=first_client_id)

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO payments (client_id, sim_card_id, amount, currency, payment_method, status)
            VALUES (?, ?, 100, 'RUB', 'card', 'paid')
            """,
            (second_client_id, sim_card_id),
        )


def test_sim_card_services_keep_reconnection_history(db):
    sim_card_id = insert_sim_card(db)
    service_id = insert_service(db)

    db.execute(
        """
        INSERT INTO sim_card_services
            (sim_card_id, service_id, connected_at, disconnected_at, status, price_at_connection)
        VALUES (?, ?, '2026-01-01', '2026-02-01', 'disconnected', 500)
        """,
        (sim_card_id, service_id),
    )
    db.execute(
        """
        INSERT INTO sim_card_services
            (sim_card_id, service_id, connected_at, status, price_at_connection)
        VALUES (?, ?, '2026-03-01', 'active', 600)
        """,
        (sim_card_id, service_id),
    )

    rows = db.execute(
        """
        SELECT connected_at, status
        FROM sim_card_services
        WHERE sim_card_id = ? AND service_id = ?
        ORDER BY connected_at
        """,
        (sim_card_id, service_id),
    ).fetchall()

    assert rows == [
        ("2026-01-01", "disconnected"),
        ("2026-03-01", "active"),
    ]

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO sim_card_services
                (sim_card_id, service_id, connected_at, status, price_at_connection)
            VALUES (?, ?, '2026-04-01', 'active', 700)
            """,
            (sim_card_id, service_id),
        )


def test_check_constraints_are_enforced(db):
    client_id = insert_client(db)
    sim_card_id = insert_sim_card(db)
    service_id = insert_service(db)

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO clients (type, name, phone, email, status)
            VALUES ('individual', 'Петр Петров', '+79990000002', 'petr@example.test', 'unknown')
            """
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO clients (type, name, phone, email, preferred_channel)
            VALUES ('individual', 'Канал Тест', '+79990000012', 'channel@example.test', 'telegram')
            """
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO individual_clients
                (client_id, last_name, first_name, birth_date, passport_data)
            VALUES (?, 'Иванов', 'Иван', 'not-a-date', 'demo')
            """,
            (client_id,),
        )

    legal_client_id = insert_client(
        db,
        email="company@example.test",
        phone="+79990000006",
        client_type="legal",
    )
    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO legal_clients (client_id, inn, kpp, legal_address, contact_person)
            VALUES (?, '123', '770001001', 'Москва', 'Анна')
            """,
            (legal_client_id,),
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO services (name, description, type, cost, billing_period)
            VALUES ('Плохая услуга', 'Описание', 'bad', 500, 'monthly')
            """
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO services (name, description, type, cost, billing_period)
            VALUES ('Минус', 'Описание', 'internet', -1, 'monthly')
            """
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO services (name, description, type, cost, billing_period, status)
            VALUES ('Период', 'Описание', 'internet', 500, 'weekly', 'active')
            """
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO services (name, description, type, cost, billing_period, status)
            VALUES ('Статус', 'Описание', 'internet', 500, 'monthly', 'unknown')
            """
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO payments (client_id, amount, currency, payment_method, status)
            VALUES (?, -10, 'RUB', 'card', 'paid')
            """,
            (client_id,),
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO payments (client_id, amount, currency, payment_method, status)
            VALUES (?, 100, 'rub', 'card', 'paid')
            """,
            (client_id,),
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO payments (client_id, amount, currency, payment_method, status)
            VALUES (?, 100, 'RUB', 'crypto', 'paid')
            """,
            (client_id,),
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO payments (client_id, amount, currency, payment_method, status)
            VALUES (?, 100, 'RUB', 'card', 'unknown')
            """,
            (client_id,),
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO payments
                (client_id, amount, currency, payment_method, status, created_at, confirmed_at)
            VALUES (?, 100, 'RUB', 'card', 'paid', '2026-01-02', '2026-01-01')
            """,
            (client_id,),
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO sim_cards (iccid, phone_number, status)
            VALUES ('8970100000000000002', '+79990000004', 'unknown')
            """
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO sim_cards (iccid, phone_number, status, issued_at, activated_at)
            VALUES ('8970100000000000003', '+79990000005', 'active', '2026-01-02', '2026-01-01')
            """
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO sim_card_services
                (sim_card_id, service_id, status, price_at_connection)
            VALUES (?, ?, 'unknown', 500)
            """,
            (sim_card_id, service_id),
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO sim_card_services
                (sim_card_id, service_id, price_at_connection)
            VALUES (?, ?, -1)
            """,
            (sim_card_id, service_id),
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO sim_card_services
                (sim_card_id, service_id, connected_at, disconnected_at, price_at_connection)
            VALUES (?, ?, '2026-01-02', '2026-01-01', 500)
            """,
            (sim_card_id, service_id),
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO knowledge_base_articles
                (title, slug, category, content, published_status)
            VALUES ('Черновик', 'draft', 'services', 'Описание', 'unknown')
            """
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO knowledge_base_articles
                (title, slug, category, content, created_at, updated_at)
            VALUES ('Даты', 'dates', 'services', 'Описание', '2026-01-02', '2026-01-01')
            """
        )

    with pytest.raises(sqlite3.IntegrityError):
        insert_tariff(db, name="Минус", fee=-1)
    with pytest.raises(sqlite3.IntegrityError):
        insert_tariff(db, name="Неизвестный", status="deprecated")


def test_tariff_tables_and_nullable_sim_assignment(db):
    tables = {
        row[0]
        for row in db.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table'"
        )
    }
    assert {"tariffs", "tariff_services", "charges"} <= tables

    sim_card_id = insert_sim_card(db)
    assert db.execute(
        "SELECT tariff_id FROM sim_cards WHERE id = ?", (sim_card_id,)
    ).fetchone()[0] is None


def test_archived_tariff_cannot_be_assigned_but_existing_assignment_survives(db):
    active_id = insert_tariff(db)
    archived_id = insert_tariff(db, name="Архивный", status="archived")
    sim_card_id = insert_sim_card(db)

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO sim_cards
                (iccid, phone_number, status, tariff_id)
            VALUES ('8970100000000000099', '+79990000099', 'active', ?)
            """,
            (archived_id,),
        )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            "UPDATE sim_cards SET tariff_id = ? WHERE id = ?",
            (archived_id, sim_card_id),
        )

    db.execute(
        "UPDATE sim_cards SET tariff_id = ? WHERE id = ?",
        (active_id, sim_card_id),
    )
    db.execute("UPDATE tariffs SET status = 'archived' WHERE id = ?", (active_id,))
    assert db.execute(
        "SELECT tariff_id FROM sim_cards WHERE id = ?", (sim_card_id,)
    ).fetchone()[0] == active_id


def test_charge_is_validated_immutable_and_restricts_parent_deletion(db):
    tariff_id = insert_tariff(db)
    sim_card_id = insert_sim_card(db)
    db.execute(
        """
        INSERT INTO charges
            (sim_card_id, tariff_id, billing_period, tariff_name, amount)
        VALUES (?, ?, '2026-02', 'Учебный', 500)
        """,
        (sim_card_id, tariff_id),
    )

    with pytest.raises(sqlite3.IntegrityError):
        db.execute("UPDATE charges SET amount = 600")
    with pytest.raises(sqlite3.IntegrityError):
        db.execute("DELETE FROM charges")
    with pytest.raises(sqlite3.IntegrityError):
        db.execute("DELETE FROM sim_cards WHERE id = ?", (sim_card_id,))
    with pytest.raises(sqlite3.IntegrityError):
        db.execute("DELETE FROM tariffs WHERE id = ?", (tariff_id,))
    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO charges
                (sim_card_id, tariff_id, billing_period, tariff_name, amount)
            VALUES (?, ?, '2026-13', 'Учебный', 500)
            """,
            (sim_card_id, tariff_id),
        )
    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO charges
                (sim_card_id, tariff_id, billing_period, tariff_name, amount)
            VALUES (?, ?, '2026-02', 'Учебный', 500)
            """,
            (sim_card_id, tariff_id),
        )
    with pytest.raises(sqlite3.IntegrityError):
        db.execute(
            """
            INSERT INTO charges
                (sim_card_id, tariff_id, billing_period, tariff_name, amount)
            VALUES (?, ?, '2026-03', 'Учебный', -1)
            """,
            (sim_card_id, tariff_id),
        )
