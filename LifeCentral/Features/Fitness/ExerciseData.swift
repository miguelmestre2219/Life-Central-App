// The built-in exercises. Poses were drawn and checked frame by frame;
// angles are in degrees (0 points down, 90 forward, 180 up).

import CoreGraphics

extension ExerciseLibrary {
    static let all: [Exercise] = [
        Exercise(
            id: "bench-press", name: "Bench press", muscle: .chest, alsoWorks: [.shoulders, .arms],
            equipment: .barbell, isTimed: false,
            plan: .init(sets: 4, reps: 8, seconds: 0, rest: 120),
            steps: [
                "Lie on the bench with your eyes under the bar and feet flat on the floor.",
                "Grip the bar a little wider than your shoulders and lift it off the rack.",
                "Lower it with control to the middle of your chest, elbows about 45° from your body.",
                "Press back up until your arms are straight, without locking hard.",
            ],
            mistakes: [
                "Bouncing the bar off your chest.",
                "Lifting your hips off the bench.",
                "Flaring your elbows straight out to the sides.",
            ],
            tip: "Squeeze your shoulder blades together before you unrack, and keep them there.",
            motion: Motion(frames: [
                Pose(hip: (0.6, 0.605), torso: -90, neck: -90, spread: (0, 0), arms: (165.2, -177, 165.2, -177), legs: (55.8, -2.7, 55.2, -8.1), feet: (80, 80)),
                Pose(hip: (0.6, 0.605), torso: -90, neck: -90, spread: (0, 0), arms: (132.7, -146.7, 132.7, -146.7), legs: (55.8, -2.7, 55.2, -8.1), feet: (80, 80)),
                Pose(hip: (0.6, 0.605), torso: -90, neck: -90, spread: (0, 0), arms: (112.6, -132.9, 112.6, -132.9), legs: (55.8, -2.7, 55.2, -8.1), feet: (80, 80)),
                Pose(hip: (0.6, 0.605), torso: -90, neck: -90, spread: (0, 0), arms: (90.8, -127.2, 90.8, -127.2), legs: (55.8, -2.7, 55.2, -8.1), feet: (80, 80)),
                Pose(hip: (0.6, 0.605), torso: -90, neck: -90, spread: (0, 0), arms: (48.3, -149.6, 48.3, -149.6), legs: (55.8, -2.7, 55.2, -8.1), feet: (80, 80)),
            ], worked: [.chest, .upperArm], props: [.bench(x: 0.14, y: 0.66, width: 0.56), .barbell(radius: 0.08)])
        ),
        Exercise(
            id: "dumbbell-bench-press", name: "Dumbbell bench press", muscle: .chest, alsoWorks: [.shoulders, .arms],
            equipment: .dumbbells, isTimed: false,
            plan: .init(sets: 3, reps: 10, seconds: 0, rest: 90),
            steps: [
                "Sit on the bench with a dumbbell on each thigh, then lie back and bring them up.",
                "Start with the dumbbells over your chest, palms facing your feet.",
                "Lower them to the sides of your chest, elbows slightly tucked.",
                "Press up and slightly in until your arms are straight.",
            ],
            mistakes: [
                "Letting the dumbbells drift too wide at the bottom.",
                "Dropping them fast at the end of a set.",
            ],
            tip: "Each arm works on its own, so it's a good fix if one side is weaker.",
            motion: Motion(frames: [
                Pose(hip: (0.6, 0.605), torso: -90, neck: -90, spread: (0, 0), arms: (167.7, -171, 167.7, -171), legs: (55.8, -2.7, 55.2, -8.1), feet: (80, 80)),
                Pose(hip: (0.6, 0.605), torso: -90, neck: -90, spread: (0, 0), arms: (141.4, -145.9, 141.4, -145.9), legs: (55.8, -2.7, 55.2, -8.1), feet: (80, 80)),
                Pose(hip: (0.6, 0.605), torso: -90, neck: -90, spread: (0, 0), arms: (125, -132.9, 125, -132.9), legs: (55.8, -2.7, 55.2, -8.1), feet: (80, 80)),
                Pose(hip: (0.6, 0.605), torso: -90, neck: -90, spread: (0, 0), arms: (109.8, -124.3, 109.8, -124.3), legs: (55.8, -2.7, 55.2, -8.1), feet: (80, 80)),
                Pose(hip: (0.6, 0.605), torso: -90, neck: -90, spread: (0, 0), arms: (91.7, -121.6, 91.7, -121.6), legs: (55.8, -2.7, 55.2, -8.1), feet: (80, 80)),
            ], worked: [.chest, .upperArm], props: [.bench(x: 0.14, y: 0.66, width: 0.56), .dumbbells])
        ),
        Exercise(
            id: "incline-dumbbell-press", name: "Incline dumbbell press", muscle: .chest, alsoWorks: [.shoulders, .arms],
            equipment: .dumbbells, isTimed: false,
            plan: .init(sets: 3, reps: 10, seconds: 0, rest: 90),
            steps: [
                "Set the bench to about 30–45° and sit back with a dumbbell in each hand.",
                "Start with the dumbbells by your shoulders, palms forward.",
                "Press up until your arms are straight above your upper chest.",
                "Lower slowly back to your shoulders.",
            ],
            mistakes: [
                "Setting the bench too steep, which turns it into a shoulder press.",
                "Arching your lower back off the pad.",
            ],
            tip: "Think about bringing your upper arms together as you press.",
            motion: Motion(frames: [
                Pose(hip: (0.56, 0.68), torso: 228, neck: 215, spread: (0, 0), arms: (160.6, 170.7, 160.6, 170.7), legs: (77.6, 11.5, 78.5, 5.5), feet: (85, 85)),
                Pose(hip: (0.56, 0.68), torso: 228, neck: 215, spread: (0, 0), arms: (170.2, 135.475, 170.2, 135.475), legs: (77.6, 11.5, 78.5, 5.5), feet: (85, 85)),
                Pose(hip: (0.56, 0.68), torso: 228, neck: 215, spread: (0, 0), arms: (179.8, 100.25, 179.8, 100.25), legs: (77.6, 11.5, 78.5, 5.5), feet: (85, 85)),
                Pose(hip: (0.56, 0.68), torso: 228, neck: 215, spread: (0, 0), arms: (189.4, 65.025, 189.4, 65.025), legs: (77.6, 11.5, 78.5, 5.5), feet: (85, 85)),
                Pose(hip: (0.56, 0.68), torso: 228, neck: 215, spread: (0, 0), arms: (199, 29.8, 199, 29.8), legs: (77.6, 11.5, 78.5, 5.5), feet: (85, 85)),
            ], worked: [.chest, .upperArm], props: [.incline(x: 0.5, y: 0.72, width: 0.22, angle: 48, length: 0.36), .dumbbells])
        ),
        Exercise(
            id: "chest-fly", name: "Cable chest fly", muscle: .chest, alsoWorks: [.shoulders],
            equipment: .cable, isTimed: false,
            plan: .init(sets: 3, reps: 12, seconds: 0, rest: 60),
            steps: [
                "Set both pulleys high and hold a handle in each hand, one foot forward.",
                "Start with arms out wide and a soft bend in the elbows.",
                "Bring your hands together in front of your chest in a wide hugging arc.",
                "Let your arms open back out slowly until you feel a stretch.",
            ],
            mistakes: [
                "Bending the elbows more and turning it into a press.",
                "Using so much weight you lean forward to move it.",
            ],
            tip: "Keep the same small elbow bend all the way through.",
            motion: Motion(frames: [
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0.17, 0.08), arms: (73.3, 76.3, -73.3, -76.3), legs: (3, 0, -3, 0), feet: (60, -60)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0.17, 0.08), arms: (-59.3, 26.3, 59.3, -26.3), legs: (3, 0, -3, 0), feet: (60, -60)),
            ], worked: [.chest, .upperArm], props: [.cables(nearX: 0.94, nearY: 0.1, farX: 0.06, farY: 0.1)])
        ),
        Exercise(
            id: "push-up", name: "Push-up", muscle: .chest, alsoWorks: [.arms, .core],
            equipment: .bodyWeight, isTimed: false,
            plan: .init(sets: 3, reps: 12, seconds: 0, rest: 60),
            steps: [
                "Start in a high plank, hands just wider than your shoulders.",
                "Keep your body in one straight line from head to heels.",
                "Lower your chest towards the floor, elbows angled back.",
                "Push the floor away to come back up.",
            ],
            mistakes: [
                "Letting your hips sag.",
                "Only going down halfway.",
            ],
            tip: "Too hard? Put your hands on a bench. Too easy? Slow the way down.",
            motion: Motion(frames: [
                Pose(hip: (0.393, 0.753), torso: 113, neck: 98, spread: (0, 0), arms: (2.6, 5.7, -1.5, 1.6), legs: (-67, -67, -67, -67), feet: (8, 8)),
                Pose(hip: (0.388, 0.778), torso: 109.75, neck: 94.75, spread: (0, 0), arms: (-25.1, 36.5, -30, 31.8), legs: (-64.7, -75.9, -64.7, -75.9), feet: (4.75, 4.75)),
                Pose(hip: (0.384, 0.802), torso: 106.5, neck: 91.5, spread: (0, 0), arms: (-37, 51.3, -42.8, 45.8), legs: (-67.1, -80.1, -67.1, -80.1), feet: (1.5, 1.5)),
                Pose(hip: (0.379, 0.826), torso: 103.25, neck: 88.25, spread: (0, 0), arms: (-45.3, 64.4, -52.7, 57.6), legs: (-71.2, -82.5, -71.2, -82.5), feet: (-1.75, -1.75)),
                Pose(hip: (0.374, 0.85), torso: 100, neck: 85, spread: (0, 0), arms: (-50.6, 78, -60.4, 69), legs: (-80, -80, -80, -80), feet: (-5, -5)),
            ], worked: [.chest, .upperArm], props: [.mat(from: 0.1, to: 0.86)])
        ),
        Exercise(
            id: "dip", name: "Dip", muscle: .chest, alsoWorks: [.arms, .shoulders],
            equipment: .bodyWeight, isTimed: false,
            plan: .init(sets: 3, reps: 8, seconds: 0, rest: 90),
            steps: [
                "Hold the parallel bars and lift yourself up with straight arms.",
                "Lean slightly forward and bend your knees behind you.",
                "Lower until your upper arms are about level with the floor.",
                "Press back up to straight arms.",
            ],
            mistakes: [
                "Dropping too deep, which strains the shoulders.",
                "Swinging the legs to help.",
            ],
            tip: "Use the assisted dip machine or a band until you can do 8 clean reps.",
            motion: Motion(frames: [
                Pose(hip: (0.48, 0.519), torso: 176, neck: 166, spread: (0, 0), arms: (-12.5, 17.9, -16.8, 13.7), legs: (18, -95, 12, -100), feet: (0, 0)),
                Pose(hip: (0.46, 0.55), torso: 172, neck: 162, spread: (0, 0), arms: (-27.2, 36.8, -32.1, 32.1), legs: (18, -95, 12, -100), feet: (0, 0)),
                Pose(hip: (0.44, 0.581), torso: 168, neck: 158, spread: (0, 0), arms: (-35.9, 50.8, -41.8, 45.4), legs: (18, -95, 12, -100), feet: (0, 0)),
                Pose(hip: (0.421, 0.612), torso: 164, neck: 154, spread: (0, 0), arms: (-41.9, 64, -49.1, 57.7), legs: (18, -95, 12, -100), feet: (0, 0)),
                Pose(hip: (0.401, 0.643), torso: 160, neck: 150, spread: (0, 0), arms: (-44.8, 78.4, -54, 70.6), legs: (18, -95, 12, -100), feet: (0, 0)),
            ], worked: [.chest, .upperArm], props: [.dipBars(y: 0.5, from: 0.36, to: 0.66)])
        ),
        Exercise(
            id: "lat-pulldown", name: "Lat pulldown", muscle: .back, alsoWorks: [.arms],
            equipment: .cable, isTimed: false,
            plan: .init(sets: 4, reps: 10, seconds: 0, rest: 90),
            steps: [
                "Sit with your thighs under the pads and grip the bar wider than your shoulders.",
                "Lean back slightly and lift your chest.",
                "Pull the bar down to your upper chest, driving your elbows down.",
                "Let the bar rise slowly until your arms are straight.",
            ],
            mistakes: [
                "Pulling the bar behind your neck.",
                "Rocking your whole body to move the weight.",
            ],
            tip: "Imagine putting your elbows into your back pockets.",
            motion: Motion(frames: [
                Pose(hip: (0.42, 0.71), torso: 188, neck: 180, spread: (0, 0), arms: (160.6, 170.7, 160.6, 170.7), legs: (87.2, -1.4, 86.8, -7.1), feet: (90, 90)),
                Pose(hip: (0.42, 0.71), torso: 190, neck: 180, spread: (0, 0), arms: (161.375, 132.25, 161.375, 132.25), legs: (87.2, -1.4, 86.8, -7.1), feet: (90, 90)),
                Pose(hip: (0.42, 0.71), torso: 192, neck: 180, spread: (0, 0), arms: (162.15, 93.8, 162.15, 93.8), legs: (87.2, -1.4, 86.8, -7.1), feet: (90, 90)),
                Pose(hip: (0.42, 0.71), torso: 194, neck: 180, spread: (0, 0), arms: (162.925, 55.35, 162.925, 55.35), legs: (87.2, -1.4, 86.8, -7.1), feet: (90, 90)),
                Pose(hip: (0.42, 0.71), torso: 196, neck: 180, spread: (0, 0), arms: (163.7, 16.9, 163.7, 16.9), legs: (87.2, -1.4, 86.8, -7.1), feet: (90, 90)),
            ], worked: [.torso, .upperArm], props: [.seat(x: 0.32, y: 0.75, width: 0.2), .cable(x: 0.55, y: 0.04)])
        ),
        Exercise(
            id: "pull-up", name: "Pull-up", muscle: .back, alsoWorks: [.arms],
            equipment: .bodyWeight, isTimed: false,
            plan: .init(sets: 3, reps: 6, seconds: 0, rest: 120),
            steps: [
                "Hang from the bar with hands a little wider than your shoulders, palms away.",
                "Pull your shoulders down and back.",
                "Pull up until your chin is over the bar.",
                "Lower all the way down with control.",
            ],
            mistakes: [
                "Kicking or swinging to get up.",
                "Stopping short of straight arms at the bottom.",
            ],
            tip: "Start with an assisted machine, a band or slow lowering-only reps.",
            motion: Motion(frames: [
                Pose(hip: (0.51, 0.65), torso: 182, neck: 182, spread: (0, 0), arms: (177.5, 174.6, -174.6, -177.5), legs: (14, -88, 8, -94), feet: (40, 40)),
                Pose(hip: (0.498, 0.607), torso: 179.5, neck: 179.5, spread: (0, 0), arms: (205.4, 142.9, -145.3, -207.8), legs: (14, -88, 8, -94), feet: (40, 40)),
                Pose(hip: (0.485, 0.564), torso: 177, neck: 177, spread: (0, 0), arms: (217, 127.8, -131.7, 139.1), legs: (14, -88, 8, -94), feet: (40, 40)),
                Pose(hip: (0.472, 0.52), torso: 174.5, neck: 174.5, spread: (0, 0), arms: (225.1, 114.9, -120.7, 129.1), legs: (14, -88, 8, -94), feet: (40, 40)),
                Pose(hip: (0.46, 0.477), torso: 172, neck: 172, spread: (0, 0), arms: (230.6, 102, -110.5, 120.9), legs: (14, -88, 8, -94), feet: (40, 40)),
            ], worked: [.torso, .upperArm], props: [.bar(y: 0.07, from: 0.25, to: 0.75)])
        ),
        Exercise(
            id: "chin-up", name: "Chin-up", muscle: .back, alsoWorks: [.arms],
            equipment: .bodyWeight, isTimed: false,
            plan: .init(sets: 3, reps: 6, seconds: 0, rest: 120),
            steps: [
                "Hang from the bar with hands shoulder-width apart, palms facing you.",
                "Pull your shoulders down and back.",
                "Pull up until your chin clears the bar.",
                "Lower slowly to straight arms.",
            ],
            mistakes: [
                "Craning your neck to reach the bar.",
                "Half reps at the bottom.",
            ],
            tip: "Palms facing you brings your biceps in, so most people find chin-ups easier than pull-ups.",
            motion: Motion(frames: [
                Pose(hip: (0.51, 0.65), torso: 182, neck: 182, spread: (0, 0), arms: (177.5, 174.6, -174.6, -177.5), legs: (14, -88, 8, -94), feet: (40, 40)),
                Pose(hip: (0.498, 0.607), torso: 179.5, neck: 179.5, spread: (0, 0), arms: (205.4, 142.9, -145.3, -207.8), legs: (14, -88, 8, -94), feet: (40, 40)),
                Pose(hip: (0.485, 0.564), torso: 177, neck: 177, spread: (0, 0), arms: (217, 127.8, -131.7, 139.1), legs: (14, -88, 8, -94), feet: (40, 40)),
                Pose(hip: (0.472, 0.52), torso: 174.5, neck: 174.5, spread: (0, 0), arms: (225.1, 114.9, -120.7, 129.1), legs: (14, -88, 8, -94), feet: (40, 40)),
                Pose(hip: (0.46, 0.477), torso: 172, neck: 172, spread: (0, 0), arms: (230.6, 102, -110.5, 120.9), legs: (14, -88, 8, -94), feet: (40, 40)),
            ], worked: [.torso, .upperArm], props: [.bar(y: 0.07, from: 0.25, to: 0.75)])
        ),
        Exercise(
            id: "barbell-row", name: "Barbell row", muscle: .back, alsoWorks: [.arms],
            equipment: .barbell, isTimed: false,
            plan: .init(sets: 3, reps: 8, seconds: 0, rest: 120),
            steps: [
                "Hold the bar with straight arms, knees soft, and hinge forward to about 45°.",
                "Keep your back flat and your neck in line.",
                "Pull the bar to your lower ribs, squeezing your shoulder blades.",
                "Lower it until your arms are straight.",
            ],
            mistakes: [
                "Rounding your lower back.",
                "Standing up taller with each rep to swing the bar.",
            ],
            tip: "If your lower back tires first, use the chest-supported row instead.",
            motion: Motion(frames: [
                Pose(hip: (0.37, 0.545), torso: 118, neck: 110, spread: (0, 0), arms: (-8.2, 13.1, -8.2, 13.1), legs: (30.5, 7.5, 31.4, 0.9), feet: (90, 90)),
                Pose(hip: (0.37, 0.545), torso: 118, neck: 110, spread: (0, 0), arms: (-7.35, -18.5, -7.35, -18.5), legs: (30.5, 7.5, 31.4, 0.9), feet: (90, 90)),
                Pose(hip: (0.37, 0.545), torso: 118, neck: 110, spread: (0, 0), arms: (-6.5, -50.1, -6.5, -50.1), legs: (30.5, 7.5, 31.4, 0.9), feet: (90, 90)),
                Pose(hip: (0.37, 0.545), torso: 118, neck: 110, spread: (0, 0), arms: (-5.65, -81.7, -5.65, -81.7), legs: (30.5, 7.5, 31.4, 0.9), feet: (90, 90)),
                Pose(hip: (0.37, 0.545), torso: 118, neck: 110, spread: (0, 0), arms: (-4.8, -113.3, -4.8, -113.3), legs: (30.5, 7.5, 31.4, 0.9), feet: (90, 90)),
            ], worked: [.torso, .upperArm], props: [.barbell(radius: 0.075)])
        ),
        Exercise(
            id: "seated-cable-row", name: "Seated cable row", muscle: .back, alsoWorks: [.arms],
            equipment: .cable, isTimed: false,
            plan: .init(sets: 3, reps: 10, seconds: 0, rest: 90),
            steps: [
                "Sit with feet on the platform, knees slightly bent, and hold the handle.",
                "Start with straight arms and a tall chest.",
                "Pull the handle to your stomach, squeezing your shoulder blades.",
                "Let your arms stretch forward again slowly.",
            ],
            mistakes: [
                "Rocking far back to move the weight.",
                "Shrugging your shoulders up.",
            ],
            tip: "Pause for a second with the handle at your stomach.",
            motion: Motion(frames: [
                Pose(hip: (0.3, 0.8), torso: 155, neck: 150, spread: (0, 0), arms: (71.9, 74.9, 71.9, 74.9), legs: (119.6, 45.1, 123.4, 40.1), feet: (150, 150)),
                Pose(hip: (0.3, 0.8), torso: 164.25, neck: 159.25, spread: (0, 0), arms: (75.475, 57.825, 75.475, 57.825), legs: (119.6, 45.1, 123.4, 40.1), feet: (150, 150)),
                Pose(hip: (0.3, 0.8), torso: 173.5, neck: 168.5, spread: (0, 0), arms: (79.05, 40.75, 79.05, 40.75), legs: (119.6, 45.1, 123.4, 40.1), feet: (150, 150)),
                Pose(hip: (0.3, 0.8), torso: 182.75, neck: 177.75, spread: (0, 0), arms: (82.625, 23.675, 82.625, 23.675), legs: (119.6, 45.1, 123.4, 40.1), feet: (150, 150)),
                Pose(hip: (0.3, 0.8), torso: 192, neck: 187, spread: (0, 0), arms: (86.2, 6.6, 86.2, 6.6), legs: (119.6, 45.1, 123.4, 40.1), feet: (150, 150)),
            ], worked: [.torso, .upperArm], props: [.seat(x: 0.18, y: 0.84, width: 0.22), .footPlate(x: 0.66, top: 0.74, bottom: 0.92), .cable(x: 0.93, y: 0.7)])
        ),
        Exercise(
            id: "face-pull", name: "Face pull", muscle: .back, alsoWorks: [.shoulders],
            equipment: .cable, isTimed: false,
            plan: .init(sets: 3, reps: 15, seconds: 0, rest: 60),
            steps: [
                "Set the pulley at face height with the rope attachment.",
                "Hold the rope with thumbs pointing towards you and step back.",
                "Pull the rope towards your face, hands ending beside your ears.",
                "Return slowly to straight arms.",
            ],
            mistakes: [
                "Using too much weight and leaning back.",
                "Letting your elbows drop low.",
            ],
            tip: "Light and controlled works best. It's great for posture and healthy shoulders.",
            motion: Motion(frames: [
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (86, 111.8, 86, 111.8), legs: (2, 0, -2, 0), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (147.6, 62.5, 147.6, 62.5), legs: (2.3, -0.3, -2.3, 0.3), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (-182.6, 61.3, -182.6, 61.3), legs: (2.3, -0.3, -2.3, 0.3), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (-146.1, 81.4, -146.1, 81.4), legs: (2.3, -0.3, -2.3, 0.3), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (-230.6, 258, -230.6, 258), legs: (2.3, -0.3, -2.3, 0.3), feet: (90, 90)),
            ], worked: [.torso, .upperArm], props: [.cable(x: 0.92, y: 0.17)])
        ),
        Exercise(
            id: "deadlift", name: "Deadlift", muscle: .back, alsoWorks: [.legs, .glutes],
            equipment: .barbell, isTimed: false,
            plan: .init(sets: 3, reps: 5, seconds: 0, rest: 180),
            steps: [
                "Stand with the bar over the middle of your feet, feet hip-width apart.",
                "Hinge down and grip the bar just outside your legs, back flat.",
                "Push the floor away and stand up tall, keeping the bar close to your legs.",
                "Hinge back down, bar sliding down your thighs.",
            ],
            mistakes: [
                "Rounding your back.",
                "Letting the bar drift away from your body.",
                "Leaning back at the top.",
            ],
            tip: "Take a big breath and brace your stomach before each rep.",
            motion: Motion(frames: [
                Pose(hip: (0.385, 0.665), torso: 118, neck: 110, spread: (0, 0), arms: (-20.1, -17.6, -20.1, -17.6), legs: (70.6, -20.9, 68.7, -25.5), feet: (90, 90)),
                Pose(hip: (0.414, 0.627), torso: 133.5, neck: 127.5, spread: (0, 0), arms: (-16.8, -14, -17.9, -15.1), legs: (57.8, -23.6, 51.025, -19.125), feet: (90, 90)),
                Pose(hip: (0.443, 0.59), torso: 149, neck: 145, spread: (0, 0), arms: (-11.5, -8.8, -13.8, -11), legs: (44.5, -23.3, 33.35, -12.75), feet: (90, 90)),
                Pose(hip: (0.471, 0.552), torso: 164.5, neck: 162.5, spread: (0, 0), arms: (-4.9, -2, -8.4, -5.6), legs: (29.6, -19, 15.675, -6.375), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (4, 6, -4, 4), legs: (2, 0, -2, 0), feet: (90, 90)),
            ], worked: [.glutes, .thigh, .torso], props: [.barbell(radius: 0.082)])
        ),
        Exercise(
            id: "overhead-press", name: "Overhead press", muscle: .shoulders, alsoWorks: [.arms],
            equipment: .barbell, isTimed: false,
            plan: .init(sets: 3, reps: 8, seconds: 0, rest: 120),
            steps: [
                "Stand with the bar resting on your upper chest, hands just outside your shoulders.",
                "Squeeze your glutes and brace your stomach.",
                "Press the bar straight up, moving your head back slightly to let it pass.",
                "Finish with the bar over the middle of your head, then lower to your chest.",
            ],
            mistakes: [
                "Leaning back to push the weight.",
                "Pressing the bar out in front instead of straight up.",
            ],
            tip: "Once the bar passes your forehead, bring your head through under it.",
            motion: Motion(frames: [
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (28, 172, 24, 170), legs: (2, 0, -2, 0), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (73.5, 211.3, 71.9, 211.5), legs: (2.3, -0.3, -2.3, 0.3), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (106.2, 220.9, 104.9, 220.6), legs: (2.3, -0.3, -2.3, 0.3), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (132.6, 213.2, 131.1, 212.3), legs: (2.3, -0.3, -2.3, 0.3), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (176, 178, 174, 177), legs: (2, 0, -2, 0), feet: (90, 90)),
            ], worked: [.upperArm], props: [.barbell(radius: 0.075)])
        ),
        Exercise(
            id: "dumbbell-shoulder-press", name: "Dumbbell shoulder press", muscle: .shoulders, alsoWorks: [.arms],
            equipment: .dumbbells, isTimed: false,
            plan: .init(sets: 3, reps: 10, seconds: 0, rest: 90),
            steps: [
                "Hold a dumbbell in each hand at shoulder height, palms forward.",
                "Brace your stomach and keep your ribs down.",
                "Press up until your arms are straight overhead.",
                "Lower back to shoulder height with control.",
            ],
            mistakes: [
                "Arching your lower back.",
                "Clanking the dumbbells together at the top.",
            ],
            tip: "You can sit on a bench with a back rest to keep your back still.",
            motion: Motion(frames: [
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (20, 168, 16, 166), legs: (2, 0, -2, 0), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (72, 214.2, 70.9, 214.8), legs: (2.3, -0.3, -2.3, 0.3), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (106, 223.6, 104.9, 223.4), legs: (2.3, -0.3, -2.3, 0.3), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (132.3, 214.6, 130.8, 213.7), legs: (2.3, -0.3, -2.3, 0.3), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (176, 178, 174, 177), legs: (2, 0, -2, 0), feet: (90, 90)),
            ], worked: [.upperArm], props: [.dumbbells])
        ),
        Exercise(
            id: "lateral-raise", name: "Lateral raise", muscle: .shoulders, alsoWorks: [],
            equipment: .dumbbells, isTimed: false,
            plan: .init(sets: 3, reps: 15, seconds: 0, rest: 60),
            steps: [
                "Stand tall with a light dumbbell in each hand by your sides.",
                "With a soft bend in the elbows, raise your arms out to the sides.",
                "Stop when your hands reach shoulder height.",
                "Lower slowly.",
            ],
            mistakes: [
                "Swinging the weights up with your body.",
                "Shrugging your shoulders towards your ears.",
            ],
            tip: "Lead with your elbows, as if pouring water from a jug.",
            motion: Motion(frames: [
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0.17, 0.08), arms: (16, 10, -16, -10), legs: (3, 0, -3, 0), feet: (60, -60)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0.17, 0.08), arms: (84, 88, -84, -88), legs: (3, 0, -3, 0), feet: (60, -60)),
            ], worked: [.upperArm], props: [.dumbbells])
        ),
        Exercise(
            id: "bicep-curl", name: "Bicep curl", muscle: .arms, alsoWorks: [],
            equipment: .dumbbells, isTimed: false,
            plan: .init(sets: 3, reps: 12, seconds: 0, rest: 60),
            steps: [
                "Stand with a dumbbell in each hand, palms facing forward.",
                "Keep your elbows pinned to your sides.",
                "Curl the weights up towards your shoulders.",
                "Lower all the way down slowly.",
            ],
            mistakes: [
                "Swinging your body to lift the weight.",
                "Letting your elbows drift forward.",
            ],
            tip: "Lowering slowly does as much work as lifting.",
            motion: Motion(frames: [
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (2, 4, -2, 2), legs: (2, 0, -2, 0), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (4, 155, 0, 150), legs: (2, 0, -2, 0), feet: (90, 90)),
            ], worked: [.upperArm], props: [.dumbbells])
        ),
        Exercise(
            id: "hammer-curl", name: "Hammer curl", muscle: .arms, alsoWorks: [],
            equipment: .dumbbells, isTimed: false,
            plan: .init(sets: 3, reps: 12, seconds: 0, rest: 60),
            steps: [
                "Hold the dumbbells by your sides with palms facing each other.",
                "Keep your elbows still at your sides.",
                "Curl the weights up, keeping your palms facing in.",
                "Lower slowly.",
            ],
            mistakes: [
                "Swinging.",
                "Cutting the range short at the bottom.",
            ],
            tip: "This grip also works your forearms.",
            motion: Motion(frames: [
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (2, 4, -2, 2), legs: (2, 0, -2, 0), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (4, 155, 0, 150), legs: (2, 0, -2, 0), feet: (90, 90)),
            ], worked: [.forearm, .upperArm], props: [.dumbbells])
        ),
        Exercise(
            id: "tricep-pushdown", name: "Tricep pushdown", muscle: .arms, alsoWorks: [],
            equipment: .cable, isTimed: false,
            plan: .init(sets: 3, reps: 12, seconds: 0, rest: 60),
            steps: [
                "Set the pulley high with a rope or bar and hold it with elbows by your sides.",
                "Lean forward very slightly.",
                "Push down until your arms are straight.",
                "Let your hands come back up to chest height, elbows staying put.",
            ],
            mistakes: [
                "Letting your elbows move forward and back.",
                "Leaning over the weight to push it down.",
            ],
            tip: "Only your forearms should move.",
            motion: Motion(frames: [
                Pose(hip: (0.5, 0.515), torso: 172, neck: 180, spread: (0, 0), arms: (4, 115, 2, 112), legs: (2, 0, -2, 0), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 172, neck: 180, spread: (0, 0), arms: (4, 8, 2, 6), legs: (2, 0, -2, 0), feet: (90, 90)),
            ], worked: [.upperArm], props: [.cable(x: 0.66, y: 0.06)])
        ),
        Exercise(
            id: "overhead-tricep-extension", name: "Overhead tricep extension", muscle: .arms, alsoWorks: [],
            equipment: .dumbbells, isTimed: false,
            plan: .init(sets: 3, reps: 12, seconds: 0, rest: 60),
            steps: [
                "Hold one dumbbell with both hands above your head.",
                "Keep your elbows pointing up and close to your head.",
                "Lower the dumbbell behind your head by bending your elbows.",
                "Straighten your arms to lift it back up.",
            ],
            mistakes: [
                "Letting the elbows flare out wide.",
                "Arching your back.",
            ],
            tip: "Go lighter than you think. The stretch at the bottom is the point.",
            motion: Motion(frames: [
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (172, -30, 168, -34), legs: (2, 0, -2, 0), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (172, 178, 168, 176), legs: (2, 0, -2, 0), feet: (90, 90)),
            ], worked: [.upperArm], props: [.dumbbell])
        ),
        Exercise(
            id: "squat", name: "Back squat", muscle: .legs, alsoWorks: [.glutes, .core],
            equipment: .barbell, isTimed: false,
            plan: .init(sets: 4, reps: 8, seconds: 0, rest: 150),
            steps: [
                "Rest the bar across your upper back and step out of the rack.",
                "Stand with feet about shoulder-width apart, toes turned out a little.",
                "Sit down and back, knees following your toes, until your thighs are about level.",
                "Drive up through your whole foot to stand.",
            ],
            mistakes: [
                "Knees caving in.",
                "Heels lifting off the floor.",
                "Rounding your back at the bottom.",
            ],
            tip: "Set the safety bars just below your lowest point.",
            motion: Motion(frames: [
                Pose(hip: (0.5, 0.515), torso: 180, neck: 176, spread: (0, 0), arms: (-148.6, 17.5, -148.6, 17.5), legs: (2, 0, -2, 0), feet: (90, 90)),
                Pose(hip: (0.471, 0.561), torso: 170.5, neck: 171.5, spread: (0, 0), arms: (-134.7, 28.7, -134.7, 28.7), legs: (32.5, -21.8, 17.9, -7.1), feet: (90, 90)),
                Pose(hip: (0.443, 0.607), torso: 161, neck: 167, spread: (0, 0), arms: (-131.9, 30.2, -131.9, 30.2), legs: (49.1, -26.9, 37.8, -14.2), feet: (90, 90)),
                Pose(hip: (0.414, 0.654), torso: 151.5, neck: 162.5, spread: (0, 0), arms: (-136, 27, -136, 27), legs: (64.4, -27.3, 57.7, -21.3), feet: (90, 90)),
                Pose(hip: (0.385, 0.7), torso: 142, neck: 158, spread: (0, 0), arms: (-148.6, 17.5, -148.6, 17.5), legs: (79.7, -23.5, 77.6, -28.4), feet: (90, 90)),
            ], worked: [.glutes, .thigh], props: [.barbell(radius: 0.08)])
        ),
        Exercise(
            id: "goblet-squat", name: "Goblet squat", muscle: .legs, alsoWorks: [.glutes, .core],
            equipment: .dumbbells, isTimed: false,
            plan: .init(sets: 3, reps: 12, seconds: 0, rest: 90),
            steps: [
                "Hold one dumbbell upright against your chest with both hands.",
                "Stand with feet a little wider than your hips.",
                "Squat down between your knees, chest up.",
                "Stand back up through your heels.",
            ],
            mistakes: [
                "Leaning forward and letting the weight pull you over.",
                "Knees caving in.",
            ],
            tip: "A great way to learn the squat before adding a barbell.",
            motion: Motion(frames: [
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (109, -29.8, 109, -29.8), legs: (2, 0, -2, 0), feet: (90, 90)),
                Pose(hip: (0.475, 0.564), torso: 175, neck: 178, spread: (0, 0), arms: (107.2, -30.7, 107.2, -30.7), legs: (32.8, -23.2, 17.95, -8.375), feet: (90, 90)),
                Pose(hip: (0.45, 0.612), torso: 170, neck: 176, spread: (0, 0), arms: (106.6, -31.1, 106.6, -31.1), legs: (49.4, -29.5, 37.9, -16.75), feet: (90, 90)),
                Pose(hip: (0.425, 0.661), torso: 165, neck: 174, spread: (0, 0), arms: (107.1, -30.8, 107.1, -30.8), legs: (64.7, -31.1, 57.85, -25.125), feet: (90, 90)),
                Pose(hip: (0.4, 0.71), torso: 160, neck: 172, spread: (0, 0), arms: (109, -29.8, 109, -29.8), legs: (80.4, -28.4, 77.8, -33.5), feet: (90, 90)),
            ], worked: [.glutes, .thigh], props: [.dumbbell])
        ),
        Exercise(
            id: "leg-press", name: "Leg press", muscle: .legs, alsoWorks: [.glutes],
            equipment: .machine, isTimed: false,
            plan: .init(sets: 3, reps: 12, seconds: 0, rest: 90),
            steps: [
                "Sit in the machine with your back flat and feet hip-width on the platform.",
                "Release the safety handles.",
                "Lower the platform until your knees are bent to about 90°.",
                "Push it back up without locking your knees.",
            ],
            mistakes: [
                "Lowering so far that your lower back lifts off the pad.",
                "Locking your knees at the top.",
            ],
            tip: "Feet higher on the platform works your glutes more; lower works your thighs.",
            motion: Motion(frames: [
                Pose(hip: (0.3, 0.66), torso: 236, neck: 215, spread: (0, 0), arms: (60.8, 58.4, 60.8, 58.4), legs: (186.3, 74.4, 189.9, 72), feet: (208, 208)),
                Pose(hip: (0.3, 0.66), torso: 236, neck: 215, spread: (0, 0), arms: (61.1, 58.1, 61.1, 58.1), legs: (176.6, 80.6, 180.1, 77.8), feet: (208, 208)),
                Pose(hip: (0.3, 0.66), torso: 236, neck: 215, spread: (0, 0), arms: (61.1, 58.1, 61.1, 58.1), legs: (166.2, 88.6, 170, 85.2), feet: (208, 208)),
                Pose(hip: (0.3, 0.66), torso: 236, neck: 215, spread: (0, 0), arms: (61.1, 58.1, 61.1, 58.1), legs: (153.8, 99.3, 158.3, 94.9), feet: (208, 208)),
                Pose(hip: (0.3, 0.66), torso: 236, neck: 215, spread: (0, 0), arms: (60.8, 58.4, 60.8, 58.4), legs: (127.3, 124.8, 141.6, 110.3), feet: (208, 208)),
            ], worked: [.glutes, .thigh], props: [.legPress(railFrom: CGPoint(x: 0.44, y: 0.6), railTo: CGPoint(x: 0.86, y: 0.37)), .sled(angle: 208)])
        ),
        Exercise(
            id: "walking-lunge", name: "Walking lunge", muscle: .legs, alsoWorks: [.glutes],
            equipment: .dumbbells, isTimed: false,
            plan: .init(sets: 3, reps: 12, seconds: 0, rest: 90),
            steps: [
                "Stand tall with a dumbbell in each hand.",
                "Take a long step forward and lower your back knee towards the floor.",
                "Push through your front foot to come up and bring your back foot forward.",
                "Keep walking, swapping legs each step.",
            ],
            mistakes: [
                "Taking short steps so the front knee shoots forward.",
                "Leaning over the front leg.",
            ],
            tip: "Reps are counted per leg.",
            motion: Motion(frames: [
                Pose(hip: (0.45, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (4, 6, -4, 4), legs: (2, 0, -2, 0), feet: (90, 90)),
                Pose(hip: (0.45, 0.561), torso: 180, neck: 180, spread: (0, 0), arms: (3.5, 6.6, -4, 4), legs: (34.5, -18.5, -5.025, -22.05), feet: (90, 77.5)),
                Pose(hip: (0.45, 0.607), torso: 180, neck: 180, spread: (0, 0), arms: (3.5, 6.6, -4, 4), legs: (53, -19, -8.05, -44.1), feet: (90, 65)),
                Pose(hip: (0.45, 0.654), torso: 180, neck: 180, spread: (0, 0), arms: (3.5, 6.6, -4, 4), legs: (69.5, -13.8, -11.075, -66.15), feet: (90, 52.5)),
                Pose(hip: (0.45, 0.7), torso: 180, neck: 180, spread: (0, 0), arms: (4, 6, -4, 4), legs: (84.3, -4, -14.1, -88.2), feet: (90, 40)),
            ], worked: [.glutes, .thigh], props: [.dumbbells])
        ),
        Exercise(
            id: "bulgarian-split-squat", name: "Bulgarian split squat", muscle: .legs, alsoWorks: [.glutes],
            equipment: .dumbbells, isTimed: false,
            plan: .init(sets: 3, reps: 10, seconds: 0, rest: 90),
            steps: [
                "Stand in front of a bench and rest the top of one foot on it behind you.",
                "Hold a dumbbell in each hand.",
                "Lower your back knee towards the floor, front shin fairly upright.",
                "Push through your front foot to stand back up.",
            ],
            mistakes: [
                "Standing too close to the bench.",
                "Bouncing off the back leg.",
            ],
            tip: "Hard but very effective. Start with no weight.",
            motion: Motion(frames: [
                Pose(hip: (0.47, 0.56), torso: 180, neck: 180, spread: (0, 0), arms: (4, 6, -4, 4), legs: (37.2, 10.4, -21.3, -118.7), feet: (90, -60)),
                Pose(hip: (0.465, 0.595), torso: 180, neck: 180, spread: (0, 0), arms: (3.5, 6.6, -4, 4), legs: (52.4, 0.7, -25.6, -128.6), feet: (90, -60)),
                Pose(hip: (0.46, 0.63), torso: 180, neck: 180, spread: (0, 0), arms: (3.5, 6.6, -4, 4), legs: (63.8, -4, -31.6, -138.4), feet: (90, -60)),
                Pose(hip: (0.455, 0.665), torso: 180, neck: 180, spread: (0, 0), arms: (3.5, 6.6, -4, 4), legs: (74.1, -6.4, -38.9, -147.9), feet: (90, -60)),
                Pose(hip: (0.45, 0.7), torso: 180, neck: 180, spread: (0, 0), arms: (4, 6, -4, 4), legs: (84, -6.9, -47.4, -156.7), feet: (90, -60)),
            ], worked: [.glutes, .thigh], props: [.bench(x: 0.04, y: 0.66, width: 0.26), .dumbbells])
        ),
        Exercise(
            id: "leg-extension", name: "Leg extension", muscle: .legs, alsoWorks: [],
            equipment: .machine, isTimed: false,
            plan: .init(sets: 3, reps: 12, seconds: 0, rest: 60),
            steps: [
                "Sit with your back against the pad and the roller on your lower shins.",
                "Hold the handles.",
                "Straighten your legs until they're nearly locked.",
                "Lower slowly.",
            ],
            mistakes: [
                "Swinging the weight up.",
                "Lifting your hips off the seat.",
            ],
            tip: "Pause for a second at the top.",
            motion: Motion(frames: [
                Pose(hip: (0.42, 0.71), torso: 182, neck: 180, spread: (0, 0), arms: (8, 50, 4, 46), legs: (88, 2, 86, 0), feet: (90, 90)),
                Pose(hip: (0.42, 0.71), torso: 182, neck: 180, spread: (0, 0), arms: (8, 50, 4, 46), legs: (88, 86, 86, 84), feet: (176, 174)),
            ], worked: [.thigh], props: [.seat(x: 0.3, y: 0.75, width: 0.26), .pad(angle: 90)])
        ),
        Exercise(
            id: "leg-curl", name: "Leg curl", muscle: .legs, alsoWorks: [],
            equipment: .machine, isTimed: false,
            plan: .init(sets: 3, reps: 12, seconds: 0, rest: 60),
            steps: [
                "Lie face down with the pad just above your heels.",
                "Hold the handles and keep your hips on the bench.",
                "Curl your heels towards your bottom.",
                "Lower slowly to straight legs.",
            ],
            mistakes: [
                "Lifting your hips to help.",
                "Dropping the weight quickly.",
            ],
            tip: "Point your toes towards your shins to keep your calves out of it.",
            motion: Motion(frames: [
                Pose(hip: (0.44, 0.6), torso: 90, neck: 82, spread: (0, 0), arms: (2, 70, 0, 66), legs: (-90, -90, -90, -90), feet: (-90, -90)),
                Pose(hip: (0.44, 0.6), torso: 90, neck: 82, spread: (0, 0), arms: (2, 70, 0, 66), legs: (-90, -175, -90, -172), feet: (-265, -262)),
            ], worked: [.thigh], props: [.bench(x: 0.18, y: 0.645, width: 0.62), .pad(angle: -90)])
        ),
        Exercise(
            id: "calf-raise", name: "Calf raise", muscle: .legs, alsoWorks: [],
            equipment: .dumbbells, isTimed: false,
            plan: .init(sets: 3, reps: 15, seconds: 0, rest: 60),
            steps: [
                "Stand tall with a dumbbell in each hand, or on the edge of a step.",
                "Rise up onto the balls of your feet as high as you can.",
                "Pause at the top.",
                "Lower slowly, heels below the step if you're on one.",
            ],
            mistakes: [
                "Bouncing quickly.",
                "Bending your knees.",
            ],
            tip: "Slow and full range beats heavy and bouncy.",
            motion: Motion(frames: [
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (4, 6, -4, 4), legs: (2, 0, -2, 0), feet: (90, 90)),
                Pose(hip: (0.518, 0.47), torso: 180, neck: 180, spread: (0, 0), arms: (4, 6, -4, 4), legs: (2, 0, -2, 0), feet: (46, 46)),
            ], worked: [.shin], props: [.dumbbells])
        ),
        Exercise(
            id: "romanian-deadlift", name: "Romanian deadlift", muscle: .legs, alsoWorks: [.glutes, .back],
            equipment: .barbell, isTimed: false,
            plan: .init(sets: 3, reps: 10, seconds: 0, rest: 120),
            steps: [
                "Stand holding the bar at your hips, knees soft.",
                "Push your hips back and let the bar slide down your thighs.",
                "Stop when you feel a strong stretch in the back of your legs.",
                "Drive your hips forward to stand back up.",
            ],
            mistakes: [
                "Rounding your back to reach lower.",
                "Bending your knees into a squat.",
            ],
            tip: "The bar stays close to your legs the whole time.",
            motion: Motion(frames: [
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (4, 6, -4, 4), legs: (2, 0, -2, 0), feet: (90, 90)),
                Pose(hip: (0.475, 0.521), torso: 165.5, neck: 164.5, spread: (0, 0), arms: (-4.8, -2, -8.4, -5.5), legs: (13.6, -4.6, 5.625, -0.55), feet: (90, 90)),
                Pose(hip: (0.45, 0.527), torso: 151, neck: 149, spread: (0, 0), arms: (-11.7, -8.9, -14, -11.2), legs: (19.9, -3.6, 13.25, -1.1), feet: (90, 90)),
                Pose(hip: (0.425, 0.534), torso: 136.5, neck: 133.5, spread: (0, 0), arms: (-17.5, -14.6, -18.6, -15.8), legs: (24.7, -1, 20.875, -1.65), feet: (90, 90)),
                Pose(hip: (0.4, 0.54), torso: 122, neck: 118, spread: (0, 0), arms: (-22, -19, -22, -19), legs: (28.5, 2.7, 28.5, -2.2), feet: (90, 90)),
            ], worked: [.glutes, .thigh, .torso], props: [.barbell(radius: 0.075)])
        ),
        Exercise(
            id: "hip-thrust", name: "Hip thrust", muscle: .glutes, alsoWorks: [.legs],
            equipment: .barbell, isTimed: false,
            plan: .init(sets: 3, reps: 10, seconds: 0, rest: 90),
            steps: [
                "Sit with your upper back against a bench and a padded bar over your hips.",
                "Plant your feet so your shins are upright at the top.",
                "Drive your hips up until your body is flat from shoulders to knees.",
                "Lower your hips with control.",
            ],
            mistakes: [
                "Arching your lower back at the top.",
                "Feet too far away.",
            ],
            tip: "Tuck your chin and squeeze your glutes hard at the top.",
            motion: Motion(frames: [
                Pose(hip: (0.476, 0.809), torso: -122, neck: -107, spread: (0, 0), arms: (70.2, 67.2, 70.2, 67.2), legs: (115.6, -0.2, 115.3, -6.1), feet: (88, 88)),
                Pose(hip: (0.487, 0.772), torso: -114.25, neck: -99.25, spread: (0, 0), arms: (77.4, 74.3, 77.4, 74.3), legs: (104, -7.4, 103, -13.5), feet: (88, 88)),
                Pose(hip: (0.498, 0.734), torso: -106.5, neck: -91.5, spread: (0, 0), arms: (84.7, 81.6, 84.7, 81.6), legs: (92.7, -12.3, 91.2, -18.3), feet: (88, 88)),
                Pose(hip: (0.509, 0.697), torso: -98.75, neck: -83.75, spread: (0, 0), arms: (92.2, 89.1, 92.2, 89.1), legs: (81.7, -15, 80, -20.7), feet: (88, 88)),
                Pose(hip: (0.52, 0.66), torso: -91, neck: -76, spread: (0, 0), arms: (99.7, 97, 99.7, 97), legs: (70.8, -15.5, 69.1, -20.9), feet: (88, 88)),
            ], worked: [.glutes, .thigh], props: [.bench(x: 0.04, y: 0.68, width: 0.22), .barbellAtHip(radius: 0.075)])
        ),
        Exercise(
            id: "glute-bridge", name: "Glute bridge", muscle: .glutes, alsoWorks: [.legs],
            equipment: .bodyWeight, isTimed: false,
            plan: .init(sets: 3, reps: 15, seconds: 0, rest: 60),
            steps: [
                "Lie on your back with knees bent and feet flat.",
                "Push through your heels and lift your hips.",
                "Squeeze your glutes at the top.",
                "Lower slowly.",
            ],
            mistakes: [
                "Pushing up with your lower back.",
                "Letting your knees fall in.",
            ],
            tip: "Add a dumbbell on your hips once 20 reps feels easy.",
            motion: Motion(frames: [
                Pose(hip: (0.51, 0.885), torso: -92, neck: -92, spread: (0, 0), arms: (124, 26.3, 124, 26.3), legs: (143.5, -3.4, 142.2, -10.2), feet: (88, 88)),
                Pose(hip: (0.505, 0.855), torso: -86, neck: -86, spread: (0, 0), arms: (123.4, 28.1, 123.4, 28.1), legs: (129.7, -12.2, 127, -20), feet: (88, 88)),
                Pose(hip: (0.499, 0.826), torso: -80, neck: -80, spread: (0, 0), arms: (123.2, 28.8, 123.2, 28.8), legs: (118, -17.5, 115, -25.2), feet: (88, 88)),
                Pose(hip: (0.494, 0.796), torso: -74, neck: -74, spread: (0, 0), arms: (123.5, 28.2, 123.5, 28.2), legs: (108.1, -20.1, 105.1, -27.4), feet: (88, 88)),
                Pose(hip: (0.489, 0.766), torso: -68, neck: -68, spread: (0, 0), arms: (124, 26.3, 124, 26.3), legs: (99.3, -20.8, 96.6, -27.6), feet: (88, 88)),
            ], worked: [.glutes, .thigh], props: [.mat(from: 0.08, to: 0.8)])
        ),
        Exercise(
            id: "kettlebell-swing", name: "Kettlebell swing", muscle: .glutes, alsoWorks: [.legs, .back],
            equipment: .kettlebell, isTimed: false,
            plan: .init(sets: 3, reps: 15, seconds: 0, rest: 60),
            steps: [
                "Stand with the kettlebell a little in front of you and hinge to grab it.",
                "Hike it back between your legs.",
                "Snap your hips forward to swing it to chest height.",
                "Let it fall back between your legs and repeat.",
            ],
            mistakes: [
                "Lifting with your arms.",
                "Squatting instead of hinging.",
            ],
            tip: "The power comes from your hips; your arms just hold on.",
            motion: Motion(frames: [
                Pose(hip: (0.38, 0.58), torso: 118, neck: 110, spread: (0, 0), arms: (-40.3, -37.6, -40.3, -37.6), legs: (46.5, -6.2, 44.9, -13), feet: (90, 90)),
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (92, 92, 88, 88), legs: (2, 0, -2, 0), feet: (90, 90)),
            ], worked: [.glutes, .thigh, .torso], props: [.kettlebell])
        ),
        Exercise(
            id: "plank", name: "Plank", muscle: .core, alsoWorks: [],
            equipment: .bodyWeight, isTimed: true,
            plan: .init(sets: 3, reps: 0, seconds: 45, rest: 60),
            steps: [
                "Rest on your forearms with elbows under your shoulders.",
                "Lift your hips so your body is one straight line.",
                "Brace your stomach and squeeze your glutes.",
                "Breathe steadily and hold.",
            ],
            mistakes: [
                "Hips sagging or pushed high.",
                "Holding your breath.",
            ],
            tip: "Shorter holds done well are better than long saggy ones.",
            motion: Motion(frames: [
                Pose(hip: (0.394, 0.825), torso: 99, neck: 84, spread: (0, 0), arms: (0, 90, -2, 88), legs: (-81, -81, -81, -81), feet: (-6, -6)),
                Pose(hip: (0.394, 0.826), torso: 99.5, neck: 84.5, spread: (0, 0), arms: (0, 90, -2, 88), legs: (-80.5, -80.5, -80.5, -80.5), feet: (-5.5, -5.5)),
            ], worked: [.torso], props: [.mat(from: 0.1, to: 0.86)], period: 3)
        ),
        Exercise(
            id: "crunch", name: "Crunch", muscle: .core, alsoWorks: [],
            equipment: .bodyWeight, isTimed: false,
            plan: .init(sets: 3, reps: 15, seconds: 0, rest: 45),
            steps: [
                "Lie on your back with knees bent and fingertips by your ears.",
                "Breathe out and curl your shoulders off the floor.",
                "Pause briefly.",
                "Lower slowly.",
            ],
            mistakes: [
                "Pulling on your neck.",
                "Rushing the reps.",
            ],
            tip: "Think of bringing your ribs towards your hips.",
            motion: Motion(frames: [
                Pose(hip: (0.5, 0.875), torso: -90, neck: -80, spread: (0, 0), arms: (-115, 19.3, -115, 19.3), legs: (131.4, 25.5, 133.7, 21), feet: (92, 92)),
                Pose(hip: (0.5, 0.875), torso: -97, neck: -87, spread: (0, 0), arms: (-120.6, 16.8, -120.6, 16.8), legs: (131.4, 25.5, 133.7, 21), feet: (92, 92)),
                Pose(hip: (0.5, 0.875), torso: -104, neck: -94, spread: (0, 0), arms: (-127.6, 11.1, -127.6, 11.1), legs: (131.4, 25.5, 133.7, 21), feet: (92, 92)),
                Pose(hip: (0.5, 0.875), torso: -111, neck: -101, spread: (0, 0), arms: (-135.4, 2.3, -135.4, 2.3), legs: (131.4, 25.5, 133.7, 21), feet: (92, 92)),
                Pose(hip: (0.5, 0.875), torso: -118, neck: -108, spread: (0, 0), arms: (-143, -8.7, -143, -8.7), legs: (131.4, 25.5, 133.7, 21), feet: (92, 92)),
            ], worked: [.torso], props: [.mat(from: 0.1, to: 0.86)])
        ),
        Exercise(
            id: "hanging-leg-raise", name: "Hanging leg raise", muscle: .core, alsoWorks: [],
            equipment: .bodyWeight, isTimed: false,
            plan: .init(sets: 3, reps: 10, seconds: 0, rest: 60),
            steps: [
                "Hang from a bar with straight arms.",
                "Keep your legs together and still.",
                "Raise your legs until they're level with the floor.",
                "Lower slowly without swinging.",
            ],
            mistakes: [
                "Swinging to get the legs up.",
                "Dropping the legs quickly.",
            ],
            tip: "Start with bent knees until you can do straight legs.",
            motion: Motion(frames: [
                Pose(hip: (0.51, 0.65), torso: 182, neck: 182, spread: (0, 0), arms: (177.5, 174.6, -174.6, -177.5), legs: (6, -18, 2, -22), feet: (72, 68)),
                Pose(hip: (0.53, 0.648), torso: 186, neck: 186, spread: (0, 0), arms: (177.5, 174.6, -174.6, -177.5), legs: (88, 92, 84, 90), feet: (182, 180)),
            ], worked: [.thigh, .torso], props: [.bar(y: 0.07, from: 0.25, to: 0.75)])
        ),
        Exercise(
            id: "mountain-climber", name: "Mountain climber", muscle: .core, alsoWorks: [.cardio],
            equipment: .bodyWeight, isTimed: true,
            plan: .init(sets: 3, reps: 0, seconds: 30, rest: 30),
            steps: [
                "Start in a high plank with hands under your shoulders.",
                "Drive one knee towards your chest.",
                "Switch legs quickly, like running in place.",
                "Keep your hips level.",
            ],
            mistakes: [
                "Hips bouncing up high.",
                "Hands creeping forward.",
            ],
            tip: "Go steady to learn it, then speed up.",
            motion: Motion(frames: [
                Pose(hip: (0.393, 0.753), torso: 113, neck: 98, spread: (0, 0), arms: (2.6, 5.7, -1.5, 1.6), legs: (-14.3, 117.4, -67, -67), feet: (20, 8)),
                Pose(hip: (0.393, 0.753), torso: 113, neck: 98, spread: (0, 0), arms: (2.6, 5.7, -1.5, 1.6), legs: (-67, -67, -14.3, 117.4), feet: (8, 20)),
            ], worked: [.thigh, .torso], props: [.mat(from: 0.1, to: 0.86)], period: 0.9)
        ),
        Exercise(
            id: "running", name: "Running", muscle: .cardio, alsoWorks: [.legs],
            equipment: .cardioMachine, isTimed: true,
            plan: .init(sets: 1, reps: 0, seconds: 1200, rest: 0),
            steps: [
                "Start with a few minutes of walking to warm up.",
                "Run tall with relaxed shoulders and arms swinging forward and back.",
                "Land with your foot under your hips, not far out in front.",
                "Cool down with a few minutes of walking.",
            ],
            mistakes: [
                "Overstriding and landing on your heel far ahead.",
                "Starting too fast.",
            ],
            tip: "Easy runs should feel like you could still hold a conversation.",
            motion: Motion(frames: [
                Pose(hip: (0.48, 0.56), torso: 172, neck: 176, spread: (0, 0), arms: (-35, 20, 35, 120), legs: (38, 8, -22, -75), feet: (95, 60)),
                Pose(hip: (0.48, 0.528), torso: 172, neck: 176, spread: (0, 0), arms: (0, 70, 0, 70), legs: (10, -40, 5, -20), feet: (80, 80)),
                Pose(hip: (0.48, 0.56), torso: 172, neck: 176, spread: (0, 0), arms: (35, 120, -35, 20), legs: (-22, -75, 38, 8), feet: (60, 95)),
                Pose(hip: (0.48, 0.528), torso: 172, neck: 176, spread: (0, 0), arms: (0, 70, 0, 70), legs: (5, -20, 10, -40), feet: (80, 80)),
            ], worked: [.shin, .thigh], props: [.treadmill], loops: true, period: 0.8)
        ),
        Exercise(
            id: "walking", name: "Brisk walk", muscle: .cardio, alsoWorks: [.legs],
            equipment: .bodyWeight, isTimed: true,
            plan: .init(sets: 1, reps: 0, seconds: 1800, rest: 0),
            steps: [
                "Stand tall and look ahead.",
                "Swing your arms naturally.",
                "Walk at a pace where talking takes a little effort.",
                "Keep it going for the whole time.",
            ],
            mistakes: [
                "Looking down at your phone.",
                "Shuffling short steps.",
            ],
            tip: "Counts towards your step goal in Health too.",
            motion: Motion(frames: [
                Pose(hip: (0.48, 0.529), torso: 178, neck: 182, spread: (0, 0), arms: (-19.25, 11, 19.25, 66), legs: (20.9, 4.4, -12.1, -41.25), feet: (95, 60)),
                Pose(hip: (0.48, 0.519), torso: 178, neck: 182, spread: (0, 0), arms: (0, 38.5, 0, 38.5), legs: (5.5, -22, 2.75, -11), feet: (80, 80)),
                Pose(hip: (0.48, 0.529), torso: 178, neck: 182, spread: (0, 0), arms: (19.25, 66, -19.25, 11), legs: (-12.1, -41.25, 20.9, 4.4), feet: (60, 95)),
                Pose(hip: (0.48, 0.519), torso: 178, neck: 182, spread: (0, 0), arms: (0, 38.5, 0, 38.5), legs: (2.75, -11, 5.5, -22), feet: (80, 80)),
            ], worked: [.shin, .thigh], props: [], loops: true, period: 1.3)
        ),
        Exercise(
            id: "cycling", name: "Cycling", muscle: .cardio, alsoWorks: [.legs],
            equipment: .cardioMachine, isTimed: true,
            plan: .init(sets: 1, reps: 0, seconds: 1200, rest: 0),
            steps: [
                "Set the seat so your knee is slightly bent at the bottom of the pedal stroke.",
                "Start at an easy resistance to warm up.",
                "Keep a steady cadence and relaxed upper body.",
                "Ease off for the last few minutes.",
            ],
            mistakes: [
                "Seat too low, which strains the knees.",
                "Gripping the handlebars hard.",
            ],
            tip: "Intervals: 30 seconds hard, 90 seconds easy, repeated.",
            motion: Motion(frames: [
                Pose(hip: (0.45, 0.565), torso: 128, neck: 110, spread: (0, 0), arms: (-48.3, 93.3, -48.3, 93.3), legs: (83.8, -50.3, 50.2, -32.5), feet: (100, 100)),
                Pose(hip: (0.45, 0.565), torso: 128, neck: 110, spread: (0, 0), arms: (-48.3, 93.3, -48.3, 93.3), legs: (78.7, -22.4, 48.6, -63.4), feet: (100, 100)),
                Pose(hip: (0.45, 0.565), torso: 128, neck: 110, spread: (0, 0), arms: (-48.3, 93.3, -48.3, 93.3), legs: (50.2, -32.5, 83.8, -50.3), feet: (100, 100)),
                Pose(hip: (0.45, 0.565), torso: 128, neck: 110, spread: (0, 0), arms: (-48.3, 93.3, -48.3, 93.3), legs: (48.6, -63.4, 78.7, -22.4), feet: (100, 100)),
            ], worked: [.shin, .thigh], props: [.bike], loops: true, period: 1)
        ),
        Exercise(
            id: "rowing-machine", name: "Rowing machine", muscle: .cardio, alsoWorks: [.back, .legs],
            equipment: .cardioMachine, isTimed: true,
            plan: .init(sets: 1, reps: 0, seconds: 900, rest: 0),
            steps: [
                "Strap your feet in and hold the handle with straight arms.",
                "Push with your legs first, then lean back slightly, then pull with your arms.",
                "Return in reverse: arms, body, then bend your knees.",
                "Keep a smooth rhythm.",
            ],
            mistakes: [
                "Pulling with the arms before the legs have pushed.",
                "Hunching your back.",
            ],
            tip: "Legs, body, arms on the way out; arms, body, legs on the way back.",
            motion: Motion(frames: [
                Pose(hip: (0.46, 0.83), torso: 152, neck: 142, spread: (0, 0), arms: (92.9, -8.9, 92.9, -8.9), legs: (132.3, 32.8, 133.8, 30.7), feet: (160, 160)),
                Pose(hip: (0.42, 0.83), torso: 165.25, neck: 155.25, spread: (0, 0), arms: (80.9, -0.8, 80.9, -0.8), legs: (126.4, 40.9, 127.7, 39.1), feet: (160, 160)),
                Pose(hip: (0.38, 0.83), torso: 178.5, neck: 168.5, spread: (0, 0), arms: (73.1, 10.1, 73.1, 10.1), legs: (119.1, 49.8, 120.2, 48.5), feet: (160, 160)),
                Pose(hip: (0.34, 0.83), torso: 191.75, neck: 181.75, spread: (0, 0), arms: (69.7, 20.8, 69.7, 20.8), legs: (109.5, 60.9, 110.2, 59.9), feet: (160, 160)),
                Pose(hip: (0.3, 0.83), torso: 205, neck: 195, spread: (0, 0), arms: (72.2, 28.5, 72.2, 28.5), legs: (87.2, 84.7, 87.1, 84.6), feet: (160, 160)),
            ], worked: [.thigh, .torso, .upperArm], props: [.rower, .cable(x: 0.86, y: 0.79)], period: 2)
        ),
        Exercise(
            id: "jumping-jack", name: "Jumping jacks", muscle: .cardio, alsoWorks: [.legs],
            equipment: .bodyWeight, isTimed: true,
            plan: .init(sets: 3, reps: 0, seconds: 45, rest: 30),
            steps: [
                "Stand with feet together and arms by your sides.",
                "Jump your feet out wide while raising your arms overhead.",
                "Jump back to the start.",
                "Keep a steady rhythm.",
            ],
            mistakes: [
                "Landing heavily on your heels.",
                "Half arm movements.",
            ],
            tip: "A good warm-up before any workout.",
            motion: Motion(frames: [
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0.17, 0.08), arms: (16, 10, -16, -10), legs: (2, 0, -2, 0), feet: (60, -60)),
                Pose(hip: (0.5, 0.527), torso: 180, neck: 180, spread: (0.17, 0.08), arms: (150, 165, -150, -165), legs: (16, 14, -16, -14), feet: (60, -60)),
            ], worked: [.shin, .thigh], props: [], period: 1)
        ),
        Exercise(
            id: "hamstring-stretch", name: "Standing hamstring stretch", muscle: .mobility, alsoWorks: [.legs],
            equipment: .bodyWeight, isTimed: true,
            plan: .init(sets: 2, reps: 0, seconds: 30, rest: 15),
            steps: [
                "Stand with feet hip-width apart, knees soft.",
                "Hinge forward from your hips and let your hands slide down your legs.",
                "Stop when you feel a stretch in the back of your legs.",
                "Breathe and hold, then roll up slowly.",
            ],
            mistakes: [
                "Bouncing to go deeper.",
                "Locking your knees hard.",
            ],
            tip: "A gentle stretch you can hold is better than a deep one you fight.",
            motion: Motion(frames: [
                Pose(hip: (0.5, 0.515), torso: 180, neck: 180, spread: (0, 0), arms: (4, 6, -4, 4), legs: (2, 0, -2, 0), feet: (90, 90)),
                Pose(hip: (0.47, 0.515), torso: 40, neck: 20, spread: (0, 0), arms: (30.3, -73.8, 30.3, -73.8), legs: (2, 0, -2, 0), feet: (90, 90)),
            ], worked: [.thigh], props: [], period: 4)
        ),
        Exercise(
            id: "hip-flexor-stretch", name: "Kneeling hip flexor stretch", muscle: .mobility, alsoWorks: [.legs],
            equipment: .bodyWeight, isTimed: true,
            plan: .init(sets: 2, reps: 0, seconds: 30, rest: 15),
            steps: [
                "Kneel on one knee with the other foot forward, both knees bent.",
                "Tuck your hips under and squeeze the glute of the back leg.",
                "Shift forward gently until you feel a stretch at the front of the back hip.",
                "Hold, then switch sides.",
            ],
            mistakes: [
                "Arching your lower back.",
                "Leaning forward too far.",
            ],
            tip: "Great after long days sitting at a desk.",
            motion: Motion(frames: [
                Pose(hip: (0.44, 0.73), torso: 184, neck: 180, spread: (0, 0), arms: (22.1, -1.8, 22.1, -1.8), legs: (92.6, 4.4, 2.8, -88.5), feet: (90, -20)),
                Pose(hip: (0.47, 0.75), torso: 188, neck: 180, spread: (0, 0), arms: (23.8, 5.1, 23.8, 5.1), legs: (98.3, -3.7, -5.7, -94), feet: (90, -20)),
            ], worked: [.thigh], props: [.mat(from: 0.1, to: 0.86)], period: 4)
        ),
    ]
}
