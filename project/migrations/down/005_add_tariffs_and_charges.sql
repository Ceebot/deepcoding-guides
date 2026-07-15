DROP TRIGGER IF EXISTS trg_sim_cards_tariff_insert;
DROP TRIGGER IF EXISTS trg_sim_cards_tariff_update;
DROP INDEX IF EXISTS idx_sim_cards_tariff_id;
DROP TABLE IF EXISTS charges;
DROP TABLE IF EXISTS tariff_services;
ALTER TABLE sim_cards DROP COLUMN tariff_id;
DROP TABLE IF EXISTS tariffs;
