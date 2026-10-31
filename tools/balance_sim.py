#!/usr/bin/env python3
"""Стресс-тест и баланс без Godot: перенос core/*.gd (поле, фигуры, генератор, очки) и экономики
game.gd/progression.gd на Python + бот-игрок. Проверяет инварианты (в каждом наборе есть ход,
перекрёсток линий, поворот фигур) и показывает баланс: очки, длину партии, монеты, опыт,
сколько партий до уровней и насколько достижимы испытания.

Запуск из корня проекта:  python3 tools/balance_sim.py [партий_на_профиль]   (по умолчанию 200, ~1 мин)
После правок в генераторе, очках или кривой опыта сравните цифры с прошлым запуском.
Фигуры читаются прямо из core/shapes.gd; веса генератора и формулы ниже — копия кода игры,
при их изменении в .gd поправьте и здесь."""
import os, random, statistics, sys, time, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIZE = 8

# --- Shapes: читаем прямо из core/shapes.gd, чтобы тест не разошёлся с игрой
shapes_src = open(f"{ROOT}/core/shapes.gd", encoding="utf-8").read()
list_src = shapes_src[shapes_src.index("const LIST = ["):shapes_src.index("\n]\n")]
SHAPES = []
for line in list_src.splitlines():
    cells = re.findall(r"Vector2\((\d+), (\d+)\)", line)
    if cells:
        SHAPES.append(tuple((int(x), int(y)) for x, y in cells))
assert len(SHAPES) == 28, len(SHAPES)

def shape_size(shape):
    return max(c[0] for c in shape) + 1, max(c[1] for c in shape) + 1

def rotate_cw(shape):
    h = shape_size(shape)[1]
    return tuple((h - 1 - y, x) for x, y in shape)

def norm(shape):
    return tuple(sorted(shape))

# --- Битовое поле: бит y*8+x
LINE_MASKS = []
for y in range(SIZE):
    LINE_MASKS.append(("row", y, sum(1 << (y * SIZE + x) for x in range(SIZE))))
for x in range(SIZE):
    LINE_MASKS.append(("col", x, sum(1 << (y * SIZE + x) for y in range(SIZE))))
FULL = (1 << 64) - 1

PLACEMENTS = {}  # shape -> [(x, y, mask)]
def placements(shape):
    if shape not in PLACEMENTS:
        w, h = shape_size(shape)
        out = []
        for y in range(SIZE - h + 1):
            for x in range(SIZE - w + 1):
                out.append((x, y, sum(1 << ((y + cy) * SIZE + (x + cx)) for cx, cy in shape)))
        PLACEMENTS[shape] = out
    return PLACEMENTS[shape]

def can_place_anywhere(board, shape):
    return any(board & m == 0 for _, _, m in placements(shape))

def find_full(board):
    return [mask for _, _, mask in LINE_MASKS if board & mask == mask]

# --- PieceGenerator (как core/piece_generator.gd)
GROUP_WEIGHTS = {1: (0.10, 0.04), 2: (0.20, 0.10), 3: (0.35, 0.30), 4: (0.35, 0.56)}
CANDIDATES = (12, 3)
GROUPS = {}
for s in SHAPES:
    GROUPS.setdefault(len(s), []).append(s)

def lerp(a, b, t):
    return a + (b - a) * t

def gd_round(v):  # GDScript round(): половина — от нуля
    return int(v + 0.5) if v >= 0 else -int(-v + 0.5)

class Generator:
    def __init__(self, rng):
        self.rng = rng
    def pick_shape(self, difficulty):
        weights = {c: lerp(p[0], p[1], difficulty) for c, p in GROUP_WEIGHTS.items()}
        total = sum(weights.values())
        roll = self.rng.random() * total
        chosen = 4
        for c, w in weights.items():
            roll -= w
            if roll <= 0.0:
                chosen = c
                break
        group = GROUPS[chosen]
        return group[self.rng.randrange(len(group))]
    def generate_set(self, board, difficulty, count=3):
        attempts = gd_round(lerp(CANDIDATES[0], CANDIDATES[1], difficulty))
        best, best_fit = [], -1
        for _ in range(max(attempts, 1)):
            cand = [self.pick_shape(difficulty) for _ in range(count)]
            fit = sum(1 for s in cand if can_place_anywhere(board, s))
            if fit == count:
                return cand
            if fit > best_fit:
                best_fit, best = fit, cand
        if best_fit <= 0:
            best[0] = self.find_fitting(board)
        return best
    def find_fitting(self, board):
        shuffled = SHAPES[:]
        self.rng.shuffle(shuffled)
        for s in shuffled:
            if can_place_anywhere(board, s):
                return s
        return SHAPES[0]

def difficulty_for_score(score):
    return min(max(score / 4000.0, 0.0), 1.0)

# --- Scoring (как core/scoring.gd)
class Scoring:
    def __init__(self):
        self.streak = 0
        self.moves_without_clear = 0
    def register(self, cells, lines, empty_after):
        placement, clear, mult, perfect = cells, 0, 1.0, False
        if lines > 0:
            self.streak += 1
            self.moves_without_clear = 0
            mult = min(1.0 + 0.5 * max(self.streak - 1, 0), 4.0)
            clear = int(10 * lines * lines * mult)
            if empty_after:
                perfect = True
                clear += 300
        else:
            self.moves_without_clear += 1
            if self.moves_without_clear > 2:
                self.streak = 0
        return placement + clear, self.streak, perfect

# --- Экономика (game.gd / progression.gd)
def calc_multiplier(score):
    for limit, m in ((200, 1.0), (800, 1.5), (1700, 2.0), (4200, 2.5), (8300, 3.0), (16700, 4.0)):
        if score < limit:
            return m
    return 5.0

def game_xp_for_score(v):
    if v <= 0:
        return 0
    xp = 10
    if v >= 1000: xp += 20
    if v >= 5000: xp += 50
    if v >= 10000: xp += 100
    return xp

def xp_for_level(level):
    return 120 + 10 * (level - 1)

# --- Бот: жадный, как средний игрок. skill 0..1 — насколько хорошо оценивает поле
def holes_penalty(board):
    # Пустые клетки, окружённые занятыми (неудобные дырки), и неровность
    penalty = 0
    for y in range(SIZE):
        for x in range(SIZE):
            bit = 1 << (y * SIZE + x)
            if board & bit:
                continue
            blocked = 0
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < SIZE and 0 <= ny < SIZE) or board & (1 << (ny * SIZE + nx)):
                    blocked += 1
            if blocked >= 3:
                penalty += blocked - 2
    return penalty

def best_move(board, tray, rng, skill):
    best = None
    for i, shape in enumerate(tray):
        if shape is None:
            continue
        for x, y, m in placements(shape):
            if board & m:
                continue
            nb = board | m
            full = find_full(nb)
            cleared = 0
            for mask in full:
                cleared |= mask
            nb2 = nb & ~cleared
            score = len(full) * 10 - holes_penalty(nb2) * skill * 2 + rng.random() * (1.5 - skill)
            if best is None or score > best[0]:
                best = (score, i, m, len(full), nb2)
    return best

def play(rng, games_played, skill, zen=False, max_moves=4000):
    board = 0
    gen = Generator(rng)
    sc = Scoring()
    score = 0
    lines_total = 0
    run_xp = 0
    moves = 0
    max_streak = 0
    perfect = 0
    sets = 0
    max_combo = 0
    clutch = 0
    while moves < max_moves:
        ramp = min(max(0.4 + 0.15 * games_played, 0.4), 1.0)
        tray = gen.generate_set(board, difficulty_for_score(score) * ramp)
        sets += 1
        # Инвариант: в каждом наборе хотя бы одна фигура помещается
        assert any(can_place_anywhere(board, s) for s in tray), "набор без хода"
        tray = list(tray)
        while any(s is not None for s in tray):
            move = best_move(board, tray, rng, skill)
            if move is None:
                return dict(score=score, lines=lines_total, xp=run_xp, moves=moves, sets=sets,
                            streak=max_streak, perfect=perfect, combo=max_combo, clutch=clutch)
            _, i, m, nlines, nb2 = move
            fill_before = bin(board).count("1") / 64
            cells = len(tray[i])
            tray[i] = None
            board = nb2
            pts, streak, perf = sc.register(cells, nlines, nlines > 0 and board == 0)
            score += pts
            moves += 1
            max_streak = max(max_streak, streak)
            if nlines:
                max_combo = max(max_combo, nlines)
                if fill_before >= 0.75:
                    clutch += 1
                lines_total += nlines
                base = nlines * 5 + nlines * 2 * nlines + (10 if nlines >= 2 else 0) + max(streak - 1, 0) * 3
                run_xp += base
                if perf:
                    perfect += 1
    return dict(score=score, lines=lines_total, xp=run_xp, moves=moves, sets=sets, streak=max_streak,
                perfect=perfect, combo=max_combo, clutch=clutch, capped=True)

def check_invariants():
    # Поворот: 4 поворота — исходная фигура; результат — фигура из библиотеки, начинается с (0,0)
    lib = {norm(s) for s in SHAPES}
    for s in SHAPES:
        r = s
        for _ in range(4):
            r = rotate_cw(r)
            assert min(c[0] for c in r) == 0 and min(c[1] for c in r) == 0, s
        assert norm(r) == norm(s), s
        assert norm(rotate_cw(s)) in lib, ("поворот вне библиотеки", s)
    # Перекрёсток: ряд и столбец одновременно — 15 клеток
    b = 0
    for x in range(SIZE):
        b |= 1 << (3 * SIZE + x)
    for y in range(SIZE):
        b |= 1 << (y * SIZE + 5)
    full = find_full(b)
    assert len(full) == 2
    cleared = 0
    for mask in full:
        cleared |= mask
    assert bin(cleared).count("1") == 15
    # Гарантия хода на почти полном поле: одна свободная клетка (без полных линий)
    rng = random.Random(1)
    gen = Generator(rng)
    for hole in range(64):
        board = FULL & ~(1 << hole)
        # убираем ещё по клетке в каждой линии, чтобы не было полных
        for y in range(SIZE):
            board &= ~(1 << (y * SIZE + (y * 3 + 1) % SIZE))
        for _ in range(20):
            s = gen.generate_set(board, 1.0)
            assert any(can_place_anywhere(board, x) for x in s)
    print("инварианты: поворот ×4, библиотека поворотов, перекрёсток 15 клеток, гарантия хода — OK")

def main():
    check_invariants()
    rng = random.Random(2026)
    t0 = time.time()
    results = {}
    per_profile = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    for skill_name, skill, games in (("новичок", 0.2, per_profile), ("средний", 0.6, per_profile), ("сильный", 1.0, per_profile)):
        runs = []
        for g in range(games):
            runs.append(play(rng, g, skill))
        results[skill_name] = runs
    dt = time.time() - t0
    total_games = sum(len(r) for r in results.values())
    print(f"сыграно партий: {total_games} за {dt:.1f} с, ходов: {sum(x['moves'] for r in results.values() for x in r)}")

    for name, runs in results.items():
        scores = [r["score"] for r in runs]
        early = scores[:5]
        later = scores[50:]
        coins = [int(int(r["score"] / 10.0) * calc_multiplier(r["score"])) for r in runs]
        xp = [r["xp"] + game_xp_for_score(r["score"]) for r in runs]
        moves = [r["moves"] for r in runs]
        capped = sum(1 for r in runs if r.get("capped"))
        print(f"\n== {name}: партий {len(runs)}, упёрлись в лимит ходов: {capped}")
        print(f"  очки: медиана {statistics.median(scores):.0f}, среднее {statistics.mean(scores):.0f}, "
              f"p90 {sorted(scores)[int(len(scores) * 0.9)]}, макс {max(scores)}")
        print(f"  первые 5 партий: {early}; после 50-й медиана {statistics.median(later):.0f}")
        print(f"  ходов за партию: медиана {statistics.median(moves):.0f} (≈{statistics.median(moves) * 3.5 / 60:.1f} мин при 3.5 с на ход)")
        print(f"  линий: медиана {statistics.median([r['lines'] for r in runs]):.0f}, серия макс медиана "
              f"{statistics.median([r['streak'] for r in runs]):.0f}, чистых полей всего {sum(r['perfect'] for r in runs)}")
        print(f"  монет за партию: медиана {statistics.median(coins):.0f}, XP за партию: медиана {statistics.median(xp):.0f}")
        # Сколько партий до уровней (только XP партий, без заданий и награды дня)
        level, cur, reach = 1, 0, {}
        for i, gain in enumerate(xp * 50):
            cur += gain
            while level < 500 and cur >= xp_for_level(level):
                cur -= xp_for_level(level)
                level += 1
                if level in (2, 5, 10, 20, 30, 50, 100, 200, 500) and level not in reach:
                    reach[level] = i + 1
            if level >= 500:
                break
        print("  партий до уровня (без заданий/награды дня): " + ", ".join(f"{k}: {v}" for k, v in sorted(reach.items())))

    # Монеты: хватает ли на продолжение (100) и бонусы
    mid = results["средний"]
    coins = [int(int(r["score"] / 10.0) * calc_multiplier(r["score"])) for r in mid]
    print(f"\nэкономика (средний игрок): монет за 10 партий ≈ {sum(coins[-10:])}; "
          f"доля партий, после которых хватит на «Продолжить» (100): {sum(1 for c in coins if c >= 100) / len(coins):.0%}")

    # Достижимость испытаний (доля партий, где это случилось хоть раз)
    every = [r for runs in results.values() for r in runs]
    share = lambda cond: f"{sum(1 for r in every if cond(r)) / len(every):.1%}"
    print("\nиспытания — доля партий: "
          f"2 линии за ход {share(lambda r: r['combo'] >= 2)}, 3 линии {share(lambda r: r['combo'] >= 3)}, "
          f"4 линии {share(lambda r: r['combo'] >= 4)}; серия ≥8 {share(lambda r: r['streak'] >= 8)}, "
          f"≥12 {share(lambda r: r['streak'] >= 12)}, ≥20 {share(lambda r: r['streak'] >= 20)}; "
          f"очистка при поле ≥75% {share(lambda r: r['clutch'] > 0)}; чистое поле {share(lambda r: r['perfect'] > 0)}; "
          f"5000+ очков {share(lambda r: r['score'] >= 5000)}, 10000+ {share(lambda r: r['score'] >= 10000)}")
    print("бот играет ровнее человека: у живых игроков очков и линий меньше, а поле чаще забито")

if __name__ == "__main__":
    main()
