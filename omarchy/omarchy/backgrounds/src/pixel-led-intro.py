# "Power on" intro for the pixel LED-panel wallpaper. The last frame is drawn
# with exactly the wallpaper's geometry and colours, so the handover is seamless.
import sys, os, math, random
out = sys.argv[1]
W, H = 2560, 1440
CELL, GAP = 25, 4
STEP = CELL + GAP
FPS = 30
T_END = 3.3            # animation; then a hold on the final frame
HOLD = 0.5
G = {
 '<': ["00010","00100","01000","10000","01000","00100","00010"],
 '>': ["01000","00100","00010","00001","00010","00100","01000"],
 '/': ["00001","00010","00010","00100","01000","01000","10000"],
}
TEXT = '</>'
def mix(a,b,t):
    a=[int(a[i:i+2],16) for i in (1,3,5)]; b=[int(b[i:i+2],16) for i in (1,3,5)]
    return '#'+''.join(f'{round(x+(y-x)*t):02x}' for x,y in zip(a,b))
def shade(t):
    t=max(0,min(1,t))
    return mix('#7dcfff','#7aa2f7',t*2) if t<0.5 else mix('#7aa2f7','#bb9af7',(t-0.5)*2)
def ease(x): x=max(0,min(1,x)); return 1-(1-x)**3
def smooth(x): x=max(0,min(1,x)); return x*x*(3-2*x)

cols_total = W // STEP; rows_total = H // STEP
ox = (W - cols_total*STEP)/2 + GAP/2; oy = (H - rows_total*STEP)/2 + GAP/2
ncols = len(TEXT)*5 + (len(TEXT)-1)
c0 = (cols_total - ncols)//2; r0 = (rows_total - 7)//2
lit = []   # (col,row,colour) in left-to-right order
for gi,ch in enumerate(TEXT):
    for r,row in enumerate(G[ch]):
        for c,v in enumerate(row):
            if v=='1':
                t=((gi*6+c)/(ncols-1))*0.6+(r/6)*0.4
                lit.append((c0+gi*6+c, r0+r, shade(t)))
litset = {(c,r) for c,r,_ in lit}
lit.sort(key=lambda p:(p[0],p[1]))
cx = (cols_total-1)/2; cy = (rows_total-1)/2
maxd = math.hypot(cx, cy)
mid_row = r0 + 3
random.seed(7)
flick = [random.random() for _ in range(200)]

def frame(t):
    # phases
    bg = smooth((t-0.75)/0.9)                    # navy fades in from black
    line_on = (t>=0.25) and (t<1.45)
    line_w = ease((t-0.25)/0.45)                 # warm-up line grows from the centre
    line_a = (0.55+0.45*flick[int(t*FPS)%200]) * (1 - smooth((t-1.05)/0.4))
    reach = ease((t-0.8)/1.0) * (maxd+6)        # grid spreads outward
    pop_start, pop_dur = 1.75, 1.0               # </> pixels light one by one
    glow = smooth((t-2.55)/0.7)
    final = t >= T_END
    if final: bg=1; reach=maxd+99; glow=1; line_on=False
    parts=[f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
  <defs>
    <radialGradient id="bg" cx="50%" cy="50%" r="75%"><stop offset="0" stop-color="#1e2030"/><stop offset="0.55" stop-color="#1a1b26"/><stop offset="1" stop-color="#15161e"/></radialGradient>
    <radialGradient id="fadeg" cx="50%" cy="50%" r="60%"><stop offset="0" stop-color="#fff" stop-opacity="1"/><stop offset="0.7" stop-color="#fff" stop-opacity="0.55"/><stop offset="1" stop-color="#fff" stop-opacity="0.25"/></radialGradient>
    <mask id="fade"><rect width="{W}" height="{H}" fill="url(#fadeg)"/></mask>
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="22"/></filter>
    <filter id="halo" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="90"/></filter>
    <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6"/></filter>
  </defs>
  <rect width="{W}" height="{H}" fill="#000"/>
  <rect width="{W}" height="{H}" fill="url(#bg)" opacity="{bg:.4f}"/>
''']
    # the unlit grid, revealed within `reach` of the centre with a soft edge
    if reach > 0:
        g=['  <g fill="#c0caf5" mask="url(#fade)">']
        for rr in range(rows_total):
            for col in range(cols_total):
                if (col,rr) in litset: continue
                d = math.hypot(col-cx, rr-cy)
                v = 1.0 if final else smooth((reach-d)/5.0)
                if v <= 0.002: continue
                # a brief brighter wave front as the grid switches on
                front = 0 if final else max(0, 1-abs(reach-d)/3.0)
                a = 0.045*v + 0.10*front
                g.append(f'<rect x="{ox+col*STEP:.1f}" y="{oy+rr*STEP:.1f}" width="{CELL}" height="{CELL}" rx="5" fill-opacity="{a:.4f}"/>')
        g.append('</g>\n'); parts.append(''.join(g))
    # warm-up line across the middle row
    if line_on and line_w > 0:
        half = line_w*(cols_total/2+1)
        g=[f'  <g fill="#7dcfff" opacity="{line_a:.3f}">']
        for col in range(cols_total):
            if abs(col-cx) <= half:
                g.append(f'<rect x="{ox+col*STEP:.1f}" y="{oy+mid_row*STEP:.1f}" width="{CELL}" height="{CELL}" rx="5" fill-opacity="0.35"/>')
        g.append('</g>\n'); parts.append(''.join(g))
        parts.append(f'  <rect x="{W/2-half*STEP:.1f}" y="{oy+mid_row*STEP+CELL/2-2:.1f}" width="{2*half*STEP:.1f}" height="4" fill="#7dcfff" opacity="{0.5*line_a:.3f}" filter="url(#soft)"/>\n')
    # the </> pixels, each popping on in turn
    n=len(lit); lits=[]
    for i,(col,rr,colr) in enumerate(lit):
        if final: a=1.0
        else:
            st = pop_start + pop_dur*i/n
            a = smooth((t-st)/0.09)
            if 0 < a < 1: a = min(1, a*1.35)   # a quick bright pop
        if a<=0: continue
        lits.append(f'<rect x="{ox+col*STEP:.1f}" y="{oy+rr*STEP:.1f}" width="{CELL}" height="{CELL}" rx="5" fill="{colr}" opacity="{min(1,a):.3f}"/>')
    litsvg=''.join(lits)
    if litsvg:
        parts.append(f'  <g filter="url(#halo)" opacity="{0.35*glow:.3f}">{litsvg}</g>\n')
        parts.append(f'  <g filter="url(#glow)" opacity="{0.55*glow:.3f}">{litsvg}</g>\n')
        parts.append(f'  <g>{litsvg}</g>\n')
    parts.append('</svg>\n')
    return ''.join(parts)

total = int(round((T_END+HOLD)*FPS))
for i in range(total+1):
    t = i/FPS
    open(os.path.join(out, f'f{i:04d}.svg'),'w').write(frame(t))
print(total+1)
