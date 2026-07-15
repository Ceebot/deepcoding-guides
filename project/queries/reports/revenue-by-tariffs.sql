-- Начисленная абонплата по месяцам и снимкам тарифов.
-- Это начисления из charges, а не сумма фактически оплаченных payments.
-- Тип клиента берётся по текущей привязке SIM к владельцу.
-- При смене владельца историческая разбивка может смещаться.

SELECT
    ch.billing_period,
    ch.tariff_id,
    ch.tariff_name,
    c.type AS client_type,
    COUNT(*) AS charge_count,
    ROUND(SUM(ch.amount), 2) AS revenue
FROM charges AS ch
LEFT JOIN sim_cards AS sc ON sc.id = ch.sim_card_id
LEFT JOIN clients AS c ON c.id = sc.client_id
GROUP BY ch.billing_period, ch.tariff_id, ch.tariff_name, c.type
ORDER BY ch.billing_period, revenue DESC, ch.tariff_id, c.type;
