#!/usr/bin/env python3
"""
Exit Plan App Icon v6
Green background + glassy white phone handset
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import math

SIZE = 1024

def rounded_rect_mask(w, h, r):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=r, fill=255)
    return m

def v_gradient(w, h, top_rgba, bot_rgba):
    arr = np.zeros((h, w, 4), dtype=np.float32)
    ts  = np.linspace(0, 1, h).reshape(-1, 1)
    for c in range(4):
        arr[:, :, c] = top_rgba[c] + (bot_rgba[c] - top_rgba[c]) * ts
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")

def ellipse_sdf(W, H, cx, cy, rx, ry, edge=3.0):
    xs = np.arange(W, dtype=np.float64)
    ys = np.arange(H, dtype=np.float64)
    xx, yy = np.meshgrid(xs, ys)
    r = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
    d = (1.0 - r) * min(rx, ry)          # positive inside
    return np.clip(d / edge * 255, 0, 255)

def rect_sdf(W, H, x1, y1, x2, y2, edge=3.0):
    xs = np.arange(W, dtype=np.float64)
    ys = np.arange(H, dtype=np.float64)
    xx, yy = np.meshgrid(xs, ys)
    dx = np.minimum(xx - x1, x2 - xx)
    dy = np.minimum(yy - y1, y2 - yy)
    return np.clip(np.minimum(dx, dy) / edge * 255, 0, 255)

def main():
    canvas = v_gradient(SIZE, SIZE,
        top_rgba=(70, 210, 100, 255),
        bot_rgba=(28, 172, 62,  255)
    )

    # ── Phone handset (upright), rotated -45° so earpiece = top-right
    # Proportions tuned to match Apple Phone.app icon feel:
    #   • caps ~48 % wider than bar
    #   • visible handle ≈ 20 % of total height
    TW, TH = 280, 560

    ear   = ellipse_sdf(TW, TH, cx=140, cy=118, rx=126, ry=110)
    mouth = ellipse_sdf(TW, TH, cx=140, cy=442, rx=130, ry=113)
    bar   = rect_sdf  (TW, TH, x1=79,  y1=96,  x2=201, y2=464)  # 122 px wide = 48 % of ear

    alpha = np.maximum(np.maximum(ear, mouth), bar)

    ph          = np.zeros((TH, TW, 4), dtype=np.uint8)
    ph[..., :3] = 255
    ph[...,  3] = np.clip(alpha, 0, 255).astype(np.uint8)
    phone_img   = Image.fromarray(ph, "RGBA")

    # -45° (CW) puts earpiece at top-right, mouthpiece at bottom-left
    rotated = phone_img.rotate(-45, expand=True, resample=Image.BICUBIC)

    sc      = int(SIZE * 0.70) / max(rotated.size)
    new_sz  = (int(rotated.width * sc), int(rotated.height * sc))
    rotated = rotated.resize(new_sz, Image.LANCZOS)

    rx = (SIZE - rotated.width)  // 2 + 18
    ry = (SIZE - rotated.height) // 2 - 18

    pf = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pf.paste(rotated, (rx, ry), rotated)
    canvas.alpha_composite(pf)

    # ── Glass highlight
    hl_h   = int(SIZE * 0.44)
    ts     = np.linspace(0, 1, hl_h).reshape(-1, 1)
    hl_arr = np.zeros((hl_h, SIZE, 4), dtype=np.float32)
    hl_arr[:, :, :3] = 255
    hl_arr[:, :,  3] = 100 * (1 - ts) ** 1.6
    hl_img     = Image.fromarray(np.clip(hl_arr, 0, 255).astype(np.uint8), "RGBA")
    hl_mask    = rounded_rect_mask(SIZE, hl_h, 200)
    hl_clipped = Image.new("RGBA", (SIZE, hl_h), (0, 0, 0, 0))
    hl_clipped.paste(hl_img, mask=hl_mask)
    canvas.alpha_composite(hl_clipped, (0, 0))

    out = "/Users/temuujinb/Documents/Claude/Exit Plan/ExitPlan/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    canvas.convert("RGB").save(out, "PNG")
    print(f"Saved → {out}")

if __name__ == "__main__":
    main()
