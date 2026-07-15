---
name: billing-flow
description: Use when analyzing or changing tariffs, monthly charges, billing periods, charge idempotency, revenue reports, or related tests in the Telecom SIM Cards project.
---

# Billing Flow

## Назначение

Карта помесячного начисления абонплаты в `project/`. Источники истины:

- `project/schema.sql` — таблицы, FK, CHECK, UNIQUE и триггеры;
- `project/scripts/manage_db.py` — `_month_bounds()` и `charge()`;
- `project/queries/integrity/active-sim-cards-without-tariff.sql` — аудит;
- `project/queries/reports/revenue-by-tariffs.sql` — отчёт;
- `project/tests/test_manage_db.py` и `project/tests/test_queries.py` — ожидаемое поведение.

## Таблицы и правила

- `tariffs`: `name`, `monthly_fee >= 0`, статус `active|archived`.
- `tariff_services`: состав тарифа. Не участвует в расчёте суммы.
- `sim_cards.tariff_id`: nullable FK на тариф. Назначить можно только активный тариф; это проверяют INSERT/UPDATE-триггеры.
- `charges`: неизменяемый снимок начисления — `sim_card_id`, `tariff_id`, `billing_period`, `tariff_name`, `amount`, `created_at`.
- `charges` имеет `UNIQUE (sim_card_id, billing_period)`. UPDATE и DELETE запрещены триггерами; удаление связанной SIM или тарифа блокирует `ON DELETE RESTRICT`.
- `payments` не участвует: начисленная выручка не равна оплаченной.

## Алгоритм начисления

Команда: `make db-charge MONTH=YYYY-MM`.

1. `_month_bounds()` строго проверяет формат и месяц `01..12`.
2. `charge()` выполняет `INSERT OR IGNORE ... SELECT`.
3. В выборку попадает SIM, если сейчас `status = 'active'`, задан `activated_at`, дата активации раньше первого дня следующего месяца и назначен тариф.
4. В `charges` копируются текущие `tariffs.name` и `tariffs.monthly_fee`.
5. Начисляется полная сумма без prorating.
6. Повторный запуск создаёт `0` строк благодаря UNIQUE и `INSERT OR IGNORE`.

Статус тарифа намеренно не фильтруется: уже назначенный архивный тариф продолжает начисляться. Расчёт прошлого периода использует текущее состояние SIM и тарифа, потому что история назначений и статусов не хранится.

## Аудит и отчёт

- Активная SIM без тарифа разрешена схемой и выявляется integrity-запросом.
- Отчёт суммирует `charges.amount` по периоду, снимку тарифа и типу текущего владельца SIM.
- Тип клиента берётся через `charges → sim_cards → clients`. При смене владельца историческая разбивка смещается; снимка владельца или типа клиента нет.
- В отчёте использовать `charges.tariff_name`, а не текущее `tariffs.name`.

## Пример проверки

```bash
make -C project db-reset
make -C project db-charge MONTH=2026-02  # 4 charge(s) created
make -C project db-charge MONTH=2026-02  # 0 charge(s) created
make -C project test
make -C project db-audit
```

## Типичные ошибки

- добавлять фильтр `tariffs.status = 'active'` без явного изменения требований и исторической модели;
- считать сумму по услугам вместо `tariffs.monthly_fee`;
- добавлять prorating без нового требования и изменения модели;
- обновлять или удалять `charges`;
- связывать начисления с `payments`;
- считать текущий тип клиента историческим;
- менять UNIQUE так, чтобы одна SIM получила два начисления за месяц.

Исторический статус тарифа, точный prorating, оплаченная выручка и исторический тип клиента не решаются локальной правкой SELECT. Для них нужны отдельные требования, миграции и правила коррекции неизменяемых начислений.

При изменении биллинга сначала добавить или изменить тест, затем править код и обновить `task_logs.md` по правилам репозитория.
