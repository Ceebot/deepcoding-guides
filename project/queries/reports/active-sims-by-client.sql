-- Число активных SIM-карт по каждому клиенту (включая ноль)

SELECT
    c.id AS client_id,
    c.name,
    c.type,
    COUNT(sc.id) AS active_sim_count
FROM clients c
LEFT JOIN sim_cards sc
    ON sc.client_id = c.id
   AND sc.status = 'active'
GROUP BY c.id, c.name, c.type
ORDER BY active_sim_count DESC, c.id;
