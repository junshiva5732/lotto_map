"""Google Play 스토어 등록용 이미지 생성.
실행: python tool/make_store_assets.py
입력: assets/icon/icon.png, store/raw/*.png (에뮬레이터 스크린샷 720x1280)
출력: store/icon-512.png, store/feature-graphic.png, store/screenshots/NN.png (1080x1920)
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..")
STORE = os.path.join(ROOT, "store")
RAW = os.path.join(STORE, "raw")
SHOTS = os.path.join(STORE, "screenshots")
os.makedirs(SHOTS, exist_ok=True)

TOP = (229, 57, 53)
BOTTOM = (120, 10, 10)
CREAM = (255, 248, 230)
GOLD = (255, 200, 40)

FONT_BOLD = r"C:\Windows\Fonts\malgunbd.ttf"
FONT_REG = r"C:\Windows\Fonts\malgun.ttf"


def font(path, size):
    return ImageFont.truetype(path, size)


def gradient(w, h):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            k = (y / max(h - 1, 1)) * 0.65 + (x / max(w - 1, 1)) * 0.35
            px[x, y] = tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * k) for i in range(3))
    return img


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def shadow(base, box_size, pos, radius, blur=40, alpha=110):
    sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer = Image.new("RGBA", box_size, (0, 0, 0, alpha))
    sh.paste(layer, (pos[0], pos[1] + 24), rounded_mask(box_size, radius))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(sh)


# ---------------------------------------------------------------- 512 아이콘
icon = Image.open(os.path.join(ROOT, "assets", "icon", "icon.png")).convert("RGB")
icon.resize((512, 512), Image.LANCZOS).save(os.path.join(STORE, "icon-512.png"))

# ---------------------------------------------------------------- 피처 그래픽 1024x500
W, H = 1024, 500
fg = gradient(W, H).convert("RGBA")

isz = 300
ic = icon.resize((isz, isz), Image.LANCZOS).convert("RGBA")
ipos = (90, (H - isz) // 2)
shadow(fg, (isz, isz), ipos, 64)
fg.paste(ic, ipos, rounded_mask((isz, isz), 64))

d = ImageDraw.Draw(fg)
tx = 430
d.text((tx, 130), "로또 명당 지도", font=font(FONT_BOLD, 74), fill=CREAM)
d.text((tx + 4, 240), "전국 1등 배출점을 지도에서 한눈에", font=font(FONT_REG, 34), fill=(255, 226, 220))
d.text((tx + 4, 305), "당첨 이력 · 명당 랭킹 · 내 메모 · 행운 번호", font=font(FONT_REG, 27), fill=(255, 200, 190))
fg.convert("RGB").save(os.path.join(STORE, "feature-graphic.png"))

# ---------------------------------------------------------------- 스크린샷 1080x1920
SW, SH = 1080, 1920
shots = [
    ("s_map.png", "전국 로또 1등 배출점을", "지도에서 한눈에"),
    ("s_sheet.png", "핀을 누르면 바로", "당첨 이력과 정보"),
    ("s_ranking.png", "1등 횟수 랭킹과", "지역·기간 필터"),
    ("s_detail.png", "다녀온 명당에", "나만의 메모와 평점"),
    ("s_memo.png", "내가 저장한 명당", "한곳에 모아보기"),
    ("s_lucky.png", "오늘의 행운 번호도", "재미로 한 번"),
]
n = 0
for fname, line1, line2 in shots:
    src_path = os.path.join(RAW, fname)
    if not os.path.exists(src_path):
        print("skip (no raw):", fname)
        continue
    n += 1
    bg = gradient(SW, SH).convert("RGBA")
    d = ImageDraw.Draw(bg)

    f1 = font(FONT_REG, 58)
    f2 = font(FONT_BOLD, 76)
    for text, f, y in ((line1, f1, 150), (line2, f2, 230)):
        w = d.textlength(text, font=f)
        d.text(((SW - w) / 2, y), text, font=f, fill=CREAM)

    src = Image.open(src_path).convert("RGBA")
    src = src.crop((0, 48, src.width, src.height - 40))  # 상태바·내비 바 제거
    ph = SH - 420
    pw = int(src.width * ph / src.height)
    src = src.resize((pw, ph), Image.LANCZOS)
    ppos = ((SW - pw) // 2, 380)
    shadow(bg, (pw, ph), ppos, 48)
    border = Image.new("RGBA", (pw + 16, ph + 16), (255, 255, 255, 60))
    bg.paste(border, (ppos[0] - 8, ppos[1] - 8), rounded_mask((pw + 16, ph + 16), 56))
    bg.paste(src, ppos, rounded_mask((pw, ph), 48))

    bg.convert("RGB").save(os.path.join(SHOTS, f"{n:02d}.png"))

print("done:", os.path.abspath(STORE))
