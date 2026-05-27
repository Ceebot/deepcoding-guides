# Лог выполненных задач — Ветеринарный модуль

## 2026-04-27 (ревью): `TransferPorkGroup::transferIn` — сброс `is_slaughter`

- **Суть:** при постановке группы в комнату из импорта Excel в запросе `UPDATE pork_group` не сбрасывался флаг `is_slaughter`, из-за чего в системе могла образоваться логически противоречивая комбинация: «группа физически находится в зале» и при этом «группа помечена на убой». Эти два состояния по своей природе взаимоисключающие и не должны встречаться вместе ни при каком сценарии движения животных, однако рассинхронизация проявлялась только при конкретном пути данных — импорте из Excel — и поэтому долго оставалась незамеченной при ручном тестировании через обычный интерфейс. Чтобы устранить корень проблемы, а не её внешние симптомы, в соответствующий SQL-запрос был добавлен явный сброс `is_slaughter = false`, выполняемый вместе с присвоением `pork_room_id`. Такой подход полностью повторяет уже зарекомендовавшую себя логику из `PlacedGroupController`, а также из сценария отгрузки в зал внутри `ShippedGroupController`, что обеспечивает единообразие поведения системы независимо от того, каким путём группа попадает в комнату — через UI или через пакетный импорт.
- **Файлы:** `packages/ametist-excel-parser-bundle/src/DatabaseInsert/PorkGroup/TransferPorkGroup.php`, `tests/Unit/Ametist/ExcelParserBundle/DatabaseInsert/PorkGroup/TransferPorkGroupIsSlaughterTest.php`, `.cursor/plans/2026-04-27-12-00-is-slaughter-pork-shipment.md`, `task_logs.md`.

## 2026-04-27: Отгрузка «На убой» и флаг `is_slaughter` (PORK)

- **Суть:** реализован полноценный сценарий отгрузки группы «На убой» для модуля свиноводства. Теперь при отгрузке группы из таблицы, когда у неё нет привязки к конкретной комнате, пользователь может явно выбрать вариант «На убой», и этот выбор сохраняется в базе данных в виде булева поля `pork_group.is_slaughter`. Визуально результат отражается на главной странице: в списке активных групп, не привязанных к комнате, рядом с именем такой группы выводится наглядный суффикс `(убой)`, благодаря чему оператор сразу видит назначение партии без необходимости открывать карточку. При этом флаг живёт ровно столько, сколько имеет смысл: как только группа ставится в зал или отгружается в другую комнату, `is_slaughter` автоматически сбрасывается, что исключает «залипание» некорректного состояния. Для поддержания симметрии схемы данных между двумя направлениями колонка `is_slaughter` была добавлена и в таблицу `poultry_group`, хотя пользовательский интерфейс работы с этим флагом на текущем этапе предусмотрен только для PORK.
- **Реализация:** миграция `Version20260427120100`; `PorkGroup::activeGroupNamesWithoutRoom`, `ShippedGroupController` (`isSlaughter` в JSON, 400 при конфликте с `targetRoomId`), `PlacedGroupController`; Twig + `tableCellModalMixin.js` + `ShippedGroup.js` + `TableApi.js`; юнит-тесты `PorkGroupTest`; `db-schema.mdc`, `api-contracts.md`.
- **Файлы:** `migrations/Version20260427120100.php`, `src/Module/PorkGroup/Database/PorkGroup.php`, `src/Controller/Table/Pork/ShippedGroupController.php`, `src/Controller/Table/Pork/PlacedGroupController.php`, `templates/table/pork/_cell_modal.html.twig`, `public/js/page/table/tableCellModalMixin.js`, `public/js/api/table/ShippedGroup.js`, `public/js/api/table/TableApi.js`, `tests/Unit/PorkGroup/PorkGroupTest.php`, `.cursor/rules/db-schema.mdc`, `.cursor/skills/table-page/references/api-contracts.md`, `.cursor/plans/2026-04-27-12-00-is-slaughter-pork-shipment.md`, `task_logs.md`.

## 2026-04-27: Главная PORK/POULTRY — блок «группы без комнаты/корпуса»

- **Суть:** на главной странице `/`, представляющей собой список комнат (для свиноводства) либо список корпусов (для птицеводства), над секциями с карточками появился отдельный информационный блок. В этом блоке одной строкой перечисляются все активные группы, которые в данный момент не имеют привязки к физическому помещению. Критерий «активности» и «отсутствия привязки» строго формализован на уровне запросов: для PORK это условие `pork_group.pork_room_id IS NULL` в сочетании с `end_date IS NULL`, а для POULTRY — аналогичное `poultry_group.building_id IS NULL` вместе с `end_date IS NULL`. Такой блок помогает оператору не терять из виду «подвисшие» партии, которые приехали, но ещё не размещены, и которые иначе было бы легко пропустить, просматривая только карточки помещений. На случай, когда подобных неприкаянных групп нет, предусмотрен аккуратный плейсхолдер «нет», чтобы блок не выглядел сломанным или пустым.
- **Реализация:** методы `PorkGroup::activeGroupNamesWithoutRoom`, `PoultryGroup::activeGroupNamesWithoutBuilding`; прокси в `RoomsData` / `BuildingsData`; миграция `Version20260427120000` (nullable `poultry_group.building_id`); в `PoultryGroup::roomIdsEligibleForStatusUpdate` исключены строки с `building_id IS NULL`; Twig + стили `rooms.scss` / `buildings.scss`; юнит-тесты в `PorkGroupTest`, `PoultryGroupTest`.
- **Файлы:** `migrations/Version20260427120000.php`, `src/Module/PorkGroup/Database/PorkGroup.php`, `src/Module/PoultryGroup/Database/PoultryGroup.php`, `src/Module/PorkGroup/PageData/RoomsData.php`, `src/Module/PoultryGroup/PageData/BuildingsData.php`, `src/Controller/Pork/RoomsPageController.php`, `src/Controller/Poultry/BuildingsPageController.php`, `templates/pork/rooms/rooms.html.twig`, `templates/poultry/buildings/list.html.twig`, `assets/scss/pages/rooms.scss`, `assets/scss/pages/buildings.scss`, `tests/Unit/PorkGroup/PorkGroupTest.php`, `tests/Unit/PoultryGroup/PoultryGroupTest.php`, `.cursor/rules/db-schema.mdc`, `task_logs.md`.

## 2026-04-23 (логика возраста PORK): ручной age приоритет, перезапись `start_date`, формула header

- **Суть:** для операций постановки и отгрузки в модуле свиноводства полностью пересмотрена логика определения возраста группы. Ключевое изменение — введён приоритет ручного ввода: если оператор явно указал значение в поле `Кол-во дней`, именно оно считается источником истины, и система не пытается «перебить» его собственными расчётами. Лишь в том случае, когда ручное значение не задано, включается механизм fallback — автоматический пересчёт возраста от даты группы, как это работало раньше. Дополнительно при каждом движении группы корректно обновляется поле `pork_group.start_date`, что позволяет всем последующим расчётам опираться на актуальную точку отсчёта, а не на устаревшую. Наконец, в шапке (header) комнаты возраст теперь выводится по прозрачной и легко проверяемой формуле: `возраст на момент постановки + число дней, прошедших с даты постановки`. Благодаря этому отображаемое значение всегда согласовано с фактической историей перемещений животных.
- **Реализация:** `PlacedGroupController` — чтение `start_date`, `resolvedAgeDays(manual->auto)`, запись `age_days` в movement и обновление `pork_group.start_date`; `ShippedGroupController` — аналогично для отгрузок (с целевой комнатой и без), запись `start_date` в `pork_group`; `HeaderData` — `ageForHeader()` на базе `movement_age_days` + `calculateAge(movement_start_date || start_date)`.
- **Файлы:** `src/Controller/Table/Pork/PlacedGroupController.php`, `src/Controller/Table/Pork/ShippedGroupController.php`, `src/Module/PorkGroup/PageData/HeaderData.php`, `task_logs.md`.

## 2026-04-23 (UI): Главная PORK — хедер как у POULTRY + title в сайдбаре «Список корпусов»

- **Суть:** проведена работа по визуальному и смысловому выравниванию главной страницы свиноводства с уже устоявшимся оформлением страницы птицеводства. Раньше две эти ключевые страницы выглядели по-разному, что создавало у пользователя ощущение разрозненности интерфейса и заставляло каждый раз заново привыкать к структуре. Теперь заголовок и подзаголовок на главной свиноводства приведены к единому формату, принятому в птицеводстве, — с поправкой на доменную терминологию (формулировки переписаны под свиней, а не под птицу). Помимо самого контента шапки, скорректировано и отображение в боковом меню: на этой странице в сайдбаре теперь показывается пункт `Список корпусов` вместо прежнего `Участок доращивания`, что точнее отражает фактическое содержание раздела и снимает путаницу с терминами.
- **Реализация:** в `RoomsPageController` изменён `title` на `Список корпусов`; в `rooms.html.twig` обновлён подзаголовок на «Обзор всех корпусов и партий свиней»; в `sidenav.html.twig` условие для PORK синхронизировано с новым заголовком главной (`title != 'Список корпусов'`), чтобы логика кнопки «К комнатам» работала корректно.
- **Документация:** обновлён `frontend-architecture.mdc` — добавлен блок про главную `/` для PORK/POULTRY и уровень группировки (PORK по `pork_building`).
- **Файлы:** `src/Controller/Pork/RoomsPageController.php`, `templates/pork/rooms/rooms.html.twig`, `templates/components/blocks/sidenav.html.twig`, `.cursor/rules/frontend-architecture.mdc`, `task_logs.md`.

## 2026-04-23 (фикс): PORK главная — группировка по building вместо site

- **Суть:** на главной странице свиноводства был обнаружен баг отображения: вместо ожидаемых заголовков уровня корпуса показывался заголовок уровня площадки (например, `Репродуктор ...`). Причина крылась в том, что секции карточек группировались по сущности `pork_site`, то есть на один уровень выше, чем требовалось бизнес-логикой. Это расходилось с тем, как данные представлены в основной таблице свиноводства, и вводило пользователя в заблуждение относительно того, что именно он видит на экране. Для устранения несоответствия группировка была понижена до уровня корпуса/участка `pork_building`, благодаря чему секции теперь корректно озаглавлены привычными названиями вроде `Доращивание 1/2` и `Откорм 1/2`. После правки главная страница и таблица оперируют одной и той же иерархией, и переход между ними больше не требует мысленного «пересчёта» уровней.
- **Реализация:** в `RoomsData` в карточку комнаты добавлены `building_id/building_name`; в `RoomsPageController::roomsBySite()` первичный ключ группировки изменён на `building_name` с fallback на `site_name`.
- **Файлы:** `src/Module/PorkGroup/PageData/RoomsData.php`, `src/Controller/Pork/RoomsPageController.php`, `task_logs.md`.

## 2026-04-23 (доп.): Главная POULTRY — группировка карточек корпусов по участкам

- **Суть:** на странице `/` в режиме птицеводства список корпусов получил полноценную двухуровневую группировку по участкам, что существенно повысило читаемость для крупных площадок с большим числом корпусов. Теперь страница строится по принципу «сначала заголовок участка, затем относящиеся к нему карточки корпусов»: каждый участок визуально отделён собственным заголовком, под которым компактно собраны все его корпуса. Это избавляет оператора от необходимости вручную сопоставлять разрозненные карточки с участками и заметно ускоряет навигацию. Для устойчивости к неполным данным предусмотрен аккуратный fallback: если у корпуса по какой-то причине отсутствует название участка, такие карточки собираются под служебным заголовком `Без участка`, и страница не «рассыпается» из-за пропущенного значения.
- **Реализация:** `BuildingsData` переключён на источник `buildingsWithSites()` и дополняет карточки `site_id/site_name`; в `BuildingsPageController` добавлена группировка `buildingsBySite`; шаблон `poultry/buildings/list.html.twig` перестроен на секции `buildings_by_site`; стили `buildings.scss` дополнены классами секций и заголовков.
- **Файлы:** `src/Module/PoultryGroup/PageData/BuildingsData.php`, `src/Controller/Poultry/BuildingsPageController.php`, `templates/poultry/buildings/list.html.twig`, `assets/scss/pages/buildings.scss`, `task_logs.md`.

## 2026-04-23: Главная PORK — группировка карточек комнат по участкам

- **Суть:** на странице `/` для модуля свиноводства реализована группировка карточек комнат по участкам, симметричная той, что используется в птицеводстве. Карточки больше не выводятся одним сплошным списком, в котором легко потеряться: вместо этого страница организована иерархически — сначала идёт заголовок участка, а ниже располагаются все принадлежащие ему комнаты. Такой порядок делает структуру площадки наглядной с первого взгляда и позволяет оператору быстро находить нужное помещение, ориентируясь сразу на участок. Чтобы интерфейс оставался устойчивым при неполных или ещё не заполненных данных, добавлен fallback-заголовок `Без участка`: под него попадают комнаты, у которых привязка к участку по каким-либо причинам отсутствует, что гарантирует корректное отображение страницы в любых условиях.
- **Реализация:** данные комнат теперь загружаются с `site/building` через `roomsWithSites()`, в `RoomsPageController` добавлена серверная группировка `roomsBySite`, шаблон `rooms.html.twig` перестроен на секции `rooms_by_site`, стили `rooms.scss` расширены классами секций/заголовков.
- **Файлы:** `src/ExternalModule/AuditModule/Pork/Room/Rooms.php`, `src/Module/PorkGroup/PageData/RoomsData.php`, `src/Controller/Pork/RoomsPageController.php`, `templates/pork/rooms/rooms.html.twig`, `assets/scss/pages/rooms.scss`, `task_logs.md`.

## 2026-04-21 (reviewer, раунд 2): ЛПМ свиней, очистка яиц без потери брака, доки

- **Суть:** второй раунд правок по результатам ревью, затронувший сразу несколько связанных областей. В `PorkGroup\TableData::applyLpmData` поведение при пустом `medicament_id` в интервале приведено к единообразию с птицеводством: вместо прерывания обработки выполняется `continue`, что позволяет корректно пропускать незаполненные записи, не теряя остальные данные интервала. В `SavedPoultryEggsDay::clearDayForDate` уточнена семантика очистки дня — теперь сбрасывается только показатель `whole`, тогда как значение `defective` сознательно сохраняется, чтобы при редактировании целых яиц не терять ранее учтённый брак. Соответствующее уточнение внесено в контракт `api-contracts.md` в части яиц (eggs). Параллельно приведена в порядок документация: в описании парсера ЛПМ оставлен один корректный пункт про `history`, а также закреплён используемый в домене термин «метафилактика». Добавлен поясняющий PHPDoc в `MedicamentsController` относительно поведения фильтра при `animal_type IS NULL` (общие препараты). Все изменения подкреплены тестами — новыми кейсами в `TableDataApplyLpmTest` и доработкой `SavedPoultryEggsDayTest`.
- **Файлы:** `src/Module/PorkGroup/PageData/TableData.php`, `src/Module/PoultryGroup/Database/SavedPoultryEggsDay.php`, `src/Controller/Medicament/MedicamentsController.php`, `tests/Unit/Module/PorkGroup/PageData/TableDataApplyLpmTest.php`, `tests/Unit/Module/PoultryGroup/Database/SavedPoultryEggsDayTest.php`, `.cursor/skills/table-page/references/api-contracts.md`, `docs/parser/таблица_падёжа_выпойки/Описание_таблицы.md`, `task_logs.md`.

## 2026-04-21 (reviewer): правки по плану таблицы — ЛПМ `applyLpmData`, яйца `records: []`, миграция `medicament`, доки

- **Суть:** пакет правок по плану доработки таблицы, выполненных по итогам ревью и затронувших как backend-логику, так и хранение данных и документацию. В методе `applyLpmData` пустой `medicament_id` больше не прерывает перебор записей ЛПМ, благодаря чему частично заполненные интервалы обрабатываются корректно и не «обрывают» остальные данные. Миграция `Version20260421153100` переработана так, чтобы она перестала затирать значение `NULL` в `medicament.animal_type` — это важно для так называемых общих препаратов, которые применимы сразу к нескольким видам животных. Уточнено поведение запроса `PUT` для яиц с телом `records: []`: через `clearDayForDate` снимается только показатель `whole`, тогда как `defective` остаётся нетронутым (стоит отметить, что ранее в этой записи лога формулировка «очищает день» была неточной; актуальное и проверенное поведение зафиксировано во втором раунде правок и отражено в `api-contracts.md`). На фронте в модалке яиц устранена отправка полностью пустых блоков — такие блоки теперь просто не попадают в запрос. Дополнительно у `SavedCullingCellController` оставлен единственный корректный атрибут `#[Route]`, добавлен поясняющий PHPDoc по агрегации корма, а также синхронизированы документация (`api-contracts.md`, описание парсера ЛПМ) и тесты (`PoultryTableDataTest`, `SavedPoultryEggsDayTest`).
- **Файлы:** `src/Module/PoultryGroup/PageData/PoultryTableData.php`, `migrations/Version20260421153100.php`, `src/Module/PoultryGroup/Database/SavedPoultryEggsDay.php`, `src/Controller/Table/Poultry/SavedPoultryCellController.php`, `src/Controller/Table/Pork/SavedCullingCellController.php`, `public/js/page/table/poultry/tablePagePoultryCellModalMixin.js`, `tests/Unit/Module/PoultryGroup/PageData/PoultryTableDataTest.php`, `tests/Unit/Module/PoultryGroup/Database/SavedPoultryEggsDayTest.php`, `.cursor/skills/table-page/references/api-contracts.md`, `docs/parser/таблица_падёжа_выпойки/Описание_таблицы.md`, `task_logs.md`.

## 2026-04-21 (доп.): юнит-тесты под сорта яиц СВ…С3, `PoultryTableData` + `PlannedEvents`, брак/яйца

- **Суть:** после прерывания прогона приведены в соответствие `PoultryEggsEnumTest`, `PoultryTableDataTest` (5-й аргумент конструктора), `SavedPoultryCullDayTest` (текст исключения), `SavedPoultryEggsDayTest` (кейсы сортов `СВ`/`С1`); отмечены чекбоксы в `todo.md` → `## Правки`; `npm run build:js` — OK; полный `php bin/phpunit` в контейнере `vet_php-fpm-vet` — OK.
- **Файлы:** `tests/Unit/Enum/Poultry/PoultryEggsEnumTest.php`, `tests/Unit/Module/PoultryGroup/PageData/PoultryTableDataTest.php`, `tests/Unit/Module/PoultryGroup/Database/SavedPoultryCullDayTest.php`, `tests/Unit/Module/PoultryGroup/Database/SavedPoultryEggsDayTest.php`, `todo.md`, `.cursor/rules/db-schema.mdc` (описание `pork_group.culling_list`).

## 2026-04-21: Таблица — план `2026-04-21-15-30-table-fixes-right-section` (§Правки в todo)

- **Суть:** миграции A (`Version20260421153000` … `153200`) в репозитории; реализованы UI/API из раздела «Правки»: выбраковка PORK (`SavedCullingCell.js`, тултип без дубля ЛПМ у выбраковки), POULTRY — несколько записей яиц, брак (насечка/скорлупа), корм в т + `recipe`, вода в л, вкладка ЛПМ + `LoadedMedicaments`/`CreatedLpm`, загрузка препаратов `pork`/`poultry`; «Метафилактика» в UI, тестах, `RecordedPlannedEvent`, импорте LPM, `PoultryLpmData`; фикстуры `medicament` с `animal_type` и тестовыми препаратами для птиц; обновлены `db-schema.mdc`, `fixtures-rules.mdc`, `api-contracts.md`; handoff в плане отмечен.
- **Файлы (ключевые):** `public/js/api/table/SavedCullingCell.js`, `public/js/page/table/poultry/tablePagePoultryCellModalMixin.js`, `public/js/page/table/poultry/tablePagePoultry.js`, `templates/table/poultry/_cell_modal.html.twig`, `templates/table/poultry/table.html.twig`, `public/js/component/lpm/LpmModal.js`, `src/DataFixtures/MedicamentFixtures.php`, `public/js/page/table/tableCellTypes.js`, `.cursor/skills/table-page/references/api-contracts.md`, `.cursor/rules/db-schema.mdc`, `.cursor/plans/2026-04-21-15-30-table-fixes-right-section.md`.

## 2026-04-17: Analytics POULTRY — UX: скролл при графике, горизонтальный скролл таблицы, фикс строки «Среднее»

- **Суть:** после перерисовки Apex не прыгает окно (`scrollTo` после двойного `requestAnimationFrame`); колонка контента grid
  с `min-width: 0` и обёртка таблицы — горизонтальный скролл внутри блока; `tfoot` с `position: sticky; bottom: 0` и  z-index для угла как у thead.
- **Файлы:** `public/js/page/analytics/poultry/analyticsPage.js`, `assets/scss/pages/analytics-poultry.scss`, `task_logs.md`.

## 2026-04-17: Analytics POULTRY — блок «Табличные данные» под графиком

- **Суть:** под объединённым графиком метрик на `/analytics` (POULTRY) добавлен блок с заголовком, сводкой Ср/Мин/Макс по
  колонкам (корпус × метрика) и таблицей `fact` по дням (`toFixed(2)`); пустые точки — `—`. Данные из уже загруженных
  `*-chart` и того же merge дат/серий, что у `RenderedPoultryMetricsChartData`; нового backend-эндпойнта нет.
- **Реализация:** `BuiltPoultryMetricsTableData.js` (порядок колонок: корпус, затем выбранные метрики), состояние
  `poultryMetricsTableData` в `analyticsPage.js`, разметка в `_metrics-graph.html.twig`, стили в `analytics-poultry.scss`;
  регрессия builder: `node scripts/verify-poultry-table-builder.mjs`.
- **Файлы:** `public/js/component/analytics/poultry/BuiltPoultryMetricsTableData.js`,
  `public/js/page/analytics/poultry/analyticsPage.js`, `templates/analytics/poultry/_metrics-graph.html.twig`,
  `templates/analytics/poultry/analytics.html.twig`, `assets/scss/pages/analytics-poultry.scss`,
  `scripts/verify-poultry-table-builder.mjs`, `task_logs.md`,
  `.cursor/skills/analytics-page/SKILL.md`, `.cursor/skills/analytics-page/references/poultry.md`,
  `.cursor/rules/frontend-architecture.mdc`, `.cursor/plans/2026-04-17-15-32-analytics-poultry-table-data-block.md`.

## 2026-04-17: Analytics POULTRY — красные линии скачков и строки в тултипе

- **Суть:** вертикальные пунктирные аннотации скачков температуры на графике аналитики POULTRY перекрашены в красный
  (`#dc2626`); в кастомный HTML-тултип добавлены строки событий по дню: корпус, датчик, `Δ`, переход `prev → current`
  и время события (если есть `occurred_at`).
- **Техдетали:** по `temperatureSpikeEvents` строится `temperatureSpikeTooltipByDay` (группировка по `chart_date`,
  сортировка по `delta_c`, дедуп по `building_id:sensor_id:occurred_at`), контекст передаётся в
  `_poultryMetricsChartTooltipContext`.
- **Файлы:** `public/js/component/analytics/poultry/RenderedPoultryMetricsChartData.js`, `task_logs.md`,
  `.cursor/skills/analytics-page/SKILL.md`, `.cursor/skills/analytics-page/references/poultry.md`,
  `.cursor/rules/frontend-architecture.mdc`.

## 2026-04-17: SensorFixtures — детерминированные скачки температуры для проверки аналитики

- **Суть:** в `SensorFixtures` добавлены контролируемые скачки температуры для части `poultry_building` (корпуса `1`, `3`, `5`)
  в фиксированные `dayOffset/hour` слоты. Пиковые значения заданы так, чтобы на соседних точках стабильно выполнялся критерий
  аналитики **`|delta| >= 10°C`** и вертикальные события можно было проверить в UI `/analytics`.
- **Реализация:** расширены сигнатуры генерации intraday-данных (`roomId`, `roomType`, `dayOffset`), добавлены константы
  расписания/значений и helper `isPoultryTemperatureSpikeMoment()`. Для `pork_room` поведение генератора без изменений.
- **Файлы:** `src/DataFixtures/SensorFixtures.php`, `.cursor/rules/fixtures-rules.mdc`, `task_logs.md`.

## 2026-04-17: Analytics POULTRY — ревью: скачки температуры (синхрон now, LAG, даты на фронте)

- **Суть (правки reviewer):** один снимок `now` для `dates` и UTC-границ SQL; `LAG` по полной ленте `sensor_data` в подзапросе,
  фильтр периода только на внешнем `z.created_at`; union оси на клиенте дополнен `poultryTemperatureSpikePayload.dates`;
 тесты порога 10 / пустой fetch / форма SQL; разбор `created_at` через try/catch при невалидной строке.
- **Файлы:** `PreparedPoultryTemperatureSpikeEvents.php`, `PreparedPoultryTemperatureSpikeEventsTest.php`,
  `analyticsPage.js`, `.cursor/skills/analytics-page/references/poultry.md`, `task_logs.md`.

## 2026-04-17: Analytics POULTRY — вертикальные маркеры скачка температуры (≥10 °C)

- **Суть:** на объединённом графике метрик `/analytics` (POULTRY) отображаются **особые события** — скачки температуры по
  `sensor_data` (тип `TEMPERATURE`, корпус `sensor.room_id` при `room_type = poultry_building`): вертикальные пунктирные
  линии (`annotations.xaxis` ApexCharts) на всю высоту графика. Критерий: **|Δ| ≥ 10 °C** между двумя **соседними** по БД
  показаниями одного `sensor_id` (упорядочивание `created_at ASC`, `id ASC`; момент события — второе показание). Период в
  UTC для SQL: от `rangeStart` 00:00 пользователя до `(todayStart + 1 day)` 00:00 пользователя (полуинтервал), как ось `dates`
  у метрик. Отдельный endpoint **`GET /api/analytics/poultry/temperature-spike-events`** (те же query, что `*-chart`);
  при выключенном модуле **SENSORS** — `events: []` без ошибки. Общая логика списка корпусов вынесена в
  `ResolvedPoultryAnalyticsChartBuildingIds` (используют `PreparedPoultryMortalityChartSeries`, `PreparedPoultryLpmChartSeries`,
  `PreparedPoultryTemperatureSpikeEvents`). На клиенте: `LoadedPoultryTemperatureSpikeEvents.js`, запрос параллельно метрикам /
  ЛПМ при `window.poultryAnalyticsSensorsModuleEnabled`; несколько скачков в один календарный день — **одна** вертикаль на
  `chart_date`; события с датой вне merge `dates` отбрасываются.
- **Тесты:** `docker exec … php bin/phpunit tests/Unit/Module/Analytics/Poultry/` — OK (43). `make test` локально падает из‑за
  CRLF в `bin/phpunit-clean` (как ранее в логе).
- **Файлы:** `src/Module/Analytics/Poultry/PreparedPoultryTemperatureSpikeEvents.php`,
  `src/Module/Analytics/Poultry/ResolvedPoultryAnalyticsChartBuildingIds.php`,
  `src/Module/Analytics/Poultry/PreparedPoultryMortalityChartSeries.php`,
  `src/Module/Analytics/Poultry/PreparedPoultryLpmChartSeries.php`,
  `src/Controller/Analytics/Poultry/PoultryAnalyticsTemperatureSpikeEventsController.php`,
  `public/js/api/analytics/poultry/LoadedPoultryTemperatureSpikeEvents.js`,
  `public/js/page/analytics/poultry/analyticsPage.js`,
  `public/js/component/analytics/poultry/RenderedPoultryMetricsChartData.js`,
  `templates/analytics/poultry/analytics.html.twig`,
  `tests/Unit/Module/Analytics/Poultry/PreparedPoultryTemperatureSpikeEventsTest.php`,
  `tests/Unit/Module/Analytics/Poultry/PreparedPoultryMortalityChartSeriesTest.php`,
  `tests/Unit/Module/Analytics/Poultry/PreparedPoultryLpmChartSeriesTest.php`,
  `.cursor/skills/analytics-page/SKILL.md`, `.cursor/skills/analytics-page/references/poultry.md`,
  `.cursor/rules/frontend-architecture.mdc`, `.cursor/plans/2026-04-17-12-00-poultry-analytics-temperature-spike-markers.md`.

## 2026-04-16: Analytics POULTRY — ЛПМ без column: маркеры `markers.discrete` на линиях

- **Суть:** убраны column-серии ЛПМ из mixed ApexCharts; наличие ЛПМ показывается **увеличенными маркерами** на линиях метрик
  (`markers.discrete`, индексы `seriesIndex` / `dataPointIndex`, цвет в тон линии). Предикат дня с ЛПМ совпадает с критериями
  строк тултипа (`label` + `value`). Переименован цвет тултипа: `lpmTooltipRoomColor`. При включённом ЛПМ без выбранных метрик —
  empty state в контейнере (класс `analytics-page-poultry__metrics-graph-empty`), график не создаётся.
- **Тесты:** PHP не менялся; `make test` не запускался.
- **Файлы:** `public/js/component/analytics/poultry/RenderedPoultryMetricsChartData.js`,
  `assets/scss/pages/analytics-poultry.scss`, `.cursor/skills/analytics-page/SKILL.md`,
  `.cursor/skills/analytics-page/references/poultry.md`, `.cursor/rules/frontend-architecture.mdc`, `task_logs.md`,
  `.cursor/plans/2026-04-16-17-30-poultry-analytics-lpm-line-markers.md`.
- **Ревью:** в `lpmChartPointQualifiesForTooltip` добавлена проверка `Number.isFinite` для `value`; цвет строк метрик в
  тултипе через `sanitizeTooltipColor`; в `poultry.md` уточнена цепочка санитизации цвета ЛПМ; newline в конце
  `analytics-poultry.scss`.
- **Уборка:** удалён устаревший `tmp/playwright-poultry-lpm-regression.mjs` (column-режим); JSDoc в
  `LoadedPoultryLpmChartData.js`, комментарий в `analyticsPage.js` без отсылки к column.

## 2026-04-16: Analytics POULTRY — ЛПМ: откат grouped, снова stack + узкий column

- **Суть:** отменён эксперимент **grouped** столбцов ЛПМ; восстановлено **`chart.stacked: hasLpmColumns`**,
  **`stackOnlyBar: true`**, **`plotOptions.bar.columnWidth: 10%`** при ЛПМ, **`LPM_COLUMN_HEIGHT: 8`** (как до grouped).
- **Файлы:** `public/js/component/analytics/poultry/RenderedPoultryMetricsChartData.js`, `task_logs.md`.

## 2026-04-16: Analytics POULTRY — ЛПМ column: grouped (рядом), без stack

- **Суть:** по запросу UX — столбцы ЛПМ разных корпусов в одном дне **рядом** (Apex grouped), а не stack друг над
  другом и без смешивания цветов в одной точке при включённых метриках. У **`chart`** выставлено **`stacked: false`**
  (раньше при ЛПМ было `true`). Сохранены **`stackOnlyBar: true`**, легенда скрыта, **`columnWidth`** для режима ЛПМ
  **28%** (компромисс читаемость / съём ширины сетки). При регрессе hover/сетки — откат к прежнему stack.
- **Файлы:** `public/js/component/analytics/poultry/RenderedPoultryMetricsChartData.js`, `task_logs.md`.

## 2026-04-16: Analytics POULTRY — mixed-график: ЛПМ column, легенда off, меньше сужения и дубля hover

- **Суть:** несколько ЛПМ `column` в одной категории без stacked давали **grouped** столбцы (два якоря hover, смещение
  центров относительно линии). Включены **`chart.stacked` только при наличии ЛПМ-колонок** и **`stackOnlyBar: true`**
  (стек только у column, линии не схлопываются). Легенда Apex **скрыта** (`legend.show: false`). Частичное сужение
  `gridWidth` из‑за bar-pad в Apex при numeric-подобной оси компенсировано **`plotOptions.bar.columnWidth: 10%`** в режиме
  ЛПМ и явным **`xaxis.type: 'category'`** (на стенде: ~946px → ~915px вместо ~773px ранее). JSDoc выровнены с фактической
  одной осью Y для метрик и ЛПМ.
- **Проверка:** ручная проверка в браузере (ранее использовался временный Playwright-скрипт для column-режима).
- **Файлы:** `public/js/component/analytics/poultry/RenderedPoultryMetricsChartData.js`, `task_logs.md`.

## 2026-04-16: Analytics POULTRY — ЛПМ через native ApexCharts (column + line), без overlay

- **Суть:** ЛПМ на графике метрик — **mixed chart** ApexCharts, без overlay: серии ЛПМ рисуются как `column`, а метрики — как
  линии на оси отклонения **−100…100**. Удалены SVG-overlay и связанный мёртвый код. После стабилизации mixed-графика убрана
  логика «следующий ЛПМ выше/за предыдущим»: отключены стек/группы для ЛПМ, столбцы отображаются рядом по сериям в один день,
  визуальная высота столбцов фиксирована на фронте как маркер ЛПМ-активности. Контракт
  **`GET /api/analytics/poultry/lpm-chart`** остаётся без `lpm_intervals`; источник UI/тултипа — `series[].data[i].label`.
  Обновлены референс `references/poultry.md` и правило `frontend-architecture.mdc`.
- **Тесты:** `docker exec … php bin/phpunit tests/Unit/Module/Analytics/Poultry/PreparedPoultryLpmChartSeriesTest.php` — OK.
- **Файлы:** `public/js/component/analytics/poultry/RenderedPoultryMetricsChartData.js`,
  `public/js/page/analytics/poultry/analyticsPage.js`, `public/js/api/analytics/poultry/LoadedPoultryLpmChartData.js`,
  `src/Module/Analytics/Poultry/PreparedPoultryLpmChartSeries.php`,
  `src/Controller/Analytics/Poultry/PoultryAnalyticsLpmChartController.php`,
  `tests/Unit/Module/Analytics/Poultry/PreparedPoultryLpmChartSeriesTest.php`,
  `.cursor/skills/analytics-page/references/poultry.md`, `.cursor/rules/frontend-architecture.mdc`, `task_logs.md`.

## 2026-04-16: Analytics POULTRY — ЛПМ overlay: правки по ревью (дорожки, ось X, ResizeObserver)

- **Суть:** вертикальные смещения дорожек ЛПМ на overlay масштабируются под доступную высоту inner (`LPM_OVERLAY_TOP_PAD`,
  clamp `y`); центры категорий по оси X — нестрогое совпадение числа DOM-подписей с `dates.length` (интерполяция и
  прореживание по отсортированным позициям); перерисовка overlay дополнена `ResizeObserver` на контейнер графика (вместе с
  `resize`); `dynamicAnimation.enabled` выровнен с `animations.enabled: false`; цвет строки ЛПМ в HTML-тултипе пропускается
  через `sanitizeTooltipColor`. В `PreparedPoultryLpmChartSeries::chartPayload` интервалы собираются в один массив без
  `array_merge` в цикле по корпусам.
- **Тесты:** `docker exec … php bin/phpunit tests/Unit/Module/Analytics/Poultry/PreparedPoultryLpmChartSeriesTest.php` — OK. `make test` локально падает из‑за CRLF в
  `bin/phpunit-clean` (как ранее).
- **Файлы:** `public/js/component/analytics/poultry/RenderedPoultryMetricsChartData.js`,
  `src/Module/Analytics/Poultry/PreparedPoultryLpmChartSeries.php`, `.cursor/rules/frontend-architecture.mdc`, `task_logs.md`.

## 2026-04-16: Analytics POULTRY — ЛПМ: overlay вместо mixed Apex (line+column)

- **Суть:** контракт `GET /api/analytics/poultry/lpm-chart` дополнен массивом **`lpm_intervals`** (явные интервалы по
  `event_id`, `building_id`, `building_name`, `legend_index`, даты inclusive, обрезка к периоду); серия `series[]`
  сохранена для совместимости, отрисовка ЛПМ на клиенте только из интервалов. ApexCharts рисует **только линии метрик**;
  ЛПМ — **SVG-overlay** (`data-poultry-lpm-overlay`) поверх `.apexcharts-inner`, `pointer-events: none`, перерисовка на
  `mounted` / `updated` / `animationEnd` и debounced `resize`, цвет `roomColorWithAlpha(..., 0.5)`, расслоение по
  `legend_index` и до 5 sub-lane внутри корпуса. Тултип ЛПМ — из `lpm_intervals` по дню. Toggle `showPoultryLpmOverlay` и
  догрузка `lpm-chart` без изменения сценария.
- **Тесты:** `docker exec … php bin/phpunit tests/Unit/Module/Analytics/Poultry/PreparedPoultryLpmChartSeriesTest.php` — OK.
  `make test` в локальной среде падает из‑за CRLF в `bin/phpunit-clean` (не связано с задачей).
- **Файлы:** `src/Module/Analytics/Poultry/PreparedPoultryLpmChartSeries.php`,
  `src/Controller/Analytics/Poultry/PoultryAnalyticsLpmChartController.php`,
  `tests/Unit/Module/Analytics/Poultry/PreparedPoultryLpmChartSeriesTest.php`,
  `public/js/component/analytics/poultry/RenderedPoultryMetricsChartData.js`,
  `public/js/page/analytics/poultry/analyticsPage.js`,
  `public/js/api/analytics/poultry/LoadedPoultryLpmChartData.js`,
  `assets/scss/pages/analytics-poultry.scss`, `templates/analytics/poultry/sidebar/_lpm-toggle.html.twig`,
  `.cursor/skills/analytics-page/references/poultry.md`, `.cursor/rules/frontend-architecture.mdc`,
  `.cursor/plans/2026-04-16-16-00-analytics-poultry-lpm-overlay-refactor.md`, `task_logs.md`.

## 2026-04-16: Analytics POULTRY — ревью ЛПМ: стек, маркеры, PHPDoc, догрузка lpm-chart

- **Суть:** несколько ЛПМ на один корпус и день — отдельные `series[]` с полем `stack_slot` и стек на графике (`group:
  lpm-{building_id}`, `chart.stacked` при наличии столбиков); тултип — одна подпись на слот. Сравнение дня события с
  календарём — через TZ `TimezoneProvider`. Выровнен PHPDoc `PlannedEvents::lpmEventsForGroupsForPeriod` с SQL (включительные
  календарные границы). В `RenderedPoultryMetricsChartData` маркеры только у линий (размер 0 у column). В `analyticsPage.js`
  при неизменных фильтрах и успешном кэше метрик, но `poultryLpmPayload === null`, выполняется повторный запрос только
  `lpm-chart`. Обновлён референс `references/poultry.md`; тест `testTwoLpmSameBuildingSameDayYieldTwoStackSlots`.
- **Тесты:** `docker exec … php bin/phpunit tests/Unit/Module/Analytics/Poultry/PreparedPoultryLpmChartSeriesTest.php` — OK.
- **Файлы:** `src/Module/Analytics/Poultry/PreparedPoultryLpmChartSeries.php`,
  `src/Module/PlannedEvent/Database/PlannedEvents.php`,
  `public/js/component/analytics/poultry/RenderedPoultryMetricsChartData.js`,
  `public/js/page/analytics/poultry/analyticsPage.js`,
  `tests/Unit/Module/Analytics/Poultry/PreparedPoultryLpmChartSeriesTest.php`,
  `.cursor/skills/analytics-page/references/poultry.md`, `task_logs.md`.

## 2026-04-16: Analytics POULTRY — ЛПМ на общем графике метрик (столбики)

- **Суть:** добавлен `GET /api/analytics/poultry/lpm-chart` и сервис `PreparedPoultryLpmChartSeries` (группы за период,
  `ResolvedGroupOnChartDay`, пакет `PlannedEvents::lpmEventsForGroupsForPeriod` для poultry). Точки дня: `value` / `label`;
  высота столбика `(legend_index+1)*10` при активном ЛПМ; интервал дней по `duration_days`. В `PlannedEvents` в выборку ЛПМ
  добавлено поле `event_name`. На фронте: `LoadedPoultryLpmChartData.js`, загрузка ЛПМ вместе с полной перезагрузкой query
  метрик, `showPoultryLpmOverlay` + `sidebar/_lpm-toggle.html.twig`, смешанный ApexCharts (линии + `column` на вторичную ось),
  цвет ЛПМ — `roomColorWithAlpha(..., 0.5)`. Контракты существующих `*-chart` не менялись.
- **Тесты:** `tests/Unit/Module/Analytics/Poultry/PreparedPoultryLpmChartSeriesTest.php`; прогон
  `php bin/phpunit tests/Unit` в контейнере `vet_php-fpm-vet` — OK.
- **Файлы:** `src/Module/PlannedEvent/Database/PlannedEvents.php`,
  `src/Module/Analytics/Poultry/PreparedPoultryLpmChartSeries.php`,
  `src/Controller/Analytics/Poultry/PoultryAnalyticsLpmChartController.php`,
  `public/js/api/analytics/poultry/LoadedPoultryLpmChartData.js`,
  `public/js/page/analytics/poultry/analyticsPage.js`,
  `public/js/page/analytics/poultry/utils/roomColor.js`,
  `public/js/component/analytics/poultry/RenderedPoultryMetricsChartData.js`,
  `templates/analytics/poultry/analytics.html.twig`,
  `templates/analytics/poultry/sidebar/sidebar.html.twig`,
  `templates/analytics/poultry/sidebar/_lpm-toggle.html.twig`,
  `.cursor/skills/analytics-page/references/poultry.md`, `.cursor/skills/analytics-page/SKILL.md`,
  `.cursor/rules/frontend-architecture.mdc`.

---

## 2026-04-15: Analytics POULTRY — включена плавная анимация линий графика

- **Суть:** в `RenderedPoultryMetricsChartData` включена анимация ApexCharts для первичного рендера и апдейтов:
  `chart.animations.enabled=true`, `easing='easeinout'`, `speed=550`, `dynamicAnimation.speed=320`.
  Для исключения эффекта «лестницы» оставлен режим без постепенной отрисовки серий:
  `animateGradually.enabled=false`.
  При обновлении графика включена анимация в `updateOptions(..., ..., true, ...)`.
- **Файлы:** `public/js/component/analytics/poultry/RenderedPoultryMetricsChartData.js`.

---

## 2026-04-15: Фикстуры POULTRY — выровнены данные для аналитики отклонений

- **Суть:** уменьшены экстремальные отклонения (`±100%`) на графиках poultry за счёт более реалистичных демо-данных:
  в `PoultryGroupFixtures` яйца теперь генерируются **ежедневно без пропусков** (`eggs_list`) и ближе к плану
  (плавный процент лэйинга + шум); суточный падеж сделан регулярным и умеренным (без «пустых» длинных участков).
  В `PoultryDeathsNormFixtures` нормы стадий снижены до реалистичных долей процента (`0.012/0.014/0.016`), чтобы
  факт и норма были сопоставимы по масштабу. В `PoultryEggProductionPlanFixtures` плановые проценты выровнены под
  демо-профили групп (стабильные значения около 87–91% вместо широкого случайного разброса).
- **Перезагрузка данных:** выполнены `make audit-fixtures-load-poultry` и `make fixtures-load` (успешно).
- **Файлы:** `src/DataFixtures/Poultry/PoultryGroupFixtures.php`,
  `src/DataFixtures/Poultry/PoultryDeathsNormFixtures.php`,
  `src/DataFixtures/Poultry/PoultryEggProductionPlanFixtures.php`,
  `.cursor/rules/fixtures-rules.mdc`.

---

## 2026-04-15: Analytics POULTRY — ревью: merge дат, id контейнера, один SQL норм падежа

- **Суть:** объединение payload метрик на общей оси: union всех `dates`, сортировка, для каждой серии значения по дню через  `Map`, пропуски — `null` (корректный тултип и линии). Контейнер Apex переименован в `poultry-metrics-chart-container`
  (twig + `analyticsPage.js`). Точки с запятой после `$watch`. Файл компонента переименован в
  `RenderedPoultryMetricsChartData.js`. Нормы падежа для графика: один запрос `poultry_deaths_norm` на все группы периода
  (`DeathsNormByStage::indexedNormRowsByGroupIdAndStage`), подбор стадии по дню без N запросов. PHPDoc у  `CalculatedPoultryChartDeviationPercent::percent`.
- **Файлы:** `public/js/page/analytics/poultry/analyticsPage.js`,
  `public/js/component/analytics/poultry/RenderedPoultryMetricsChartData.js` (удалён `MetricsChartData.js`),
  `templates/analytics/poultry/_metrics-graph.html.twig`, `templates/analytics/poultry/analytics.html.twig`,
  `src/Module/PoultryGroup/Database/DeathsNormByStage.php`,
  `src/Module/Analytics/Poultry/PreparedPoultryMortalityChartSeries.php`,
  `src/Module/Analytics/Poultry/CalculatedPoultryChartDeviationPercent.php`,
  `.cursor/rules/frontend-architecture.mdc`,   `.cursor/skills/analytics-page/SKILL.md`,
  `.cursor/skills/analytics-page/references/poultry.md`,
  `tests/Unit/Module/Analytics/Poultry/PreparedPoultryMortalityChartSeriesTest.php`.

---

## 2026-04-15: Analytics POULTRY — фикс режима цветов метрик + маркеры

- **Суть:** режим цвета серий/тултипа переведён на критерий UI (`checkedPoultryRoomIds.length`), а не по набору
  `building_id` в payload (из-за этого раньше часто оставался «корпусный» режим и визуально было 1-2 цвета). Цвет
  метрик — стабильный через фиксированную палитру `METRIC_COLORS` + hash по `metric.code`. Добавлен глобальный helper
  `window.metricColorByCode` и метод `metricColorByCode` в Alpine. Для 4 текущих кодов метрик добавлена явная карта
  `METRIC_FIXED_COLORS` без коллизий (`mortality`, `egg_production`, `feed_consumption`, `water_consumption`), hash
  оставлен fallback для будущих кодов. В `sidebar/_metrics-check.html.twig` добавлен маркер `colored-circle` для
  каждой метрики.
- **Файлы:** `public/js/component/analytics/poultry/MetricsChartData.js`,
  `public/js/page/analytics/poultry/analyticsPage.js`,
  `templates/analytics/poultry/sidebar/_metrics-check.html.twig`,
  `.cursor/skills/analytics-page/references/poultry.md`.

---

## 2026-04-15: Analytics POULTRY — цветовые режимы по метрике/корпусу

- **Суть:** в `MetricsChartData.js` добавлены два цветовых режима: при одном выбранном зале/корпусе цвет серии и строки
  тултипа берётся из стабильного псевдослучайного `metricColorByCode(metric.code)`, при нескольких — из
  `roomColorById(building_id)`. Для строк тултипа выбран вариант B: цветной текст строки (`metric + series + details`).
- **Файлы:** `public/js/component/analytics/poultry/MetricsChartData.js`,
  `.cursor/skills/analytics-page/references/poultry.md`.

---

## 2026-04-15: Analytics POULTRY — параллельная загрузка графиков, один render

- **Суть:** `loadMetricsCharts`: `Promise.all` только по `codesToFetch` (при неизменном периоде/залах — догрузка новых метрик
  без повторного запроса уже кэшированных); один `renderPoultryMergedMetricsChart` после ответов; нет промежуточного `render` и
  обнуления payload до ответов (инстанс Apex не сбрасывался между метриками). Prune снятых метрик + render без API.
  `_poultryChartLoadSeq` против гонок. Apex: `animations.enabled: false` в `MetricsChartData.js`.
- **Файлы:** `public/js/page/analytics/poultry/analyticsPage.js`, `public/js/component/analytics/poultry/MetricsChartData.js`.

---

## 2026-04-15: Analytics POULTRY — тултип Apex, updateOptions, сплошные линии

- **Суть:** `RenderedPoultryMetricsChartData`: тултип через `apexcharts-tooltip-custom` и устойчивый `dataPointIndex`
  (`globals.tooltip` / `globals.hover`); контекст для тултипа на `container._poultryMetricsChartTooltipContext` при
  `updateOptions`. При повторном `render` — `updateOptions` без `destroy`; пустые данные — по-прежнему `destroy`.
  Все серии — `stroke.dashArray: 0` (пунктир только у аннотации y=0). Обновлён `references/poultry.md`.
- **Файлы:** `public/js/component/analytics/poultry/MetricsChartData.js`,
  `.cursor/skills/analytics-page/references/poultry.md`.

---

## 2026-04-15: Analytics POULTRY — фиксы ревью (тултип, батч норм падежа, ось дат)

- **Суть:** в `RenderedPoultryMetricsChartData` экранирование строк из API в HTML тултипа, подпись метрики + имя корпуса,
  длина строк JS ≤ 120. `PreparedPoultryMortalityChartSeries`: одна пакетная загрузка норм на календарный день через
  `normRowsForGroups`. `analyticsPage.js`: без `console.log`, при merge графиков — проверка совпадения `dates` и усечение
  рядов до общей длины при расхождении. PHPDoc яйценоскости; unit-тест `CalculatedPoultryChartDeviationPercent` для `fact === null`.
- **Файлы:** `public/js/component/analytics/poultry/MetricsChartData.js`, `public/js/page/analytics/poultry/analyticsPage.js`,
  `src/Module/Analytics/Poultry/PreparedPoultryMortalityChartSeries.php`, `PreparedPoultryEggProductionChartSeries.php`,
  `tests/Unit/Module/Analytics/Poultry/PreparedPoultryMortalityChartSeriesTest.php`,
  `CalculatedPoultryChartDeviationPercentTest.php`, `.cursor/plans/2026-04-15-14-30-poultry-analytics-chart-norms-deviation.md`.
- **Тесты:** `docker exec … php bin/phpunit` — OK (1501 тест).

---

## 2026-04-15: Analytics POULTRY — нормы и отклонение % в *-chart, единый график

- **Суть:** расширены ответы `GET .../mortality-chart`, `egg-production-chart`, `feed-consumption-chart`,
  `water-consumption-chart`: в `series[].data[]` объекты `fact`, `norm`, `deviation_percent` (и для яиц `fact_quantity`); отклонение считается на бэкенде. Падёж: факт и норма в головах/сутки, норма — доля от `poultry_deaths_norm` × поголовье на начало дня. Яйца: `fact` в % лэйинга, план батчем `EggProductionPlanPercent`.
  Корм/вода: нормы через `PoultryAnalyticsNormDailyTotals` по UTC-дню. Фронт: `poultryChartPayloadsByMetric`, merge в
  `RenderedPoultryMetricsChartData` (ApexCharts, Y = отклонение %, y=0 пунктир, `roomColorById`, кастомный тултип).
- **Файлы:** `CalculatedPoultryChartDeviationPercent.php`, `PoultryAnalyticsNormDailyTotals.php`,
  `PreparedPoultryMortalityChartSeries.php`, `PreparedPoultryEggProductionChartSeries.php`,
  `PreparedPoultryFeedConsumptionChartSeries.php`, `PreparedPoultryWaterConsumptionChartSeries.php`,
  `CalculatedPoultryChartDeviationPercentTest.php`, `PreparedPoultry*ChartSeriesTest.php`,
  `public/js/component/analytics/poultry/MetricsChartData.js`, `public/js/page/analytics/poultry/analyticsPage.js`,
  `public/js/api/analytics/poultry/LoadedPoultry*ChartData.js`, `.cursor/skills/analytics-page/references/poultry.md`,
  `.cursor/skills/analytics-page/SKILL.md`, `.cursor/rules/frontend-architecture.mdc`,
  `.cursor/plans/2026-04-15-14-30-poultry-analytics-chart-norms-deviation.md`.
- **Тесты:** `docker exec … php bin/phpunit` — OK (1500 тестов).

---

## 2026-04-15: Analytics POULTRY — query графиков из сайдбара (период, залы)

- **Суть:** `analyticsPage.js` собирает `resolvedPoultryChartRequestParams()` (`period`, `building_id=all`, `roomIds` из
  `checkedPoultryRoomIds`) и передаёт в `LoadedPoultry*ChartData.load(...)`; перед пакетом — `console.log` с фильтрами и кодами
  метрик. Поведение API без изменений.
- **Файлы:** `public/js/page/analytics/poultry/analyticsPage.js`, `.cursor/skills/analytics-page/references/poultry.md`.

---

## 2026-04-15: Analytics POULTRY — метрики без выбора по умолчанию

- **Суть:** при загрузке `available-metrics` больше не заполняется `checkedPoultryMetricCodes`: чекбоксы пустые, запросы
  графиков идут только после выбора метрик пользователем.
- **Файлы:** `public/js/page/analytics/poultry/analyticsPage.js`.

---

## 2026-04-15: Analytics POULTRY — чекбоксы метрик в сайдбаре

- **Суть:** в `sidebar/_metrics-check.html.twig` список метрик из API с чекбоксами (как у корпусов): `x-model` на
  `checkedPoultryMetricCodes`, подпись `metric.label`, значение `metric.code`. В `analyticsPage.js` — состояние
  `poultryAvailableMetrics` / `checkedPoultryMetricCodes`; `loadPoultryAvailableMetrics` вызывается сразу после корпусов.
- **Файлы:** `templates/analytics/poultry/sidebar/_metrics-check.html.twig`, `public/js/page/analytics/poultry/analyticsPage.js`.

---

## 2026-04-15: Analytics POULTRY — каталог доступных метрик и GET available-metrics

- **Суть:** единый backend-каталог метаданных графиков (`DeclaredPoultryAnalyticsChartMetrics`: `code`, `label`, `unit`,
  `endpoint`, `enabled`, `sort`) без дублирования расчётов. Новый **`GET /api/analytics/poultry/available-metrics`** —
  envelope `{ status, data: { metrics } }`, в `metrics` только включённые записи, сортировка по `sort`. Контракты
  существующих `*-chart` и dashboard не менялись.
- **Файлы:** `DeclaredPoultryAnalyticsChartMetrics.php`, `PoultryAnalyticsAvailableMetricsController.php`,
  `DeclaredPoultryAnalyticsChartMetricsTest.php`, `ModuleAccessSubscriberAnalyticsTest.php` (guard),
  `.cursor/skills/analytics-page/references/poultry.md`, `.cursor/skills/analytics-page/SKILL.md`.
- **Тесты:** в контейнере `php bin/phpunit` — OK (1495 тестов).

---

## 2026-04-15: Analytics POULTRY — заготовка нового JS для единого графика

- **Суть:** удалён старый рендер `MortalityChartData.js`; добавлен пустой каркас `MetricsChartData.js` для будущей
  отрисовки единого графика выбранных метрик по корпусам.
- **Подключение:** в `templates/analytics/poultry/analytics.html.twig` скрипт переключён на
  `/js/component/analytics/poultry/MetricsChartData.js`, в `analyticsPage.js` вызов рендера переведён на
  `RenderedPoultryMetricsChartData`.
- **Статус:** в новом файле есть только базовая структура класса и метод `render(...)` без реализации логики.
- **Файлы:** удалён `public/js/component/analytics/poultry/MortalityChartData.js`, добавлен
  `public/js/component/analytics/poultry/MetricsChartData.js`, изменены
  `templates/analytics/poultry/analytics.html.twig`, `public/js/page/analytics/poultry/analyticsPage.js`.

---

## 2026-04-15: Analytics POULTRY — пакетная загрузка групп для графиков mortality/egg, лог health

- **Суть:** убран N+1 `poultryGroupByBuildingAtDate` в `PreparedPoultryMortalityChartSeries` и `PreparedPoultryEggProductionChartSeries`:
  один вызов `PoultryGroup::groupsByBuildingsForPeriod`, выбор группы на день в памяти через `ResolvedGroupOnChartDay`
  (семантика как SQL: последняя по `start_date` среди пересекающихся периодов). В `task_logs` у старой записи про удаление
  `health` добавлена актуализация — endpoint снова в проекте.
- **Файлы:** `ResolvedGroupOnChartDay.php`, `PreparedPoultryMortalityChartSeries.php`, `PreparedPoultryEggProductionChartSeries.php`,
  `ResolvedGroupOnChartDayTest.php`, правки `PreparedPoultryMortalityChartSeriesTest.php`, `PreparedPoultryEggProductionChartSeriesTest.php`,
  `task_logs.md`, `.cursor/skills/analytics-page/references/poultry.md`, `SKILL.md`.
- **Тесты:** `php bin/phpunit` в контейнере — OK (1492 теста).

---

## 2026-04-15: Analytics POULTRY — reviewer: health, фильтры room_scope, тесты, доки

- **Суть:** восстановлен `GET /api/analytics/poultry/health` (каркас `items: []`). Конфликт query `room_scope=selected` +
  числовой `building_id` → **400**; в ответе графиков при selected в `filters.building_id` всегда `"all"`. Добавлены unit-тесты
  `PoultryAnalyticsChartFilterPolicyTest`, пустой `room_ids` для egg/feed/water сервисов. В `poultry.md` уточнены **404** vs `dashboard-metrics` и совместность фильтров. Класс `PoultryAnalyticsChartFilterPolicy`.
- **Файлы:** `PoultryAnalyticsHealthController.php`, `PoultryAnalyticsChartFilterPolicy.php`, правки четырёх `*ChartController.php`,
  `PreparedPoultryMortalityChartSeries.php` / `PreparedPoultryEggProductionChartSeries.php` (TODO по производительности),
  тесты в `tests/Unit/Module/Analytics/Poultry/`, `.cursor/skills/analytics-page/references/poultry.md`, `SKILL.md`.
- **Тесты в контейнере:** `php bin/phpunit` — OK (1486 тестов).

---

## 2026-04-15: Analytics POULTRY — графики метрик: суточные ряды и отдельные API

- **Суть:** `mortality-chart` переведён на **суточный** падеж (голов/сутки), не накопительный. Добавлены  `GET /api/analytics/poultry/egg-production-chart`, `.../feed-consumption-chart`, `.../water-consumption-chart`
  с теми же фильтрами (`period`, `building_id`, `room_scope`, `room_ids`). Ответы: envelope + `data` с полями
  `filters`, `metric`, `unit`, `dates`, `series` (суточные `data` по дням). Корм/вода: сумма факта по корпусу и дню UTC
  (полдень локальной даты точки), яйца — `whole` из `eggs_list`, падеж — `death_list` за день.
- **Тесты:** обновлён `PreparedPoultryMortalityChartSeriesTest`; добавлены
  `PreparedPoultryEggProductionChartSeriesTest`, `PoultryAnalyticsFactDailyTotalsTest`,
  `PreparedPoultryFeedConsumptionChartSeriesTest`, `PreparedPoultryWaterConsumptionChartSeriesTest`.
  В контейнере: `php bin/phpunit` — OK (1478 тестов).
- **Документация:** `.cursor/skills/analytics-page/references/poultry.md`, `SKILL.md`.
- **Файлы:** `PreparedPoultryMortalityChartSeries.php`, `PoultryAnalyticsFactDailyTotals.php`,
  `PreparedPoultryEggProductionChartSeries.php`, `PreparedPoultryFeedConsumptionChartSeries.php`,
  `PreparedPoultryWaterConsumptionChartSeries.php`, `PoultryAnalyticsChartRequestTrait.php`,
  `PoultryAnalyticsMortalityChartController.php`, `PoultryAnalyticsEggProductionChartController.php`,
  `PoultryAnalyticsFeedConsumptionChartController.php`, `PoultryAnalyticsWaterConsumptionChartController.php`,
  тесты в `tests/Unit/Module/Analytics/Poultry/`.

---

## 2026-04-15: Analytics POULTRY — удалён лишний каркасный endpoint health

> **Актуализация (2026-04-15):** endpoint `GET /api/analytics/poultry/health` **восстановлен** и снова поддерживается
> (см. запись «reviewer: health, фильтры room_scope…»). Ниже — история промежуточного решения об удалении.

- **Суть:** после добавления агрегирующего `GET /api/analytics/poultry/dashboard-metrics` удалён неиспользуемый
  каркасный `GET /api/analytics/poultry/health` (`items: []`), чтобы не держать дублирующий/пустой endpoint.
- **Guard-тест:** `ModuleAccessSubscriberAnalyticsTest` переведён с `/api/analytics/poultry/health` на
  `/api/analytics/poultry/dashboard-metrics` в сценариях allow/deny.
- **Документация:** обновлены `.cursor/skills/analytics-page/references/poultry.md` и `SKILL.md`
  (актуальный список POULTRY analytics API).
- **Файлы:** удалён `src/Controller/Analytics/Poultry/PoultryAnalyticsHealthController.php`,
  изменены `tests/Integration/EventSubscriber/ModuleAccessSubscriberAnalyticsTest.php`,
  `.cursor/skills/analytics-page/references/poultry.md`,
  `.cursor/skills/analytics-page/SKILL.md`.

---

## 2026-04-15: Analytics POULTRY — единый API всех метрик dashboard

- **Суть:** добавлен `GET /api/analytics/poultry/dashboard-metrics`, который отдаёт одним ответом данные всех блоков
  dashboard птицы для текущей даты пользователя (`TimezoneProvider`): `critical_alerts`, `mortality`, `egg_production`,
  `feed_consumption`, `water_consumption`, `cull`, `moba_sorting`.
- **Контракт:** `data.user_date`, `data.generated_at`, `data.metrics.*`; формат каждого блока внутри `metrics`
  совпадает с существующими `GET /api/dashboard/poultry/*`.
- **Документация:** обновлён референс `.cursor/skills/analytics-page/references/poultry.md` с новым endpoint.
- **Файлы:** `src/Controller/Analytics/Poultry/PoultryAnalyticsDashboardMetricsController.php`,
  `.cursor/skills/analytics-page/references/poultry.md`.

---

## 2026-04-15: Analytics POULTRY — график падежа в головах (вместо %)

- **Суть (история):** переход с процентов от `start_count` к значениям в головах на графике. **Актуальный контракт графика:**
  суточный падеж (`heads/day`), см. свежие записи про `mortality-chart` выше.
- **Тесты (на тот этап):** обновлён `PreparedPoultryMortalityChartSeriesTest` под отказ от `percent`.
- **Документация:** референс analytics poultry.
- **Файлы:** `PreparedPoultryMortalityChartSeries.php`, `public/js/component/analytics/poultry/MortalityChartData.js`,
  `PreparedPoultryMortalityChartSeriesTest.php`, `references/poultry.md`.

---

## 2026-04-14: Analytics POULTRY — mortality-chart: room_scope, пустой выбор, перезапрос по UI

- **Суть:** `room_scope=selected` и `room_ids[]`; при пустом `room_ids` — `series: []`, оси `dates` как при полном периоде.
  Невалидный id при непустом списке → **404**. Фронт: параметры в `RefreshedPoultryMortalityChartData.load`, Alpine  `selectedPeriod` + `$watch` на чекбоксы и период, лог `mortality-chart refresh`. Селект7/14/30/90 в сайдбаре, стили селекта.
- **Файлы:** `PreparedPoultryMortalityChartSeries.php`, `PoultryAnalyticsMortalityChartController.php`,
  `PreparedPoultryMortalityChartSeriesTest.php`, `RefreshedPoultryMortalityChartData.js`, `analyticsPage.js`,
  `templates/analytics/poultry/sidebar/_period.html.twig`, `assets/scss/pages/analytics-poultry.scss`,
  `.cursor/skills/analytics-page/references/poultry.md`.

---

## 2026-04-14: Analytics POULTRY — график падежа: ряды из death_list (накопительный %)

- **Суть:** `PreparedPoultryMortalityChartSeries` строит `dates` и `series` для
  `GET /api/analytics/poultry/mortality-chart`: по каждому дню и корпусу — группа
  `poultryGroupByBuildingAtDate`, накопительная сумма падежа по ключам `death_list` с датой ≤ дня графика,
  процент от `start_count` (округление до 2 знаков); корпуса и имена из `Buildings::buildings()`, диапазон дат —
  TZ пользователя (`TimezoneProvider`). Контроллер мерджит `chartPayload` с `filters`.
- **Тесты:** `tests/Unit/Module/Analytics/Poultry/PreparedPoultryMortalityChartSeriesTest.php`.
- **Файлы:** `src/Module/Analytics/Poultry/PreparedPoultryMortalityChartSeries.php`,
  `src/Controller/Analytics/Poultry/PoultryAnalyticsMortalityChartController.php`,
  `.cursor/skills/analytics-page/SKILL.md`, `.cursor/skills/analytics-page/references/poultry.md`.

---

## 2026-04-14: Analytics POULTRY — маршрут графика падежа (JSON-заглушка)

- **Суть:** добавлен `GET /api/analytics/poultry/mortality-chart` с разбором `period` и `building_id` как у `health`;
  ответ `data`: `filters`, `dates`, `series` (пока пустые ряды — под будущую SQL-агрегацию по дням).
  `RefreshedPoultryMortalityChartData.js` нормализует объект `data`, а не только массив.
- **Файлы:** `src/Controller/Analytics/Poultry/PoultryAnalyticsMortalityChartController.php`,
  `public/js/api/analytics/poultry/RefreshedPoultryMortalityChartData.js`.

---

## 2026-04-14: Analytics POULTRY — сайдбар (Alpine), выбор залов, актуализация docs

- **Суть:** `analytics.html.twig` — корень `x-data="analyticsPoultry()"` без дубля `x-init` (загрузка в `init()` компонента);
  сайдбар — `templates/analytics/poultry/sidebar/*`, виджет списка залов: `x-model="checkedPoultryRoomIds"` + `:value="room.id"`,
  клик по строке через обёртывающий `<label>`, подпись в `<span>` (не `x-text` на `label` с вложенным `input`);
  `roomColorById` в `public/js/page/analytics/poultry/utils/roomColor.js`; API `LoadedPoultryBuildings` и утилита — IIFE, экспорт на
  `window`; стили — `assets/scss/pages/analytics-poultry.scss` → `/build/pages/analytics-poultry.css` (`npm run build:css`).
- **Документация:** `.cursor/skills/analytics-page/SKILL.md`, `references/poultry.md`, `frontend-architecture.mdc`,
  `backend-architecture.mdc`, `animal-type-switching.mdc`.
- **Файлы:** `public/js/page/analytics/poultry/analyticsPage.js`, `public/js/api/analytics/poultry/LoadedPoultryBuildings.js`,
  `public/js/page/analytics/poultry/utils/roomColor.js`, `templates/analytics/poultry/analytics.html.twig`,
  `templates/analytics/poultry/sidebar/*`, `assets/scss/pages/analytics-poultry.scss`.

---

## 2026-04-14: Analytics POULTRY — список площадок с залами одним запросом

- **Суть:** добавлен `GET /api/analytics/poultry/buildings` для фронтенд-фильтров analytics (возвращает
  `data: [{ id, name, rooms: [{ id, name }] }]`), чтобы получать площадки и вложенные залы в одном ответе.
- **Фронт:** `LoadedPoultryBuildings` переведён на новый analytics endpoint; в `analyticsPage.js` — заполнение
  `poultryBuildings` / `poultryBuildingsError`; сайдбар — `templates/analytics/poultry/sidebar/*`, список залов через Alpine `x-for`.
- **Файлы:** `src/Controller/Analytics/Poultry/PoultryAnalyticsBuildingsController.php`,
  `public/js/api/analytics/poultry/LoadedPoultryBuildings.js`,
  `public/js/page/analytics/poultry/analyticsPage.js`,
  `templates/analytics/poultry/analytics.html.twig`,
  `templates/analytics/poultry/sidebar/sidebar.html.twig`.

---

## 2026-04-14: Аналитика — доработки по reviewer (guard, тесты, todo)

- **Суть:** синхронизация `todo.md` с выполненной задачей по плану analytics; guard для `/api/analytics/poultry*` — только точный сегмент
  `poultry` или `poultry/…`, иначе 404 (не попадание в ветку PORK для путей вида `/api/analytics/poultry-extra`); интеграционные тесты:
  `expectNotToPerformAssertions()` вместо искусственного счётчика ассертов; кейсы при выключенном `ANALYTICS`; тест невалидного сегмента
  после `poultry`.
- **Файлы:** `todo.md`, `src/EventSubscriber/ModuleAccessSubscriber.php`,
  `tests/Integration/EventSubscriber/ModuleAccessSubscriberAnalyticsTest.php`, `.cursor/rules/animal-type-switching.mdc`,
  `.cursor/plans/2026-04-14-15-00-analytics-pork-poultry-dispatcher.md`.

---

## 2026-04-14: Аналитика — диспетчер PORK/POULTRY, guard, каркас API POULTRY

- **Суть:** `GET /analytics` в main app (`AnalyticsPageController`) — forward на `/analytics/pork-page` (бандл, прежний Twig/логика)
  или `/analytics/poultry-page` (заглушка). Старые `GET /api/analytics/*` без `poultry` — только PORK+ANALYTICS; новый префикс
  `GET /api/analytics/poultry/*` — POULTRY+ANALYTICS; каркас `ParsedPoultryAnalyticsFilters` + `GET .../poultry/health`.
- **Guard:** `ModuleAccessSubscriber` — убраны `/analytics` и `/api/analytics` из `URL_PORK_MODULE_MAP`; отдельные проверки как у
  dashboard/table. Sidenav: пункт «Аналитика» при `ANALYTICS` и (PORK или POULTRY).
- **Документация:** `.cursor/skills/analytics-page/SKILL.md`, `references/pork.md`, `references/poultry.md`;
  `animal-type-switching.mdc`, `backend-architecture.mdc`, `general-rules.mdc`.
- **Тесты:** `tests/Unit/Module/Analytics/Poultry/ParsedPoultryAnalyticsFiltersTest.php`,
  `tests/Integration/EventSubscriber/ModuleAccessSubscriberAnalyticsTest.php`; полный `php vendor/bin/phpunit` в контейнере — OK.
- **Файлы:** `config/routes.yaml`, `config/routes/analytics_group.php`, `src/Controller/Analytics/**`,
  `src/Module/Analytics/Poultry/ParsedPoultryAnalyticsFilters.php`, `packages/analytics-bundle/src/Controller/AnalyticsPageController.php`,
  `src/EventSubscriber/ModuleAccessSubscriber.php`, `templates/components/blocks/sidenav.html.twig`,
  `templates/analytics/poultry/analytics_stub.html.twig`.

---

## 2026-04-13: Фикстуры — расширенный список демо-оповещений animal_alert

- **Суть:** в `AnimalAlertFixtures` вместо пяти однотипных записей создаётся 15 оповещений с разными заголовками и
  текстами (чередование critical/warning); группы назначаются по кругу из всех строк `poultry_group`.
- **Файл:** `src/DataFixtures/AnimalAlertFixtures.php`.

---

## 2026-04-13: Dashboard POULTRY — модалка критического оповещения

- **Суть:** по кнопке «Детали» в списке оповещений открывается оверлей с полным текстом (статус, корпус, дата/время,
  описание); закрытие — крестик, клик по фону, Escape; блокировка `overflow` у `body` на время открытия.
- **JS:** `Alpine.store('criticalAlertModal')` в `public/js/page/dashboard/poultry/criticalAlertModal.js` (регистрация в
  `alpine:init`); в `dashboardPagePoultry.js` — поля `id`, `status_label` в элементах списка, ключ `x-for` по `id`.
- **Верстка/стили:** `templates/dashboard/poultry/_critical_alerts_modal.html.twig`, кнопка в  `_critical_alerts_card.html.twig`; `assets/scss/modals/_critical-alerts-modal.scss` подключён в `dashboard.scss` через
  `@use`; порядок скриптов: `criticalAlertModal.js` перед `dashboardPagePoultry.js`.
- **Сборка:** `npm run build:css` (в т.ч. `public/build/pages/dashboard.css`).
- **Документация:** `.cursor/rules/frontend-architecture.mdc` — упоминание store и модалки.

---

## 2026-04-09: Dashboard POULTRY — редизайн карточек и план яйценоскости из БД (дочистка)

- **Яйценоскость:** убран хардкод `92%`; блок `GET /api/dashboard/poultry/egg-production` использует
  `plan_percent` из `poultry_egg_production_plan` (через `EggProductionPlanPercent` и `AggregatedEggProduction`),
  включая `byBuilding[].plan_percent` и `total.plan_percent` (взвешенное среднее по поголовью при наличии плана).
- **Верстка dashboard:** карточки `egg/feed/water/cull` переведены в единый каркас как у `mortality`
  (`dashboard-card__header-left/right`, `dashboard-card__total`, list-строки), исправлены KPI-подписи и fallback для
  отсутствующего плана (`план —`).
- **CSS и регрессии:** восстановлены/добавлены стили для `dashboard-muted`, `dashboard-card__error`, MOBA-таблицы
  и фильтра (`dashboard-card__header--row`, `__filter`, `__select`), alert-элементов и адаптива сетки.
- **Критические оповещения:** возвращено отображение заголовка оповещения (`a.title`) в `_critical_alerts_card`.
- **Фикстуры:** добавлен `PoultryEggProductionPlanFixtures`; для порядка загрузки — зависимость от
  `PoultryGroupFixtures` (`DependentFixtureInterface`), при пустых группах — мягкий `return` без падения загрузки.
- **Тесты/проверки:** `AggregatedEggProductionTest` расширен (в т.ч. кейсы `null` vs `0%` и смешанный план/без плана),
  прогон в контейнере `vet_php-fpm-vet` — OK (9); линтер по изменённым файлам — без ошибок.
- **Изменённые файлы:** `templates/dashboard/poultry/_*.twig`, `assets/scss/pages/dashboard.scss`,
  `public/js/page/dashboard/poultry/dashboardPagePoultry.js`,
  `src/Module/PoultryGroup/Database/{AggregatedEggProduction,EggProductionPlanPercent}.php`,
  `tests/Unit/Module/PoultryGroup/Database/AggregatedEggProductionTest.php`,
  `src/DataFixtures/Poultry/PoultryEggProductionPlanFixtures.php`,
  `migrations/Version20260409120000.php`,
  `.cursor/rules/{db-schema,fixtures-rules}.mdc`,
  `.cursor/skills/dashboard-page/{SKILL.md,references/poultry.md}`.

---

## 2026-04-09: План яйценоскости из БД (`poultry_egg_production_plan`)

- **Суть**: таблица `poultry_egg_production_plan` (1:1 с `poultry_group`, FK CASCADE, CHECK 0–100, UNIQUE по группе); чтение планов `EggProductionPlanPercent::percentByGroupIds`; `AggregatedEggProduction` добавляет `plan_percent` в строки и взвешенный `total.plan_percent` (только строки с планом в БД; при сумме поголовья 0 по таким строкам — `null`; `0%` в БД ≠ отсутствие строки). UI: `_egg_production_card.html.twig`, `dashboardPagePoultry.js` — без хардкода 92%.
- **Файлы**: `migrations/Version20260409120000.php`, `src/Module/PoultryGroup/Database/EggProductionPlanPercent.php`, `AggregatedEggProduction.php`, `tests/Unit/Module/PoultryGroup/Database/AggregatedEggProductionTest.php`, `templates/dashboard/poultry/_egg_production_card.html.twig`, `public/js/page/dashboard/poultry/dashboardPagePoultry.js`, `public/js/api/dashboard/poultry/LoadedEggProductionData.js`, `.cursor/rules/db-schema.mdc`, `.cursor/skills/dashboard-page/SKILL.md`, `references/poultry.md`, план `.cursor/plans/2026-04-08-egg-production-plan-percent.md`.
- **Тесты**: `docker exec … php vendor/bin/phpunit tests/Unit/Module/PoultryGroup/Database/` — OK (45).

---

## 2026-04-08: План — плановый % яйценоскости (FK `poultry_group_id`)

- **Суть**: подготовлен артефакт плана (без реализации фичи): хранение плана яйценоскости в отдельной таблице с FK на `poultry_group.id`, расширение ответа `GET /api/dashboard/poultry/egg-production` полями `plan_percent`, снятие хардкода `92%` в UI; тест-план, риски, rollback, готовый промпт для worker.
- **Файл плана**: `.cursor/plans/2026-04-08-egg-production-plan-percent.md`

---

## 2026-04-06: Итог по задаче Dashboard `/dashboard` (update-rules, ветка)

Сводка после закрытия задачи; детализация по этапам и итерациям — в записях ниже за 2026-04-06.

- **Суть**: `GET /dashboard` (диспетчер PORK/POULTRY), модуль `DASHBOARD` в `module_config`, guard и sidenav; POULTRY — семь асинхронных блоков и `GET /api/dashboard/poultry/*`; PORK — заглушка. Структура `eggs_list` / `whole` с сортами, `PoultryEggsEnum`, модалка «Яйца» на `/table`, скилл `.cursor/skills/dashboard-page/SKILL.md` и `references/poultry.md`.
- **Документация**: `db-schema.mdc`, `animal-type-switching.mdc`, `backend-architecture.mdc`, `frontend-architecture.mdc`, `date-timezone-flow.mdc`, `general-rules.mdc` (ссылка на skill); план `.cursor/plans/2026-04-06-16-20-dashboard-page.md`.
- **Код (ориентиры)**: `src/Controller/Dashboard/**`, `config/routes/dashboard_group.php`, `migrations/Version20260406162000.php`, `ModuleAccessSubscriber`, `templates/dashboard/**`, `public/js/page/dashboard/**`, `public/js/api/dashboard/**`, `assets/scss/pages/dashboard.scss`, SQL `Aggregated*`, `MobaSortingByGrade`, `NormalizedEggsWhole`, `AnimalAlerts`, правки `SavedPoultryEggsDay` и таблицы птиц.
- **Тесты**: unit по агрегациям, MOBA, яйцам, оповещениям; прогон в контейнере `vet_php-fpm-vet` — см. записи ниже.

---

## 2026-04-06: Dashboard — правки reviewer R1–R6 (MOBA, дата, корпуса, стадия, json_encode)

- **R1 MOBA**: `NormalizedEggsWhole::countAndWeightedAvgPartsByGrade`, `MobaSortingByGrade` отдаёт `avg_weight_g`, `weight_kg` по сорту и `total_weight_kg` / `avg_weight_g` в корне; `dashboardPagePoultry.js` без хардкода весов.
- **R2**: `PoultryDashboardPageController` + `user_date` в `dashboard.html.twig` (timezone из cookie).
- **R3**: `AggregatedEggProduction`, `AggregatedCull` — обход всех корпусов как в `AggregatedMortality`.
- **R4**: `DeathsNormByStage::determineStage` — `null`, если `start_date` позже опорной даты.
- **R5**: `AggregatedEggProduction::currentLivestock` — максимальный ключ даты в `livestock_list`.
- **R6**: `SavedPoultryEggsDay::save` — проверка `json_encode`.
- Тесты: `MobaSortingByGradeTest`, `NormalizedEggsWholeTest`, `AggregatedEggProductionTest`, `AggregatedCullTest`.
- Документация: `.cursor/skills/dashboard-page/SKILL.md`, `references/poultry.md`.
- Прогон: `docker exec … php bin/phpunit tests/Unit` — OK (1427).

---

## 2026-04-06: Dashboard — fmtNum для корма и воды (reviewer)

- Карточки `_feed_consumption_card.html.twig`, `_water_consumption_card.html.twig`: вместо `fmtInt` для факта/нормы
  и единообразно для отклонения — `fmtNum(..., 3)` (как округление в SQL-агрегатах).
- Документация: `.cursor/skills/dashboard-page/SKILL.md`.

---

## 2026-04-06: Dashboard POULTRY — данные без HTML-строк в JS

- Убрана сборка HTML в `dashboardPagePoultry.js` (`render*` / `x-html`); ответы API разбираются в массивы/поля,
  шаблоны — в `templates/dashboard/poultry/_*_card.html.twig` (Alpine `x-for`, `x-text`, `:class`, `x-show`).
- Стили: класс контента карточки `dashboard-card__content` вместо `dashboard-card__html` в `assets/scss/pages/dashboard.scss`;
  пересобран `public/build/pages/dashboard.css` (`npm run build:css`).
- Удалена отладочная задержка 2 с в загрузке критических оповещений.
- Документация: `frontend-architecture.mdc`, `.cursor/skills/dashboard-page/SKILL.md`.
- Проверки: `npm run build:css` — OK; `make test` — падает (CRLF в `bin/phpunit-clean`, как в логе);
  `docker exec … php vendor/bin/phpunit tests/Unit/Module/PoultryGroup/Database/` — OK (36);
  `tests/Unit/Module/AnimalAlert` — OK (2).

---

## 2026-04-06: Dashboard — правки по замечаниям reviewer

- `SavedPoultryEggsDay`: слияние `whole` по слоту сорта (не затирать MOBA); тест `testSaveMergesByGradeKeepsOtherGrades`.
- `AggregatedFeedConsumption` / `AggregatedWaterConsumption`: день для SQL — календарный UTC от того же instant, что `userToday`.
- `AggregatedMortality`: все корпуса из audit, без группы — нули.
- `migrations/Version20260406162000.php`: убран `final`.
- `PoultryEggsEnum`: `uiLabel()` вместо static `labels()`/`values()`; `TablePageController` собирает `egg_grades`.
- `NormalizedEggsWhole`: методы экземпляра; вызовы в `AggregatedEggProduction`, `MobaSortingByGrade`, `PoultryTableData`.
- `AbstractPoultryDashboardApiController` + 7 API-контроллеров: `LoggerInterface`, лог при 500.
- Unit-тесты: `AggregatedFeedConsumptionTest`, `AggregatedWaterConsumptionTest`, `AggregatedMortalityTest`, `AggregatedEggProductionTest`, `AggregatedCullTest`, `MobaSortingByGradeTest`, `AnimalAlertsTest`; обновлены `NormalizedEggsWholeTest`, `PoultryEggsEnumTest`, `SavedPoultryEggsDayTest`.
- Документация: `db-schema.mdc`, `general-rules.mdc`, `date-timezone-flow.mdc`, `dashboard-page` skill + `references/poultry.md`, `table-page/SKILL.md`; план `.cursor/plans/2026-04-06-16-20-dashboard-page.md`.
- Тесты: `docker exec … php vendor/bin/phpunit` — OK (1446). `make test` локально падает из-за CRLF в `bin/phpunit-clean` (без изменений).

---

## 2026-04-06: Страница Dashboard `/dashboard` (POULTRY)

- Реализован дашборд с агрегированной аналитикой по всем корпусам птицефабрики: 7 блоков (оповещения, падеж, яйценоскость, корм, вода, бой/насечка, MOBA), async-подгрузка (skeleton → REST), стили `assets/scss/pages/dashboard.scss`.
- Модуль **DASHBOARD**: миграция `migrations/Version20260406162000.php`, `ModuleCodeEnum::DASHBOARD`, guard в `ModuleAccessSubscriber`, ссылка в `templates/components/blocks/sidenav.html.twig`, роуты `config/routes/dashboard_group.php`, исключение `src/Controller/Dashboard/` из общего импорта в `config/routes.yaml`.
- Диспетчер `DashboardPageController`, PORK — `templates/dashboard/pork/dashboard_stub.html.twig`, POULTRY — `templates/dashboard/poultry/*`, JS `public/js/page/dashboard/poultry/dashboardPagePoultry.js`, API-клиенты `public/js/api/dashboard/poultry/Loaded*.js`.
- API: `src/Controller/Dashboard/Poultry/*Controller.php`, envelope JSON; дата «сегодня» — `TimezoneProvider` (cookie `user_timezone`).
- SQL: `AggregatedMortality`, `AggregatedEggProduction`, `AggregatedFeedConsumption`, `AggregatedWaterConsumption`, `AggregatedCull`, `MobaSortingByGrade`, `AnimalAlerts`; нормы падежа — пакетно `DeathsNormByStage::normRowsForGroups`, стадия на дату пользователя в `determineStage($group, $asOfDate)`.
- `eggs_list`: `whole` как массив сортов; `NormalizedEggsWhole`; сохранение из таблицы — `SavedPoultryEggsDay` + select «Сорт» в модалке; `PoultryTableData::applyEggsData`; фикстуры `PoultryGroupFixtures`.
- Тесты: `tests/Unit/Module/PoultryGroup/Database/NormalizedEggsWholeTest.php`, `PoultryEggsEnumTest.php`, правка `SavedPoultryEggsDayTest`; integration-тесты API не добавлены (политика `.cursor/skills/phpunit-tests/SKILL.md`). Прогон: `docker exec … php vendor/bin/phpunit` — OK (1434 теста). Локально `make test` падает из-за CRLF в `bin/phpunit-clean`.
- Документация: `.cursor/rules/db-schema.mdc`, `animal-type-switching.mdc`, `backend-architecture.mdc`, `frontend-architecture.mdc`, `general-rules.mdc`; skill `.cursor/skills/dashboard-page/SKILL.md` + `references/poultry.md`.

План: `.cursor/plans/2026-04-06-16-20-dashboard-page.md`
## 2026-04-15 (редактирование названия партии pork/poultry)

### Задача
Inline-редактирование `pork_group.name` на `/rooms/{id}` (шапка «Партия») и `poultry_group.name` на `/buildings/{id}` (блок «Информация о партии» → «Номер партии»): иконка карандаша, input, отмена/сохранение, PATCH API.

### Сделано
- API: `PATCH /api/rooms/{roomId}/batch-name`, `PATCH /api/buildings/{buildingId}/batch-name`, JSON `{"name":"..."}`; ответ `{status, name}`.
- SQL: `UpdatedPorkGroupBatchName`, `UpdatedPoultryGroupBatchName` (активная группа, валидация 1–60 символов после trim).
- `ModuleAccessSubscriber`: `/api/rooms/*` без `/sensors` → PORK; `/api/rooms/.../sensors` → SENSORS; `/api/buildings/*` → POULTRY.
- Twig: `templates/components/blocks/_editable_batch_name.html.twig`, правки `header.html.twig`, `poultry/building/_dashboard.html.twig`; контроллеры страниц передают `batch_name_api_url` (+ `editable_batch_name` для комнаты).
- JS: `public/js/component/batch_name/EditedBatchName.js`; стили в `assets/scss/app.scss`, сборка `npm run build:css`.
- Документация: `.cursor/rules/frontend-architecture.mdc`, `animal-type-switching.mdc`.

### Файлы
`src/Controller/Pork/RoomBatchNameController.php`, `src/Controller/Poultry/BuildingBatchNameController.php`,
`src/Module/PorkGroup/Database/UpdatedPorkGroupBatchName.php`,
`src/Module/PoultryGroup/Database/UpdatedPoultryGroupBatchName.php`,
`src/EventSubscriber/ModuleAccessSubscriber.php`, `src/Controller/Pork/RoomPageController.php`,
`src/Controller/Poultry/BuildingPageController.php`, `templates/components/blocks/header.html.twig`,
`templates/components/blocks/_editable_batch_name.html.twig`, `templates/poultry/building/_dashboard.html.twig`,
`templates/pork/room/room.html.twig`, `templates/poultry/building/dashboard.html.twig`,
`public/js/component/batch_name/EditedBatchName.js`, `assets/scss/app.scss`, `public/build/app.css` (и прочие page css после сборки).

---

## 2026-04-03 (quality audit + iterate: безопасность контроллера, изоляция бандла)

### Задача
Общая проверка качества реализации задачи `death_list`, передача замечаний в цикл iterate (worker → reviewer).

### Исправления (2 итерации worker + 2 подтверждения reviewer)

**Критичные:**
- `src/Controller/Table/Pork/SavedMortalityCellController.php` — добавлена валидация даты `canonicalDateYmdOrNull`
  (regex + `createFromFormat` с обратной проверкой); невалидная дата → 400 вместо 500.
  `catch (\Throwable)` теперь логирует через `LoggerInterface` и отдаёт «Внутренняя ошибка сервера»
  (без `$e->getMessage()` в ответе). `months` / `monthsForward` читаются из payload (clamped 1–24 / 0–3)
  и передаются в `builtTablePatch` — patch корректно соответствует текущему периоду пользователя.

**Предупреждения:**
- `packages/ametist-excel-parser-bundle/src/DatabaseInsert/PorkGroup/DeathRegistration.php` —
  устранена скрытая связь бандла с `App\Module\JsonList\ListedDeathRecordsForDeathListDay`.
  Логика нормализации bucket вынесена в приватные методы `listedDeathRecordsForDayBucket` /
  `deathDayBucketIsListArray` прямо в классе (изолированный пакет — дублирование допустимо).
  Порядок `use` приведён к PSR-12.

**Рекомендации / code quality:**
- `public/js/page/table/tableCellModalMixin.js` — убраны двойные `.find()` для отгрузки/постановки;
  упрощена инициализация `selectedType` (убрана избыточная ветка `if`).
- `public/js/api/table/SavedMortalityCell.js` + `public/js/page/table/tablePage.js` —
  `tableMonthsBack` / `tableMonthsForward` сохраняются после успешного GET и передаются в PUT.
- PHPDoc у `canonicalDateYmdOrNull` переформулирован с явным глаголом.

**Документация:**
- `.cursor/rules/backend-architecture.mdc` — добавлено явное правило: пакеты в `packages/*`
  не должны импортировать `App\...`.

### Тесты
`php bin/phpunit` в контейнере `vet_php-fpm-vet.*` — OK (1418 тестов, 2660 assertions).

---

## 2026-04-03 (worker: reviewer — изоляция ametist-excel-parser, PHPDoc)

- **DeathRegistration (ametist-excel-parser-bundle):** убрана зависимость от `App\Module\JsonList\ListedDeathRecordsForDeathListDay`;
  нормализация bucket за день — приватные методы `listedDeathRecordsForDayBucket` и `deathDayBucketIsListArray` (та же логика, что в JsonList).
- **SavedMortalityCellController:** PHPDoc у `canonicalDateYmdOrNull` — явная формулировка действия (проверка формата Y-m-d).
- **Проверка:** `php bin/phpunit` в контейнере `vet_php-fpm-vet.*` — OK (1418).

## 2026-04-03 (reviewer: SavedMortalityCell, DeathRegistration, tableCellModalMixin)

- **SavedMortalityCellController:** валидация `date` как `Y-m-d` через `canonicalDateYmdOrNull` (400 при невалидной дате);
  из payload — `months` / `monthsForward` (ограничения как у poultry) для `builtTablePatch`; при необработанной ошибке — лог
  + ответ 500 с «Внутренняя ошибка сервера» (без `getMessage()`). Зависимость: `LoggerInterface`.
- **DeathRegistration (ametist-excel-parser-bundle):** нормализация bucket за день в коде бандла (логика как в App JsonList;
  без зависимости App — см. запись «изоляция ametist-excel-parser»); удалён дублирующий `normalizedDayRecordsList`.
- **Frontend:** `tablePage.js` — `tableMonthsBack` / `tableMonthsForward` после успешного GET (как poultry);
  `SavedMortalityCell.js` и `tableCellModalMixin.saveToApi` передают их в PUT; `openCellModal` — один `find` на тип отгрузки,
  упрощён выбор `selectedType`.
- **Документация:** `.cursor/skills/table-page/references/api-contracts.md`, `pork.md` — контракт PUT mortality.
- **Проверка:** `php bin/phpunit` в контейнере `vet_php-fpm-vet.*` — OK (1418).

## 2026-04-03 (таблица PORK: несколько падежей в модалке и Excel; время history)

- **Причина:** строка `history` для падежа в SQL (`Histories`) агREGирует записи `death_list` через `string_agg` с `;`;
  `overlayFromHistoryRows` подменял весь `padezh` из `death_list` одной «склеенной» записью — модалка и экспорт свиней
  вели себя иначе, чем птицы.
- **Исправление:** если в ячейке уже есть `padezh` из `death_list`, блок падежа из history **не** накладывается;
  оверлей истории по падежу только при пустом `padezh` (fallback для данных только в history). Файл:
  `src/Module/PorkGroup/PageData/TableData.php`.
- **Время записи history при сохранении ячейки:** вместо фиксированного `12:00:00` на дату ячейки используется текущее
  время суток (`Y-m-d` ячейки + `H:i:s` «сейчас»), дата для `created_at::date` совпадает с днём ячейки. Файлы:
  `src/Controller/Table/Pork/SavedMortalityCellController.php`, PHPDoc в `src/Module/History/Database/CreatedHistory.php`.
- **Тесты:** `tests/Unit/Module/PorkGroup/PageData/TableDataOverlayTest.php` — сценарий заполнения из history при пустом
  padezh; сценарий сохранения нескольких записей при наличии mortality в history.
- **Проверка:** `php bin/phpunit` в контейнере `vet_php-fpm-vet.*` — OK (1418).

## 2026-04-03 (death_list — reviewer, третий раунд)

- **SyncMortalityHistoryCommand:** при `deleteMortalityHistoryForDay === false` в ветке prune — `$failed++`, сообщение
  об ошибке, код выхода `FAILURE`; help `--prune-orphan-mortality` и PHPDoc класса выровнены с поведением (ключ даты /
  пустой список, учёт `--dry-run` в help).
- **Тесты:** `SyncMortalityHistoryCommandTest` — `dry-run` + prune не вызывает delete, строка вывода
  `подчистка history (dry-run): …`; неуспешный delete → `FAILURE` и текст «Ошибка удаления history (prune)».
- **JS:** `tablePagePoultryCellModalMixin.js` — JSDoc у `addPoultryMortalityBlock`, у `openCellModal` про
  `mortalityBlocks`, у методов блока падежа — тип `block` как элемент `mortalityBlocks`.
- **Проверка:** `php bin/phpunit` в контейнере `vet_php-fpm-vet.*` — OK (1417). `make test` — падает из‑за CRLF в
  `bin/phpunit-clean` (как в логах).

## 2026-04-03 (death_list — reviewer, второй раунд)

- **SyncMortalityHistoryCommand:** подчистка `--prune-orphan-mortality` сопоставляет календарный день с ключами
  `death_list` так же, как основной цикл sync (`substr` первых 10 символов + `Y-m-d`), метод
  `deathListHasNonEmptyRecordsForCanonicalDate`.
- **Тесты:** `tests/Unit/Command/SyncMortalityHistoryCommandTest.php` — неканонический ключ JSON с записями не даёт
  удалить history; пустой bucket за день — удаление вызывается (мок `porkGroupsWithDeathList` непустой, чтобы команда
  не выходила до блока prune).
- **JS:** `tablePagePoultryCellModalMixin.js` — слиты дублирующие JSDoc перед `poultryMortalityBlock*Input/Paste`.
- **Проверка:** `php bin/phpunit` в контейнере `vet_php-fpm-vet.*` — OK (1415 тестов).

## 2026-04-03 (death_list — правки по reviewer)

- **PHPDoc poultry:** `SavedPoultryCellController` — mortality через обязательный `records`, семантика очистки дня.
- **UI модалки:** удаление последнего блока падежа (pork/poultry JS + Twig); сохранение шлёт `records: []` для полной очистки.
- **Histories:** сумма `count` в LATERAL только при строке из неотрицательных цифр, иначе 0 (защита от битого JSON).
- **Sync mortality:** расширенный PHPDoc класса; опция `--prune-orphan-mortality` (удаление history при отсутствии записей в `death_list` за день); в цикл sync добавлена передача `diagnosis` в агрегат текста.
- **CreatedHistory:** поле `diagnosis` в описании записи; тест `CreatedHistoryTest::testMortalityTitleAndDescriptionFromEntryIncludesDiagnosis`.
- **Poultry вес:** `SavedPoultryMortalityDay::parsedWeightOrNull` с `is_finite`; тест `SavedPoultryMortalityDayTest::testReplaceStoresNullWeightWhenNotFinite`.
- **PorkGroup:** `distinctMortalityHistoryKeys` для подчистки.
- **Документация skills:** `table-page/references/pork.md`, `poultry.md` — очистка дня через пустой `records` / все блоки удалены.
- **Проверка:** `php bin/phpunit` в контейнере `vet_php-fpm-vet.*` — OK (1413 тестов).

## 2026-04-03 (death_list: несколько записей падежа на дату)

- **Формат JSON:** `death_list` для `pork_group` и `poultry_group` — за ключ даты `Y-m-d` хранится **массив** записей
  `{count, comment, pen?, weight?, age_days?, diagnosis?}`; сохранение из таблицы — полная замена дня полем `records`;
  `records: []` удаляет ключ дня; для свиней связанная запись `history` типа падёж удаляется при очистке дня.
- **Миграция:** `migrations/Version20260403150000.php` — обёртка существующего объекта за дату в одноэлементный массив.
- **Утилита:** `src/Module/JsonList/ListedDeathRecordsForDeathListDay.php` — нормализация значения за дату при чтении.
- **Backend (фрагменты):** `SavedDeathEntry`, `SavedPoultryMortalityDay`, `SavedMortalityCellController`, `SavedPoultryCellController`,
  `CreatedHistory` (агрегат текста + `deleteMortalityHistoryForDay`), `Histories` (LATERAL + `jsonb_array_elements`),
  `TableData`, `PoultryTableData`, метрики/дашборды (`ExtractedMetric*`, `MetricsData`, `BuildingsData`, `RoomsData`, `EventFeedData`,
  `PoultryLivestockSection`), `SyncMortalityHistoryCommand`.
- **Excel:** `packages/ametist-excel-parser-bundle/.../DeathRegistration.php` — append записи в массив за дату (транзакция SELECT FOR UPDATE).
- **Frontend:** `SavedMortalityCell.js`, `tableCellModalMixin.js`, `tableCellTypes.js`, `tablePagePoultryCellModalMixin.js`,
  шаблоны `templates/table/pork/_cell_modal.html.twig`, `templates/table/poultry/_cell_modal.html.twig`.
- **Фикстуры:** `PorkGroupFixtures`, `PoultryGroupFixtures` — генерация `death_list` в новом формате.
- **Тесты:** обновлены затронутые unit-тесты; добавлен `ListedDeathRecordsForDeathListDayTest`; переписан `SavedPoultryMortalityDayTest`.
- **Документация:** `.cursor/rules/db-schema.mdc`, `fixtures-rules.mdc`, `table-page/references/pork.md`, `poultry.md`.
- **Проверка:** `php bin/phpunit` в контейнере `vet_php-fpm-vet.*` — OK (1411 тестов). `make test` внутри контейнера падает из‑за CRLF в `bin/phpunit-clean` (как в предыдущих логах).
- **План:** `.cursor/plans/2026-04-03-15-00-death-list-multiple-entries.md`.

## 2026-04-01 (таблица POULTRY — финальные корректировки по итогам диалога)

- **Откат по названиям корпусов:** возвращены исходные имена `Корпус 1..5` в audit-демо и в группировке poultry
  (без нормализации префикса). Синхронизированы тесты и описания. Файлы:
  `src/ExternalModule/AuditModule/Poultry/Building/BuildingsGroupedBySite.php`,
  `src/Command/LoadAuditDataCommand.php`,
  `tests/Unit/ExternalModule/AuditModule/Poultry/Building/BuildingsGroupedBySiteTest.php`,
  `docs/table-page.md`.
- **Откат заголовка таблицы:** возвращено `Дата/корпус` в poultry Twig.
  Файл: `templates/table/poultry/table.html.twig`.
- **Экспорт Excel (финальное поведение):** убран комментарий `Нет данных` для пустых poultry-ячеек в экспорте
  (пустые ячейки без tooltip-комментария, как было до правки). Файлы:
  `assets/js/tableExport.js`, `public/build/tableExport.js`.
- **Экспорт Excel (poultry):** в контексте экспорта явно передаются пустые `legendItems` и `medicaments`, чтобы легенда
  ЛПМ не генерировалась. Файл:
  `public/js/page/table/poultry/tablePagePoultry.js`.
- **Чистка кода и UX:** удалён мёртвый poultry JS/API-код, унифицированы ошибки модалки без дублирующего alert,
  сохранены patch/reload и валидации второй итерации.
  Файлы: `public/js/page/table/poultry/tablePagePoultry.js`,
  `public/js/page/table/poultry/tablePagePoultryCellModalMixin.js`,
  `public/js/api/table/poultry/LoadedPoultryBuildings.js` (удалён),
  `public/js/api/table/poultry/LoadedPoultryRooms.js` (удалён).
- **Проверки:** `npm run build:js` — OK; `php bin/phpunit` в контейнере `vet_php-fpm-vet` — OK по отчётам итераций.

## 2026-04-01 (таблица POULTRY — корректировка экспорта и чистка комментариев)

- **Экспорт Excel:** откат поведения для пустых poultry-ячеек — примечание «Нет данных» в `tableExport` больше не
  добавляется; пустые ячейки экспортируются без tooltip-комментария. Файлы:
  `assets/js/tableExport.js`, `public/build/tableExport.js`.
- **Чистка комментариев:** удалены лишние inline-комментарии в
  `public/js/page/table/poultry/tablePagePoultry.js` без изменения логики.
- **Проверка:** `npm run build:js` — OK.

## 2026-04-01 (таблица POULTRY — финальная зачистка качества, без смены бизнес-логики)

- **Excel:** `assets/js/tableExport.js` — при активном `buildTooltipRowsForExport` пустой массив строк → примечание «Нет данных»
  (как тултип UI); при исключении хука по-прежнему fallback на `TableCellTypes.getTooltipData`. Пересборка `public/build/tableExport.js`.
- **Frontend:** `tablePagePoultry.js` — убраны заглушки истории зала и неиспользуемое состояние/методы ЛПМ выделения;
  `tablePagePoultryCellModalMixin.js` — ошибки сохранения только в `poultryModalError` (без дублирующего `alert`);
  удалены `window.PoultryTableTabKeys` и заглушки `closeMedicineDropdown*`.
- **Мёртвый код:** удалены неподключаемые `public/js/api/table/poultry/LoadedPoultryBuildings.js`, `LoadedPoultryRooms.js`.
- **Проверки:** `npm run build:js` — OK; `php bin/phpunit` в `vet_php-fpm-vet.*` — OK (1407). `make test` локально упал из‑за CRLF в `bin/phpunit-clean` в образе.

## 2026-04-01 (таблица POULTRY — ревью-фиксы после итерации 2)

- **Backend:** `SavedPoultryEggsDay` / `SavedPoultryCullDay` — при невалидном JSON или не-массиве `eggs_list` сохранение не
  выполняется (`InvalidArgumentException`); пустой SELECT по группе — исключение, не тихий return; для яиц/боя обязательно
  явное поле количества (`quantity`/`count` и т.д.), без неявного нуля.
- **Frontend:** `tablePagePoultryCellModalMixin.js` — корм/вода: непустой невалидный ввод и отрицательные значения не уходят
  на API; падёж и остальные вкладки — единая обработка ошибок (`poultryModalError` + alert); яйца — проверка `avg_weight_g`.
- **Экспорт:** `assets/js/tableExport.js` — хук `buildTooltipRowsForExport`: try/catch, при пустом/бесполезном ответе fallback
  на `TableCellTypes.getTooltipData` (не терять примечания); `npm run build:js` → `public/build/tableExport.js`.
- **Тесты:** расширены `SavedPoultryEggsDayTest`, `SavedPoultryCullDayTest`, `SavedPoultryWaterDayTest` (невалидный `eggs_list`,
  обязательные поля, отрицательная вода, граница 0 для брака).
- **Проверки:** `php bin/phpunit` в `vet_php-fpm-vet.*` — OK (1407).

## 2026-04-01 (таблица POULTRY — итерация 2: save eggs/cull/feed/water, Excel, skill table-page)

- **Backend:** `SavedPoultryEggsDay`, `SavedPoultryCullDay`, `SavedPoultryFeedDay`, `SavedPoultryWaterDay` — SQL merge
  `eggs_list` / delete+insert fact за (корпус, день UTC); корм с `name = 'Таблица'`. `SavedPoultryCellController` — PHPDoc контракта,
  feed/water по `roomId`; удалён `PoultryCellTabNotImplementedException` и ответ **501** для этих вкладок.
- **Frontend:** модалка — редактируемые поля + санитайзеры, тела `PUT` с числами; `tablePagePoultry.js` — `buildTooltipRowsForExport`;
  `assets/js/tableExport.js` — опциональный хук `buildTooltipRowsForExport`; пересборка `public/build/tableExport.js` (`npm run build:js`).
- **Parity:** блок легенды ЛПМ на poultry скрыт при пустом `legendItems` (`table.html.twig`).
- **Документация:** `.cursor/skills/table-page/SKILL.md` + `references/*.md`; `docs/table-page.md` сокращён до указателя;
  `general-rules.mdc`, `frontend-architecture.mdc`, `db-schema.mdc` (комментарий к save feed/water из таблицы).
- **Тесты:** `SavedPoultryEggsDayTest`, `SavedPoultryCullDayTest`, `SavedPoultryFeedDayTest`, `SavedPoultryWaterDayTest`.
- **Проверки:** `php vendor/bin/phpunit` в `vet_php-fpm-vet.*` — OK (1398). Ручной smoke pork/poultry/export — по плану на стенде.
- **План:** `.cursor/plans/2026-04-01-22-00-poultry-table-iteration2.md` (критерии выполнены).

## 2026-04-01 (ревью: poultry demo — проверка id залов в тесте)

- **Тест:** `BuildingsGroupedBySiteTest::testGroupedBuildingsMatchesDemoPoultrySitesAndHallNames` — явные `assertSame` для
  `rooms[*].id`: Птичник **1–3**, Молодняк **4–5** (регрессии по id корпусов audit).
- **Документация:** `docs/table-page.md` — то же распределение id по площадкам в описании демо.
- **Файлы:** `tests/Unit/ExternalModule/AuditModule/Poultry/Building/BuildingsGroupedBySiteTest.php`, `docs/table-page.md`.

## 2026-04-01 (poultry: площадки Птичник / Молодняк и залы 1–3 / 1–2)

- **Audit demo:** `LoadAuditDataCommand::loadPoultry()` — две площадки (`poultry_sites` id 1–2), пять корпусов id 1–5: Птичник → имена **1**, **2**, **3**; Молодняк → **1**, **2**; id корпусов сохранены для vet-фикстур.
- **Фикстуры:** число корпусов по-прежнему 5 — `PoultryGroupFixtures`, `SensorFixtures` и прочие `Poultry/*` без правок; после смены audit нужна перезагрузка vet-фикстур для `poultry_group.building_id`.
- **Тесты:** `BuildingsGroupedBySiteTest::testGroupedBuildingsMatchesDemoPoultrySitesAndHallNames`.
- **Документация:** `docs/table-page.md` (демо-структура + блок про точечный SQL без смены id), `.cursor/rules/fixtures-rules.mdc`.
- **Проверки:** `make audit-fixtures-load-poultry`; SQL audit (JOIN sites/buildings) — ожидаемая сетка; `docker exec … php bin/phpunit` в `vet_php-fpm-vet` — OK (1392). Pork / `loadPork()` не менялись. UI/API `/table` и `GET /api/table/poultry/*` — вручную при включённом TABLE+POULTRY.

## 2026-04-01 (таблица POULTRY — UI/UX и подписи, итерация 1)

- **Тултип:** пустая ячейка — «Нет данных»; непустая — строки падёж/яйца/корм/вода (`tablePagePoultry.js`, метод
  `poultryBuildTooltipRows`).
- **Тело ячейки:** только падёж (`getCellDisplayAmount` без яиц).
- **Имена площадок/корпусов:** структура сохранена как «площадки → корпуса» из audit без изменения id и исходных названий.
- **Модалка падежа:** ограничение ввода через `TablePageGlobals.sanitizeUnsignedIntString` /
  `sanitizeUnsignedDecimalString` и обработчики в `tablePagePoultryCellModalMixin.js` + `_cell_modal.html.twig`.
- **Документация:** `docs/table-page.md`, `frontend-architecture.mdc`. Тесты: `BuildingsGroupedBySiteTest` расширен;
  `docker exec … php bin/phpunit` — OK (1391). `make test` в среде с CRLF в `bin/phpunit-clean` может падать — прямой
  вызов `php bin/phpunit` в контейнере.

## 2026-04-01 (ревью-фиксы таблицы POULTRY)

- **Синхронизация `tablePatch` с окном данных:** тело `PUT /api/table/poultry/cell` — опциональные `months` / `monthsForward`
  (как у `GET .../data`); `SavedPoultryCellController` передаёт их в `PoultryTableData::builtTablePatch`. Клиент:
  `tablePagePoultry.js` — поля `tableMonthsBack` / `tableMonthsForward` после успешной загрузки; миксин модалки передаёт их
  в save; fallback `loadTableData()` без аргументов; `retryLoad` сохраняет окно.
- **Безопасность и валидация:** дата `Y-m-d` с проверкой календарной корректности (400); 500 без утечки `getMessage()`
  (`SavedPoultryCellController`, `TableDataController` + `LoggerInterface`); IDOR: `roomId` только из
  `BuildingsGroupedBySite`; `SavedPoultryMortalityDay` — отрицательный `count` → `InvalidArgumentException`, `age_days`
  только валидное целое ≥ 0 иначе `null`.
- **Guard:** `ModuleAccessSubscriber` — маршруты птиц: точное `/api/table/poultry` или префикс `/api/table/poultry/`;
  при исключении в проверках страницы/API таблицы — закрыто (fail-closed).
- **Документация и план:** `docs/table-page.md`, `.cursor/plans/2026-04-01-20-45-poultry-table-backend.md` (секция ревью-фиксы),
  `animal-type-switching.mdc`. Тесты: расширен `SavedPoultryMortalityDayTest`; `make test` в `vet_php-fpm-vet`.
- **Модалка POULTRY (JS):** для вкладок eggs/cull/feed/water после `PUT` с `status === 'ok'` — как у mortality: закрытие модалки,
  `TablePageUtils.applyTablePatch` или `loadTableData()`, иначе алерт (`tablePagePoultryCellModalMixin.js`).

## 2026-04-01 (таблица POULTRY, итерация 1)

- **Таблица птицеводства end-to-end:** миграция `migrations/Version20260401204500.php` — колонка `poultry_group.eggs_list`
  (JSONB, комментарий); `PoultryGroupFixtures` заполняет `eggs_list` по дням; `PoultryGroup` — выборки с `eggs_list`,
  `groupsByBuildingsForPeriod`, `poultryGroupByBuildingAtDate`, декодирование JSON.
- **Audit:** `Buildings::buildingsWithSites()`, `BuildingsGroupedBySite`; **данные страницы:** `PoultryTableData`
  (корпуса по площадкам, падёж, яйца, корм/вода из fact-таблиц); контроллеры `src/Controller/Table/Poultry/`
  (`TableDataController`, `BuildingsAndRoomsController`, `SavedPoultryCellController`).
- **Сохранение:** `PUT /api/table/poultry/cell` — `SavedPoultryMortalityDay` + заглушки `SavedPoultryEggsDay`,
  `SavedPoultryCullDay`, `SavedPoultryFeedDay`, `SavedPoultryWaterDay` (501); ответ с `tablePatch`.
- **Доступ:** `ModuleAccessSubscriber` — `/api/table/poultry/*` только TABLE + POULTRY; `/api/table/*` без poultry — только PORK.
- **Frontend:** `templates/table/poultry/table.html.twig`, `_cell_modal.html.twig`; `public/js/page/table/poultry/tablePagePoultry.js`,
  `tablePagePoultryCellModalMixin.js`; `public/js/api/table/poultry/*`. Диспетчер `/table` → `Poultry\TablePageController::page`.
- **Тесты:** `BuildingsGroupedBySiteTest`, `PoultryTableDataTest`, `SavedPoultryMortalityDayTest`; полный `php bin/phpunit` в
  контейнере `vet_php-fpm-vet` — OK (1389). Документация: `docs/table-page.md`, `db-schema.mdc`, `animal-type-switching.mdc`,
  `frontend-architecture.mdc`, `fixtures-rules.mdc`. План: `.cursor/plans/2026-04-01-20-45-poultry-table-backend.md`.

## 2026-04-01 (ревью TABLE)

- **Guard внутренних путей `/table/*`:** `ModuleAccessSubscriber::checkTablePageAccess($path)` — `/table/pork-page` только при
  активном PORK, `/table/poultry-stub` только при POULTRY; иначе 404 (POULTRY не открывает свиную страницу по прямому URL).
  Миграция `Version20260401181500`: `INSERT ... ON CONFLICT (code) DO NOTHING`. PHPDoc `checkModule`. Документация:
  `docs/table-page.md`, `animal-type-switching.mdc`. План: `.cursor/plans/2026-04-01-18-15-table-poultry-support.md` (секция
  ревью, POST для `cell/placement`).

## 2026-04-01

- **`/table` для PORK/POULTRY, модуль TABLE:** миграция `migrations/Version20260401181500.php` — строка `TABLE` в
  `module_config` (по умолчанию enabled); `ModuleCodeEnum::TABLE`. Контроллеры страницы и `/api/table/*` перенесены в
  `src/Controller/Table/Pork/*`; диспетчер `src/Controller/Table/TablePageController.php` (`GET /table`, имена
  `app_table_page` + алиас `table_page`); заглушка птицеводства `src/Controller/Table/Poultry/TablePageController.php`.
  Роутинг: `config/routes/table_group.php`, исключение `src/Controller/Table/` из общего импорта в `config/routes.yaml`.
  Шаблоны: `templates/table/pork/*`, `templates/table/poultry/table_stub.html.twig` (удалён каталог
  `templates/pork/table/`). `ModuleAccessSubscriber`: убран `/table` из `URL_PORK_MAP`; отдельные проверки для `/table`
  (TABLE + активный вид) и `/api/table` (TABLE + только pork). Sidenav: пункт «Таблица» по `is_module_enabled('TABLE')`.
  Документация: `docs/table-page.md`, `.cursor/rules/animal-type-switching.mdc`, `db-schema.mdc`,
  `frontend-architecture.mdc`, `.cursor/skills/symfony-bundles/references/module-config.md`. План:
  `.cursor/plans/2026-04-01-18-15-table-poultry-support.md`. Тесты: `php bin/phpunit` в контейнере `vet_php-fpm-vet` — OK.
## 2026-03-31

- **Журнал `animal_alert` и запись из consumer статуса комнаты:** добавлены тип PostgreSQL
  `animal_alert_status` (`normal` | `warning` | `critical`) и таблица `animal_alert` (журнал только INSERT),
  enum приложения `App\Enum\AnimalAlertStatusEnum`, класс `AiBundle\Database\CreatedAnimalAlert`.
  `ParsedRoomStatus::parse()` возвращает `?RoomStatusEnum` для статуса; нераспознанный ответ → `null` в журнале,
  для обновления группы сохранён fallback `RoomStatusEnum::NORMAL`. В `ConsumedRoomStatusMessage` после парсинга —
  `statusUpdater->update`, затем попытка INSERT в `animal_alert` с заголовком «Определение статуса группы»;
  при ошибке INSERT — лог без nack. Обновлены тесты парсера, интеграционные тесты consumer, добавлен
  `tests/Unit/AiBundle/Database/CreatedAnimalAlertTest.php`. Миграция: `Version20260331143000`.
  Документация: `.cursor/rules/db-schema.mdc`. План с отметками:
  `.cursor/plans/2026-03-31-12-30-animal-alert-table-and-room-status-insert.md`.
  Файлы: `migrations/Version20260331143000.php`, `src/Enum/AnimalAlertStatusEnum.php`,
  `packages/ai-bundle/src/Database/CreatedAnimalAlert.php`, `packages/ai-bundle/src/Module/ParsedRoomStatus.php`,
  `packages/ai-bundle/src/Module/ConsumedRoomStatusMessage.php`, `tests/Unit/Module/PorkGroup/ParsedRoomStatusTest.php`,
  `tests/Unit/AiBundle/Database/CreatedAnimalAlertTest.php`,
  `tests/Integration/Module/PorkGroup/ConsumedRoomStatusMessageIntegrationTest.php`.

## 2026-03-30

- **Показания датчиков `/sensors` — удалён мёртвый код в табах:** из `list.html.twig` убрана ветка
  `if (this.tab === 'readings') ...`, которая не срабатывала при стартовом `tab: 'charts'`. Триггер показа
  вкладки «Показания датчиков» остался единым — через `$watch('tab', ...)`. Файлы:
  `packages/sensor-bundle/Resources/views/sensors/list.html.twig`.

- **Показания датчиков — ревью: IO при любой смене вкладки readings:** в `initObserverWhenTabVisible`
  добавлен поллинг, пока панель скрыта (`offsetHeight === 0`), до `maxWaitMs` (раньше один тик и ожидание
  только события). На странице `/sensors` событие показа вкладки диспатчится из `$watch('tab')` родительского
  `x-data` (и при старте, если `tab === 'readings'`), а не только из `@click` кнопки. Имя события —
  `window.SENSORS_READINGS_TAB_VISIBLE_EVENT` в `SensorsReadings.js` (fallback в Twig). Слушатели `window`
  снимаются в `destroy()`. Файлы: `packages/sensor-bundle/assets/js/component/SensorsReadings.js`,
  `public/js/component/sensor/SensorsReadings.js`,
  `packages/sensor-bundle/Resources/views/sensors/list.html.twig`, план
  `.cursor/plans/2026-03-30-16-00-sensors-readings-infinite-scroll.md`.

- **Показания датчиков — чистка после перехода на viewport scroll:** в `LoadedPagesByScroll` удалён
  дублирующий fallback (`window` scroll/resize при `root=null`); догрузка только через
  `IntersectionObserver`. В `SensorsReadings` убраны поясняющий блок про контейнер и вызовы
  `setRoot(null)`; переименован метод ожидания видимости вкладки в `initObserverWhenTabVisible`,
  переменная панели — `panel`. В `_readings.html.twig` добавлен Twig-комментарий к `readingsScrollRoot`.
  Обновлён `.cursor/skills/pagination-load-more/SKILL.md`, чекбоксы в плане
  `.cursor/plans/2026-03-30-16-00-sensors-readings-infinite-scroll.md` (секция «Дочистка»).
  Файлы: `packages/sensor-bundle/assets/js/page/shared/LoadedPagesByScroll.js`,
  `public/js/page/shared/LoadedPagesByScroll.js`,
  `packages/sensor-bundle/assets/js/component/SensorsReadings.js`,
  `public/js/component/sensor/SensorsReadings.js`,
  `packages/sensor-bundle/Resources/views/sensors/_readings.html.twig`.

- **Показания датчиков `/sensors` — фикc IO при скрытом табе:** observer теперь переинициализировался,
  когда `readingsScrollRoot` становится видимым (вместо единственного init на первом рендере),
  чтобы догрузка работала сразу после перехода на вкладку «Показания датчиков».
  Файлы: `public/js/component/sensor/SensorsReadings.js`, `packages/sensor-bundle/assets/js/component/SensorsReadings.js`.

- **Показания датчиков `/sensors` — infinite scroll и envelope (финал):** реализация завершена и ревьюирована.
  Итоговая оценка: нет мертвого кода, все старые методы `buildQuery`/`buildParams` удалены из `SensorsData`,
  старый `loadReadings()` полностью заменён на `reloadReadingsFromScratch()`, фильтр «Количество записей»
  убран из UI, JS-дубликаты синхронизированы. API `GET /api/sensors/readings` возвращает envelope
  `{status, meta.pagination, data.readings}` через `Paginator::okEnvelope`; страница **по 50 записей**.
  Backend: `SensorsData::list()` — обёртка над `listPage()`, `countList()` и `listPage()` — новые методы
  с общим WHERE для фильтров, `LIMIT`/`OFFSET` c `PDO::PARAM_INT`. Frontend: `LoadedPagesByScroll`
  (IntersectionObserver + sentinel), `_reloadGeneration` счётчик для защиты от гонок, при пустом чанке
  `_hasMore=false`. Защита от циклического скролла, корректная переподписка observer при смене фильтров.
  Все тесты — OK (1386 tests, `tests/Unit/Module/Sensor/SensorsDataTest.php` — 8 тестов).
  Файлы: `packages/sensor-bundle/src/Database/SensorsData.php`,
  `packages/sensor-bundle/src/Controller/ListReadingsController.php`,
  `packages/sensor-bundle/src/Controller/SensorsPageController.php`,
  `packages/sensor-bundle/Resources/views/sensors/list.html.twig`,
  `packages/sensor-bundle/Resources/views/sensors/_readings.html.twig`,
  `public/js/page/shared/LoadedPagesByScroll.js`,
  `public/js/api/sensor/LoadedReadingsList.js`, `public/js/component/sensor/SensorsReadings.js`,
  `packages/sensor-bundle/assets/js/page/shared/LoadedPagesByScroll.js`,
  `packages/sensor-bundle/assets/js/api/sensor/LoadedReadingsList.js`,
  `packages/sensor-bundle/assets/js/component/SensorsReadings.js`,
  `tests/Unit/Module/Sensor/SensorsDataTest.php`,
  `.cursor/rules/frontend-architecture.mdc`, `.cursor/skills/pagination-load-more/SKILL.md`,
  `.cursor/skills/symfony-bundles/references/sensor-bundle.md`, `task_logs.md` (этот файл).

- **Показания датчиков — ревью (гонки reload, пустой чанк):** в `SensorsReadings.js` счётчик `_reloadGeneration`:
  применение ответа и `isLoading=false` в `finally` только при актуальном токене; `loadFirstPage(gen)` и проверка
  токена в `onChunk`. В `LoadedPagesByScroll._applyPageJson` при `readings.length === 0` принудительно
  `_hasMore = false`. `ListReadingsController`: внешний `catch (\Throwable)` без неиспользуемой переменной;
  PHPDoc класса в прошедшем времени. Прогон: `php vendor/bin/phpunit tests/Unit/Module/Sensor/SensorsDataTest.php`
  в контейнере `vet_php-fpm-vet.*` — OK (8 тестов).
  Файлы: `packages/sensor-bundle/assets/js/component/SensorsReadings.js`,
  `packages/sensor-bundle/assets/js/page/shared/LoadedPagesByScroll.js`,
  `public/js/component/sensor/SensorsReadings.js`, `public/js/page/shared/LoadedPagesByScroll.js`,
  `packages/sensor-bundle/src/Controller/ListReadingsController.php`,
  `.cursor/skills/pagination-load-more/SKILL.md`, `.cursor/rules/frontend-architecture.mdc`.

- **Показания датчиков `/sensors` — infinite scroll и envelope:** API `GET /api/sensors/readings`
  отдаёт `status`, `meta.pagination` (`limit`, `offset`, `total`, `has_more`) и `data.readings` через
  `Paginator::okEnvelope`; лимит страницы по умолчанию и максимум **50**. В `SensorsData` общий WHERE
  для `countList` и `listPage` (`LIMIT`/`OFFSET`), `list()` — обёртка над `listPage(…, 0, $limit)`.
  Фронт: `Paginator.js`, `LoadedPagesByScroll.js` (IntersectionObserver + sentinel), `LoadedReadingsList.js`,
  `SensorsReadings.js`; убрано поле «Количество записей» в фильтрах. Дубликаты в `packages/sensor-bundle/assets/js/`.
  Прогон: полный `php vendor/bin/phpunit` в контейнере `vet_php-fpm-vet` — OK (1386 тестов).
  `make test` локально падает из‑за CRLF в `bin/phpunit-clean` (не из этой задачи).
  Файлы: `packages/sensor-bundle/src/Database/SensorsData.php`,
  `packages/sensor-bundle/src/Controller/ListReadingsController.php`,
  `packages/sensor-bundle/src/Controller/SensorsPageController.php`,
  `packages/sensor-bundle/Resources/views/sensors/list.html.twig`,
  `packages/sensor-bundle/Resources/views/sensors/_readings.html.twig`,
  `public/js/page/shared/LoadedPagesByScroll.js`,
  `public/js/api/sensor/LoadedReadingsList.js`, `public/js/component/sensor/SensorsReadings.js`,
  `packages/sensor-bundle/assets/js/page/shared/LoadedPagesByScroll.js`,
  `packages/sensor-bundle/assets/js/api/sensor/LoadedReadingsList.js`,
  `packages/sensor-bundle/assets/js/component/SensorsReadings.js`,
  `tests/Unit/Module/Sensor/SensorsDataTest.php`,
  `.cursor/plans/2026-03-30-16-00-sensors-readings-infinite-scroll.md`,
  `.cursor/rules/frontend-architecture.mdc`, `.cursor/skills/pagination-load-more/SKILL.md`,
  `.cursor/skills/symfony-bundles/references/sensor-bundle.md`.

- **Исправление блока «На момент постановки» после `/table`:**
  блок теперь использует данные последнего открытого движения группы (`pork_group_movement.start_date/count/avg_weight/age_days`)
  вместо `pork_group.start_date/start_count`, чтобы корректно отображать “возраст” и “дату постановки”,
  переданные из таблицы. Реализовано через `LatestPorkGroupMovement`, прокидывание movement-полей
  в `RoomPageController` и приоритетное чтение в `PlacementData`. Одновременно `UpdatedPlacementSnapshot`
  перестал перетира́ть `pork_group.start_date/start_count` и обновляет только JSONB-срезы
  `livestock_list`/`weight_list`. Прогон: полный `php vendor/bin/phpunit` в контейнере — зелёный.
  Файлы: `src/Module/PorkGroup/Database/LatestPorkGroupMovement.php`, `src/Controller/Pork/RoomPageController.php`,
  `src/Module/PorkGroup/PageData/PlacementData.php`, `src/Module/PorkGroup/Database/UpdatedPlacementSnapshot.php`,
  `tests/Unit/Module/PorkGroup/Database/UpdatedPlacementSnapshotTest.php`.

- **Снимок постановки после операций из таблицы `/table`:** добавлен
  `App\Module\PorkGroup\Database\UpdatedPlacementSnapshot::apply()` — обновляет
  `pork_group.start_date`, `start_count`, мержит `livestock_list` по ключу `Y-m-d`
  и при переданном среднем весе — `weight_list` (общий вес = средний × головы), по образцу
  `COALESCE(..., '{}'::jsonb) || :payload::jsonb`. Вызов после успешного INSERT в
  `pork_group_movement` в `PlacedGroupController::place()` и в ветке с целевой комнатой
  в `ShippedGroupController::ship()` (без целевой комнаты снимок не трогаем). Unit-тесты
  на корректные SQL-обновления при null / не-null среднем весе. Прогон: `php vendor/bin/phpunit tests/Unit/Module/PorkGroup/Database/UpdatedPlacementSnapshotTest.php` (в контейнере `vet_php-fpm-vet`).
  Файлы: `src/Module/PorkGroup/Database/UpdatedPlacementSnapshot.php`,
  `src/Controller/Pork/PlacedGroupController.php`, `src/Controller/Pork/ShippedGroupController.php`,
  `tests/Unit/Module/PorkGroup/Database/UpdatedPlacementSnapshotTest.php`.

## 2026-03-27

- **Проверка и фиксы метрик/графиков корпуса птицы (живой вес, привес, ККК):**
  исправлен расчёт `fcr_fact` в блоке показателей — сумма фактического корма теперь ограничена диапазоном
  между первой и последней датой взвешивания (устранено завышение ККК при задержке ввода веса). Исправлен
  расчёт планового веса в `ChartData`: вместо одной текущей нормы на весь период применяется норма по стадиям
  (`starter/grower/finisher`) для каждой даты по возрасту группы; для неполного набора стадий добавлен fallback,
  чтобы график не пропадал целиком. Во фронтенде исправлена серия ККК (`BuildingCharts.js`) — базовая точка
  берётся по первому непустому значению веса, и накопление корма начинается после этой базовой точки.
  Добавлены unit-тесты на диапазон дат корма в `MetricsData` и на стадийный расчёт `plan_weight_by_date`
  в `ChartData`. Прогон `php vendor/bin/phpunit` в контейнере — зелёный.
  Файлы: `src/Module/PoultryGroup/Database/FeedNorm/FeedByDate.php`,
  `src/Module/PoultryGroup/PageData/MetricsData.php`, `src/Module/PoultryGroup/PageData/ChartData.php`,
  `public/js/component/building/BuildingCharts.js`,
  `tests/Unit/PoultryGroup/PageData/PoultryMetricsDataFcrFactTest.php`,
  `tests/Unit/PoultryGroup/PageData/PoultryChartDataTest.php`.

- **Реформат skill pagination-load-more по образцу ai-chat:** убран checklist-стиль, добавлена архитектурная
  структура: общие frontend/backend модули, сквозной цикл данных (SSR -> init -> request -> response -> append -> reinit),
  таблицы параметров и `meta.pagination`, правила изменений, список отслеживаемых файлов.
  Файл: `.cursor/skills/pagination-load-more/SKILL.md`.

- **Документация skill по пагинации:** расширен `.cursor/skills/pagination-load-more/SKILL.md` под требования тимлида:
  описан полный цикл frontend -> backend -> frontend, параметры `limit/offset/loaded/total/dataKey`,
  структура `meta.pagination`, пример request/response envelope, частые ошибки и проверки после create/update.
  Файл: `.cursor/skills/pagination-load-more/SKILL.md`.

- **Фикс ЛПМ-пагинации (issue142):** восстановлен прежний контракт `LpmData::data()` (полный список, без неявного limit=14),
  чтобы не сломать legacy endpoint `/api/lpm/list`; постраничная загрузка остаётся только в `LpmData::page()`.
  Убрано дублирование рендера ЛПМ: общий JS `public/js/page/shared/LpmLoadMore.js` подключён в room/building,
  `RoomPageDataLoader.js`, `BuildingPageDataLoader.js` и `RefreshLpm.js` используют общую реализацию.
  Файлы: `src/Module/PorkGroup/PageData/LpmData.php`, `src/Module/PoultryGroup/PageData/LpmData.php`,
  `public/js/page/shared/LpmLoadMore.js`, `public/js/page/room/RoomPageDataLoader.js`,
  `public/js/page/building/BuildingPageDataLoader.js`, `public/js/api/lpm/RefreshLpm.js`,
  `templates/pork/room/room.html.twig`, `templates/poultry/building/dashboard.html.twig`,
  `tests/Unit/PorkGroup/PageData/LpmDataTest.php`, `.cursor/rules/frontend-architecture.mdc`.

- **ЛПМ: «Загрузить ещё» для room/building (issue142):** вкладка ЛПМ переведена на общий async-паттерн
  (`LoadMoreManager` + `Paginator`) как у мероприятий/ленты. Добавлены API страницы:
  `GET /api/pork/groups/{id}/lpms`, `GET /api/poultry/groups/{id}/lpms` (limit/offset 14/90, envelope `data.events`);
  `LpmData` в pork/poultry получил `page(...)` и `timezoneAbbreviation()`. В `RoomPageController` и
  `BuildingPageController` SSR ЛПМ теперь отдаёт первые 14 записей и `lpm_total`. ЛПМ-блоки в Twig получили
  `data-lpm-*` атрибуты, кнопку «Загрузить ещё» и блок ошибки; инициализация дозагрузки добавлена в
  `RoomPageDataLoader.js` и `BuildingPageDataLoader.js`. `RefreshLpm.js` переведён на новые paged-endpoints
  и переинициализацию load-more после create/update. Добавлен skill
  `.cursor/skills/pagination-load-more/SKILL.md`, ссылка на него внесена в `.cursor/rules/general-rules.mdc`,
  `frontend-architecture.mdc` обновлён по ЛПМ-пагинации.
  Файлы: `src/Controller/Pork/RoomLpmController.php`, `src/Controller/Poultry/BuildingLpmController.php`,
  `src/Controller/Pork/RoomPageController.php`, `src/Controller/Poultry/BuildingPageController.php`,
  `src/Module/PorkGroup/PageData/LpmData.php`, `src/Module/PoultryGroup/PageData/LpmData.php`,
  `templates/pork/room/_lpm.html.twig`, `templates/poultry/building/_lpm.html.twig`,
  `public/js/page/room/RoomPageDataLoader.js`, `public/js/page/building/BuildingPageDataLoader.js`,
  `public/js/api/lpm/RefreshLpm.js`, `tests/Unit/PorkGroup/PageData/LpmDataTest.php`,
  `.cursor/skills/pagination-load-more/SKILL.md`, `.cursor/rules/general-rules.mdc`,
  `.cursor/rules/frontend-architecture.mdc`.

- **Таблица /table: bulk history и tablePatch после save:** `Histories::historiesByRoomsAndDateRange` (один SQL на
  период и комнаты), `historiesByRoomAndDate` делегирует в bulk; `TableData` — индекс по дню, `overlayFromHistoryRows`,
  `builtTablePatch` / `builtLpmTablePatch` / `hallHeaderSnapshotsForRooms`; класс `PreparedLpmPatchCoordinates` для
  координат ЛПМ через границу месяца. Ответы `tablePatch`: mortality, place-group, ship-group, `POST /api/lpm/create`.
  Фронт: `TablePageUtils.applyTablePatch`, миксин — патч или fallback `loadTableData`. Тесты: `HistoriesTest`,
  `TableDataOverlayTest`, `PreparedLpmPatchCoordinatesTest`, `TableDataHistoryIndexTest`. Док: `docs/table-page.md`,
  `.cursor/rules/frontend-architecture.mdc`. План: `.cursor/plans/2026-03-27-15-00-table-performance-partial-refresh.md`.
  Файлы: `src/Module/History/Database/Histories.php`, `src/Module/PorkGroup/PageData/TableData.php`,
  `src/Module/PorkGroup/PageData/PreparedLpmPatchCoordinates.php`, `src/Controller/Pork/SavedMortalityCellController.php`,
  `src/Controller/Pork/PlacedGroupController.php`, `src/Controller/Pork/ShippedGroupController.php`,
  `src/Controller/Lpm/CreatedLpmController.php`, `public/js/page/table/tablePageUtils.js`,
  `public/js/page/table/tableCellModalMixin.js`, `tests/Unit/Module/History/HistoriesTest.php`,
  `tests/Unit/Module/PorkGroup/PageData/TableDataOverlayTest.php`,
  `tests/Unit/Module/PorkGroup/PageData/PreparedLpmPatchCoordinatesTest.php`,
  `tests/Unit/Module/PorkGroup/PageData/TableDataHistoryIndexTest.php`.

## 2026-03-26

- **Ревью load-more (issue142):** синхронизирован `todo.md` с выполненной задачей; из include ленты в
  `poultry/building/_dashboard.html.twig` убрана неиспользуемая передача `historyData` (лента на `EventFeedData`);
  `LoadMoreManager.js` — при пустом `data` и `has_more` сдвиг следующего offset по `meta.pagination` (или `+limit`),
  сообщение об ошибке, без зацикливания запроса с тем же offset. План: доп. блок в
  `.cursor/plans/2026-03-26-17-00-load-more-events-and-feed.md`.
  Файлы: `todo.md`, `templates/poultry/building/_dashboard.html.twig`, `public/js/api/shared/LoadMoreManager.js`.

- **«Загрузить ещё» для мероприятий и ленты (issue142):** SQL-страница `PlannedEvents::eventsPage`, API
  `GET /api/pork|poultry/groups/{id}/events` и `GET /api/poultry/groups/{id}/event-feed` (limit/offset 14/90),
  envelope `data.events` / `data.items`, JSON как у Twig с `activity_date`/`date` в ATOM. `PlannedEventFormatter`,
  SSR — первые 14 + `events_total` / `event_feed_total`. `LoadMoreManager` + `Paginator`, разметка в
  `planned_events.html.twig`, `event_feed.html.twig`, partial `_event_feed_data_list.html.twig`; poultry дашборд ленты
  переведён на `EventFeedData` вместо `HistoryData`. Тесты: `PlannedEventsEventsPageTest`, `EventFeedDataPageTest`,
  правка `EventDataTest`. План: `.cursor/plans/2026-03-26-17-00-load-more-events-and-feed.md`.
  Файлы: `src/Module/PlannedEvent/Database/PlannedEvents.php`, `src/Module/PlannedEvent/PlannedEventFormatter.php`,
  `src/Module/PorkGroup/PageData/EventData.php`, `src/Module/PoultryGroup/PageData/EventData.php`,
  `src/Module/PoultryGroup/PageData/EventFeedData.php`, `src/Controller/Pork/RoomEventsController.php`,
  `src/Controller/Pork/RoomPageController.php`, `src/Controller/Poultry/BuildingEventsController.php`,
  `src/Controller/Poultry/BuildingEventFeedController.php`, `src/Controller/Poultry/BuildingPageController.php`,
  `public/js/api/shared/LoadMoreManager.js`, `public/js/page/room/RoomPageDataLoader.js`,
  `public/js/page/building/BuildingPageDataLoader.js`, `templates/components/blocks/planned_events.html.twig`,
  `templates/components/blocks/event_feed.html.twig`, `templates/components/partials/_event_feed_data_list.html.twig`,
  `templates/poultry/building/_dashboard.html.twig`, `templates/pork/room/room.html.twig`,
  `templates/poultry/building/dashboard.html.twig`, `tests/Unit/Module/PlannedEvent/PlannedEventsEventsPageTest.php`,
  `tests/Unit/PoultryGroup/PageData/EventFeedDataPageTest.php`, `tests/Unit/PorkGroup/PageData/EventDataTest.php`,
  `.cursor/rules/backend-architecture.mdc`, `.cursor/rules/frontend-architecture.mdc`.

- **Корпус птицы:** блок климата — снова сетка `climate-card__grid` (3 колонки), как в старой дублирующей карточке.
  Файл: `templates/poultry/building/blocks/_internal_climate_metric_section.html.twig`.

- **Корпус птицы:** «Климат (внутренний)» — отдельная карточка под «Показателями», на всю ширину контента карточки
  (без сетки из трёх колонок). Файлы: `_dashboard.html.twig`, `_metrics.html.twig`, `references/sensor-bundle.md`.

- **Страница корпуса птицы — климат без дубля:** убрана дублирующая карточка климата из `_dashboard.html.twig`;
  секция «Климат (внутренний)» вынесена в `_internal_climate_metric_section.html.twig` (нормы, warnings, давление,
  скелетон, кнопка «История климата»). Удалён `_sensor_climate_card.html.twig`.
  Файлы: `templates/poultry/building/_dashboard.html.twig`, `templates/poultry/building/blocks/_metrics.html.twig`,
  `templates/poultry/building/blocks/_internal_climate_metric_section.html.twig`,
  `.cursor/skills/symfony-bundles/references/sensor-bundle.md`.

- **Единая пагинация модалок комнаты (pork) и корпуса (poultry):** envelope `status` + `meta.pagination` + `data`
  (`rows` / `days` / `history`), `GET limit`/`offset` (дефолт 14, макс. 90). Pork: `FeedData::consumptionTablePage`,
  `RoomFeedTableController`; модалка корма на `Paginator` + infinite scroll; удалён `RoomModalCache.js`. Климат: при отсутствии
  `limit` в query — прежний массив для `SensorChart.js`; при `limit` — envelope и `ClimateHistoryByRoom::historyPage` (SQL);
  `RoomClimateHistoryController` дублирует форму envelope без зависимости бандла от `App\Paginator`. Building: `Paginator.js`
  в dashboard; `MetricsData::disposalTablesPage`, пагинация mortality/feed; новый `BuildingWaterTableController`,
  `ResourceHistoryData::waterHistoryPage`, Alpine-модалка воды; `water_history` в SSR пустой массив; удалён
  `BuildingModalCache.js`. План: `.cursor/plans/2026-03-26-17-45-modal-pagination-room-and-building.md`.
  Файлы: `src/Module/PorkGroup/PageData/FeedData.php`, `src/Controller/Pork/RoomFeedTableController.php`,
  `templates/pork/room/modals/_feed_consumption_table_modal.twig`, `templates/pork/room/modals/_internal_climate_table.html.twig`,
  `templates/pork/room/room.html.twig`, `packages/sensor-bundle/src/Database/ClimateHistoryByRoom.php`,
  `packages/sensor-bundle/src/Controller/RoomClimateHistoryController.php`,
  `src/Module/PoultryGroup/PageData/MetricsData.php`, `src/Module/PoultryGroup/PageData/FeedData.php`,
  `src/Module/PoultryGroup/PageData/ResourceHistoryData.php`, `src/Controller/Poultry/BuildingMortalityTableController.php`,
  `src/Controller/Poultry/BuildingFeedTableController.php`, `src/Controller/Poultry/BuildingWaterTableController.php`,
  `src/Controller/Poultry/BuildingPageController.php`, `templates/poultry/building/dashboard.html.twig`,
  `templates/poultry/building/modals/_mortality_table_modal.html.twig`,
  `templates/poultry/building/modals/_feed_history_modal.html.twig`,
  `templates/poultry/building/modals/_water_history_modal.html.twig`,
  `templates/poultry/building/modals/_internal_climate_table.html.twig`,
  `tests/Unit/Module/PorkGroup/PageData/FeedDataConsumptionTablePageTest.php`,
  `tests/Unit/PoultryGroup/PageData/PoultryMetricsDataDisposalTablesPageTest.php`,
  `tests/Unit/PoultryGroup/PageData/PoultryFeedDataConsumptionTablePageTest.php`,
  `tests/Unit/PoultryGroup/PageData/ResourceHistoryDataWaterHistoryPageTest.php`,
  `.cursor/rules/frontend-architecture.mdc`, `.cursor/skills/symfony-bundles/references/sensor-bundle.md`.

- **Ревью (второй проход) модалки выбытия:** убрано `initialized = true` при отсутствии `window.Paginator`, чтобы не
  показывать одновременно `loadError` и строки «Нет данных»; PHPDoc теста в прошедшем времени.
  Файлы: `templates/pork/room/modals/_mortality_table_modal.html.twig`,
  `tests/Unit/Module/PorkGroup/PageData/MetricsDataDisposalTablesPageTest.php`,
  `.cursor/plans/2026-03-26-16-45-room-mortality-modal-pagination.md`.

- **Ревью пагинации модалки выбытия (pork):** JSDoc у `Paginator.js` (конструктор, `abortPending`, `loadPage`);
  в плане и `frontend-architecture.mdc` — исключение по имени `window.Paginator`; PHPDoc у
  `MetricsData::disposalTablesPage` про компромисс полной сборки в памяти; модалка — `loadError`, если скрипт
  пагинации не загрузился; расширены `MetricsDataDisposalTablesPageTest` (пустая группа, offset за пределами,
  день только с переводами). План: `.cursor/plans/2026-03-26-16-45-room-mortality-modal-pagination.md` (блок «Ревью-фикс»).
  Файлы: `public/js/api/shared/Paginator.js`, `src/Module/PorkGroup/PageData/MetricsData.php`,
  `templates/pork/room/modals/_mortality_table_modal.html.twig`,
  `tests/Unit/Module/PorkGroup/PageData/MetricsDataDisposalTablesPageTest.php`,
  `.cursor/plans/2026-03-26-16-45-room-mortality-modal-pagination.md`, `.cursor/rules/frontend-architecture.mdc`.

- **Модалка «Таблица выбытия» на странице комнаты свиней (pork):** пагинация по календарным дням
  (`GET /api/pork/groups/{id}/mortality-table?limit=&offset=`), ответ `{ status, meta.pagination, data.days }`;
  `App\Module\Pagination\Paginator`, `MetricsData::disposalTablesPage()`; кэш mortality в `RoomModalCache.js` снят
  (остался `loadFeedTable`); `public/js/api/shared/Paginator.js` + `IntersectionObserver` на sentinel, лоадер внизу
  при `loadingMore`. Тесты: `PaginatorTest`, `MetricsDataDisposalTablesPageTest`. План:
  `.cursor/plans/2026-03-26-16-45-room-mortality-modal-pagination.md`.
  Файлы: `src/Module/Pagination/Paginator.php`, `src/Module/PorkGroup/PageData/MetricsData.php`,
  `src/Controller/Pork/RoomMortalityTableController.php`, `public/js/api/shared/Paginator.js`,
  `public/js/page/room/RoomModalCache.js`, `templates/pork/room/modals/_mortality_table_modal.html.twig`,
  `templates/pork/room/room.html.twig`, `tests/Unit/Module/Pagination/PaginatorTest.php`,
  `tests/Unit/Module/PorkGroup/PageData/MetricsDataDisposalTablesPageTest.php`,
  `.cursor/rules/frontend-architecture.mdc`.

- **Страница корпуса `/buildings/{id}` (птица) — асинхронная загрузка:** API
  `BuildingChartDataController`, `BuildingSensorCardDataController`, `BuildingMortalityTableController`,
  `BuildingFeedTableController` (`/api/poultry/groups/{id}/...`, id = `poultry_group.id`);
  `BuildingPageController` без `ChartData`/`SensorData`; `MetricsData`/`FeedData` с `withTableData=false` для SSR;
  JS `BuildingPageDataLoader.js`, `BuildingModalCache.js`; `BuildingCharts.js` по событию `building:chart-data-loaded`
  (маппинг `ChartData` → серии Apex); `SensorChart.js` / `IntradaySensorChart.js` — `building:sensor-card-loaded`
  и `buildingSensorChartData` при `window.buildingGroupId`; Twig скелетоны, `roomSensorAsync: true` для sensor-bundle;
  модалки выбытия/корма на fetch. План: `.cursor/plans/2026-03-26-building-page-async-load.md`.
  После ревью: обязательный query `buildingId` для данных по группе; `BuildingPoultryGroupApiGuard`;
  общий SCSS `skeleton-pulse`; защита `norms` в карточке климата; `window.buildingId` в twig.
  Файлы: `src/Controller/Poultry/Building*Controller.php`, `BuildingPoultryGroupApiGuard.php`, `src/Module/PoultryGroup/PageData/MetricsData.php`,
  `FeedData.php`, `public/js/page/building/*.js`, `public/js/component/building/BuildingCharts.js`,
  `public/js/component/sensor/chart/SensorChart.js`, `IntradaySensorChart.js`,
  `packages/sensor-bundle/assets/js/component/chart/SensorChart.js`, `IntradaySensorChart.js`,
  `templates/poultry/building/*.twig`, `templates/poultry/building/blocks/*.twig`,
  `templates/poultry/building/modals/_mortality_table_modal.html.twig`,
  `_feed_history_modal.html.twig`, `assets/scss/pages/buildings.scss`,
  `tests/Unit/PoultryGroup/PageData/PoultryMetricsDataTableFlagTest.php`,
  `.cursor/rules/frontend-architecture.mdc`, `.cursor/skills/symfony-bundles/references/sensor-bundle.md`.

- **Страница комнаты `/rooms/{id}` — ускорение TTFB:** тяжёлые данные вынесены в API
  (`RoomChartDataController`, `RoomSensorCardDataController`, `RoomMortalityTableController`,
  `RoomFeedTableController`); `RoomPageController` без `ChartData`/`SensorData`;
  `MetricsData`/`FeedData` с флагами без табличных массивов для SSR.
  JS: `RoomPageDataLoader.js` (кэш chart + sensor на время страницы, события
  `room:chart-data-loaded`, `room:sensor-card-loaded`), `RoomModalCache.js` для модалок;
  скелетоны в `room.scss`; модалки выбытия/расхода на Alpine + fetch.
  Sensor-bundle: `_sensor_charts_block` / `_intraday_charts` — режим `roomSensorAsync` (pork)
  и legacy SSR (poultry). План: `.cursor/plans/2026-03-26-room-page-async-load.md`.
  После ревью: независимая обработка chart/sensor в `RoomPageDataLoader.js` (сбой одного API
  не блокирует второй); в модалках выбытия/расхода — сообщение об ошибке загрузки.

## 2026-03-25

- **/table — фиксы после e2e проверки:** исправлено закрытие модалки по `Escape` (закрытие модалки ячейки и
  истории комнаты), добавлены `window.*` экспорты для `public/js/api/lpm/*` (нужно для `CreatedLpm` в миксинах),
  унифицирована обработка ошибок в API-классах `/table` и `LoadedMedicaments` (не теряем backend `message` при
  HTTP 4xx/5xx). Документация `/table` обновлена (`docs/table-page.md`).
  Изменённые файлы:
  - `public/js/page/table/tablePage.js`
  - `public/js/api/lpm/CreatedLpm.js`
  - `public/js/api/lpm/LoadedLpm.js`
  - `public/js/api/lpm/UpdatedLpm.js`
  - `public/js/api/lpm/RefreshLpm.js`
  - `public/js/api/table/LoadedTableData.js`
  - `public/js/api/table/SavedMortalityCell.js`
  - `public/js/api/table/LoadedBuildings.js`
  - `public/js/api/table/LoadedRooms.js`
  - `public/js/api/table/LoadedFreeGroups.js`
  - `public/js/api/table/PlacedGroup.js`
  - `public/js/api/table/ShippedGroup.js`
  - `public/js/api/table/LoadedRoomHistory.js`
  - `public/js/api/shared/LoadedMedicaments.js`
  - `docs/table-page.md`
  - `.cursor/rules/frontend-architecture.mdc`

- **Рефакторинг фронтенда `/table`:** вынесены API-классы в `public/js/api/table/*.js`, общий
  `LoadedMedicaments.js` в `public/js/api/shared/`; `tablePageUtils.js`, `tableCellModalMixin.js`,
  `tableRoomHistoryMixin.js`; `tablePage.js` без `window.TableApi`, порядок скриптов в
  `templates/pork/table/table.html.twig` (без подключения `TableApi.js` на этой странице).
  `LpmModal.js` использует `LoadedMedicaments`; перед ним скрипт добавлен в
  `templates/pork/room/room.html.twig` и `templates/poultry/building/dashboard.html.twig`.
  `TableApi.js` не изменялся (остаётся для `/room`).

## 2026-03-24

- **/table — месяцы вперёд:** `monthsForward` в API (`TableDataController`, `TableData`), фронт (`TableApi`, `tablePage`, twig, scss); кнопка «+ Добавить месяц», затем backend-driven без localStorage; откат при ошибке, reviewer (storage + twig).
- **/table — Excel:** градиенты и контраст текста; комментарии (отступы, plain/rich, Arial 11, жирные заголовки секций); `applyLpmData` без пустых ЛПМ-ячеек; рефактор без литерала «Нет данных»; `getCellStyle` без лишнего `getCellColor`.
- **/table — сохранение и ошибки:** единый reload после правок; `PADEZH` после ответа API; `apiErrorAlert.js` + `HistoryModal`/`tablePage`.

## 2026-03-23

- **Excel:** градиент 50/50 в ExcelJS; единый reload после save; алерты падежа; контраст текста на градиенте; убран мок-экспорт, легенда ЛПМ с API; рефреш после POST ЛПМ с `preserveExpandedMonths`.
- **Скилл:** `.cursor/skills/iterate/SKILL.md` (worker ↔ reviewer).

## 2026-03-13

- Климат/модалки: шаблоны в app, `SensorChart` в sensor-bundle, pork+poultry блоки, календарь/легенда, `templates/components`, poultry building (мероприятия, ЛПМ).

## 2026-03-12

- Лаборатория: create, interpretation, poll, reviewer, кнопка «Интерпретировать».
- Контроллеры Pork/Poultry плоско; общие API History/Lab/Lpm/Calendar; удалён `CompletedLpmSchemeRowData`.
- Poultry: `HeaderData`/`PlacementData`, миграции feed/water, dashboard, фикстуры.
- **module_config** PORK/POULTRY, mutex, `/admin/modules`.

## 2026-03-11

- `ResourceHistory` вместо FakeData; `LoadAuditDataCommand` poultry; бэкенд корпусов птиц.

## 2026-03-10

- **module_config:** БД, админка, subscriber.
- **shared DB** для ametist-excel-parser; **analytics-bundle**; reviewer; парсер в бандле + `MortalityRecorder`.

## 2026-03-06

- **pharmacy-bundle**, маршруты poultry, **mock-scenarios-bundle**, SCSS/JS poultry (`buildingsFilter`).
- **Экспорт /table в Excel** (ExcelJS, `tableExport.js`, issue134/136), twig таблицы.

## 2026-03-05

- `Controller/Pork`, route-loaders, шаблоны pork; **ai_dialog.animal_type NULL** (миграция + резолвер).

## 2026-03-04

- **packages/shared:** интерфейсы Vet/Audit БД.
- Оптимизация `/rooms/{id}` (индекс, climate history API).
- Удалён `poultry/app.js`, shared SCSS dashboard/charts.

## 2026-03-03

- **/table:** бэкенд вместо моков (фазы 1–4): `TableData`, API, write-контроллеры, `TableApi`, отгрузка/постановка групп.
- Мультивид: миграции `animal_type`, `PoultryGroup`, AI/sensor bundles, room status, RabbitMQ, сборка ассетов бандлов.

## 2026-02-26

- Удалена `external_climate`; **ametist-demo-bundle** `/demo`.

## 2026-02-25

- Миграции `day_list` / `placement_date_list`; фикстуры; `ClearPorkGroupJsonCommand`.

## 2026-02-24

- SSE чат: `done`, таймаут 120 с, AbortController.

## 2026-02-20

- Суточные датчики, оси Y, `IntersectionObserver`, миграция батареи/last_data_at.

## 2026-02-19

- Страница **/table:** модалка ячейки, ЛПМ, подсветка, выделение, `tableSelection.js`, документация.
