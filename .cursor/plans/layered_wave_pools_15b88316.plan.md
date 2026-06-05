---
name: Layered Wave Pools
overview: Добавить до 3 параллельных визуальных волн через структуру BoardView -> CellFxLayer -> CellFxPool, с очередью ходов сверх лимита и валидатором, который принимает только клики по цвету, реально расширяющему активную область.
todos:
  - id: cell-fx-layer
    content: Добавить CellFxLayer и CellFxLayerManager для трёх независимых пулов FX
    status: completed
  - id: scene-layer-tree
    content: Обновить игровые сцены на структуру BoardView -> CellFxLayerManager -> CellFxLayer -> CellFxPool
    status: completed
  - id: available-values-cache
    content: Добавить кэш доступных для клика типов ячеек и обновлять его после изменения активной зоны
    status: completed
  - id: transition-queue
    content: Переделать TransitionPlayer на 3 активных слоя и очередь pending waves
    status: completed
  - id: game-wire
    content: "Обновить game.gd: использовать менеджер слоёв, разрешить валидные клики во время волн, очищать всё при restart"
    status: completed
  - id: smoke-test
    content: Проверить пограничный фильтр, 3 активные волны, очередь 4-го хода и restart
    status: completed
isProject: false
---

# План: Слои Волн И Пулы FX

## Подход

Ваше направление хорошее: `BoardModel` уже обновляется сразу в `apply_move()`, поэтому вторая волна может считаться от финального логического состояния, даже если первая ещё визуально проигрывается. Главное не смешивать логическую модель и визуальные слои: модель решает, какой ход применим, а `TransitionPlayer` управляет слоями анимации.

Текущая точка изменения:

```84:91:/home/aleksey/godot/проекты/filling/scenes/game/game_small.tscn
[node name="BoardView" type="TileMapLayer" parent="BoardField"]
tile_map_data = PackedByteArray("...")
tile_set = SubResource("TileSet_lmrul")
script = ExtResource("4_view")

[node name="CellFxPool" type="Node2D" parent="BoardField/BoardView"]
z_index = 10
script = ExtResource("9_pool")
```

Целевая структура во всех игровых сценах:

```text
BoardView
└── CellFxLayerManager
    ├── CellFxLayer0
    │   └── CellFxPool
    ├── CellFxLayer1
    │   └── CellFxPool
    └── CellFxLayer2
        └── CellFxPool
```

## Важные правила

- Ход разрешён только если выбранный тип ячейки входит в кэш `available_move_values` — список типов пограничных клеток, которые реально расширят активную область.
- Клик по активной зоне или по непограничной клетке ничего не запускает, потому что их тип не попадёт в `available_move_values`.
- `BoardModel.apply_move()` остаётся источником истины и применяется сразу. Поэтому следующая волна считается уже от нового финального состояния.
- Одновременно визуально активны максимум 3 волны. Если все 3 слоя заняты, новый валидный ход попадает в очередь.
- Когда слой завершает волну, он освобождается, переупорядочивается вниз, а активные слои получают корректный `z_index`, чтобы новые волны были выше старых.

## План Реализации

1. Добавить `widgets/cell_fx/cell_fx_layer.gd`.
   - `CellFxLayer` будет `Node2D` с дочерним `CellFxPool`.
   - Хранит `wave_id`, `busy`, `generation` и методы `claim(wave_id)`, `release()`, `stop_all()`, `get_pool()`.
   - Визуальный порядок задаётся через `z_index` слоя, а не отдельных `CellFx`.

2. Добавить `widgets/cell_fx/cell_fx_layer_manager.gd`.
   - Создаёт или находит 3 слоя.
   - Выдаёт свободный слой для новой волны.
   - Если свободного слоя нет, сообщает `null`, а `TransitionPlayer` ставит ход в очередь.
   - После завершения волны освобождает слой и переупорядочивает слои: свободные вниз, активные сверху по времени запуска.

3. Обновить сцены `scenes/game/game_small.tscn`, `game_large.tscn`, `game_random.tscn`.
   - Заменить прямой `CellFxPool` под `BoardView` на `CellFxLayerManager`.
   - Убрать зависимость `game.gd` от конкретного `$BoardField/BoardView/CellFxPool`.

4. Добавить в `widgets/board/board_model.gd` кэш доступных типов ходов.
   - Добавить поле `available_move_values: Array[int]` или `Dictionary[int, bool]` для O(1) `has`.
   - Добавить метод `refresh_available_move_values()`:
     - найти активную область от `start_coord` по текущему значению;
     - собрать типы соседних клеток за пределами активной области;
     - исключить текущий тип активной области;
     - сохранить результат в `available_move_values`.
   - Вызывать обновление после инициализации поля, импорта, restore/restart и после каждого успешного `apply_move()`.

5. Обновить `scenes/game/game.gd`.
   - Хранить ссылку на `cell_fx_layer_manager`, а не на один пул.
   - Убрать блокировку `session.is_animating` как запрет хода.
   - При клике брать `selected_color` из `BoardModel` и валидировать через `available_move_values.has(selected_color)`.
   - Если ход валиден, сразу применять `board_model.apply_move()`, регистрировать ход и отдавать `move_result` в `TransitionPlayer`.
   - Для restart вызывать `transition_player.stop_all()` или `cell_fx_layer_manager.stop_all()` и очищать очередь.

6. Обновить `widgets/game_rules/move_validator.gd`.
   - Заменить текущую блокировку `ANIMATING` на проверку `board_model.available_move_values.has(next_value)`.
   - Добавить причину вроде `NOT_EXPANDING_MOVE`.
   - Валидатор не должен сам обходить поле каждый клик; его задача — простой `contains` по актуальному массиву/словарю допустимых типов.

7. Обновить `widgets/game_transition/transition_player.gd`.
   - Вернуть поддержку нескольких волн, но ограничить её через `max_active_waves = 3` и менеджер слоёв.
   - Для каждой волны брать отдельный `CellFxLayer`, а в jobs передавать именно `layer.get_pool()`.
   - Если все слои заняты, сохранять pending wave в очередь и запускать её после освобождения слоя.
   - Сигнал `active_waves_changed` должен учитывать активные плюс, при необходимости, queued. Для HUD лучше показывать `Переход...`, пока есть активные визуальные волны или очередь.

8. Обновить `widgets/game_transition/wave_cell_playback.gd`.
   - Не менять логику клетки радикально: она уже принимает `fx_pool` и работает через `play_at_async()`.
   - Проверить, что координаты `overlay_pos` остаются локальными к `BoardView`; так как слой будет дочерним у `BoardView`, позиционирование сохранится.

9. Проверка.
   - Клик по активной зоне не запускает ход.
   - Клик по непограничной клетке не запускает ход.
   - Клик по типу из `available_move_values` запускает волну.
   - После каждой успешной смены активной зоны `available_move_values` обновляется и следующий клик проверяется только через `contains`.
   - Второй и третий валидные клики во время первой волны запускают волны на слоях выше.
   - Четвёртый валидный клик попадает в очередь и стартует после освобождения слоя.
   - Restart гасит все слои, очередь и возвращает поле в консистентное состояние.

## Замечания

- Очередь ходов будет хранить уже рассчитанный `move_result`, потому что логическая модель обновляется сразу при клике. Это соответствует требованию считать каждый следующий ход от финального состояния.
- Визуально возможна ситуация, когда игрок кликает по клетке, которая ещё выглядит старой, но логически уже имеет новое значение. Мы приняли модельный вариант: выбранный цвет берётся из `BoardModel`, а не из видимого верхнего слоя.
- Если позже захотим сделать поведение строго по видимой клетке, понадобится отдельный визуальный hit-test по слоям, это существенно сложнее и лучше не смешивать с текущей задачей.