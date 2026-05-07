## Технологический стек

- **Backend**: PHP 8.4.12, Symfony 6.4, PostgreSQL, RabbitMQ 4.0.7
- **Frontend**: Twig, Tailwind CSS 3.x, Alpine.js 3.x, Apexcharts.js 5.3.5
- **Инфраструктура**: Docker (+Swarm), Nginx, Traefik

## Правила проекта

- Перед выполнением задачи прочитать уже проделанные работы проекта в `task_logs.md`
- Обновить проектные правила и документацию после изменений в коде,
  используя скилл ``.cursor/skills/update-rules/SKILL.md``
- Не использовать сущности `Entity`, `Repository`, придерживаться аналогичной проекту архитектуры 
- Не создавать `final`, `static`, `invoke` классы/методы
  (исключения: классы миграций Doctrine — без `final`; у backed enum допустим встроенный `cases()`;
  подписи для UI — метод экземпляра `uiLabel()` у `App\Enum\Poultry\PoultryEggsEnum`, карта для Twig собирается в контроллере)
- Не называть методы с приписками `get`, `set`
- Не использовать Doctrine ORM, а только чистый SQL-код
- Все терминальные команды, связанные с PHP и Symfony (`php bin/console`),
  выполнять внутри docker-контейнера PHP, его имя содержит `vet_php-fpm-vet`.
- Не делай строки длиннее 120 символов
- Называть php/js классы в прошедшем времени, например `CreatedEvent.php` или `CreatedMessage.js`
- Писать PHPDoc и JSDoc к каждому классу/методу, делать описания для классов
  в прошедшем времени, например «Созданная заявка», а для методов по тому,
  что он делает, например «Создание заявки»

## Документация проекта

### Backend

- [backend-architecture.mdc](./backend-architecture.mdc) — обзор backend-архитектуры проекта: MVC, `src/`,
  `packages/`, слои, бандлы, контракты, Docker/Swarm, зависимости от auth и audit
- [db-schema.mdc](./db-schema.mdc) — структура и описание основной БД vet-module
- [audit-db-rules.mdc](./audit-db-rules.mdc) — структура и описание БД аудита
- [auth-flow.mdc](./auth-flow.mdc) — авторизация через SSO: cookie uuid_token, редирект, исключения, логаут
- [phpunit-tests/SKILL.md](../skills/phpunit-tests/SKILL.md) — правила написания и запуска unit/integration тестов
- [fixtures-rules.mdc](./fixtures-rules.mdc) — структура DataFixtures, доступ к БД, зависимости
- [ai-system-request/SKILL.md](../skills/ai-system-request/SKILL.md) — запросы к ИИ (RAG, INLINE, OPENROUTER), работа с файлами

### Frontend

- [frontend-architecture.mdc](./frontend-architecture.mdc) — обзор frontend-архитектуры: Twig, Alpine.js,
  `assets/js`, `public/js`, API-классы, стили и сборка
- [pagination-load-more/SKILL.md](../skills/pagination-load-more/SKILL.md) — паттерн async-подгрузки списков
  с кнопкой «Загрузить ещё» через `LoadMoreManager`/`Paginator`

### Функции
- [animal-type-switching.mdc](./animal-type-switching.mdc) — переключение видов животных (PORK/POULTRY), роуты, guard, sidenav
- [symfony-bundles](../skills/symfony-bundles/SKILL.md) — структура и работа внутренних Symfony-бандлов
- [date-timezone-flow.mdc](./date-timezone-flow.mdc) — работа с датами и временными зонами
- [table-page/SKILL.md](../skills/table-page/SKILL.md) — страница таблицы /table; [docs/table-page.md](../../docs/table-page.md) — краткий указатель
- [dashboard-page/SKILL.md](../skills/dashboard-page/SKILL.md) — страница дашборда /dashboard (POULTRY API, блоки, MOBA)
- [analytics-page/SKILL.md](../skills/analytics-page/SKILL.md) — страница /analytics (диспетчер), API PORK/POULTRY, guard
