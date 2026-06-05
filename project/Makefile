PYTHON ?= python3
DB     ?= data/telecom.db

.PHONY: db-create db-migrate db-seed db-clean db-reset db-check help

help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

db-create: ## Создать пустой файл SQLite
	mkdir -p data
	@test -f $(DB) || $(PYTHON) -c "import sqlite3; sqlite3.connect('$(DB)').close()"

db-migrate: db-create ## Применить миграции к БД
	$(PYTHON) migrate.py $(DB)

db-seed: db-migrate ## Загрузить seed-данные из seeds/*.sql
	@$(PYTHON) -c "import sqlite3,glob; conn=sqlite3.connect('$(DB)'); conn.execute('PRAGMA foreign_keys=ON'); files=sorted(glob.glob('seeds/*.sql')); [conn.executescript(open(f,encoding='utf-8').read()) for f in files]; conn.commit(); conn.close(); print('seed: применено файлов', len(files))"

db-clean: ## Очистить данные из БД (структуру и историю миграций сохранить)
	@$(PYTHON) -c "import sqlite3; c=sqlite3.connect('$(DB)'); c.execute('PRAGMA foreign_keys=OFF'); skip={'migration_history','sqlite_sequence'}; ts=[r[0] for r in c.execute(\"SELECT name FROM sqlite_master WHERE type='table'\")]; ts=[t for t in ts if t not in skip]; [c.execute('DELETE FROM '+t) for t in ts]; c.commit(); c.close(); print('очищено таблиц:', len(ts))"

db-reset: ## Сброс БД (блок 5)
	@echo "Не реализовано: блок 5 (manage_db.py reset)"
	@exit 1

db-check: ## Проверить наличие файла БД
	@test -f $(DB) || (echo "БД не найдена: $(DB). Запустите: make db-create" && exit 1)
	@echo "OK: $(DB)"
