"""Pose model + renderer mirroring ExerciseFigure.swift, for checking the cartoons."""
import math
from PIL import Image, ImageDraw

TORSO, NECK, HEAD_R = 0.29, 0.035, 0.062
UPPER_ARM, FOREARM = 0.145, 0.135
THIGH, SHIN, FOOT = 0.205, 0.20, 0.065
FLOOR = 0.94
STAND_HIP_Y = FLOOR - THIGH - SHIN - 0.02

def d(theta):
    r = math.radians(theta)
    return (math.sin(r), math.cos(r))

def add(p, v, k=1.0):
    return (p[0] + v[0] * k, p[1] + v[1] * k)

BASE = dict(hip=(0.5, STAND_HIP_Y), torso=180, neck=180, ss=0.0, hs=0.0,
            na=(4, 6), fa=(-4, 4), nl=(2, 0), fl=(-2, 0), nf=90, ff=90)

def pose(**kw):
    p = dict(BASE)
    p.update(kw)
    return p

def joints(p):
    hip = p['hip']
    sh = add(hip, d(p['torso']), TORSO)
    perp_t = (-math.cos(math.radians(p['torso'])), math.sin(math.radians(p['torso'])))
    shn = add(sh, perp_t, p['ss'] / 2)
    shf = add(sh, perp_t, -p['ss'] / 2)
    hipn = add(hip, perp_t, p['hs'] / 2)
    hipf = add(hip, perp_t, -p['hs'] / 2)
    head = add(sh, d(p['neck']), NECK + HEAD_R)
    def arm(s, a):
        e = add(s, d(a[0]), UPPER_ARM)
        h = add(e, d(a[1]), FOREARM)
        return s, e, h
    def leg(h0, l, f):
        k = add(h0, d(l[0]), THIGH)
        a = add(k, d(l[1]), SHIN)
        t = add(a, d(f), FOOT)
        return h0, k, a, t
    return dict(hip=hip, sh=sh, head=head,
                near_arm=arm(shn, p['na']), far_arm=arm(shf, p['fa']),
                near_leg=leg(hipn, p['nl'], p['nf']), far_leg=leg(hipf, p['fl'], p['ff']))

def lerp(a, b, t):
    out = {}
    for k in a:
        va, vb = a[k], b[k]
        if isinstance(va, tuple):
            out[k] = tuple(x + (y - x) * t for x, y in zip(va, vb))
        else:
            out[k] = va + (vb - va) * t
    return out

# Colours
BODY, BODY_FAR = (148, 163, 184), (203, 213, 225)
WORK, WORK_FAR = (194, 65, 12), (253, 186, 116)
KIT, PLATE, FLOORC = (31, 41, 55), (55, 65, 81), (200, 200, 200)

def points(p):
    J = joints(p)
    pts = [J['hip'], J['sh'], add(J['head'], (0, -HEAD_R)), add(J['head'], (HEAD_R, 0)), add(J['head'], (-HEAD_R, 0))]
    for k in ('near_arm', 'far_arm', 'near_leg', 'far_leg'):
        pts += list(J[k])
    return pts

PROP_POINTS = {
    'bench': lambda pr: [(pr[1], pr[2]), (pr[1] + pr[3], pr[2])],
    'incline': lambda pr: [(pr[1], pr[2]), (pr[1] + pr[3], pr[2]), add((pr[1], pr[2]), d(180 + pr[4]), pr[5])],
    'seat': lambda pr: [(pr[1], pr[2]), (pr[1] + pr[3], pr[2])],
    'bar': lambda pr: [(pr[2], pr[1]), (pr[3], pr[1])],
    'dipbars': lambda pr: [(pr[2], pr[1]), (pr[3], pr[1])],
    'mat': lambda pr: [(pr[1], FLOOR), (pr[2], FLOOR)],
    'cable': lambda pr: [(pr[1], pr[2])],
    'cable2': lambda pr: [(pr[1], pr[2]), (pr[3], pr[4])],
    'treadmill': lambda pr: [(0.12, FLOOR), (0.86, 0.47)],
    'bike': lambda pr: [(0.21, 0.85), (0.83, 0.85), (0.72, 0.46)],
    'rower': lambda pr: [(0.08, FLOOR), (0.92, FLOOR - 0.16)],
    'legpress': lambda pr: [(0.06, 0.48), (pr[3], pr[4])],
    'footplate': lambda pr: [(pr[1], pr[2]), (pr[1], pr[3])],
}

def fit_for(frames, props):
    pts = [q for f in frames for q in points(f)]
    for pr in props:
        if pr[0] in PROP_POINTS:
            pts += PROP_POINTS[pr[0]](pr)
    minx = min(q[0] for q in pts) - 0.05; maxx = max(q[0] for q in pts) + 0.05
    miny = min(q[1] for q in pts) - 0.05
    s = min(1.0, (FLOOR - 0.0) / (FLOOR - miny), 1.0 / (maxx - minx))
    return s, (minx + maxx) / 2

def render(p, props, worked, size=240, fit=(1.0, 0.5)):
    S = 3  # supersample
    W = size * S
    fs, fcx = fit
    img = Image.new('RGB', (W, W), (255, 255, 255))
    g = ImageDraw.Draw(img)
    def P(pt): return ((0.5 + (pt[0] - fcx) * fs) * W, (FLOOR + (pt[1] - FLOOR) * fs) * W)
    def line(a, b, w, col):
        a, b = P(a), P(b)
        g.line([a, b], fill=col, width=int(w * W * fs))
        r = w * W * fs / 2
        for c in (a, b):
            g.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=col)
    def circle(c, r, col, outline=None, ow=0):
        c = P(c); r *= W * fs
        g.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=col, outline=outline, width=int(ow * W * fs))
    def rect(x, y, w, h, col):
        a, b = P((x, y)), P((x + w, y + h))
        g.rectangle([a[0], a[1], b[0], b[1]], fill=col)
    J = joints(p)
    line((0.04, FLOOR + 0.012), (0.96, FLOOR + 0.012), 0.008, FLOORC)
    # static props behind
    for pr in props:
        kind = pr[0]
        if kind == 'bench':   # x, y(top), w
            _, x, y, w = pr
            rect(x, y, w, 0.035, (100, 116, 139)); rect(x + 0.03, y + 0.035, 0.025, FLOOR - y - 0.035, KIT); rect(x + w - 0.055, y + 0.035, 0.025, FLOOR - y - 0.035, KIT)
        elif kind == 'incline':  # x, y, w, back angle (deg from vertical), back length
            _, x, y, w, ang, ln = pr
            rect(x, y, w, 0.035, (100, 116, 139)); rect(x + w / 2 - 0.0125, y + 0.035, 0.025, FLOOR - y - 0.035, KIT)
            top = add((x + 0.01, y), d(180 + ang), ln)
            line((x + 0.01, y + 0.012), top, 0.04, (100, 116, 139))
        elif kind == 'seat':  # x, y, w
            _, x, y, w = pr
            rect(x, y, w, 0.03, (100, 116, 139)); rect(x + w / 2 - 0.0125, y + 0.03, 0.025, FLOOR - y - 0.03, KIT)
        elif kind == 'bar':   # y, x0, x1
            _, y, x0, x1 = pr
            line((x0, y), (x1, y), 0.016, KIT)
        elif kind == 'dipbars':
            _, y, x0, x1 = pr
            line((x0, y), (x1, y), 0.016, KIT); line((x0 + 0.02, y), (x0 + 0.02, FLOOR), 0.014, KIT); line((x1 - 0.02, y), (x1 - 0.02, FLOOR), 0.014, KIT)
        elif kind == 'mat':
            _, x0, x1 = pr
            rect(x0, FLOOR - 0.012, x1 - x0, 0.016, (226, 232, 240))
        elif kind == 'treadmill':
            rect(0.12, FLOOR - 0.03, 0.72, 0.03, (100, 116, 139)); line((0.80, FLOOR - 0.03), (0.86, 0.48), 0.018, KIT); line((0.86, 0.48), (0.76, 0.47), 0.018, KIT)
        elif kind == 'bike':
            circle((0.30, 0.85), 0.085, None, KIT, 0.012); circle((0.74, 0.85), 0.085, None, KIT, 0.012)
            line((0.30, 0.85), (0.46, 0.60), 0.016, KIT); line((0.46, 0.60), (0.52, 0.80), 0.016, KIT); line((0.52, 0.80), (0.74, 0.85), 0.016, KIT); line((0.46, 0.60), (0.70, 0.52), 0.016, KIT); line((0.70, 0.52), (0.74, 0.85), 0.016, KIT)
            line((0.40, 0.585), (0.50, 0.585), 0.022, KIT); line((0.70, 0.52), (0.72, 0.46), 0.016, KIT)
        elif kind == 'rower':
            rect(0.08, FLOOR - 0.06, 0.84, 0.02, (100, 116, 139)); rect(0.80, FLOOR - 0.16, 0.10, 0.10, KIT)
        elif kind == 'legpress':
            rect(0.10, 0.70, 0.30, 0.03, (100, 116, 139)); line((0.12, 0.70), (0.06, 0.48), 0.035, (100, 116, 139))
            rect(0.12, 0.73, 0.03, FLOOR - 0.73, KIT); rect(0.34, 0.73, 0.03, FLOOR - 0.73, KIT)
            _, x0, y0, x1, y1 = pr
            line((x0, y0), (x1, y1), 0.014, KIT); line((x0 + 0.02, y0), (x0 + 0.02, FLOOR), 0.014, KIT); line((x1 - 0.02, y1 + 0.01), (x1 - 0.02, FLOOR), 0.014, KIT)
        elif kind == 'footplate':
            _, x, y0, y1 = pr
            line((x, y0), (x, y1), 0.025, KIT)
        elif kind == 'step':  # x0, x1, h
            _, x0, x1, h = pr
            rect(x0, FLOOR - h, x1 - x0, h, (100, 116, 139))
    na, fa, nl, fl = J['near_arm'], J['far_arm'], J['near_leg'], J['far_leg']
    front = p['ss'] > 0.05
    def col(part, far):
        far = far and not front
        if part in worked:
            return WORK_FAR if far else WORK
        return BODY_FAR if far else BODY
    # far limbs
    line(fl[0], fl[1], 0.068, col('thigh', True)); line(fl[1], fl[2], 0.06, col('shin', True)); line(fl[2], fl[3], 0.042, col('shin', True))
    line(fa[0], fa[1], 0.052, col('upper', True)); line(fa[1], fa[2], 0.046, col('fore', True))
    # torso
    tw = 0.11 + p['ss'] * 0.25
    line(J['hip'], J['sh'], tw, col('torso', False))
    if 'chest' in worked:
        line(add(J['hip'], d(p['torso']), TORSO * 0.55), J['sh'], tw * 0.8, WORK)
    if 'glutes' in worked:
        circle(add(J['hip'], d(p['torso'] - 180 + 0), 0.0), 0.05, WORK)
    circle(J['head'], HEAD_R, BODY)
    # eye: on facing side of head
    eye = add(J['head'], d(p['neck'] - 120), HEAD_R * 0.45)
    if p['ss'] > 0.05:
        circle(add(J['head'], (0.022, -0.01)), 0.009, (255, 255, 255)); circle(add(J['head'], (-0.022, -0.01)), 0.009, (255, 255, 255))
    else:
        circle(eye, 0.01, (255, 255, 255))
    # near limbs
    line(nl[0], nl[1], 0.072, col('thigh', False)); line(nl[1], nl[2], 0.062, col('shin', False)); line(nl[2], nl[3], 0.044, col('shin', False))
    line(na[0], na[1], 0.054, col('upper', False)); line(na[1], na[2], 0.048, col('fore', False))
    # hand-held props
    for pr in props:
        kind = pr[0]
        if kind == 'barbell':
            r = pr[1] if len(pr) > 1 else 0.075
            circle(na[2], r, PLATE); circle(na[2], 0.018, KIT)
        elif kind == 'dumbbells':
            for h in (fa[2], na[2]):
                line(add(h, (-0.03, 0)), add(h, (0.03, 0)), 0.04, KIT)
        elif kind == 'dumbbell_far':
            line(add(fa[2], (-0.03, 0)), add(fa[2], (0.03, 0)), 0.04, KIT)
        elif kind == 'kettlebell':
            c = add(na[2], (0, 0.045)); circle(c, 0.04, KIT); circle(na[2], 0.018, None, KIT, 0.008)
        elif kind == 'cable':
            _, ax, ay = pr
            circle((ax, ay), 0.022, KIT)
            g.line([P((ax, ay)), P(na[2])], fill=(60, 60, 60), width=max(1, int(0.006 * W)))
            circle(na[2], 0.016, KIT)
        elif kind == 'cable2':
            _, ax, ay, bx, by = pr
            circle((ax, ay), 0.022, KIT); circle((bx, by), 0.022, KIT)
            g.line([P((ax, ay)), P(na[2])], fill=(60, 60, 60), width=max(1, int(0.006 * W)))
            g.line([P((bx, by)), P(fa[2])], fill=(60, 60, 60), width=int(0.006 * W))
        elif kind == 'sled':  # plate at near foot
            a, t = nl[2], nl[3]
            mid = ((a[0] + t[0]) / 2, (a[1] + t[1]) / 2)
            v = d(pr[1])
            line(add(mid, v, -0.08), add(mid, v, 0.08), 0.03, KIT)
        elif kind == 'dumbbell_one':
            line(add(na[2], (-0.035, 0)), add(na[2], (0.035, 0)), 0.045, KIT)
        elif kind == 'barbell_hip':
            circle(add(J['hip'], (0.0, -0.07)), pr[1], PLATE); circle(add(J['hip'], (0.0, -0.07)), 0.018, KIT)
        elif kind == 'pad':
            circle(add(nl[2], d(p['nl'][1] + pr[1]), 0.04), 0.03, KIT)
        elif kind == 'handle':
            circle(na[2], 0.016, KIT)
    return img.resize((size, size), Image.LANCZOS)
