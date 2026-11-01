#!/usr/bin/env python3
"""Звуки интерфейса и наград для Block Puzzle — синтез без чужих сэмплов (никаких лицензий).

Запуск из корня проекта:  python3 tools/make_sounds.py  →  assets/sounds/<имя>.wav (моно, 16 бит, 44.1 кГц)
Нужен numpy. Звуки играет автозагрузка Sfx (autoload/sfx.gd) на шине SFX.

Принципы: короткие (интерфейс — до 0.1 с, награды — до 1.5 с), мягкая атака без щелчков,
колокольчиковые тембры (FM) для наград, «шумовые» — для действий (молоток, поворот, перемешивание).
Громкость выровнена: награды чуть громче, клик и «не встало» — тихие.
"""
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sounds")
RATE = 44100
rng = np.random.default_rng(2026)


def t_axis(duration):
    return np.arange(int(duration * RATE)) / RATE


def envelope(n, attack=0.005, release=0.1, hold=0.0, curve=4.0):
    """Атака → (удержание) → экспоненциальный спад до конца."""
    t = np.arange(n) / RATE
    env = np.ones(n)
    a = max(int(attack * RATE), 1)
    env[:a] = np.linspace(0, 1, a) ** 0.6
    start = a + int(hold * RATE)
    if start < n:
        decay_t = t[start:] - t[start]
        env[start:] = np.exp(-curve * decay_t / max(release, 1e-3))
    # мягкий хвост в ноль — без щелчка в конце
    tail = min(int(0.008 * RATE), n)
    env[-tail:] *= np.linspace(1, 0, tail)
    return env


def note(freq, duration, kind="sine", attack=0.004, release=0.3, hold=0.0, curve=4.0, vibrato=0.0):
    t = t_axis(duration)
    phase_freq = freq * (1 + vibrato * np.sin(2 * np.pi * 5.5 * t))
    phase = 2 * np.pi * np.cumsum(phase_freq) / RATE
    if kind == "sine":
        wave_ = np.sin(phase)
    elif kind == "triangle":
        wave_ = 2 / np.pi * np.arcsin(np.sin(phase))
    elif kind == "soft_square":  # нечётные гармоники с убыванием — «монетка»
        wave_ = sum(np.sin(k * phase) / k for k in (1, 3, 5, 7)) * 0.8
    elif kind == "brass":  # пила с убывающими гармониками и «раскрытием» фильтра
        bright = np.clip(t / 0.06, 0, 1)
        wave_ = sum(np.sin(k * phase) / k * (bright ** (k * 0.4)) for k in range(1, 9)) * 0.6
    elif kind == "bell":  # FM-колокольчик: модулятор 3.5×, индекс затухает
        index = 2.4 * np.exp(-t * 7)
        wave_ = np.sin(phase + index * np.sin(3.5 * phase))
    elif kind == "pluck":
        index = 1.5 * np.exp(-t * 18)
        wave_ = np.sin(phase + index * np.sin(2 * phase))
    else:
        raise ValueError(kind)
    return wave_ * envelope(len(t), attack, release, hold, curve)


def noise(duration):
    return rng.uniform(-1, 1, int(duration * RATE))


def one_pole(signal, cutoff):
    """Однополюсный фильтр нижних частот; cutoff — число или массив (Гц) для «плывущего» фильтра."""
    cut = np.broadcast_to(np.asarray(cutoff, dtype=float), signal.shape)
    alpha = 1 - np.exp(-2 * np.pi * cut / RATE)
    out = np.empty_like(signal)
    acc = 0.0
    for i, (x, a) in enumerate(zip(signal, alpha)):
        acc += a * (x - acc)
        out[i] = acc
    return out


def highpass(signal, cutoff):
    return signal - one_pole(signal, cutoff)


def mix(*parts):
    length = max(len(offset_signal[1]) + int(offset_signal[0] * RATE) for offset_signal in parts)
    out = np.zeros(length)
    for offset, signal in parts:
        start = int(offset * RATE)
        out[start:start + len(signal)] += signal
    return out


def reverb(signal, amount=0.25, length=0.6):
    """Лёгкое пространство: несколько затухающих отражений."""
    out = np.concatenate([signal, np.zeros(int(length * RATE))])
    for delay, gain in ((0.031, 0.5), (0.047, 0.4), (0.071, 0.32), (0.113, 0.22), (0.167, 0.14)):
        d = int(delay * RATE)
        echo = np.zeros_like(out)
        echo[d:d + len(signal)] = signal * gain
        out += echo * amount * 2
    tail = int(0.05 * RATE)
    out[-tail:] *= np.linspace(1, 0, tail)
    return out


def save(name, signal, peak_db=-3.0):
    signal = signal / max(np.max(np.abs(signal)), 1e-9) * (10 ** (peak_db / 20))
    data = (np.clip(signal, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, f"{name}.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())
    return len(data) / RATE


def hz(semitones_from_a4):
    return 440.0 * 2 ** (semitones_from_a4 / 12)


C5, D5, E5, G5, A5 = hz(3), hz(5), hz(7), hz(10), hz(12)
C6, D6, E6, G6, A6, C7 = hz(15), hz(17), hz(19), hz(22), hz(24), hz(27)
G4, C4, E4 = hz(-2), hz(-9), hz(-5)


def build():
    sounds = {}

    # Клик кнопки — короткий мягкий «тик»
    t = t_axis(0.05)
    freq = 1500 * np.exp(-t * 25) + 700
    click = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * envelope(len(t), 0.001, 0.02)
    click += highpass(noise(0.05), 3000) * envelope(len(t), 0.0005, 0.006) * 0.3
    sounds["click"] = (click, -12)

    # Монетка — две быстрые ноты
    sounds["coin"] = (reverb(mix((0, note(hz(14), 0.07, "soft_square", release=0.05, hold=0.04)),
                                 (0.06, note(hz(19), 0.35, "soft_square", release=0.18, hold=0.02))), 0.15), -6)

    # Новый уровень — восходящее арпеджио колокольчиком и блеск сверху
    arp = [(0.0, C5), (0.08, E5), (0.16, G5), (0.24, C6)]
    level = mix(*[(o, note(f, 0.7, "bell", release=0.45)) for o, f in arp],
                (0.32, note(E6, 0.9, "bell", release=0.6) * 0.6),
                (0.32, note(G6, 0.9, "sine", release=0.6) * 0.3))
    sounds["level_up"] = (reverb(level, 0.3, 0.8), -3)

    # Награда (предмет, достижение) — россыпь высоких колокольчиков
    sparkle_notes = [C6, D6, E6, G6, A6, C7]
    reward = mix(*[(i * 0.045, note(f, 0.5, "bell", release=0.3) * (0.7 + 0.06 * i)) for i, f in enumerate(sparkle_notes)])
    sounds["reward"] = (reverb(reward, 0.35, 0.7), -4)

    # Комбо (2+ линии за ход) — взлёт шума и аккорд-щипок; высоту поднимает игра
    dur = 0.28
    t = t_axis(dur)
    sweep = one_pole(noise(dur), 600 + 5000 * (t / dur) ** 2) * envelope(len(t), 0.12, 0.08, 0.08)
    stab = mix((0.16, note(C5, 0.4, "pluck", release=0.25)), (0.16, note(E5, 0.4, "pluck", release=0.25)),
               (0.16, note(G5, 0.4, "pluck", release=0.25)), (0.16, note(C6, 0.4, "pluck", release=0.25) * 0.6))
    sounds["combo"] = (reverb(mix((0, sweep * 0.5), (0, stab)), 0.25), -4)

    # Чистое поле — широкий светлый аккорд и блеск
    chord = [C4, E4, G4, C5, D5, E5]
    pad = mix(*[(0, (note(f, 1.6, "sine", attack=0.12, release=1.1, vibrato=0.002)
                    + note(f * 1.003, 1.6, "sine", attack=0.12, release=1.1)) * 0.5) for f in chord])
    sparkles = mix(*[(0.15 + i * 0.07, note(f, 0.5, "bell", release=0.3) * 0.5) for i, f in enumerate([G6, C7, E6, G6])])
    sounds["perfect"] = (reverb(mix((0, pad), (0, sparkles)), 0.3, 0.9), -3)

    # Новый рекорд — короткие фанфары
    fanfare = mix((0.0, note(G4, 0.16, "brass", release=0.08, hold=0.08)),
                  (0.15, note(C5, 0.16, "brass", release=0.08, hold=0.08)),
                  (0.30, note(E5, 0.16, "brass", release=0.08, hold=0.08)),
                  (0.45, note(G5, 0.7, "brass", release=0.4, hold=0.25, vibrato=0.004)),
                  (0.45, note(C5, 0.7, "brass", release=0.4, hold=0.25) * 0.5))
    sounds["record"] = (reverb(fanfare, 0.3, 0.7), -3)

    # Молоток — глухой удар и треск
    t = t_axis(0.3)
    thud_freq = 55 + 110 * np.exp(-t * 30)
    thud = np.sin(2 * np.pi * np.cumsum(thud_freq) / RATE) * envelope(len(t), 0.001, 0.12)
    crack = highpass(noise(0.3), 2500) * envelope(len(t), 0.0005, 0.03) * 0.6
    sounds["hammer"] = (mix((0, thud), (0.005, crack)), -4)

    # Поворот — короткий взмах (шум с поднимающимся фильтром)
    dur = 0.22
    t = t_axis(dur)
    swoosh = one_pole(highpass(noise(dur), 400), 800 + 4000 * (t / dur)) * np.sin(np.pi * t / dur) ** 2
    sounds["rotate"] = (mix((0, swoosh), (0.17, note(hz(17), 0.08, "pluck", release=0.05) * 0.4)), -7)

    # Отмена — взмах «назад» (фильтр опускается)
    swoosh_back = one_pole(highpass(noise(dur), 400), 4800 - 4000 * (t / dur)) * np.sin(np.pi * t / dur) ** 2
    sounds["undo"] = (mix((0, swoosh_back), (0.15, note(hz(10), 0.08, "pluck", release=0.05) * 0.4)), -7)

    # Новые фигуры — «перетасовка»: серия коротких щелчков
    parts = []
    for i in range(9):
        tick = highpass(noise(0.03), 1800) * envelope(int(0.03 * RATE), 0.001, 0.012)
        parts.append((i * 0.032 + rng.uniform(0, 0.008), tick * (0.6 + 0.4 * rng.random())))
    sounds["shuffle"] = (mix(*parts, (0.3, note(hz(15), 0.12, "pluck", release=0.08) * 0.35)), -8)

    # Фигура не встала — мягкое «бум-бум» вниз, тихо
    sounds["invalid"] = (mix((0, note(hz(-5), 0.09, "triangle", release=0.06)),
                             (0.07, note(hz(-9), 0.14, "triangle", release=0.09))), -14)
    return sounds


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (signal, peak) in build().items():
        duration = save(name, signal, peak)
        print(f"{name:10s} {duration:.2f} с")


if __name__ == "__main__":
    main()
