# SPB Landmarks — карта Санкт-Петербурга (Roblox)

Скелет проекта по ТЗ v1.4: прогулочная карта (Exploration / Walking Simulator)
с фото-точками, днём/ночью, ненавязчивой монетизацией и фундаментом под
Roleplay v2.0.

Стек (п.17 ТЗ): **Rojo + Rokit + Wally**, **ProfileStore**, **ZonePlus**,
**TopbarPlus**, **Promise**, **Trove**. Код — Luau (`--!strict` там, где уместно),
проверяется **Selene**, форматируется **StyLua**.

---

## Быстрый старт

```bash
# 0. Клонирование (ZonePlus — сабмодуль, поэтому обязательно --recurse-submodules)
git clone --recurse-submodules git@github.com:akoffice933-maker/spb-landmarks.git
cd spb-landmarks

# 1. Инструменты (версии зафиксированы в rokit.toml)
rokit install

# 2. Зависимости (в Wally-реестре: ProfileStore/TopbarPlus/Promise/Trove)
wally install

# 3. Если клонировали без --recurse-submodules — подтяните ZonePlus:
git submodule update --init

# 4. Запуск синхронизации с Roblox Studio
rojo serve
# в Studio: Rojo-плагин -> Connect

# 5. Разовая сборка плейса
rojo build -o SPB-Landmarks.rbxl
```

В Studio включите **Studio Access to API Services**, если хотите реальный
DataStore; без него всё работает на `ProfileStore.Mock` (см. ниже).

---

## Что уже работает

Всё нижеописанное — код. Карту-заглушку (зоны, силуэты, фонари, скамейки,
таблички) генерирует скрипт `BootstrapProject.server.lua`, чтобы проект был
играбельным с первого запуска.

| Система | Файлы | Статус |
|---|---|---|
| Профили игроков | `ServerScriptService/Data/*` | ProfileStore (+ Mock в Studio) |
| Монетизация | `ServerScriptService/Monetization/*` | Game Pass кэш, ProcessReceipt идемпотентно |
| Зоны / Photo Spots | `ServerScriptService/Zones`, `Interaction/PhotoSpotService` | ZonePlus, серверная валидация |
| Интерьеры | `Interaction/InteriorService` + блокаут 3 залов | Входы бесплатны; закрытый зал за «Интерьерным пропуском» |
| Инфо-таблички | `Interaction/InfoService` | Базовый текст всем, расширенный с «Гидом» |
| Указатели улиц | BootstrapProject.server.lua | Физические таблички над улицами (п.5.1) |
| День/ночь | `Lighting/LightingController` | 4 пресета + цикл 25 мин + фонари авто |
| Звук | `Zones/ZoneClient` + `Audio/UISoundClient` | Каналы Ambient/Music/UI, UI-звуки авто, слайдеры в настройках |
| Спавны / телепорты | `Spawn/SpawnService` | Выбор спавна + платный FastTravel |
| Онбординг | `UI/OnboardingUI` | 4 слайда, один раз |
| UI | `StarterPlayerScripts/UI/*` | Магазин, коллекция, HUD, настройки — кодом |
| Топбар | `UI/TopbarUI` | TopbarPlus: иконки без попапов (п.14.3) |

## Структура проекта

```
src/
├── ReplicatedStorage/
│   ├── Shared/
│   │   ├── Remotes.lua           -- единая точка доступа к RemoteEvent/RemoteFunction
│   │   ├── Config/
│   │   │   ├── Landmarks.lua     -- СПРАВОЧНИК: зоны, спавны, достоприм., тексты, настройки
│   │   │   ├── LightingPresets.lua -- day/sunset/whiteNights/night пресеты
│   │   │   ├── GamePasses.lua    -- реестр пассов (id=0 — заглушки до публикации)
│   │   │   ├── DeveloperProducts.lua -- реестр продуктов + фильтры
│   │   │   └── Theme.lua         -- палитра/шрифты/рамки UI
│   │   └── Util/
│   │       ├── Signal.lua        -- простая реализация сигналов
│   │       └── Validate.lua      -- вся валидация входящих данных (п.16)
├── ServerScriptService/
│   ├── Main.server.lua           -- порядок запуска сервисов
│   ├── BootstrapProject.server.lua -- генератор блокаута (ОТКЛЮЧИТЬ на проде)
│   ├── Data/
│   │   ├── ProfileTemplate.lua   -- схема профиля (п.5.2, поля v2.0 заложены)
│   │   └── PlayerDataService.lua -- ProfileStore сессии, мутаторы, PurchaseLog
│   ├── Monetization/
│   │   ├── MonetizationController.lua -- пассы: кэш, фичи, промпты
│   │   └── ProductHandler.lua    -- ProcessReceipt: idempotency + SaveNow
│   ├── Zones/ZoneService.lua     -- ZonePlus-обвязка: зоны, фото-точки, эмбиент
│   ├── Lighting/LightingController.lua -- цикл суток, пресеты, фонари, «Хронос»
│   ├── Interaction/
│   │   ├── PhotoSpotService.lua  -- валидация фото-точек, PhotoCount
│   │   ├── InfoService.lua       -- таблички (InfoBoard тег + InfoId)
│   │   └── OnboardingService.lua -- флаг онбординга
│   └── Spawn/SpawnService.lua    -- выбор спавна, RespawnLocation, FastTravel
└── StarterPlayerScripts/
    ├── ClientMain.client.lua     -- точка входа клиента
    ├── Data/
    │   └── DataClient.lua        -- клиентский кэш профиля
    ├── UI/
    │   ├── UIInstances.lua       -- базовая фабрика UI + тосты
    │   ├── SettingsClient.lua    -- дебаунс отправки настроек на сервер
    │   ├── TopbarUI.lua          -- иконки TopbarPlus
    │   ├── ShopUI.lua            -- магазин (Game Pass + продукты)
    │   ├── CollectionUI.lua      -- сетка «открытых мест»
    │   ├── InfoBoardUI.lua       -- читалка табличек
    │   ├── HUDUI.lua             -- зона, часы, подсказки, мини-панель «Хроноса»
    │   ├── SettingsUI.lua        -- ползунки громкости
    │   ├── SpawnChoiceUI.lua     -- выбор точки старта
    │   ├── TeleportFade.lua      -- затемнение при телепортации
    │   └── OnboardingUI.lua      -- туториал из 4 экранов
    ├── Zones/ZoneClient.lua      -- эмбиент/музыка по зонам (SoundGroup, кроссфейд)
    ├── Audio/UISoundClient.lua   -- UI-звуки: клик автоподключён, shutter, тосты
    └── PhotoSpot/PhotoModeClient.lua -- скрытие UI + рамка + фильтры
```

Workspace при игре (п.6 ТЗ — содержимое генерирует Bootstrap):

```
Workspace
├── Map/{Zones,Buildings,Props,Water}
├── Spawns/Spawn_{Dvortsovaya,Nevsky,Petropavlovka}
├── PhotoSpots/PhotoSpot_<landmarkId>   (атрибут LandmarkId)
├── InfoBoards/InfoBoard_<name>         (тег InfoBoard + атрибут InfoId)
└── FastTravel/<LandmarkId>             (невидимые точки телепорта)
```

## Как добавить контент

1. **Новая достопримечательность** — запись в
   `Shared/Config/Landmarks.lua` (+секция зоны в `Landmarks.Zones` при
   необходимости). Дальше зоны/таблички/коллекция/магазин подхватят её сами
   по `landmarkId`.
2. **Game Pass** — запись в `GamePasses.lua`. В коде гейтинг через
   `MonetizationController.HasFeature(player, "FeatureName")` — новых
   проверок ID нигде писать не нужно.
3. **Developer Product** — запись в `DeveloperProducts.lua`. Есть три типа
   выдачи: `FastTravel`, `Filter`, `FilterPack`.
4. **Пресет освещения** — добавьте в `LightingPresets.Modes` и в `ModeOrder`
   + автоматику в `AutoSchedule`.

## Критические замечания по эксплуатации

- **ID монетизации = 0.** `ProcessReceipt` не будет вызываться, пока в
  `DeveloperProducts.lua` не проставлены реальные id (в том числе потому, что
  в Studio продукт с id 0 невозможно купить). Перед публикацией опыта
  проставьте реальные id и сделайте тест-покупку.
- **Bootstrap выключать на реальной карте.** В `BootstrapProject.server.lua`
  установите `BOOTSTRAP_ENABLED = false` (или удалите скрипт), когда
  появится построенная карта.
- **`ProfileStore.Mock` в Studio.** `PlayerDataService.STUDIO_USES_MOCK_STORE = true`
  — данные в Studio не затирают боевые ключи. На проде Mock не используется.
- **Схема профиля уже v2.0-ready** (`Money`, `Inventory`, `Housing`), поэтому
  миграций через Reconcile достаточно — старые профили получат новые поля
  мягко.
- **Серверная валидация везде.** Любой remote валидируется
  (`Shared/Util/Validate.lua`); добавляя новые remotes — добавляйте проверки
  туда и держите принцип: клиент никогда не доверен.
- **Звуки и картинки — заглушки.** `rbxassetid://0` меняйте на реальные
  ассеты; до этого эмбиент и изображения просто не проигрываются (Gracefully
  degrades — код это переживает).

## Проверка качества

```bash
stylua src        # форматирование (config: stylua.toml)
selene src        # линтер (config: selene.toml)
```

Чек-листы оптимизации и приёмки — в ТЗ (п.8, п.10). Перед релизом пройдите
их на реальной карте: бюджет света (п.4.4), Streaming (п.8.1), DoD зданий
(п.3.4).
