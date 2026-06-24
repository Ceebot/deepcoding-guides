-- Клиенты без профиля своего типа (individual / legal)

SELECT
    c.id AS client_id,
    c.type,
    c.name,
    c.status
FROM clients c
LEFT JOIN individual_clients ic ON ic.client_id = c.id
LEFT JOIN legal_clients lc ON lc.client_id = c.id
WHERE (c.type = 'individual' AND ic.client_id IS NULL)
   OR (c.type = 'legal' AND lc.client_id IS NULL);
