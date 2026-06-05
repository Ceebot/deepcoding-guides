# Todo: Telecom SIM Cards — учебный проект

## Блок 1: Развёртывание проекта
- [x] Создать структуру директорий: `project/migrations/`, `project/seeds/`, `project/scripts/`, `project/docs/`
- [x] Создать `project/.gitignore` (исключить `*.db`, `*.pyc`, `.env`, `__pycache__/`)
- [x] Создать `project/Makefile` с целями: `db-create`, `db-migrate`, `db-seed`, `db-reset`, `db-check`
- [x] Инициализировать Git-репозиторий в `project/`

## Блок 2: Схема БД
- [x] Настроить инфраструктуру тестов: `project/tests/`, `conftest.py` (фикстура временной БД из схемы), pytest
- [x] Спроектировать ERD и написать `project/schema.sql`:
  - [x] Таблица `clients` (id, type, name/company, phone, email, registered_at, status)
  - [x] Таблица `individual_clients` (client_id, last_name, first_name, middle_name, birth_date, passport_data)
  - [x] Таблица `legal_clients` (client_id, inn, kpp, legal_address, contact_person)
  - [x] Таблица `sim_cards` (id, iccid, phone_number, status, issued_at, activated_at, client_id)
  - [x] Таблица `services` (id, name, description, type, cost, billing_period, status)
  - [x] Таблица `sim_card_services` (sim_card_id, service_id, connected_at, disconnected_at, status, price_at_connection)
  - [x] Таблица `payments` (id, client_id, sim_card_id nullable, amount, currency, payment_method, status, created_at, confirmed_at)
  - [x] Таблица `knowledge_base_articles` (id, title, slug, category, content, published_status, created_at, updated_at)
  - [x] Таблица `article_services` (article_id, service_id)
  - [x] Первичные и внешние ключи
  - [x] Unique constraints (ICCID, phone, email, INN, slug)
  - [x] CHECK constraints (статусы, суммы платежей, даты)
  - [x] Индексы для частых запросов
- [x] Тесты схемы (`project/tests/test_schema.py`): срабатывание UNIQUE, FK, CHECK-ограничений
- [x] Прогнать тесты схемы

## Блок 3: Миграции
- [x] `project/migrations/001_create_tables.sql` — CREATE TABLE всех таблиц
- [x] `project/migrations/002_add_indexes.sql` — добавление индексов
- [ ] `project/migrations/003_example_alter.sql` — пример изменения схемы (eSIM); создаётся вживую на лекции из Word-требования
- [x] Тесты миграций (`project/tests/test_migrations.py`): применение на пустую БД, откат, идемпотентность
- [x] Прогнать тесты миграций

## Блок 4: Seed-данные
- [ ] `project/seeds/seed.sql` — вымышленные данные:
  - 3-5 физических лиц
  - 2-3 юридических лица
  - ~10 SIM-карт (available, reserved, active, blocked, lost)
  - 6-8 услуг (интернет, минуты, SMS, роуминг, статический IP, корпоративные)
  - Подключенные услуги к SIM-картам
  - 5-10 платежей (pending, paid, failed, refunded)
  - 3-5 статей базы знаний
- [ ] Тест seed (`project/tests/test_seed.py`): повторяемая загрузка без ошибок, ожидаемое число записей
- [ ] Прогнать тест seed

## Блок 5: Скрипты автоматизации
- [ ] `project/scripts/manage_db.py` — Python-скрипт управления БД:
  - Команда `migrate` — применение миграций по порядку
  - Команда `rollback` — откат последней миграции
  - Команда `seed` — заполнение seed-данными
  - Команда `reset` — сброс БД (удаление + создание + миграции + seed)
  - Команда `check` — smoke-тесты (проверка наличия таблиц, записей, ограничений)
- [ ] Дополнить `Makefile` вызовами `python scripts/manage_db.py <command>`
- [ ] Тесты команд `manage_db.py` (`project/tests/test_manage_db.py`): migrate, rollback, seed, reset, check
- [ ] Добавить в `Makefile` цель `test` (запуск `pytest`)
- [ ] Прогнать все тесты (`make test`)

## Блок 6: Документация
- [ ] `project/README.md` — что делает проект, быстрый старт
- [ ] `project/docs/architecture.md` — модель данных, ERD, ключевые решения
- [ ] `project/docs/database.md` — таблицы, связи, индексы, ограничения
- [ ] `project/docs/commands.md` — список команд Makefile и manage_db.py
- [ ] `project/docs/agent-workflow.md` — как агенты работают над проектом
- [ ] `project/docs/examples.md` — примеры SQL-запросов

## Блок 7: Примеры бизнес-сценариев
- [ ] Найти все активные SIM-карты клиента
- [ ] Посмотреть услуги, подключенные к конкретной SIM-карте
- [ ] Посчитать сумму платежей клиента за период
- [ ] Найти клиентов с неоплаченными платежами
- [ ] Вывести опубликованные статьи по конкретной услуге
- [ ] Найти SIM-карты без активных услуг
- [ ] Проверить, какие юридические лица имеют >10 SIM-карт
- [ ] Тесты бизнес-запросов (`project/tests/test_queries.py`): результат каждого запроса на seed-данных
- [ ] Прогнать тесты запросов
