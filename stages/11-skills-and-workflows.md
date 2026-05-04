# Этап 11. Skills, commands и reusable workflows

[← К roadmap](../README.md)

Цель: не писать один и тот же prompt каждый день.

## Что такое skill

Skill - это инструкция или мини-workflow, который агент подгружает, когда задача подходит. Например:

- review skill;
- brainstorming skill;
- security check skill;
- release notes skill;
- API testing skill;
- project-specific feature workflow.

## Что такое command

Command - короткая команда для частого сценария:

```md
/review
/fix-issue 123
/write-tests
/update-task-log
/create-pr
```

## Пример skill-идеи

```md
# Feature Workflow Skill

1. Изучи задачу.
2. Найди похожие места в проекте.
3. Составь план.
4. Реализуй минимальный diff.
5. Добавь тесты.
6. Запусти проверки.
7. Обнови task-logs.md.
```

## Домашнее задание

- Найти повторяющийся workflow в своей работе.
- Описать его в Markdown.
- Прогнать через ИИ 2 раза и улучшить инструкцию.
