"""High-res page chrome for the calibration PDF (vectors rasterized at print DPI)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
CERT = ROOT / "assets" / "cert"
PREVIEW = ROOT / "tool" / "cert_preview"
PAPER = (252, 251, 248)
GRAPHITE = (43, 43, 43)
# Full-page JPEG hangs package:pdf; we embed only left/right strips.
DPI = 160
A4_W = int(round(210 / 25.4 * DPI))
A4_H = int(round(297 / 25.4 * DPI))
LEFT_FRAC = 0.12
RIGHT_FRAC = 0.26


def lerp(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        int(a[0] + (b[0] - a[0]) * t),
        int(a[1] + (b[1] - a[1]) * t),
        int(a[2] + (b[2] - a[2]) * t),
    )


def capsule(thickness: int, length: int, c1: tuple[int, int, int], c2: tuple[int, int, int]) -> Image.Image:
    im = Image.new("RGBA", (thickness, length), (0, 0, 0, 0))
    px = im.load()
    for y in range(length):
        col = lerp(c1, c2, y / max(1, length - 1))
        for x in range(thickness):
            px[x, y] = (*col, 255)
    mask = Image.new("L", (thickness, length), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, thickness - 1, length - 1],
        radius=max(1, thickness // 2),
        fill=255,
    )
    im.putalpha(mask)
    return im


def paste_rotated(
    base: Image.Image,
    cap: Image.Image,
    angle: float,
    cx: float,
    cy: float,
) -> None:
    rot = cap.rotate(angle, expand=True, resample=Image.Resampling.BICUBIC)
    x = int(cx - rot.width / 2)
    y = int(cy - rot.height / 2)
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer.paste(rot, (x, y), rot)
    composed = Image.alpha_composite(base.convert("RGBA"), layer)
    base.paste(composed.convert(base.mode))


def add_drawn_slashes(bg: Image.Image, *, cover: bool) -> None:
    w, h = bg.size
    scale = w / 525
    cream = (248, 214, 158)
    gold_a = (224, 168, 58)
    gold_b = (196, 148, 64)
    graphite = (52, 50, 46)
    specs = [
        (int(28 * scale), int(168 * scale), cream, gold_a, w + 8 * scale, -6 * scale),
        (int(20 * scale), int(150 * scale), gold_a, gold_b, w - 16 * scale, 22 * scale),
        (int(14 * scale), int(128 * scale), gold_b, cream, w - 38 * scale, 18 * scale),
        (int(11 * scale), int(96 * scale), (236, 198, 118), gold_b, w - 54 * scale, 34 * scale),
        (int(24 * scale), int(150 * scale), gold_b, gold_a, w + 6 * scale, h - 48 * scale),
    ]
    if cover:
        specs.append(
            (int(18 * scale), int(112 * scale), gold_a, cream, 24 * scale, h - 80 * scale)
        )
    else:
        specs.append(
            (int(18 * scale), int(112 * scale), graphite, (38, 38, 38), -4 * scale, 96 * scale)
        )
    rgba = bg.convert("RGBA")
    for thickness, length, c1, c2, cx, cy in specs:
        cap = capsule(max(8, int(thickness)), max(24, int(length)), c1, c2)
        paste_rotated(rgba, cap, 42, cx, cy)
    bg.paste(rgba.convert("RGB"))


def blend_logo_watermark(bg: Image.Image) -> None:
    logo_path = CERT / "logo_clear.png"
    if not logo_path.exists():
        return
    wm = Image.open(logo_path).convert("RGBA")
    target_w = int(bg.width * 0.42)
    ratio = target_w / max(1, wm.width)
    wm = wm.resize((target_w, max(1, int(wm.height * ratio))), Image.Resampling.LANCZOS)
    wm.putalpha(wm.getchannel("A").point(lambda a: int(a * 0.10)))
    cx = (bg.width - wm.width) // 2
    cy = int(bg.height * 0.40 - wm.height / 2)
    layer = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    layer.paste(wm, (cx, cy), wm)
    composed = Image.alpha_composite(bg.convert("RGBA"), layer)
    bg.paste(composed.convert("RGB"))


def make_cover() -> Image.Image:
    bg = Image.new("RGB", (A4_W, A4_H), GRAPHITE)
    add_drawn_slashes(bg, cover=True)
    return bg


def make_inner() -> Image.Image:
    bg = Image.new("RGB", (A4_W, A4_H), PAPER)
    add_drawn_slashes(bg, cover=False)
    blend_logo_watermark(bg)
    return bg


def save_jpeg(path: Path, im: Image.Image) -> None:
    im.convert("RGB").save(
        path,
        "JPEG",
        quality=93,
        optimize=True,
        progressive=False,
        subsampling=0,
    )


def save_strips(im: Image.Image, prefix: str) -> None:
    w, h = im.size
    left_w = max(8, int(w * LEFT_FRAC))
    right_w = max(8, int(w * RIGHT_FRAC))
    save_jpeg(CERT / f"{prefix}_left.jpg", im.crop((0, 0, left_w, h)))
    save_jpeg(CERT / f"{prefix}_right.jpg", im.crop((w - right_w, 0, w, h)))
    save_jpeg(CERT / f"{prefix}_bg.jpg", im)


def main() -> None:
    PREVIEW.mkdir(parents=True, exist_ok=True)
    cover = make_cover()
    intro = make_inner()
    save_strips(cover, "cover")
    save_strips(intro, "inner")
    cover.save(PREVIEW / "cover_bg_preview.png")
    intro.save(PREVIEW / "inner_bg_preview.png")
    for name in ("cover_left.jpg", "cover_right.jpg", "inner_left.jpg", "inner_right.jpg"):
        path = CERT / name
        print(name, Image.open(path).size, path.stat().st_size)


if __name__ == "__main__":
    main()
