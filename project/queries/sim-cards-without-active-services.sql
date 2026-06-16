-- SIM-карты без активных подключённых услуг

SELECT
    sc.id,
    sc.iccid,
    sc.phone_number,
    sc.status
FROM sim_cards sc
WHERE NOT EXISTS (
    SELECT 1
    FROM sim_card_services scs
    WHERE scs.sim_card_id = sc.id
      AND scs.status = 'active'
);
