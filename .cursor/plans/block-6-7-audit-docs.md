# План: Блоки 6-7 — аудит целостности, аналитика и документация

## Контекст
- Требуется закрыть Блок 6 и Блок 7 из `todo.md`: добавить SQL-проверки целостности, аналитические запросы, `project/scripts/audit_db.py`, цель `db-audit`, тесты аудита и документацию проекта.
- Проверены `project/telecom-sim-cards-spec.md`, `todo.md`, `project/schema.sql`, `project/migrations/001_create_tables.sql`, `project/migrations/002_add_indexes.sql`, `project/migrations/003_add_esim_support.sql`, `project/seeds/seed.sql`, `project/Makefile`, `project/scripts/manage_db.py`, `project/migrate.py`, `project/tests/conftest.py`, `project/tests/test_manage_db.py`, `project/tests/test_seed.py`, `project/tests/test_queries.py`, `project/queries/sim-cards-without-active-services.sql`, `project/docs/erd.md`.
- Текущая модель БД уже содержит таблицы `clients`, `individual_clients`, `legal_clients`, `sim_cards`, `services`, `sim_card_services`, `payments`, `knowledge_base_articles`, `article_services`, `migration_history`.
- В проекте уже есть пример запроса `project/queries/sim-cards-without-active-services.sql`, но он выбирает все SIM-карты без активных услуг. Для аудита Блока 6 нужен отдельный запрос только по `sim_cards.status = 'active'`.
- В seed-данных ожидаемо нет нарушений целостности: активные SIM-карты `1`, `2`, `7`, `10` имеют активные услуги; платежи с `sim_card_id` соответствуют владельцам; все клиенты имеют профиль своего типа; связанные услуги статей активны.

## Шаги
1. Создать директории `project/queries/integrity/` и `project/queries/reports/`.
2. Добавить SQL-проверки в `project/queries/integrity/`:
   - `active-sim-cards-without-active-services.sql`: активные SIM-карты без строк `sim_card_services.status = 'active'`.
   - `active-services-on-inactive-sims.sql`: активные подключения услуг, где SIM-карта имеет статус не `active` или `lost`; по требованию отдельно считать `lost` нарушением.
   - `payments-with-foreign-sim.sql`: платежи, где `payments.sim_card_id IS NOT NULL`, но `sim_cards.client_id <> payments.client_id`.
   - `clients-without-type-details.sql`: клиенты `individual` без строки в `individual_clients` и клиенты `legal` без строки в `legal_clients`.
   - `article-services-with-unpublished-services.sql`: связи `article_services` с услугами `services.status IN ('deprecated', 'archived')`.
3. В каждом integrity-запросе возвращать минимум идентификатор проблемной записи и поля для диагностики: `client_id`, `sim_card_id`, `service_id`, `payment_id`, `status` там, где применимо. Запросы должны быть обычными `SELECT`, без изменения данных.
4. Добавить аналитические запросы в `project/queries/reports/`:
   - `revenue-by-services.sql`: расчётная выручка по услугам за период через оплаченные платежи `payments.status = 'paid'`, `payments.confirmed_at` или `created_at`, `payments.sim_card_id`, `sim_card_services` и `services`. Так как в схеме нет строк платежа по конкретной услуге, явно указать в SQL-комментарии ограничение: отчёт распределяет выручку по услугам, подключенным к SIM-карте на момент платежа, и не является бухгалтерской детализацией.
   - `active-sims-by-client.sql`: число активных SIM-карт по каждому клиенту, включая клиентов с нулём активных SIM через `LEFT JOIN`.
5. Реализовать `project/scripts/audit_db.py`:
   - принимать `--db`, по умолчанию `project/data/telecom.db`;
   - подключаться к SQLite с `PRAGMA foreign_keys=ON`;
   - выполнять все `.sql` из `project/queries/integrity/` в стабильном порядке по имени файла;
   - печатать сводку по каждой проверке: имя проверки, количество найденных строк, первые несколько строк для диагностики;
   - возвращать exit code `0`, если все проверки пустые, и `1`, если хотя бы одна проверка нашла строки или произошла ошибка чтения/SQL.
6. Добавить в `project/Makefile` цель `db-audit` и включить её в `.PHONY`:
   - команда должна вызывать `$(PYTHON) scripts/audit_db.py --db $(DB)`;
   - формат цели оставить в стиле текущих целей с кратким `##` описанием для `help`.
7. Добавить `project/tests/test_audit.py`:
   - тест на чистом seed: создать временную БД через `manage_db.py reset` или фикстуру `db` + `seed.sql`, запустить `audit_db.py`, ожидать `returncode == 0`;
   - тест на испорченных данных: в временной БД создать нарушения минимум для всех integrity-запросов и ожидать `returncode != 0`, а в выводе увидеть имена проверок или ненулевые counts;
   - для нарушений, которые блокируются триггерами (`payments` с чужой SIM), портить только временную БД теста: можно удалить соответствующие триггеры в тестовой БД перед вставкой/обновлением неконсистентных данных. Не менять `schema.sql` и миграции ради теста аудита.
8. Обновить или расширить `project/tests/test_queries.py` только если worker решит покрывать новые report-запросы отдельно. Минимум для Блока 6 — покрыть audit через `test_audit.py`.
9. Прогнать проверки:
   - `make db-reset`;
   - `make db-audit`;
   - `make test`.
10. Обновить `todo.md`: отметить выполненными пункты Блоков 6 и 7 только после успешных тестов и созданной документации.
11. Добавить документацию Блока 7:
   - `project/README.md`: назначение учебного проекта, быстрый старт, минимальная последовательность `make db-reset`, `make db-check`, `make db-audit`, `make test`.
   - `project/docs/architecture.md`: модель данных, роли основных таблиц, связи клиентов/SIM/услуг/платежей/статей, ссылка или перенос актуальной ERD из `project/docs/erd.md`, ключевые решения по SQLite, триггерам, seed и миграциям.
   - `project/docs/database.md`: таблицы, ключевые поля, PK/FK, UNIQUE, CHECK, индексы из `schema.sql` и миграций, ограничения по чувствительным demo-данным.
   - `project/docs/commands.md`: команды `Makefile` и `scripts/manage_db.py`; явно указать `db-audit`.
   - `project/docs/agent-workflow.md`: роли planner, worker, tester, reviewer; порядок работы; правило логирования изменений в `task_logs.md` после правок внутри `project/`.
   - `project/docs/examples.md`: примеры SQL-запросов, включая существующий `project/queries/sim-cards-without-active-services.sql`, новые integrity-запросы и report-запросы.
12. После изменений внутри `project/` обновить `task_logs.md` одним компактным пунктом за текущую дату: аудит, аналитика, документация, тесты. Не добавлять длинный список файлов.

## Риски
- Текущая схема уже предотвращает часть нарушений триггерами и FK. Для тестов испорченных данных нельзя ослаблять production-схему; повреждения надо делать только во временной БД теста.
- Отчёт `revenue-by-services.sql` не может быть точной финансовой разбивкой по услугам, потому что `payments` не содержит `service_id` или строк начислений. Нужно явно задокументировать учебное допущение и не менять схему в рамках Блока 6.
- Запрос `active-services-on-inactive-sims.sql` должен аккуратно трактовать формулировку "неактивную/потерянную SIM": нарушение для любого статуса SIM, отличного от `active`, включая `lost`.
- `article_services` ссылается на таблицу `services`, где статус услуги называется `status`, а статус статьи находится в `knowledge_base_articles.published_status`. Проверка Блока 6 относится именно к снятой с публикации услуге, то есть к `services.status IN ('deprecated', 'archived')`.
- Существующий `project/docs/erd.md` не содержит `sim_type` и `eid`, добавленные миграцией `003_add_esim_support.sql`; документацию Блока 7 надо синхронизировать с текущим `schema.sql`.
- `Makefile help` использует `grep` и `awk`. Worker может оставить этот стиль без рефакторинга, но при правке цели нужно не ломать текущий формат `target: ## описание`.

## Проверка
- `make db-reset`
- `make db-audit`
- `make test`
- Дополнительно tester должен проверить, что:
  - чистый seed даёт пустой аудит и exit code `0`;
  - временно испорченная БД даёт exit code `1`;
  - все новые integrity SQL-файлы являются read-only `SELECT`;
  - документация перечисляет реальные команды, таблицы, индексы и ограничения из прочитанных файлов.

## Handoff для worker
- Реализуй Блоки 6 и 7 строго внутри `project/` плюс обнови `todo.md` и `task_logs.md`.
- Не меняй схему и миграции без отдельной причины: текущие требования закрываются SQL-аудитом, скриптом и документацией.
- Для отчёта по выручке зафиксируй учебное допущение прямо в SQL-комментарии и документации.
- После реализации запусти `make db-reset`, `make db-audit`, `make test`; если что-то падает, исправь до передачи tester.
