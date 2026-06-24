# Примеры SQL-запросов

Файлы в `queries/` можно выполнять через `sqlite3 data/telecom.db < путь.sql`.

## Бизнес-запрос: SIM без активных услуг

`queries/sim-cards-without-active-services.sql` — все карты без активного подключения (любой статус SIM).

## Аудит целостности (`queries/integrity/`)

| Файл | Что ищет |
|------|----------|
| `active-sim-cards-without-active-services.sql` | status=active без active в sim_card_services |
| `active-services-on-inactive-sims.sql` | active услуга на SIM ≠ active |
| `payments-with-foreign-sim.sql` | sim_card_id не принадлежит client_id платежа |
| `clients-without-type-details.sql` | нет строки в individual/legal по type |
| `article-services-with-unpublished-services.sql` | услуга deprecated/archived в article_services |

Запуск всех проверок: `make db-audit`.

## Отчёты (`queries/reports/`)

### Выручка по услугам

`revenue-by-services.sql` — только `payments.status = 'paid'`. **Учебное допущение**: сумма платежа делится поровну между услугами, подключёнными к SIM на дату оплаты по интервалу `connected_at` / `disconnected_at`; `sim_card_services.status` не проверяется. В схеме нет `service_id` в платеже — это не бухгалтерская детализация. Период задаётся раскомментированием фильтра по `confirmed_at` / `created_at`.

### Активные SIM по клиентам

`active-sims-by-client.sql` — `LEFT JOIN`, клиенты с нулём активных карт тоже в выборке.

## Пример в sqlite3

```bash
cd project
make db-reset
sqlite3 -header -column data/telecom.db < queries/reports/active-sims-by-client.sql
```
