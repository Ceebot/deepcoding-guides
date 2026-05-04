# Этап 5. Правила, инструкции и память проекта

[← К roadmap](../README.md)

Цель: сделать так, чтобы ИИ помнил правила проекта не из головы разработчика, а из файлов.

## Базовые файлы

- `AGENTS.md` - общие правила для AI-агентов.
- `CLAUDE.md` - правила для Claude Code.
- `CURSOR.md` или `.cursor/rules/*` - правила для Cursor.
- `task-logs.md` - короткая история важных изменений.
- `docs/architecture.md` - карта архитектуры.
- `docs/commands.md` - команды запуска, тестов, миграций.

## Что писать в правилах

- Стек проекта.
- Команды: test, lint, build, typecheck.
- Стиль кода.
- Запреты: не трогать миграции без спроса, не менять публичный API, не добавлять зависимости без причины.
- Где искать документацию.
- Как делать ревью.

## Пример `AGENTS.md`

```md
# AGENTS.md

## Commands

- `npm test` - run tests.
- `npm run lint` - run linter.
- `npm run build` - production build.

## Rules

- Prefer existing patterns.
- Do not add dependencies without approval.
- After code edits run relevant tests.
- Never commit secrets.

## Project Map

- `src/api` - backend routes.
- `src/domain` - business logic.
- `src/ui` - React components.
```

## Зачем нужен `task-logs.md`

ИИ часто теряет историю длинной работы. Короткий лог помогает восстановить контекст:

```md
# task-logs.md

2026-05-03
- Added CSV export for orders.
- Tests: `npm test -- orders`.
- Risk: timezone formatting still needs manual check.
```

## Домашнее задание

- Создать черновик `AGENTS.md` для учебного проекта.
- Добавить команды запуска и тестов.
- Добавить 5 правил, где ИИ чаще всего ошибается.
- Создать `task-logs.md` и записать первое изменение.
