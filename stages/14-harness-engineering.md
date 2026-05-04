# Этап 14. Harness Engineering

[← К roadmap](../README.md)

Цель: построить среду, где агент работает стабильно, а не каждый раз с нуля.

Harness - это обвязка вокруг модели: правила, инструменты, команды, skills, MCP, тесты, документация, логи, ограничения.

## Из чего состоит хороший harness

- Понятная структура проекта.
- `AGENTS.md` / `.cursor/rules`.
- Команды проверки.
- `task-logs.md`.
- Архитектурная документация.
- Skills для частых задач.
- MCP для внешних данных.
- Автотесты.
- Security-ограничения.
- Review workflow.

## Пример зрелого проекта

```md
project/
  AGENTS.md
  task-logs.md
  docs/
    architecture.md
    commands.md
    ai-workflows.md
  .cursor/
    rules/
      backend.md
      frontend.md
      security.md
    commands/
      review.md
      write-tests.md
```

## Домашнее задание

- Создать минимальный AI-harness для учебного проекта.
- Добавить карту проекта.
- Добавить команды проверки.
- Добавить один reusable workflow.
