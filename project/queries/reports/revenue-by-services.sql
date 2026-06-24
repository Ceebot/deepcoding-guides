-- Расчётная выручка по услугам за период (оплаченные платежи).
--
-- Учебное допущение: в payments нет service_id и строк начислений.
-- Выручка распределяется поровну между услугами, подключёнными к SIM-карте
-- на момент платежа (connected_at <= дата оплаты, disconnected_at пуст или позже).
-- Это не бухгалтерская детализация по услугам.
--
-- Период: раскомментируйте и задайте границы в payment_events.

WITH payment_events AS (
    SELECT
        p.id AS payment_id,
        p.sim_card_id,
        p.amount,
        COALESCE(p.confirmed_at, p.created_at) AS paid_at
    FROM payments p
    WHERE p.status = 'paid'
      AND p.sim_card_id IS NOT NULL
      -- AND COALESCE(p.confirmed_at, p.created_at) >= '2026-01-01'
      -- AND COALESCE(p.confirmed_at, p.created_at) < '2026-02-01'
),
payment_service_links AS (
    SELECT
        pe.payment_id,
        scs.service_id,
        pe.amount * 1.0 / COUNT(*) OVER (PARTITION BY pe.payment_id) AS allocated_amount
    FROM payment_events pe
    JOIN sim_card_services scs ON scs.sim_card_id = pe.sim_card_id
        AND scs.connected_at <= pe.paid_at
        AND (scs.disconnected_at IS NULL OR scs.disconnected_at > pe.paid_at)
)
SELECT
    s.id AS service_id,
    s.name AS service_name,
    ROUND(SUM(psl.allocated_amount), 2) AS revenue
FROM payment_service_links psl
JOIN services s ON s.id = psl.service_id
GROUP BY s.id, s.name
ORDER BY revenue DESC, s.id;
