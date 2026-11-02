#!/bin/bash
# Стресс-тест сохранений: игра запускается на испорченных, пустых, обрезанных, недописанных,
# старых и крайних сохранениях — и должна открыться без ошибок скриптов, с живым полем.
# Работает на копии проекта со своим config/name: ваши сохранения не трогает.
#   tests/save_stress.sh /путь/к/godot
set -u
GODOT=${1:?укажите путь к Godot}
SRC=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/block_puzzle_stress.XXXXXX")
trap 'rm -rf "${WORK:?}"' EXIT
# Кэш импорта (.godot) копируется вместе с проектом, если он есть, — так быстрее
(cd "$SRC" && tar --exclude=.git -cf - .) | tar -xf - -C "$WORK"
sed -i 's/^config\/name=.*/config\/name="BlockPuzzleSaveStress"/' "$WORK/project.godot"
printf 'extends SceneTree\nfunc _initialize():\n\tprint("USERDIR ", OS.get_user_data_dir())\n\tquit()\n' > "$WORK/tests/user_dir.gd"
# Импорт иногда падает в самом движке (замечено один раз на чистой копии) — повторяем
for attempt in 1 2 3; do
  timeout 600 "$GODOT" --headless --import --path "$WORK" >/dev/null 2>&1 && break
  echo "импорт упал (попытка $attempt), повторяю"
done
USER_DIR=$(timeout 60 "$GODOT" --headless --path "$WORK" -s tests/user_dir.gd 2>/dev/null | sed -n 's/^USERDIR //p')
[ -n "$USER_DIR" ] || { echo "не удалось узнать папку сохранений"; exit 1; }
FIX="$SRC/tests/fixtures/saves_v0.9"
FILES="progression.save achievements.save missions.save settings.save run.save challenge.save challenge_run.save"
FAILS=0

run() {  # имя, затем аргументы для save_probe.gd
  local title=$1; shift
  local out
  out=$(timeout 120 "$GODOT" --headless --path "$WORK" --fixed-fps 60 -s tests/save_probe.gd -- "$@" 2>&1)
  local probe errors
  probe=$(echo "$out" | sed -n 's/^PROBE //p')
  errors=$(echo "$out" | grep -E "SCRIPT ERROR|Parse Error|Invalid (get|set|call|access)|Cannot call|Nonexistent" | head -3)
  if [ -z "$probe" ] || [ -n "$errors" ]; then
    FAILS=$((FAILS + 1))
    echo "✗ $title"
    [ -n "$errors" ] && echo "$errors" | sed 's/^/    /'
    [ -z "$probe" ] && echo "    игра не дошла до поля"
  else
    echo "✓ $title: $probe"
  fi
}

fresh() { rm -rf "${USER_DIR:?}"; mkdir -p "$USER_DIR"; }
old() { fresh; cp "$FIX"/*.save "$USER_DIR"/; }

fresh; run "чистый запуск"
old; run "сохранения версии 0.9 (до испытаний и титулов)"
fresh; for f in $FILES; do head -c 900 /dev/urandom > "$USER_DIR/$f"; done; run "мусор во всех файлах"
fresh; for f in $FILES; do : > "$USER_DIR/$f"; done; run "пустые файлы"
old; cp "$USER_DIR/progression.save" "$USER_DIR/progression.save.bak"; head -c 300 "$FIX/progression.save" > "$USER_DIR/progression.save"
run "прогресс обрезан, есть .bak (уровень должен совпасть с версией 0.9)"
old; head -c 400 /dev/urandom > "$USER_DIR/progression.save.tmp"; run "оборванная запись (остался .tmp)"
old; head -c 500 /dev/urandom > "$USER_DIR/run.save"; run "испорчена незаконченная партия"
old; run "испытание «идёт», но задачи нет" --prepare=challenge_no_puzzle
old; run "испытание вчерашнего дня осталось активным" --prepare=challenge_yesterday
old; run "испытание идёт, файл попытки испорчен" --prepare=challenge_broken_run
fresh; run "крайние значения: 500-й уровень, 2 млрд монет, всё золотое" --prepare=maxed
fresh; run "поля не того типа" --prepare=wrong_types
fresh; run "испорчены задания, задача испытания, цвета и партия внутри файлов" --prepare=broken_inner
echo
[ "$FAILS" -eq 0 ] && echo "SAVE STRESS: OK" || echo "SAVE STRESS: $FAILS проблем"
