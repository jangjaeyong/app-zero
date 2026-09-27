#!/usr/bin/env python3
"""ZERO 임시 효과음 합성기.

기획서 16번대로 소리가 조작의 일부라, 무음으로 슬라이스를 검증할 수 없다.
나중에 진짜 폴리 사운드로 갈아끼운다. 파일 이름은 그대로 두면 코드 수정 없다.

    python3 tools/make_sfx.py
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "game", "assets", "audio")

random.seed(20260927)


def write(name, samples, peak=0.85):
    hi = max(1e-9, max(abs(s) for s in samples))
    g = peak / hi
    data = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * g)) * 32767)) for s in samples)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    return path


def n(seconds):
    return int(SR * seconds)


def lowpass(buf, cutoff):
    a = math.exp(-2.0 * math.pi * cutoff / SR)
    out, prev = [], 0.0
    for s in buf:
        prev = (1.0 - a) * s + a * prev
        out.append(prev)
    return out


def highpass(buf, cutoff):
    lp = lowpass(buf, cutoff)
    return [s - l for s, l in zip(buf, lp)]


def noise(seconds):
    return [random.uniform(-1.0, 1.0) for _ in range(n(seconds))]


def env(buf, attack, decay, curve=3.0):
    total = len(buf)
    a = max(1, int(SR * attack))
    out = []
    for i, s in enumerate(buf):
        if i < a:
            e = i / a
        else:
            t = (i - a) / max(1, total - a)
            e = max(0.0, (1.0 - t)) ** curve
        out.append(s * e)
    return out


def tone(freq, seconds, shape=math.sin, detune=0.0):
    out = []
    for i in range(n(seconds)):
        t = i / SR
        f = freq * (1.0 + detune * t)
        out.append(shape(2.0 * math.pi * f * t))
    return out


def mix(*layers):
    m = max(len(l) for l in layers)
    out = [0.0] * m
    for l in layers:
        for i, s in enumerate(l):
            out[i] += s
    return out


def build():
    os.makedirs(OUT, exist_ok=True)
    made = []

    # click — 부품을 짚었다. 아주 짧고 마른 소리.
    made.append(write("click", env(
        mix(lowpass(highpass(noise(0.045), 1800), 7000),
            [s * 0.5 for s in tone(2400, 0.045)]),
        0.0008, 0.044, curve=5.0), peak=0.55))

    # clack — 걸렸다. 이 소리가 "안 빠진다"는 말을 대신한다. 낮고 둔탁하게.
    made.append(write("clack", env(
        mix(lowpass(noise(0.13), 1500),
            [s * 0.8 for s in tone(190, 0.13, detune=-260)],
            [s * 0.35 for s in tone(96, 0.13)]),
        0.0006, 0.13, curve=3.4), peak=0.92))

    # slide — 금속이 레일을 타고 미끄러진다.
    sl = highpass(lowpass(noise(0.26), 2600), 500)
    made.append(write("slide", env(sl, 0.02, 0.26, curve=1.6), peak=0.45))

    # ratchet — 링이 눈금 하나 넘어갈 때.
    made.append(write("ratchet", env(
        mix(highpass(noise(0.035), 3200),
            [s * 0.6 for s in tone(1450, 0.035, detune=-9000)]),
        0.0005, 0.034, curve=6.0), peak=0.6))

    # snap — 자석처럼 딱 붙었다 떨어진다.
    made.append(write("snap", env(
        mix(lowpass(noise(0.11), 4200),
            [s * 0.9 for s in tone(880, 0.11, detune=-3600)],
            [s * 0.4 for s in tone(1760, 0.11, detune=-5200)]),
        0.0008, 0.11, curve=4.0), peak=0.8))

    # lock_release — 잠금이 풀린다. 서보가 한 번 돌고 멎는 느낌.
    servo = [s * 0.5 for s in tone(320, 0.34, detune=-380)]
    for i in range(len(servo)):
        servo[i] *= 0.6 + 0.4 * math.sin(2 * math.pi * 55 * i / SR)
    made.append(write("lock_release", env(
        mix(servo,
            lowpass(noise(0.34), 2200),
            [s * 0.35 for s in tone(147, 0.34)]),
        0.004, 0.34, curve=2.2), peak=0.75))

    # core_hum — 코어를 누르고 있는 동안. 불안하게 흔들리는 저음.
    hum = []
    for i in range(n(2.0)):
        t = i / SR
        wob = 1.0 + 0.012 * math.sin(2 * math.pi * 6.3 * t)
        s = (math.sin(2 * math.pi * 72 * t * wob) * 0.6
             + math.sin(2 * math.pi * 144 * t * wob) * 0.28
             + math.sin(2 * math.pi * 217 * t) * 0.12)
        s *= 0.75 + 0.25 * math.sin(2 * math.pi * 3.1 * t)
        hum.append(s)
    fade = n(0.12)
    for i in range(fade):
        hum[i] *= i / fade
        hum[-1 - i] *= i / fade
    made.append(write("core_hum", hum, peak=0.55))

    # stable — 주황이 시안으로 넘어가는 순간. 맑게 올라가서 가라앉는다.
    chord = []
    for i in range(n(1.6)):
        t = i / SR
        s = 0.0
        for f, a in ((261.6, 0.5), (392.0, 0.34), (523.3, 0.26), (784.0, 0.16)):
            s += math.sin(2 * math.pi * f * t + 0.3 * math.sin(2 * math.pi * 2.2 * t)) * a
        chord.append(s)
    a = n(0.14)
    for i in range(len(chord)):
        if i < a:
            chord[i] *= i / a
        else:
            chord[i] *= max(0.0, 1.0 - (i - a) / (len(chord) - a)) ** 1.5
    made.append(write("stable", chord, peak=0.7))

    # alarm — 불안정도 경고. 거슬리되 아프지 않게. 두 번 삑.
    alarm = []
    for i in range(n(0.46)):
        t = i / SR
        gate = 1.0 if (t % 0.23) < 0.10 else 0.0
        s = (math.sin(2 * math.pi * 880 * t) * 0.6
             + math.sin(2 * math.pi * 1320 * t) * 0.25) * gate
        alarm.append(s)
    made.append(write("alarm", lowpass(alarm, 5200), peak=0.55))

    # overload — 과부하. 낮게 깔리며 무너지는 소리. 이게 나면 뭔가 잃은 것이다.
    over = []
    for i in range(n(1.1)):
        t = i / SR
        f = 220.0 * math.exp(-1.7 * t)
        s = (math.sin(2 * math.pi * f * t) * 0.8
             + math.sin(2 * math.pi * f * 0.5 * t) * 0.5)
        s += random.uniform(-1.0, 1.0) * 0.35 * math.exp(-4.0 * t)
        over.append(s * math.exp(-1.6 * t))
    made.append(write("overload", lowpass(over, 2400), peak=0.95))

    # relock — 잠금이 도로 걸린다. 짧고 묵직한 쇳소리.
    made.append(write("relock", env(
        mix(lowpass(noise(0.22), 1800),
            [s * 0.9 for s in tone(150, 0.22, detune=-140)],
            [s * 0.5 for s in tone(300, 0.22, detune=-300)]),
        0.0008, 0.22, curve=2.8), peak=0.9))

    for p in made:
        print("  %-16s %6.1f KB" % (os.path.basename(p), os.path.getsize(p) / 1024.0))
    print("ZERO_SFX_OK %d개" % len(made))


build()
