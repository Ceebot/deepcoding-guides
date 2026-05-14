# Этап 2. Подготовка инструментов

[← К roadmap](../README.md)

Цель: собрать рабочую среду, где ИИ может не только отвечать, но и работать с проектом.

## Основные инструменты

### Полноценные IDE (работа с проектами, автодополнение кода)

- [Cursor](https://cursor.com/download) - IDE на основе VSCode с ИИ-агентами, правилами, контекстом, ревью и browser/debug режимами.
- [Antigravity](https://antigravity.google/download) - альтернативный вариант Cursor от Google, тоже на основе VSCode и с похожими возможностями.

### Desktop-инструменты (программы, не имеющие встроенного редактора кода, но имеющие просмотр файлов проекта, лучше работать в связке с IDE)

- [Claude Code](https://claude.com/download) - сильный CLI-агент для работы в терминале.
- [Codex](https://developers.openai.com/codex/app) - агентная работа с кодом, задачами и репозиторием.

### Расширения для VSCode

![Claude Code for VS Code](../references/screenshots/claude-vscode.png)

![Codex – OpenAI’s coding agent](../references/screenshots/codex-vscode.png)

![Qwen Code Companion](../references/screenshots/qwen-vscode.png)

![Cline](../references/screenshots/cline-vscode.png)

![Kilo Code: AI Coding Agent, Copilot, and Autocomplete](../references/screenshots/kilocode-vscode.png)

### CLI-инструменты (работа с проектами в терминале)

- Codex
- Claude
- QWEN Code
- OpenCode

## Модели и стоимость

Не всегда нужно использовать самую дорогую модель.

- Сильная модель: планирование, архитектура, сложный debug, ревью.
- Средняя модель: обычная реализация, тесты, документация.
- Дешевая модель: массовые правки, черновики, простые преобразования, реализация плана.

Пример связки: умная модель составляет план, более дешевая модель выполняет понятные шаги. Это экономит токены и деньги.

## Домашнее задание

- Установить минимум один агентный инструмент: Cursor, Claude Code или Codex.
- Открыть свой учебный проект.
- Попросить ИИ объяснить структуру проекта.
- Настроить запуск тестов или линтера одной командой.

