import SwiftUI
import Observation

enum AppTab: String, CaseIterable, Identifiable {
    case today, money, travel, fitness, more
    var id: String { rawValue }
}

/// Every screen you can push onto a tab. All tabs share one list so a link
/// opens the same screen wherever it is tapped.
enum Route: Hashable {
    case search
    case inbox

    case moneyCategory(MoneyCategory)
    case moneyEntry(MoneyEntry)
    case monthlyPlan
    case bills

    case trip(Trip)
    case tripDay(Trip, Date)
    case tripMap(Trip, Date?)
    case tripBudget(Trip)
    case packing(Trip)
    case explore

    case workoutTemplate(WorkoutTemplate)
    case exerciseGuide(String)
    case progress(String?)
    case session(WorkoutSession)
    case health
    case healthMetric(HealthMetric)

    case documents
    case documentFolder(String)
    case document(Document)
    case habits
    case tasks
    case meals
    case shopping
    case friends
    case settings

    /// The tab a screen belongs to when opened from somewhere else.
    var homeTab: AppTab {
        switch self {
        case .search, .inbox: .today
        case .moneyCategory, .moneyEntry, .monthlyPlan, .bills: .money
        case .trip, .tripDay, .tripMap, .tripBudget, .packing, .explore: .travel
        case .workoutTemplate, .exerciseGuide, .progress, .session, .health, .healthMetric: .fitness
        default: .more
        }
    }
}

/// Forms shown as sheets. The + button and each area's own add button open
/// the same form, so adding something works the same way everywhere.
enum SheetRoute {
    case quickAdd
    case moneyEntry(MoneyEntry?, category: MoneyCategory? = nil, trip: Trip? = nil, isIncome: Bool = false)
    case bill(Bill?)
    case startWorkout
    case healthLog(HealthLogKind)
    case task(TodoItem?, trip: Trip? = nil)
    case trip(Trip?)
    case tripItem(TripItem?, trip: Trip?, day: Date?)
    case tripShare(Trip)
    case googleMaps(Trip, Date?)
    case document(folder: String?, trip: Trip? = nil, bill: Bill? = nil, tripItem: TripItem? = nil)
    case meal(MealPlanEntry?, day: Date?)
    case habit(Habit?)
    case newWorkout
}

struct PresentedSheet: Identifiable {
    let id = UUID()
    let route: SheetRoute
}

@Observable
final class AppRouter {
    var tab: AppTab = .today
    var paths: [AppTab: [Route]] = [:]
    var sheet: PresentedSheet?

    /// The gym session in progress, if any. It stays alive while minimised.
    var liveSession: WorkoutSession?
    var isLiveExpanded = false

    func path(_ tab: AppTab) -> Binding<[Route]> {
        Binding(get: { self.paths[tab] ?? [] }, set: { self.paths[tab] = $0 })
    }

    /// Opens a screen from anywhere: switches to its tab and shows it on top.
    func show(_ route: Route) {
        let target = route.homeTab
        tab = target
        paths[target] = [route]
    }

    func push(_ route: Route) {
        paths[tab, default: []].append(route)
    }

    func present(_ route: SheetRoute) {
        sheet = PresentedSheet(route: route)
    }

    func startWorkout(_ session: WorkoutSession) {
        liveSession = session
        isLiveExpanded = true
    }
}
