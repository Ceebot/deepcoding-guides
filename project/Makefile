PYTHON ?= python3
DB     ?= data/telecom.db

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
