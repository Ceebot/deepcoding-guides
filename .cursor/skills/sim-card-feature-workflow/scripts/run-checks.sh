#!/usr/bin/env bash
# Пересобрать учебную БД и прогнать smoke-проверку.
# Агент запускает этот скрипт вместо того, чтобы каждый раз печатать команды руками.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
make -C "$ROOT/project" db-clean db-migrate db-seed

echo "--- smoke-проверка ---"
make -C "$ROOT/project" db-check
