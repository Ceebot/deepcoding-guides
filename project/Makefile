PYTHON ?= python3
DB     ?= data/telecom.db
CLI    := scripts/manage_db.py

.PHONY: db-create db-migrate db-seed db-rollback db-reset db-check db-audit test help

help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

db-create: ## Создать пустой файл SQLite
	mkdir -p $(dir $(DB))
	@test -f $(DB) || $(PYTHON) -c "import sqlite3; sqlite3.connect('$(DB)').close()"

db-migrate: ## Применить миграции к БД
	$(PYTHON) $(CLI) --db $(DB) migrate

db-seed: ## Загрузить seed-данные
	$(PYTHON) $(CLI) --db $(DB) seed

db-rollback: ## Откатить последнюю миграцию
	$(PYTHON) $(CLI) --db $(DB) rollback

db-reset: ## Сбросить БД и загрузить seed
	$(PYTHON) $(CLI) --db $(DB) reset

db-check: ## Smoke-проверка БД
	$(PYTHON) $(CLI) --db $(DB) check

db-audit: ## Аудит целостности БД
	$(PYTHON) scripts/audit_db.py --db $(DB)

test: ## Запустить pytest
	$(PYTHON) -m pytest
