import Foundation
import SwiftData

// MARK: Documents

enum DocumentFolder {
    static let defaults = ["Identity", "Travel", "Car", "Home", "Health", "Money", "Work", "Other"]

    static func icon(_ folder: String) -> String {
        switch folder {
        case "Identity": "person.text.rectangle"
        case "Travel": "airplane"
        case "Car": "car"
        case "Home": "house"
        case "Health": "cross.case"
        case "Money": "sterlingsign.circle"
        case "Work": "briefcase"
        default: "folder"
        }
    }
}

enum DocumentSource: String {
    case scan, file, photo
}

/// A stored document. The file itself lives encrypted in the app's folder
/// (see DocumentStore); this row holds what you search and sort by.
@Model
final class Document {
    var title: String = ""
    var folder: String = "Other"
    /// File name inside the app's encrypted documents folder.
    var storedFileName: String = ""
    var originalFileName: String = ""
    /// "pdf", "jpg", "png", "docx"…
    var fileExtension: String = "pdf"
    var pageCount: Int = 1
    var sourceRaw: String = DocumentSource.file.rawValue
    var expiresAt: Date?
    var remindDaysBefore: Int = 90
    var notes: String = ""
    /// Text read from scans and photos, so search finds words inside them.
    var recognizedText: String = ""
    @Attribute(.externalStorage) var thumbnail: Data?
    var createdAt: Date = Date.now

    var trip: Trip?
    var tripItem: TripItem?
    var bill: Bill?

    init(title: String, folder: String, storedFileName: String, fileExtension: String, source: DocumentSource) {
        self.title = title
        self.folder = folder
        self.storedFileName = storedFileName
        self.fileExtension = fileExtension
        self.sourceRaw = source.rawValue
    }

    var source: DocumentSource { DocumentSource(rawValue: sourceRaw) ?? .file }

    var isExpiringSoon: Bool {
        guard let expiresAt else { return false }
        return expiresAt.daysFromToday <= remindDaysBefore
    }

    var kindLabel: String { fileExtension.uppercased() }
}

// MARK: Habits

@Model
final class Habit {
    var name: String = ""
    var icon: String = "checkmark.circle"
    var colorHex: String = "6D28D9"
    var detail: String = ""
    /// 7 means every day.
    var targetPerWeek: Int = 7
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    /// Days ticked, stored as start-of-day dates.
    var completions: [Date] = []
    /// "water" fills itself from logged water.
    var linkedMetric: String = ""
    var isArchived: Bool = false

    init(name: String, icon: String = "checkmark.circle", targetPerWeek: Int = 7, detail: String = "") {
        self.name = name
        self.icon = icon
        self.targetPerWeek = targetPerWeek
        self.detail = detail
    }

    func isDone(on day: Date) -> Bool {
        completions.contains(day.startOfDay)
    }

    func toggle(on day: Date = .now) {
        let d = day.startOfDay
        if let i = completions.firstIndex(of: d) {
            completions.remove(at: i)
        } else {
            completions.append(d)
        }
    }

    /// Days in a row up to today (or yesterday if today is not ticked yet).
    var streak: Int {
        var day = Date.now.startOfDay
        if !completions.contains(day) { day = day.adding(days: -1) }
        var count = 0
        while completions.contains(day) {
            count += 1
            day = day.adding(days: -1)
        }
        return count
    }

    var doneThisWeek: Int {
        let start = Date.now.startOfWeek
        return completions.filter { $0 >= start }.count
    }

    var streakText: String {
        targetPerWeek < 7 ? "\(doneThisWeek) of \(targetPerWeek) this week" : (streak == 1 ? "1 day" : "\(streak) days")
    }
}

// MARK: Tasks

@Model
final class TodoItem {
    var title: String = ""
    var notes: String = ""
    var dueDate: Date?
    /// When false, the task is due on the day with no particular time.
    var hasTime: Bool = false
    var isDone: Bool = false
    var doneAt: Date?
    var createdAt: Date = Date.now
    var trip: Trip?

    init(title: String, dueDate: Date? = nil, hasTime: Bool = false) {
        self.title = title
        self.dueDate = dueDate
        self.hasTime = hasTime
    }

    var isOverdue: Bool {
        guard let dueDate, !isDone else { return false }
        return dueDate.startOfDay < Date.now.startOfDay
    }

    var isDueToday: Bool {
        guard let dueDate else { return false }
        return dueDate.isToday
    }
}

// MARK: Meals and shopping

enum MealSlot: Int, CaseIterable, Identifiable {
    case breakfast, lunch, dinner
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        }
    }
}

@Model
final class MealPlanEntry {
    var day: Date = Date.now
    var slotRaw: Int = MealSlot.dinner.rawValue
    var name: String = ""
    /// One ingredient per line.
    var ingredients: String = ""
    var note: String = ""
    var recipe: Recipe?

    init(day: Date, slot: MealSlot, name: String) {
        self.day = day.startOfDay
        self.slotRaw = slot.rawValue
        self.name = name
    }

    var slot: MealSlot { MealSlot(rawValue: slotRaw) ?? .dinner }

    var ingredientList: [String] {
        let own = ingredients.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
        let fromRecipe = recipe?.ingredientList ?? []
        return (own + fromRecipe).filter { !$0.isEmpty }
    }
}

@Model
final class Recipe {
    var name: String = ""
    var ingredients: String = ""
    var steps: String = ""
    var minutes: Int = 30
    @Relationship(deleteRule: .nullify, inverse: \MealPlanEntry.recipe)
    var meals: [MealPlanEntry]? = []

    init(name: String) {
        self.name = name
    }

    var ingredientList: [String] {
        ingredients.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

@Model
final class ShoppingItem {
    var name: String = ""
    var aisle: String = "Other"
    var note: String = ""
    var isBought: Bool = false
    var addedBy: String = ""
    var createdAt: Date = Date.now

    init(name: String, aisle: String? = nil, note: String = "") {
        self.name = name
        self.aisle = aisle ?? ShoppingItem.guessAisle(for: name)
        self.note = note
    }

    static let aisles = ["Fruit and veg", "Fridge", "Meat and fish", "Bakery", "Cupboard", "Frozen", "Drinks", "Household", "Other"]

    /// Simple keyword guess so items land in a sensible aisle.
    static func guessAisle(for name: String) -> String {
        let n = name.lowercased()
        let table: [(String, [String])] = [
            ("Fruit and veg", ["apple", "banana", "lemon", "lime", "broccoli", "carrot", "onion", "garlic", "potato", "tomato", "pepper", "spinach", "lettuce", "lentil", "avocado", "berries", "orange", "mushroom"]),
            ("Meat and fish", ["chicken", "beef", "pork", "salmon", "fish", "tuna", "mince", "bacon", "prawn", "lamb"]),
            ("Fridge", ["milk", "cheese", "yoghurt", "yogurt", "butter", "egg", "mozzarella", "cream", "ham"]),
            ("Bakery", ["bread", "bagel", "croissant", "wrap", "tortilla"]),
            ("Frozen", ["frozen", "ice cream", "peas"]),
            ("Drinks", ["coffee", "tea", "juice", "water", "wine", "beer"]),
            ("Household", ["soap", "detergent", "toilet", "bin bag", "sponge", "shampoo"]),
            ("Cupboard", ["rice", "pasta", "flour", "oil", "sugar", "salt", "beans", "tin", "cereal", "oats", "sauce", "spice"])
        ]
        for (aisle, words) in table where words.contains(where: { n.contains($0) }) {
            return aisle
        }
        return "Other"
    }
}

// MARK: Health logs kept in the app

enum HealthLogKind: String, CaseIterable, Identifiable {
    case weight, water, mood
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Weight, water and mood logged in Life Central. Weight and water are also
/// written to Apple Health when it is connected.
@Model
final class HealthLog {
    var kindRaw: String = HealthLogKind.weight.rawValue
    var date: Date = Date.now
    /// kg for weight, ml for water, 1…5 for mood.
    var value: Double = 0

    init(kind: HealthLogKind, value: Double, date: Date = .now) {
        self.kindRaw = kind.rawValue
        self.value = value
        self.date = date
    }

    var kind: HealthLogKind { HealthLogKind(rawValue: kindRaw) ?? .weight }

    static let moods = ["Low", "Meh", "OK", "Good", "Great"]
}

// MARK: Friends

/// Someone you share with. Filled from iCloud sharing once it is switched on.
@Model
final class Friend {
    var name: String = ""
    var colorHex: String = "3730A3"
    var addedAt: Date = Date.now

    init(name: String, colorHex: String = "3730A3") {
        self.name = name
        self.colorHex = colorHex
    }

    var initial: String { String(name.prefix(1)).uppercased() }
}
