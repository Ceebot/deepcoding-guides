-- Черновик на ревью перед мерджем: почистить неудачные платежи и вручную
-- завести один компенсационный платёж клиенту 1.

DELETE FROM payments WHERE status = 'failed';

INSERT INTO payments (client_id, sim_card_id, amount, currency, payment_method, status)
VALUES (1, 3, 500, 'RUB', 'card', 'paid');
