#!/usr/bin/env python3
"""Статическая проверка целостности SPB-Landmarks (п.10, п.16 ТЗ).

Запуск:  python3 tools/check_integrity.py   (из корня проекта)
Выход:   0 — замечаний нет; 1 — есть ошибки; 2 — только предупреждения.

Проверки (все чисто статические, Studio не нужна):
  1. Remotes: каждый Remotes.Names.X, упомянутый в коде, объявлен в реестре;
     объявленные, но нигде не используемые — предупреждение.
  2. Require: каждый require(...) резолвится в существующий файл модуля.
  3. Зоны/интерьеры: все "Interior_*" строки есть в Landmarks.Zones;
     ZoneId/EntryLandmarkId интерьеров существуют; Interior-зоны имеют Music.
  4. Настройки: ключи Landmarks.SETTINGS == ключи ProfileTemplate.Settings.
  5. Пассы: HasFeature(player, "X") ⊆ Features из GamePasses.lua.
  6. Продукты: Grant-типы из DeveloperProducts обрабатываются в ProductHandler.
  7. MoveTo: цели телепорта интерьерных дверей существуют как Name в bootstrap'е.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def lua_files():
    return list(SRC.rglob("*.lua"))


def find_block(text: str, open_regex: str) -> str | None:
    """Извлекает тело `{ ... }` начиная с первой скобки, найденной regex'ом."""
    m = re.search(open_regex, text)
    if not m:
        return None
    i = text.find("{", m.end() - 1)
    if i == -1:
        return None
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[i:j + 1]
    return None


def section(text: str, name: str) -> str | None:
    return find_block(text, rf"local {name}[^\n]*=\s*\{{")


def strip_comments(text: str) -> str:
    """Грубо убирает -- комментарии (строчные И блочные --[[ ]])."""
    text = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.S)
    return re.sub(r"--[^\n]*(\n|$)", r"\1", text)


def top_keys(block: str) -> list[str]:
    return re.findall(r"^\t(\w+) = \{", block, re.M)


# --- 1. Remotes -------------------------------------------------------------
remotes_lua = (SRC / "ReplicatedStorage" / "Shared" / "Remotes.lua").read_text()
declared = set(re.findall(r"^\t(\w+) = \"", find_block(remotes_lua, r"Remotes\.Names = \{") or "", re.M))
referenced: set[str] = set()
for f in lua_files():
    referenced |= set(re.findall(r"Remotes\.Names\.(\w+)", strip_comments(f.read_text())))

for name in sorted(referenced - declared):
    err(f"[remotes] Remotes.Names.{name} используется, но не объявлен в Remotes.lua")
for name in sorted(declared - referenced):
    warn(f"[remotes] Remotes.Names.{name} объявлен, но нигде не используется")

# --- 2. Require paths -------------------------------------------------------
SSS = SRC / "ServerScriptService"
SPS = SRC / "StarterPlayerScripts"
REP = SRC / "ReplicatedStorage"
SERVER_ALIASES = {"Data", "Zones", "Lighting", "Interaction", "Monetization", "Spawn", "Bootstrap"}
WALLY = {
    "Packages.Promise": ROOT / "Packages" / "Promise.lua",
    "Packages.Trove": ROOT / "Packages" / "Trove.lua",
    "Packages.TopbarPlus": ROOT / "Packages" / "TopbarPlus.lua",
    "Packages.Zone": ROOT / "vendor" / "ZonePlus",
    "Packages.ProfileStore": ROOT / "ServerPackages" / "ProfileStore.lua",
}

REQ_RE = re.compile(r'require\(((?:script\.Parent(?:\.Parent)*|[A-Z]\w*)[.\w:]+(?::WaitForChild\("\w+"\))?\.?\w*(?:\.\w+)*)\)')

def resolve(expr: str, file: pathlib.Path) -> pathlib.Path | None:
    # script.Parent(/Parent...).A.B
    if expr.startswith("script.Parent"):
        hops = expr.count(".Parent") - expr.count(".Parent.Parent")
        path = file.parent
        for _ in range(expr.count(".Parent")):
            path = path.parent
        rel = expr.split(".")
        # убрать "script" и все "Parent"
        parts = [p for p in rel if p not in ("script", "Parent")]
        # path уже продвинут вверх на число Parent (включая первый Parent = сама папка)
        path = file.parent
        for _ in range(expr.count(".Parent") - 1):
            path = path.parent
        for p_ in parts:
            path = path / p_
        return path.with_suffix(".lua")
    if expr.startswith("Shared."):
        return (REP / "Shared" / pathlib.Path(*expr.split(".")[1:])).with_suffix(".lua")
    if expr.startswith("StarterPlayerScripts:WaitForChild"):
        m = re.match(r'StarterPlayerScripts:WaitForChild\("(\w+)"\)\.(\w+)', expr)
        return (SPS / m.group(1) / m.group(2)).with_suffix(".lua") if m else None
    if expr.startswith("ServerScriptService.Packages") or expr.startswith("ReplicatedStorage.Packages"):
        key = "Packages." + expr.split(".")[-1]
        return WALLY.get(key)
    if expr.startswith("Packages."):
        return WALLY.get("Packages." + expr.split(".")[-1])
    alias = expr.split(".", 1)[0]
    if alias in SERVER_ALIASES:
        rest = expr.split(".")[1:]
        return (SSS / alias / pathlib.Path(*rest)).with_suffix(".lua")
    return None

for f in lua_files():
    text = f.read_text()
    for req in REQ_RE.findall(text):
        if "require(path.to" in text.replace("\t", " ") or req in ("module", "path.to.Remotes"):
            continue
        target = resolve(req, f)
        if target is None:
            continue  # неизвестный, но заранее зарезервированный паттерн
        if not target.exists():
            err(f"[require] {f.relative_to(SRC)}: require({req}) → нет файла {target.relative_to(ROOT) if target.is_absolute() else target}")

# --- 3. Зоны / интерьеры -----------------------------------------------------
lm = (REP / "Shared" / "Config" / "Landmarks.lua").read_text()
zones_block = section(lm, "Zones") or ""
interiors_block = section(lm, "Interiors") or ""
zone_keys = set(top_keys(zones_block))
# Записи Landmarks добавляются присваиваниями `Landmarks.X = { ... }`
lm_keys = set(re.findall(r"^Landmarks\.(\w+) = \{", lm, re.M))

bootstrap = (SSS / "BootstrapProject.server.lua").read_text()
for zid in sorted(set(re.findall(r'"(Interior_\w+)"', bootstrap))):
    if zid not in zone_keys:
        err(f"[zones] bootstrap ссылается на «{zid}», но её нет в Landmarks.Zones")

for zm in re.finditer(r'ZoneId = "([^"]+)"', interiors_block):
    if zm.group(1) not in zone_keys:
        err(f"[zones] Interiors.ZoneId «{zm.group(1)}» нет среди зон")
for zm in re.finditer(r'EntryLandmarkId = "([^"]+)"', interiors_block):
    if zm.group(1) not in lm_keys:
        err(f"[zones] Interiors.EntryLandmarkId «{zm.group(1)}» нет среди достопримечательностей")

# Interior-зона обязана иметь Music (п.12.3)
for zm in re.finditer(r'(\w+) = \{\n\t\tId = "(Interior_\w+)"', zones_block):
    name = zm.group(1)
    sub = zones_block[zm.end():]
    end = sub.find("\n\t},")
    body = sub[:end] if end != -1 else sub[:800]
    if "Music = {" not in body:
        err(f"[zones] Interior-зона «{name}» без Music (п.12.3)")
    if "Interior = true" not in body:
        warn(f"[zones] Interior-зона «{name}» без флага Interior = true")

# --- 4. Настройки -------------------------------------------------------------
settings_block = section(lm, "SETTINGS") or ""
settings_keys = set(re.findall(r"^\t(\w+) = \{", settings_block, re.M))
tpl = (SSS / "Data" / "ProfileTemplate.lua").read_text()
tpl_settings = find_block(tpl, r"Settings = \{") or ""
tpl_keys = set(re.findall(r"^\t\t(\w+) = ", tpl_settings, re.M))
for key in sorted(settings_keys - tpl_keys):
    err(f"[settings] «{key}» объявлен в Landmarks.SETTINGS, но не в ProfileTemplate.Settings")
for key in sorted(tpl_keys - settings_keys):
    err(f"[settings] «{key}» есть в ProfileTemplate, но нет в Landmarks.SETTINGS (валидация отклонит!)")

# --- 5. Пассы -----------------------------------------------------------------
gp = (REP / "Shared" / "Config" / "GamePasses.lua").read_text()
features = set(re.findall(r'Feature = "([^"]+)"', gp))
for f in lua_files():
    for fm in re.finditer(r'HasFeature\([^)]*"([^"]+)"\)', strip_comments(f.read_text())):
        if fm.group(1) not in features:
            err(f"[passes] {f.relative_to(SRC)}: HasFeature «{fm.group(1)}» нет среди Features")

# --- 6. Продукты ----------------------------------------------------------------
dp = (REP / "Shared" / "Config" / "DeveloperProducts.lua").read_text()
grants = set(re.findall(r'Grant = "([^"]+)"', dp))
ph = (SSS / "Monetization" / "ProductHandler.lua").read_text()
handled = set(re.findall(r'== "(\w+)"', ph)) | set(re.findall(r'"(\w+)"', "".join(re.findall(r'GRANT_HANDLERS[^\n]*\n((?:[^\n]*\n)*?)\}', ph))))
for g in sorted(grants - handled):
    err(f"[products] Grant «{g}» из DeveloperProducts не обработан в ProductHandler")

# --- 7. MoveTo ------------------------------------------------------------------
for mt in re.finditer(r'SetAttribute\("MoveTo", "([^"]+)"\)', bootstrap):
    if f'Name = "{mt.group(1)}"' not in bootstrap:
        err(f"[interiors] MoveTo → «{mt.group(1)}»: такой части нет в BootstrapProject")

# --- Итог -------------------------------------------------------------------------
print(f"Файлов проверено: {len(lua_files())}")
for w in warnings:
    print("  ⚠ ", w)
for e in errors:
    print("  ✗ ", e)
if errors:
    print(f"\nИТОГ: {len(errors)} ошибок, {len(warnings)} предупреждений")
    sys.exit(1)
if warnings:
    print(f"\nИТОГ: 0 ошибок, {len(warnings)} предупреждений")
    sys.exit(2)
print("\nИТОГ: замечаний нет ✓")
sys.exit(0)
