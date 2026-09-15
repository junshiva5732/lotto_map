"""앱 아이콘 생성 스크립트. 실행: python tool/make_icon.py
assets/icon/icon.png (1024x1024, 배경 포함) 과
assets/icon/icon_fg.png (Android adaptive 전경, 투명 배경) 을 만든다.

디자인: 빨강 그라데이션 배경 + 크림색 지도 핀, 핀 안에 금색 로또공(1)."""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
os.makedirs(OUT, exist_ok=True)

TOP = (229, 57, 53)      # 0xFFE53935
BOTTOM = (141, 14, 14)   # 짙은 빨강
CREAM = (255, 248, 230)
GOLD = (255, 200, 40)
GOLD_DARK = (214, 150, 0)
INK = (60, 30, 10)

FONT_BOLD = r"C:\Windows\Fonts\arialbd.ttf"


def gradient_bg(size):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        for x in range(size):
            k = t * 0.7 + (x / (size - 1)) * 0.3
            px[x, y] = tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * k) for i in range(3))
    return img


def draw_symbol(layer, scale=1.0):
    """지도 핀 + 금색 공. layer 는 RGBA (1024x1024)."""
    s = SIZE * scale
    cx = SIZE * 0.5
    cy = SIZE * 0.44           # 핀 머리(원) 중심
    r = s * 0.27               # 핀 머리 반지름
    tip_y = cy + r * 2.05      # 핀 끝

    # 핀: 원 + 아래 꼬리 (원과 접하는 삼각형)
    pin = Image.new("L", (SIZE, SIZE), 0)
    pd = ImageDraw.Draw(pin)
    pd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    # 접선 근사: 원 중심에서 약간 아래의 좌우 점과 끝점을 잇는다
    k = 0.62
    pd.polygon([(cx - r * 0.78, cy + r * k), (cx + r * 0.78, cy + r * k), (cx, tip_y)], fill=255)
    pin = pin.filter(ImageFilter.GaussianBlur(1.2))
    layer.paste(Image.new("RGBA", (SIZE, SIZE), CREAM + (255,)), (0, 0), pin)

    # 금색 공 (핀 머리 안)
    br = r * 0.68
    ball = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    bd = ImageDraw.Draw(ball)
    bd.ellipse([cx - br, cy - br, cx + br, cy + br], fill=GOLD_DARK + (255,))
    bd.ellipse([cx - br * 0.96, cy - br * 1.0, cx + br * 0.96, cy + br * 0.92], fill=GOLD + (255,))
    # 하이라이트
    hl = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hd.ellipse([cx - br * 0.55, cy - br * 0.75, cx + br * 0.05, cy - br * 0.25], fill=(255, 255, 255, 120))
    hl = hl.filter(ImageFilter.GaussianBlur(br * 0.12))
    ball.alpha_composite(hl)
    layer.alpha_composite(ball)

    # 숫자 1
    d = ImageDraw.Draw(layer)
    f = ImageFont.truetype(FONT_BOLD, int(br * 1.35))
    txt = "1"
    bbox = d.textbbox((0, 0), txt, font=f)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text((cx - tw / 2 - bbox[0], cy - th / 2 - bbox[1]), txt, font=f, fill=INK + (255,))


def with_shadow(symbol):
    sh = symbol.filter(ImageFilter.GaussianBlur(SIZE * 0.025))
    sh = Image.eval(sh, lambda v: int(v * 0.45))
    black = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    black.paste((40, 0, 0, 255), (0, 0), sh.split()[3])
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.alpha_composite(black, (0, int(SIZE * 0.02)))
    out.alpha_composite(symbol)
    return out


# 1) 풀 아이콘 (iOS / 스토어용, 불투명)
bg = gradient_bg(SIZE).convert("RGBA")
sym = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw_symbol(sym)
bg.alpha_composite(with_shadow(sym))
bg.convert("RGB").save(os.path.join(OUT, "icon.png"))

# 2) Adaptive 전경 (Android): flutter_launcher_icons 가 16% 인셋을 넣으므로 축소하지 않는다
fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw_symbol(fg)
with_shadow(fg).save(os.path.join(OUT, "icon_fg.png"))

print("written:", os.path.abspath(OUT))
