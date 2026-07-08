-- Down для 004_add_preferred_channel: убирает preferred_channel из clients.

ALTER TABLE clients DROP COLUMN preferred_channel;
