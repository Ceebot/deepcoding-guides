-- Активные SIM-карты, которым не назначен текущий тариф.

SELECT
    id,
    phone_number,
    client_id
FROM sim_cards
WHERE status = 'active'
  AND tariff_id IS NULL;
