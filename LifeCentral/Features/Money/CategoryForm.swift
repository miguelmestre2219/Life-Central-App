import SwiftUI
import SwiftData

struct CategoryForm: View {
    let category: MoneyCategory?
    var startAsIncome = false
    var onCreate: ((MoneyCategory) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var all: [MoneyCategory]
    @AppStorage(SettingsKey.homeCurrency) private var home = "GBP"

    @State private var name = ""
    @State private var icon = "tag"
    @State private var colorHex = "047857"
    @State private var isIncome = false
    @State private var planText = ""
    @State private var confirmArchive = false

    static let icons = [
        "cart", "fork.knife", "cup.and.saucer", "tram", "car", "fuelpump", "house", "bolt", "drop", "wifi",
        "bag", "tshirt", "sparkles", "gamecontroller", "film", "music.note", "book", "graduationcap",
        "cross.case", "pills", "dumbbell", "airplane", "bed.double", "gift", "pawprint", "figure.and.child.holdinghands",
        "heart", "scissors", "wrench.and.screwdriver", "banknote", "briefcase", "building.columns", "creditcard",
        "tag", "ellipsis.circle", "plus.circle",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Toggle("This is income", isOn: $isIncome)
                    HStack {
                        Text(isIncome ? "Expected each month" : "Plan each month")
                        Spacer()
                        Text(CurrencyInfo.symbol(home)).foregroundStyle(.secondary)
                        TextField("0", text: $planText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                Section("Colour") {
                    HStack {
                        ForEach(Color.palette, id: \.self) { hex in
                            Button { colorHex = hex } label: {
                                Circle().fill(Color(hex: hex)).frame(width: 30, height: 30)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: colorHex == hex ? 3 : 0))
                                    .overlay(Circle().strokeBorder(Color(hex: hex), lineWidth: colorHex == hex ? 1 : 0).padding(-2))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Colour \(hex)")
                        }
                    }
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(Self.icons, id: \.self) { symbol in
                            Button { icon = symbol } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(icon == symbol ? .white : Color(hex: colorHex))
                                    .background(icon == symbol ? Color(hex: colorHex) : Color(hex: colorHex).opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                if let category {
                    Section {
                        Button("Hide this category", role: .destructive) { confirmArchive = true }
                    } footer: {
                        Text("Hidden categories keep their past entries but stop showing in lists and the plan.")
                    }
                    .confirmationDialog("Hide \(category.name)?", isPresented: $confirmArchive, titleVisibility: .visible) {
                        Button("Hide", role: .destructive) {
                            category.isArchived = true
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(category == nil ? "New category" : "Edit category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty).fontWeight(.bold)
                }
            }
            .onAppear {
                if let category {
                    name = category.name
                    icon = category.icon
                    colorHex = category.colorHex
                    isIncome = category.isIncome
                    planText = MoneyFormat.editString(category.monthlyPlanMinor, home)
                } else {
                    isIncome = startAsIncome
                }
            }
        }
    }

    private func save() {
        let plan = MoneyFormat.parse(planText, home) ?? 0
        if let category {
            category.name = name
            category.icon = icon
            category.colorHex = colorHex
            category.isIncome = isIncome
            category.monthlyPlanMinor = plan
        } else {
            let created = MoneyCategory(name: name.trimmingCharacters(in: .whitespaces), icon: icon, colorHex: colorHex,
                                        isIncome: isIncome, monthlyPlanMinor: plan, sortOrder: (all.map(\.sortOrder).max() ?? 0) + 1)
            context.insert(created)
            onCreate?(created)
        }
        dismiss()
    }
}
