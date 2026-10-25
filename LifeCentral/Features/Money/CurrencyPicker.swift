import SwiftUI
import SwiftData

/// Any currency in the world, searchable by name, code or country.
struct CurrencyPicker: View {
    @Binding var selection: String
    var suggested: [String] = []
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MoneyEntry.createdAt, order: .reverse) private var recent: [MoneyEntry]
    @AppStorage(SettingsKey.homeCurrency) private var home = "GBP"
    @State private var query = ""

    private var suggestions: [String] {
        var list: [String] = []
        for code in [home] + suggested + recent.prefix(40).map(\.currencyCode) where !list.contains(code) {
            list.append(code)
            if list.count == 6 { break }
        }
        return list
    }

    private var results: [String] {
        guard !query.isEmpty else { return CurrencyInfo.allCodes }
        return CurrencyInfo.allCodes.filter { code in
            code.localizedCaseInsensitiveContains(query)
                || CurrencyInfo.name(code).localizedCaseInsensitiveContains(query)
                || CurrencyInfo.countries(using: code).contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        List {
            if query.isEmpty {
                Section("Suggested") {
                    ForEach(suggestions, id: \.self) { row($0) }
                }
            }
            Section(query.isEmpty ? "All currencies" : "Results") {
                ForEach(results, id: \.self) { row($0) }
            }
        }
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Country, currency or code")
    }

    private func row(_ code: String) -> some View {
        Button {
            selection = code
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(CurrencyInfo.name(code)).foregroundStyle(.primary)
                    let countries = CurrencyInfo.countries(using: code)
                    if !countries.isEmpty {
                        Text(countries.prefix(3).joined(separator: ", ") + (countries.count > 3 ? " and more" : ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("\(CurrencyInfo.symbol(code))  \(code)")
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
                if code == selection {
                    Image(systemName: "checkmark").foregroundStyle(Area.money.color)
                }
            }
        }
    }
}
