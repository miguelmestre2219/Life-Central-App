"""Exercise motions. Each motion: frames (list of poses), loop flag, props, worked parts."""
import math
from figure import *

def ang(v):
    return math.degrees(math.atan2(v[0], v[1]))

def ik(base, target, a, b, bend):
    """Two-bone IK. bend=+1 or -1 picks which side the middle joint goes."""
    dx, dy = target[0] - base[0], target[1] - base[1]
    D = max(1e-6, min(math.hypot(dx, dy), a + b - 1e-4))
    phi = ang((dx, dy))
    cosA = (a * a + D * D - b * b) / (2 * a * D)
    alpha = math.degrees(math.acos(max(-1, min(1, cosA))))
    upper = phi + bend * alpha
    mid = add(base, d(upper), a)
    lower = ang((target[0] - mid[0], target[1] - mid[1]))
    return (round(upper, 1), round(lower, 1))

def shoulder_of(p):
    return add(p['hip'], d(p['torso']), TORSO)

def arms_to(p, near, far=None, bend=-1, fbend=None):
    sh = shoulder_of(p)
    perp = (-math.cos(math.radians(p['torso'])), math.sin(math.radians(p['torso'])))
    shn, shf = add(sh, perp, p['ss'] / 2), add(sh, perp, -p['ss'] / 2)
    p['na'] = ik(shn, near, UPPER_ARM, FOREARM, bend)
    p['fa'] = ik(shf, far or near, UPPER_ARM, FOREARM, fbend if fbend is not None else bend)
    return p

def legs_to(p, near, far=None, bend=1, fbend=None):
    hip = p['hip']
    perp = (-math.cos(math.radians(p['torso'])), math.sin(math.radians(p['torso'])))
    hn, hf = add(hip, perp, p['hs'] / 2), add(hip, perp, -p['hs'] / 2)
    p['nl'] = ik(hn, near, THIGH, SHIN, bend)
    p['fl'] = ik(hf, far or near, THIGH, SHIN, fbend if fbend is not None else bend)
    return p

ANKLE_Y = FLOOR - 0.02
FRONT = dict(ss=0.17, hs=0.08, nf=60, ff=-60, na=(8, 4), fa=(-8, -4), nl=(3, 0), fl=(-3, 0))

M = {}

# ---------- Shoulders / chest / arms ----------
ohp_start = pose(na=(28, 172), fa=(24, 170))
ohp_end = pose(na=(176, 178), fa=(174, 177))
M['overhead-press'] = dict(frames=[ohp_start, ohp_end], props=[('barbell', 0.075)], worked={'upper'})
M['dumbbell-shoulder-press'] = dict(frames=[pose(na=(20, 168), fa=(16, 166)), ohp_end], props=[('dumbbells',)], worked={'upper'})

BENCH_HIP = (0.60, 0.605)
def bench_body(**kw):
    p = pose(hip=BENCH_HIP, torso=-90, neck=-90, nf=80, ff=80)
    legs_to(p, (0.76, ANKLE_Y), (0.74, ANKLE_Y), bend=1)
    p.update(kw)
    return p
bp_top = arms_to(bench_body(), (0.34, 0.33))
bp_bottom = arms_to(bench_body(), (0.35, 0.585), bend=-1)
M['bench-press'] = dict(frames=[bp_top, bp_bottom], props=[('bench', 0.14, 0.66, 0.56), ('barbell', 0.08)], worked={'chest', 'upper'}, start=0)
M['dumbbell-bench-press'] = dict(frames=[arms_to(bench_body(), (0.32, 0.33)), arms_to(bench_body(), (0.34, 0.53), bend=-1)],
                                 props=[('bench', 0.14, 0.66, 0.56), ('dumbbells',)], worked={'chest', 'upper'})

INC_HIP = (0.56, 0.68)
def incline_body():
    p = pose(hip=INC_HIP, torso=228, neck=215, nf=85, ff=85)
    legs_to(p, (0.80, ANKLE_Y), (0.78, ANKLE_Y), bend=1)
    return p
ib = incline_body(); sh = shoulder_of(ib)
M['incline-dumbbell-press'] = dict(frames=[arms_to(incline_body(), add(sh, (0.07, -0.27))), arms_to(incline_body(), add(sh, (0.02, -0.02)), bend=1)],
                                   props=[('incline', 0.50, 0.72, 0.22, 48, 0.36), ('dumbbells',)], worked={'chest', 'upper'})

lat_start = pose(**{**FRONT, 'na': (16, 10), 'fa': (-16, -10)})
lat_end = pose(**{**FRONT, 'na': (84, 88), 'fa': (-84, -88)})
M['lateral-raise'] = dict(frames=[lat_start, lat_end], props=[('dumbbells',)], worked={'upper'})

jj_start = pose(**{**FRONT, 'na': (16, 10), 'fa': (-16, -10), 'nl': (2, 0), 'fl': (-2, 0)})
jj_end = pose(**{**FRONT, 'na': (150, 165), 'fa': (-150, -165), 'nl': (16, 14), 'fl': (-16, -14), 'hip': (0.5, STAND_HIP_Y + 0.012)})
M['jumping-jack'] = dict(frames=[jj_start, jj_end], props=[], worked={'thigh', 'shin'}, period=1.0)

fly_s = pose(**FRONT); sh = shoulder_of(fly_s)
fly_start = arms_to(dict(fly_s), (0.86, 0.30), (0.14, 0.30), bend=-1, fbend=1)
fly_end = arms_to(dict(fly_s), (0.52, 0.42), (0.48, 0.42), bend=-1, fbend=1)
M['chest-fly'] = dict(frames=[fly_start, fly_end], props=[('cable2', 0.94, 0.10, 0.06, 0.10)], worked={'chest', 'upper'})

push_s = pose(torso=172, na=(4, 115), fa=(2, 112))
push_e = pose(torso=172, na=(4, 8), fa=(2, 6))
M['tricep-pushdown'] = dict(frames=[push_s, push_e], props=[('cable', 0.66, 0.06)], worked={'upper'})

curl_s = pose(na=(2, 4), fa=(-2, 2))
curl_e = pose(na=(4, 155), fa=(0, 150))
M['bicep-curl'] = dict(frames=[curl_s, curl_e], props=[('dumbbells',)], worked={'upper'})
M['hammer-curl'] = dict(frames=[curl_s, curl_e], props=[('dumbbells',)], worked={'upper', 'fore'})

ote_s = pose(na=(172, -30), fa=(168, -34))
ote_e = pose(na=(172, 178), fa=(168, 176))
M['overhead-tricep-extension'] = dict(frames=[ote_s, ote_e], props=[('dumbbell_one',)], worked={'upper'})

# ---------- Back ----------
SEAT_HIP = (0.42, 0.71)
def seated(torso=188, **kw):
    p = pose(hip=SEAT_HIP, torso=torso, nf=90, ff=90)
    legs_to(p, (0.62, ANKLE_Y), (0.60, ANKLE_Y), bend=1)
    p.update(kw)
    return p
lp_s = seated(); sh = shoulder_of(lp_s); arms_to(lp_s, (sh[0] + 0.07, sh[1] - 0.27))
lp_e = seated(torso=196); sh = shoulder_of(lp_e); arms_to(lp_e, (sh[0] + 0.08, sh[1] - 0.01), bend=1)
M['lat-pulldown'] = dict(frames=[lp_s, lp_e], props=[('seat', 0.32, 0.75, 0.2), ('cable', 0.55, 0.04)], worked={'torso', 'upper'})

row_hip = (0.38, 0.0)
def bent(torso=118):
    p = pose(torso=torso, neck=110)
    p['hip'] = (0.37, 0.545)
    legs_to(p, (0.50, ANKLE_Y), (0.48, ANKLE_Y), bend=1)
    return p
r_s = bent(); sh = shoulder_of(r_s); arms_to(r_s, (sh[0] + 0.01, sh[1] + 0.275))
r_e = bent(); arms_to(r_e, (0.49, 0.50), bend=1)
M['barbell-row'] = dict(frames=[r_s, r_e], props=[('barbell', 0.075)], worked={'torso', 'upper'})

CR_HIP = (0.30, 0.80)
def floor_seat(torso):
    p = pose(hip=CR_HIP, torso=torso, neck=torso - 5, nf=150, ff=150)
    legs_to(p, (0.62, 0.84), (0.60, 0.84), bend=1)
    return p
cr_s = floor_seat(155); arms_to(cr_s, (0.70, 0.62))
cr_e = floor_seat(192); arms_to(cr_e, (0.40, 0.66), bend=1)
M['seated-cable-row'] = dict(frames=[cr_s, cr_e], props=[('seat', 0.18, 0.84, 0.22), ('footplate', 0.66, 0.74, 0.92), ('cable', 0.93, 0.70)], worked={'torso', 'upper'})

fp_s = pose(); sh = shoulder_of(fp_s); arms_to(fp_s, (sh[0] + 0.27, sh[1] - 0.04))
fp_e = pose(); arms_to(fp_e, (sh[0] - 0.02, sh[1] - 0.12), bend=1)
M['face-pull'] = dict(frames=[fp_s, fp_e], props=[('cable', 0.92, 0.17)], worked={'upper', 'torso'})

BAR_Y = 0.07
def hang(sh_y, torso=182, legs=((14, -88), (8, -94))):
    p = pose(torso=torso, neck=torso, nl=legs[0], fl=legs[1], nf=40, ff=40)
    shx = 0.5
    p['hip'] = (shx - TORSO * math.sin(math.radians(torso)), sh_y - TORSO * math.cos(math.radians(torso)))
    return p
pu_s = arms_to(hang(0.36), (0.52, BAR_Y), (0.48, BAR_Y), bend=1)
pu_e = arms_to(hang(0.19, torso=172), (0.52, BAR_Y), (0.48, BAR_Y), bend=1)
M['pull-up'] = dict(frames=[pu_s, pu_e], props=[('bar', BAR_Y, 0.25, 0.75)], worked={'torso', 'upper'})
M['chin-up'] = dict(frames=[pu_s, pu_e], props=[('bar', BAR_Y, 0.25, 0.75)], worked={'torso', 'upper'})

hl_s = arms_to(hang(0.36, legs=((6, -18), (2, -22))), (0.52, BAR_Y), (0.48, BAR_Y), bend=1)
hl_e = arms_to(hang(0.36, torso=186, legs=((88, 92), (84, 90))), (0.52, BAR_Y), (0.48, BAR_Y), bend=1)
for p in (hl_s, hl_e): p['nf'] = p['nl'][1] + 90; p['ff'] = p['fl'][1] + 90
M['hanging-leg-raise'] = dict(frames=[hl_s, hl_e], props=[('bar', BAR_Y, 0.25, 0.75)], worked={'torso', 'thigh'})

DIP_Y = 0.50
def dip(sh_y, torso):
    p = pose(torso=torso, neck=torso - 10, nl=(18, -95), fl=(12, -100), nf=0, ff=0)
    p['hip'] = (0.5 - TORSO * math.sin(math.radians(torso)), sh_y - TORSO * math.cos(math.radians(torso)))
    return p
dp_s = arms_to(dip(DIP_Y - 0.27, 176), (0.51, DIP_Y), (0.49, DIP_Y), bend=-1)
dp_e = arms_to(dip(DIP_Y - 0.13, 160), (0.53, DIP_Y), (0.51, DIP_Y), bend=-1)
M['dip'] = dict(frames=[dp_s, dp_e], props=[('dipbars', DIP_Y, 0.36, 0.66)], worked={'upper', 'chest'})

# ---------- Legs ----------
def standing_bar(p):
    sh = shoulder_of(p)
    return arms_to(p, (sh[0] - 0.035, sh[1] + 0.005), bend=-1)
sq_s = standing_bar(pose(neck=176))
sq_e = pose(torso=142, neck=158, hip=(0.385, 0.70))
legs_to(sq_e, (0.507, ANKLE_Y), (0.49, ANKLE_Y), bend=1); standing_bar(sq_e)
M['squat'] = dict(frames=[sq_s, sq_e], props=[('barbell', 0.08)], worked={'thigh', 'glutes'})

gs_s = pose(); sh = shoulder_of(gs_s); arms_to(gs_s, (sh[0] + 0.07, sh[1] + 0.07), bend=1)
gs_e = pose(torso=160, neck=172, hip=(0.40, 0.71)); legs_to(gs_e, (0.507, ANKLE_Y), (0.49, ANKLE_Y), bend=1)
sh = shoulder_of(gs_e); arms_to(gs_e, (sh[0] + 0.07, sh[1] + 0.07), bend=1)
M['goblet-squat'] = dict(frames=[gs_s, gs_e], props=[('dumbbell_one',)], worked={'thigh', 'glutes'})

rdl_s = pose()
rdl_e = pose(torso=122, neck=118, hip=(0.40, 0.54)); legs_to(rdl_e, (0.507, ANKLE_Y), (0.49, ANKLE_Y), bend=1)
sh = shoulder_of(rdl_e); arms_to(rdl_e, (0.545, sh[1] + 0.27))
M['romanian-deadlift'] = dict(frames=[rdl_s, rdl_e], props=[('barbell', 0.075)], worked={'thigh', 'glutes', 'torso'})

dl_s = pose(torso=118, neck=110, hip=(0.385, 0.665)); legs_to(dl_s, (0.507, ANKLE_Y), (0.49, ANKLE_Y), bend=1)
arms_to(dl_s, (0.53, FLOOR - 0.082))
dl_e = pose()
M['deadlift'] = dict(frames=[dl_s, dl_e], props=[('barbell', 0.082)], worked={'thigh', 'glutes', 'torso'})

LP_HIP = (0.30, 0.66)
def lp(ankle):
    p = pose(hip=LP_HIP, torso=236, neck=215, nf=208, ff=208)
    legs_to(p, ankle, (ankle[0] - 0.015, ankle[1] + 0.01), bend=1)
    sh = shoulder_of(p); arms_to(p, (0.40, 0.70), bend=1)
    return p
M['leg-press'] = dict(frames=[lp((0.47, 0.51)), lp((0.63, 0.42))], props=[('legpress', 0.44, 0.60, 0.86, 0.37), ('sled', 208)], worked={'thigh', 'glutes'})

ln_s = pose(hip=(0.45, STAND_HIP_Y))
ln_e = pose(hip=(0.45, 0.70), nf=90, ff=40); legs_to(ln_e, (0.64, ANKLE_Y), (0.20, 0.905), bend=1, fbend=1)
M['walking-lunge'] = dict(frames=[ln_s, ln_e], props=[('dumbbells',)], worked={'thigh', 'glutes'})

bs_s = pose(hip=(0.47, 0.56), nf=90, ff=-60); legs_to(bs_s, (0.63, ANKLE_Y), (0.22, 0.655), bend=1, fbend=1)
bs_e = pose(hip=(0.45, 0.70), nf=90, ff=-60); legs_to(bs_e, (0.63, ANKLE_Y), (0.22, 0.655), bend=1, fbend=1)
M['bulgarian-split-squat'] = dict(frames=[bs_s, bs_e], props=[('bench', 0.04, 0.66, 0.26), ('dumbbells',)], worked={'thigh', 'glutes'})

cf_s = pose()
cf_e = pose(hip=(0.518, STAND_HIP_Y - 0.045), nf=46, ff=46)
M['calf-raise'] = dict(frames=[cf_s, cf_e], props=[('dumbbells',)], worked={'shin'})

le_s = seated(torso=182); le_s['nl'] = (88, 2); le_s['fl'] = (86, 0); le_s['nf'] = 90; le_s['ff'] = 90
le_e = seated(torso=182); le_e['nl'] = (88, 86); le_e['fl'] = (86, 84); le_e['nf'] = 176; le_e['ff'] = 174
for p in (le_s, le_e): p['na'] = (8, 50); p['fa'] = (4, 46)
M['leg-extension'] = dict(frames=[le_s, le_e], props=[('seat', 0.30, 0.75, 0.26), ('pad', 90)], worked={'thigh'})

lc_base = dict(hip=(0.44, 0.60), torso=90, neck=82, nl=(-90, -90), fl=(-90, -90), nf=-90, ff=-90, na=(2, 70), fa=(0, 66))
lc_s = pose(**lc_base)
lc_e = pose(**{**lc_base, 'nl': (-90, -175), 'fl': (-90, -172), 'nf': -265, 'ff': -262})
M['leg-curl'] = dict(frames=[lc_s, lc_e], props=[('bench', 0.18, 0.645, 0.62), ('pad', -90)], worked={'thigh'})

HT_SH = (0.23, 0.655)
def thrust(torso):
    p = pose(torso=torso, neck=torso + 15, nf=88, ff=88)
    p['hip'] = (HT_SH[0] - TORSO * math.sin(math.radians(torso)), HT_SH[1] - TORSO * math.cos(math.radians(torso)))
    legs_to(p, (0.66, ANKLE_Y), (0.64, ANKLE_Y), bend=1)
    arms_to(p, add(p['hip'], (0.02, -0.05)), bend=1)
    return p
M['hip-thrust'] = dict(frames=[thrust(-122), thrust(-91)], props=[('bench', 0.04, 0.68, 0.22), ('barbell_hip', 0.075)], worked={'glutes', 'thigh'})

GB_SH = (0.22, 0.875)
def bridge(torso):
    p = pose(torso=torso, neck=torso, nf=88, ff=88)
    p['hip'] = (GB_SH[0] - TORSO * math.sin(math.radians(torso)), GB_SH[1] - TORSO * math.cos(math.radians(torso)))
    legs_to(p, (0.62, ANKLE_Y), (0.60, ANKLE_Y), bend=1)
    arms_to(p, (0.40, 0.915), bend=1)
    return p
M['glute-bridge'] = dict(frames=[bridge(-92), bridge(-68)], props=[('mat', 0.08, 0.80)], worked={'glutes', 'thigh'})

kb_s = pose(torso=118, neck=110, hip=(0.38, 0.58)); legs_to(kb_s, (0.507, ANKLE_Y), (0.48, ANKLE_Y), bend=1)
arms_to(kb_s, (0.43, 0.70))
kb_e = pose(na=(92, 92), fa=(88, 88))
M['kettlebell-swing'] = dict(frames=[kb_s, kb_e], props=[('kettlebell',)], worked={'glutes', 'thigh', 'torso'})

# ---------- Core / floor ----------
def plank_line(sh, torso, hands_mode):
    p = pose(torso=torso, neck=torso - 15, nf=0, ff=0)
    p['hip'] = (sh[0] - TORSO * math.sin(math.radians(torso)), sh[1] - TORSO * math.cos(math.radians(torso)))
    leg = torso - 180
    p['nl'] = (leg, leg); p['fl'] = (leg, leg)
    p['nf'] = leg + 75; p['ff'] = leg + 75
    return p
pl_s = plank_line((0.68, 0.78), 99, 'forearm'); pl_s['na'] = (0, 90); pl_s['fa'] = (-2, 88)
pl_e = plank_line((0.68, 0.778), 99.5, 'forearm'); pl_e['na'] = (0, 90); pl_e['fa'] = (-2, 88)
M['plank'] = dict(frames=[pl_s, pl_e], props=[('mat', 0.10, 0.86)], worked={'torso'}, period=3.0)

pu_top = plank_line((0.66, 0.64), 113, ''); arms_to(pu_top, (0.68, 0.92), (0.66, 0.92), bend=-1)
pu_bot = plank_line((0.66, 0.80), 100, ''); arms_to(pu_bot, (0.68, 0.92), (0.66, 0.92), bend=-1)
M['push-up'] = dict(frames=[pu_top, pu_bot], props=[('mat', 0.10, 0.86)], worked={'chest', 'upper'})

mc_s = dict(pu_top); mc_e = dict(pu_top)
hipx = pu_top['hip']
mc_s = dict(pu_top); legs_to(mc_s, (0.52, 0.86), None, bend=-1); mc_s['fl'] = pu_top['fl']; mc_s['nf'] = 20
mc_e = dict(pu_top); legs_to(mc_e, (0.52, 0.86), None, bend=-1); mc_e['nl'] = pu_top['nl']; mc_e['nf'] = pu_top['nf']; mc_e['ff'] = 20
M['mountain-climber'] = dict(frames=[mc_s, mc_e], props=[('mat', 0.10, 0.86)], worked={'torso', 'thigh'}, period=0.9)

CR = (0.50, 0.875)
def crunch(torso):
    p = pose(hip=CR, torso=torso, neck=torso + 10, nf=92, ff=92)
    legs_to(p, (0.74, ANKLE_Y), (0.72, ANKLE_Y), bend=1)
    head = add(shoulder_of(p), d(p['neck']), NECK + HEAD_R)
    arms_to(p, add(head, d(p['neck'] + 90), 0.05), bend=-1)
    return p
M['crunch'] = dict(frames=[crunch(-90), crunch(-118)], props=[('mat', 0.10, 0.86)], worked={'torso'})

# ---------- Cardio ----------
def runner(phase, scale=1.0, lean=172, bob=0.0):
    k = scale
    a = dict(nl=(38 * k, 8 * k), fl=(-22 * k, -75 * k), na=(-35 * k, 20 * k), fa=(35 * k, 120 * k), nf=95, ff=60)
    b = dict(nl=(-22 * k, -75 * k), fl=(38 * k, 8 * k), na=(35 * k, 120 * k), fa=(-35 * k, 20 * k), nf=60, ff=95)
    mid1 = dict(nl=(10 * k, -40 * k), fl=(5 * k, -20 * k), na=(0, 70 * k), fa=(0, 70 * k), nf=80, ff=80)
    mid2 = dict(nl=(5 * k, -20 * k), fl=(10 * k, -40 * k), na=(0, 70 * k), fa=(0, 70 * k), nf=80, ff=80)
    frames = []
    for f in (a, mid1, b, mid2):
        p = pose(torso=lean, neck=lean + 4, **f)
        lowest = max(math.cos(math.radians(f['nl'][0])) * THIGH + math.cos(math.radians(f['nl'][1])) * SHIN,
                     math.cos(math.radians(f['fl'][0])) * THIGH + math.cos(math.radians(f['fl'][1])) * SHIN)
        p['hip'] = (0.48, ANKLE_Y - lowest - bob)
        frames.append(p)
    return frames
M['running'] = dict(frames=runner(0, 1.0), props=[('treadmill',)], worked={'thigh', 'shin'}, loop=True, period=0.8)
M['walking'] = dict(frames=runner(0, 0.55, lean=178), props=[], worked={'thigh', 'shin'}, loop=True, period=1.3)

BIKE_HIP = (0.45, 0.565)
def bike(angle):
    p = pose(hip=BIKE_HIP, torso=128, neck=110)
    c, r = (0.53, 0.80), 0.075
    pn = add(c, d(angle), r); pf = add(c, d(angle + 180), r)
    legs_to(p, add(pn, (-0.03, -0.01)), add(pf, (-0.03, -0.01)), bend=1)
    p['nf'] = 100; p['ff'] = 100
    arms_to(p, (0.705, 0.475), bend=-1)
    return p
M['cycling'] = dict(frames=[bike(a) for a in (180, 90, 0, -90)], props=[('bike',)], worked={'thigh', 'shin'}, loop=True, period=1.0)

def rower(hipx, torso, hand, ankle=(0.72, 0.86)):
    p = pose(hip=(hipx, 0.83), torso=torso, neck=torso - 10, nf=160, ff=160)
    legs_to(p, ankle, (ankle[0] - 0.01, ankle[1]), bend=1)
    arms_to(p, hand, bend=1)
    return p
M['rowing-machine'] = dict(frames=[rower(0.46, 152, (0.72, 0.70)), rower(0.30, 205, (0.38, 0.73))],
                           props=[('rower',), ('cable', 0.86, 0.79)], worked={'thigh', 'torso', 'upper'}, period=2.0)

# ---------- Mobility ----------
hs_s = pose()
hs_e = pose(torso=40, neck=20, hip=(0.47, STAND_HIP_Y)); sh = shoulder_of(hs_e); arms_to(hs_e, (0.60, 0.90), bend=1)
M['hamstring-stretch'] = dict(frames=[hs_s, hs_e], props=[], worked={'thigh'}, period=4.0)

hf = pose(hip=(0.44, 0.73), torso=184, nf=90, ff=-20); legs_to(hf, (0.66, ANKLE_Y), (0.25, 0.94), bend=1, fbend=1)
hf2 = pose(hip=(0.47, 0.75), torso=188, nf=90, ff=-20); legs_to(hf2, (0.66, ANKLE_Y), (0.25, 0.94), bend=1, fbend=1)
for p in (hf, hf2):
    sh = shoulder_of(p); arms_to(p, add(p['hip'], (0.03, -0.02)), bend=1)
M['hip-flexor-stretch'] = dict(frames=[hf, hf2], props=[('mat', 0.10, 0.86)], worked={'thigh'}, period=4.0)

# ---------- In-between frames ----------
# For moves where hands or feet travel in a straight line (presses, rows,
# squats), solve the limbs at each step so the path looks natural instead of
# swinging the joint angles.
LIMBS = {'near_arm': ('na', UPPER_ARM, FOREARM), 'far_arm': ('fa', UPPER_ARM, FOREARM),
         'near_leg': ('nl', THIGH, SHIN), 'far_leg': ('fl', THIGH, SHIN)}

def side(b, m, e):
    return (e[0] - b[0]) * (m[1] - b[1]) - (e[1] - b[1]) * (m[0] - b[0])

def tween(f0, f1, t, elbows_up=False):
    p = lerp(f0, f1, t)
    J0, J1 = joints(f0), joints(f1)
    for limb, (key, a, b) in LIMBS.items():
        b0, m0, e0 = J0[limb][:3]
        b1, m1, e1 = J1[limb][:3]
        s0, s1 = side(b0, m0, e0), side(b1, m1, e1)
        if s0 * s1 < 0 and abs(s0) > 1e-4 and abs(s1) > 1e-4 and not (elbows_up and key in ('na', 'fa')):
            continue
        ref = s0 if abs(s0) > abs(s1) else s1
        target = (e0[0] + (e1[0] - e0[0]) * t, e0[1] + (e1[1] - e0[1]) * t)
        base = joints(p)[limb][0]
        best = None
        if elbows_up and key in ('na', 'fa'):
            sols = [ik(base, target, a, b, s) for s in (1, -1)]
            best = min(sols, key=lambda sol: add(base, d(sol[0]), a)[1])
        for bend in (() if best else (1, -1)):
            sol = ik(base, target, a, b, bend)
            mid = add(base, d(sol[0]), a)
            if side(base, mid, target) * ref >= 0:
                best = sol
                break
        if best:
            # keep angles continuous with the lerped value
            def near(x, y):
                while x - y > 180: x -= 360
                while y - x > 180: x += 360
                return x
            p[key] = (round(near(best[0], p[key][0]), 1), round(near(best[1], p[key][1]), 1))
    return p

STRAIGHT = ['bench-press', 'dumbbell-bench-press', 'incline-dumbbell-press', 'push-up', 'lat-pulldown', 'barbell-row',
            'seated-cable-row', 'pull-up', 'chin-up', 'dip', 'squat', 'goblet-squat', 'romanian-deadlift',
            'deadlift', 'leg-press', 'walking-lunge', 'bulgarian-split-squat', 'hip-thrust', 'glute-bridge', 'crunch',
            'rowing-machine', 'overhead-press', 'dumbbell-shoulder-press']
for key in STRAIGHT:
    f0, f1 = M[key]['frames']
    M[key]['frames'] = [f0] + [tween(f0, f1, t) for t in (0.25, 0.5, 0.75)] + [f1]

f0, f1 = M['face-pull']['frames']
M['face-pull']['frames'] = [f0] + [tween(f0, f1, t, elbows_up=True) for t in (0.25, 0.5, 0.75)] + [tween(f0, f1, 1.0, elbows_up=True)]
