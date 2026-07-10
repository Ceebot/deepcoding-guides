#!/bin/bash
# Событие beforeShellExecution: Cursor зовёт этот скрипт перед КАЖДОЙ командой агента в терминале.
# На вход из stdin приходит JSON, в нём поле .command — сама команда.
# Правило: в базу можно только смотреть. Меняет данные — запрещаем.

cmd=$(jq -r '.command // ""')

# Команда вообще про нашу базу? Если нет — не наше дело.
if ! printf '%s' "$cmd" | grep -qi 'telecom\.db'; then
    jq -n '{permission: "allow"}'
    exit 0
fi

# Про базу. А данные меняет?
if printf '%s' "$cmd" | grep -qiE 'insert|update|delete|drop|alter'; then
    jq -n '{
        permission: "deny",
        user_message: "Команда меняет данные в БД. Разрешено только чтение.",
        agent_message: "Запись в telecom.db запрещена. Читать можно, менять — только миграцией."
    }'
    exit 0
fi

# Про базу, но только читает — пропускаем.
jq -n '{permission: "allow"}'
