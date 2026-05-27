---
name: db-schema
description: >
  Полное описание таблиц БД vet-module, с типами, связями и комментариями. Использовать при написании SQL-запросов или миграций.
---

## Сводная схема БД

Ниже приведены таблицы, их поля (имя → тип → комментарий/особенности), ключи, индексы и связи. Типы указаны в терминах БД (PostgreSQL).

### Таблица `ai_dialog` — Диалог с агентом
- **PK**: `id BIGINT` — Первичный ключ
- **Поля**:
  - `animal_group_id BIGINT NULL` — Полиморфная ссылка на группу (id в таблице по `animal_type`). NULL означает общий чат без привязки к группе.
  - `animal_type VARCHAR(20) NULL` — Тип группы (`pork` | `poultry`). NULL — общий чат без модуля животных.
  - `title VARCHAR(50) NOT NULL` — Заголовок диалога
  - `created_at TIMESTAMPTZ NOT NULL` — Дата создания диалога
  - `updated_at TIMESTAMPTZ NOT NULL` — Дата последнего обновления диалога
- **Связи**:
  - Полиморфная связь по (`animal_group_id`, `animal_type`) на `pork_group`/`poultry_group`.

### Таблица `ai_message` — Сообщение диалога
- **PK**: `id BIGINT` — Первичный ключ
- **Поля**:
  - `dialog_id BIGINT NOT NULL` — FK → `ai_dialog.id` (on delete CASCADE)
  - `author_id BIGINT NULL` — Идентификатор автора (auth-модуль)
  - `role VARCHAR(20) NOT NULL` — Роль автора: 'user' | 'assistant'
  - `text TEXT NOT NULL` — Текст сообщения
  - `is_system BOOLEAN NOT NULL DEFAULT false` — Системное сообщение (не отображается в чате)
  - `ai_model VARCHAR(150) NULL` — Модель/сервис ИИ, сформировавший ответ (для role=assistant)
  - `created_at TIMESTAMPTZ NOT NULL` — Дата создания сообщения
- **Связи**:
  - N→1 `ai_dialog`

### Таблица `animal_alert` — Журнал оповещений ИИ по статусу группы
- **PK**: `id BIGSERIAL` — Идентификатор записи журнала
- **Поля**:
  - `animal_type VARCHAR(20) NOT NULL` — Тип группы (`pork` | `poultry`)
  - `animal_group_id BIGINT NOT NULL` — Полиморфная ссылка на группу (id в таблице по `animal_type`)
  - `title VARCHAR(80) NOT NULL` — Заголовок (для автоанализа: «Определение статуса группы»)
  - `description TEXT NULL` — Пояснение из ответа ИИ
  - `status animal_alert_status NULL` — Enum в БД: `normal` | `warning` | `critical`; NULL если статус из ответа ИИ не распознан
  - `created_at TIMESTAMPTZ NOT NULL` — Время создания записи
  - `updated_at TIMESTAMPTZ NOT NULL` — Время последнего обновления записи
- **Связи**:
  - Полиморфная связь по (`animal_group_id`, `animal_type`) на `pork_group`/`poultry_group`
- **Поведение**: только `INSERT` (журнал событий), без upsert

### Таблица `ifa_lab_result` — Результат ИФА-исследований
- **PK**: `id BIGINT` — Первичный ключ
- **Поля**:
  - `animal_group_id BIGINT NOT NULL` — Полиморфная ссылка на группу.
  - `animal_type VARCHAR(20) NOT NULL DEFAULT 'pork'` — Тип группы (`pork` | `poultry`).
  - `data JSON NOT NULL` — Результаты (структурированные данные). Структура:
    - `interpretation_result` (string, optional) — Результат AI интерпретации в формате Markdown
    - `interpretation_completed_at` (string, optional) — Дата завершения интерпретации
    - `interpretation_error` (string, optional) — Сообщение об ошибке (при статусе failed)
    - другие специфичные для типа исследования данные
  - `status VARCHAR(100) NOT NULL DEFAULT 'pending'` — Статус: pending (ожидает), download_success (загружено), in_progress (обрабатывается), completed (завершено), failed (ошибка)
  - `research_type lab_result_research_type NOT NULL` — Тип лабораторного исследования (enum: elisa, pcr, other)
  - `created_at TIMESTAMPTZ NOT NULL` — Дата создания результата исследования
- **Связи**:
  - Полиморфная связь по (`animal_group_id`, `animal_type`) на `pork_group`/`poultry_group`.

### Таблица `employee` — Сотрудник
- **PK**: `id BIGINT` — Первичный ключ
- **Поля**:
  - `company_id BIGINT NOT NULL` — ID компании/комплекса из модуля аудита (внешняя БД).
  - `last_name VARCHAR(80) NOT NULL` — Фамилия сотрудника
  - `first_name VARCHAR(80) NOT NULL` — Имя сотрудника
  - `middle_name VARCHAR(80) NULL` — Отчество сотрудника
  - `position VARCHAR(80) NOT NULL` — Должность сотрудника
  - `email VARCHAR(190) NULL UNIQUE` — Email сотрудника
  - `phone VARCHAR(20) NULL UNIQUE` — Телефон сотрудника
  - `telegram_id VARCHAR(64) NULL` — Telegram ID сотрудника
  - `created_at TIMESTAMPTZ NOT NULL` — Дата создания записи сотрудника
  - `updated_at TIMESTAMPTZ NOT NULL` — Дата последнего обновления записи сотрудника

### Таблица `module_config` — Конфигурация включения модулей
- **PK**: `id BIGINT` — Первичный ключ
- **Уникальные ограничения**: `uniq_module_config_code` на `code`
- **Поля**:
  - `code VARCHAR(50) NOT NULL` — Уникальный код модуля (SENSORS, PHARMACY, AI_CHAT, AI_INTERPRETATION, AI_ROOM_STATUS, MOCK_SCENARIOS, AMETIST_EXCEL_PARSER, ANALYTICS, PORK, POULTRY, TABLE, DASHBOARD). PORK и POULTRY — mutex (взаимное исключение).
  - `name VARCHAR(100) NOT NULL` — Отображаемое имя модуля
  - `enabled BOOLEAN NOT NULL DEFAULT TRUE` — Включён ли модуль

### Таблица `file` — Универсальное хранилище файлов
- **PK**: `id BIGINT` — Первичный ключ
- **Индексы**:
  - `idx_file_ref(ref_table, ref_id)`
- **Поля**:
  - `ref_table VARCHAR(50) NOT NULL` — Имя связанной таблицы
  - `ref_id BIGINT NOT NULL` — ID связанной сущности
  - `file_path VARCHAR(255) NOT NULL` — Путь к файлу
  - `filename VARCHAR(255) NOT NULL` — Отображаемое имя
  - `file_type VARCHAR(50) NOT NULL` — Тип/расширение
  - `uploaded_at TIMESTAMPTZ NOT NULL` — Дата загрузки файла

### Таблица `history` — История группы животных
- **PK**: `id BIGINT` — Первичный ключ
- **Индексы**:
  - `IDX_HISTORY_PORK_GROUP` (animal_group_id)
  - `IDX_HISTORY_PORK_ROOM` (pork_room_id) — для запросов истории по комнате
- **Поля**:
  - `animal_group_id BIGINT NULL` — Полиморфная ссылка на группу.
  - `animal_type VARCHAR(20) NOT NULL DEFAULT 'pork'` — Тип группы (`pork` | `poultry`).
  - `pork_room_id BIGINT NULL` — Ссылка на комнату свиней (pork_room из audit). Для запросов истории комнаты.
  - `author_id BIGINT NOT NULL` — Пользователь (auth-модуль)
  - `planned_event_id BIGINT NULL` — FK → `planned_event.id` (on delete SET NULL)
  - `type history_type NOT NULL` — Тип события (enum PostgreSQL: падеж, оборудование, климат, исследование, отгрузка, постановка, осмотр, вакцинация, лечение, кормление, мероприятие, произвольное)
  - `title VARCHAR(50) NOT NULL` — Заголовок события
  - `description TEXT NULL` — Подробное описание события
  - `created_at TIMESTAMPTZ NOT NULL` — Дата создания записи истории
  - `updated_at TIMESTAMPTZ NOT NULL` — Дата последнего обновления записи истории
- **Связи**:
  - Полиморфная связь по (`animal_group_id`, `animal_type`) на `pork_group`/`poultry_group`.
  - Логическая связь `pork_room_id` на `pork_room` (внешняя БД аудита)
  - 1→1 `planned_event`

### Таблица `veterinary_pharmacy_history` — История аптеки
- **Поля**: в т.ч. `animal_group_id BIGINT NULL`, `animal_type VARCHAR(20) NOT NULL DEFAULT 'pork'` — полиморфная ссылка на группу (`pork_group`/`poultry_group`).

### Таблица `medicament` — Справочник ветеринарных препаратов
- **PK**: `id BIGINT` — Первичный ключ
- **Поля**:
  - `name VARCHAR(100) NOT NULL` — Название препарата
  - `manufacturer VARCHAR(100) NULL` — Производитель препарата
  - `usage_method VARCHAR(200) NULL` — Способ применения
  - `color VARCHAR(20) NOT NULL` — HEX-цвет для отображения в таблице
  - `animal_type VARCHAR(100) NULL` — Вид животных: `pork`, `poultry`; при `GET /api/medicaments?animal_type=` в выборку входят строки с этим значением и с `NULL` (общие/наследие)
  - `created_at TIMESTAMPTZ NOT NULL` — Дата создания
  - `updated_at TIMESTAMPTZ NOT NULL` — Дата обновления

### Таблица `planned_event` — Планируемые мероприятия
- **PK**: `id BIGINT` — Первичный ключ
- **Поля**:
  - `author_id BIGINT NULL` — FK → `employee.id` (on delete SET NULL)
  - `animal_group_id BIGINT NULL` — Полиморфная ссылка на группу.
  - `animal_type VARCHAR(20) NOT NULL DEFAULT 'pork'` — Тип группы (`pork` | `poultry`).
  - `name VARCHAR(160) NOT NULL` — Название мероприятия
  - `status planned_event_status NULL` — Статус мероприятия (enum: planned, done, overdue, cancelled)
  - `category planned_event_category NULL` — Категория мероприятия (enum PostgreSQL; для ЛПМ — в т.ч. «Метафилактика», «Лечение», «Диагностика»)
  - `is_lpm BOOLEAN DEFAULT FALSE` - Признак ЛПМ
  - `duration_days INT DEFAULT NULL` - Длительность мероприятия в днях
  - `medicament_id BIGINT NULL` — FK → medicament.id (on delete SET NULL)
  - `dosage VARCHAR(200) NULL` — Дозировка препарата в рамках ЛПМ
  - `activity_date TIMESTAMPTZ NOT NULL` — Планируемая дата проведения мероприятия
  - `description TEXT NULL` — Описание мероприятия
  - `created_at TIMESTAMPTZ NOT NULL` — Дата создания мероприятия
  - `updated_at TIMESTAMPTZ NOT NULL` — Дата последнего обновления мероприятия
- **Связи**:
  - Полиморфная связь по (`animal_group_id`, `animal_type`) на `pork_group`/`poultry_group`.
  - N→1 `employee`

### Таблица `pork_climate_norm` — Нормы климата (по возрасту/сезону)
- **PK**: `id BIGINT` — Первичный ключ
- **Поля**:
  - `age_days_min INT NOT NULL` — Диапазон возраста от
  - `age_days_max INT NOT NULL` — Диапазон возраста до
  - `season VARCHAR(15) NOT NULL` — зима/весна/лето/осень
  - `min_temp DECIMAL(6,2) NOT NULL` — Минимальная температура, °C
  - `max_temp DECIMAL(6,2) NOT NULL` — Максимальная температура, °C
  - `min_humidity DECIMAL(6,2) NOT NULL` — Минимальная влажность, %
  - `max_humidity DECIMAL(6,2) NOT NULL` — Максимальная влажность, %
  - `min_ventilation DECIMAL(8,3) NOT NULL` — Минимальная вентиляция, кПа
  - `max_ventilation DECIMAL(8,3) NOT NULL` — Максимальная вентиляция, кПа
  - `min_co2 NUMERIC(6,0) NOT NULL` — Минимальная норма CO2, ppm
  - `max_co2 NUMERIC(6,0) NOT NULL` — Максимальная норма CO2, ppm
  - `min_pressure NUMERIC(6,2) NOT NULL` — Минимальная норма давления, гПа
  - `max_pressure NUMERIC(6,2) NOT NULL` — Максимальная норма давления, гПа
  - `created_at TIMESTAMPTZ NOT NULL` — Дата создания нормы климата
  - `updated_at TIMESTAMPTZ NOT NULL` — Дата последнего обновления нормы климата

### Таблица `pork_deaths_norm` — Нормы выбытия (падежа) для свиней
- **PK**: `id BIGINT` — Первичный ключ
- **Уникальные ограничения**:
  - `UNIQUE(pork_group_id, stage)` (имя `uniq_pork_deaths_norm_group_stage`)
- **Поля**:
  - `animal_group_id BIGINT NOT NULL` — Полиморфная ссылка на группу.
  - `animal_type VARCHAR(20) NOT NULL DEFAULT 'pork'` — Тип группы (`pork` | `poultry`).
  - `stage VARCHAR(50) NOT NULL` — Тип участка/стадия производства (enum `ProductionStageEnum`: доращивание)
  - `percent DECIMAL(5,2) NOT NULL` — Процент падежа (норма)
  - `created_at TIMESTAMPTZ NOT NULL` — Дата создания записи нормы
  - `updated_at TIMESTAMPTZ NOT NULL` — Дата последнего обновления записи нормы
- **Связи**:
  - Полиморфная связь по (`animal_group_id`, `animal_type`) на `pork_group`/`poultry_group`.

### Таблица `pork_weight_norm` — Нормы привеса для свиней
- **PK**: `id BIGINT` — Первичный ключ
- **Уникальные ограничения**:
  - `UNIQUE(pork_group_id, stage)` (имя `uniq_pork_weight_norm_group_stage`)
- **Поля**:
  - `animal_group_id BIGINT NOT NULL` — Полиморфная ссылка на группу.
  - `animal_type VARCHAR(20) NOT NULL DEFAULT 'pork'` — Тип группы (`pork` | `poultry`).
  - `stage VARCHAR(50) NOT NULL` — Тип участка/стадия производства (enum `ProductionStageEnum`: доращивание)
  - `weight_kg NUMERIC(8,3) NOT NULL` — Привес в килограммах на голову
  - `created_at TIMESTAMPTZ NOT NULL` — Дата создания записи нормы
  - `updated_at TIMESTAMPTZ NOT NULL` — Дата последнего обновления записи нормы
- **Связи**:
  - Полиморфная связь по (`animal_group_id`, `animal_type`) на `pork_group`/`poultry_group`.

### Таблица `pork_feed_norm` — Плановые нормы потребления корма по площадке в целом
- **PK**: `id BIGINT` — Первичный ключ
- **Поля**:
  - `pork_site_id BIGINT NOT NULL` — Ссылка на площадку `pork_site` из БД аудита
  - `name VARCHAR(100) NOT NULL` — Название корма
  - `value DECIMAL(10,2) NOT NULL` — Количество потребляемого корма (кг)
  - `date TIMESTAMPTZ NOT NULL` — Дата для данной нормы
  - `created_at TIMESTAMPTZ NOT NULL` — Дата создания записи нормы
  - `updated_at TIMESTAMPTZ NOT NULL` — Дата последнего обновления записи нормы

### Таблица `pork_feed_fact` — Фактические показатели потребления корма по площадке в целом
- **PK**: `id BIGINT` — Первичный ключ
- **Поля**:
  - `pork_site_id BIGINT NOT NULL` — Ссылка на площадку `pork_site` из БД аудита
  - `name VARCHAR(100) NOT NULL` — Название корма
  - `value DECIMAL(10,2) NOT NULL` — Фактически потребленное количество корма (кг)
  - `date TIMESTAMPTZ NOT NULL` — Дата для данного показателя
  - `created_at TIMESTAMPTZ NOT NULL` — Дата создания записи показателя
  - `updated_at TIMESTAMPTZ NOT NULL` — Дата последнего обновления записи показателя

### Таблица `pork_group` — Группа свиней (партия в комнате)
- **PK**: `id BIGINT` — Первичный ключ
- **Поля**:
  - `pork_room_id BIGINT NULL` — Ссылка на `pork_room` во внешней БД аудита (NULL — группа без комнаты; частичный уникальный индекс по непустому `pork_room_id`)
  - `is_slaughter BOOLEAN NOT NULL DEFAULT false` — Убой (партия на убой без комнаты; сбрасывается при постановке в зал)
  - `operator_id INT NULL` — FK → `employee.id` (on delete SET NULL)
  - `name VARCHAR(60) NOT NULL` — Код партии (например, S-2025-02)
  - `breed VARCHAR(60) NULL` — Порода свиней
  - `start_date TIMESTAMPTZ NOT NULL` — Дата постановки группы в комнату
  - `end_date TIMESTAMPTZ NULL` — Дата завершения периода (если группа завершена)
  - `end_reason VARCHAR(300) NULL` — Причина завершения периода
  - `start_count INT NOT NULL` — Количество голов на момент постановки
  - `livestock_list JSONB NULL` — Поголовье по дням: {дата: {"start_of_day": N, "end_of_day": M}}
  - `death_list JSONB NULL` — Падёж по дням: {дата: [ { "count", "comment", "pen", "weight", "age_days"; опц. "diagnosis" }, ... ]}; за дату — массив записей (порядок = порядок в UI); пустой массив или отсутствие ключа — нет падежа за день
  - `culling_list JSONB NULL` — Выбраковка по дням: {дата: [ { "count", "comment", "pen", "weight", "age_days" }, ... ]} (как `death_list`); legacy `{дата: число}` при чтении нормализуется в одну запись
  - `transfer_list JSONB NULL` — Переводы животных по дням: {дата: количество}
  - `feed_change_list JSONB NULL` — История смен кормов: [{"feed_brand_start":"СК-1","feed_brand_end":"СК-2","change_date":"2024-12-10"}]
  - `weight_list JSONB NULL` — Список весов: {дата: {"start_of_day": вес_группы_кг, "end_of_day": вес_группы_кг}}
  - `water_consumption JSONB NULL` — Потребление воды: {дата: литры}
  - `status pork_group_status NOT NULL DEFAULT 'Норма'` — Статус группы животных (enum: 'Норма', 'Внимание', 'Критично')
  - `status_updated_at TIMESTAMPTZ NULL` — Дата последнего обновления статуса группы через ИИ
  - `status_description TEXT NULL` — Пояснение причины статуса группы от ИИ (при статусе не Норма)
  - `created_at TIMESTAMPTZ NOT NULL` — Дата создания группы животных
  - `updated_at TIMESTAMPTZ NOT NULL` — Дата последнего обновления группы животных
 - **Связи**:
  - N→1 `employee` (operator)

### Таблица `pork_group_movement` — Движение группы свиней по комнатам
- **PK**: `id`
- **Поля** (в т.ч.): `pork_group_id`, `pork_room_id`, `count` (кол-во при постановке в эту комнату),
  `avg_weight` NUMERIC(8,2) NULL — средний вес при постановке (кг/голову),
  `age_days` INT NULL — возраст при постановке (дней),
  `end_count`, `end_avg_weight`, `end_age_days` — снимок при отгрузке/закрытии движения,
  `start_date`, `end_date`, `comment`

### Таблица `sensor` — Зарегистрированные физические датчики
- **PK**: `id BIGINT` — Первичный ключ
- **Поля**:
  - `room_id BIGINT NULL` — Необязательная ссылка на комнату/корпус во внешней БД аудита.
  - `room_type VARCHAR(20) NOT NULL DEFAULT 'pork_room'` — Тип комнаты (`pork_room` | `poultry_building`).
  - `title VARCHAR(50) NULL` — Название датчика
  - `device_name VARCHAR(150) NOT NULL` — Имя устройства датчика
  - `battery_voltage DECIMAL(4,3) NULL` — Напряжение батареи (В), последнее из payload Chirpstack (BatV)
  - `created_at TIMESTAMPTZ NOT NULL` — Дата создания датчика
  - `updated_at TIMESTAMPTZ NOT NULL` — Дата последнего обновления датчика
- **Связи**:
  - 1→N `sensor_data`

### Таблица `sensor_data` — Показания датчиков
- **PK**: `id BIGINT` — Первичный ключ
- **Индексы**: `idx_sensor_data_sensor_id_created_at` (sensor_id, created_at DESC) — для запросов истории климата
- **Поля**:
  - `sensor_id BIGINT NOT NULL` — FK → `sensor.id` (on delete CASCADE)
  - `type VARCHAR(50) NOT NULL` — Тип показания (CHECK: TEMPERATURE, HUMIDITY, VENTILATION, CO2, PRESSURE)
  - `unit VARCHAR(16) NOT NULL` — Единица измерения (CHECK: °C, %, кПа, ppm, гПа)
  - `value DECIMAL(12,4) NOT NULL` — Показание датчика
  - `created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP` — Дата получения показания
  - `updated_at TIMESTAMPTZ NOT NULL` — Дата последнего обновления показания
- **Связи**:
  - N→1 `sensor`

---
Примечания:
- Поля времени помеченные как `TIMESTAMPTZ` соответствуют Doctrine `datetime_immutable` с хранением в часовом поясе БД.
- Поля с enumType: `PlannedEvent.status` и `PlannedEvent.category` хранятся как PostgreSQL ENUM типы. Остальные enum поля (например, `SensorData.type`, `SensorData.unit`, `History.type`) хранятся как `VARCHAR` с контролем допустимых значений на уровне Doctrine/валидации и CHECK constraints в БД.
- Поля со связью на внешнюю БД (например, `pork_room_id`) — это логические ссылки на сущности модуля аудита и не имеют FK внутри этой БД.


### Таблица `poultry_group` — Партия птицы
- **PK**: `id BIGINT` — Первичный ключ
- **Поля**:
  - `building_id BIGINT NULL` — Ссылка на корпус `poultry_buildings` из внешней БД аудита (NULL — группа без корпуса)
  - `is_slaughter BOOLEAN NOT NULL DEFAULT false` — Убой (резерв схемы; UI отгрузки PORK)
  - `operator_id INT NULL` — FK → `employee.id` (on delete SET NULL)
  - `name VARCHAR(60) NOT NULL`, `breed VARCHAR(60) NULL`, `bird_type VARCHAR(20) NOT NULL`
  - `parent_age_weeks INT NULL`, `incubator_number VARCHAR(20) NULL`, `feeding_program VARCHAR(60) NULL`
  - `initial_weight_g NUMERIC(8,2) NULL`, `slaughter_date TIMESTAMPTZ NULL`
  - `start_date TIMESTAMPTZ NOT NULL`, `end_date TIMESTAMPTZ NULL`, `end_reason VARCHAR(300) NULL`, `start_count INT NOT NULL`
  - `livestock_list JSONB NULL`, `death_list JSONB NULL` (как у `pork_group`: за дату массив записей с `count`, `comment`, `weight`, `age_days`), `culling_list JSONB NULL`
  - `feed_change_list JSONB NULL`, `weight_list JSONB NULL`, `egg_production_list JSONB NULL`
  - `eggs_list JSONB NULL` — яйца по дням: ключ даты `Y-m-d` → объект с полями `whole` и `defective`.
    - `whole` — **массив** объектов `{ count, avg_weight_g [, grade] }` (`grade` — опционально; значения как в `App\Enum\Poultry\PoultryEggsEnum`, напр. СВ, СО, С1–С3; устаревшие коды при чтении маппятся в `tryFromWithLegacy`). Каждая сохранённая запись из модалки добавляется отдельной строкой в `whole` (без слияния по сорту).
    - Обратная совместимость: legacy-объект `whole: { count, avg_weight_g }` (без массива) читается в `NormalizedEggsWhole` и в `PoultryTableData::applyEggsData`.
    - `defective` — объект брака: `{ items: [ { type: 'notch'|'shell', count: int }, ... ], count: int }` (сумма шт.; `count` — сумма; legacy — только `{ count }`, трактуется как насечка).
  - `status VARCHAR(20) NOT NULL DEFAULT 'Норма'`, `status_updated_at TIMESTAMPTZ NULL`, `status_description TEXT NULL`
  - `created_at TIMESTAMPTZ NOT NULL`, `updated_at TIMESTAMPTZ NOT NULL`

### Таблица `poultry_deaths_norm`
- **PK**: `id BIGINT`; `poultry_group_id BIGINT NOT NULL` FK → `poultry_group.id` (on delete CASCADE)
- Поля: `stage VARCHAR(50)`, `percent NUMERIC(5,2)`, `created_at`, `updated_at`
- **UNIQUE**: (`poultry_group_id`, `stage`)

### Таблица `poultry_egg_production_plan`
- **PK**: `id BIGINT`; `poultry_group_id BIGINT NOT NULL` FK → `poultry_group.id` (on delete CASCADE)
- Поля: `plan_percent NUMERIC(5,2) NOT NULL` (CHECK 0–100; `0` допустим — отличие от отсутствия строки), `created_at`, `updated_at`
- **UNIQUE**: (`poultry_group_id`) — одна запись плана на партию

### Таблица `poultry_weight_norm`
- **PK**: `id BIGINT`; `poultry_group_id BIGINT NOT NULL` FK → `poultry_group.id` (on delete CASCADE)
- Поля: `stage VARCHAR(50)`, `weight_g NUMERIC(8,2)`, `created_at`, `updated_at`
- **UNIQUE**: (`poultry_group_id`, `stage`)

### Таблица `poultry_fcr_plan`
- **PK**: `id BIGINT`; `poultry_group_id BIGINT NOT NULL` FK → `poultry_group.id` (on delete CASCADE)
- Поля: `age_days_min INT`, `age_days_max INT` — диапазон возраста птицы, `value NUMERIC(5,2)` — плановая кормоконверсия, `created_at`, `updated_at`
- **UNIQUE**: (`poultry_group_id`, `age_days_min`, `age_days_max`)

### Таблица `poultry_climate_norm`
- **PK**: `id BIGINT`
- Поля: `age_days_min`, `age_days_max`, `season`, `min_temp`, `max_temp`, `min_humidity`, `max_humidity`,
  `min_ventilation`, `max_ventilation`, `min_co2`, `max_co2`, `min_pressure`, `max_pressure`, `created_at`, `updated_at`

### Таблица `poultry_feed_norm`
- **PK**: `id BIGINT`
- Поля: `poultry_building_id BIGINT`, `name VARCHAR(100)`, `value NUMERIC(10,2)`, `date TIMESTAMPTZ`, `created_at`, `updated_at`
- Ссылка на `poultry_buildings` из БД аудита (без FK)

### Таблица `poultry_feed_fact`
- **PK**: `id BIGINT`
- Поля: `poultry_building_id BIGINT`, `name VARCHAR(100)`, `value NUMERIC(10,2)` — фактический расход **кг** за сутки по корпусу, `recipe VARCHAR(255) NULL` — название рецепта из ввода в таблице, `date TIMESTAMPTZ`, `created_at`, `updated_at`
- Ссылка на `poultry_buildings` из БД аудита (без FK)
- Сохранение из UI таблицы `/table` (POULTRY): за пару (корпус, календарный день UTC) удаляются все строки за день,
  затем одна вставка с `name = 'Таблица'` и введённым расходом (кг), чтобы сумма за день совпадала с вводом; в UI таблицы ввод в **тоннах**, на сервер уходит перевод в кг.

### Таблица `poultry_water_norm`
- **PK**: `id BIGINT`
- Поля: `poultry_building_id BIGINT NOT NULL`, `name VARCHAR(100) NOT NULL`, `value NUMERIC(10,2) NOT NULL`, `date TIMESTAMPTZ NOT NULL`, `created_at TIMESTAMPTZ NOT NULL`, `updated_at TIMESTAMPTZ NOT NULL`
- Ссылка на `poultry_buildings` из БД аудита (без FK)

### Таблица `poultry_water_fact`
- **PK**: `id BIGINT`
- Поля: `poultry_building_id BIGINT NOT NULL`, `value NUMERIC(10,2) NOT NULL`, `date TIMESTAMPTZ NOT NULL`, `created_at TIMESTAMPTZ NOT NULL`, `updated_at TIMESTAMPTZ NOT NULL`
- Сохранение из UI таблицы: за (корпус, день UTC) — удаление всех строк за день и одна вставка (мл)
