-- Платежи, где SIM-карта не принадлежит клиенту платежа

SELECT
    p.id AS payment_id,
    p.client_id,
    p.sim_card_id,
    sc.client_id AS sim_owner_client_id,
    p.status
FROM payments p
JOIN sim_cards sc ON sc.id = p.sim_card_id
WHERE p.sim_card_id IS NOT NULL
  AND sc.client_id IS NOT p.client_id;
