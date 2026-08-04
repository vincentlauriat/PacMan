#!/usr/bin/env python3
"""Generate all game assets: 8-bit WAV sounds + AppIcon.icns.

Pure stdlib (wave, zlib, struct) + macOS tools (sips, iconutil).
Run from anywhere: paths are resolved relative to this script.
"""
import math
import os
import random
import shutil
import struct
import subprocess
import wave
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOUNDS = os.path.join(ROOT, "Resources", "Sounds")
RESOURCES = os.path.join(ROOT, "Resources")
RATE = 22050

# ---------------------------------------------------------------- sounds

def write_wav(name, samples):
    os.makedirs(SOUNDS, exist_ok=True)
    path = os.path.join(SOUNDS, name + ".wav")
    data = bytes(max(0, min(255, int(128 + s * 127))) for s in samples)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(1)  # 8-bit unsigned: authentic grit
        f.setframerate(RATE)
        f.writeframes(data)
    print("wav :", path, f"({len(samples)/RATE:.2f}s)")


def square(phase):
    return 1.0 if (phase % 1.0) < 0.5 else -1.0


def sweep(f0, f1, dur, vol=0.6):
    """Square wave exponential frequency sweep."""
    n = int(dur * RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        f = f0 * (f1 / f0) ** t
        phase += f / RATE
        env = 1.0 - t * 0.5
        out.append(square(phase) * vol * env)
    return out


def tone(freq, dur, vol=0.7):
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / n
        env = min(1.0, (1.0 - t) * 4)
        out.append(square(freq * i / RATE) * vol * env)
    return out


def silence(dur):
    return [0.0] * int(dur * RATE)


def warble(center, depth, mod_hz, dur, vol=0.3):
    """Loopable siren-style warble (integer number of mod cycles)."""
    n = int(dur * RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        f = center + depth * math.sin(2 * math.pi * mod_hz * t)
        phase += f / RATE
        out.append(square(phase) * vol)
    return out


def gen_sounds():
    # Opening jingle: an original melody in the spirit of the 1980 intro.
    melody = [(659, .11), (1319, .11), (988, .11), (831, .11),
              (1319, .07), (988, .14), (831, .21),
              (622, .11), (1245, .11), (932, .11), (784, .11),
              (1245, .07), (932, .14), (784, .21),
              (659, .11), (1319, .11), (988, .11), (831, .11),
              (1319, .07), (988, .14), (831, .21),
              (831, .07), (880, .07), (932, .07),
              (932, .07), (988, .07), (1047, .07),
              (1047, .07), (1109, .07), (1175, .07), (1319, .25)]
    jingle = []
    for f, d in melody:
        jingle += tone(f, d, vol=0.5)
        jingle += silence(0.015)
    write_wav("intro", jingle)

    # The waka-waka chomp: two alternating short sweeps.
    write_wav("waka1", sweep(550, 220, 0.07, vol=0.5))
    write_wav("waka2", sweep(220, 550, 0.07, vol=0.5))

    # Background siren (loops).
    write_wav("siren", warble(420, 140, 3.0, 1.0, vol=0.25))

    # Frightened-mode wobble (loops, faster and lower).
    write_wav("fright", warble(220, 80, 6.0, 1.0, vol=0.25))

    # Eyes returning home (loops, high ping).
    write_wav("eyes", warble(900, 250, 5.0, 1.0, vol=0.18))

    # Ghost eaten: rising zip.
    write_wav("eat_ghost", sweep(200, 1400, 0.35, vol=0.6))

    # Fruit eaten: quick double blip.
    write_wav("eat_fruit", tone(784, 0.08, vol=0.6) + tone(1175, 0.12, vol=0.6))

    # Death: long falling warble then two low thuds.
    death = []
    for f0 in [900, 800, 700, 600, 500, 400]:
        death += sweep(f0, f0 * 0.55, 0.13, vol=0.55)
    death += silence(0.05)
    death += sweep(160, 60, 0.12, vol=0.7) + silence(0.04)
    death += sweep(160, 60, 0.12, vol=0.7)
    write_wav("death", death)

    # Extra life: ascending blips.
    ext = []
    for f in [523, 659, 784, 1047]:
        ext += tone(f, 0.09, vol=0.55)
    write_wav("extra", ext)

# ---------------------------------------------------------------- icon

W = 1024

GHOST = [
    "....######....",
    "..##########..",
    ".############.",
    ".############.",
    "##############",
    "##############",
    "##############",
    "##############",
    "##############",
    "##############",
    "##############",
    "##############",
    "##############",
    "##.###..###.##",
]
GHOST_EYES = [
    "..............",
    "..............",
    "..............",
    "...##....##...",
    "..####..####..",
    "..####..####..",
    "..####..####..",
    "...##....##...",
]
GHOST_PUPILS = [
    "..............",
    "..............",
    "..............",
    "..............",
    "..............",
    "..##....##....",
    "..##....##....",
]


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.buf = bytearray(w * h * 4)

    def blend(self, x, y, r, g, b, a):
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        i = (y * self.w + x) * 4
        sa = a / 255.0
        for k, c in enumerate((r, g, b)):
            self.buf[i + k] = int(c * sa + self.buf[i + k] * (1 - sa))
        self.buf[i + 3] = max(self.buf[i + 3], a)

    def rect(self, x0, y0, w, h, r, g, b, a=255):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                self.blend(x, y, r, g, b, a)

    def png(self, path):
        raw = b""
        for y in range(self.h):
            raw += b"\x00" + bytes(self.buf[y * self.w * 4:(y + 1) * self.w * 4])

        def chunk(tag, data):
            c = tag + data
            return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c))

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(raw, 9))
        png += chunk(b"IEND", b"")
        with open(path, "wb") as f:
            f.write(png)


def in_squircle(x, y, x0, y0, size, radius):
    dx = max(0, abs(x - (x0 + size / 2)) - (size / 2 - radius))
    dy = max(0, abs(y - (y0 + size / 2)) - (size / 2 - radius))
    return dx * dx + dy * dy <= radius * radius


def draw_pattern(cv, pattern, px, x0, y0, color, alpha=255):
    r, g, b = color
    for row_i, row in enumerate(pattern):
        for col_i, ch in enumerate(row):
            if ch == "#":
                cv.rect(x0 + col_i * px, y0 + row_i * px, px, px, r, g, b, alpha)


def draw_pac(cv, cx, cy, radius, color, mouth_deg=55, glow=None):
    """Pac-Man disc with a wedge mouth opening to the right."""
    half = math.radians(mouth_deg)
    r, g, b = color
    for y in range(cy - radius, cy + radius + 1):
        for x in range(cx - radius, cx + radius + 1):
            dx, dy = x - cx, y - cy
            if dx * dx + dy * dy > radius * radius:
                continue
            ang = abs(math.atan2(dy, dx))
            if ang < half:
                continue
            cv.blend(x, y, r, g, b, 255)


def gen_icon():
    cv = Canvas(W, W)
    m, size, radius = 100, 824, 185
    # Background: vertical gradient deep black -> midnight blue
    for y in range(m, m + size):
        t = (y - m) / size
        r, g, b = int(3 + 8 * t), int(4 + 10 * t), int(14 + 44 * t)
        for x in range(m, m + size):
            if in_squircle(x, y, m, m, size, radius):
                i = (y * W + x) * 4
                cv.buf[i:i + 4] = bytes((r, g, b, 255))

    # Maze hint: two horizontal blue wall lines
    wall = (40, 40, 220)
    cv.rect(m + 60, 240, size - 120, 14, *wall, 200)
    cv.rect(m + 60, 770, size - 120, 14, *wall, 200)

    # Trail of dots ahead of Pac-Man
    for i in range(3):
        x = 660 + i * 105
        cv.rect(x, 495, 34, 34, 255, 200, 170)

    # Soft glow then the big Pac-Man
    draw_pac(cv, 400, 512, 240, (120, 90, 0), glow=None)
    draw_pac(cv, 392, 512, 232, (255, 220, 0))

    # A red ghost chasing from behind (partially clipped left)
    px = 22
    gx, gy = 60, 420
    draw_pattern(cv, GHOST, px, gx, gy, (255, 40, 40))
    draw_pattern(cv, GHOST_EYES, px, gx, gy, (255, 255, 255))
    draw_pattern(cv, GHOST_PUPILS, px, gx, gy, (40, 40, 220))

    # Scanlines
    for y in range(m, m + size, 6):
        for yy in range(y, min(y + 2, m + size)):
            for x in range(m, m + size):
                if in_squircle(x, yy, m, m, size, radius):
                    i = (yy * W + x) * 4
                    for k in range(3):
                        cv.buf[i + k] = int(cv.buf[i + k] * 0.82)
    # Clip everything outside the squircle
    for y in range(W):
        for x in range(W):
            if not in_squircle(x, y, m, m, size, radius):
                i = (y * W + x) * 4
                cv.buf[i:i + 4] = b"\x00\x00\x00\x00"

    os.makedirs(RESOURCES, exist_ok=True)
    iconset = os.path.join(ROOT, "AppIcon.iconset")
    shutil.rmtree(iconset, ignore_errors=True)
    os.makedirs(iconset)
    master = os.path.join(iconset, "icon_512x512@2x.png")
    cv.png(master)
    sizes = [(16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
             (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
             (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
             (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
             (512, "icon_512x512.png")]
    for s, name in sizes:
        subprocess.run(["sips", "-z", str(s), str(s), master,
                        "--out", os.path.join(iconset, name)],
                       check=True, capture_output=True)
    icns = os.path.join(RESOURCES, "AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", icns], check=True)
    # Keep the master PNG for the landing page.
    shutil.copyfile(master, os.path.join(ROOT, "docs", "icon.png")) if \
        os.path.isdir(os.path.join(ROOT, "docs")) else None
    shutil.rmtree(iconset)
    print("icns:", icns)


if __name__ == "__main__":
    gen_sounds()
    gen_icon()
    print("Done.")
