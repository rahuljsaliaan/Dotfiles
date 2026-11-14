# Shinkai's pixel LED-panel wallpapers: the Tokyo Night pixel-led wallpaper's
# panel (same 25 px cells, 4 px gaps, same </> in the middle) sunk into
# Material Ocean ink, in three scenes:
#
#   abyss     darker panel with scattered dim "bioluminescent" cells (default)
#   tide      a dim swell lit along the bottom of the panel, cyan -> teal
#   recolour  the panel and </> alone
#
# usage:
#   shinkai-pixel.py still <scene> <out.svg>   the wallpaper
#   shinkai-pixel.py off   <scene> <out.svg>   the same panel switched off, for
#                                               the focus sign on unfocused screens
#   shinkai-pixel.py intro <scene> <out-dir>   power-on intro frames (f0000.svg ...);
#                                               the last frame is the wallpaper itself
#
# Render with rsvg-convert, and the intro frames with ffmpeg at 30 fps
# (libx264, yuv420p), as for pixel-led-intro.py.
import sys, os, math, random

mode, scene, out = sys.argv[1], sys.argv[2], sys.argv[3]
if mode not in ('still', 'off', 'intro') or scene not in ('abyss', 'tide', 'recolour'):
    sys.exit(__doc__ or 'usage: shinkai-pixel.py still|off|intro abyss|tide|recolour <out>')

W, H = 2560, 1440
CELL, GAP = 25, 4
STEP = CELL + GAP
FPS = 30
T_END = 3.3            # animation; then a hold on the final frame
HOLD = 0.5
cols, rows = W // STEP, H // STEP
ox = (W - cols * STEP) / 2 + GAP / 2
oy = (H - rows * STEP) / 2 + GAP / 2

# Shinkai colors.toml: cyan, blue, magenta, foreground; teal is Material's.
CYAN, BLUE, PURPLE, TEAL = '#89ddff', '#82aaff', '#c792ea', '#80cbc4'
GRID = '#a6accd'
if scene == 'abyss':
    BG, BG_OFF = ('#11131f', '#0b0d14', '#07080c'), ('#0a0c12', '#07080c')
else:
    BG, BG_OFF = ('#151827', '#0f111a', '#090b10'), ('#0e1018', '#090b10')

G = {
 '<': ["00010", "00100", "01000", "10000", "01000", "00100", "00010"],
 '>': ["01000", "00100", "00010", "00001", "00010", "00100", "01000"],
 '/': ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
}
TEXT = '</>'

def mix(a, b, t):
    a = [int(a[i:i+2], 16) for i in (1, 3, 5)]; b = [int(b[i:i+2], 16) for i in (1, 3, 5)]
    return '#' + ''.join(f'{round(x + (y - x) * t):02x}' for x, y in zip(a, b))
def shade(t):
    t = max(0, min(1, t))
    return mix(CYAN, BLUE, t * 2) if t < 0.5 else mix(BLUE, PURPLE, (t - 0.5) * 2)
def ease(x): x = max(0, min(1, x)); return 1 - (1 - x) ** 3
def smooth(x): x = max(0, min(1, x)); return x * x * (3 - 2 * x)
def rect(c, r, extra=''):
    return f'<rect x="{ox + c * STEP:.1f}" y="{oy + r * STEP:.1f}" width="{CELL}" height="{CELL}" rx="5"{extra}/>'

# The </>, coloured cyan -> blue -> purple from left to right and top to bottom.
ncols = len(TEXT) * 5 + (len(TEXT) - 1)
c0, r0 = (cols - ncols) // 2, (rows - 7) // 2
lit = []
for gi, ch in enumerate(TEXT):
    for r, row in enumerate(G[ch]):
        for c, v in enumerate(row):
            if v == '1':
                t = ((gi * 6 + c) / (ncols - 1)) * 0.6 + (r / 6) * 0.4
                lit.append((c0 + gi * 6 + c, r0 + r, shade(t)))
litset = {(c, r) for c, r, _ in lit}
lit.sort(key=lambda p: (p[0], p[1]))

# The scene's own dim cells: (col, row, colour, opacity).
extra = []
if scene == 'tide':
    for c in range(cols):
        y = 41 + 1.7 * math.sin(2 * math.pi * c / 62 + 0.6) + 0.7 * math.sin(2 * math.pi * c / 23)
        crest = round(y)
        tcol = mix(CYAN, TEAL, c / (cols - 1))
        for r in range(crest, rows):
            d = r - crest
            op = 0.20 if d == 0 else max(0.0, 0.075 - d * 0.008)
            if op > 0.015:
                extra.append((c, r, tcol, op))
elif scene == 'abyss':
    rnd = random.Random(7)
    for _ in range(55):
        r = int(rows * (1 - rnd.random() ** 1.8))
        c = rnd.randrange(cols)
        if (c, r) in litset or abs(r - (r0 + 3)) < 6 and abs(c - (c0 + ncols / 2)) < 14:
            continue
        extra.append((c, r, rnd.choice([CYAN, TEAL, BLUE]), rnd.uniform(0.05, 0.22)))
extraset = {(c, r) for c, r, _, _ in extra}

cx, cy = (cols - 1) / 2, (rows - 1) / 2
maxd = math.hypot(cx, cy)
mid_row = r0 + 3
random.seed(7)
flick = [random.random() for _ in range(200)]
twinkle = {(c, r): random.random() for c, r, _, _ in extra}

DEFS = f'''  <defs>
    <radialGradient id="bg" cx="50%" cy="50%" r="75%"><stop offset="0" stop-color="{BG[0]}"/><stop offset="0.55" stop-color="{BG[1]}"/><stop offset="1" stop-color="{BG[2]}"/></radialGradient>
    <radialGradient id="bgoff" cx="50%" cy="50%" r="75%"><stop offset="0" stop-color="{BG_OFF[0]}"/><stop offset="1" stop-color="{BG_OFF[1]}"/></radialGradient>
    <radialGradient id="fadeg" cx="50%" cy="50%" r="60%"><stop offset="0" stop-color="#fff" stop-opacity="1"/><stop offset="0.7" stop-color="#fff" stop-opacity="0.55"/><stop offset="1" stop-color="#fff" stop-opacity="0.25"/></radialGradient>
    <mask id="fade"><rect width="{W}" height="{H}" fill="url(#fadeg)"/></mask>
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="22"/></filter>
    <filter id="halo" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="90"/></filter>
    <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="10"/></filter>
    <filter id="line" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6"/></filter>
  </defs>
'''
HEAD = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">\n'

def frame(t):
    bg = smooth((t - 0.75) / 0.9)                   # the ink fades in from black
    line_on = 0.25 <= t < 1.45
    line_w = ease((t - 0.25) / 0.45)                # warm-up line grows from the centre
    line_a = (0.55 + 0.45 * flick[int(t * FPS) % 200]) * (1 - smooth((t - 1.05) / 0.4))
    reach = ease((t - 0.8) / 1.0) * (maxd + 6)     # the grid spreads outward
    pop_start, pop_dur = 1.75, 1.0                  # the </> pixels light one by one
    glow = smooth((t - 2.55) / 0.7)
    final = t >= T_END
    if final:
        bg, reach, glow, line_on = 1, maxd + 99, 1, False
    p = [HEAD, DEFS]
    if not final:
        p.append(f'  <rect width="{W}" height="{H}" fill="#000"/>\n')
    p.append(f'  <rect width="{W}" height="{H}" fill="url(#bg)"' + ('' if final else f' opacity="{bg:.4f}"') + '/>\n')

    # The unlit grid, revealed within `reach` of the centre with a bright front.
    g = [f'  <g fill="{GRID}" mask="url(#fade)">']
    for r in range(rows):
        for c in range(cols):
            if (c, r) in litset or (c, r) in extraset:
                continue
            d = math.hypot(c - cx, r - cy)
            v = 1.0 if final else smooth((reach - d) / 5.0)
            if v <= 0.002:
                continue
            front = 0 if final else max(0, 1 - abs(reach - d) / 3.0)
            g.append(rect(c, r, f' fill-opacity="{0.045 * v + 0.10 * front:.4f}"'))
    g.append('</g>\n'); p.append(''.join(g))

    # The scene's cells switch on as the grid reaches them, each with a short
    # flicker (a twinkle for the abyss, a quick swell for the tide).
    if extra:
        soft, cells = [], []
        for c, r, colr, op in extra:
            d = math.hypot(c - cx, r - cy)
            if final:
                a = 1.0
            else:
                st = 0.8 + (d / (maxd + 6)) * 1.0 + 0.15 + twinkle[(c, r)] * 0.6
                a = smooth((t - st) / 0.25)
                if 0 < a < 1:
                    a = min(1, a * 1.6)
            if a <= 0:
                continue
            cells.append(rect(c, r, f' fill="{colr}" fill-opacity="{op * a:.3f}"'))
            if op > 0.2:
                soft.append(rect(c, r, f' fill="{colr}" fill-opacity="{op * a:.3f}"'))
        if soft:
            p.append('  <g filter="url(#soft)" opacity="0.6">' + ''.join(soft) + '</g>\n')
        if cells:
            p.append('  <g>' + ''.join(cells) + '</g>\n')

    # Warm-up line across the middle row.
    if line_on and line_w > 0:
        half = line_w * (cols / 2 + 1)
        g = [f'  <g fill="{CYAN}" opacity="{line_a:.3f}">']
        for c in range(cols):
            if abs(c - cx) <= half:
                g.append(rect(c, mid_row, ' fill-opacity="0.35"'))
        g.append('</g>\n'); p.append(''.join(g))
        p.append(f'  <rect x="{W / 2 - half * STEP:.1f}" y="{oy + mid_row * STEP + CELL / 2 - 2:.1f}" width="{2 * half * STEP:.1f}" height="4" fill="{CYAN}" opacity="{0.5 * line_a:.3f}" filter="url(#line)"/>\n')

    # The </>, each pixel popping on in turn, then the glow.
    n = len(lit); lits = []
    for i, (c, r, colr) in enumerate(lit):
        if final:
            a = 1.0
        else:
            st = pop_start + pop_dur * i / n
            a = smooth((t - st) / 0.09)
            if 0 < a < 1:
                a = min(1, a * 1.35)
        if a <= 0:
            continue
        lits.append(rect(c, r, f' fill="{colr}"' + ('' if a >= 1 else f' opacity="{a:.3f}"')))
    s = ''.join(lits)
    if s:
        if glow > 0:
            p.append(f'  <g filter="url(#halo)" opacity="{0.35 * glow:.3f}">{s}</g>\n')
            p.append(f'  <g filter="url(#glow)" opacity="{0.55 * glow:.3f}">{s}</g>\n')
        p.append(f'  <g>{s}</g>\n')
    p.append('</svg>\n')
    return ''.join(p)

def off():
    # The panel powered off: no glow from the centre, the grid flat and faint,
    # the </> a faint grey outline, the scene's cells dimmed to a trace.
    p = [HEAD, DEFS, f'  <rect width="{W}" height="{H}" fill="url(#bgoff)"/>\n']
    p.append(f'  <g fill="{GRID}" fill-opacity="0.028">' + ''.join(
        rect(c, r) for r in range(rows) for c in range(cols) if (c, r) not in litset and (c, r) not in extraset) + '</g>\n')
    if extra:
        p.append('  <g>' + ''.join(rect(c, r, f' fill="{colr}" fill-opacity="{op * 0.4:.3f}"') for c, r, colr, op in extra) + '</g>\n')
    p.append(f'  <g fill="{GRID}" fill-opacity="0.11">' + ''.join(rect(c, r) for c, r, _ in lit) + '</g>\n')
    p.append('</svg>\n')
    return ''.join(p)

if mode == 'still':
    open(out, 'w').write(frame(T_END))
elif mode == 'off':
    open(out, 'w').write(off())
else:
    os.makedirs(out, exist_ok=True)
    total = int(round((T_END + HOLD) * FPS))
    for i in range(total + 1):
        open(os.path.join(out, f'f{i:04d}.svg'), 'w').write(frame(i / FPS))
    print(total + 1)
