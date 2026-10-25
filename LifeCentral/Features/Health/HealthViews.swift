import SwiftUI
import SwiftData
import Charts

struct HealthView: View {
    @Environment(AppRouter.self) private var router
    @Environment(HealthService.self) private var health
    @Query(sort: \HealthLog.date, order: .reverse) private var logs: [HealthLog]

    private let color = Area.health.color

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !health.isAvailable {
                    EmptyState(symbol: "heart.slash", title: "Apple Health isn't available here",
                               message: "You can still log weight, water and mood in Life Central.")
                        .card()
                } else if !health.isConnected {
                    connectCard
                }
                quickLog
                if health.isConnected {
                    ForEach(HealthMetric.Group.allCases, id: \.self) { group in
                        groupSection(group)
                    }
                    Link(destination: URL(string: "x-apple-health://")!) {
                        Label("Open the Health app", systemImage: "arrow.up.right.square").font(.subheadline.weight(.semibold))
                    }
                    .tint(color)
                }
                moodCard
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle("Health")
        .refreshable { await health.refreshAll() }
        .task { await health.refreshAll() }
    }

    private var connectCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            IconChip(symbol: "heart.fill", color: color, size: 44)
            Text("Connect Apple Health").font(.headline)
            Text("See steps, sleep, heart rate, weight and more in one place. Workouts and the weight and water you log here are saved back to Health. It all stays on your iPhone.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button {
                Task { await health.connect() }
            } label: {
                Text("Connect").frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .tint(color)
        }
        .card(padding: 16)
    }

    private var quickLog: some View {
        HStack(spacing: 10) {
            logButton("Weight", symbol: "scalemass", kind: .weight)
            logButton("Water", symbol: "drop", kind: .water)
            logButton("Mood", symbol: "face.smiling", kind: .mood)
        }
    }

    private func logButton(_ title: String, symbol: String, kind: HealthLogKind) -> some View {
        Button { router.present(.healthLog(kind)) } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.body.weight(.semibold))
                Text("Log \(title.lowercased())").font(.caption.weight(.semibold))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func groupSection(_ group: HealthMetric.Group) -> some View {
        let metrics = HealthMetric.allCases.filter { $0.group == group }
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: group.rawValue)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(metrics) { metric in
                    NavigationLink(value: Route.healthMetric(metric)) {
                        MetricTile(metric: metric, point: health.latest[metric], color: color)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var moodCard: some View {
        let moods = logs.filter { $0.kind == .mood }.prefix(14)
        if !moods.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Mood, last two weeks")
                HStack(spacing: 6) {
                    ForEach(Array(moods.reversed())) { log in
                        let index = max(0, min(4, Int(log.value) - 1))
                        VStack(spacing: 2) {
                            Image(systemName: MoodPicker.symbols[index])
                                .foregroundStyle(MoodPicker.color(index))
                            Text(log.date.formatted(.dateTime.day())).font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(log.date.formatted(date: .abbreviated, time: .omitted)): \(HealthLog.moods[index])")
                    }
                }
            }
            .card()
        }
    }
}

private struct MetricTile: View {
    let metric: HealthMetric
    let point: HealthPoint?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: metric.icon).foregroundStyle(color)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            Text(metric.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
            if let point {
                Text(metric.text(point.value)).font(.headline).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.7)
                Text(when(point.date)).font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("No data").font(.subheadline).foregroundStyle(.tertiary)
            }
        }
        .card(padding: 12)
    }

    private func when(_ date: Date) -> String {
        if metric == .sleep { return date.isToday ? "Last night" : "Night to \(DateText.relativeDay(date))" }
        return DateText.relativeDay(date)
    }
}

struct HealthMetricView: View {
    let metric: HealthMetric

    @Environment(AppRouter.self) private var router
    @Environment(HealthService.self) private var health
    @Query(sort: \HealthLog.date, order: .reverse) private var logs: [HealthLog]
    @State private var range = 30
    @State private var points: [HealthPoint] = []
    @State private var selected: Date?

    private let color = Area.health.color

    private var average: Double? {
        points.isEmpty ? nil : points.reduce(0) { $0 + $1.value } / Double(points.count)
    }

    private var selectedPoint: HealthPoint? {
        guard let selected else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selected)) < abs($1.date.timeIntervalSince(selected)) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Range", selection: $range) {
                    Text("Week").tag(7)
                    Text("Month").tag(30)
                    Text("Year").tag(365)
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 10) {
                    Text(metric.isTotal ? "Daily total" : "Daily average").font(.subheadline.weight(.semibold))
                    if let average {
                        Text("Average \(metric.text(average))").font(.footnote).foregroundStyle(.secondary)
                    }
                    if points.isEmpty {
                        Text(health.isConnected ? "No data for this period." : "Connect Apple Health on the Health screen to see this.")
                            .font(.footnote).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        chart
                    }
                }
                .card(padding: 16)

                if !points.isEmpty { stats }

                if let kind = metric.logKind {
                    Button { router.present(.healthLog(kind)) } label: {
                        Label("Log \(kind.title.lowercased())", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(color)
                }

                if !points.isEmpty { table }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle(metric.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: range) { await load() }
        .onChange(of: logs.count) { _, _ in Task { await load() } }
    }

    private func load() async {
        var loaded = await health.series(metric, days: range)
        // Without Health, fall back to what was logged in the app.
        if loaded.isEmpty, let kind = metric.logKind {
            let start = Date.now.startOfDay.adding(days: -(range - 1))
            let mine = logs.filter { $0.kind == kind && $0.date >= start }
            let byDay = Dictionary(grouping: mine) { $0.date.startOfDay }
            loaded = byDay.map { day, entries in
                let total = entries.reduce(0) { $0 + $1.value }
                let value = kind == .water ? total / 1000 : total / Double(entries.count)
                return HealthPoint(date: day, value: value)
            }
            .sorted { $0.date < $1.date }
        }
        points = loaded
        selected = nil
    }

    @ChartContentBuilder
    private func marks(_ point: HealthPoint) -> some ChartContent {
        if metric.isTotal {
            BarMark(x: .value("Day", point.date, unit: .day), y: .value(metric.title, point.value))
                .cornerRadius(3)
                .foregroundStyle(selectedPoint == nil || selectedPoint == point ? color : color.opacity(0.35))
        } else {
            LineMark(x: .value("Day", point.date, unit: .day), y: .value(metric.title, point.value))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .foregroundStyle(color)
            if range <= 30 {
                PointMark(x: .value("Day", point.date, unit: .day), y: .value(metric.title, point.value))
                    .symbolSize(50)
                    .foregroundStyle(color)
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(points) { point in
                marks(point)
            }
            if let point = selectedPoint {
                RuleMark(x: .value("Day", point.date, unit: .day))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(point.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(metric.text(point.value)).font(.caption.weight(.bold))
                        }
                        .padding(8)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
                    }
            }
        }
        .chartXSelection(value: $selected)
        .chartYScale(domain: .automatic(includesZero: metric.isTotal))
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: range > 30 ? .dateTime.month(.abbreviated) : .dateTime.day().month(.abbreviated))
            }
        }
        .frame(height: 220)
        .accessibilityLabel("\(metric.title) by day")
    }

    private var stats: some View {
        let values = points.map(\.value)
        return HStack(spacing: 10) {
            stat("Latest", points.last.map { metric.text($0.value) } ?? "–")
            stat("Lowest", values.min().map(metric.text) ?? "–")
            stat("Highest", values.max().map(metric.text) ?? "–")
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .card(padding: 12)
    }

    private var table: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "By day")
            ForEach(Array(points.suffix(14).reversed())) { point in
                ValueRow(label: DateText.relativeDay(point.date), value: metric.text(point.value), valueColor: .primary)
                    .font(.subheadline)
            }
        }
        .card(padding: 16)
    }
}

struct HealthLogSheet: View {
    let kind: HealthLogKind

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(HealthService.self) private var health
    @Query(sort: \HealthLog.date, order: .reverse) private var logs: [HealthLog]
    @Query private var habits: [Habit]

    @State private var selectedKind: HealthLogKind = .water
    @State private var weight: Double = 70
    @State private var waterTotal: Double = 0
    @State private var mood = 3
    @State private var date = Date.now
    @State private var didLoad = false

    private let color = Area.health.color
    private var todaysWater: Double {
        logs.filter { $0.kind == .water && $0.date.isToday }.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("What", selection: $selectedKind) {
                    ForEach(HealthLogKind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                switch selectedKind {
                case .weight: weightSection
                case .water: waterSection
                case .mood: moodSection
                }

                if selectedKind != .water {
                    DatePicker("When", selection: $date, in: ...Date.now)
                }
                if selectedKind != .mood && health.isConnected {
                    Label("Also saved to Apple Health", systemImage: "heart.fill")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .tint(color)
            .navigationTitle("Log \(selectedKind.title.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if selectedKind != .water {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: save).fontWeight(.bold)
                    }
                }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                selectedKind = kind
                if let last = logs.first(where: { $0.kind == .weight }) { weight = last.value }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var weightSection: some View {
        Section {
            HStack {
                Button { weight = max(20, weight - 0.1) } label: { Image(systemName: "minus.circle.fill").font(.title) }
                    .buttonStyle(.plain).foregroundStyle(color)
                    .accessibilityLabel("Less")
                Spacer()
                DecimalField(value: $weight, placeholder: "kg", font: .display(34))
                    .frame(width: 130)
                Text("kg").foregroundStyle(.secondary)
                Spacer()
                Button { weight += 0.1 } label: { Image(systemName: "plus.circle.fill").font(.title) }
                    .buttonStyle(.plain).foregroundStyle(color)
                    .accessibilityLabel("More")
            }
            .padding(.vertical, 6)
        }
    }

    private var waterSection: some View {
        Section {
            VStack(spacing: 8) {
                Text("\((todaysWater / 1000).formatted(.number.precision(.fractionLength(0...2)))) L today")
                    .font(.display(30))
                ProgressBar(value: todaysWater / 2000, color: color, height: 10)
                Text("Goal 2 L").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            HStack(spacing: 8) {
                ForEach([150, 250, 330, 500], id: \.self) { ml in
                    Button("+\(ml) ml") { addWater(Double(ml)) }
                        .buttonStyle(.bordered)
                        .font(.footnote.weight(.semibold))
                }
            }
            if let last = logs.first(where: { $0.kind == .water && $0.date.isToday }) {
                Button("Undo last (\(Int(last.value)) ml)", role: .destructive) { context.delete(last) }
                    .font(.footnote)
            }
        } footer: {
            Text("Each tap is saved straight away.")
        }
    }

    private var moodSection: some View {
        Section("How are you feeling?") {
            MoodPicker(selection: $mood)
                .padding(.vertical, 6)
        }
    }

    private func addWater(_ ml: Double) {
        context.insert(HealthLog(kind: .water, value: ml))
        Task { await health.saveWater(ml: ml, at: .now) }
        // The water habit ticks itself once the day's goal is reached.
        if todaysWater + ml >= 2000 {
            for habit in habits where habit.linkedMetric == "water" && !habit.isDone(on: .now) {
                habit.toggle(on: .now)
            }
        }
    }

    private func save() {
        switch selectedKind {
        case .weight:
            context.insert(HealthLog(kind: .weight, value: weight, date: date))
            let kg = weight, when = date
            Task { await health.saveWeight(kg: kg, at: when) }
        case .mood:
            context.insert(HealthLog(kind: .mood, value: Double(mood), date: date))
        case .water:
            break
        }
        dismiss()
    }
}

struct MoodPicker: View {
    @Binding var selection: Int

    static let symbols = ["cloud.rain", "cloud", "cloud.sun", "sun.max", "sparkles"]
    static func color(_ index: Int) -> Color {
        [Color(hex: "64748B"), Color(hex: "0E7490"), Color(hex: "A16207"), Color(hex: "C2410C"), Color(hex: "BE185D")][index]
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                let isOn = selection == index + 1
                Button { selection = index + 1 } label: {
                    VStack(spacing: 4) {
                        Image(systemName: Self.symbols[index]).font(.title2)
                        Text(HealthLog.moods[index]).font(.caption2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .foregroundStyle(isOn ? .white : Self.color(index))
                    .background(isOn ? Self.color(index) : Self.color(index).opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}
