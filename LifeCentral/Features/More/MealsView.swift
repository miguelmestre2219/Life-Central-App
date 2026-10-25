import SwiftUI
import SwiftData

struct MealsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MealPlanEntry.day) private var meals: [MealPlanEntry]
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Query(filter: #Predicate<ShoppingItem> { !$0.isBought }) private var shopping: [ShoppingItem]

    @State private var weekStart = Date.now.startOfWeek
    @State private var editing: MealTarget?
    @State private var editingRecipe: Recipe?
    @State private var newRecipe = false
    @State private var addedCount: Int?

    struct MealTarget: Identifiable {
        let id = UUID()
        let meal: MealPlanEntry?
        let day: Date
        let slot: MealSlot
    }

    private let color = Area.meals.color
    private var days: [Date] { (0..<7).map { weekStart.adding(days: $0) } }
    private var weekMeals: [MealPlanEntry] { meals.filter { $0.day >= weekStart && $0.day < weekStart.adding(days: 7) } }

    var body: some View {
        List {
            Section {
                HStack {
                    Button { weekStart = weekStart.adding(days: -7) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Previous week")
                    Spacer()
                    Text(weekStart.isSameDay(as: Date.now.startOfWeek) ? "This week" : "Week of \(weekStart.formatted(.dateTime.day().month(.abbreviated)))")
                        .font(.headline)
                    Spacer()
                    Button { weekStart = weekStart.adding(days: 7) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("Next week")
                }
                .buttonStyle(.borderless)
            }

            ForEach(days, id: \.self) { day in
                Section {
                    ForEach(MealSlot.allCases) { slot in
                        let meal = weekMeals.first { $0.day.isSameDay(as: day) && $0.slot == slot }
                        Button { editing = MealTarget(meal: meal, day: day, slot: slot) } label: {
                            HStack {
                                Text(slot.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                    .frame(width: 74, alignment: .leading)
                                if let meal {
                                    Text(meal.name).foregroundStyle(.primary)
                                    if meal.recipe != nil { Image(systemName: "book.closed").font(.caption).foregroundStyle(color) }
                                } else {
                                    Text("Add").foregroundStyle(.tertiary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        .foregroundStyle(day.isToday ? color : .secondary)
                }
            }

            Section {
                let ingredients = weekMeals.flatMap(\.ingredientList)
                Button {
                    addedCount = addToShopping(ingredients)
                } label: {
                    Label(addedCount.map { $0 == 0 ? "Everything is already on the list" : "Added \($0) to shopping" }
                          ?? "Add this week's ingredients to shopping (\(ingredients.count))",
                          systemImage: "cart.badge.plus")
                }
                .disabled(ingredients.isEmpty)
            }

            Section {
                ForEach(recipes) { recipe in
                    Button { editingRecipe = recipe } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recipe.name).foregroundStyle(.primary)
                            Text("\(recipe.ingredientList.count) ingredients · \(recipe.minutes) min").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in for i in offsets { context.delete(recipes[i]) } }
                Button { newRecipe = true } label: { Label("New recipe", systemImage: "plus") }
            } header: {
                Text("Recipes")
            }
        }
        .tint(color)
        .navigationTitle("Meals")
        .onChange(of: weekStart) { _, _ in addedCount = nil }
        .sheet(item: $editing) { target in
            MealForm(meal: target.meal, presetDay: target.day, presetSlot: target.slot)
        }
        .sheet(item: $editingRecipe) { recipe in RecipeForm(recipe: recipe) }
        .sheet(isPresented: $newRecipe) { RecipeForm(recipe: nil) }
    }

    /// Adds ingredients not already on the list. Returns how many were added.
    private func addToShopping(_ ingredients: [String]) -> Int {
        var existing = Set(shopping.map { $0.name.lowercased() })
        var added = 0
        for name in ingredients where !existing.contains(name.lowercased()) {
            context.insert(ShoppingItem(name: name))
            existing.insert(name.lowercased())
            added += 1
        }
        return added
    }
}

struct MealForm: View {
    let meal: MealPlanEntry?
    var presetDay: Date?
    var presetSlot: MealSlot?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Recipe.name) private var recipes: [Recipe]

    @State private var name = ""
    @State private var day = Date.now
    @State private var slot: MealSlot = .dinner
    @State private var recipe: Recipe?
    @State private var ingredients = ""
    @State private var note = ""
    @State private var saveAsRecipe = false
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What's cooking?", text: $name)
                    DatePicker("Day", selection: $day, displayedComponents: .date)
                    Picker("Meal", selection: $slot) {
                        ForEach(MealSlot.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                if !recipes.isEmpty {
                    Section {
                        Picker("Recipe", selection: $recipe) {
                            Text("None").tag(Recipe?.none)
                            ForEach(recipes) { Text($0.name).tag(Recipe?.some($0)) }
                        }
                        .onChange(of: recipe) { _, chosen in
                            if let chosen, name.isEmpty || recipes.contains(where: { $0.name == name }) { name = chosen.name }
                        }
                        if let recipe, !recipe.ingredientList.isEmpty {
                            Text(recipe.ingredientList.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    TextField("Ingredients, one per line", text: $ingredients, axis: .vertical)
                        .lineLimit(3...10)
                    TextField("Note", text: $note)
                    if meal == nil && recipe == nil {
                        Toggle("Save as a recipe too", isOn: $saveAsRecipe)
                    }
                } header: {
                    Text(recipe == nil ? "Ingredients" : "Extra ingredients")
                }
                if let meal {
                    Section {
                        Button("Remove from plan", role: .destructive) {
                            context.delete(meal)
                            dismiss()
                        }
                    }
                }
            }
            .tint(Area.meals.color)
            .navigationTitle(meal == nil ? "Plan a meal" : "Edit meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.bold)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        day = presetDay ?? .now
        slot = presetSlot ?? .dinner
        guard let meal else { return }
        name = meal.name
        day = meal.day
        slot = meal.slot
        recipe = meal.recipe
        ingredients = meal.ingredients
        note = meal.note
    }

    private func save() {
        let item: MealPlanEntry
        if let meal {
            item = meal
        } else {
            item = MealPlanEntry(day: day, slot: slot, name: name)
            context.insert(item)
        }
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.day = day.startOfDay
        item.slotRaw = slot.rawValue
        item.note = note
        if saveAsRecipe && recipe == nil {
            let newRecipe = Recipe(name: item.name)
            newRecipe.ingredients = ingredients
            context.insert(newRecipe)
            item.recipe = newRecipe
            item.ingredients = ""
        } else {
            item.recipe = recipe
            item.ingredients = ingredients
        }
        dismiss()
    }
}

struct RecipeForm: View {
    let recipe: Recipe?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var ingredients = ""
    @State private var steps = ""
    @State private var minutes = 30
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Recipe name", text: $name)
                Stepper("Takes \(minutes) min", value: $minutes, in: 5...300, step: 5)
                Section("Ingredients, one per line") {
                    TextField("e.g. 2 onions", text: $ingredients, axis: .vertical).lineLimit(4...15)
                }
                Section("Method") {
                    TextField("Steps", text: $steps, axis: .vertical).lineLimit(4...20)
                }
                if let recipe {
                    Section {
                        Button("Delete recipe", role: .destructive) {
                            context.delete(recipe)
                            dismiss()
                        }
                    }
                }
            }
            .tint(Area.meals.color)
            .navigationTitle(recipe == nil ? "New recipe" : "Edit recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let item = recipe ?? Recipe(name: name)
                        if recipe == nil { context.insert(item) }
                        item.name = name.trimmingCharacters(in: .whitespaces)
                        item.ingredients = ingredients
                        item.steps = steps
                        item.minutes = minutes
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                guard !didLoad, let recipe else { return }
                didLoad = true
                name = recipe.name
                ingredients = recipe.ingredients
                steps = recipe.steps
                minutes = recipe.minutes
            }
        }
    }
}

struct ShoppingView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ShoppingItem.createdAt) private var items: [ShoppingItem]
    @State private var newItem = ""
    @FocusState private var isAdding: Bool

    private let color = Area.meals.color
    private var toBuy: [ShoppingItem] { items.filter { !$0.isBought } }
    private var bought: [ShoppingItem] { items.filter(\.isBought) }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "plus.circle.fill").foregroundStyle(color).font(.title3)
                    TextField("Add an item", text: $newItem)
                        .focused($isAdding)
                        .submitLabel(.done)
                        .onSubmit(add)
                }
            } footer: {
                Text("Items are sorted into aisles automatically. Hold one to move it.")
            }

            ForEach(ShoppingItem.aisles, id: \.self) { aisle in
                let inAisle = toBuy.filter { $0.aisle == aisle }
                if !inAisle.isEmpty {
                    Section(aisle) {
                        ForEach(inAisle) { item in row(item) }
                            .onDelete { offsets in for i in offsets { context.delete(inAisle[i]) } }
                    }
                }
            }

            if !bought.isEmpty {
                Section {
                    ForEach(bought) { item in row(item) }
                    Button("Clear \(bought.count) bought", role: .destructive) {
                        for item in bought { context.delete(item) }
                    }
                } header: {
                    Text("In the basket")
                }
            }
        }
        .tint(color)
        .navigationTitle("Shopping")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) { Image(systemName: "square.and.arrow.up") }
                    .disabled(toBuy.isEmpty)
                    .accessibilityLabel("Share list")
            }
        }
        .overlay {
            if items.isEmpty {
                EmptyState(symbol: "cart", title: "Your list is empty",
                           message: "Add items here, or send a week of meal ingredients from Meals.")
                    .padding(.top, 140)
            }
        }
    }

    private func row(_ item: ShoppingItem) -> some View {
        Button {
            withAnimation { item.isBought.toggle() }
        } label: {
            HStack(spacing: 12) {
                CircleTick(isOn: item.isBought, color: color, size: 24)
                Text(item.name)
                    .strikethrough(item.isBought)
                    .foregroundStyle(item.isBought ? .secondary : .primary)
                if !item.note.isEmpty { Text(item.note).font(.caption).foregroundStyle(.secondary) }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Menu("Move to aisle") {
                ForEach(ShoppingItem.aisles, id: \.self) { aisle in
                    Button(aisle) { item.aisle = aisle }
                }
            }
            Button("Delete", role: .destructive) { context.delete(item) }
        }
    }

    private var shareText: String {
        var lines = ["Shopping list"]
        for aisle in ShoppingItem.aisles {
            let inAisle = toBuy.filter { $0.aisle == aisle }
            guard !inAisle.isEmpty else { continue }
            lines.append("")
            lines.append(aisle)
            lines += inAisle.map { "• \($0.name)" }
        }
        return lines.joined(separator: "\n")
    }

    private func add() {
        let name = newItem.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        context.insert(ShoppingItem(name: name))
        newItem = ""
        isAdding = true
    }
}
