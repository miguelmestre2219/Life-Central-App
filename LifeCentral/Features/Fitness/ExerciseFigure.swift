import SwiftUI

// The cartoon figure used in exercise guides. It is drawn, not filmed: each
// exercise lists a few poses and the figure moves between them. The same
// maths lives in tools/exercise-figures, which renders preview sheets.

enum BodyPart: Hashable {
    case torso, chest, upperArm, forearm, thigh, shin, glutes
}

/// Joint angles in degrees: 0 points down, 90 forward (right), 180 up.
/// Positions are in a unit square with the floor at y = 0.94.
struct Pose {
    struct Limb {
        var upper: Double
        var lower: Double
    }

    var hip: CGPoint
    var torso: Double
    var neck: Double
    /// Shoulder and hip width; above zero the figure faces the viewer.
    var shoulderSpread: Double
    var hipSpread: Double
    var nearArm: Limb
    var farArm: Limb
    var nearLeg: Limb
    var farLeg: Limb
    var nearFoot: Double
    var farFoot: Double

    init(hip: (Double, Double), torso: Double, neck: Double, spread: (Double, Double),
         arms: (Double, Double, Double, Double), legs: (Double, Double, Double, Double), feet: (Double, Double)) {
        self.hip = CGPoint(x: hip.0, y: hip.1)
        self.torso = torso
        self.neck = neck
        self.shoulderSpread = spread.0
        self.hipSpread = spread.1
        self.nearArm = Limb(upper: arms.0, lower: arms.1)
        self.farArm = Limb(upper: arms.2, lower: arms.3)
        self.nearLeg = Limb(upper: legs.0, lower: legs.1)
        self.farLeg = Limb(upper: legs.2, lower: legs.3)
        self.nearFoot = feet.0
        self.farFoot = feet.1
    }

    var facesViewer: Bool { shoulderSpread > 0.05 }

    static func mix(_ a: Pose, _ b: Pose, _ t: Double) -> Pose {
        func m(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
        func limb(_ x: Limb, _ y: Limb) -> Limb { Limb(upper: m(x.upper, y.upper), lower: m(x.lower, y.lower)) }
        var p = a
        p.hip = CGPoint(x: m(a.hip.x, b.hip.x), y: m(a.hip.y, b.hip.y))
        p.torso = m(a.torso, b.torso)
        p.neck = m(a.neck, b.neck)
        p.shoulderSpread = m(a.shoulderSpread, b.shoulderSpread)
        p.hipSpread = m(a.hipSpread, b.hipSpread)
        p.nearArm = limb(a.nearArm, b.nearArm)
        p.farArm = limb(a.farArm, b.farArm)
        p.nearLeg = limb(a.nearLeg, b.nearLeg)
        p.farLeg = limb(a.farLeg, b.farLeg)
        p.nearFoot = m(a.nearFoot, b.nearFoot)
        p.farFoot = m(a.farFoot, b.farFoot)
        return p
    }
}

/// Where every joint ends up for a pose.
struct Skeleton {
    static let torsoLength = 0.29, neckLength = 0.035, headRadius = 0.062
    static let upperArm = 0.145, forearm = 0.135, thigh = 0.205, shin = 0.20, foot = 0.065
    static let floor = 0.94

    struct Chain {
        let root: CGPoint
        let middle: CGPoint
        let end: CGPoint
        var tip: CGPoint = .zero
    }

    let hip: CGPoint
    let shoulder: CGPoint
    let head: CGPoint
    let nearArm: Chain
    let farArm: Chain
    let nearLeg: Chain
    let farLeg: Chain

    static func direction(_ degrees: Double) -> CGPoint {
        let r = degrees * .pi / 180
        return CGPoint(x: sin(r), y: cos(r))
    }

    static func step(_ p: CGPoint, _ degrees: Double, _ length: Double) -> CGPoint {
        let v = direction(degrees)
        return CGPoint(x: p.x + v.x * length, y: p.y + v.y * length)
    }

    init(_ pose: Pose) {
        hip = pose.hip
        shoulder = Self.step(hip, pose.torso, Self.torsoLength)
        let r = pose.torso * .pi / 180
        let perp = CGPoint(x: -cos(r), y: sin(r))
        func offset(_ p: CGPoint, _ k: Double) -> CGPoint { CGPoint(x: p.x + perp.x * k, y: p.y + perp.y * k) }
        head = Self.step(shoulder, pose.neck, Self.neckLength + Self.headRadius)

        func arm(_ base: CGPoint, _ limb: Pose.Limb) -> Chain {
            let elbow = Self.step(base, limb.upper, Self.upperArm)
            return Chain(root: base, middle: elbow, end: Self.step(elbow, limb.lower, Self.forearm))
        }
        func leg(_ base: CGPoint, _ limb: Pose.Limb, _ foot: Double) -> Chain {
            let knee = Self.step(base, limb.upper, Self.thigh)
            let ankle = Self.step(knee, limb.lower, Self.shin)
            return Chain(root: base, middle: knee, end: ankle, tip: Self.step(ankle, foot, Self.foot))
        }
        nearArm = arm(offset(shoulder, pose.shoulderSpread / 2), pose.nearArm)
        farArm = arm(offset(shoulder, -pose.shoulderSpread / 2), pose.farArm)
        nearLeg = leg(offset(hip, pose.hipSpread / 2), pose.nearLeg, pose.nearFoot)
        farLeg = leg(offset(hip, -pose.hipSpread / 2), pose.farLeg, pose.farFoot)
    }

    var points: [CGPoint] {
        let r = Self.headRadius
        return [hip, shoulder, CGPoint(x: head.x, y: head.y - r), CGPoint(x: head.x - r, y: head.y), CGPoint(x: head.x + r, y: head.y)]
            + [nearArm, farArm].flatMap { [$0.root, $0.middle, $0.end] }
            + [nearLeg, farLeg].flatMap { [$0.root, $0.middle, $0.end, $0.tip] }
    }
}

enum Prop {
    case barbell(radius: Double)
    case barbellAtHip(radius: Double)
    case dumbbells
    case dumbbell
    case kettlebell
    case bench(x: Double, y: Double, width: Double)
    case incline(x: Double, y: Double, width: Double, angle: Double, length: Double)
    case seat(x: Double, y: Double, width: Double)
    case bar(y: Double, from: Double, to: Double)
    case dipBars(y: Double, from: Double, to: Double)
    case mat(from: Double, to: Double)
    case cable(x: Double, y: Double)
    case cables(nearX: Double, nearY: Double, farX: Double, farY: Double)
    case footPlate(x: Double, top: Double, bottom: Double)
    case treadmill
    case bike
    case rower
    case legPress(railFrom: CGPoint, railTo: CGPoint)
    case sled(angle: Double)
    case pad(angle: Double)

    /// Fixed points the drawing needs room for.
    var points: [CGPoint] {
        let floor = Skeleton.floor
        switch self {
        case let .bench(x, y, w), let .seat(x, y, w):
            return [CGPoint(x: x, y: y), CGPoint(x: x + w, y: y)]
        case let .incline(x, y, w, angle, length):
            return [CGPoint(x: x, y: y), CGPoint(x: x + w, y: y), Skeleton.step(CGPoint(x: x, y: y), 180 + angle, length)]
        case let .bar(y, from, to), let .dipBars(y, from, to):
            return [CGPoint(x: from, y: y), CGPoint(x: to, y: y)]
        case let .mat(from, to):
            return [CGPoint(x: from, y: floor), CGPoint(x: to, y: floor)]
        case let .cable(x, y):
            return [CGPoint(x: x, y: y)]
        case let .cables(nx, ny, fx, fy):
            return [CGPoint(x: nx, y: ny), CGPoint(x: fx, y: fy)]
        case let .footPlate(x, top, bottom):
            return [CGPoint(x: x, y: top), CGPoint(x: x, y: bottom)]
        case .treadmill:
            return [CGPoint(x: 0.12, y: floor), CGPoint(x: 0.86, y: 0.47)]
        case .bike:
            return [CGPoint(x: 0.21, y: 0.85), CGPoint(x: 0.83, y: 0.85), CGPoint(x: 0.72, y: 0.46)]
        case .rower:
            return [CGPoint(x: 0.08, y: floor), CGPoint(x: 0.92, y: floor - 0.16)]
        case let .legPress(_, to):
            return [CGPoint(x: 0.06, y: 0.48), to]
        default:
            return []
        }
    }
}

struct Motion {
    let frames: [Pose]
    let worked: Set<BodyPart>
    let props: [Prop]
    /// Loops round the frames (running, cycling) instead of going there and back.
    var loops = false
    /// Seconds for one full rep.
    var period: Double = 2.4

    init(frames: [Pose], worked: Set<BodyPart>, props: [Prop], loops: Bool = false, period: Double = 2.4) {
        self.frames = frames
        self.worked = worked
        self.props = props
        self.loops = loops
        self.period = period
        let points = frames.flatMap { Skeleton($0).points } + props.flatMap(\.points)
        let minX = (points.map(\.x).min() ?? 0) - 0.05
        let maxX = (points.map(\.x).max() ?? 1) + 0.05
        let minY = (points.map(\.y).min() ?? 0) - 0.05
        scale = min(1, Skeleton.floor / (Skeleton.floor - minY), 1 / (maxX - minX))
        centerX = (minX + maxX) / 2
    }

    /// Scale and centre that fit every frame in the square.
    let scale: Double
    let centerX: Double

    /// Progress through one rep, 0…1 (start → finish → start for there-and-back moves).
    func pose(at progress: Double) -> Pose {
        guard frames.count > 1 else { return frames.first! }
        let u = progress - progress.rounded(.down)
        if loops {
            let position = u * Double(frames.count)
            let index = Int(position) % frames.count
            return Pose.mix(frames[index], frames[(index + 1) % frames.count], position - Double(Int(position)))
        }
        // Ease out and back: 0 → 1 → 0.
        let s = 0.5 - 0.5 * cos(2 * .pi * u)
        return pose(along: s)
    }

    /// 0 is the start position, 1 the finish.
    func pose(along s: Double) -> Pose {
        let position = min(max(s, 0), 1) * Double(frames.count - 1)
        let index = min(Int(position), frames.count - 2)
        return Pose.mix(frames[index], frames[index + 1], position - Double(index))
    }
}

/// Draws one exercise, moving on its own unless paused or Reduce Motion is on.
struct ExerciseFigure: View {
    let motion: Motion
    var isPlaying = true
    var speed = 1.0
    /// Shown when paused: 0 start, 1 finish.
    var stillAt = 1.0
    var accent: Color = Area.fitness.color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    var body: some View {
        Group {
            if isPlaying && !reduceMotion {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(start) * speed
                    canvas(motion.pose(at: elapsed / motion.period))
                }
            } else {
                canvas(motion.pose(along: stillAt))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func canvas(_ pose: Pose) -> some View {
        Canvas { context, size in
            FigurePainter(motion: motion, pose: pose, size: size, accent: accent).draw(in: &context)
        }
    }
}

private struct FigurePainter {
    let motion: Motion
    let pose: Pose
    let size: CGSize
    let accent: Color

    private let body = Color(red: 0.58, green: 0.64, blue: 0.72)
    private let kit = Color.primary.opacity(0.85)
    private let plate = Color.primary.opacity(0.72)
    private let furniture = Color(red: 0.39, green: 0.45, blue: 0.55)

    private var side: Double { min(size.width, size.height) }

    private func point(_ p: CGPoint) -> CGPoint {
        let x = (0.5 + (p.x - motion.centerX) * motion.scale) * side + (size.width - side) / 2
        let y = (Skeleton.floor + (p.y - Skeleton.floor) * motion.scale) * side + (size.height - side) / 2
        return CGPoint(x: x, y: y)
    }

    private func width(_ w: Double) -> Double { w * side * motion.scale }

    private func line(_ ctx: inout GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ w: Double, _ color: Color) {
        var path = Path()
        path.move(to: point(a))
        path.addLine(to: point(b))
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width(w), lineCap: .round))
    }

    private func thinLine(_ ctx: inout GraphicsContext, _ a: CGPoint, _ b: CGPoint) {
        var path = Path()
        path.move(to: point(a))
        path.addLine(to: point(b))
        ctx.stroke(path, with: .color(.primary.opacity(0.6)), lineWidth: max(1, width(0.006)))
    }

    private func circle(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: Double, _ color: Color) {
        let center = point(c), radius = width(r)
        ctx.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
    }

    private func ring(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: Double, _ lineWidth: Double, _ color: Color) {
        let center = point(c), radius = width(r)
        ctx.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                   with: .color(color), lineWidth: width(lineWidth))
    }

    private func rect(_ ctx: inout GraphicsContext, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: Color) {
        let a = point(CGPoint(x: x, y: y)), b = point(CGPoint(x: x + w, y: y + h))
        ctx.fill(Path(CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)), with: .color(color))
    }

    private func colour(_ part: BodyPart) -> Color {
        motion.worked.contains(part) ? accent : body
    }

    func draw(in ctx: inout GraphicsContext) {
        let floor = Skeleton.floor
        let s = Skeleton(pose)
        line(&ctx, CGPoint(x: 0.04, y: floor + 0.012), CGPoint(x: 0.96, y: floor + 0.012), 0.008, .secondary.opacity(0.35))

        for prop in motion.props { drawFixed(prop, &ctx) }

        // Far limbs sit behind the body, a little faded, unless the figure faces us.
        if pose.facesViewer {
            drawLeg(s.farLeg, near: false, &ctx)
            drawArm(s.farArm, near: false, &ctx)
        } else {
            // The layer is blended as a whole, so joints don't double up.
            var faded = ctx
            faded.opacity = 0.5
            faded.drawLayer { layer in
                drawLeg(s.farLeg, near: false, &layer)
                drawArm(s.farArm, near: false, &layer)
            }
        }

        let torsoWidth = 0.11 + pose.shoulderSpread * 0.25
        line(&ctx, s.hip, s.shoulder, torsoWidth, colour(.torso))
        if motion.worked.contains(.chest) {
            let from = Skeleton.step(s.hip, pose.torso, Skeleton.torsoLength * 0.55)
            line(&ctx, from, s.shoulder, torsoWidth * 0.8, accent)
        }
        if motion.worked.contains(.glutes) {
            circle(&ctx, s.hip, 0.05, accent)
        }
        circle(&ctx, s.head, Skeleton.headRadius, body)
        if pose.facesViewer {
            circle(&ctx, CGPoint(x: s.head.x + 0.022, y: s.head.y - 0.01), 0.009, .white)
            circle(&ctx, CGPoint(x: s.head.x - 0.022, y: s.head.y - 0.01), 0.009, .white)
        } else {
            circle(&ctx, Skeleton.step(s.head, pose.neck - 120, Skeleton.headRadius * 0.45), 0.01, .white)
        }

        drawLeg(s.nearLeg, near: true, &ctx)
        drawArm(s.nearArm, near: true, &ctx)

        for prop in motion.props { drawHeld(prop, s, &ctx) }
    }

    private func drawLeg(_ leg: Skeleton.Chain, near: Bool, _ ctx: inout GraphicsContext) {
        line(&ctx, leg.root, leg.middle, near ? 0.072 : 0.068, colour(.thigh))
        line(&ctx, leg.middle, leg.end, near ? 0.062 : 0.06, colour(.shin))
        line(&ctx, leg.end, leg.tip, near ? 0.044 : 0.042, colour(.shin))
    }

    private func drawArm(_ arm: Skeleton.Chain, near: Bool, _ ctx: inout GraphicsContext) {
        line(&ctx, arm.root, arm.middle, near ? 0.054 : 0.052, colour(.upperArm))
        line(&ctx, arm.middle, arm.end, near ? 0.048 : 0.046, colour(.forearm))
    }

    private func drawFixed(_ prop: Prop, _ ctx: inout GraphicsContext) {
        let floor = Skeleton.floor
        switch prop {
        case let .bench(x, y, w):
            rect(&ctx, x, y, w, 0.035, furniture)
            rect(&ctx, x + 0.03, y + 0.035, 0.025, floor - y - 0.035, kit)
            rect(&ctx, x + w - 0.055, y + 0.035, 0.025, floor - y - 0.035, kit)
        case let .incline(x, y, w, angle, length):
            rect(&ctx, x, y, w, 0.035, furniture)
            rect(&ctx, x + w / 2 - 0.0125, y + 0.035, 0.025, floor - y - 0.035, kit)
            let top = Skeleton.step(CGPoint(x: x + 0.01, y: y), 180 + angle, length)
            line(&ctx, CGPoint(x: x + 0.01, y: y + 0.012), top, 0.04, furniture)
        case let .seat(x, y, w):
            rect(&ctx, x, y, w, 0.03, furniture)
            rect(&ctx, x + w / 2 - 0.0125, y + 0.03, 0.025, floor - y - 0.03, kit)
        case let .bar(y, from, to):
            line(&ctx, CGPoint(x: from, y: y), CGPoint(x: to, y: y), 0.016, kit)
        case let .dipBars(y, from, to):
            line(&ctx, CGPoint(x: from, y: y), CGPoint(x: to, y: y), 0.016, kit)
            line(&ctx, CGPoint(x: from + 0.02, y: y), CGPoint(x: from + 0.02, y: floor), 0.014, kit)
            line(&ctx, CGPoint(x: to - 0.02, y: y), CGPoint(x: to - 0.02, y: floor), 0.014, kit)
        case let .mat(from, to):
            rect(&ctx, from, floor - 0.012, to - from, 0.016, .secondary.opacity(0.18))
        case let .footPlate(x, top, bottom):
            line(&ctx, CGPoint(x: x, y: top), CGPoint(x: x, y: bottom), 0.025, kit)
        case .treadmill:
            rect(&ctx, 0.12, floor - 0.03, 0.72, 0.03, furniture)
            line(&ctx, CGPoint(x: 0.80, y: floor - 0.03), CGPoint(x: 0.86, y: 0.48), 0.018, kit)
            line(&ctx, CGPoint(x: 0.86, y: 0.48), CGPoint(x: 0.76, y: 0.47), 0.018, kit)
        case .bike:
            ring(&ctx, CGPoint(x: 0.30, y: 0.85), 0.085, 0.012, kit)
            ring(&ctx, CGPoint(x: 0.74, y: 0.85), 0.085, 0.012, kit)
            let frame: [(Double, Double, Double, Double)] = [
                (0.30, 0.85, 0.46, 0.60), (0.46, 0.60, 0.52, 0.80), (0.52, 0.80, 0.74, 0.85),
                (0.46, 0.60, 0.70, 0.52), (0.70, 0.52, 0.74, 0.85), (0.70, 0.52, 0.72, 0.46),
            ]
            for f in frame { line(&ctx, CGPoint(x: f.0, y: f.1), CGPoint(x: f.2, y: f.3), 0.016, kit) }
            line(&ctx, CGPoint(x: 0.40, y: 0.585), CGPoint(x: 0.50, y: 0.585), 0.022, kit)
        case .rower:
            rect(&ctx, 0.08, floor - 0.06, 0.84, 0.02, furniture)
            rect(&ctx, 0.80, floor - 0.16, 0.10, 0.10, kit)
        case let .legPress(from, to):
            rect(&ctx, 0.10, 0.70, 0.30, 0.03, furniture)
            line(&ctx, CGPoint(x: 0.12, y: 0.70), CGPoint(x: 0.06, y: 0.48), 0.035, furniture)
            rect(&ctx, 0.12, 0.73, 0.03, floor - 0.73, kit)
            rect(&ctx, 0.34, 0.73, 0.03, floor - 0.73, kit)
            line(&ctx, from, to, 0.014, kit)
            line(&ctx, CGPoint(x: from.x + 0.02, y: from.y), CGPoint(x: from.x + 0.02, y: floor), 0.014, kit)
            line(&ctx, CGPoint(x: to.x - 0.02, y: to.y + 0.01), CGPoint(x: to.x - 0.02, y: floor), 0.014, kit)
        default:
            break
        }
    }

    private func drawHeld(_ prop: Prop, _ s: Skeleton, _ ctx: inout GraphicsContext) {
        let hand = s.nearArm.end
        switch prop {
        case let .barbell(radius):
            circle(&ctx, hand, radius, plate)
            circle(&ctx, hand, 0.018, kit)
        case let .barbellAtHip(radius):
            let c = CGPoint(x: s.hip.x, y: s.hip.y - 0.07)
            circle(&ctx, c, radius, plate)
            circle(&ctx, c, 0.018, kit)
        case .dumbbells:
            for h in [s.farArm.end, hand] {
                line(&ctx, CGPoint(x: h.x - 0.03, y: h.y), CGPoint(x: h.x + 0.03, y: h.y), 0.04, kit)
            }
        case .dumbbell:
            line(&ctx, CGPoint(x: hand.x - 0.035, y: hand.y), CGPoint(x: hand.x + 0.035, y: hand.y), 0.045, kit)
        case .kettlebell:
            circle(&ctx, CGPoint(x: hand.x, y: hand.y + 0.045), 0.04, kit)
            ring(&ctx, hand, 0.018, 0.008, kit)
        case let .cable(x, y):
            let anchor = CGPoint(x: x, y: y)
            circle(&ctx, anchor, 0.022, kit)
            thinLine(&ctx, anchor, hand)
            circle(&ctx, hand, 0.016, kit)
        case let .cables(nx, ny, fx, fy):
            let near = CGPoint(x: nx, y: ny), far = CGPoint(x: fx, y: fy)
            circle(&ctx, near, 0.022, kit)
            circle(&ctx, far, 0.022, kit)
            thinLine(&ctx, near, hand)
            thinLine(&ctx, far, s.farArm.end)
        case let .sled(angle):
            let a = s.nearLeg.end, t = s.nearLeg.tip
            let mid = CGPoint(x: (a.x + t.x) / 2, y: (a.y + t.y) / 2)
            line(&ctx, Skeleton.step(mid, angle, -0.08), Skeleton.step(mid, angle, 0.08), 0.03, kit)
        case let .pad(angle):
            circle(&ctx, Skeleton.step(s.nearLeg.end, pose.nearLeg.lower + angle, 0.04), 0.03, kit)
        default:
            break
        }
    }
}
