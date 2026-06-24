-- Активные SIM-карты без активных подключённых услуг

SELECT
    sc.id AS sim_card_id,
    sc.iccid,
    sc.phone_number,
    sc.client_id,
    sc.status
FROM sim_cards sc
WHERE sc.status = 'active'
  AND NOT EXISTS (
      SELECT 1
      FROM sim_card_services scs
      WHERE scs.sim_card_id = sc.id
        AND scs.status = 'active'
  );
