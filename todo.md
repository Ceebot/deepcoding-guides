# Todo: Telecom SIM Cards — учебный проект

## Блок 1: Развёртывание проекта
- [x] Создать структуру директорий: `project/migrations/`, `project/seeds/`, `project/scripts/`, `project/docs/`
- [x] Создать `project/.gitignore` (исключить `*.db`, `*.pyc`, `.env`, `__pycache__/`)
- [x] Создать `project/Makefile` с целями: `db-create`, `db-migrate`, `db-seed`, `db-reset`, `db-check`
- [x] Инициализировать Git-репозиторий в `project/`

## Блок 2: Схема БД
- [ ] Спроектировать ERD и написать `project/schema.sql`:
  - [ ] Таблица `clients` (id, type, name/company, phone, email, registered_at, status)
  - [ ] Таблица `individual_clients` (client_id, last_name, first_name, middle_name, birth_date, passport_data)
  - [ ] Таблица `legal_clients` (client_id, inn, kpp, legal_address, contact_person)
  - [ ] Таблица `sim_cards` (id, iccid, phone_number, status, issued_at, activated_at, client_id)
  - [ ] Таблица `services` (id, name, description, type, cost, billing_period, status)
  - [ ] Таблица `sim_card_services` (sim_card_id, service_id, connected_at, disconnected_at, status, price_at_connection)
  - [ ] Таблица `payments` (id, client_id, sim_card_id nullable, amount, currency, payment_method, status, created_at, confirmed_at)
  - [ ] Таблица `knowledge_base_articles` (id, title, slug, category, content, published_status, created_at, updated_at)
  - [ ] Таблица `article_services` (article_id, service_id)
  - [ ] Первичные и внешние ключи
  - [ ] Unique constraints (ICCID, phone, email, INN, slug)
  - [ ] CHECK constraints (статусы, суммы платежей, даты)
  - [ ] Индексы для частых запросов

## Блок 3: Миграции
- [ ] `project/migrations/001_create_tables.sql` — CREATE TABLE всех таблиц
- [ ] `project/migrations/002_add_indexes.sql` — добавление индексов
- [ ] `project/migrations/003_seed_services.sql` — справочник услуг
- [ ] `project/migrations/004_example_alter.sql` — пример изменения схемы (добавление статуса/поля)

## Блок 4: Seed-данные
- [ ] `project/seeds/seed.sql` — вымышленные данные:
  - 3-5 физических лиц
  - 2-3 юридических лица
  - ~10 SIM-карт (available, reserved, active, blocked, lost)
  - 6-8 услуг (интернет, минуты, SMS, роуминг, статический IP, корпоративные)
  - Подключенные услуги к SIM-картам
  - 5-10 платежей (pending, paid, failed, refunded)
  - 3-5 статей базы знаний

## Блок 5: Скрипты автоматизации
- [ ] `project/scripts/manage_db.py` — Python-скрипт управления БД:
  - Команда `migrate` — применение миграций по порядку
  - Команда `rollback` — откат последней миграции
  - Команда `seed` — заполнение seed-данными
  - Команда `reset` — сброс БД (удаление + создание + миграции + seed)
  - Команда `check` — smoke-тесты (проверка наличия таблиц, записей, ограничений)
- [ ] Дополнить `Makefile` вызовами `python scripts/manage_db.py <command>`

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
