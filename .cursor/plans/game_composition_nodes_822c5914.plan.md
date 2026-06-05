---
name: Game Composition Nodes
overview: Внедрить переиспользуемую композицию игры с явными узлами в дереве сцены, где BoardModel и GameSessionState представлены как пустые Node со скриптами. План не мигрирует старую реализацию, а добавляет новый компонентный каркас для дальнейшей интеграции.
todos:
  - id: create-composed-scene
    content: Добавить новую сцену GameRoot с полным деревом компонентных узлов
    status: completed
  - id: implement-core-nodes
    content: Реализовать BoardModel и GameSessionState как пустые Node со скриптами домена/состояния
    status: completed
  - id: wire-input-validation
    content: Добавить InputController и MoveValidator с единым контрактом ValidationResult
    status: completed
  - id: implement-view-transition-hud
    content: Сделать TileMap BoardView, TransitionPlayer и HUDController с базовой интеграцией
    status: completed
  - id: orchestrate-and-smoke-test
    content: Связать pipeline в GameRoot и проверить ключевые сценарии ходов
    status: completed
isProject: false
---

# План реализации композиции сцены игры

## Цель
Собрать новый модульный каркас `GameRoot` для будущих больших карт (включая пустоты/непрямоугольные формы), где все ключевые роли явно видны в дереве нод, включая `BoardModel` и `GameSessionState` как пустые `Node` со скриптами.

## 1) Создать новую сцену-композицию
- Добавить новую сцену-контейнер (например, `res://scenes/game_composed/game_composed.tscn`) с деревом:
  - `GameRoot` (Node2D)
  - `BoardModel` (Node)
  - `GameSessionState` (Node)
  - `BoardView` (TileMapLayer/TileMap)
  - `InputController` (Node)
  - `MoveValidator` (Node)
  - `TransitionPlayer` (Node)
  - `HUDController` (CanvasLayer/Control)
- Текущую сцену игры не менять; новая сцена живет параллельно как новая архитектура.

## 2) Добавить скрипт-оркестратор GameRoot
- Создать скрипт `GameRoot`, который в `_ready()` получает ссылки на дочерние узлы и связывает сигналы/вызовы.
- Зафиксировать базовый pipeline хода:
  - `InputController` эмитит `cell_selected(coord)`
  - `MoveValidator.validate(...)`
  - `BoardModel.apply_move(...)`
  - `BoardView.apply_changes(...)`
  - `TransitionPlayer.play(...)`
  - обновление `GameSessionState` и `HUDController`
- Ввести простое состояние фазы матча в `GameRoot`: `IDLE`, `ANIMATING`, `GAME_OVER`.

## 3) Реализовать Node-скрипт BoardModel (пустой узел + логика)
- Создать `BoardModel` как `extends Node` без дочерних визуальных элементов.
- Перенести в него доменную логику поля (без input/UI/анимации):
  - хранение клеток (`Dictionary[Vector2i, int]` или стартовый прямоугольный режим),
  - соседей,
  - flood-fill,
  - проверку solved,
  - возврат `MoveResult` с `changed_cells`.
- Оставить совместимость с текущим подходом цветов `1..8`.

## 4) Реализовать Node-скрипт GameSessionState (пустой узел + состояние матча)
- Создать `GameSessionState` как `extends Node` без визуала.
- Хранить только runtime-состояние матча:
  - число ходов,
  - лимит ходов,
  - флаги активности/паузы,
  - опционально историю ходов (для будущего replay/undo).
- Добавить методы `start_new_game(...)`, `register_move(...)`, `can_continue()`.

## 5) Реализовать BoardView на TileMap
- Создать `BoardView` на базе `TileMapLayer/TileMap` и API:
  - `render_full(board_model)`
  - `apply_changes(changed_cells)`
  - `coord_from_local_pos(local_pos)`
- Отрисовывать только существующие клетки; пустоты не рисовать.

## 6) Реализовать InputController и MoveValidator
- `InputController` получает ссылку на `BoardView` и переводит input в координату клетки.
- `MoveValidator` принимает `GameSessionState` + `BoardModel` и возвращает `ValidationResult` (`ok/reason`).
- Причины отказа стандартизировать строковыми кодами: `ANIMATING`, `GAME_OVER`, `NO_MOVES`, `INVALID_CELL`, `NO_OP_MOVE`.

## 7) Реализовать TransitionPlayer и интеграцию с HUD
- `TransitionPlayer` инкапсулирует только визуальный переход, с сигналами `started/finished`.
- `HUDController` подписывается на изменение `GameSessionState` (ходы, конец игры).
- `GameRoot` блокирует вход в фазе `ANIMATING` до `finished`.

## 8) Первичная валидация и дымовой прогон
- Проверить запуск новой сцены отдельно от старой.
- Проверить 4 сценария:
  - валидный ход,
  - клик в пустоту,
  - no-op ход,
  - блокировка кликов во время перехода.
- Убедиться, что структура дерева нод отражает архитектуру и читается в редакторе.

## Файлы, которые будут добавлены/затронуты
- Новые:
  - [res://scenes/game_composed/game_composed.tscn](res://scenes/game_composed/game_composed.tscn)
  - [res://scenes/game_composed/game_root.gd](res://scenes/game_composed/game_root.gd)
  - [res://scenes/game_composed/board_model.gd](res://scenes/game_composed/board_model.gd)
  - [res://scenes/game_composed/game_session_state.gd](res://scenes/game_composed/game_session_state.gd)
  - [res://scenes/game_composed/input_controller.gd](res://scenes/game_composed/input_controller.gd)
  - [res://scenes/game_composed/move_validator.gd](res://scenes/game_composed/move_validator.gd)
  - [res://scenes/game_composed/transition_player.gd](res://scenes/game_composed/transition_player.gd)
  - [res://scenes/game_composed/hud_controller.gd](res://scenes/game_composed/hud_controller.gd)
  - [res://scenes/game_composed/board_view_tilemap.gd](res://scenes/game_composed/board_view_tilemap.gd)
- Существующие (минимально):
  - [res://scenes/main/...](res://scenes/main/) — только если потребуется добавить кнопку/переход на новую сцену для ручного запуска.

## Критерии готовности
- В дереве новой сцены явно присутствуют `BoardModel` и `GameSessionState` как пустые `Node` со скриптами.
- Ход обрабатывается через композицию компонентов, без прямой логики поля в view/input.
- Новая сцена работает автономно и не ломает текущую `scenes/game` реализацию.