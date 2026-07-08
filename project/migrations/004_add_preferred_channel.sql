-- 004: предпочтительный канал уведомлений клиента (CR-2026-031).
-- ALTER без пересоздания таблицы; существующим строкам SQLite проставит DEFAULT 'email'.

ALTER TABLE clients ADD COLUMN preferred_channel TEXT NOT NULL DEFAULT 'email'
    CHECK (preferred_channel IN ('email', 'sms', 'push'));
