#!/bin/bash
# Событие stop: агент закончил цикл и собирается замолчать.
# Заблокировать его нельзя, но можно вернуть followup_message — и агент получит
# это как следующее сообщение от пользователя.
# Правило AGENTS.md: менял project/ — обнови task_logs.md.

cd "$(git rev-parse --show-toplevel)" || exit 0

# Агент трогал тестовый проект?
if git status --porcelain project/ | grep -q .; then
    # А журнал обновил?
    if ! git status --porcelain task_logs.md | grep -q .; then
        jq -n '{
            followup_message: "Ты менял файлы в project/, но не обновил task_logs.md. Добавь запись по скиллу update-task-log."
        }'
        exit 0
    fi
fi

# Всё в порядке — молчим, агент завершает работу.
exit 0
