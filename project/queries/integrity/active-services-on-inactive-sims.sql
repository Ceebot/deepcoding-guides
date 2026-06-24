-- Активные подключения услуг на SIM со статусом, отличным от active (включая lost)

SELECT
    scs.id,
    scs.sim_card_id,
    scs.service_id,
    scs.status AS service_status,
    sc.status AS sim_status
FROM sim_card_services scs
JOIN sim_cards sc ON sc.id = scs.sim_card_id
WHERE scs.status = 'active'
  AND sc.status <> 'active';
