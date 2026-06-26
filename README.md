# Deepcoding Guides

Deepcoding - это осмысленная разработка с ИИ: программист ускоряет работу агентами, моделями и инструментами, но сам отвечает за архитектуру, качество, безопасность и итоговый код.

Это roadmap-курс для новичков и практикующих разработчиков, которые хотят перейти от хаотичного "вайбкодинга" к управляемой работе с ИИ.

## Для кого

- Разработчики баз данных: SQL, Oracle и тд...
- Веб-разработчики: frontend, backend, fullstack.
- Новички, которые уже умеют писать код, но не понимают, как правильно включить ИИ в работу.
- Команды, которые хотят единые правила работы с Cursor, Claude Code, Codex и похожими инструментами.

## Главная идея

Основная идея вайбкодинга: пишем промпт "сделай мне приложение", не проверяем результат и надеемся, что все работает.

Deepcoding: сначала понимаем задачу, даем ИИ правильный контекст, работаем по шагам, проверяем код тестами, ревью и линтерами, а сложные задачи раскладываем на роли: planner, worker, tester, reviewer.

## Roadmap курса

1. [Мышление Deepcoding](stages/01-mindset.md)
2. [Подготовка инструментов](stages/02-tools-setup.md)
3. [Базовая работа с ИИ](stages/03-ai-basics.md)
4. [Контекст проекта](stages/04-project-context.md)
5. [Правила, инструкции и память проекта](stages/05-rules-and-memory.md)
6. [Планирование задачи](stages/06-task-planning.md)
7. [Реализация фич с агентом](stages/07-agent-implementation.md)
8. [Тесты, ревью и контроль качества](stages/08-quality-control.md)
9. [Работа с файлами и разными форматами данных](stages/09-files-and-data.md)
10. [MCP и внешние инструменты](stages/10-mcp-tools.md)
11. [Skills, commands и reusable workflows](stages/11-skills-and-workflows.md)
12. [Субагенты и параллельная работа](stages/12-subagents.md)
13. [Безопасность работы с ИИ-агентом](stages/13-security.md)
14. [Harness Engineering](stages/14-harness-engineering.md)
15. [ИИ в команде и production](stages/15-team-and-production.md)

## Практический итог курса

После прохождения roadmap разработчик должен уметь:

- ставить ИИ понятные задачи;
- давать правильный контекст;
- планировать фичи перед кодом;
- читать и проверять сгенерированный код;
- писать правила проекта для агентов;
- использовать MCP, skills и commands;
- запускать субагентов;
- проверять качество тестами, ревью и анализом;
- контролировать безопасность;
- строить AI-harness (обзвязку ИИ-инструментами) для команды.

## Минимальный финальный проект

В конце курса каждый участник собирает учебный проект с AI-инфраструктурой (параллельно обогащает документацией реальный проект):

```md
AGENTS.md
task-logs.md
docs/architecture.md
docs/commands.md
docs/ai-workflows.md
.cursor/rules/project.md
.cursor/commands/review.md
```

И показывает полный цикл:

1. постановка задачи;
2. план агента;
3. реализация;
4. тесты;
5. ревью;
6. security check;
7. обновление `task-logs.md`.

## Рекомендуемые источники

- [Cursor: Best practices for coding with agents](https://cursor.com/blog/agent-best-practices)
- [Anthropic: Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- Официальная документация Cursor, Claude Code и Codex.

## Главный принцип

ИИ должен ускорять сильного разработчика, а не заменять инженерное мышление.