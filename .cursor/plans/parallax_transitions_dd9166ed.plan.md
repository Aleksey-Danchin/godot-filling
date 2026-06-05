---
name: Parallax Transitions
overview: Добавить фоновые параллакс-слои для главного меню и игры, fade-переходы из меню в игру и стартовую анимацию появления игрового поля без изменения `.godot/`. Решение будет опираться на существующие `main_scene.gd`, `game.gd`, `BoardCamera` и ассеты `assets/New free backgrounds part2/`.
todos:
  - id: parallax-widget
    content: Добавить переиспользуемый виджет параллакса и подключить ассеты background 1/2/3/4
    status: completed
  - id: menu-parallax
    content: Подключить медленный параллакс background 1 в главное меню
    status: completed
  - id: game-parallax
    content: Подключить случайный camera-follow параллакс в игровые сцены
    status: completed
  - id: fade-transition
    content: Добавить fade out/fade in для переходов меню->игра, игра->меню и play again
    status: completed
  - id: board-intro
    content: Добавить стартовый tween перемещения BoardField справа налево
    status: completed
  - id: verify-visuals
    content: "Проверить порядок слоёв: background ниже поля, FX/HUD выше, переходы без мерцания"
    status: completed
isProject: false
---

# План: Параллакс, Fade И Старт Поля

## Подход

Добавить переиспользуемые виджеты в `widgets/`: один для параллакс-фона, один для fade-перехода. В главном меню фон будет медленно двигаться сам, в игре фон будет следовать за `BoardCamera`. Стартовое поле в `game.gd` получит короткий tween позиции `BoardField` справа налево до текущей целевой позиции.

## 1. Параллакс-Фон

- Создать `widgets/background/parallax_background.gd`.
- Поддержать два режима:
  - `MENU_DRIFT`: медленное движение фона по времени;
  - `CAMERA_FOLLOW`: смещение слоёв относительно позиции `Camera2D`.
- Ассеты:
  - главное меню: `res://assets/New free backgrounds part2/background 1/`;
  - игры: случайно выбрать один из `background 2`, `background 3`, `background 4`.
- Использовать набор слоёв `1.png`, `2.png`, `3.png`, `4.png`, если они доступны; для `background 2` учесть `5.png`.
- Добавить фон как нижний узел в `scenes/main/main_scene.tscn` и игровые сцены `game_small.tscn`, `game_large.tscn`, `game_random.tscn`, `game.tscn`.

## 2. Fade-Переходы

- Создать `widgets/screen_transition/screen_fader.gd` или встроенный `ColorRect`-оверлей в `main_scene.tscn`.
- Использовать fade во всех игровых сценариях:
  - `главное меню -> игра`;
  - `игра -> главное меню`;
  - `game over -> play again`.
- Обычные переходы должны занимать суммарно 1.0 с: например `fade_out = 0.5`, `fade_in = 0.5`.
- Стартовый вход в игру из главного меню должен занимать суммарно 1.5 с: например `fade_out = 0.75`, `fade_in = 0.75`.
- В `scenes/main/main_scene.gd` заменить прямые вызовы:

```gdscript
get_tree().change_scene_to_file(GAME_SMALL_SCENE)
```

на helper вроде:

```gdscript
await screen_fader.fade_out()
get_tree().change_scene_to_file(path)
```

- После загрузки игровой сцены выполнить `fade_in` через такой же `ScreenFader` в игровой сцене.
- Для `game over -> play again` и `игра -> главное меню` обновить обработчики в `scenes/game/game.gd`, чтобы они тоже проходили через `ScreenFader`.
- Переходы в настройки/об игре можно оставить без fade, если задача касается только игровых сценариев.

## 3. Стартовая Анимация Поля

- В `scenes/game/game.gd` сохранить текущую позицию `BoardField` как целевую.
- После `_setup_board_for_new_session()` временно поставить `BoardField` правее экрана.
- Tween: поле едет справа налево к `target_position + Vector2(20..40, 0)`, то есть чуть-чуть не доходит до исходной точки.
- На время анимации можно кратко игнорировать клики через флаг `_intro_animating`, чтобы игрок не запускал ход до появления поля.

## 4. Проверка

- Главное меню: `background 1` движется медленно, кнопки остаются поверх.
- Малое/большое/случайное поле: фон выбран случайно из остальных background-наборов.
- В игре фон реагирует на перемещение/zoom камеры, но не мешает `BoardView`, FX и HUD.
- Переходы `меню -> игра`, `игра -> меню`, `game over -> play again` проходят через fade out/fade in с нужными длительностями.
- При рестарте партии стартовая анимация поля либо повторяется, либо остается только для первой загрузки сцены. Рекомендованный вариант: повторять на новую сцену, не повторять на pause restart.