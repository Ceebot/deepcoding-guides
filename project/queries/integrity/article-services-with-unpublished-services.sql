-- Связи article_services с услугами в статусе deprecated или archived

SELECT
    a.article_id,
    a.service_id,
    s.name AS service_name,
    s.status AS service_status
FROM article_services a
JOIN services s ON s.id = a.service_id
WHERE s.status IN ('deprecated', 'archived');
