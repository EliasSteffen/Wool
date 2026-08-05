#!/usr/bin/env python3
"""
Wool — Instagram portrait trailer builder.

Turns the three landscape gameplay screen-recordings into a 1080x1920 vertical
reel: a follow-cam keeps Wool centered, freeze-frames "pause" the action while a
headline explains a mechanic, then the game resumes. Logo intro/outro, the game's
own music bed + gameplay SFX.

Run (isolated env, does not touch the repo's Python project):
    uv run --no-project --with pillow --with numpy marketing/trailer/build_trailer.py

Only dependencies: Pillow, numpy, and ffmpeg/ffprobe on PATH.

Everything creative lives in the CONFIG / TIMELINE section near the top so the user
can tweak captions, timing, zoom, colors and re-render.
"""

import os
import subprocess
import sys
import tempfile
from dataclasses import dataclass

from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance
import numpy as np

# --------------------------------------------------------------------------- #
# Paths
# --------------------------------------------------------------------------- #
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TRAILER_DIR = os.path.join(REPO, "marketing", "trailer")
FONT_DIR = os.path.join(REPO, "assets", "font")
MUSIC = os.path.join(REPO, "assets", "sound", "game", "background.mp3")

CLIP = {
    "load": os.path.join(TRAILER_DIR, "Load-into-game-and-show-tutorial.mov"),
    "normal": os.path.join(TRAILER_DIR, "Normal-Gameplay.mov"),
    "fish": os.path.join(TRAILER_DIR, "Encounter-Enemy-Fish.mov"),
}
OUT = os.path.join(TRAILER_DIR, "wool_trailer_instagram.mp4")

# --------------------------------------------------------------------------- #
# Global config
# --------------------------------------------------------------------------- #
W, H = 1080, 1920          # portrait output
FPS = 60                   # match the 60fps source -> smooth camera moves
SRC_W, SRC_H = 2622, 1206  # source frame size
SRC_FPS = 60
FONT_HEAD = os.path.join(FONT_DIR, "Chopsticks.ttf")
FONT_KICK = os.path.join(FONT_DIR, "Lost-Tumbler.ttf")

# Brand palette (from the game art)
PINK = (217, 107, 125)
BLUE = (95, 92, 220)
RED = (226, 59, 52)
YELLOW = (245, 205, 66)
TAN = (217, 196, 160)
INK = (38, 32, 30)
WHITE = (245, 242, 236)

# Camera "height" presets = how many source pixels of height map onto the 1920px
# output. 1206 == full frame height (STRIP: portrait slice, no blur bars).
# <1206 == zoom in (PUNCH). ~4661 == whole board fits width-wise (WIDE, blur bars).
H_STRIP = 1206
H_WIDE = int(SRC_W / (W / H))   # source height s.t. full width fits -> 4661
H_LOGO = 3500                   # tighter WIDE for the logo cards (bigger logo)
CX0 = 1305                      # Wool's stable horizontal position (normal clip)


# --------------------------------------------------------------------------- #
# Timeline
# --------------------------------------------------------------------------- #
@dataclass
class Seg:
    name: str
    clip: str
    dur: float
    # source frames: (start, end) for moving segments, or a single int freeze frame
    frames: object
    # camera keyframes: list of (local_t_fraction, value); eased interpolation
    h: list
    cx: list
    cy: list
    caption: dict = None          # {text, accent, dot, kicker}
    paused: bool = False          # draw the game pause glyph
    use_audio: bool = True        # take original clip SFX for this (moving) segment
    ramp_frac: float = None       # decelerate source playback to a stop by this
                                  # local-time fraction, then hold (slow-mo freeze)


def kf(*pairs):
    """Keyframe helper: kf((0,a),(1,b)) -> [(0,a),(1,b)]."""
    return list(pairs)


CY_MID = SRC_H / 2

TIMELINE = [
    # 1. INTRO — logo card (WIDE), slow push in. Music fades in.
    Seg("intro", "load", 2.4, 24,
        h=kf((0, 3700), (1, 3350)),
        cx=kf((0, 1300)), cy=kf((0, 540)),
        use_audio=False),

    # 2. RUN 1 — Wool swinging (STRIP).
    Seg("run1", "normal", 1.20, (30, 97),
        h=kf((0, 1240), (1, 1190)),
        cx=kf((0, CX0)), cy=kf((0, CY_MID))),

    # 3. CAPTION 1 — slow-mo settle + zoom in, "Swing from pin to pin".
    Seg("cap1", "normal", 2.05, (97, 108), ramp_frac=0.42,
        h=kf((0, 1190), (0.42, 820), (1, 820)),
        cx=kf((0, CX0), (0.42, 1294)), cy=kf((0, CY_MID), (0.42, 1000)),
        caption=dict(text="Swing from pin to pin", accent=BLUE, dot=BLUE,
                     kicker="HOOK & SWING"),
        paused=True),

    # 4. RUN 2 — resume, ease back out (STRIP).
    Seg("run2", "normal", 1.13, (108, 166),
        h=kf((0, 820), (0.45, 1206), (1, 1206)),
        cx=kf((0, 1294), (0.45, CX0)), cy=kf((0, 1000), (0.45, CY_MID))),

    # 5. CAPTION 2 — slow-mo settle + zoom, "Red pins fall away".
    Seg("cap2", "normal", 1.95, (166, 176), ramp_frac=0.42,
        h=kf((0, 1206), (0.42, 860), (1, 860)),
        cx=kf((0, CX0), (0.42, 1294)), cy=kf((0, CY_MID), (0.42, 738)),
        caption=dict(text="Red pins fall away", accent=RED, dot=RED,
                     kicker="RISKY"),
        paused=True),

    # 6. FISH APPROACH — pull back to reveal the threat (STRIP -> WIDE).
    Seg("fish_in", "fish", 0.90, (14, 56),
        h=kf((0, 1206), (1, H_WIDE)),
        cx=kf((0, 1300), (1, 1311)), cy=kf((0, CY_MID))),

    # 7. CAPTION 3 — slow-mo settle, whole board visible, "Outrun the fish!".
    Seg("cap3", "fish", 1.95, (56, 62), ramp_frac=0.40,
        h=kf((0, H_WIDE), (0.40, int(H_WIDE * 0.96)), (1, int(H_WIDE * 0.96))),
        cx=kf((0, 1311)), cy=kf((0, CY_MID)),
        caption=dict(text="Outrun the fish!", accent=PINK, dot=RED,
                     kicker="DANGER"),
        paused=True),

    # 8. FISH DODGE — punch back in and follow Wool darting away.
    Seg("fish_dodge", "fish", 1.00, (62, 120),
        h=kf((0, int(H_WIDE * 0.96)), (0.30, 1000), (1, 1000)),
        cx=kf((0, 1311), (0.30, 1052), (0.55, 863), (0.8, 793), (1, 931)),
        cy=kf((0, CY_MID), (0.30, 950), (1, 780))),

    # 9. SPRINT — approach a pin, meter climbing (STRIP).
    Seg("sprint", "normal", 0.85, (128, 172),
        h=kf((0, 1206), (1, 1150)),
        cx=kf((0, CX0)), cy=kf((0, CY_MID))),

    # 10. CAPTION 4 — Wool hooked on the pin: slow-mo settle, caption lands just
    #     before the release.
    Seg("cap4", "normal", 1.85, (172, 178), ramp_frac=0.5,
        h=kf((0, 1150), (0.5, 900), (1, 900)),
        cx=kf((0, CX0), (0.5, 1255)), cy=kf((0, CY_MID), (0.5, 730)),
        caption=dict(text="Release for a boost!", accent=YELLOW, dot=YELLOW,
                     kicker="YELLOW PINS"),
        paused=True),

    # 11. BOOST — Wool releases; the launch burst fires (payoff, no caption).
    Seg("boost", "normal", 0.85, (178, 194),
        h=kf((0, 900), (0.35, 1206), (1, 1180)),
        cx=kf((0, 1255), (0.35, CX0)), cy=kf((0, 730), (0.35, CY_MID))),

    # 11. OUTRO — logo end card (WIDE), gentle pull. Music fades out.
    Seg("outro", "load", 2.40, 24,
        h=kf((0, 3350), (1, 3700)),
        cx=kf((0, 1300)), cy=kf((0, 540)),
        use_audio=False),
]


# --------------------------------------------------------------------------- #
# Interpolation
# --------------------------------------------------------------------------- #
def smoothstep(t):
    return t * t * (3 - 2 * t)


def interp(keys, t):
    if len(keys) == 1:
        return keys[0][1]
    if t <= keys[0][0]:
        return keys[0][1]
    if t >= keys[-1][0]:
        return keys[-1][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t0 <= t <= t1:
            f = smoothstep((t - t0) / (t1 - t0)) if t1 > t0 else 0
            return v0 + (v1 - v0) * f
    return keys[-1][1]


# --------------------------------------------------------------------------- #
# Source frame extraction / caching
# --------------------------------------------------------------------------- #
CACHE = {}  # (clip, frame_idx) -> PIL.Image


def extract_frames(clip_key, indices):
    """Extract the given source frame indices from a clip into the cache.

    ffmpeg's expression parser can't handle a huge ``eq(n,..)+..`` list, so we
    decode the contiguous [min,max] frame range in one pass (tiny expression) and
    load only the frames we actually need from the resulting sequence.
    """
    indices = sorted(set(int(i) for i in indices))
    missing = [i for i in indices if (clip_key, i) not in CACHE]
    if not missing:
        return
    mn, mx = missing[0], missing[-1]
    tmp = tempfile.mkdtemp(prefix=f"wool_{clip_key}_")
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", CLIP[clip_key],
           "-vf", f"select='between(n\\,{mn}\\,{mx})'", "-vsync", "0",
           os.path.join(tmp, "f_%05d.png")]
    subprocess.run(cmd, check=True)
    files = sorted(os.listdir(tmp))  # files[k] == source frame mn+k
    for idx in missing:
        pos = idx - mn
        if pos >= len(files):
            raise RuntimeError(f"{clip_key}: frame {idx} missing (got {len(files)})")
        CACHE[(clip_key, idx)] = Image.open(os.path.join(tmp, files[pos])).convert("RGB")


def seg_source_frames(seg):
    """Which source frame index each of the seg's output frames uses.

    With ``ramp_frac`` set, playback decelerates to a stop by that fraction of the
    segment (ease-out, velocity -> 0) and then holds on the last frame — a slow-mo
    settle into the freeze that the caption sits on top of.
    """
    n = max(1, round(seg.dur * FPS))
    if isinstance(seg.frames, int):
        return [seg.frames] * n
    s, e = seg.frames
    out = []
    for i in range(n):
        lt = i / max(1, n - 1)
        if seg.ramp_frac:
            u = min(lt / seg.ramp_frac, 1.0)
            f = 1 - (1 - u) ** 2          # decelerate to a stop at u == 1
        else:
            f = lt
        out.append(int(round(s + (e - s) * f)))
    return out


# --------------------------------------------------------------------------- #
# Camera compositing (the unified model)
# --------------------------------------------------------------------------- #
_BG_CACHE = {}


def blurred_bg(src):
    key = id(src)
    if key in _BG_CACHE:
        return _BG_CACHE[key]
    scale = max(W / SRC_W, H / SRC_H)
    bw, bh = int(SRC_W * scale) + 2, int(SRC_H * scale) + 2
    bg = src.resize((bw, bh), Image.LANCZOS)
    left = (bw - W) // 2
    top = (bh - H) // 2
    bg = bg.crop((left, top, left + W, top + H))
    bg = bg.filter(ImageFilter.GaussianBlur(38))
    bg = ImageEnhance.Brightness(bg).enhance(0.55)
    bg = ImageEnhance.Color(bg).enhance(0.9)
    _BG_CACHE[key] = bg
    return bg


def render_camera(src, h_src, cx, cy):
    """Compose one 1080x1920 frame from the source, centred on (cx,cy) with `h_src`
    source pixels of height filling the 1920px output.

    Uses a single sub-pixel affine transform (bicubic) sampling the *original* frame,
    so zoom/pan move continuously instead of stepping by whole pixels — that integer
    stepping is what made the earlier version judder. The affine coeffs map an output
    pixel (x,y) back to source (inv*x + c, inv*y + f).
    """
    inv = h_src / H              # source px per output px (== 1/scale)
    view_w = W * inv             # source px shown horizontally
    view_h = h_src               # source px shown vertically

    if view_h <= SRC_H and view_w <= SRC_W:
        # Zoom-in / strip: whole output lies inside the frame. Clamp the sampled
        # window so an off-centre subject never samples outside the frame (no black).
        c = min(max(cx - (W / 2) * inv, 0.0), SRC_W - view_w)
        f = min(max(cy - (H / 2) * inv, 0.0), SRC_H - view_h)
        return src.transform((W, H), Image.AFFINE, (inv, 0, c, 0, inv, f),
                             resample=Image.BICUBIC)

    # Wide: sharp frame (sub-pixel) composited over a blurred cover background.
    c = cx - (W / 2) * inv
    f = cy - (H / 2) * inv
    coeffs = (inv, 0, c, 0, inv, f)
    sharp = src.transform((W, H), Image.AFFINE, coeffs, resample=Image.BICUBIC)
    mask = Image.new("L", (SRC_W, SRC_H), 255).transform(
        (W, H), Image.AFFINE, coeffs, resample=Image.NEAREST, fillcolor=0)
    return Image.composite(sharp, blurred_bg(src), mask)


# --------------------------------------------------------------------------- #
# Caption / overlay drawing
# --------------------------------------------------------------------------- #
_FONT_CACHE = {}


def font(path, size):
    k = (path, size)
    if k not in _FONT_CACHE:
        _FONT_CACHE[k] = ImageFont.truetype(path, size)
    return _FONT_CACHE[k]


def wrap(draw, text, fnt, max_w):
    words = text.split()
    lines, cur = [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=fnt) <= max_w:
            cur = t
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


# Precomputed lower-gradient mask (reused for every caption frame)
_GRAD = None


def grad_mask():
    global _GRAD
    if _GRAD is None:
        col = np.zeros((H, 1), dtype=np.float32)
        start = int(H * 0.42)
        ys = np.arange(start, H)
        col[start:, 0] = ((ys - start) / (H - start)) ** 1.3
        _GRAD = col
    return _GRAD


def scrim(base, strength):
    """Darken the lower portion with a vertical gradient (0..1 strength)."""
    if strength <= 0:
        return base
    alpha = (grad_mask() * strength * 205).astype(np.uint8)
    alpha = np.repeat(alpha, W, axis=1)
    black = Image.new("RGB", (W, H), (10, 8, 12))
    mask = Image.fromarray(alpha, "L")
    return Image.composite(black, base, mask)


def draw_pause_glyph(img, alpha):
    if alpha <= 0:
        return
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy, r = W // 2, 150, 46
    a = int(255 * alpha)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, int(70 * alpha)))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 255, 255, a), width=5)
    bw, bh, gap = 10, 40, 9
    for dx in (-gap - bw, gap):
        d.rounded_rectangle([cx + dx, cy - bh // 2, cx + dx + bw, cy + bh // 2],
                            radius=4, fill=(255, 255, 255, a))


def draw_caption(img, cap, prog):
    """prog: 0..1 eased appearance (fade+slide)."""
    a = smoothstep(min(1.0, max(0.0, prog)))
    if a <= 0:
        return
    slide = int((1 - a) * 60)
    d = ImageDraw.Draw(img, "RGBA")
    head = font(FONT_HEAD, 96)
    kick = font(FONT_KICK, 40)
    max_w = int(W * 0.84)
    lines = wrap(d, cap["text"], head, max_w)
    line_h = int(head.size * 1.06)
    base_y = int(H * 0.72) + slide

    if cap.get("kicker"):
        kw = d.textlength(cap["kicker"], font=kick)
        ky = base_y - 66
        d.text(((W - kw) / 2 + 1, ky + 1), cap["kicker"], font=kick,
               fill=(0, 0, 0, int(150 * a)))
        d.text(((W - kw) / 2, ky), cap["kicker"], font=kick,
               fill=cap["accent"] + (int(255 * a),))

    y = base_y
    for ln in lines:
        lw = d.textlength(ln, font=head)
        x = (W - lw) / 2
        d.text((x + 3, y + 3), ln, font=head, fill=(0, 0, 0, int(150 * a)))
        d.text((x, y), ln, font=head, fill=WHITE + (int(255 * a),))
        y += line_h

    uw = int(W * 0.30 * a)
    uy = y + 14
    ux = (W - uw) // 2
    d.rounded_rectangle([ux, uy, ux + uw, uy + 8], radius=4,
                        fill=cap["accent"] + (int(255 * a),))
    dot = cap.get("dot")
    if dot and uw > 0:
        dr = 13
        dcx = ux - 34
        d.ellipse([dcx - dr, uy + 4 - dr, dcx + dr, uy + 4 + dr],
                  fill=dot + (int(255 * a),), outline=(255, 255, 255, int(220 * a)),
                  width=3)


# --------------------------------------------------------------------------- #
# Build video
# --------------------------------------------------------------------------- #
def build_video(video_path):
    need = {}
    for seg in TIMELINE:
        need.setdefault(seg.clip, set()).update(seg_source_frames(seg))
    for clip_key, idxs in need.items():
        print(f"  extracting {len(idxs)} frames from {clip_key} ...")
        extract_frames(clip_key, idxs)

    total_frames = sum(max(1, round(s.dur * FPS)) for s in TIMELINE)
    print(f"  rendering {total_frames} frames ({total_frames / FPS:.1f}s) ...")

    ff = subprocess.Popen(
        ["ffmpeg", "-y", "-loglevel", "error",
         "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
         "-i", "-", "-an",
         "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18",
         "-preset", "medium", "-movflags", "+faststart", video_path],
        stdin=subprocess.PIPE)

    done = 0
    for seg in TIMELINE:
        srcs = seg_source_frames(seg)
        n = len(srcs)
        for i, sidx in enumerate(srcs):
            lt = i / max(1, n - 1)
            src = CACHE[(seg.clip, sidx)]
            img = render_camera(src, interp(seg.h, lt),
                                interp(seg.cx, lt), interp(seg.cy, lt))
            if seg.caption:
                # let the slow-mo settle before the headline slides in
                appear_at = (seg.ramp_frac or 0.30) + 0.04
                appear = max(0.0, min(1.0, (lt - appear_at) / 0.18))
                fade_out = 1.0 if lt <= 0.9 else max(0.0, (1.0 - lt) / 0.1)
                vis = appear * fade_out
                img = scrim(img, 0.85 * vis)
                if seg.paused:
                    draw_pause_glyph(img, vis)
                draw_caption(img, seg.caption, vis)
            ff.stdin.write(img.tobytes())
            done += 1
        sys.stdout.write(f"\r    {done}/{total_frames}")
        sys.stdout.flush()
    print()
    ff.stdin.close()
    ff.wait()
    if ff.returncode != 0:
        raise RuntimeError("ffmpeg video encode failed")


# --------------------------------------------------------------------------- #
# Build audio (music bed + per-segment gameplay SFX)
# --------------------------------------------------------------------------- #
def build_audio(audio_path):
    total = sum(s.dur for s in TIMELINE)
    inputs = ["-i", MUSIC, "-i", CLIP["normal"], "-i", CLIP["fish"]]
    idx_of = {"normal": 1, "fish": 2}
    parts = [
        f"[0:a]atrim=0:{total:.3f},asetpts=PTS-STARTPTS,volume=0.55,"
        f"afade=t=in:st=0:d=1.2,afade=t=out:st={total - 1.6:.3f}:d=1.6[music]"
    ]
    labels = ["[music]"]

    offset, k = 0.0, 0
    for seg in TIMELINE:
        # only full-speed moving segments contribute SFX (freeze/slow-mo would desync)
        if seg.use_audio and not seg.caption and not isinstance(seg.frames, int):
            s, e = seg.frames
            ss, to = s / SRC_FPS, e / SRC_FPS
            delay = int(offset * 1000)
            lab = f"[s{k}]"
            parts.append(
                f"[{idx_of[seg.clip]}:a]atrim={ss:.3f}:{to:.3f},"
                f"asetpts=PTS-STARTPTS,volume=0.9,adelay={delay}|{delay}{lab}")
            labels.append(lab)
            k += 1
        offset += seg.dur

    mix = "".join(labels) + f"amix=inputs={len(labels)}:normalize=0:duration=longest[a]"
    filter_complex = ";".join(parts + [mix])
    cmd = ["ffmpeg", "-y", "-loglevel", "error", *inputs,
           "-filter_complex", filter_complex,
           "-map", "[a]", "-c:a", "aac", "-b:a", "192k", audio_path]
    subprocess.run(cmd, check=True)


# --------------------------------------------------------------------------- #
def main():
    for p in [MUSIC, *CLIP.values(), FONT_HEAD, FONT_KICK]:
        if not os.path.exists(p):
            print("MISSING:", p)
            sys.exit(1)

    tmpdir = tempfile.mkdtemp(prefix="wool_trailer_")
    video = os.path.join(tmpdir, "video.mp4")
    audio = os.path.join(tmpdir, "audio.m4a")

    print("[1/3] video ...")
    build_video(video)
    print("[2/3] audio ...")
    build_audio(audio)
    print("[3/3] mux ...")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error",
                    "-i", video, "-i", audio,
                    "-c:v", "copy", "-c:a", "copy", "-shortest", OUT], check=True)
    print("DONE ->", OUT)


if __name__ == "__main__":
    main()
