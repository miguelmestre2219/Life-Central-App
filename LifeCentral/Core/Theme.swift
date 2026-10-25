import SwiftUI

/// Each part of the app has one colour, used for its tab, buttons and labels,
/// so the same colour always means the same area.
enum Area: String, CaseIterable, Identifiable {
    case today, money, travel, fitness, health, documents, habits, tasks, meals, friends, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .money: "Money"
        case .travel: "Travel"
        case .fitness: "Fitness"
        case .health: "Health"
        case .documents: "Documents"
        case .habits: "Habits"
        case .tasks: "Tasks and calendar"
        case .meals: "Meals and shopping"
        case .friends: "Friends and sharing"
        case .settings: "Settings"
        }
    }

    var color: Color {
        switch self {
        case .today: .primary
        case .money: Color(hex: "047857")
        case .travel: Color(hex: "1D4ED8")
        case .fitness: Color(hex: "C2410C")
        case .health: Color(hex: "BE123C")
        case .documents: Color(hex: "0E7490")
        case .habits: Color(hex: "6D28D9")
        case .tasks: Color(hex: "BE185D")
        case .meals: Color(hex: "A16207")
        case .friends: Color(hex: "3730A3")
        case .settings: Color(hex: "334155")
        }
    }

    /// Soft background used behind icons and selected chips.
    var tint: Color { color.opacity(0.14) }

    var icon: String {
        switch self {
        case .today: "sun.max"
        case .money: "creditcard"
        case .travel: "airplane"
        case .fitness: "dumbbell"
        case .health: "heart"
        case .documents: "doc.text"
        case .habits: "checkmark.circle"
        case .tasks: "calendar"
        case .meals: "fork.knife"
        case .friends: "person.2"
        case .settings: "gearshape"
        }
    }
}

extension Color {
    /// Accepts "RRGGBB" with or without a leading #.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// Colours people can pick for workouts, categories and trips.
    static let palette: [String] = ["C2410C", "1D4ED8", "047857", "7C3AED", "BE185D", "0E7490", "A16207", "334155"]
}

enum Theme {
    static let background = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    static let cornerRadius: CGFloat = 18
    static let gutter: CGFloat = 20
}

extension Font {
    /// Rounded, heavy display type for big numbers and screen titles.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
}
