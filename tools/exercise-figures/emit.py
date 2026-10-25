import os
from poses import M
from meta import META

ORDER = list(META)
PART = {'torso': '.torso', 'chest': '.chest', 'upper': '.upperArm', 'fore': '.forearm', 'thigh': '.thigh', 'shin': '.shin', 'glutes': '.glutes'}
EQUIP = {'barbell': '.barbell', 'dumbbells': '.dumbbells', 'kettlebell': '.kettlebell', 'cable': '.cable', 'machine': '.machine',
         'body weight': '.bodyWeight', 'cardio machine': '.cardioMachine'}

def n(x):
    v = round(float(x), 3)
    if v == int(v):
        return str(int(v))
    return f"{v:g}"

def q(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'

def prop(pr):
    k = pr[0]
    a = [n(x) for x in pr[1:]]
    return {
        'barbell': lambda: f".barbell(radius: {a[0]})",
        'barbell_hip': lambda: f".barbellAtHip(radius: {a[0]})",
        'dumbbells': lambda: ".dumbbells",
        'dumbbell_one': lambda: ".dumbbell",
        'kettlebell': lambda: ".kettlebell",
        'bench': lambda: f".bench(x: {a[0]}, y: {a[1]}, width: {a[2]})",
        'incline': lambda: f".incline(x: {a[0]}, y: {a[1]}, width: {a[2]}, angle: {a[3]}, length: {a[4]})",
        'seat': lambda: f".seat(x: {a[0]}, y: {a[1]}, width: {a[2]})",
        'bar': lambda: f".bar(y: {a[0]}, from: {a[1]}, to: {a[2]})",
        'dipbars': lambda: f".dipBars(y: {a[0]}, from: {a[1]}, to: {a[2]})",
        'mat': lambda: f".mat(from: {a[0]}, to: {a[1]})",
        'cable': lambda: f".cable(x: {a[0]}, y: {a[1]})",
        'cable2': lambda: f".cables(nearX: {a[0]}, nearY: {a[1]}, farX: {a[2]}, farY: {a[3]})",
        'footplate': lambda: f".footPlate(x: {a[0]}, top: {a[1]}, bottom: {a[2]})",
        'treadmill': lambda: ".treadmill",
        'bike': lambda: ".bike",
        'rower': lambda: ".rower",
        'legpress': lambda: f".legPress(railFrom: CGPoint(x: {a[0]}, y: {a[1]}), railTo: CGPoint(x: {a[2]}, y: {a[3]}))",
        'sled': lambda: f".sled(angle: {a[0]})",
        'pad': lambda: f".pad(angle: {a[0]})",
    }[k]()

def pose(p):
    return (f"Pose(hip: ({n(p['hip'][0])}, {n(p['hip'][1])}), torso: {n(p['torso'])}, neck: {n(p['neck'])}, "
            f"spread: ({n(p['ss'])}, {n(p['hs'])}), "
            f"arms: ({n(p['na'][0])}, {n(p['na'][1])}, {n(p['fa'][0])}, {n(p['fa'][1])}), "
            f"legs: ({n(p['nl'][0])}, {n(p['nl'][1])}, {n(p['fl'][0])}, {n(p['fl'][1])}), "
            f"feet: ({n(p['nf'])}, {n(p['ff'])}))")

out = ["// The built-in exercises. Poses were drawn and checked frame by frame;",
       "// angles are in degrees (0 points down, 90 forward, 180 up).",
       "", "import CoreGraphics", "", "extension ExerciseLibrary {", "    static let all: [Exercise] = ["]
for key in ORDER:
    name, muscle, also, equip, timed, plan, steps, mistakes, tip = META[key]
    m = M[key]
    worked = ", ".join(PART[w] for w in sorted(m['worked']))
    props = ", ".join(prop(pr) for pr in m['props'])
    frames = ",\n".join("                " + pose(f) for f in m['frames'])
    extras = []
    if m.get('loop'):
        extras.append("loops: true")
    if m.get('period'):
        extras.append(f"period: {n(m['period'])}")
    extra = (", " + ", ".join(extras)) if extras else ""
    out.append(f"""        Exercise(
            id: {q(key)}, name: {q(name)}, muscle: .{muscle}, alsoWorks: [{", ".join("." + a for a in also)}],
            equipment: {EQUIP[equip]}, isTimed: {"true" if timed else "false"},
            plan: .init(sets: {plan[0]}, reps: {plan[1]}, seconds: {plan[2]}, rest: {plan[3]}),
            steps: [
{chr(10).join("                " + q(s) + "," for s in steps)}
            ],
            mistakes: [
{chr(10).join("                " + q(s) + "," for s in mistakes)}
            ],
            tip: {q(tip)},
            motion: Motion(frames: [
{frames},
            ], worked: [{worked}], props: [{props}]{extra})
        ),""")
out += ["    ]", "}", ""]
target = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'LifeCentral', 'Features', 'Fitness', 'ExerciseData.swift')
open(target, 'w').write("\n".join(out))
print(len(ORDER))
