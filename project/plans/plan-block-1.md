# План реализации — блок 1: развёртывание проекта

План только для **блока 1** из [todo.md](../../todo.md).  
Требования: [ТЗ §7](../telecom-sim-cards-spec.md) (команды), [decisions.md](decisions.md) (стек).

## Цель блока

Подготовить каркас репозитория в `project/`: каталоги, игнор артефактов, `Makefile` с целями для БД, отдельный git.  
Логика миграций, схема и seed — **не в этом блоке** (блоки 2–5).

## Результат после блока 1

```
project/
├── data/                 # создаётся make db-create, не в git
│   └── telecom.db
├── migrations/           # пусто + .gitkeep
├── seeds/
├── scripts/
├── docs/
├── plans/
├── .gitignore
├── Makefile
└── telecom-sim-cards-spec.md
```

Файлов `schema.sql`, `manage_db.py`, миграций и seed **ещё нет**.

## Что входит / не входит

| Входит | Не входит (следующие блоки) |
|--------|----------------------------|
| Каталоги `migrations/`, `seeds/`, `scripts/`, `docs/` | `schema.sql` |
| `.gitignore` | SQL-миграции |
| `Makefile`: `db-create` … `db-check` | `scripts/manage_db.py` |
| `git init` в `project/` | `seeds/seed.sql`, документация в `docs/` |

## Предпосылки

- Решения из [decisions.md](decisions.md): SQLite, файл `data/telecom.db`, Python 3.11+ (понадобится в блоке 5).
- На машине: `make`, `python3` (для заглушек — опционально в блоке 1).

---

## Шаг 1. Каталоги

Создать:

```bash
mkdir -p project/{migrations,seeds,scripts,docs,data}
```

| Каталог | Назначение | В блоке 1 |
|---------|------------|-----------|
| `migrations/` | SQL-миграции | `.gitkeep` |
| `seeds/` | seed-данные | `.gitkeep` |
| `scripts/` | `manage_db.py` | `.gitkeep` |
| `docs/` | документация | `.gitkeep` |
| `data/` | файл БД | без `.gitkeep`; каталог в `.gitignore` |

`data/` не коммитить — появится после `make db-create`.

---

## Шаг 2. `.gitignore`

Файл `project/.gitignore`:

```gitignore
# SQLite
*.db
data/

# Python
*.pyc
__pycache__/
.venv/

# Секреты
.env
```

Проверка: `git check-ignore -v data/telecom.db` после создания БД — путь игнорируется.

---

## Шаг 3. `Makefile`

### Переменные

```makefile
PYTHON ?= python3
DB     ?= data/telecom.db
```

### Цели

| Цель | Поведение в блоке 1 |
|------|---------------------|
| `db-create` | `mkdir -p data`; если нет `$(DB)` — создать пустую SQLite-БД |
| `db-migrate` | Сообщение: «реализуется в блоке 5», `exit 1` |
| `db-seed` | То же |
| `db-reset` | То же |
| `db-check` | Минимум: файл `$(DB)` существует; иначе `exit 1` |

### Пример `db-create` (без manage_db.py)

```makefile
.PHONY: db-create db-migrate db-seed db-reset db-check help

help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

db-create: ## Создать пустой файл SQLite
	mkdir -p data
	@test -f $(DB) || $(PYTHON) -c "import sqlite3; sqlite3.connect('$(DB)').close()"

db-migrate: ## Применить миграции (блок 5)
	@echo "Не реализовано: блок 5 (manage_db.py migrate)"
	@exit 1

db-seed: ## Загрузить seed (блок 5)
	@echo "Не реализовано: блок 5 (manage_db.py seed)"
	@exit 1

db-reset: ## Сброс БД (блок 5)
	@echo "Не реализовано: блок 5 (manage_db.py reset)"
	@exit 1

db-check: ## Проверить наличие файла БД
	@test -f $(DB) || (echo "БД не найдена: $(DB). Запустите: make db-create" && exit 1)
	@echo "OK: $(DB)"
```

После блока 5 цели `db-migrate`, `db-seed`, `db-reset`, `db-check` переключить на `$(PYTHON) scripts/manage_db.py …`.

---

## Шаг 4. Git в `project/`

```bash
cd project
git init
git add .
git status   # убедиться: нет *.db, нет data/telecom.db
git commit -m "chore: bootstrap project layout (block 1)"
```

### Вложенный git и корень курса

- Репозиторий курса (`deepcoding-guides`) может трекать `project/` целиком **или** игнорировать `project/.git`.
- Если оба репозитория активны — зафиксировать выбор в [decisions.md](decisions.md) после согласования.

---

## Шаг 5. Проверка

```bash
cd project
make db-create
make db-check
ls -la data/telecom.db
make db-migrate   # ожидается exit 1 и понятное сообщение
git status
```

---

## Критерии приёмки блока 1

- [ ] Есть `migrations/`, `seeds/`, `scripts/`, `docs/` с `.gitkeep` где нужно
- [ ] `project/.gitignore` исключает `*.db`, `*.pyc`, `.env`, `__pycache__/`
- [ ] `make db-create` создаёт `data/telecom.db`
- [ ] `make db-check` проходит после `db-create`
- [ ] `make help` показывает все пять целей `db-*`
- [ ] `db-migrate` / `db-seed` / `db-reset` завершаются с ошибкой и текстом про блок 5
- [ ] В `project/` выполнен `git init`, первый коммит без файлов БД
- [ ] Пункты блока 1 в [todo.md](../../todo.md) отмечены выполненными

## Оценка

~30 минут.

## После блока 1

Следующий шаг — **блок 2**: `schema.sql` и проектирование таблиц (отдельный план или новый файл в `plans/`).  
Не менять `Makefile` под полную автоматизацию до готовности `manage_db.py` (блок 5).

## Связь с todo.md

```markdown
## Блок 1: Развёртывание проекта
- [ ] Создать структуру директорий: migrations/, seeds/, scripts/, docs/
- [ ] Создать project/.gitignore
- [ ] Создать project/Makefile с целями db-*
- [ ] Инициализировать Git-репозиторий в project/
```
