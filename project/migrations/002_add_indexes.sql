-- 002: индексы для частых запросов. Воспроизводит CREATE INDEX из schema.sql.

CREATE INDEX idx_clients_status ON clients(status);
CREATE INDEX idx_sim_cards_client_status ON sim_cards(client_id, status);
CREATE INDEX idx_services_type_status ON services(type, status);
CREATE UNIQUE INDEX uq_active_sim_card_service
    ON sim_card_services(sim_card_id, service_id)
    WHERE status = 'active';
CREATE INDEX idx_sim_card_services_service_status ON sim_card_services(service_id, status);
CREATE INDEX idx_payments_client_status_created ON payments(client_id, status, created_at);
CREATE INDEX idx_payments_sim_card_id ON payments(sim_card_id);
CREATE INDEX idx_articles_category_status ON knowledge_base_articles(category, published_status);
CREATE INDEX idx_article_services_service_id ON article_services(service_id);
